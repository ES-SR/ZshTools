#!/bin/zsh
##  @args:parse


() {

function @array:toAssoc @assoc:fromArray {
        emulate -L zsh; options[extendedglob]=on

        local Name=${(k)parameters[(I)${1:?}]}
        if [[ ${(tP)Name} == "assoc"* ]] {
                shift
        } else {
                unset Name
        }
        local -A Assoc=(${${(e):-{1..$ARGC}}:^argv})
        local Output="$(typeset -p1 Assoc)"
        (( ${+Name} )) && {
                Output=${Output/Assoc/$Name}
        }
        print -- $Output
}
function @assoc:toArray @array:fromAssoc {
        emulate -L zsh; options[extendedglob]=on

        local Name=${(k)parameters[(I)${1:?}]}
        if [[ ${(tP)Name} == "array"* ]] {
                shift
        } else {
                unset Name
        }
        (( ARGC%2 )) && {
                argv+=(NULL)
                local NULL=1
        }
        local -A Assoc=("${(@)argv}")
        local -a Array=(${()=${(-k)Assoc//(#m)(*)/"${MATCH}" "${Assoc[$MATCH]}"}})
        (( NULL )) && {
                Array=(${Array/NULL/})
        }
        local Output="$(typeset -p1 Array)"
        (( $+Name )) && {
                Output=${Output/Array/$Name}
        }
        print -- $Output
}
function @arrays:indices:normalize {
        emulate -L zsh; options[extendedglob]=on

        local -i ArrSize
        if [[ ${1} == <0-> ]] {
                (( ArrSize = ${1} ))
        } elif (( ${(c)#${(k)parameters[(I)${1}]}} )) {
                ArrSize=${(P)#1}
        } else {
                return 1
        }
        shift

        local -i Idx
        for Idx ( ${(-u)argv} ) {
                (( Idx >= 0 )) && { break }
                local -i NormalizedIdx
                (( NormalizedIdx = ArrSize + 1 + Idx ))
                argv=(${argv//$Idx/$NormalizedIdx})
        }
        print -- $argv
}
function @arrays:slice {
        emulate -L zsh; options[extendedglob]=on

        local ArrayName=${1:?}
        local -a Array=("${(@P)ArrayName}")
        shift

        local Mode=${${argv[(R)(#s)(-|+|_)(#e)]}:-"+"}
        argv=(${argv:#$Mode})

        local -A Modes=(
                ['+']=""
                ['-']=": \${IdxStart::=\$(( IdxStart=IdxStart+1 ))}; : \${IdxEnd::=\$(( IdxEnd=IdxEnd+1 ))}"
                ['_']=": \${IdxStart::=\$(( IdxStart=IdxStart+1 ))}"
        )
        local Cmds=("${Modes[$Mode]}" ": \${(A)Slice::=\${Array[\$IdxStart, \$IdxEnd]}}")

        local -a argv=($(@arrays:indices:normalize $ARGC $argv))

        local I=1 IdxStart=0 Idx=""
        for Idx ( ${(-)argv} $(( ${#Array} + 1 )) ) {
                local -i IdxEnd
                (( IdxEnd = Idx - 1 ))
                local -a Slice=()
                ${(ze)Cmds}
                local Output="$(typeset -p1 Slice)"
                print ${Output/Slice/$ArrayName$IdxStart}

                (( I++ ))
                (( IdxStart = Idx ))
        }
}
function @arrays:removeIndices {
        emulate -L zsh

        local ArrayName=${1:?}
        shift
        local -a Array=("${(@P)ArrayName}")

        local -aU Indices=($(@arrays:indices:normalize $ArrayName "${(@)argv}"))
        local Idx; for Idx ( ${(O-)Indices} ) {
                Array[$Idx]=()
        }

        local Output="$(typeset -p1 Array)"
        print -- ${Output/Array/$ArrayName}
}

function @args:parse:generatePattern {
        emulate -L zsh; options[extendedglob]=on

        (( ARGC )) || { return 1 }

        local Arg; for Arg {
                local FlagName="${Arg//-/_}"
                local PartJoint="([-_]|)"
                (( ${FlagName[(I)[a-zA-Z0-9]]} )) || {
                        return 1
                }
                local -a PatternParts=(${(s._.)${FlagName//(#b)([a-z])([A-Z])/$match[1]_$match[2]}})
                local LongPattern="${(pj.$PartJoint.)PatternParts}"
                PatternParts=(${PatternParts//(#m)(*)/$MATCH[1]})
                local ShortPattern="${(pj.$PartJoint.)PatternParts}"
                local -aU Patterns=( ${LongPattern} ${ShortPattern} )
                local FullPattern=""
                (( $#Patterns > 1 )) && {
                        local Long="((-|--|)${Patterns[1]})"
                        local Short="((-|--)${Patterns[2]})"
                        FullPattern="${Long}|${Short}"
                } || {
                        FullPattern="(-|--)${Patterns}"
                }
                local FullPattern="(#s)(#i)(${FullPattern})(#e)"
                print - $FullPattern
        }
}

function @args:parse:specsParse {
        emulate -L zsh

        local -A Specs=()

        local Spec; for Spec {
                local -a SpecParts=(${(s.:.)Spec})
                local MaxVals="${${(M)Spec%:${~:-"(\*|<->)"}}#\:}"
                SpecParts=(${SpecParts:#$MaxVals})
                local Name=${SpecParts[-1]}
                SpecParts[-1]=()
                local Pattern=${${(j.:.)SpecParts}:-$(@args:parse:generatePattern $Name)}

                Specs+=(
                        [Order]="${Specs[Order]}:${Name}"
                        [${Name}]="Pattern=${(b)Pattern}:MaxVals=${MaxVals:-Null}"
                )
        }

        typeset -p1 Specs
}

function @args:parse:match {
        emulate -L zsh; options[extendedglob]=on

        local -A Assoc=()
        if [[ ${(tP)1} == "array"* ]] {
                local -a Array=(${(P)1})
                Assoc=(${${(e):-{1..${#Array}}}:^Array})
        } elif [[ ${(tP)1} == "assoc"* ]] {
                Assoc=(${(kvP)1})
        } else {
                return 1
        }
        shift

        local Pattern; for Pattern {
                local -A Matches=(${(kv)Assoc[(R)${~Pattern}]})
                print -- ${(-k)Matches//(#m)(*)/"$MATCH $Matches[$MATCH]"}
        }
}

function __@args:parse {
        emulate -L zsh; options[extendedglob]=on

        local Args=("${(z@)${(s.=.)1}}")
        shift

        local -A Specs
        eval "$(@args:parse:specsParse "${(@)argv}")"

        typeset -p1 Args
        typeset -p1 Specs

        local -A IndexedArgs
        eval "$(@array:toAssoc IndexedArgs "${(@)Args}")"

        local -A Matches=()
        local K=""; local V=""; for K V ( ${(kv)Specs} ) {
                if [[ $K == "Order" ]] { continue }
                local Name=${K}
                local Pattern=""
                local MaxVals=""
                eval "${(s.:.)V}"

                local -A SpecMatches=($(@args:parse:match IndexedArgs ${Pattern}))
                Matches+=( [${Name}]=${(j.:.)${(k)SpecMatches}} )
                local Output="$(typeset -p1 SpecMatches)"
                print ${Output/SpecMatches/$Name}
        }

        local -aU DirtyArgs=(${(zs.:.)=Matches})
        @arrays:slice Args _ "${(@)DirtyArgs}"
        eval "$(@arrays:slice Args _ ${(zs.:.)=Matches})"
        local SpecName=""; for SpecName ( ${(s.:.)Specs[Order]} ) {
                local Pattern=""
                local MaxVals=""
                eval ${(s.:.)${Specs[$SpecName]}}
                local -a SpecArr=()
                local Match=""; for Match ( ${(s.:.)Matches[$SpecName]} ) {
                        local -a PossibleArgs=(${(Pe):-"\$Args$((Match+1))"})
                        SpecArr+=( ${PossibleArgs[1,${MaxVals/\*/${#PossibleArgs}}]} )
                        DirtyArgs+=( {$Match..$((Match+${#SpecArr}))} )
                }
                local Output="$(typeset -p1 SpecArr)"
                print -- ${Output//SpecArr/$SpecName}
        }
        local -a CleanArgv=("${(@)Args}")
        eval "$(@arrays:removeIndices CleanArgv "${(@)DirtyArgs}")"
        typeset -p1 CleanArgv
}
alias @args:parse="__@args:parse \"\${argv}\" "

}

:<<"Example.@args:parse"
	() {
		emulate -L zsh
		# display the output
		Test@args:parse Debug 'Extract:*' '(-#|)(#i)C(P|)':CustomPattern FS:FullSpec:3

		# use the output
		eval "$(Test@args:parse Debug 'Extract:*' '(-#|)(#i)C(P|)':CustomPattern FS:FullSpec:3)"
		print -P -- "%F{cyan}${(l.10..-.)} ${(l.2.r.COLUMNS-13..-.. .):-"Debug"}%f"
		print -l -- ${(kv)Debug}
		print -P -- "%F{cyan}${(l.10..-.)} ${(l.3.r.COLUMNS-14..-.. .):-"Extract"}%f"
		print -l -- ${(kv)Extract}
		print -P -- "%F{cyan}${(l.10..-.)} ${(l.6.r.COLUMNS-17..-.. .):-"CustomPattern"}%f"
		print -l -- ${(kv)CustomPattern}
		print -P -- "%F{cyan}${(l.10..-.)} ${(l.4.r.COLUMNS-15..-.. .):-"FullSpec"}%f"
		print -l -- ${(kv)FullSpec}
		print -P -- "%F{cyan}${(l.10..-.)} ${(l.2.r.COLUMNS-13..-.. .):-"argv"}%f"
		print -l -- ${argv}
		print -P -- "%F{cyan}${(l.10..-.)} ${(l.4.r.COLUMNS-15..-.. .):-"CleanArgv"}%f"
		print -l -- ${CleanArgv}
	} hello -debug world Debug c -C ---C --extract some non-spec-matched args FS 4 args go here --D trailing args
Example@args:parse





: <<"DEPRECATED"
emulate zsh -c '
	autoload -Uz @tree:new 
	autoload -Uz @iterators:arrays:asIterator
	autoload -Uz __@args:parse
'

function @tree:new {
	function __@tree:unpack:toArray {
		local AAName=${1:?}
		local Key=${2:?}
		declare -H __${AAName}__${Key}__Str="${${(P)AAName}[$Key]}"
		declare -Ha __${AAName}__${Key}
		typeset -T __${AAName}__${Key}__Str __${AAName}__${Key}
		typeset -p __${AAName}__${Key}
	}

	local AAName=${1:?}
	for K ( ${(Pk)AAName} ) {
		eval \
			"function ${AAName}:${K} {
				eval \$(__@tree:unpack:toArray ${AAName} ${K})
				print -l - \$__${AAName}__${K}
			}"
	}
}


function @iterators:arrays:asIterator {
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

	local ArrayName=${1:?}
	alias "${ArrayName}:next"="@iterators:arrays:next ${ArrayName}"
	alias "${ArrayName}:previous"="@iterators:arrays:previous ${ArrayName}"
	alias "${ArrayName}:cycle:forward"="@iterators:arrays:cycle:forward ${ArrayName}"
	alias "${ArrayName}:cycle:backward"="@iterators:arrays:cycle:backward ${ArrayName}"
}

function __@args:parse {

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
	@iterators:arrays:asIterator argv
}
alias @args:parse="() { eval \$( __@args:parse \"\${argv}\" \"\$@\" ) } "
#alias -L @args:parse

} 

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
	>>	........................................................................... No Specs  ................................................................................
	typeset -a argv=( -V value -d 1 2 log.file Debug --verbose )
	...............................................................................  verbose  ................................................................................
	typeset -g -a verbose=( 1 )
	;
	typeset -a argv=( -V value -d 1 2 log.file Debug )
	..........................................................................  verbose debug  ...............................................................................
	typeset -g -a debug=( 2 )
	;
	typeset -g -a verbose=( 1 )
	;
	typeset -a argv=( -V value 1 2 log.file )
	............................................................... +- +-V(alue|)+value=1 verbose debug=3  +-..................................................................
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
DEPRECATED
