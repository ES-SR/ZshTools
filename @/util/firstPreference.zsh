#!/bin/zsh
##  @util:firstPreference.zsh


() {

autoload -Uz @util:firstPreference
function @util:firstPreference {
	local TruthFuncName=${1}
	local -a Preferences=( ${@[2,-1]} )

	for P ( ${Preferences} ) {
		($TruthFuncName ${P} >/dev/null) && {
			print - $P
			return
		}
	}
 	return 1
}

@util:firstPreference "@"

} "$@"
