
function @numbers:random:range {
	emulate -L zsh; setopt extendedglob typesetsilent

	local -i Low=0 High=255 RangeIdx=${argv[(I)((-|)<->|)[,]((-|)<->|)]}
	(( $RangeIdx )) && {
		local -a Range=(${(-)${(s.,.)${(P)RangeIdx}}})
		Low=${Range[1]:-$Low}
		High=${Range[2]:-$High}
		argv[$RangeIdx]=()
	}

	local -i Count=${1:-1}
	local -a Numbers=()

	RANDOM=$(od -An -N1 -tu1 /dev/urandom)

	while (( Count )) {
		Numbers+=$(( RANDOM % (High - Low + 1) + Low ))
		(( Count-- ))
	}

	print -l -- $Numbers
}
