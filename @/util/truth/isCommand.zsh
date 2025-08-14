#!/bin/zsh
##  @util:truth:isCommand.zsh


() {

autoload -Uz @util:truth:isCommand
function @util:truth:isCommand {
	local IsCommand=${${${$(command -v ${1} 2>/dev/null)}:+true}:-false}

	($IsCommand) && {
		echo 0
		return 0
	} || {
		echo 1
		return 1
	}
}

@util:truth:isCommand "$@"

} "$@"
