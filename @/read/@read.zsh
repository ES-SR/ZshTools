
function @read {
	emulate -L zsh; setopt extendedglob typesetsilent
	if ! [[ -p /dev/stdin ]] { return 1 }

	local MER MBS TO
	@args:parse MaxEmptyReads:1 MaxBufferSize:1 Timeout:1 '-[abcCDfilmnNoOPRrsSuXxz](*|)':PrintOptsIdxs
	MER=${MaxEmptyReads:-5}
	MBS=${MaxBufferSize:-255}
	TO=${Timeout:-.9}
	local -i MaxPos=$(( -MBS - 1 ))

	local -a PrintOpts=("${(@)PrintOptsIdxs//(#m)*/${(P)MATCH}}")

	local -F Timeout=${TO}

	local Delim1="" Delim2=""
	local -a DefaultGroup=("${(@s..)IFS}" "{}")
	@delimiter:generate -sm "${(q+)DefaultGroup}" | read -t1 -r Delim1
	local __DefaultGroup="${(pj.$Delim1.)DefaultGroup}"

	declare -T __Groups="${__DefaultGroup}" Groups ,
	set +A Groups ${(@)${(s.,.)Argv}//(#m)*/${(pj.$Delim1.)${(A)=MATCH}}}

	local -a InDelims=() OutDelims=()
	local -A StarDelims=()
	local Grp I=0
	for Grp ( ${Groups} ) {
		(( ++I ))
		InDelims[$I]="(${(j.|.)${(Aps.$Delim1.)Grp}[1,-2]})"
		OutDelims[$I]="${${(Aps.$Delim1.)Grp}[-1]}"
		StarDelims+=( "*(${(j.|.)${(Aps.$Delim1.)Grp}[1,-2]})*" "$I" )
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
	local -a HistKeys=( $(( [#2] 0 )) ${${(e):-{1..$RegionSize}}//(#m)*/$(( [#2] 2**MATCH - 1 ))} )
	local -a RegionOffsets=( {$RegionCount..$(( RegionSize*RegionCount - 1 ))..$RegionSize} )

	local -a TimeoutArr=()
	local -a Exponents=( ${${:-{0..$RegionSize}}//(#m)*/$(( 1. * MATCH / RegionCount ))} )
	Exponents=( $(@numbers:featureScale 0.01,0.99 ${(@)Exponents}) )
	local -i TL TS
	for TL ( {1..$RegionCount} ) {
		for TS ( {1..$RegionSize} ) {
			TimeoutArr[$(( 2*TS + TL ))]=$(( (1. * TO * (RegionCount - TL + 1) / RegionCount) ** (1 - Exponents[TS + 1]) ))
		}
	}

	local -a Buffer=()
	local BuffStr="" ID="" MB="" ME=""
	local -T __Idxs="" Idxs
	local -i2 ReadState=0 LevelBits NewLevelBits Marker Hist ProtectMask DG HistCount
	local -i RegionIdx RegionOffset Idx

	while (( ReadState >= 0 )) {
		(( LevelBits = ReadState & LevelMask ))
		((
			RegionIdx = ${LevelKeys[(Ie)${LevelBits}]} ,
			RegionOffset = RegionOffsets[RegionIdx] ,
			HistCount = (ReadState >> RegionOffset) & CounterUnit
		))
		Timeout=${TimeoutArr[$(( 2 * (${HistKeys[(Ie)${HistCount}]} - 1) + RegionIdx ))]:-${TO}}

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

		Buffer+=("${Char}")
		local Out="${(j..)Buffer[1,MaxPos]}"
		Buffer[1,MaxPos]=()
		BuffStr="${(j..)Buffer}"

		local -a Starts=() Ends=() DelimGrps=() Lens=() Content=()
		__Idxs=""
		: "${(@)StarDelims[(K)${BuffStr}]//(#m)*/${DG::=${MATCH}}${ID::=${InDelims[$DG]}}${ID:+${BuffStr//(#m)${~ID}/${MATCH:+${MB::=$(( MBEGIN ))}${ME::=$(( MEND ))}${Idx::=$(( (MB << ShiftWidth) | DG ))}${Starts[$Idx]::=${MB}}${Ends[$Idx]::=${ME}}${DelimGrps[$Idx]::=${DG}}${Lens[$Idx]::=$(( ME - MB ))}${Content[$Idx]::="${MATCH}"}${__Idxs::=${__Idxs:+${__Idxs}:}${Idx}}}}}}"

		local -i Pos=1
		: "${(@n)Idxs//(#m)*/${MATCH:+${${${:-$(( Ends[MATCH] < ${#BuffStr} || ${#BuffStr} >= MBS ))}:#0}:+${Out::=${Out}${BuffStr[Pos,Starts[MATCH]-1]}${OutDelims[$(( DelimGrps[MATCH] ))]//\{\{*\}\}/${Content[$MATCH]}}}${Pos::=$(( Ends[MATCH] + 1 ))}}}}"
		(( ${#Out} )) && {
			print -n ${(z)=PrintOpts} -- "${Out}"
			BuffStr="${BuffStr[Pos,-1]}"
			Buffer=(${(s..)BuffStr})
		}
	}

	(( ${#Buffer} )) && {
		print ${(z)PrintOpts} -- "${(j..)Buffer}"
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
