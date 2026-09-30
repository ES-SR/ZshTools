function @whence:function {
	emulate -LR zsh -o extendedglob -o typesetsilent

{ #set -x
	function __@whence:function:help {
		print -l -- \
			"Path: print the path to the file containing the function definition" \
			"Display: use the bat command to display the content of the found function file" \
			"CliEdit: the content of the found function file is placed on the command line for editing" \
			"Edit: open for editing in \$EDITOR or using the program passed as an argument after \"Edit\"" \
			"Help: display this message"
	}
	function __@whence:function:path {
		print -- ${FilePath}
	}
	function __@whence:function:display {
		bat -pp -l zsh --theme=Monokai\ Extended\ Bright "${FilePath}"
	}
	function __@whence:function:cliEdit {
		print -X2 -zR "$(< "${FilePath}")"
	}
	function __@whence:function:edit {
		(( ARGC )) && {
			${1} "${FilePath}"
		} || {
			${EDITOR} "${FilePath}" &!
		}
	}

	(( ARGC )) || {
		__@whence:function:help
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
		__@whence:function:${(L)Cmd[1]}${Cmd[2,-1]} ${(P)Cmd}
		CmdsExecuted+=($Cmd)
	}
	(( ${#CmdsExecuted} )) || {
		__@whence:function:path
	}

} always {
	unfunction \
		__@whence:function:help __@whence:function:path \
		__@whence:function:display __@whence:function:cliEdit \
		__@whence:function:edit 2>/dev/null
	set +x
}
}
