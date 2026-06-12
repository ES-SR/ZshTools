
function @read {
	emulate -L zsh; setopt extendedglob typesetsilent
	if ! [[ -p /dev/stdin ]] { return 1 }

	local MER MBS TO
	@args:parse MaxEmptyReads:1 MaxBufferSize:1 Timeout:1 '-[abcCDfilmnNoOPRrsSuXxz](*|)':PrintOptsIdxs
	MER=${MaxEmptyReads:-5}
	MBS=${MaxBufferSize:-255}
	TO=${Timeout:-.9}

	local -a PrintOpts=("${(@)PrintOptsIdxs//(#m)*/${(P)MATCH}}")

	local -F BaseTimeout=${TO}
	local -F Timeout=${BaseTimeout}

	declare -T __Groups="[[:IFS:]] {}" Groups ,
	set +A Groups ${(s.,.)${Argv// , /,}//${(q+)MATCH}/}

	local -a InDelims=() OutDelims=()
	local -A StarDelims=()
	local Grp I=0
	for Grp ( ${Groups} ) {
		(( ++I ))
		InDelims[$I]="(${(j.|.)${(A)=Grp}[1,-2]})"
		OutDelims[$I]="${${(A)=Grp}[-1]}"
		StarDelims+=( "*(${(j.|.)${(A)=Grp}[1,-2]})*" "$I" )
	}
	local -i ShiftWidth=${(c)#$(( [##2] I ))}

	local -i RegionCount=${MER}
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

	local BuffStr="" ID="" MB="" ME=""
	local -T __Idxs="" Idxs
	local -i2 ReadState=0 LevelBits NewLevelBits Marker Hist ProtectMask DG
	local -i RegionIdx RegionOffset HistCount Idx FirstIdx

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
			continue
		}

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

		while {
			local -a Starts=() Ends=() DelimGrps=() Lens=() Content=()
			__Idxs=""
			: "${(@)StarDelims[(K)${BuffStr}]//(#m)*/${DG::=${MATCH}}${ID::=${InDelims[$DG]}}${ID:+${BuffStr//(#m)${~ID}/${MATCH:+${MB::=$(( MBEGIN ))}${ME::=$(( MEND ))}${Idx::=$(( (MB << ShiftWidth) | DG ))}${Starts[$Idx]::=${MB}}${Ends[$Idx]::=${ME}}${DelimGrps[$Idx]::=${DG}}${Lens[$Idx]::=$(( ME - MB ))}${Content[$Idx]::="${MATCH}"}${__Idxs::=${__Idxs:+${__Idxs}:}${Idx}}}}}}"
			(( ${#Starts} ))
		} {
			FirstIdx=${Starts[(i)?*]}
			(( MB = Starts[FirstIdx], ME = Ends[FirstIdx], DG = DelimGrps[FirstIdx] ))
			(( ME >= MB )) || { break }
			(( ME < ${#BuffStr} || ${#BuffStr} >= MBS )) || { break }
			print -n ${(z)=PrintOpts} -- "${BuffStr[1,MB-1]}${OutDelims[$DG]//\{\{*\}\}/${Content[$FirstIdx]}}"
			BuffStr="${BuffStr[ME+1,-1]}"
		}
	}

	(( ${#BuffStr} )) && {
		print ${(z)PrintOpts} -- "${BuffStr}"
	}
}

: <<"Examples.@read"
	() {
		{
		#	set -x
			print -- a1b2c3 | @read -n '<->' '({{}})' , '[a-z]' '[{{}}]'
			print
			print -- 'Some (432) input TO 23321 read.' | @read '[[:digit:]][[:digit:]]#' '<N:{{}}>' , '[[:punct:]][[:punct:]]#' '<P>'
			print -- 'one,two;three' | @read ',' ';' '|'
			print -- words split on whitespace | @read
		} always {
			set +x
		}
	}
Examples.@read
