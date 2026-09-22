

function __@args:parse:v2 {
	emulate -LR zsh -o extendedglob -o typesetsilent
	{ # set -x
	
	local -a Specs=("${(@)argv[2,-1]}") FlagNames FlagMaxExtracts FlagPatterns
	local Spec
	for Spec ("${(@)Specs}") {
  	local -a SpecParts=("${(@s.:.)Spec}")

    local MaxExtracts="${${(M)Spec%:${~:-"(+|<->)"}}#:}"
    SpecParts=(${SpecParts:#$MaxExtracts})
    MaxExtracts=${MaxExtracts:-0}

		local Name=${SpecParts[-1]}
    SpecParts[-1]=()

    local Pattern=${${(j.:.)SpecParts}:-$(@args:parse:v2:generatePattern "${Name}")}

    Name="${${${${${Name//,*\//}//\/*./}//[.\/]/}//[^-[:alnum:]]/}//-/_}"

    FlagNames+=("${Name}")
    FlagPatterns+=("${Pattern}")
    FlagMaxExtracts+=(${MaxExtracts})

    local -a "${Name}"
    (( ${MaxExtracts/+/1} )) || {
    	set -A "${Name}" 0
    }
  }

  set -- "${(@P)1}"

  local MetaPat="${(j.|.)FlagPatterns}"

  local -i Idx
  local -a PositionalArgs FlagInfo=(${"${(@)FlagInfo}":-})
  while (( ${Idx::=${argv[(I)${~MetaPat}]}} )) {
    argv[$Idx]=("${${argv[$Idx]}%%=*}" ${"${${(M)${argv[$Idx]}%%=*}#=}":-})
    local RawFlag="${argv[$Idx]}"
    local FNIdx=${FlagPatterns//(#m)*/${${${RawFlag}[(r)${~MATCH},(R)${~MATCH}]}:+${FlagPatterns[(ie)$MATCH]}}}
    local FlagName="${FlagNames[$FNIdx]}"
    local MaxExtract="${${FlagMaxExtracts[$FNIdx]}/+/${ARGC}}"
    set -A FlagInfo "${FlagName}:${Idx}:${RawFlag}" "${(@)FlagInfo}"
    set -A "${FlagName}" "${(@)argv[$((Idx+1)),$((Idx + MaxExtract))]}" "${(@P)FlagName}"
    (( MaxExtract )) || {
    	set -A "${FlagName}" $(( "${(P)FlagName:-0}" + 1 ))
    }
    set -A PositionalArgs  "${(@)argv[$((Idx+1+MaxExtract)),-1]}" "${(@)PositionalArgs}"
    argv[$Idx,-1]=()
  }

  set -A PositionalArgs "${(@)argv}" "${(@)PositionalArgs}"

  local FN
  for FN ($FlagNames PositionalArgs FlagInfo) {
  	typeset -p1 -- ${FN}
  }

} always {
        set +x
}
}

function __@args:parse:v2:bridge {
	print -r -- 'eval "$(__@args:parse:v2 __ArgsParseArgv "${(@)argv}")"' 
}

alias @args:parse:v2='local -a __ArgsParseArgv=("${(@)argv}"); . <(__@args:parse:v2:bridge)'

function @args:parse:v2:generatePattern {
        emulate -LR zsh -o extendedglob -o typesetsilent

        (( ARGC )) || return 1
        (( ARGC == 1 )) && [[ $1 = (-|--)(#i)(h(elp|)) ]] && {
                <<-"EOF"
                        . the following segment is optional
                        , the following preceding segment is an alternate
                        / the following segment is applied to the end of each preceding segment
                EOF
        return
        }     
        
        local Arg
        for Arg {                                                                             
                # 1. Normalize camelCase into required word boundaries (FileDest -> File-Dest)
                local SpecNorm="${Arg//(#b)([a-z0-9])([A-Z])/$match[1]-$match[2]}"
                                                     
                # 2. Split into required words on '-'
                local -a Words=(${(s.-.)SpecNorm})
                local -a LongWordPats=()
                local -a ShortChars=()

                local Word                                                     
                for Word ( "${(@)Words}" ) {
                        # Short flag anchor: first letter of required word stem
                        ShortChars+=( "${${Word/[^[:alnum:]]/}[1]}" )
          
                        # Split word into optional segments on '.'
                        local -a Segs=( ${(s:.:)Word} )
                        local -a Stems=() Slashes=() Alts=()

                        # Parse individual segment DSL structures
                        local Seg                             
                        for Seg  ( "${(@)Segs}" ) {                     
                                if [[ "$Seg" = *","* ]] { 
                                        # Handle Stem,Alt1/Alt2 syntax (e.g., ector,y/ies)
                                        local Stem="${Seg%%,*}"   
                                        local Rest="${Seg#*,}" 
                                        local -a AltList=(${(s./.)Rest})
                                        Stems+=("${Stem}")    
                                        Slashes+=("")
                                        Alts+=("${(j.|.)AltList}")
                                } elif [[ "${Seg}" = *"/"* ]] {
                                        # Handle Stem/Slash syntax (e.g., Dir/s)
                                        Stems+=("${Seg%%/*}")
                                        Slashes+=("${Seg#*/}")
                                        Alts+=("")
                                } else {
                                        Stems+=("${Seg}")                              
                                        Slashes+=("")
                                        Alts+=("")
                                }                        
                        }                                     

                        # Pass 1: Backward propagation of slashes to preceding segments
                        local CurrSlash=""                     
                        local -i I                  
                        for (( I=${#Segs}; I>=1; I-- )) {
                                if [[ -n "${Slashes[$I]}" ]] {    
                                        CurrSlash="${Slashes[$I]}"
                                } elif [[ -n "${Alts[$I]}" ]] {
                                        CurrSlash=""
                                } else {                                     
                                        Slashes[$I]="${CurrSlash}"
                                }                        
                        }                                

                        # Pass 2: Right-to-left nested group pattern assembly
                        local WordPat=""               
                        for (( I=${#Segs}; I>=1; I-- )) {
                                local Stem="${Stems[$I]}"
                                local Slash="${Slashes[$I]}"                     
                                local Alt="${Alts[$I]}"

                                local SegPat="${Stem}"  
                                [[ -n "${Alt}" ]] && { SegPat="${Stem}(${Alt})" }

                                if (( I == ${#Segs} )) {           
                                        if [[ -n "${Alt}" ]] {      
                                                WordPat="${SegPat}"         
                                        } elif [[ -n "${Slash}" ]] {
                                                WordPat="${Stem}(${Slash}|)"
                                        } else {
                                                WordPat="${SegPat}"
                                        }                                                  
                                } else {
                                        WordPat="${SegPat}(${Slash:+${Slash}|}${WordPat}|)"
                                }
                        }                           

                        LongWordPats+=("${WordPat}")
                }

                # 3. Combine long forms and short forms
                local PartJoint="([-_.]|)"
                local LongPattern="${(pj.$PartJoint.)LongWordPats}"
                local ShortPattern="${(pj.$PartJoint.)ShortChars}"

                local FullPattern=""
                if ! [[ "${LongPattern}" = "${ShortPattern}" ]] {
                        FullPattern="((-|--|)${LongPattern})|((-|--)${ShortPattern})"
                } else {
                        FullPattern="(-|--)${LongPattern}"
                }

                # Wrap in Zsh string anchors, case insensitivity, and optional assignment matching
                print -r -- "(#s)(#i)(${FullPattern})(=*|)(#e)"
        }
}


: <<"Examples.@args:parse:v2"
	function test@args:parse:testFunction {
    	@args:parse:v2 --:NotOpts:+
        set -- "${(@)PositionalArgs}"

        @args:parse:v2 Help Debug:1 Verbose:+ --my-spec:MySpec:3 FileDir/s.ector,y/ies:+ UnusedFlag

        print -Pl -- "%UHelp%u" "${(@)Help}" \
                "%UDebug%u" "${(@)Debug}" \    
                "%UVerbose%u" "${(@)Verbose}" \
                "%UUnusedFlag%u" "${(@)UnusedFlag}" \
                "%UMySpec%u" "${(@)MySpec}" \                  
                "%UNotOpts%u" "${(@)NotOpts}" \              
                "%UFileDirectories%u" "${(@)FileDirectories}" \
                "%UPositionalArgs%u" "${(@)PositionalArgs}" \
                "%UFlagInfo%u" "${(@)FlagInfo}"
                              
	}                                                                                               
	test@args:parse:testFunction \                                   
        one --my-spec 1 2 3 4 -h debug=hello=world --help --V "many words" before another flag \
        FileDirs {a..d} FileDirectory fd FileDirectories {A..D} \            
        -D verbose second VerboseFlag occurance values help \
        -- these verbose "not-opts" have other flag names" like debug mixed in
Examples.@args:parse:v2
