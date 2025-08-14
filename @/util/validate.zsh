#!/bin/zsh

() {

function @validate {
	local Args=( ${(a)@} )
	local Verbose=${Args[(r)-v]}
	Verbose=${${Verbose:+true}:-false}
	$Verbose && {
		Args=( ${Args:#-v} )
		exec 3>&1
	} || {
		exec 3>/dev/null
	}

	function __@verbose {
		echo "$@" >&3
	}

	local Value=${1}
	local Tests=${Args[2,-1]}
	Tests=( ${(s--)Tests// /} )

	local -a ValidTestChars=( a b c d e f G g h k L n N o O p r s S t u v w x z )
	local -a InvalidArgs=( ${Tests:|ValidTestChars} )
	Tests=( ${Tests:*ValidTestChars} )

	local -a Results=()
	for T ( $Tests ) {
		local Res=0
		eval "if [[ ! -${T} $Value ]] {
			__@verbose "\"-${T}: failed for $Value\""
			Res=1
		};"
		$Verbose && {
			Results+=( $T $Res )
		} || {
			Results+=( $Res )
		}
	}

	$Verbose && {
		(( $#InvalidArgs )) && {
			print "Invalid Tests: ${InvalidArgs}"
		}
		
		print -C $(( $#Results / 2 )) $Results
	} || {
		print $Results
	}
}


@validate "$@"

} "$@"
