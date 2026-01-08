function __@ack {
	# Definition:
	#   A(0, n) = n + 1
	#   A(m, 0) = A(m-1, 1)
	#   A(m, n) = A(m-1, A(m, n-1))
	integer M=$1 N=$2
	# Base Case: m = 0
	(( M )) || {
		return $(( N + 1 ))
	}
	# Recursive Step: n = 0
	(( N )) || {
		__@ack $(( M - 1 )) 1
		return $?
	}
	# Recursive Step: m > 0, n > 0
	integer Inner
	# Calculate inner layer: A(m, n-1)
	__@ack $M $(( N - 1 )); Inner=$?
	# Calculate outer layer: A(m-1, inner)
	__@ack $(( M - 1 )) $Inner

	return $?
}

function __@ack:memo {
	integer M=$1 N=$2
	(( ${+__AckMemos["$M,$N"]} )) && {
		return $__AckMemos["$M,$N"]
	}
	(( M )) || {
		return $(( N + 1 ))
	}
	(( N )) || {
		__@ack:memo $(( M - 1 )) 1
		return $?
	}
	integer Inner Result
	__@ack:memo $M $(( N - 1 )); Inner=$?
	__@ack:memo $(( M - 1 )) $Inner; Result=$?
	__AckMemos["$M,$N"]=$Result

	return $Result
}

function __@ack:hybrid {
	integer M=$1 N=$2
	local Memo="${1},${2}"
	# 1. Formula Shortcuts (The Anti-Stack-Overflow Mechanism)
	if (( M == 0 )) {
		return $(( N + 1 ))
	} elif (( M == 1 )) {
		return $(( N + 2 ))
	} elif (( M == 2 )) {
		return $(( 2 * N + 3 ))
	} elif (( M == 3 )) {
		return $(( (1 << (N + 3)) - 3 ))  # 2^(n+3) - 3
	}
	if (( ${+AckMemos[$Memo]} )) {
		return $AckMemos[$Memo]
	}
	# 3. Recursive Step (Only for M >= 3)
	integer Inner Result
	(( N )) && {
		__@ack:hybrid $M $(( N - 1 )); Inner=$?
		__@ack:hybrid $(( M - 1 )) $Inner; Result=$?
	} || {
		__@ack:hybrid $(( M - 1 )) 1
		Result=$?
	}
	AckMemos[$Memo]=$Result

	return $Result
}

function @ack:run {
	local -a argv=("${(@)argv}")
	local Mode=${argv[(r)((-|--|)(#i)((Memo)|(Hybrid)))|((-|--)(#i)(m|h))]}
	argv=(${argv:#$Mode})
	Mode=${${${(U)${Mode##-#}[1]}:s/M/Memoized/:s/H/Hybrid}:-Standard}
	local -A Modes=(
		Memoized __@ack:memo
		Hybrid __@ack:hybrid
		Standard __@ack
	)

	integer M=$1 N=$2
	print -P "%BRunning ${Mode:+"$Mode "}Ackermann($M, $N)...%b" | tee -a ack.log

	if [[ $Mode != "Standard" ]] {
		(( ${+__AckMemos} )) || {
			declare -gHA __AckMemos
		}
	}

	local Cmd=${Modes[$Mode]}
	$Cmd $M $N

	print -P "Result: %B$?%b" | tee -a ack.log
}

alias @ack="() { < /dev/null >|ack.log; time ( @ack:run \$1 \$2 \$3); }


function @ack {
    integer M=$1 N=$2
    integer RegLo=$N RegHi=0
    local -A AckMemos

    function __@math:add {
        integer Val=$1
        (( RegLo += Val ))
        # Carry Logic: Detect 64-bit signed wrap
        # If RegLo was positive/zero and adding positive Val made it negative
        if (( RegLo < 0 && (RegLo - Val) >= 0 )) {
            (( RegHi++ ))
        }
    }
    function __@math:sub {
        integer Val=$1
        if (( RegLo == 0 )) {
            if (( RegHi > 0 )) {
                (( RegHi-- ))
                RegLo=-1  # Wraps to Max Unsigned (All 1s)
                return
            }
        }
        (( RegLo -= Val ))
    }
    function __@math:shift:left {
        # 128-bit :left shift (Multiply by 2)
        integer Carry=0
        if (( RegLo < 0 )) { Carry=1 } # Capture Sign Bit

        (( RegHi = (RegHi << 1) + Carry ))
        (( RegLo = RegLo << 1 ))
    }

    function __@ack {
        integer M=$1

        local Key="${M},${RegLo},${RegHi}"
        Key=${(q+)Key}

        if (( ${+AckMemos[$Key]} )) {
            RegLo=${AckMemos[$Key]}
            RegHi=${AckMemos["${Key},Hi"]}
            return
        }

        if (( M == 0 )) {
            __@math:add 1
        } elif (( M == 1 )) {
            __@math:add 2
        } elif (( M == 2 )) {
            __@math:shift:left
            __@math:add 3
        } else {
            integer SaveLo=$RegLo SaveHi=$RegHi

            if (( RegLo == 0 && RegHi == 0 )) {
                # Case: A(m, 0) -> A(m-1, 1)
                RegLo=1; RegHi=0
                __@ack $(( M - 1 ))
            } else {
                # Case: A(m, n) -> A(m-1, A(m, n-1))
                __@math:sub 1
                __@ack $M
                __@ack $(( M - 1 ))
            }
            # Reconstruct Key for storage (Registers changed)
            Key="${M},${SaveLo},${SaveHi}"
            Key=${(q+)Key}
        }

        # 4. Write Back
        AckMemos[$Key]=$RegLo
        AckMemos["${Key},Hi"]=$RegHi
    }

    # -------------------------------------------------------------------------
    # Execution
    # -------------------------------------------------------------------------

    __@ack $M

    # -------------------------------------------------------------------------
    # Output
    # -------------------------------------------------------------------------

    if (( RegHi == 0 )) {
        # Fits in 64-bit
        print -P "Result: %B$RegLo%b"
    } else {
        # 128-bit Result
        print -P "Result: %BHigh:$RegHi Low:$RegLo%b"
				print -- $(( [#16] RegHi RegLo ))
        printf "Hex: %lx%016lx\n" $RegHi $RegLo

    }

    # Cleanup: Prevent namespace pollution in the interactive shell
    unfunction __@ack __@math:add __@math:sub __@math:shift:left
}

