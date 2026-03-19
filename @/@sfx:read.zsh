
function @sfx:read {                   
	emulate -L zsh; setopt extendedglob typesetsilent
	if ! [[ -p /dev/stdin ]] { return 1 }        
         
	local Delimiter=${1%.(#i)rc(#e)}                
	shift                      
        
	@args:parse MaxEmptyReads:1 Timeout:1 FailSafe:1 OutDelimiter:+
	local -i MaxEmptyReads=${${MaxEmptyReads[1]}:-4}
	local -F Timeout=${${Timeout[1]}:-0.2}
	local -i FailSafe=${${FailSafe[1]}:-400}
	local OutDelim="${${OutDelimiter[1]}:-"{}"}" 
        
	local -a Buffer=()                      
          
	local -i ReadAttempts=${MaxEmptyReads}
	while (( ReadAttempts )) {        
		local Char
		IFS=  read -u 0 -t ${Timeout} -k 1 -rs Char

		(( ${#Buffer} > ${FailSafe} )) && { break }

		[[ -z $Char ]] && {
			((ReadAttempts--))
			continue
		}

		Buffer+=("${Char}")
		((ReadAttempts=MaxEmptyReads))

		local DelimMatch=${(M)${(j..)Buffer}%${~Delimiter}*}
		[[ -n $DelimMatch ]] && {
			local AfterDelim="${DelimMatch#*${~Delimiter}}"
			local BeforeDelim="${${(j..)Buffer}%${~Delimiter}*}"
			local ActualMatch="${(M)DelimMatch#${~Delimiter}}"
                        
			print -Nr -- ${BeforeDelim}
			print -Nr -- ${OutDelim//{}/$ActualMatch}
                        
			Buffer=(${(s..)AfterDelim})
		}
	}

	print -Nr -- ${Buffer:+"${(j..)Buffer}"}
}
alias -s rc=@sfx:read

