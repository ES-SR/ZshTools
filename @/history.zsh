function @history {
	emulate -L zsh
	setopt extendedglob
	(( DEBUG )) && {
		exec 3>&2
		set -x
	} || {
		exec 3>/dev/null
	}

	local -x Split
	local -ax SplitParts=(
		$'\u0000'  # NUL
		$'\u0001'  # SOH
		$'\u0002'  # STX
		$'\u0003'  # ETX
		$'\u001D'  # Group separator
		$'\u001E'  # Record separator
		$'\u001F'  # Unit separator
		$'\u2007'  # figure space
		$'\u2008'  # punctuation space
		$'\u2009'  # thin space
		$'\u200A'  # hair space
		$'\u2011'  # non-breaking hyphen
	)
	function __@history:genSplit {
		local Len=${1:-$(( RANDOM % 10 + 5 ))}

		for I ( {1..$Len} ) {
			Split+="${SplitParts[$RANDOM%$#SplitParts+1]}"
		}
	}

	__@history:genSplit

	local FilterPattern=\*\(${(j.)|(.)@}\)\*

	(( SAFEMODE )) && {
		local HistContent="$(fc -ln 1)"
		while [[ "$HistContent" == *"$Split"* ]] {
			__@history:genSplit 1
		}
	}

	print -u3 ${(V)Split}
	declare -gA History=(${(Aps.$Split.):-"$(fc -ln -t ${Split}"%s"${Split} -m "${FilterPattern}" 1)"})
}
