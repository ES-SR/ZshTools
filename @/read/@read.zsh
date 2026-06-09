
function @read {
	emulate -L zsh; setopt extendedglob typesetsilent
	if ! [[ -p /dev/stdin ]] { return 1 }

	@args:parse MaxEmptyReads:1 Timeout:1 OutDelimiter:+ InDelimiter:+
	set -- "${(@)ParsedArgv}"

	local -F Timeout=${${Timeout[1]}:-0.2}

	local -a InDelims=( "${(@)${(@)InDelimiter:-${(@)argv}}:#}" )
	(( ${#InDelims} )) || InDelims=( "{}" )
	local -a OutDelims=( "${(@)OutDelimiter}" )
	OutDelims=( "${(@)OutDelims:#}" )
	(( ${#OutDelims} )) || OutDelims=( "{} " )
	local -A Delims=( "${(@)InDelims:^^OutDelims}" )
	local -A StarDelims=( "${(@)${(@)InDelims//(#m)(*)/"*${MATCH}*"}:^^OutDelims}" )

	local -i2 GrpBase=${#InDelims}
	local -i GrpWidth=${(c)#GrpBase}

	local -i RegionCount=${${MaxEmptyReads[1]}:-4}
	local -i RegionSize=$(( (60. - RegionCount) / RegionCount ))

	local -i2 LevelMask=$(( 2**RegionCount - 1 ))
	local -i2 RegionMask=$(( 2**RegionSize - 1 ))

	local -a RegionOffsets=(0 {$RegionCount..$(( RegionSize*RegionCount - 1 ))..$RegionSize})
	local -a RegionOffsetIdxs=(0)

	local -i2 FullDecayMask=0 M=0
	local -i R
	for R ( {1..$RegionCount} ) {
		RegionOffsetIdxs+=( $(( M = (M << 1) + 1 )) )

		(( FullDecayMask |= (RegionMask >> 1) << RegionOffsets[R] ))
	}

	local -a Buffer=()
	local -i2 ReadState=0 LevelBits RegionBits NewLevelBits
	local -i RegionOffsetIdx RegionOffset

	while (( ReadState >= 0 )) {
		(( LevelBits = ReadState & LevelMask ))
		RegionOffsetIdx=$RegionOffsetIdxs[(I)$(( LevelBits ))]
		(( RegionOffset = RegionOffsets[RegionOffsetIdx] ))
		(( RegionBits = ( ( ReadState & ( ~ LevelMask ) ) & ( RegionMask << RegionOffset ) ) >> RegionOffset ))

		local Char=""; local -i ReadRes=1
		IFS= read -u 0 -t ${Timeout} -k 1 -rs Char
		(( ReadRes = $? ))

		(( ReadRes )) && {
			(( NewLevelBits = LevelBits << 1 | 1 ))
		} || {
			(( NewLevelBits = 0 ))

			(( RegionOffsetIdx )) && {
				(( ReadState = (ReadState >> 1) & (FullDecayMask ^ (RegionMask << RegionOffset)) ))
			} || {
				(( ReadState = (ReadState >> 1) & FullDecayMask ))
			}
			(( ReadState |= ( ( RegionBits << 1 | 1 ) & RegionMask ) << RegionOffset ))

			Buffer+=("${Char}")
			local BuffStr="${(j..)Buffer}"
			local -a MatchStarts=()
			local ID="" FirstID="" FirstDelim=""

			while {
				MatchStarts=()
				for ID ( ${(@)${(@)${(@k)StarDelims[(K)${BuffStr}]}#\*}%\*} ) {
					: "${BuffStr/(#m)${~ID}/${MatchStarts[$(( MBEGIN << GrpWidth | ${InDelims[(ie)${ID}]} ))]::="${(q+)ID}"}}"
				}
				(( ${#MatchStarts} ))
			} {
				FirstID="${(Q)${MatchStarts[(r)?*]}}"
				FirstDelim="${(M)BuffStr#*${~FirstID}}"
				[[ -n ${FirstDelim} ]] || { break }
				BuffStr="${BuffStr#*${~FirstID}}"
				print -nr -- "${FirstDelim/(#m)${~FirstID}/"${Delims[${FirstID}]//\{\{*\}\}/${MATCH}}"}"
			}
			Buffer=(${(s..)BuffStr})
		}

		(( NewLevelBits > LevelMask )) && {
			(( ReadState = ~ ReadState ))
		} || {
			(( ReadState = ( ReadState & ( ~ LevelMask ) ) | ( NewLevelBits & LevelMask ) ))
		}
	}
	##common pattern i use
	#print -nr -- ${Buffer:+"${(j..)Buffer}"$'\n'}
	##allows print -n like in the example to prevent a new line in the output
	print -nr -- ${Buffer:+"${(j..)Buffer}"}
}

: <<"Examples.@read"
	() {
		{
		#	set -x
			print -nl -- {} hello {} world | @read outdelimiter '<{}>'
			print
			print -- a1b2c3 | @read -ID '<->' '[a-z]' -OD '({{}})' '[{{}}]'
		} always {
			set +x
		}
	}
Examples.@read
