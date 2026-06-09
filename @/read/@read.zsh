
function @read {
	emulate -L zsh; setopt extendedglob typesetsilent
	if ! [[ -p /dev/stdin ]] { return 1 }

	@args:parse MaxEmptyReads:1 Timeout:1 OutDelimiter:+ InDelimiter:+
	set -- "${(@)Argv}"

	local -F Timeout=${${Timeout[1]}:-0.2}

	local -a InDelims=( "${(@)${(@)InDelimiter:-${(@)argv}}:#}" )
	(( ${#InDelims} )) || InDelims=( "{}" )
	local -a OutDelims=( "${(@)OutDelimiter}" )
	OutDelims=( "${(@)OutDelims:#}" )
	(( ${#OutDelims} )) || OutDelims=( "{}" )
	local -A Delims=( "${(@)InDelims:^^OutDelims}" )
	local -A StarDelims=( "${(@)${(@)InDelims//(#m)(*)/"*${MATCH}*"}:^^OutDelims}" )

	local -i2 GrpBase=${#InDelims}
	local -i GrpWidth=${(c)#GrpBase}

	local -i RegionCount=${${MaxEmptyReads[1]}:-4}
	local -i RegionSize=$(( (60. - RegionCount) / RegionCount > 1 ? (60. - RegionCount) / RegionCount : 1 ))

	local -i2 LevelMask=$(( 2**RegionCount - 1 ))
	local -i2 CounterUnit=$(( 2**(RegionSize - 1) - 1 ))
	local -i2 RegionComb=$(( (2**(RegionSize * RegionCount) - 1) / (2**RegionSize - 1) ))
	local -i2 CounterMasks=$(( RegionComb * CounterUnit << RegionCount ))
	local -i2 MarkerMask=$(( RegionComb << (RegionCount + RegionSize - 1) ))

	local -a LevelKeys=( {1..$RegionCount} )
	LevelKeys=( ${(@)LevelKeys//(#m)*/$(( 2**MATCH - 1 ))} )

	local BuffStr="" ID=""
	local -a MatchStarts=() MatchEnds=() DelimGroupIDs=()
	local -i2 ReadState=0 LevelBits NewLevelBits Marker Hist ProtectMask
	local -i RegionIdx RegionOffset GID FirstIdx MBegin MEnd

	while (( ReadState >= 0 )) {
		local Char=""; local -i ReadRes=1
		IFS= read -u 0 -t ${Timeout} -k 1 -rs Char
		(( ReadRes = $? ))

		(( LevelBits = ReadState & LevelMask ))
		(( ReadRes )) && {
			(( ReadState = (NewLevelBits = LevelBits << 1 | 1) > LevelMask ? ~ ReadState : ReadState & ~ LevelMask | NewLevelBits ))
			continue
		}

		RegionIdx=$LevelKeys[(I)$(( LevelBits ))]
		((
			RegionOffset = RegionCount + (RegionIdx - 1) * RegionSize,
			Marker = ReadState & MarkerMask,
			Hist = ReadState & CounterMasks,
			ProtectMask = RegionIdx ? CounterUnit << RegionOffset : (Marker >> (RegionSize - 1)) * CounterUnit,
			ReadState = ((Hist & ~ ProtectMask) >> 1) & CounterMasks
				| Hist & ProtectMask
				| (RegionIdx ? ((((Hist >> RegionOffset) & CounterUnit) << 1 | 1) & CounterUnit) << RegionOffset
					| 1 << (RegionOffset + RegionSize - 1)
					: Marker)
		))

		BuffStr+="${Char}"

		while {
			MatchStarts=() MatchEnds=() DelimGroupIDs=()
			: "${(@)${(@)${(@)${(@k)StarDelims[(K)${BuffStr}]}#\*}%\*}//(#m)*/${ID::="${MATCH}"}${GID::="${InDelims[(ie)${ID}]}"}${ID:+${BuffStr//(#m)${~ID}/${MBEGIN:+${MatchStarts[$(( MBEGIN << GrpWidth | GID ))]::="${MBEGIN}"}${MatchEnds[$(( MBEGIN << GrpWidth | GID ))]::="${MEND}"}${DelimGroupIDs[$(( MBEGIN << GrpWidth | GID ))]::="${GID}"}}}}}"
			(( ${#MatchStarts} ))
		} {
			FirstIdx=${MatchStarts[(i)?*]}
			(( MBegin = MatchStarts[FirstIdx], MEnd = MatchEnds[FirstIdx], GID = DelimGroupIDs[FirstIdx] ))
			(( MEnd >= MBegin )) || { break }
			print -nr -- "${BuffStr[1,MBegin-1]}${Delims[${InDelims[GID]}]//\{\{*\}\}/${BuffStr[MBegin,MEnd]}}"
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
			print -- 'one,two;three' | @read ',' ';'
		} always {
			set +x
		}
	}
Examples.@read
