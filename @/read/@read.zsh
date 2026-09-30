function @read {
	emulate -L zsh; setopt extendedglob

	! [[ -p /dev/stdin ]] && { return 1 }
	(( ${+builtins[sysread]} )) || { zmodload zsh/system }

	local -a ReturnValueMeanings=(
		'At least one byte of data was successfully read and, if appropriate, written.'
		'There was an error in the parameters to the command.  This is the only error for which a message is printed to standard error.'
		'There was an error on the read, or on polling the input file descriptor for a timeout.  The parameter ERRNO gives the error.'
		'Data were successfully read, but there was an error writing them to outfd.  The parameter ERRNO gives the error.'
		'The attempt to read timed out.  Note this does not set ERRNO as this is not a system error.'
		'No system error occurred, but zero bytes were read.  This usually indicates end of file.  The parameters are set according to the usual rules; no write to outfd is attempted.'
	)

	# --- inline argument parser (range-based) ---------------------------------
	# EVERY arg is quoted once up front, so the whole parser runs on tokens that
	# are never empty and never split: a newline, a space, '' and ' | ' all
	# survive the index zip, the (z) splits and the index arithmetic. Args are
	# unquoted only where their VALUE is used (delimiters, flag values).
	# Flag name -> match pattern; name -> value count (+ = "rest"). Split any
	# flag=val token into two, find each flag's occurrences, expand them to the
	# argv indices each flag consumes (start .. start+count). Delimiter args are
	# argv at the indices no flag consumed; a flag's values are its consumed
	# indices minus its own start indices. Verbose takes the fd to write to.
	set -- "${(@q+)argv}"
	local -A Flags=(
		UserLogic  '--'
		EmptyReads '((-|--|)(Empty|)([-_]|)Read(s|)|(-|--)(E|)([-_]|)R)'
		ChunkSize  '((-|--|)Chunk([-_]|)(Size|)|(-|--)C([-_]|)(S|))'
		BufferSize '((-|--|)Buffer([-_]|)(Size|)|(-|--)B([-_]|)(S|))'
		Timeout    '((-|--|)Timeout|(-|--)T)'
		Verbose    '((-|--|)Verbose|(-|--)V)'
	)
	local -A FlagValCounts=( UserLogic + EmptyReads 1 ChunkSize 1 BufferSize 1 Timeout 1 Verbose 1 )

	local -A IdxdArgv=(${${:-{1..$ARGC}}:^argv})
	local AssignmentPattern="(#i)((${(j.)|(.)Flags}))(=*)"
	local -a Found=(${IdxdArgv[(R)${AssignmentPattern}]})
	# argv is already quoted, so the (z) split separates only the "flag val"
	# pair made here; ${~...} makes the found tokens a live alternation
	(( ${#Found} )) && { set -- ${(z)argv//(#m)(${~${(j.|.)Found}})/${MATCH%%=*} ${MATCH#*=}} }

	local -a ArgvIdxs=({1..$ARGC})
	IdxdArgv=(${ArgvIdxs:^argv})

	local Idxs
	local -A FoundFlags=( ${(Az)${(-k)Flags}//(#m)*/${${Idxs::=${(j.:.)${(-k)IdxdArgv[(R)(#i)(${~Flags[$MATCH]})]}}}:+${MATCH} ${Idxs}}} )

	local FlagName ValCount; local -a StartIdxs RangeIdxs
	local -A FlagRanges=( ${(Az)${(k)FoundFlags}//(#m)*/${FlagName::=$MATCH} ${${ValCount::=${FlagValCounts[$FlagName]}}:+} ${${(A)StartIdxs::=${(s.:.)FoundFlags[$FlagName]}}:+} ${(q-)RangeIdxs::=${StartIdxs//(#m)*/${(e):-{$MATCH..$((MATCH+${ValCount/+/$((ARGC-MATCH))}))}}}} } )

	local -a DirtyIdxs=(${(Qz)FlagRanges})
	ArgvIdxs=(${ArgvIdxs:|DirtyIdxs})
	local -a Args=(${ArgvIdxs//(#m)*/${IdxdArgv[$MATCH]}})

	# print options: whatever is left that spells a print flag, kept in order
	# and passed through to every output print. Taken from the LEFTOVERS rather
	# than given a Flags entry, so @read's own short forms win first -- -C and
	# -CS are ChunkSize, and only an unclaimed -C would reach print. A literal
	# -n or -l meant as a DELIMITER has to be written as a pattern that is not
	# a bare option, e.g. [-]n, the same escape hatch [,] gives the separator.
	local PrintOptPat='(#s)-[abcCDfilmnNoOPRrsSuXxz]*(#e)'
	local -a PrintOpts=( ${(@Q)${(M)Args:#${~PrintOptPat}}} )
	Args=( ${Args:#${~PrintOptPat}} )

	for FlagName ( ${(k)Flags} ) { local -a $FlagName }
	local -a ValIdxs
	for FlagName ( ${(k)FoundFlags} ) {
		RangeIdxs=( ${(Qz)FlagRanges[$FlagName]} ) ; StartIdxs=( ${(s.:.)FoundFlags[$FlagName]} )
		[[ ${FlagValCounts[$FlagName]} == 0 ]] && { ValIdxs=( $RangeIdxs ) } || { ValIdxs=( ${RangeIdxs:|StartIdxs} ) }
		set -A $FlagName "${(@Q)${(@)ValIdxs//(#m)*/${IdxdArgv[$MATCH]}}}"
	}

	# comma-separated groups: last element is the group's out-delimiter, the
	# rest are in-delimiter patterns. An EMPTY out-delimiter removes its
	# in-delimiters from the stream instead of swapping them. The separator test
	# is anchored against the QUOTED token, so only a bare , separates groups;
	# a comma meant as a delimiter is written as a pattern that is not a bare
	# comma -- [,] is the idiomatic spelling (a backslash only escapes
	# pattern-special characters, so \, stays two literal characters).
	# Each member is unquoted as it is stored, at the point its value is used.
	# Group number and member number are declaration order, fixed
	# here; each group's whole-pattern alternation (GroupDelims) is built once
	# up front, and doubles as an exact DelimGroup key so single-group G
	# patterns resolve without a scan. StarGroup maps a member's star-key to
	# its group, so a group's members are a reverse lookup.
	local -A StarDelims=() StarGroup=() DelimGroup=() DelimMember=() GroupDelims=()
	local -a OutDelims=() Group=() AllDelims=()
	local Arg Delim
	local -i MemberNum=0
	for Arg ( "${(@)Args}" , ) {
		[[ $Arg == (#s),(#e) ]] && {
			(( ${#Group} >= 2 )) && {
				OutDelims+=( "${Group[-1]}" )
				GroupDelims[${#OutDelims}]=${(j.|.)${Group[1,-2]//(#m)*/(${MATCH})}}
				AllDelims+=( ${GroupDelims[${#OutDelims}]} )
				DelimGroup[(${(j.|.)${Group[1,-2]//(#m)*/(${MATCH})}})]=${#OutDelims}
				(( MemberNum = 0 ))
				for Delim ( ${Group[1,-2]//(#m)*/(${MATCH})} ) {
					DelimGroup[$Delim]=${#OutDelims}
					DelimMember[$Delim]=$(( ++MemberNum ))
					StarDelims[*${Delim}*]=$Delim
					StarGroup[*${Delim}*]=${#OutDelims}
				}
			}
			Group=()
		} || { Group+=( "${(Q)Arg}" ) }
	}

	# selector entries drive the default choice: <S|L|E>:<slice> filters the
	# working id set by that table -- the slice (raw zsh subscript text: 1,
	# -1, 2,4) picks from the RESTRICTED sorted unique VALUE list, so a pick
	# is a whole value-class and ties never split. Every entry is a filter;
	# the survivors always resolve to their groups' patterns. The default
	# chain is the design default: the whole group of the longest match at the
	# earliest start. A slice is split into its two bounds (SliceA,SliceB)
	# because a range comma has to be literal text inside the subscript
	# brackets.
	# every declared delimiter, in declaration order, as ONE alternation. Each
	# group is already (m1)|(m2) with its members wrapped, so this is
	# ((m1)|(m2)|(m3)|(m4)) -- the order the caller wrote, which is the order
	# zsh resolves at each position.
	local AllDelimPat="(${(j.|.)AllDelims})"

	local -A TableByLetter=( S Starts L Lens E Ends )
	# -- entries REPLACE the default filter chain. They are filter specs, not
	# code: the same <S|L|E>:<slice> grammar, applied to the group phase and
	# then to the member phase. There is no DelimPat or REPLY any more --
	# consumption reads the tables, so a pattern handed back by user code has
	# nothing left to attach to.
	local -a Choices=( "${(@)UserLogic}" )
	(( ${#Choices} )) || Choices=( S:1 L:-1 )
	# The selection compiles to ONE expansion, chosen here and never inspected
	# again. (S) searches for the match starting closest to the front (# and ##)
	# or closest to the end (% and %%); of the matches at that position, the
	# single form takes the shortest and the doubled form the longest. B, E and
	# N return begin, one-past-end and length, so the pick and its position come
	# back together -- no table, no sort, no candidate list.
	#   S:1 L:1 -> #    S:1 L:-1 -> ##    S:-1 L:1 -> %    S:-1 L:-1 -> %%
	# Empty SelExpr means no specs were given: consumption takes the bulk path
	# that swaps every match in the span at once.
	local SelOp='' SelIdx='' SelExpr='' SSpec=''
	(( ${#UserLogic} )) && {
		# the S spec's SIGN chooses the operator family -- # counts matches
		# forward from the front, % counts the same matches backward from the end
		# -- and its MAGNITUDE becomes I:N:, the Nth match in that direction. The
		# L spec's sign doubles the operator: single takes the shortest match at
		# the chosen position, doubled the longest.
		SSpec=${${(M)Choices:#(#i)s:*}#?:}
		SelOp=${${SSpec:+${${SSpec%%,*}:#-*}}:+#}
		SelOp=${SelOp:-${SSpec:+%}}
		SelOp=${SelOp:-#}
		SelOp=${SelOp}${${${(M)Choices:#(#i)l:-*}:+${SelOp}}:-}
		SelIdx=${${SSpec##[-+]}%%,*}
		SelExpr='${(SBENI.'${SelIdx:-1}'.)BuffStr'${SelOp}'${~AllDelimPat}}'
	}

	local ArrName='' Slice='' SliceA='' SliceB=''

	ChunkSize[1]=${${ChunkSize[1]}:-8}
	EmptyReads[1]=${${EmptyReads[1]}:-5}
	BufferSize[1]=${${BufferSize[1]}:-4096}
	Timeout[1]=${${Timeout[1]}:-0.4}

	local -i HistSize=$((63-EmptyReads))
	local -i HistMask=$(( 2**HistSize - 1 ))
	local -i EmptyReadsMask=$(( (2**EmptyReads - 1) << HistSize ))
	local -i TimeoutHist=0

	# the timeout curve, ported from the tiered-history @read.1781416012.zsh onto
	# this two-partition register: the empty-read run decays the BASE
	# multiplicatively, which is always downward whatever Timeout is, while the
	# history run drives a BOUNDED exponent that can only pull the value toward
	# 1, never invert it. Putting the empty-read run in the exponent instead
	# (the old (Timeout*(1+HB/HistSize))**((EmptyReads+ERB)/EmptyReads)) made
	# empty reads LENGTHEN the poll for any Timeout > 1.
	#   T = (Timeout * (EmptyReads+1-ERB)/(EmptyReads+1)) ** (ExpHi - ExpSpan*HB/HistSize)
	# ERB 0..EmptyReads scales the base from 1x down to 1/(EmptyReads+1); HB
	# 0..HistSize sweeps the exponent from ExpHi down to ExpLo. The bounds are
	# @numbers:featureScale in closed form -- the source list is a linear ramp,
	# so scaling it is just the endpoints, and no subshell. ExpHi is 1 so that
	# the idle state (ERB and HB both 0, which the tiered register never had,
	# its level counter starting at 1) returns the timeout the caller asked
	# for, untransformed. ExpLo must never reach 0, which would collapse every
	# fully-decayed state to 1 second whatever Timeout is. The span between
	# them is just what the bounds leave, not a figure to preserve.
	local -F ExpLo=0.01 ExpHi=1.0
	local -F ExpSpan=$(( ExpHi - ExpLo ))

	# happy path pre-calculated: an empty read shifts a 1 into BOTH partitions,
	# so every reachable escalation state carries HistoryBits == EmptyReadBits.
	# Both partitions are always a contiguous run of 1s (grow (x<<1)|1, shrink
	# >>1, clear wholesale). TOTable[0] is the first read's timeout.
	local -A TOTable=()
	local -i EmptyReadBits=0
	for EmptyReadBits ( {0..$EmptyReads} ) { TOTable[$(( ((2**EmptyReadBits-1) << HistSize) | (2**EmptyReadBits-1) ))]=$(( (1.0*Timeout*(EmptyReads+1-EmptyReadBits)/(EmptyReads+1)) ** (ExpHi - ExpSpan*EmptyReadBits/HistSize) )) }
	local CurTimeout=${TOTable[0]}

	# verbose sink: a fresh fd dup'd from the requested one, or /dev/null, so
	# it is always ours to close; the loop prints to it unconditionally
	local -i VerboseFD=0
	(( ${#Verbose} )) && { exec {VerboseFD}>&$Verbose[1] } || { exec {VerboseFD}>/dev/null }

	# the match tables, all in dynamic scope for the (e)-evaluated selection logic:
	# MatchIds is the pristine per-iteration match set from extraction,
	# __MatchIds the working copy the filter chain seeds from it and mutates.
	# Groups and Members map each id to its parse-time group/member numbers.
	# reply/REPLY are the conventional names; @read consumes only
	# ${DelimPat:-$REPLY}.
	local -a MatchIds=() reply=()
	local -aU __MatchIds=()
	local -A Starts=() Lens=() Ends=() Texts=() InDelims=() Groups=() Members=()
	local Pattern=''

	# The match table, built in ONE pass. MBEGIN, MEND and MATCH are all live
	# per match, and the group and member fall out of the same (k) reverse
	# lookup consumption already uses -- so no walk over groups and no separate
	# scan per member. NOTHING CALLS THIS YET: consumption resolves each match
	# inline and needs no table. It is kept because filter specs (-- S:1 L:-1)
	# need it, and because it is the cheap way to get one: a single // over the
	# same alternation the swap uses.
	local MatchExtraction='${MatchNum::=1}${${BuffStr//(#m)(${~AllDelimPat})/${MATCH:+${Starts[M$MatchNum]::=$MBEGIN}${Ends[M$MatchNum]::=$MEND}${Lens[M$MatchNum]::=${#MATCH}}${Texts[M$MatchNum]::=$MATCH}${InDelims[M$MatchNum]::=${(k)DelimGroup[(K)$MATCH]}}${Groups[M$MatchNum]::=${DelimGroup[(k)$MATCH]}}${Members[M$MatchNum]::=${DelimMember[(k)$MATCH]}}${MatchIds[$MatchNum]::=M$MatchNum}${MatchNum::=$((MatchNum+1))}}}:+}'

	# loop workspace, declared once
	local -a PVals=() MVals=() MIds=() Present=() GrpStars=()
	local -i MatchNum=0 BytesRead=0 ReadReturn=0
	local Over=''
	local DelimGrp='' DelimMbr='' Head='' BuffStr='' Chunk='' SelectionOut=''
	local WinGrp='' Win='' OutDelim='' SpanEnd='' NextStart=''
	local WinPat=''
	local -a OutParts=()
	local SubMark='{{}}'
	local -a SafeEnds=() GrpStarts=()
	local -i SpanMade=0 LastEnd=0
	local -a SelInfo=()

	# the only loop: one chunked read per iteration, then three expansions
	{
		while (( TimeoutHist >= 0 )) {
			# SpanMade carries from the previous pass: while passes keep consuming
			# matches the buffer still holds resolvable delimiters, so resolve it
			# again rather than reading more input on top. A pass that consumes
			# nothing clears it, which is exactly when more input is needed. The
			# skipped read reports as a success so the register decays normally.
			Chunk='' BytesRead=0
			(( SpanMade )) && { ReadReturn=0 } || { sysread -c BytesRead -s $ChunkSize[1] -t $CurTimeout Chunk; ReadReturn=$? }
			print -u $VerboseFD -- "BytesRead: ${BytesRead}\tTO: ${CurTimeout}\tHist: ${(l.63..0.)$(( [##2] TimeoutHist ))}\tReturn: ${ReadReturn} - ${ReturnValueMeanings[ReadReturn+1]}"

			# expansion 1: register update -- an empty read shifts a 1 into both
			# partitions (an ER run past EmptyReads lands in the sign bit and ends
			# the loop); a success clears the ER run, else decays one history bit
			# -- then the NEXT read's timeout, memoized by raw register value.
			# Partition bit lengths: [##2] with one trailing 0 stripped
			# (0 -> "" -> 0, 2^k-1 -> k), riding the contiguous-run invariant.
			: ${${${ReadReturn:#0}:+${TimeoutHist::=$(( ((TimeoutHist & ~HistMask) << 1) | (2**HistSize) | ((((TimeoutHist & HistMask) << 1) | 1) & HistMask) ))}}:-${TimeoutHist::=$(( TimeoutHist & EmptyReadsMask ? TimeoutHist & HistMask : TimeoutHist >> 1 ))}}${CurTimeout::=${TOTable[$TimeoutHist]:-${TOTable[$TimeoutHist]::=$(( (1.0*Timeout*(EmptyReads+1-${#${${:-$(( [##2] (TimeoutHist & EmptyReadsMask) >> HistSize ))}%0}})/(EmptyReads+1)) ** (ExpHi - ExpSpan*${#${${:-$(( [##2] TimeoutHist & HistMask ))}%0}}/HistSize) ))}}}
			BuffStr+=$Chunk

			# expansion 2: all match metadata, consuming nothing. Present is the
			# star-keys the buffer matches; their groups (unique) are walked with
			# the group number stored first, each group's star-keys (StarGroup
			# reverse lookup, assigned so :* has a name) intersected with Present,
			# and each present member scanned over BuffStr to fill the id tables.
			# The tables are reset with plain assignments, not inside the
			# expansion: ${(A)MatchIds::=} leaves ONE empty element, not none.
			MatchIds=() __MatchIds=() Starts=() Lens=() Ends=() Texts=() InDelims=() Groups=() Members=()

			# expansion 2: extraction AND resolution in one pass. The chosen
			# logic reads the tables it just filled, may mutate BuffStr in place,
			# and leaves its choice in DelimPat (or REPLY). Both empty defers to
			# the next iteration. What the expansion yields is the verbose
			# output; :+ supplies its newline, so an empty result prints nothing.
			# Never print -l here: with no args it still prints a newline, the
			# same reason every output print is -n.
			# ONE pass. The whole declared alternation, in declaration order, is
			# matched against the span, and each match resolves to ITS OWN group
			# through DelimGroup[(k)$MATCH]. Nothing selects a group or a member
			# first: which alternative wins at a position is zsh's own rule, so
			# member order is the caller's lever again -- ([el]#|o) and (o|[el]#)
			# give different answers, exactly as they do outside @read.
			# The span still stops one character short of the buffer end, so a
			# delimiter that may still be growing is deferred to the next read.
			# ${MATCH:+} keeps a zero-width match from emitting a delimiter.
			# A match that reaches the buffer end may still be growing, so it and
			# everything after its START is held for the next read. MEND and MBEGIN
			# are live in the same pass that does the swapping, so the deferral
			# point is exact -- the old one-character reserve could not hold back a
			# variable-length run, which is why a run split across a chunk boundary
			# came out as two delimiters instead of one.
			# LastEnd is the end of the last match that does NOT reach the buffer
			# end. // scans left to right, so the final assignment wins. A match
			# touching the end may still be growing and is held for the next read;
			# no match at all leaves LastEnd 0, so nothing is consumed and the
			# buffer simply grows. This replaces the old one-character reserve,
			# which could not hold back a variable-length run -- that is why a run
			# split across a chunk boundary came out as two delimiters.
			# With specs: the compiled expansion returns the single chosen match as
			# begin, one-past-end, length. Only that match is swapped, and only up
			# to it is consumed, so the caller's selection governs each pass. It is
			# deferred if it reaches the buffer end, the same rule as the bulk path.
			# Without specs: SelExpr is empty and the bulk path swaps every match in
			# the span at once.
			SelInfo=( ${SelExpr:+${=${(e)SelExpr}}} )
			LastEnd=0
			[[ -n $SelExpr ]] && { : ${SelInfo:+${${${:-$(( ${SelInfo[2]} <= ${#BuffStr} ))}:#0}:+${LastEnd::=$(( ${SelInfo[2]} - 1 ))}}} } || { : ${BuffStr//(#m)(${~AllDelimPat})/${${${:-$(( MEND < ${#BuffStr} ))}:#0}:+${LastEnd::=$MEND}}} }
			Head=${BuffStr[1,$LastEnd]}
			print -rn "${(@)PrintOpts}" -- ${Head:+${Head//(#m)(${~AllDelimPat})/${MATCH:+${${OutDelims[${DelimGroup[(k)$MATCH]}]}//\{\{\}\}/$MATCH}}}}
			BuffStr=${BuffStr[$(( ${#Head} + 1 )),-1]}
			# over the cap: this portion is forced out, so nothing can be held back
			# for it either -- it is swapped with the same no-reserve pass the
			# terminal drain uses, rather than going out raw. A match straddling the
			# cap boundary is still split, which is unavoidable once the buffer has
			# to be released.
			Over=${BuffStr[1,-$((BufferSize+1))]}
			print -rn "${(@)PrintOpts}" -- ${Over:+${Over//(#m)(${~AllDelimPat})/${MATCH:+${${OutDelims[${DelimGroup[(k)$MATCH]}]}//\{\{\}\}/$MATCH}}}}
			BuffStr=${BuffStr[-$BufferSize,-1]}
		}
		# terminal drain: nothing more can arrive, so the one-character reserve
		# is dropped and the WHOLE remainder is swapped in the same single pass.
		: ${${(k)StarDelims[(K)$BuffStr]}:+${BuffStr::=${BuffStr//(#m)(${~AllDelimPat})/${MATCH:+${${OutDelims[${DelimGroup[(k)$MATCH]}]}//\{\{\}\}/$MATCH}}}}}
		print -r "${(@)PrintOpts}" -- $BuffStr
	} always { (( VerboseFD > 2 )) && { exec {VerboseFD}>&- } }
	return 0
}
