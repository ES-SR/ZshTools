
() {

	autoload -Uz @history:toAA
	function @history:toAA {
		emulate -L zsh; setopt extendedglob; @debug:init
		#(( DEBUG )) && {
			#exec 3>&2
			#set -x
		#} || {
			#exec 3>/dev/null
		#}

		local -x Split
		function __@history:genSplit {
			local -ax SplitChars=(
				$'ƒ '  # NUL
				$''  # SOH
				$''  # STX
				$''  # ETX
				$''  # Group separator
				$''  # Record separator
				$''  # Unit separator
				$'â€ƒ§'  # figure space
				$'â€ƒ¨'  # punctuation space
				$'â€ƒ©'  # thin space
				$'â€ƒª'  # hair space
				$'â€ƒ±'  # non-breaking hyphen
			)
			local Len=${1:-$(( RANDOM % 10 + 5 ))}

			for I ( {1..$Len} ) {
				Split+="${SplitChars[$RANDOM%$#SplitChars+1]}"
			}
		}

		__@history:genSplit

		local FilterPattern=\*(#i)(${(j.)|(.)@})\*

		(( SAFEMODE )) && {
			local HistContent="$(fc -ln 1)"
			while [[ "$HistContent" == *"$Split"* ]] {
				__@history:genSplit 1
			}
		}
    
		print -u3 ${(V)Split}
		declare -gA HistList=(${(Aps.$Split.):-"$(fc -ln -t ${Split}"%s"${Split} -m "${FilterPattern}" 1)"})
	}

}
