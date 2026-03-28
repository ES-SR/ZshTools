
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


<<"Examples.@term:size"
	{	: set -x

		print -- "${(l.COLUMNS/2..-.r.COLUMNS/2..-.):-""}"
		@term:size

		print -- "${(l.COLUMNS/2..-.r.COLUMNS/2..-.):-"l c"}"
		@term:size l c

		print -- "${(l.COLUMNS/2..-.r.COLUMNS/2..-.):-"W H"}"
		@term:size W H

		print -- "${(l.COLUMNS/2..-.r.COLUMNS/2..-.):-"1 5 8"}"
		@term:size 1 5 8

		print -- "${(l.COLUMNS/2..-.r.COLUMNS/2..-.):-"w 2 3 4"}"
		@term:size w 2 3 4

		print -- "${(l.COLUMNS/2..-.r.COLUMNS/2..-.):-"2 4 h"}"
		@term:size 2 4 h

		print -- "${(l.COLUMNS/2..-.r.COLUMNS/2..-.):-"2 w l"}"
		@term:size 2 w l

		print -- "${(l.COLUMNS/2..-.r.COLUMNS/2..-.):-"l 4 c"}"
		@term:size l 4 c

		print -- "${(l.COLUMNS/2..-.r.COLUMNS/2..-.):-"10"}"
		@term:size 10
	} always { set +x }
Examples.@term:size
