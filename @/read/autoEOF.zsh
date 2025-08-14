#!/bin/zsh
##  @read:autoEOF
###


() {

function __@read:autoEOF {
	local MAX_BLANK=${1:-2}
	local TIMEOUT=${2:-1}
	local DELAY=${3:-0}
	local LINE CNT
	while [[ ${${${LINE::="$(IFS= read -t${TIMEOUT} -rse)"}:+$CNT}:-$((CNT++))} -lt ${MAX_BLANK} ]] {
		if [[ -n $LINE ]] {
			while [[ $CNT -gt 0 ]] {
				echo ""
				((CNT=CNT-1))
			}
		}

		echo -n "${LINE}${LINE:+"\n"}"
		sleep $DELAY
	}
}

__@read:autoEOF "$@"

} "$@"
