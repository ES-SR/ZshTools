
function @numbers:random:range {
	emulate -L zsh; setopt extendedglob typesetsilent

	local -i RangeIdx=${argv[(I)(-|)([0-9.]##|)[,](-|)([0-9.]##|)]}
	local -a Range=( 0 255 )
	(( $RangeIdx )) && {
		Range=(${(-s.,.)${(P)RangeIdx}})
		argv[$RangeIdx]=()
	}

	local -i Count=${1:-1}
	local -a Numbers=()

	RANDOM=$(od -An -N1 -tu1 /dev/urandom)

	while (( Count )) {
		Numbers+=$(( RANDOM % (Range[2] - Range[1] + 1) + 1 ))
		(( Count-- ))
	}

	print -- $Numbers
}

