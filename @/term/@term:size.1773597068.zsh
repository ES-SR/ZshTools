
function @term:size {
	emulate -L zsh; setopt extendedglob typesetsilent

	local -a Args=("${(@)argv}")
	Args=(${Args:#<->})
	local -aU Nums=( ${${argv:|Args}:-1} )

	(( ${#Args} )) || { Args=( H  W ) }

	local -i Hidx=${Args[(I)(#i)(H(eight|)|(L(ines|))|(R(ows|)))]}
	local -i Widx=${Args[(I)(#i)(W(idth|)|(C(olumns|)))]}

	local -a H=()
	(( Hidx )) && {
		H=(${Nums//(#m)(*)/$((LINES/MATCH))})
	}
	local -a W=()
	(( Widx )) && {
		W=(${Nums//(#m)(*)/$((COLUMNS/MATCH))})
	}

	(( Hidx - Widx < 0 )) && {
		print ${H:^^W}
	} || {
		print ${W:^^H}
	}
}

