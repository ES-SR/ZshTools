function @term:cursor:getPosition {
        emulate -L zsh

        local -h OriginalSTTY
        OriginalSTTY="$(stty -g)"
{
        stty raw -echo min 0 time 2

        tput u7 > $TTY

        local -a CPos
        IFS='[;' read -rsd R -A CPos
        CPos=( ${CPos[2,3]} )
} always {
        stty "${OriginalSTTY}" 2>/dev/null
}
        # because they are not declared before use and assigned with ::= CLine and CCol are made global
        : ${(A)CLine::=${(j:,:)CPos[1]}}
        : ${(A)CCol::=${(j:,:)CPos[2]}}
        local -a Output=( ${${(s..)${@//-/}}// /} )

        (( $#Output )) && {
                (( ${Output[(I)l]} )) && { Output[${Output[(i)l]}]=$CLine }
                (( ${Output[(I)c]} )) && { Output[${Output[(i)c]}]=$CCol }
                print -- ${(j.,.)Output}
        }
}

<<-"EXAMPLES"
        @term:cursor:getPosition
        @term:cursor:getPosition l
        @term:cursor:getPosition c
        @term:cursor:getPosition cl
        @term:cursor:getPosition lc
        @term:cursor:getPosition -lc
        @term:cursor:getPosition -l -c
        @term:cursor:getPosition -l
        print -P - "%B%S${(%l:((COLUMNS/2))::-:: :r:((COLUMNS/2))::-:: :):-$(@term:cursor:getPosition l)}%s%b"
        print -P - "%B%S${(%l:((COLUMNS/2))::-:: :r:((COLUMNS/2))::-:: :):-$(@term:cursor:getPosition lc)}%s%b"
        print -P - "%B%S${(%l:((COLUMNS/2))::-:: :r:((COLUMNS/2))::-:: :):-$(@term:cursor:getPosition l)}%s%b"
        print -P - "%B%S${(%l:((COLUMNS/2))::-:: :r:((COLUMNS/2))::-:: :):-$(@term:cursor:getPosition l)}%s%b"
        () {
                @term:cursor:getPosition
                print -n -- $CCol
                tput cuf 10
                @term:cursor:getPosition
                print -n -- $CCol
                tput cuf 10
                @term:cursor:getPosition
                print -n -- $CCol
                tput cuf 10
                @term:cursor:getPosition
                print -- $CCol
        }
EXAMPLES
