#!/bin/zsh


() {
emulate -L zsh

	autoload -Uz @term:display:info
	function @term:display:info {
		local Content
		local -A Info=(
			[ItemCount]=$(( $#argv ))
			[TermWidth]=$(( COLUMNS ))
			[TermHeight]=$(( LINES ))
			[MaxLen]=$(( 0 ))
			[ColWidth]=$(( 0 ))
			[ColCount]=$(( 0 ))
			[LineCount]=$(( 0 ))
			[PageCount]=$(( 0 ))
		)

		for Content {
			(( Info[MaxLen]=$#Content>Info[MaxLen]?$#Content:Info[MaxLen] ))
		}

		(( Info[ColWidth]=Info[MaxLen] > 0 ? Info[MaxLen]+2 : Info[TermWidth] ))
		(( Info[ColCount]=Info[TermWidth]/Info[ColWidth] ))
		(( Info[LineCount]=Info[ItemCount]/Info[ColCount] ))
		(( Info[PageCount]=Info[LineCount]/Info[TermHeight] ))

		print - ${(kv)Info}
	}


	@term:display:info "$@"
} "$@"
