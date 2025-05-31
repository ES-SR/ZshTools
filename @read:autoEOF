#!/bin/zsh
##  @read:autoEOF
###


() {


function __@read:autoEOF {
	local MAX_BLANK=${1:-2}
	while [[  ${${${LINE::="$(IFS= read -rse)"}:+$(( CNT=0 ))}:-$((CNT++))} -lt ${MAX_BLANK} ]] {
		print -nP - "${LINE}${LINE:+"\n"}"
  	}
}

__@read:autoEOF "$@"

} "$@"
