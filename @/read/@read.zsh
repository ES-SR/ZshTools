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
	# Flag name -> match pattern; name -> value count (+ = "rest"). Split any
	# flag=val token into two, find each flag's occurrences, expand them to the
	# argv indices each flag consumes (start .. start+count). Delimiter args are
	# argv at the indices no flag consumed; a flag's values are its consumed
	# indices minus its own start indices. Verbose takes the fd to write to.
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
	# quote every arg first so the (z) split only separates the "flag val" pair
	# made here (a ' | ' or '' delimiter survives), then unquote
	(( ${#Found} )) && { set -- "${(@Q)${(@z)${(@)${(@q-)argv}//(#m)(${~${(j.|.)Found}})/${MATCH%%=*} ${MATCH#*=}}}}" }

	local -a ArgvIdxs=({1..$ARGC})
	IdxdArgv=(${ArgvIdxs:^argv})

	local Idxs
	local -A FoundFlags=( ${(Az)${(-k)Flags}//(#m)*/${${Idxs::=${(j.:.)${(-k)IdxdArgv[(R)(#i)(${~Flags[$MATCH]})]}}}:+${MATCH} ${Idxs}}} )

	local FlagName ValCount; local -a StartIdxs RangeIdxs
	local -A FlagRanges=( ${(Az)${(k)FoundFlags}//(#m)*/${FlagName::=$MATCH} ${${ValCount::=${FlagValCounts[$FlagName]}}:+} ${${(A)StartIdxs::=${(s.:.)FoundFlags[$FlagName]}}:+} ${(q-)RangeIdxs::=${StartIdxs//(#m)*/${(e):-{$MATCH..$((MATCH+${ValCount/+/$((ARGC-MATCH))}))}}}} } )

	local -a DirtyIdxs=(${(Qz)FlagRanges})
	ArgvIdxs=(${ArgvIdxs:|DirtyIdxs})
	local -a Args=(${ArgvIdxs//(#m)*/${IdxdArgv[$MATCH]}})

	for FlagName ( ${(k)Flags} ) { local -a $FlagName }
	local -a ValIdxs
	for FlagName ( ${(k)FoundFlags} ) {
		RangeIdxs=( ${(Qz)FlagRanges[$FlagName]} ) ; StartIdxs=( ${(s.:.)FoundFlags[$FlagName]} )
		[[ ${FlagValCounts[$FlagName]} == 0 ]] && { ValIdxs=( $RangeIdxs ) } || { ValIdxs=( ${RangeIdxs:|StartIdxs} ) }
		set -A $FlagName "${(@)ValIdxs//(#m)*/${IdxdArgv[$MATCH]}}"
	}

	# comma-separated groups: last element is the group's out-delimiter, the
	# rest are in-delimiter patterns. Group number and member number are
	# declaration order, fixed here; each group's whole-pattern alternation
	# (GroupDelims) is built once up front, and doubles as an exact DelimGroup
	# key so single-group G patterns resolve without a scan. StarGroup maps a
	# member's star-key to its group, so a group's members are a reverse lookup.
	local -A StarDelims=() StarGroup=() DelimGroup=() DelimMember=() GroupDelims=()
	local -a OutDelims=() Group=()
	local Arg Delim
	local -i MemberNum=0
	for Arg ( "${(@)Args}" , ) {
		[[ $Arg == , ]] && {
			(( ${#Group} >= 2 )) && {
				OutDelims+=( "${Group[-1]}" )
				GroupDelims[${#OutDelims}]=${(j.|.)Group[1,-2]}
				DelimGroup[(${(j.|.)Group[1,-2]})]=${#OutDelims}
				(( MemberNum = 0 ))
				for Delim ( ${Group[1,-2]} ) {
					DelimGroup[$Delim]=${#OutDelims}
					DelimMember[$Delim]=$(( ++MemberNum ))
					StarDelims[*${Delim}*]=$Delim
					StarGroup[*${Delim}*]=${#OutDelims}
				}
			}
			Group=()
		} || { Group+=( "$Arg" ) }
	}

	# selector entries drive the default choice: <S|L|E>:<slice> filters the
	# working id set by that table -- the slice (raw zsh subscript text: 1,
	# -1, 2,4) picks from the RESTRICTED sorted unique VALUE list, so a pick
	# is a whole value-class and ties never split -- and a bare G or M entry
	# sets how the survivors resolve into DelimPat. The default chain is the
	# design default: the whole group of the longest match at the earliest
	# start. A slice is split into its two bounds (SliceA,SliceB) because a
	# range comma has to be literal text inside the subscript brackets.
	local -A TableByLetter=( S Starts L Lens E Ends )
	local -a Choices=( S:1 L:-1 )
	local Mode='G' ArrName='' Slice='' SliceA='' SliceB=''

	ChunkSize[1]=${${ChunkSize[1]}:-8}
	EmptyReads[1]=${${EmptyReads[1]}:-5}
	BufferSize[1]=${${BufferSize[1]}:-4096}
	Timeout[1]=${${Timeout[1]}:-0.4}

	local -i HistSize=$((63-EmptyReads))
	local -i HistMask=$(( 2**HistSize - 1 ))
	local -i EmptyReadsMask=$(( (2**EmptyReads - 1) << HistSize ))
	local -i TimeoutHist=0

	# happy path pre-calculated: an empty read shifts a 1 into BOTH partitions,
	# so every reachable escalation state carries HistoryBits == EmptyReadBits.
	# Both partitions are always a contiguous run of 1s (grow (x<<1)|1, shrink
	# >>1, clear wholesale). TOTable[0] is the first read's timeout.
	local -A TOTable=()
	local -i EmptyReadBits=0
	for EmptyReadBits ( {0..$EmptyReads} ) { TOTable[$(( ((2**EmptyReadBits-1) << HistSize) | (2**EmptyReadBits-1) ))]=$(( (Timeout*(1+(1.0*EmptyReadBits/HistSize)))**(((1.0*EmptyReads)+EmptyReadBits)/EmptyReads) )) }
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
	local DelimPat='' REPLY='' Pattern=''

	# resolution chosen ONCE: the user's entries, or the default selector chain,
	# in DelimSelectionLogic. Entries are expansion text, joined with nothing
	# and run by (e) every iteration (left to right, so serial entries keep
	# their order); values are set with ${Var::=...}, nested arrays need an
	# explicit (@), and the tables are empty on iterations without a match --
	# the default is one ${MatchIds:+...} around all its entries, so an empty
	# match set never seeds __MatchIds (an empty (A)::= leaves one '' element,
	# which would resolve to a bogus DelimPat). The chain is ONE expansion over
	# the entries: each stage maps the live ids to their values (restricted),
	# sorts unique, slices the value list, reverse-looks-up the picked values'
	# keys, and intersects with the live set -- ArrName/Slice read the entry's
	# MATCH before the inner map clobbers it. Its expansion result is the
	# per-stage tab columns, which the loop prints to VerboseFD.
	local -a DefaultLogic=(
		'${MatchIds:+'
		'${${(A)__MatchIds::=${(@)MatchIds}}:+}${${Mode::=G}:+}'
		'${(F)${(@)Choices//(#m)*/${${(M)MATCH:#[GM]}:+Mode ${Mode::=$MATCH}}${${MATCH:#[GM]}:+\tArrName ${ArrName::=${TableByLetter[${(U)MATCH[1]}]}}\tSlice ${Slice::=${${MATCH[3,-1]}:-1}}${${SliceA::=${Slice%%,*}}:+}${${SliceB::=${Slice#*,}}:+}\tPVals ${(A)PVals::=${(Au-)${(@)__MatchIds//(#m)*/${${(P)ArrName}[$MATCH]}}}}\tMVals ${(A)MVals::=${(Au)${(@)PVals[${SliceA},${SliceB}]}}}\tMIds ${(A)MIds::=${(@k)${(P)ArrName}[(R)(${(j.|.)MVals})]}}\t__MatchIds ${(A)__MatchIds::=${(@)__MatchIds:*MIds}}}}}'
		'${${${(M)Mode:#M}:+${DelimPat::=${(uj.|.)${(@)__MatchIds//(#m)*/${InDelims[$MATCH]}}}}}:+}${${${Mode:#M}:+${DelimPat::=${(uj.|.)${(@)${(u@)__MatchIds//(#m)*/${Groups[$MATCH]}}//(#m)*/(${GroupDelims[$MATCH]})}}}}:+}'
		'}'
	)
	local -a DelimSelectionLogic=( ${UserLogic:-$DefaultLogic} )

	# loop workspace, declared once
	local -a PVals=() MVals=() MIds=() Present=() GrpStars=()
	local -i MatchNum=0 BytesRead=0 ReadReturn=0
	local DelimGrp='' DelimMbr='' Head='' BuffStr='' Chunk='' SelectionOut=''

	# the only loop: one chunked read per iteration, then three expansions
	{
		while (( TimeoutHist >= 0 )) {
			Chunk='' BytesRead=0
			sysread -c BytesRead -s $ChunkSize[1] -t $CurTimeout Chunk
			ReadReturn=$?
			print -u $VerboseFD -- "BytesRead: ${BytesRead}\tTO: ${CurTimeout}\tHist: ${(l.63..0.)$(( [##2] TimeoutHist ))}\tReturn: ${ReadReturn} - ${ReturnValueMeanings[ReadReturn+1]}"

			# expansion 1: register update -- an empty read shifts a 1 into both
			# partitions (an ER run past EmptyReads lands in the sign bit and ends
			# the loop); a success clears the ER run, else decays one history bit
			# -- then the NEXT read's timeout, memoized by raw register value.
			# Partition bit lengths: [##2] with one trailing 0 stripped
			# (0 -> "" -> 0, 2^k-1 -> k), riding the contiguous-run invariant.
			: ${${${ReadReturn:#0}:+${TimeoutHist::=$(( ((TimeoutHist & ~HistMask) << 1) | (2**HistSize) | ((((TimeoutHist & HistMask) << 1) | 1) & HistMask) ))}}:-${TimeoutHist::=$(( TimeoutHist & EmptyReadsMask ? TimeoutHist & HistMask : TimeoutHist >> 1 ))}}${CurTimeout::=${TOTable[$TimeoutHist]:-${TOTable[$TimeoutHist]::=$(( (Timeout*(1+(1.0*${#${${:-$(( [##2] TimeoutHist & HistMask ))}%0}}/HistSize)))**(((1.0*EmptyReads)+${#${${:-$(( [##2] (TimeoutHist & EmptyReadsMask) >> HistSize ))}%0}})/EmptyReads) ))}}}
			BuffStr+=$Chunk

			# expansion 2: all match metadata, consuming nothing. Present is the
			# star-keys the buffer matches; their groups (unique) are walked with
			# the group number stored first, each group's star-keys (StarGroup
			# reverse lookup, assigned so :* has a name) intersected with Present,
			# and each present member scanned over BuffStr to fill the id tables.
			MatchIds=() Starts=() Lens=() Ends=() Texts=() InDelims=() Groups=() Members=()
			: ${MatchNum::=1}${(A)Present::=${(k)StarDelims[(K)$BuffStr]}}${${(u)Present//(#m)*/${StarGroup[$MATCH]}}//(#m)*/${DelimGrp::=$MATCH}${${(A)GrpStars::=${(k)StarGroup[(R)$DelimGrp]}}:+}${${GrpStars:*Present}//(#m)*/${Delim::=${StarDelims[$MATCH]}}${DelimMbr::=${DelimMember[$Delim]}}${${BuffStr//(#m)${~Delim}/${MBEGIN:+${Starts[M$MatchNum]::=$MBEGIN}${Ends[M$MatchNum]::=$MEND}${Lens[M$MatchNum]::=${#MATCH}}${Texts[M$MatchNum]::=$MATCH}${InDelims[M$MatchNum]::=$Delim}${Groups[M$MatchNum]::=$DelimGrp}${Members[M$MatchNum]::=$DelimMbr}${MatchIds[$MatchNum]::=M$MatchNum}${MatchNum::=$((MatchNum+1))}}}:+}}}

			# expansion 3: ONE resolution per iteration -- the chosen logic reads
			# the tables, may mutate BuffStr in place, and leaves its choice in
			# DelimPat (or REPLY). Both empty defers to the next iteration. The
			# expansion's text is the verbose output; :+ supplies its newline, so
			# an empty result prints nothing. Never print -l here: with no args
			# it still prints a newline, the same reason every output print is -n.
			DelimPat='' REPLY=''
			SelectionOut=${(e)${(j..)DelimSelectionLogic}}
			print -nu $VerboseFD -- ${SelectionOut:+$SelectionOut$'\n'}

			# batch consumption: everything through the pattern's last occurrence
			# -- kept clear of the buffer end, honoring deferral -- prints with
			# every occurrence swapped for its own group's out-delimiter: an exact
			# DelimGroup hit for a declared delimiter or a single-group G pattern,
			# else [(k)$MATCH] pattern-keys resolve each matched text back to its
			# group. Matches of unchosen delimiters inside the span print raw; a
			# delimiter left past the span is picked up next iteration (the EOF
			# drain runs these expansions too). An empty Pattern or a zero-width
			# match gives an empty Head: nothing prints, the buffer stays.
			Pattern=${DelimPat:-$REPLY}
			Head=${Pattern:+${(M)${BuffStr[1,-2]}##*${~Pattern}}}
			print -rn -- ${Head:+${Head//(#m)${~Pattern}/${OutDelims[${DelimGroup[$Pattern]:-${DelimGroup[(k)$MATCH]}}]}}}
			BuffStr=${BuffStr[$(( ${#Head} + 1 )),-1]}
			print -rn -- ${BuffStr[1,-$((BufferSize+1))]}
			BuffStr=${BuffStr[-$BufferSize,-1]}
		}
		print -r -- $BuffStr
	} always { (( VerboseFD > 2 )) && { exec {VerboseFD}>&- } }
	return 0
}
print -r -- '# basic swap and delimiter split across chunks'
print -rn -- 'oneENDtwoENDthree' | @read -CS 5 END ' | '

print -r -- '# two delimiter groups, small chunks'
print -rn -- 'xAAyCCzBBw' | @read AA BB '|' , CC '_'

print -r -- '# one chunk: the default G span consumes through BB, foreign CC prints raw'
print -rn -- 'xAAyCCzBBw' | @read -CS 32 AA BB '|' , CC '_'

print -r -- '# user logic reads the tables: longest match by value reverse-lookup'
print -rn -- 'xxabcyy' | @read ab abc '<>' -- '${MatchIds:+${DelimPat::=${InDelims[${(k)Lens[(r)${${(@On)${(@v)Lens}}[1]}]}]}}}'

print -r -- '# serial user logic: the second entry vetoes the first'
print -rn -- 'xxabyy' | @read ab abc '<>' -- '${MatchIds:+${DelimPat::=${InDelims[${(k)Lens[(r)${${(@On)${(@v)Lens}}[1]}]}]}}}' '${MatchIds:+${${${:-$(( ${${(@On)${(@v)Lens}}[1]} < 3 ))}:#0}:+${DelimPat::=}}}'

print -r -- '# conventional REPLY name still honored'
print -rn -- 'aENDb' | @read END '|' -- '${${REPLY::=END}:+}'

print -r -- '# user logic overrides the group choice outright'
print -rn -- 'xAAyCCzw' | @read -CS 32 AA '|' , CC '_' -- '${${DelimPat::=CC}:+}'

print -r -- '# newline to space'
print -l -- one two three | @read $'\n' ' '

print -r -- '# EOF counts as an empty read (verbose to fd 2)'
print -rn -- 'aENDb' | @read -v 2 -ER 2 END '|'

print -r -- '# trailing delimiter is deferred, never consumed early'
print -rn -- 'xENDyEND' | @read END '|'

print -r -- '# stalled producer trips the sign-bit kill-switch (verbose to fd 3, routed to stderr)'
{ print -rn -- 'aaa'; sleep 3 } | @read -v 3 -T 0.2 -ER 3 END ' ' 3>&2

print -r -- '# BufferSize caps an unbroken stream'
print -rn -- 'abcdefghijklmnopqrstuvwxyz' | @read -CS 8 -BS 10 Q ' '

print -r -- '# pattern delimiter from the proof of concept'
print -rn -- ' 9630 print 1' | @read -CS 16 '([^0-9][^0-9]#)' '<>'

print -r -- '# chunk boundary can split a variable-length pattern run: tune ChunkSize'
print -rn -- ' 9630 print 1' | @read -CS 8 '([^0-9][^0-9]#)' '<>'

print -r -- '# anchored pattern with an empty match defers instead of looping'
print -rn -- 'abc' | @read '(#s)[0-9]#' '<'

print -r -- '# flag=val tokens: whitespace and empty args survive the split'
print -rn -- 'oneENDtwoENDthree' | @read -CS=5 --Timeout=0.4 END ' | '

print -r -- '# three spans pending in the last chunk resolve during the EOF drain'
print -rn -- 'aXbXcXd' | @read -CS 32 X '-'

## the selector chain standalone, against fake match tables: the SAME entry
## text @read stores as its default UserLogic, run the same way, so a range
## slice (2,4) is on record picking a value-class range, not a single element.
function rig {
	emulate -L zsh; setopt extendedglob typesetsilent
	local -A Starts=( M1 1 M2 1 M3 4 M4 5 ) Ends=( M1 3 M2 6 M3 4 M4 6 ) Lens=( M1 3 M2 6 M3 1 M4 2 )
	local -A Vals=( M1 32 M2 6 M3 31 M4 123 )
	local -A TableByLetter=( S Starts L Lens E Ends V Vals )
	local -a MatchIds=( M1 M2 M3 M4 ) PVals=() MVals=() MIds=() Choices=( "$@" )
	local -aU __MatchIds=( "${(@)MatchIds}" )
	local Mode='G' ArrName='' Slice='' SliceA='' SliceB=''
	local Chain='${MatchIds:+${(F)${(@)Choices//(#m)*/${${(M)MATCH:#[GM]}:+Mode ${Mode::=$MATCH}}${${MATCH:#[GM]}:+\tArrName ${ArrName::=${TableByLetter[${(U)MATCH[1]}]}}\tSlice ${Slice::=${${MATCH[3,-1]}:-1}}${${SliceA::=${Slice%%,*}}:+}${${SliceB::=${Slice#*,}}:+}\tPVals ${(A)PVals::=${(Au-)${(@)__MatchIds//(#m)*/${${(P)ArrName}[$MATCH]}}}}\tMVals ${(A)MVals::=${(Au)${(@)PVals[${SliceA},${SliceB}]}}}\tMIds ${(A)MIds::=${(@k)${(P)ArrName}[(R)(${(j.|.)MVals})]}}\t__MatchIds ${(A)__MatchIds::=${(@)__MatchIds:*MIds}}}}}}'
	: ${(e)Chain}
	print -r -- "${(r.16.)${(j:,:)argv}} -> ( ${(j: :)__MatchIds} )"
}

rig S:1 L:-1
rig E:-1
rig E:-1 L:-1
rig V:-1
rig L:2,4
rig S:1
# basic swap and delimiter split across chunks
one | two | three
# two delimiter groups, small chunks
x|y_z|w
# one chunk: the default G span consumes through BB, foreign CC prints raw
x|yCCz|w
# user logic reads the tables: longest match by value reverse-lookup
xx<>yy
# serial user logic: the second entry vetoes the first
xxabyy
# conventional REPLY name still honored
a|b
# user logic overrides the group choice outright
xAAy_zw
# newline to space
one two three

# EOF counts as an empty read (verbose to fd 2)
BytesRead: 5	TO: 0.40000000000000002	Hist: 000000000000000000000000000000000000000000000000000000000000000	Return: 0 - At least one byte of data was successfully read and, if appropriate, written.
	ArrName Starts	Slice 1	PVals 2	MVals 2	MIds M1	__MatchIds M1
	ArrName Lens	Slice -1	PVals 3	MVals 3	MIds M1	__MatchIds M1
a|BytesRead: 0	TO: 0.40000000000000002	Hist: 000000000000000000000000000000000000000000000000000000000000000	Return: 5 - No system error occurred, but zero bytes were read.  This usually indicates end of file.  The parameters are set according to the usual rules; no write to outfd is attempted.
BytesRead: 0	TO: 0.25922851304987854	Hist: 010000000000000000000000000000000000000000000000000000000000001	Return: 5 - No system error occurred, but zero bytes were read.  This usually indicates end of file.  The parameters are set according to the usual rules; no write to outfd is attempted.
BytesRead: 0	TO: 0.17066380005374901	Hist: 110000000000000000000000000000000000000000000000000000000000011	Return: 5 - No system error occurred, but zero bytes were read.  This usually indicates end of file.  The parameters are set according to the usual rules; no write to outfd is attempted.
b
# trailing delimiter is deferred, never consumed early
x|yEND
# stalled producer trips the sign-bit kill-switch (verbose to fd 3, routed to stderr)
BytesRead: 3	TO: 0.20000000000000001	Hist: 000000000000000000000000000000000000000000000000000000000000000	Return: 0 - At least one byte of data was successfully read and, if appropriate, written.
BytesRead: 0	TO: 0.20000000000000001	Hist: 000000000000000000000000000000000000000000000000000000000000000	Return: 4 - The attempt to read timed out.  Note this does not set ERRNO as this is not a system error.
BytesRead: 0	TO: 0.11956702964788249	Hist: 001000000000000000000000000000000000000000000000000000000000001	Return: 4 - The attempt to read timed out.  Note this does not set ERRNO as this is not a system error.
BytesRead: 0	TO: 0.072241051378128127	Hist: 011000000000000000000000000000000000000000000000000000000000011	Return: 4 - The attempt to read timed out.  Note this does not set ERRNO as this is not a system error.
BytesRead: 0	TO: 0.044100000000000007	Hist: 111000000000000000000000000000000000000000000000000000000000111	Return: 4 - The attempt to read timed out.  Note this does not set ERRNO as this is not a system error.
aaa
# BufferSize caps an unbroken stream
abcdefghijklmnopqrstuvwxyz
# pattern delimiter from the proof of concept
<>9630<>1
# chunk boundary can split a variable-length pattern run: tune ChunkSize
<>9630<><>1
# anchored pattern with an empty match defers instead of looping
abc
# flag=val tokens: whitespace and empty args survive the split
one | two | three
# three spans pending in the last chunk resolve during the EOF drain
a-b-c-d
S:1,L:-1         -> ( M2 )
E:-1             -> ( M2 M4 )
E:-1,L:-1        -> ( M2 )
V:-1             -> ( M4 )
L:2,4            -> ( M1 M2 M4 )
S:1              -> ( M1 M2 )


: <<-"OLDVERSION"
function @read { 
	emulate -L zsh; setopt extendedglob typesetsilent
	if ! [[ -p /dev/stdin ]] { return 1 } 
 
	@args:parse MaxEmptyReads:1 Timeout:1 OutDelimiter:+ InDelimiter:+
	set -- "${(@)ParsedArgv}"

	local -i MaxEmptyReads=${${MaxEmptyReads[1]}:-4}
	local -F Timeout=${${Timeout[1]}:-0.2}
	local InDelim="${InDelimiter:-"${argv:-"{}"}"}"
	local OutDelim="${:-"${OutDelimiter:-"{}"}"} "

	local -a Buffer=() 
 
	local -i ReadAttempts=${MaxEmptyReads}
	while (( ReadAttempts )) { 
		local Char
		IFS= read -u 0 -t ${Timeout} -k 1 -rs Char

		[[ -z $Char ]] && {
			((ReadAttempts--))
			continue
		}

		Buffer+=("${Char}")
		((ReadAttempts=MaxEmptyReads))
		local BuffStr="${(j..)Buffer}"
		local FirstDelim=""

		while [[ -n "${FirstDelim::="${(M)BuffStr#*${~InDelim}}"}" ]] {
			BuffStr="${BuffStr#*${~InDelim}}"
			print -nr -- "${FirstDelim/${~InDelim}/"${OutDelim}"}"
		}
		Buffer=(${(s..)BuffStr})
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
		} always {
			set +x
		}
	}
Examples.@read
OLDVERSION

