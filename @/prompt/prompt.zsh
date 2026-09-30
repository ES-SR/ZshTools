function @prompt:length {
	emulate -LR zsh -o extendedglob -o promptsubst

	local -i X Y=${(c)#argv} M
	(( Y )) && {
		while (( ${${(%):-${argv}%${Y}(l.1.0)}[-1]} )) {
			(( X = Y ))
			(( Y *= 2 ))
		}
		while (( Y > X + 1 )) {
			(( M = X + ( Y - X ) / 2 ))
			(( ${${(%):-${argv}%${M}(l.X.Y)}[-1]} = M  ))
		}
	}
	print $X
}

function @prompt {
	emulate -L zsh -o extendedglob -o typesetsilent -o promptsubst

	declare -gxA PromptVars=(
		Dir '%d'
		Time '%T'
		NL $'\n'
		Hist ''
		Keymap ''
		Lines 0
	)

	local -a PromptLineVars=("${(s. , .)${(@)argv//(#m)*/"${(q)MATCH}"}}")
	local -a PromptLines

	local LineVars LineNumber=1
	for LineVars ( "${(@)PromptLineVars}" ) {
		local Line=""
		local LV
		for LV ( "${(z)LineVars}" ) {
			[[ -v PromptVars["${LV}"] ]] && {
				Line+=$'${'PromptVars$'['"${LV}"$']}'
			} || {
				Line+="${(Q)LV}"
			}
		}
		PromptVars+=( $LineNumber "${Line}" )
		(( LineNumber++ , PromptVars[Lines]+=1 ))
	}

	function zle-line-init {
		emulate -L zsh -o extendedglob -o typesetsilent -o promptsubst

		@prompt:update
	}

	function zle-keymap-select {
		local Keymap="${KEYMAP}"
		local -A Style=(
			COMMAND "%K{#FF0}%F{#000}"
			INSERT "%K{#0F0}%F{#000}"
			ERROR "%K{#F00}%F{#000}"
		)

		Keymap="${Keymap:s/vicmd/COMMAND/:s/viins/INSERT/:s/main/INSERT/}"

		PromptVars[Keymap]="${Style[$Keymap]}${Keymap:-"---"}"
		@prompt:update
	}

	function zle-history-line-set {
		PromptVars[Hist]="${HISTNO}"
		@prompt:update
	}

	function @prompt:update {
		emulate -LR zsh -o extendedglob -o typesetsilent -o promptsubst

		#print -u2 -Pl -- %F{red} "%Ufuncstack%u" "${(@)funcstack}" %f
		(( $funcstack[(I)${0}] > 1 )) && { return }

		local -a PromptFunctions=(
			zle-history-line-set
			zle-keymap-select
		)
		#print -u2 -Pl -- %F{red} "%UPromptFunctions%u" "${(@)PromptFunctions}" %f
		#print -u2 -Pl -- %F{red} "%UFiltered PromptFunctions%u" "${(@)PromptFunctions:|funcstack}" %f

		local PF
		for PF ( ${PromptFunctions:|funcstack} ) {
			$PF
		}

		local Prompt=''
		local -i LN
		for LN ( {1..${PromptVars[Lines]}} ) {
			local Line="${PromptVars[${LN}]}"

			local RawSpacer='{{SP}}'
			local -a LineArr=(${(ps.$RawSpacer.)Line})
			local -i Spacers=$(( ${#LineArr} > 1 ? ${#LineArr} - 1 : 1 ))
			local -i SpacerSize=$COLUMNS
			local Str
			for Str ( "${(@)LineArr}" ) {
				Str="${(e)Str}"
				local -i Len=$(@prompt:length $Str)
				(( SpacerSize -= Len ))
			}
			(( SpacerSize /= Spacers ))
			local Spacer="\${(l.${SpacerSize}.)}"
			Prompt+="${(pj.$Spacer.)LineArr}"
			(( LN < PromptVars[Lines] )) && {
				Prompt+=$'${'PromptVars$'['NL$']}'
			}
		}
		prompt="${Prompt}"
		zle reset-prompt
		zle -R
	}

	zle -N zle-keymap-select
	zle -N zle-history-line-set
	zle -N @prompt:update
	zle -N zle-line-init
}

@prompt '%K{#222}' '[' Hist ']' '{{SP}}' Dir '{{SP}}' '[' Time ']' '%E%k' , Keymap '{{SP}}' '%E%f%k' NL
