

function @Examples {
{
	emulate -L zsh; @debug:init

	print -Pnu2 %F{cyan}%K{black}
	print -lu2 $funcstack
	print "Running Examples for ${1}"

	zpty Example ' RUN=1 && while (( RUN )) {  eval $( read -re ) } '
	while (( 1 )) {
		local Line=""
		read -t1 -rs Line
		print -Pnu2 %F{yellow}%K{black}
		print -n -- ${Line:+"${(q+)Line}\n"}
		(( ${(c)#Line} )) || {
			zpty -w Example 'RUN=0'
			zpty -d Example
			break
		}
		zpty -w Example "${(z)Line}"
		print -Pnu2 %F{green}%K{black}
		local FailSafe=10
		until ( zpty -tr Example ) { (( (FailSafe--) )) &&  sleep 0.1 || break }
		print -Pnu2 %k%f
	}
	print -Pnu2 %k%f

	} always {
		2>/dev/null {
			zpty -w Example 'RUN=0'
			zpty -d Example
		}
		tput sgr0
	}
}

NullCmds+=( @Examples )
