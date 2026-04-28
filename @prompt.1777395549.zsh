
	function @prompt {
		setopt promptsubst
		emulate -L zsh; setopt extendedglob

		declare -gA PromptVars=(
			"(#i)(K(eymap|))"					'${psvar[1]}'
			"(#i)(H(ist(ory|)|)(Num(ber|)|))"			'${HISTNO}'
			"(#i)(C(ur(r(ent|)|)|)(W(orking|)|)D(ir(ectory|)|))"	'%d'
			"(#i)(T(ime|))"						'%T'
			"(#i)(L(ast|)R(uturn|))"				'%(?..%F{red}[%?]%f)'
			"(#i)(J(obs|))"						'%1(j.[%j].)'
			"(#i)(N(ew|)L(ine|))"					$'\n'
			"(#i)(I(nput|)M(arker|))"				'<<|'
			"(#i)(F(ixed|)S(pacer|))"				''
			"(#i)(E(xpand|)S(pacer|))"				''
		)

		local -a DefaultSegments=( HistoryNumber NewLine InputMarker Newline )
		local Arg Prompt

		(( ARGC )) && {
			for Arg ( "${(@)argv:-${DefaultSegments}}" ) {
				local Segment="${PromptVars[(k)$Arg]}"
				Arg="${Arg//(#s)(#i)(#b)(s(tyle|))([-_[:space:]]|)(<->|[rR])/"%{\$(@style ${match[4]})%}"}"
				Segment="${Segment:-${Arg}}"
				Prompt+="${Segment}"
			}
		}

		PROMPT="${(Q)Prompt}"

		function zle-keymap-select {
			local Keymap="${KEYMAP}"
			Keymap="${Keymap//vicmd/"%{$(@style 15)%}CMD%{$(@style r)%}"}"
			Keymap="${Keymap//(viins|main)/"%{$(@style 14)%}INS%{$(@style r)%}"}"
			psvar[1]="${Keymap}"
			zle reset-prompt
		}

		function zle-line-init {
			zle reset-prompt
			trap 'zle reset-prompt' WINCH
		}

		function zle-history-line-set {
			zle reset-prompt
		}

		zle -N zle-keymap-select
		zle -N zle-line-init
		zle -N zle-history-line-set
	}

#@prompt S_11 \[ H \] S_r '${(l.COLUMNS-13.)}' S_12 \[ T \] S_r NL '<<' K '|' NL

