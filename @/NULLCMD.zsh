
function @NULLCMD {
	emulate -L zsh; @debug:init; options[extendedglob]=on

	(( ${+NULLCMDS} + ${+NullCmds} < 2 )) && {
		if (( ${+NULLCMDS} )) {
			declare -gxUa NullCmds
			declare -Tgx NULLCMDS="${NULLCMDS}" NullCmds
		} elif (( ${+NullCmds} )) {
			declare -gxU NULLCMDS
			declare -Tgx NULLCMDS NullCmds=("${(@)NullCmds}")
		} else {
			declare -gxU NULLCMDS
			declare -gxUa NullCmds
			declare -Tgx NULLCMDS NullCmds
		}
	}

	local -a argv; read -u 0 -t 0.3 -s -A argv
	local Cmd=${${1}%.*}

	local -aU AllowedFuncs=(${(s.:.)NULLCMDS})
	(( #argv && ${AllowedFuncs[(I)$Cmd]} )) && {
		$Cmd $argv[2,-1]
	}
}

NULLCMD=@NULLCM
