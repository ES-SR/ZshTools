# @read — feature parts (assembly reference)

Each section is a feature you developed and tested separately in the conversation,
kept as the verbatim snippet you submitted. The three supporting functions are
already committed as their own files; the rest are the in-conversation parts to
assemble into `@read`.

---

## Committed supporting functions

- `@/delimiter/generate/@delimiter:generate.zsh` — generates a collision-safe
  delimiter from a control/unicode-space pool; `-sm <text>` keeps it absent from
  the given text, positional args set the pool, `++`/`--` add/remove pool chars,
  `-V` prints the visible (escape-text) form.
- `@/numbers/random/range/@numbers:random:range.zsh` — `Low,High Count` random
  ints in range (low bound applied in the modulo, open-ended halves allowed),
  one per line.
- `@/numbers/featureScale/@numbers:featureScale.zsh` — normalize values into a
  range; `0.01,0.99 {0..N}` used to scale the timeout exponent; `-` reverses.
- `@/read/sporadic/@read:sporadic.zsh` — random-pacing re-emitter, used as the
  test harness for the read loop.

---

## 1. Combined index as a UUID across parallel arrays

The match's `(MB << ShiftWidth) | DG` value is its UUID; arrays are keyed by it,
and numeric-sorting the index list gives position order because `MB` is in the
high bits (`ShiftWidth` from the base-2 width of the group count).

```zsh
declare -a StartIdxs=($DecArr)
declare -a DelimGrpIds=($BinArr)
declare -a MatchStarts MatchEnds MatchGrpIds
declare -i Base=${${(-O)DelimGrpIds}[1]}
declare -i I=0
for I ( $StartIdxs ) {
	declare -i J=0
	for J ( $DelimGrpIds ) {
		MatchStarts[$(( I << ${(c)#Base} | J ))]="I:${I} J:${J}"
	}
}
```

Mixed-base retrieval (decimal positions vs base-2 group ids) lets a combined or
zipped view be filtered by base prefix, and `(re)`/`[#2]` lookups stay
base-discriminating:

```zsh
declare -a CombArr=(${BinArr:^DecArr})
print -- ${(a)CombArr//2\#*/}                 # just positions
print -- ${${(a)CombArr//2\#*/}[(I)<-5>]}
print -- ${${BinArr[(re)$Lookup]}:-${BinArr[(re)$(( [#2] Lookup ))]}}
```

---

## 2. Group parsing → InDelims / OutDelims / StarDelims

Positional args form delimiter groups separated by a standalone `,`; each group
is one or more patterns sharing the trailing out-delimiter. Group ids are base-2;
`StarDelims` maps `*(pattern)*` → id for the `(K)` presence lookup. Default group
(no args) splits on IFS.

```zsh
local -a DelimGroups
(( ARGC )) || {
	set -- ${(q+s..)IFS} '{}'
}
DelimGroups=( ${(s. , .)${(q+)=argv}} )

local -a InDelims=()
local -a OutDelims=()
local -A StarDelims=()

local -i I
local Grp
for Grp ( ${DelimGroups} ) {
	(( I++ ))
	OutDelims[$(( [#2] I ))]=${(Q)${=Grp}[-1]}
	InDelims[$(( [#2]  I ))]=$'\('${(Qj.|.)${=Grp}[1,-2]}$'\)'
	StarDelims+=( $'\*\('${(Qj.|.)${=Grp}[1,-2]}$'\)\*' $(( [#2] I )) )
}
local -i ShiftWidth=${(c)#$(( [##2] I ))}
```

Default-group variant using a generated join delimiter so raw IFS characters
survive composition:

```zsh
@delimiter:generate -sm "${IFS}" | read -t1 -r Delim1
local -a Groups=("${(pj.$Delim1.)${(As..)IFS}}" $'\n' )
set +A Groups ${(@)${(s.,.)Argv}//(#m)*/${(pj.$Delim1.)${(A)=MATCH}}}
```

---

## 3. Collection expansion (canonical)

Selection (`StarDelims[(K)$Input]` → present groups) and per-group collection in
one expansion. Each match's data is assigned into the parallel arrays at its
combined-index key; `__Idxs` records insertion order.

```zsh
declare -A Starts Ends DelimGrps Lens Content Idxs
declare ID OD MB ME DG L C __Idxs
declare -T __Idxs Idxs
local -i Idx
: ${${StarDelims[(K)$Input]}//(#m)*/${DG::=$MATCH}${ID::=$InDelims[$DG]}${OD::=$OutDelims[$MATCH]} \
	${Input//(#m)${~ID}/${MB::=$((MBEGIN))} ${ME::=$((MEND))} ${L::=$((ME-MB))} ${C::="${MATCH}"} ${Idx::=$(( (MB << ShiftWidth) | DG ))} \
		${Starts[$Idx]::=$MB} ${Ends[$Idx]::=$ME} ${DelimGrps[$Idx]::=$DG} ${Lens[$Idx]::=$L} ${Content[$Idx]::=$C} ${__Idxs::=${__Idxs:+$__Idxs:}${Idx}} }}
```

