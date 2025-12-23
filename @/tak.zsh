#!/usr/bin/zsh

() {
	emulate -L zsh; 




	autoload -Uz @debug:init
	function @debug:init {
		emulate -L zsh
		(( DEBUG )) && {
			exec 3>&2
		} || {
			exec 3>/dev/null
		}
	}
	
	autoload -Uz @debug:print
	function @debug:print {
		emulate -L zsh
		options[extendedglob]=on 
		local C2=$(( COLUMNS / 2 )) 
		print -u3 -P -- %S%U${(l.C2.r.C2.):-"[$funcstack[2]]"}%u%s
		local -a PrintArgs=(${(MAz)"${argv}"#*--})
		local -a argv=(${argv:|PrintArgs})
		local -a ParamArgs=(${${(k)parameters}:*argv})
		local -a MessageArgs=(${argv:|ParamArgs})
		print -u3 $PrintArgs "${MessageArgs}"
		local A
		for A ( "${(@)ParamArgs}" ) {
			print -u3 ${PrintArgs:#"--"} -- ${(l.C2..-..|.r.C2..-..|.)A}
			if [[ ${(t)${(P)A}} =~ "assoc*" ]] {
				print -u3 -ac ${PrintArgs:#"--"} -- ${${(f)"$(print -aC2 -- "${(@kvP)A}")"}//(#m)(*)/"${(l.1.r.3.):-"|"}${MATCH/ off/off}"}
			} elif [[ ${(t)${(P)A}} =~ "array*" ]] {
				print -u3 -ac ${PrintArgs:#"--"} -- "${(@)${(P)A}//(#m)(*)/"${(l.1.r.3.):-"|"}${MATCH}"}"
			} else {
				print -u3 ${PrintArgs:#"--"} -- "${(l.1.r.3.):-"|"}${(P)A}"
			}
		}
	}


	autoload -Uz @print:pel
	function @print:pel {
		emulate -L zsh; options[extendedglob]=on; @debug:init
		local -a Args=(${argv})
				@debug:print -l -- "Args:" $Args
	
		local -i LJustify=${Args[(i)(#s)[0-9]#(#e)]}
		local -i RJustify=${Args[(I)(#s)[0-9]#(#e)]}
		(( LJustify == RJustify )) && {
			(( ARGC / 2.0 < LJustify )) && {
				(( LJustify = 0 ))
				RJustify=$Args[$RJustify]
				Args=(${Args:#$RJustify})
			} || {
				(( RJustify = 0 ))
				LJustify=$Args[$LJustify]
				Args=(${Args:#$LJustify})
			}
		} || {
			RJustify=${${Args[$RJustify]}:-0}
			LJustify=${${Args[$LJustify]}:-0}
			Args=(${Args:#$LJustify})
			Args=(${Args:#$RJustify})
		}
		local -i LJ=${LJustify}
		local -i RJ=${RJustify}
		(( LJ + RJ )) || {
			(( LJ = 1 , RJ = 1 ))
		}
		(( LJ = LJ * COLUMNS / ( LJ + RJ ) ))
		(( RJ = COLUMNS - LJ ))
				@debug:print -l -- \
					"Args:" $Args \
					"LJustify: ${LJustify}" "RJustify: ${RJustify}" \
					"LJ: ${LJ}" "RJ: ${RJ}"
	
		local LMargin=${Args[(r)(#s)[^[:alnum:]]#(#e)]}
		local RMargin=${Args[(R)(#s)[^[:alnum:]]#(#e)]}
		(( ${(c)#LMargin} + ${(c)#RMargin} )) && {
			Args=(${Args:#$LMargin})
			Args=(${Args:#$RMargin})
		}
				@debug:print -l -- \
					"Args:" $Args \
					"LMargin: ${LMargin}" "RMargin: ${RMargin}" \
	
		local LPadding=${Args[(r)(#s)[^[:alnum:]]#(#e)]}
		local RPadding=${Args[(R)(#s)[^[:alnum:]]#(#e)]}
		(( ${(c)#LPadding} + ${(c)#RPadding} )) && {
			Args=(${Args:#$LPadding})
			Args=(${Args:#$RPadding})
		}
	
		local Content LP RP LM RM
		(( $#Args )) && {
			LP=${LPadding:-" "}
			RP=${RPadding:-" "}
			LM=${LMargin:-"-"}
			RM=${RMargin:-"-"}

			Content=${Args}
			Args=()
		} || {
			LM=${LMargin}
			RM=${RMargin}
			LP=${LPadding:-$LM}
			RP=${RPadding:-$RM}
			Content="${LP}${RP}"
			(( ${(c)#Content} )) || {
				print -- ${(l.((COLUMNS))..-.)}
				return
			}
		}
				@debug:print -l -- \
					"LMargin: ${LMargin}" "RMargin: ${RMargin}" \
					"LPadding: ${LP}" "RPadding: ${RP}" \
					"Content: ${Content}"
	
		print -P -- ${(pel.((LJ))..$LM..$LP.r.((RJ))..$RM..$RP.)Content}
	}



	autoload -Uz @numbers:featureScale
	function @numbers:featureScale {
		emulate -L zsh; options[extendedglob]=on
		local -a Numbers Normalized Args
		local Min Max N Sort Range NumberStr
		local -i SortIdx
		local a=0.0
		local b=1.0
		Args=(${(@s.=.s. .)=argv})

		declare -A SortOrder=(['+']="n" ['-']="On" ['[rR]']="Oa")
		SortIdx=${Args[(I)(#i)((-|--)s(ort|))|((-|--|)sort)]}
		(( SortIdx )) && {
			Sort=$Args[$((SortIdx+1))]
			Args=(${${Args:#$Args[$SortIdx]}:#$Sort})
		}
		Sort=${${SortOrder[(k)$Sort]}:-"a"}

		Range=${Args[(r)(-|)([0-9.]##|)[,](-|)([0-9.]##|)]}
		(( $#Range )) && {
			Args=(${Args:#$Range})
			a=${Range%%,(-|)([0-9.]##|)}
			b=${Range##(-|)([0-9.]##|),}
		}

		Min=${${(n)Args}[1]}
		Max=${${(n)Args}[-1]}
		(( Max - Min )) || {
			print -u2 -P -- "%K{red}%F{black}Error: All input numbers are identical. Cannot normalize.%f%k"
		}

		a=${a:-$Min}
		b=${b:-$Max}
		(( a - b )) || {
			print -u2 -P -- %K{yellow}%F{black} range produces constant output %f%k
			for N ( {1..$#} ) {
				Normalized+=("${a}")
			}
			print -- $Normalized
			return 1
		}

		NumberStr="Numbers=(\${(${Sort})Args})"
		eval "$NumberStr"

		for N ( ${(a)Numbers} ) {
			Normalized+=($(( a + ( (N-Min)*(b-a) / (Max-Min) ) )))
		}
		: <<< "TODO:add flag to output orginal and new values (output used while developing function)"
		print -- $Normalized
	}

	(( $# )) && { @numbers:featureScale $@ }
}

	function __@tak {
		integer X=$1 Y=$2 Z=$3
		if (( Y >= X )) {
			print -- Stack Depth: $#funcstack >>| tak.log
				return $Z
		}

		integer R1 R2 R3
			__@tak $(( X - 1 )) $Y $Z; R1=$?
			__@tak $(( Y - 1 )) $Z $X; R2=$?
			__@tak $(( Z - 1 )) $X $Y; R3=$?

			__@tak $R1 $R2 $R3; return $?
	}

	function __@tak:noLog {
		integer X=$1 Y=$2 Z=$3
		if (( Y >= X )) {
			return $Z
		}

		integer R1 R2 R3
		__@tak:noLog $(( X - 1 )) $Y $Z; R1=$?
		__@tak:noLog $(( Y - 1 )) $Z $X; R2=$?
		__@tak:noLog $(( Z - 1 )) $X $Y; R3=$?

		__@tak:noLog $R1 $R2 $R3; return $?
	}

	function @tak:run {
		integer X=$1 Y=$2 Z=$3
		__@tak $X $Y $Z;
		print -P "Result: %B$?%b" | tee -a tak.log
	}
	alias @tak="() { \
	< /dev/null >|tak.log; \
	@print:pel without logging; \
	time ( __@tak:noLog \$1 \$2 \$3 ); \
	@print:pel with logging;
	time ( @tak:run \$1 \$2 \$3 );
	eval \"\$(< tak.log | awk '
		/Stack Depth/ {
			TotalCalls+=1
			Depths[\$3]++
			if( \$3 > MaxDepth ) {
				MaxDepth=\$3
			}
		}
		END {
			print \"declare -gA Results=(\"
			print \"MaxStackDepth\", MaxDepth
			print \"TotalCalls\", TotalCalls
			print \")\"
			print \"declare -gA DepthDistribution=(\"
			for( D in Depths ) {
				print D, Depths[D]
			}
		print \")\"
		}
	')\"}"
	
	@print:pel = Args:\ 18\ 12\ 6
	@tak 18 12 6

	print -aC2 -- ${(kv)Results}
	() {
		local -a Depths Occurs
		for K ( ${(nk)DepthDistribution} ) {
			Depths+=(${K})
			Occurs+=($DepthDistribution[${K}])
		}
		ScaleLens=($(@numbers:featureScale 4,$(( COLUMNS - 3 )) $Occurs))
		for D O ( ${Depths:^ScaleLens} ) {
			print -- $D: ${(l.O/2..-.r.O/2..-.)DepthDistribution[$D]}
		} 
	}

