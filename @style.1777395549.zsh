
	function @style {
		emulate -L zsh; setopt extendedglob

		local -a Args=(${(q-)argv})
		local -a Splits=(${(s.@style.)Args})
		local -i Content=0

		local Split
		for Split ( "${(@)Splits}" ) {
			local -a Parts=("${(z)Split}")
			local Style="${Parts[1]}"
			Parts[1]=()
			if [[ ${Style} = (#i)(r(eset|)) ]] {
				tput sgr0
			} 
			if [[ "${Style}" = <-> ]] {
				@ColorScheme Style_${Style}
			}
			local -i SplitContent=${${Parts:+1}:-0}
			(( SplitContent )) && { 
				(( Content++ ))
				print -nR "${(Q)Parts}"
			}
		}

		(( Content )) && { tput sgr0; print }
	}

