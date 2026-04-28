
function @ColorScheme {
	emulate -L zsh; setopt extendedglob


	if ! [[ -v ColorScheme ]] {
		local -aU SchemeColors=(${(u)LsColors//(#m)(*)/${(q-):-"${MATCH#*=}"}})
		local -aU Names

		local C I=0; for C ( ${SchemeColors} ) {
			Names+=(Style_$((I++)))
		}

		declare -Agx ColorScheme=(${Names:^SchemeColors})
	}

	local -a CmdNames=( __list __display __help __update )
	local -A Cmds=(${${(e)$(@args:parse:generatePattern ${CmdNames#__})}:^CmdNames})

	function __update { unset ColorScheme && @ColorScheme -d }
	function __help { print -aC2 ${(kv)Cmds} }
	function __list { print -l ${(nk)ColorScheme//(#m)(*)/$MATCH $ColorScheme[$MATCH]} }
	function __display {
		local K; for K ( ${(nk)ColorScheme} ) {
			print $'\\\e\['"${(Q)ColorScheme[$K]}m $K $(tput sgr0)"
		}
	}

	(( ARGC )) || { __help && return 1 }

	local -A IndexedArgs=(${${(e):-{1..$ARGC}}:^argv})
	local -a StyleIdxs=(${(k)IndexedArgs[(R)(#i)Style([-_]|)<->]})

	local StyleIdx
	for StyleIdx ( ${StyleIdxs} ) {
		local Name=$argv[$StyleIdx]
		argv[$StyleIdx]=()
		print -n -- $'\\\e\['"${(Q)ColorScheme[$Name]}m"	
	}
	local -a Args=("${(@)argv}")
	while (( ${#Args} )) {
		local Cmd=${Cmds[(k)${Args[1]}]}
		(( ${(c)#Cmd} )) && {
			Args[1]=()
		}
		${(e)Cmd}
	}
}
