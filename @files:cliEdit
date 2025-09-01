#!/bin/zsh


() {


autoload -Uz @files:cliEdit
function @files:cliEdit {
	local FileName=${${1:?}:A}

	local -a EditBuffer=(
		"cat<<-\"EOF.${FileName:t}\">${FileName}\n"
		"${(@AF)"$(<${FileName})"}"
		"\nEOF.${FileName:t}"
	)

	print -lz - "${(@)EditBuffer}"
}


}

