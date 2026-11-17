function @zpty:eval {
	emulate -LR zsh -o extendedgob

	function @zpty:eval:start {
		local Name="${1:-Eval}"
		[[ -n "$(print -m "*${Name}*" $(zpty -L) )" ]] && {
			print -u2 "zpty ${Name} command already running"
			return	
		}
		zpty -n ${Name} \
			'print -n $TTY; while (( 1 )) {  (( ${(c)#CMD::="$(read -t1 -re)"} )) && { eval "$CMD" } || { continue } }'
	}

	alias @zpty:eval:end='() { zpty -d ${1:-Eval} } '

	alias @zpty:eval:write='() { zpty -w ${1:-Eval} $(read -t1 -u0 -re) } '

	function @zpty:eval:read {
		local Name=${1:-Eval}
		local -i MaxCount=${2:-5} Count=$MaxCount
		local -F SleepTime=${3:-1}
		local Line
	
		while (( ${${${Line::="$(zpty -tr ${Name})"}:+${(e)$((Count=MaxCount))}}:-$((Count--))} )) {
			(( ${(c)#Line} )) && {
				local Lines=(${(f)Line})
				local L; for L ( "${(@)Lines}" ) {
					print -n -- ${L:+"${L}\n"}
				}
			} || {
				sleep $(( SleepTime *= ( 1 - 1.*Count / MaxCount ) ))
			}
		}
	}
	
}
