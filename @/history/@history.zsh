

function @history {
	emulate -L zsh; setopt extendedglob typesetsilent

	function __update:__HistIdx {
		local IterIdx=$History[__IterIdx]
		History[__HistIdx]=${${(nk)History}[(rn.IterIdx.)<->]}
	}
	function __view {
		print -X2 -- ${$(print -r -- ${History[$History[__HistIdx]]})//(#m)(\$\'*\')/"${(q)MATCH}"} \
		| bat -l zsh -pp --theme Monokai\ Extended\ Bright \
			--style=header-filename --set-terminal-title \
			--file-name=\[$History[__HistIdx]\]\ $History[__IterIdx]\/$History[__Size]

	}
	function __next {
		(( History[__IterIdx] = 
				History[__IterIdx] + 1 > ${History[__Size]}
					? 1
					: History[__IterIdx] + 1 
		))
		__update:__HistIdx
	}
	function __previous {
		(( History[__IterIdx] = 
				History[__IterIdx] - 1 < 1
					?  ${History[__Size]}
					: History[__IterIdx] - 1 
		))
		__update:__HistIdx
	}
	function __reset {
	 	__populateHistory
		__browse
	}

	function __browse {
		emulate -L zsh; setopt extendedglob typesetsilent

	        local -A InputCmds=(
			[\[qQ\]]='__quit'
			[\[lL\]]='__next'
			[\[hH\]]='__previous'
			[\[cC\]]='__cliEdit'
			[\[eE\]]='__edit'
		)

		function __quit {
			RUN=0
		}
		function __cliEdit {
			__quit
			print -z -- ${$(print -r -- ${History[$History[__HistIdx]]})//(#m)(\$\'*\')/"${(q)MATCH}"}
		}
		function __edit {
			__quit
			$Editor <( print -r -- "${History[$History[__IterIdx]]}" )
		}
		local NL=$'\n'
		function __statusBar {
	                local -i IterIdx=$History[__IterIdx]
	                local -i Size=$History[__Size]
	                local -i HistIdx=$History[__HistIdx]
	
	                local -i 16 BgR BgG BgB FgR FgG FgB
	                local -a BgColor=(
	                        "#"
	                        ${(r.2..0.)$(([##16] R=50))}
	                        ${(r.2..0.)$(([##16] G=25))}
	                        ${(r.2..0.)$(([##16] B=0))}
	                )
	                local Bg="${(j..)BgColor}"
	                local -a FgColor=(
	                        "#"
	                        ${(r.2..0.)$(([##16] R=0))}
	                        ${(r.2..0.)$(([##16] G=250))}
	                        ${(r.2..0.)$(([##16] B=200))}
	                )
		                local Fg="${(j..)FgColor}"

	                print -P "%K{$Fg}%F{$Bg} $IterIdx/$Size [$HistIdx] %f%k"
	                local CmdDisp=${(k)InputCmds//(#m)(*)/"${MATCH}:${${InputCmds[$MATCH]}#__}"}
	                print -P "%K{$Bg}%F{$Fg} $CmdDisp %f%k${NL}"
	        }

		{
			tput smcup; tput civis
			local -x RUN=1
			while (( RUN )) {
				tput clear
				__statusBar

				__view
		
				local Input
				read -k 1 -s Input
				${InputCmds[(k)${~Input}]}
			}

		} always {
			tput rmcup; tput cnorm
		}
	}

	function __genDelim {
		local -a DelimChars=(
			$'\u0000'  # NUL
			$'\u0001'  # SOH
			$'\u0002'  # STX
			$'\u0003'  # ETX
			$'\u001D'  # Group separator
			$'\u001E'  # Record separator
			$'\u001F'  # Unit separator
			$'\u2007'  # figure space
			$'\u2008'  # punctuation space
			$'\u2009'  # thin space
			$'\u200A'  # hair space
			$'\u2011'  # non-breaking hyphen
		)
		local Len=${1:-$(( RANDOM % 10 + 5 ))}
		local Delim=${2:-""}

		for I ( {1..$Len} ) {
			Delim+="${DelimChars[$RANDOM%$#DelimChars+1]}"
		}
		print "${Delim}"
	}

	function __populateHistory {	
		emulate -L zsh; setopt extendedglob typesetsilent

		local Delimiter="$(__@history:genSplit)"
		local FilterPattern="*(#i)(${(j.)|(.)argv})*"

		(( SAFEMODE )) && {
			local HistContent="$(fc -ln 1)"
			while [[ "$HistContent" == *"$Delimiter"* ]] {
				Delimiter="$(__genDelim 1 "${Delimiter}")"
			}
		}
        
		local -a HistEntries=(${(Aps.$Delimiter.):-"$(
			fc -lnr -t ${Delimiter}"%s"${Delimiter} -m "${~FilterPattern}" 1
		)"})

		if [[ -v History ]] { 
			unset History
		}

		declare -gA History=(
			__IterIdx 1
			__HistIdx ${HistEntries[1]}
			__Size $(( $#HistEntries / 2 ))
			"${(@)HistEntries}"
		)
		print found $History[__Size] entries
	}

	local -a CmdNames=( view next  previous browse reset )
	local -A Cmds=(${${(e)$(@args:parse:generatePattern $CmdNames)}:^CmdNames})

	local AllCmdsPat="(${(kj.|.)Cmds})"
	local NonCmdArgs=("${(@)argv:#${~AllCmdsPat}}")
	(( ${#NonCmdArgs} > 0 || $+History < 1 )) && {
		__populateHistory $NonCmdArgs
		set -- ${argv:|NonCmdArgs}
	}

	(( ARGC )) || {
		__browse
		return
	}
		
	local SubCmd
	for SubCmd ( $argv ) {
		__${Cmds[(k)$SubCmd]}
	}
}