Selection examples over the collected data (arbitrary, agnostic of collection):

```zsh
Idx=${Idxs[1]}                                  # first match
print 1st Row $Starts[$Idx] $Ends[$Idx] $DelimGrps[$Idx] $Lens[$Idx] $Content[$Idx] $Idx
local LongLen=${${(-O)Lens}[1]}                 # longest match
Idx=${Lens[(I)$LongLen]}
# sorted walk recovering corresponding values:
${(-)Idxs//(#m)*/ Starts $Starts[$MATCH] Ends $Ends[$MATCH] DelimGrps $DelimGrps[$MATCH] Lens $Lens[$MATCH] Content $Content[$MATCH]}
```

---

## 4. Single-expansion delimiter processing (within one expansion)

The pattern shown for staying inside one expansion: star-wrapped in-delims map to
out-delims, `(K)` finds which apply, and a single `//(#m)` pass captures
`MBEGIN`/`MEND`/`MATCH` per match.

```zsh
local InDelim1='(#s)([^0-9]#|)' OutDelim1='<' InDelim2='([^0-9][^0-9]#)' OutDelim2='' InDelim3='([[:space:]]|)(#e)' OutDelim3='>'
local -a InDelims=( "${(q+)InDelim1}" "${(q+)InDelim2}" "${(q+)InDelim3}" )
local -a OutDelims=( "${(q+)OutDelim1}" "${(q+)OutDelim2}" "${(q+)OutDelim3}" )
local -A Delims=( ${InDelims:^OutDelims} )
local -A StarDelims=( ${${InDelims//(#m)(*)/"*${(Q)MATCH}*"}:^OutDelims} )
local ID
: ${()=${${(k)StarDelims[(K)${Str}]}//\*/}//(#m)*/${ID::="${MATCH}"} ${"${${Str}//(#m)${~ID}/${MBEGIN:+${Found[$I]::="${(q+)ID} _ ${(q+)Delims[${ID}]} _ ${MBEGIN} _ ${MEND} _ ${(q+)MATCH} _ "}${I::=$((I+1))}}}"}}
```

---

## 5. Bitmask empty-read tracker with hysteresis

Per-level region counters track read history; on a successful read the region for
the current level-bit count is incremented (thermometer), other regions decay
their top bit, and the marker (reserved top bit per region) flags the last region
increased so consecutive successes don't shrink it. `ReadState < 0` ends the loop.

```zsh
function test@read {
	emulate -L zsh; setopt extendedglob typesetsilent

	local Timeout=${${1:-1.1}/(#s)1(#e)/1.1}
	local -i RegionCount=${2:-5}
	local -i RegionSize=$(( (60. - RegionCount) / RegionCount ))

	local -i2 LevelMask=$(( 2**RegionCount - 1 ))
	local -i2 RegionMask=$(( 2**RegionSize - 1 ))
	local -i2 DecayMask=$(( RegionMask >> 1 ))

	local -a RegionOffsets=(0 {$RegionCount..$(( RegionSize*RegionCount - 1 ))..$RegionSize})
	local -a RegionOffsetIdxs=(0)

	local -i2 FullDecayMask=0 M=0
	local -i R
	for R ( {1..$RegionCount} ) {
		RegionOffsetIdxs+=( $((M = (M << 1) + 1)) )
		(( FullDecayMask |= (RegionMask >> 1) << RegionOffsets[R] ))
	}

	local -a Buffer
	local -i2 ReadState=0 LevelBits RegionBits NewLevelBits NewRegionBits
	local -i RegionOffsetIdx RegionOffset

	while (( ReadState >= 0 )) {
		(( LevelBits = ReadState & LevelMask ))
		RegionOffsetIdx=$RegionOffsetIdxs[(I)$(( LevelBits ))]
		(( RegionOffset = RegionOffsets[RegionOffsetIdx] ))
		(( RegionBits = ( ( ReadState & ( ~ LevelMask ) ) & ( RegionMask << RegionOffset ) ) >> RegionOffset ))

		local Char; local -i ReadRes=1
		IFS= read -u0 -t $Timeout -k 1 -s Char
		(( ReadRes=$? ))

		(( ReadRes )) && {
			(( NewLevelBits = LevelBits << 1 | 1 ))
		} || {
			Buffer+=("${Char}")
			Char=
			(( NewLevelBits = 0 ))
			(( RegionOffsetIdx )) && {
				(( ReadState = (ReadState >> 1) & (FullDecayMask ^ (RegionMask << RegionOffset | 1 << RegionOffset)) ))
			} || {
				(( ReadState = (ReadState >> 1) & FullDecayMask ))
			}
			(( ReadState = ( ( RegionBits << 1 | 1 ) & RegionMask ) << RegionOffset ))
		}

		(( NewLevelBits > LevelMask )) && {
			(( ReadState = ~ ReadState ))
		} || {
			(( ReadState = ( ReadState & ( ~ LevelMask )) | ( NewLevelBits & LevelMask ) ))
		}
	}
	print -r -- "${(j..)Buffer}"
}
```

