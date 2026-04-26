
function @delimiter:generate {
	emulate -L zsh; setopt extendedglob typesetsilent

	@args:parse Length:1 SafeMode:+ '(#s)+(#e)':AddDelimChars:+ '(#s)-(#e)':RmDelimChars:+ Delimiter:1 Visible
	set -- "${(@)ParsedArgv}"

	local -aU DelimChars=(
		"\u0000" # NUL
		"\u0001" # SOH
		"\u0002" # STX
		"\u0003" # ETX
		"\u001D" # Group separator
		"\u001E" # Record separator
		"\u001F" # Unit separator
		"\u2007" # figure space
		"\u2008" # punctuation space
		"\u2009" # thin space
		"\u200A" # hair space
		"\u2011" # non-breaking hyphen
	)

	(( ${#AddDelimChars} )) && {
		DelimChars+=("${(@)AddDelimChars[2,-1]}")
	}
	(( ${#RmDelimChars} )) && {
		DelimChars=("${(@)DelimChars:|RmDelimChars}")
	}
	(( ${#Argv} )) && {
		DelimChars=("${(@)Argv}")
	}

	local Delim=${Delimiter:-""}
	local -i Len=${${Length[1]}:-$(( RANDOM % 10 + 5 ))}

	local -i I
	for I ( $(@numbers:random:range 1,${#DelimChars} $Len) ) {
		Delim+="${DelimChars[$I]}"
	}

	(( ${#SafeMode} )) && {
		while [[ *${SafeMode}* = *${Delim}* ]] {
			Delim+="${DelimChars[$(@numbers:random:range 1,${#DelimChars} 1)]}"
		}
	}

	local EchoOpt=""
	(( Visible )) && {
		EchoOpt="-E"
	}

	echo ${(e)EchoOpt} "${Delim}"
}

:<<-"Examples.@delimiter:generate"
	#input<
	@delimiter:generate -V
	#output> \u001E\u001D\u0003\u0001\u0002\u001F\u0003\u0000
Examples.@delimiter:generate
