function @delimiter:generate {
        emulate -L zsh; setopt extendedglob typesetsilent

        @args:parse Visible Length:1 ++:AddDelimChars:+ --:RmDelimChars:+ Delimiter:1 SafeMode:+
        set -- "${(@)Argv}"

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
        )

        (( ${#Argv} )) && {
                DelimChars=(${(@s..)Argv})
        }
        (( ${#AddDelimChars} )) && {
                AddDelimChars=(${(@s..)AddDelimChars})
                DelimChars+=(${(@)AddDelimChars})
        }
        (( ${#RmDelimChars} )) && {
                RmDelimChars=(${(@s..)RmDelimChars})
                DelimChars=(${(@)DelimChars:|RmDelimChars})
        }

        local Delim=${Delimiter:-""}
        local -i Len=${${Length[1]}:-$(( RANDOM % 10 + 5 ))}

        local -i I
        for I ( $(@numbers:random:range 1,${#DelimChars} $Len) ) {
                Delim+=${DelimChars[$I]}
        }

        (( ${#SafeMode} )) && {
                while [[ *${SafeMode}* = *${Delim}* ]] {
                        Delim+=${DelimChars[$(@numbers:random:range 1,${#DelimChars} 1)]}
                }
        }

        (( ${Visible[1]} )) && {
                print -R "${(V)Delim}"
        } || {
                print -- "${Delim}"
        }
}

#:<<-"Examples.@delimiter:generate"
        @delimiter:generate
        @delimiter:generate -v
        @delimiter:generate {a..d}
        @delimiter:generate {a..d} -l 3 -sm a
        @delimiter:generate {a..d} -l 13
        @delimiter:generate {a..d} -- {b..d} -l 13
        @delimiter:generate -l 13 ${(us..):-"Hello World"} -sm "Hello World"
        @delimiter:generate ${(us..):-"Hello World"} -sm "Hello World"
        @delimiter:generate ${(us..):-"Hello World"} -- elord -sm "Hello World"
#Examples.@delimiter:generate