Region/mask setup as later refined (63-bit budget, `CounterUnit = RegionMask >> 1`,
closed-form `RegionComb`, level lookup keys):

```zsh
local -i RegionSize=$(( (63 - RegionCount) / RegionCount ))
local -i2 LevelMask RegionMask RegionComb CounterUnit CounterMasks MarkerMask
(( LevelMask = 2**RegionCount - 1 ))
(( RegionMask = 2**(RegionSize-1) - 1   , RegionComb = (2**(RegionSize * RegionCount) - 1) / (2**RegionSize - 1) ))
(( CounterUnit = RegionMask >> 1        , CounterMasks = RegionComb * CounterUnit << RegionCount ))
(( MarkerMask = RegionComb << (RegionCount + RegionSize - 1) ))

local -a LevelKeys=( $(( [#2] 0 )) ${${(e):-{1..$RegionCount}}//(#m)*/$(( [#2] 2**MATCH - 1 ))} )
local -a RegionOffsets=( {$RegionCount..$((RegionSize*RegionCount - 1))..$RegionSize} )

# level lookup must sit in its own command from the LevelBits assignment:
(( LevelBits = ReadState & LevelMask ))
(( RegionIdx = ${LevelKeys[(Ie)${LevelBits}]} ))
```

---

## 6. Dynamic timeout table

Timeout per (level region, history count); base raised to `1 - fraction` keeps it
in (0,1). The history fraction is feature-scaled because region size can exceed
the level count. Keyed by `2**LS + L` / `2*TS + TL`.

```zsh
() {
	local -i Levels=${1:-5}
	local -F Timeout=${2:-1.1}
	local LevelSize=$(( ( 60 - Levels ) / Levels ))
	local Arr=()
	local L LS
	for L ( {1..$((Levels))} ) {
		for LS ( {1..$LevelSize} ) {
			Arr[$(( 2**LS + L ))]=$(( (1.*Timeout*L/Levels) ** (1-(1.*LS/Levels)) ))
		}
	}
}
```

Formula intent: shorter timeout as failure level rises, longer as history rises —
fast decay for clean reads, patience for recurring failures with successes between
(bad network). The exponent base stays in (0,1) via `1 - (fraction 0..1)`, which
is why the history term is normalized.

---

## 7. Buffer overage / constriction

`BuffStr` capped to the buffer size; the front remainder of the array is the
overage (always ≤ chunk size in a working solution). `MaxPos = -MaxBuffSize - 1`
keeps a full buffer-size match fitting.

```zsh
local MaxPos=$(( -1*MaxBuffSize - 1 ))
...
local BuffStr="${(j..)Buffer}"
local Overage="${(j..)Buffer[1,$MaxPos]}"
```

Only what is actually output is removed from the buffer, in a single trim, using
the working string — the buffer (source of truth) is not rebuilt from it:

```zsh
local Output="${BuffStr[1,$OverageEndPos]}"
local -a NewBuffState=( "${(@s..)BuffStr#$Output}" )
```

---

## 8. Chunked reads

`-k N` reads N chars but `-t` only applies to the first; the timeout drives the
history logic, so the first char of each chunk carries the adaptive timeout and
the rest are read without it. Phased over `CS=(1 chunksize-1)`:

```zsh
local -a CS=( 1 $(( ${ChunkSize:-1} - 1 )) )
local -a Timeout=( $TO " " )
...
for (( I=0 ; ${CS[$((++I))]:-0} ; )) {        # :-0 — empty for-condition loops forever
	IFS= read -u 0 ${(ze)I:s/0//:s/1/-t "${TO}"/} -k ${CS[$I]} -rs Char
	(( ReadRes = $? && I == 1 )) && {
		# empty first read → level up → continue 2
	}
	Buffer+=( ${(s..)Char} )
}
```

---

## Notes / reserved syntax

- `,` standalone separates groups; inside a delimiter word it splits the tie join,
  so a literal comma delimiter is not directly expressible with this syntax.
- The level/history lookups use `(Ie)` exact match against base-2 key arrays;
  `${(@n)…}` sorts in plain expansion but the flag is dropped when combined with
  `//` substitution — sort the index list before the emission walk, or rely on the
  combined-index numeric order.
- `@delimiter:generate` default output is `echo -e` (escape → raw chars); `-V`
  uses `-E` for the literal form.
