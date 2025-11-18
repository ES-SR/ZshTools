() {

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

} 
