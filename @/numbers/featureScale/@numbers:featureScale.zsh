
function @numbers:featureScale {
	emulate -L zsh; setopt extendedglob typesetsilent

	local -a Range Numbers Normalized Args
	local Sort NumberStr
	local -i SortIdx N 
	local A=0.0 B=1.0 Min Max #no type so they can be cast based on input

	Args=(${(@s.=.s. .)=argv})

	declare -A SortOrder=(['+']="n" ['-']="On" ['[rR]']="Oa")
	SortIdx=${Args[(I)(+|-)]}
	(( SortIdx )) && {
		Sort=$Args[$((SortIdx))]
		Args[$SortIdx]=()
	}
	Sort=${${SortOrder[(k)$Sort]}:-"a"}

	local -i RangeIdx=${argv[(I)(-|)([0-9.]##|)[,](-|)([0-9.]##|)]}
	(( $RangeIdx )) && {
		Range=(${(-s.,.)${(P)RangeIdx}})
		Args[$RangeIdx]=()
		A=${Range[1]}
		B=${Range[2]}
	}

	Min=${${(-)Args}[1]}
	Max=${${(-)Args}[-1]}

	(( Max - Min )) || {
		print -u2 -P -- "%K{red}%F{black}Error: All input numbers are identical. Cannot normalize.%f%k"
	}

	A=${A:-$Min}
	B=${B:-$Max}
	(( A - B )) || {
		print -u2 -P -- %K{yellow}%F{black} range produces constant output %f%k
		for N ( {1..$#} ) {
			Normalized+=("${A}")
		}
		print -- $Normalized
		return 1
	}

	Numbers=(${(e):-$'\$\{\('${Sort}$'\)Args\}'})
	for N ( ${(a)Numbers} ) {
		# multiply by 1. to force a float value
		Normalized+=($(( A + ( 1.0 * (N-Min) * (B-A) / (Max-Min) ) )))
	}
	# if neither A nor B have a decimal, use rint to get integer value
	# this provides properly rounded output instead of trucation when all args are ints
	[[ -z "${(M)A%.*}${(M)B%.*}" ]] && {
		Normalized=(${Normalized//(#m)(<->.(<->|))/${$(( rint(MATCH) ))%.}})
	}
	print -- $Normalized
}
