

function @numbers:random:range {
	emulate -LR zsh -o extendedglob -o typesetsilent

	local Low=0 LowPrecision=0 High=255 HighPrecision=0 Precision=-1
	local -i RangeIdx=${argv[(I)((-|)<->(.<->|)|)[,]((-|)<->(.<->|)|)]}
	(( $RangeIdx )) && {
		local -a Range=(${(-)${(s.,.)${(P)RangeIdx}}})
		Low=${Range[1]:-$Low}
		LowPrecision=${#${(M)Low%.<->}}
		High=${Range[2]:-$High}
		HighPrecision=${#${(M)High%.<->}}
		(( Precision+=
			HighPrecision > LowPrecision ? HighPrecision : ${LowPrecision/0/1}
		))

		argv[$RangeIdx]=()
	}

	local -i Count=${1:-1}
	local -a Numbers=()

	RANDOM=$(od -An -N2 -tu2 /dev/urandom)

	repeat (( Count )) {
		Numbers+=(
			${(*)$((
				(1.0 * RANDOM / 32768) * (High - Low) + Low
			))/(#b)([-0-9]##).([0-9](#c,$Precision))(*)/${match[1]}${${match[2]}:+".${match[2]}"}}
		)
	}

	print -- $Numbers
}
