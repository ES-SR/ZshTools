
function @read { 
	emulate -L zsh; setopt extendedglob typesetsilent
	if ! [[ -p /dev/stdin ]] { return 1 } 
 
	@args:parse MaxEmptyReads:1 Timeout:1 OutDelimiter:+ InDelimiter:+
	set -- "${(@)ParsedArgv}"

	local -i MaxEmptyReads=${${MaxEmptyReads[1]}:-4}
	local -F Timeout=${${Timeout[1]}:-0.2}
	local InDelim="${InDelimiter:-"${argv:-"{}"}"}"
	local OutDelim="${:-"${OutDelimiter:-"{}"}"} "

	local -a Buffer=() 
 
	local -i ReadAttempts=${MaxEmptyReads}
	while (( ReadAttempts )) { 
		local Char
		IFS= read -u 0 -t ${Timeout} -k 1 -rs Char

		[[ -z $Char ]] && {
			((ReadAttempts--))
			continue
		}

		Buffer+=("${Char}")
		((ReadAttempts=MaxEmptyReads))
		local BuffStr="${(j..)Buffer}"
		local FirstDelim=""

		while [[ -n "${FirstDelim::="${(M)BuffStr#*${~InDelim}}"}" ]] {
			BuffStr="${BuffStr#*${~InDelim}}"
			print -nr -- "${FirstDelim/${~InDelim}/"${OutDelim}"}"
		}
		Buffer=(${(s..)BuffStr})
	}
	##common pattern i use
	#print -nr -- ${Buffer:+"${(j..)Buffer}"$'\n'}
	##allows print -n like in the example to prevent a new line in the output
	print -nr -- ${Buffer:+"${(j..)Buffer}"}
}

: <<"Examples.@read"
	() {
		{
		#	set -x
			print -nl -- {} hello {} world | @read outdelimiter '<{}>'
		} always {
			set +x
		}
	}
Examples.@read
