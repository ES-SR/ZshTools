#!/bin/zsh
##  @args:parse

function __@tree:unpack:toArray {
        local AAName=${1:?}
        local Key=${2:?}
        declare -H __${AAName}__${Key}__Str="${${(P)AAName}[$Key]}"
        declare -Ha __${AAName}__${Key}
        typeset -T __${AAName}__${Key}__Str __${AAName}__${Key}
        typeset -p __${AAName}__${Key}
}

function @tree:new {
        local AAName=${1:?}
        for K ( ${(Pk)AAName} ) {
                eval \
                        "function ${AAName}:${K} {
                                eval \$(__@tree:unpack:toArray ${AAName} ${K})
                                print -l - \$__${AAName}__${K}
                        }"
        }
}

function @args:parse:generatePattern {
        local FlagName="${${1:?}//-/_}"
        if [[ ${(c)#${(*)FlagName//[^a-zA-Z0-9]/}} -lt 1 ]] {
                return 1
        }

        local ShortName=${(*j..)=${(s._.)FlagName}//(#m)(*)/${MATCH[1]}}

        local LongPattern="((-|--|)${(j.(-|).)${(s._.)=FlagName}})|"
        if [[ ${(c)#FlagName} -le 1 ]] {
                LongPattern=""
        }

        local ShortPattern="((-|--)${ShortName})"
        local FullPattern="(#i)${LongPattern}${ShortPattern}"

        print - $FullPattern
}

function @args:parse:flagspecs {
        (( $# )) || { return 1 }
        local -a Specs=( "$@" )
        local -aU Positions=( {1..$#} )
        local -A Positions_Specs=( ${Positions:^Specs} )

        local -A Specs_Patterns

        for I ( ${Positions} ) {
                Spec=${Positions_Specs[${I}]}
                FlagName="${(*)${(*R)Spec##+*+}%=*}"
                FlagPattern="${${${(*M)Spec##+*+}//+(#b)(*)+/${match}}:-$(@args:parse:generatePattern ${FlagName})}"
                MaxValues="${${(*M)Spec%%=*}/=/}"
                Specs_Patterns[$I]="${FlagName}:${FlagPattern}:${MaxValues}"
        }

        typeset -p Specs_Patterns
}

function __@args:parse {
        declare ArgsStr="${(j.:.)${(z@)1}}"
        declare -a Args
        declare -T ArgsStr Args
        declare SpecsStr="${(j.:.)@[2,-1]}"
        declare -a Specs
        declare -T SpecsStr Specs

        eval $( @args:parse:flagspecs ${Specs} )

        @tree:new Specs_Patterns

        declare -A Specs_Str

        local -a FlagArgs=( "${(@)Args}" )
        for I ( ${(-Ok)Specs_Patterns} ) {
                unset ${${(A)=$(Specs_Patterns:${I})}[1]} >/dev/null
                Specs_Str[${${(A)=$(Specs_Patterns:${I})}[1]}]=$Specs_Patterns[$I]
                FlagArgs=( ${(*)FlagArgs:/${~:-"${${(A)=$(Specs_Patterns:${I})}[2]}"}/$'\0'${${(A)=$(Specs_Patterns:${I})}[1]}} )
        }

        local argv=( )
        : ${(AF)Arrays::=${(0)FlagArgs}}
        (( $#Arrays )) && {
                (( ${+Specs_Str[${${(A)=${(z)${Arrays[1]}}}[1]}]} )) || {
                        argv+=( ${(A)=${(z)${Arrays[1]}}} )
                        Arrays=( ${Arrays[2,-1]} )
                }
        }
        local -A Counts
        for A ( ${Arrays} ) {
                : ${(A)Arr::=${(z)A}}
                local MaxVal=${${${(A)${(s.:.)Specs_Str[${Arr[1]}]}}[3]//'*'/$(( $#Arr - 1 ))}:-$(( -1 ))}
                (( MaxVal = MaxVal + 1 < $#Arr ? MaxVal + 1 : $#Arr ))
                local FlagArrName="${Arr[1]}"
                local Elements=( ${Arr[2,$(( MaxVal ))]} )
                (( Counts[$FlagArrName]+=1 ))
                local Count=${Counts[${FlagArrName}]}
                local Remove=( ${FlagArrName} ${Elements} )
                argv+=( ${Arr:|Remove} )
                printf "%s=( %s )\n" "${FlagArrName}" "${${Elements}:-${Count}}"
        }
        typeset -p argv
}
alias @args:parse="__@args:parse \"\${argv}\""


:<<-"Test.Output"
	% #functions -T __@args:parse
		unset TestArgs;
		TestArgs=(  -V value -d 1 2 log.file Debug  --verbose )
		@print:pel:cascade " No Specs "
		__@args:parse "${TestArgs}"

		@print:pel:cascade " verbose "
		__@args:parse "${TestArgs}" verbose

		@print:pel:cascade " verbose debug "
		__@args:parse "${TestArgs}" verbose debug

		@print:pel:cascade " +-V(alue|)+value=1 verbose debug=3 "
		__@args:parse "${TestArgs}" +-V(alue|)+value=1 verbose debug=3
	> ...............................................  No Specs  ...............................................
	> typeset -a argv=( -V value -d 1 2 log.file Debug --verbose )
	> ................................................  verbose  ...............................................
	> verbose=( 1 )
	> typeset -a argv=( -V value -d 1 2 log.file Debug )
	> .............................................  verbose debug  ............................................
	> debug=( 1 )
	> debug=( 2 )
	> verbose=( 1 )
	> typeset -a argv=( -V value 1 2 log.file )
	> ................................ +- +-V(alue|)+value=1 verbose debug=3  +-................................
	> value=( value )
	> debug=( 1 2 log.file )
	> debug=( 2 )
	> verbose=( 1 )
	> typeset -a argv=(  )
Enterprise%
