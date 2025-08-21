#!/bin/zsh


autoload -Uz @options:printStatus:compact
function @options:printStatus:compact {
	local -A Options=( ${(kv)options} )
	local Pattern=${1:-"*"}

	emulate -L zsh
	options[extendedglob]=on

	local -a Filtered=( ${(ok)Options[(I)${~Pattern}]} )
	
	zmodload zsh/nearcolor
	local -A Fg=( [on]='#00FF00' [off]='#FF0000' )
	local -a Bg=( '#000000' '#121212' )
	
	local -A DI=(
		$(@term:display:columns:updateInfo ${(o)Filtered})
		Bg $Bg[1]
		Fg ""
		Cnt 0
		CurrCol 0
		CellSfx ""
		CellPfx ""
		LBuf 0
		RBuf 0
		NLBgNxt 0
	)
	DI[LBuf]=$(( DI[ColWidth] / 2 ))
	DI[RBuf]=$(( DI[ColWidth] - DI[LBuf] ))
	DI[NLBgNxt]=$(( DI[ColCount] % 2 ))

	local -A CellPfx=(
		[0]='%K{<BG>}%F{<FG>}'
		[1]='%K{<BG>}%F{<FG>}'
		["${DI[ColCount]}"]='%K{<BG>}%F{<FG>}'
	)
  local -A CellSfx=(
		[0]='%f%k%E'
		[1]='%f%k%E'
		["${DI[ColCount]}"]='%f%k\n'
	)

	function DI:next {
		(( DI[Cnt]++ ))
		local -i Cnt=$DI[Cnt]

		local OptName=$Filtered[$Cnt]
		local OptVal=$Options[$OptName]

		DI[Bg]=${Bg:#${DI[Bg]}}
		DI[Fg]=$Fg[$OptVal]

		local CurrCol=$(( ( ( Cnt - 1 ) % DI[ColCount] ) + 1  ))
		DI[CurrCol]=$(( CurrCol ))

 		(( DI[NLBgNxt] + CurrCol - 1 )) || {
			DI[Bg]=${Bg:#${DI[Bg]}}
		}
		DI[CellPfx]=${${CellPfx[$CurrCol]}:-${CellPfx[0]}}
		DI[CellPfx]=${DI[CellPfx]//<BG>/${DI[Bg]}}
		DI[CellPfx]=${DI[CellPfx]//<FG>/${DI[Fg]}}

		DI[CellSfx]=${${CellSfx[$CurrCol]}:-${CellSfx[0]}}
		print -nP - "${DI[CellPfx]}${(pel.${DI[LBuf]}.r.${DI[RBuf]}.)OptName}${DI[CellSfx]}"
		DI[CellPfx]="%K{${DI[Bg]}}%F{${DI[Fg]}}"
  }
	#functions -T DI:next

	while [[ $DI[Cnt] -lt $#Filtered ]] {
		DI:next
	}
	print -nP "%k%E"$'\n'
}

autoload -Uz @options:printStatus
function @options:printStatus {
	local -A Options=( ${(kv)options} )
	local Pattern=${1:-"*"}

	emulate -L zsh
	options[extendedglob]=on

	zmodload zsh/nearcolor
	local -A Fg=( [\ on]='#00FF00' [\ off]='#FF0000' )
	local -a Bg=( '#000000' '#121212' )
	function nextBgColor {
		Bg=( $Bg[2,-1] $Bg[1] )
	}

	local -A Filtered=( ${(kv)Options[(I)${~Pattern}]} )
	local -a Opts
	: ${(Af)Opts::="$(print -aC2 - ${(kv)Filtered})"}
	local -a Output
	: ${(Af)Output::="$(print -Pc - ${(o)Opts//(#m)( (on|off))/%F{${Fg[$MATCH]}}$MATCH%f})"}

	for L ( ${Output} ) {
		print -P - "%K{${Bg[1]}}${L}%E%k"
		nextBgColor
	}
}
