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
function __@iterators:arrays:initialize:Iterator_Indices {
        (( ${+Iterator_Indices} )) || {
                declare -HgAx Iterator_Indices
        }
}

function @iterators:arrays:next {
        local ArrayName=${1:?}
        __@iterators:arrays:initialize:Iterator_Indices
        # Use the global Iterator_Indices for this array's index
        # Increment index, wrapping around to 1 if it exceeds array length
        print -P - ${${(P)ArrayName}[(( \
                Iterator_Indices[ArrayName] = \
                        Iterator_Indices[ArrayName] + 1 > ${#${(P)ArrayName}} \
                        ? 1 \
                        : Iterator_Indices[ArrayName] + 1 \
        ))]}
}

function @iterators:arrays:previous {
        local ArrayName=${1:?}
        __@iterators:arrays:initialize:Iterator_Indices
        # Use the global Iterator_Indices for this array's index
        # Decrement index, wrapping around to array length if it goes below 1
        print -P - ${${(P)ArrayName}[(( \
                Iterator_Indices[ArrayName] = \
                        Iterator_Indices[ArrayName] - 1 < 1 \
                        ? ${#${(P)ArrayName}} \
                        : Iterator_Indices[ArrayName] - 1 \
        ))]}
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

function @iterators:arrays:cycle:forward {
        local ArrayName=${1:?}
        local -a Array=( ${(P)ArrayName} )

        eval "${ArrayName}=( $Array[2,-1] $Array[1] )"
        #print -P - ${${(P)ArrayName}[1]
}

function @iterators:arrays:cycle:backward {
        local ArrayName=${1:?}
        local -a Array=( ${(P)ArrayName} )

        eval "${ArrayName}=( $Array[-1] $Array[1,-2] )"
        #print -P - ${${(P)ArrayName}[1]}
}

function @iterators:arrays:asIterator {
        local ArrayName=${1:?}
        alias "${ArrayName}:next"="@iterators:arrays:next ${ArrayName}"
        alias "${ArrayName}:previous"="@iterators:arrays:previous ${ArrayName}"
        alias "${ArrayName}:cycle:forward"="@iterators:arrays:cycle:forward ${ArrayName}"
        alias "${ArrayName}:cycle:backward"="@iterators:arrays:cycle:backward ${ArrayName}"
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
        local -A FlagCounts
        local -aU FlagArrayNames
        for A ( ${Arrays} ) {
                : ${(A)Arr::=${(z)A}}
                local FlagArrName="${Arr[1]}"
                local -a Elements
                local MaxVal=${${${(A)${(s.:.)Specs_Str[${Arr[1]}]}}[3]//'*'/$(( $#Arr - 1 ))}:-$(( 0 ))}
                (( MaxVal )) && {
                        (( MaxVal = MaxVal + 1 < $#Arr ? MaxVal + 1 : $#Arr ))
                        Elements=( ${Arr[2,$(( MaxVal ))]} )
                        eval $( printf "%s+=( %s )\n" "${FlagArrName}" "${${Elements}:-${Count}}" )
                } || {
                        (( FlagCounts[$FlagArrName]+=1 ))
                        local Count=${FlagCounts[${FlagArrName}]}
                        eval $( printf "%s=( %s )\n" "${FlagArrName}" "${${Elements}:-${Count}}" )
                }
                local Remove=( ${FlagArrName} ${Elements} )
                argv+=( ${Arr:|Remove} )
                FlagArrayNames+=( $FlagArrName )
        }
        for F ( ${FlagArrayNames} ) {
                typeset -p ${F}
                print ";"
                @iterators:arrays:asIterator ${F}
        }
        typeset -p argv
}
alias @args:parse="() { eval \$( __@args:parse \"\${argv}\" \"\$@\" ) } "



:<<-"Test.Output"
	%
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
	>>	......................................................................................................................................................................  No Specs  ......................................................................................................................................................................
		typeset -a argv=( -V value -d 1 2 log.file Debug --verbose )
		.......................................................................................................................................................................  verbose  ......................................................................................................................................................................
		typeset -g -a verbose=( 1 )
		;
		typeset -a argv=( -V value -d 1 2 log.file Debug )
		....................................................................................................................................................................  verbose debug  ...................................................................................................................................................................
		typeset -g -a debug=( 2 )
		;
		typeset -g -a verbose=( 1 )
		;
		typeset -a argv=( -V value 1 2 log.file )
		....................................................................................................................................................... +- +-V(alue|)+value=1 verbose debug=3  +-.......................................................................................................................................................
		typeset -g -a value=( value )
		;
		typeset -g -a debug=( 1 2 log.file )
		;
		typeset -g -a verbose=( 1 )
		;
		typeset -a argv=(  )
	%	verbose:next
	>>	1
	%	verbose:next
	>>	1
	%	debug:next
	>>	2
	%	debug:next
	>>	log.file
	%	debug:next
	>>	1
	%	debug:next
	>>	2
	%	debug:previous
	>>	1
	%
Test.Output
