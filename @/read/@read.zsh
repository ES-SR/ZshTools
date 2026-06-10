
function @read {
	emulate -L zsh; setopt extendedglob typesetsilent
	if ! [[ -p /dev/stdin ]] { return 1 }

	@args:parse MaxEmptyReads:1 MaxBufferSize:1 Timeout:1 OutDelimiter:+ InDelimiter:+
	set -- "${(@)Argv}"
	argv=( ${(@)argv:#} )

	local -i MaxBufferSize=${${MaxBufferSize[1]}:-4096}
	local -F BaseTimeout=${${Timeout[1]}:-0.2}
	local -F Timeout=${BaseTimeout}

	local -a DelimGroups=( ${(s. , .)${argv:+${(q+)=argv}}} )
	local -i I=0
	(( ${#DelimGroups} )) || {
		local -a InD=( "${(@)InDelimiter}" ) OutD=( "${(@)OutDelimiter}" )
		InD=( "${(@)InD:#}" ) OutD=( "${(@)OutD:#}" )
		(( ${#InD} + ${#OutD} )) && {
			(( ${#InD} )) || InD=( "{}" )
			(( ${#OutD} )) || OutD=( "{}" )
			local Pat=""
			for Pat ( "${(@)InD}" ) {
				DelimGroups+=( "${(q+)Pat} ${(q+)${OutD[$(( I++ % ${#OutD} + 1 ))]}}" )
			}
		} || {
			DelimGroups=( "${(q+s..)IFS} {}" )
		}
	}

	local -a InDelims=() OutDelims=()
	local -A StarDelims=()
	local Grp=""
	I=0
	for Grp ( ${(@)DelimGroups} ) {
		(( I++ ))
		local -a GrpWords=( "${(@Q)${(z)Grp}}" )
		(( ${#GrpWords} > 1 )) || GrpWords+=( "{}" )
		InDelims[$(( [#2] I ))]="(${(j.|.)GrpWords[1,-2]})"
		OutDelims[$(( [#2] I ))]="${GrpWords[-1]}"
		StarDelims+=( "*(${(j.|.)GrpWords[1,-2]})*" "$(( [#2] I ))" )
	}
	local -i ShiftWidth=${(c)#$(( [##2] I ))}

	local -i RegionCount=${${MaxEmptyReads[1]}:-4}
	local -i RegionSize=$(( (63 - RegionCount) / RegionCount > 1 ? (63 - RegionCount) / RegionCount : 1 ))

	local -i2 LevelMask RegionMask RegionComb CounterUnit CounterMasks MarkerMask
	(( LevelMask = 2**RegionCount - 1 ))
	(( RegionMask = 2**(RegionSize - 1) - 1	, RegionComb = (2**(RegionSize * RegionCount) - 1) / (2**RegionSize - 1) ))
	(( CounterUnit = RegionMask >> 1	, CounterMasks = RegionComb * CounterUnit << RegionCount ))
	(( MarkerMask = RegionComb << (RegionCount + RegionSize - 1) ))

	local -a LevelKeys=( $(( [#2] 0 )) ${${(e):-{1..$RegionCount}}//(#m)*/$(( [#2] 2**MATCH - 1 ))} )
	local -a RegionOffsets=( {$RegionCount..$(( RegionSize*RegionCount - 1 ))..$RegionSize} )

	local -a TimeoutArr=()
	local -a Exponents=( ${${:-{0..$RegionSize}}//(#m)*/$(( 1. * MATCH / RegionCount ))} )
	Exponents=( $(@numbers:featureScale 0.01,0.99 ${(@)Exponents}) )
	local -i TL TS
	for TL ( {1..$RegionCount} ) {
		for TS ( {1..$RegionSize} ) {
			TimeoutArr[$(( 2*TS + TL ))]=$(( (1. * BaseTimeout * (RegionCount - TL + 1) / RegionCount) ** (1 - Exponents[TS + 1]) ))
		}
	}

	local BuffStr="" ID="" DG="" MB="" ME=""
	local -a Starts=() Ends=() DelimGrps=() Lens=() Content=()
	local -T __Idxs Idxs
	__Idxs=""
	local -i2 ReadState=0 LevelBits NewLevelBits Marker Hist ProtectMask GID
	local -i RegionIdx RegionOffset HistCount Idx FirstIdx MBegin MEnd Draining=0

	while (( ReadState >= 0 )) {
		(( LevelBits = ReadState & LevelMask ))
		((
			RegionIdx = ${LevelKeys[(Ie)${LevelBits}]} ,
			RegionOffset = RegionOffsets[RegionIdx] ,
			HistCount = (ReadState >> RegionOffset) & CounterUnit
		))
		Timeout=${TimeoutArr[$(( HistCount + RegionIdx ))]:-${BaseTimeout}}

		local Char=""; local -i ReadRes=1
		IFS= read -u 0 -t ${Timeout} -k 1 -rs Char
		(( ReadRes = $? ))

		(( ReadRes )) && {
			(( ReadState = (NewLevelBits = LevelBits << 1 | 1) > LevelMask ? ~ ReadState : ReadState & ~ LevelMask | NewLevelBits ))
			(( ReadState >= 0 )) && { continue }
			(( Draining = 1 ))
		} || {
			((
				Marker = ReadState & MarkerMask ,
				Hist = ReadState & CounterMasks ,
				ProtectMask = RegionOffset ? CounterUnit << RegionOffset : (Marker >> (RegionSize - 1)) * CounterUnit ,
				ReadState = ((Hist & ~ ProtectMask) >> 1) & CounterMasks
					| Hist & ProtectMask
					| (RegionOffset ? ((HistCount << 1 | 1) & CounterUnit) << RegionOffset
						| 1 << (RegionOffset + RegionSize - 1)
						: Marker)
			))

			BuffStr+="${Char}"
		}

		while {
			Starts=() Ends=() DelimGrps=() Lens=() Content=() __Idxs=""
			: "${(@)StarDelims[(K)${BuffStr}]//(#m)*/${DG::=${MATCH}}${ID::=${InDelims[$DG]}}${ID:+${BuffStr//(#m)${~ID}/${MATCH:+${MB::=$(( MBEGIN ))}${ME::=$(( MEND ))}${Idx::=$(( (MB << ShiftWidth) | DG ))}${Starts[$Idx]::=${MB}}${Ends[$Idx]::=${ME}}${DelimGrps[$Idx]::=${DG}}${Lens[$Idx]::=$(( ME - MB ))}${Content[$Idx]::="${MATCH}"}${__Idxs::=${__Idxs:+${__Idxs}:}${Idx}}}}}}"
			(( ${#Starts} ))
		} {
			FirstIdx=${Starts[(i)?*]}
			(( MBegin = Starts[FirstIdx], MEnd = Ends[FirstIdx], GID = DelimGrps[FirstIdx] ))
			(( MEnd >= MBegin )) || { break }
			(( Draining || MEnd < ${#BuffStr} || ${#BuffStr} >= MaxBufferSize )) || { break }
			print -nr -- "${BuffStr[1,MBegin-1]}${OutDelims[GID]//\{\{*\}\}/${Content[$FirstIdx]}}"
			BuffStr="${BuffStr[MEnd+1,-1]}"
		}
	}
	##common pattern i use
	#print -nr -- ${BuffStr:+"${BuffStr}"$'\n'}
	##allows print -n like in the example to prevent a new line in the output
	print -nr -- ${BuffStr:+"${BuffStr}"}
}

: <<"Examples.@read"
	() {
		{
		#	set -x
			print -nl -- {} hello {} world | @read outdelimiter '<{}>'
			print
			print -- a1b2c3 | @read -ID '<->' '[a-z]' -OD '({{}})' '[{{}}]'
			print -- 'one,two;three' | @read ',' ';' '|'
			print -- 'Some (432) input TO 23321 read.' | @read '[[:digit:]][[:digit:]]#' '<N:{{}}>' , '[[:punct:]][[:punct:]]#' '<P>'
			print -- words split on whitespace | @read
		} always {
			set +x
		}
	}
Examples.@read
