function @whence:function {
	emulate -LR zsh -o extendedglob -o typesetsilent
{ #set -x
	__help () {
		print -l -- \
			"Path: print the path to the file containing the function definition" \
			"Display: use the bat command to display the content of the found function file" \
			"CliEdit: the content of the found function file is placed on the command line for editing" \
			"Edit: open for editing in \$EDITOR or using the program passed as an argument after \"Edit\"" \
			"Help: display this message"
	}
	__path () {
		print -- ${FilePath}
	}
	__display () {
		bat -pp -l zsh --theme=Monokai\ Extended\ Bright "${FilePath}"
	}
	__cliEdit () {
		print -X2 -zR "$(< "${FilePath}")"
	}
	__edit () {
		(( ARGC )) && {
			${1} "${FilePath}"
		} || {
			${EDITOR} "${FilePath}"
		}
	}

	(( ARGC )) || {
		__help
		return
	}

	@args:parse Display CliEdit Edit:1 Help

	local FilePath=${${(z):-"$( whence -v ${${PositionalArgs[1]}:-${Edit[1]}} )"}[-1]}
	FilePath=${(Q)FilePath:A}
	[[ -f "${FilePath}" && "$(file "${FilePath}")" = *"text"*  ]] || { return 1 }

	local -a CmdsExecuted
	local Cmd
	for Cmd ( "${(@)FlagInfo}" ) {
		Cmd=${Cmd%%:*}
		__${(L)Cmd[1]}${Cmd[2,-1]} ${(P)Cmd}
		CmdsExecuted+=($Cmd)
	}
	(( ${#CmdsExecuted} )) || {
		__path
	}

} always {
	unfunction __help __path __display __cliEdit __edit
	set +x
}
}
