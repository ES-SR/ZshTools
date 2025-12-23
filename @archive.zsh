
() {

autoload -Uz @files:content:uniq:get
function @files:content:uniq:get {
	emulate -L zsh; @debug:init

	local -a UniqFiles=(${1})
	for C N {
		local Diff="$(2>/dev/null diff -u ${C} ${N})"
		if [[ -n ${Diff} ]] {
			@debug:print -- "Diff: " "${Diff}"
			UniqFiles+=(${N})
			@debug:print -l -- "UniqFiles:" "${(@)UniqFiles}" ""
		}
	}
	print -l -- ${UniqFiles}
}

autoload -Uz @files:content:uniq:keep
function @files:content:uniq:keep {
	emulate -L zsh; @debug:init
	local -a Args=("${(@)argv}")

	local Interactive=${Args[(r)(#i)(-|--|)interactive|(-|--)i]}
	if (( ${(c)#Interactive} )) {
		Args=(${Args:#$Interactive})
	}
	Interactive=${${Interactive:+1}:-0}

	local -a Files=("${(@)Args}")
	local -a UniqFiles=($(@files:content:uniq:get "${(@)Files}"))
	local -a RemoveFiles=(${Files:|UniqFiles})
	if (( $#RemoveFiles )) {
		print -u2 -Pl -- "%K{#F00}%F{#000} removing files %E" "${(@)RemoveFiles}%E%f%k"
		if (( Interactive )) {
			local Response
			read -qs "?remove the files? [y|n]: " Response
			print ""
			if [[ $Response != [yY] ]] {
				print -P -- %K{#0FF}%F{#000} not removing any files %f%k
				return
			}
		}

		print -P -- %K{#FF0}%F{#000} removing the files %f%k
		rm ${(@)RemoveFiles} && print -P -- %K{#0F0}%F{#000} removed the files %f%k
	}
}

autoload -Uz @archive
function @archive {
	emulate -L zsh; options[extendedglob]=on; @debug:init
	local -a Args=("${(@)argv}")

	local -A ModePatterns=(
		'(#i)((-|--|)copy|(-|--)c)(:*|)' COPY
		'(#i)((-|--|)move|(-|--)m)(:*|)' MOVE
		'(#i)((-|--|)list|(-|--)l)(:*|)' LIST
		'(#i)((-|--|)(remove((-|)redundant|)|uniq))|((-|--)((r(-|)(r|))|u))(:*|)' UNIQ
		'(#i)--fail' FAIL
		'(#i)--succeed' SUCCEED
	)
	local -A ModeCmds=(
		COPY 'cp ${(ez)Opts} ${(e)F} ${(e)Destination}'
		MOVE 'mv ${(ez)Opts} ${(e)F} ${(e)Destination}'
		LIST 'eza ${(ez)Opts} ${(e)ArchiveFilePath}'
		UNIQ '@files:content:uniq:keep ${(ez)Opts} ${(e)OrderedFiles}'
		FAIL 'print -u2 -P -- %K{#F00}%F{#000} [failed] File: ${(e)F} - ${(e)ErrMsg} %f%k'
		SUCCEED 'print -u2 -P -- %K{#0F0}%F{#000} [success] File: ${(e)F} - ${(e)ScsMsg} %f%k'
	)

	declare -a Modes=() ; declare -a CmdOpts=()
	declare -i I=1
	: ${Args//(#m)(*)/${ModePatterns[(k)$MATCH]:+${Modes[((I))]::="${ModePatterns[(k)$MATCH]}"} ${CmdOpts[((I))]::="${MATCH}"} ${I::=$((I+=1))}}}

	Args=(${Args:|CmdOpts})
	CmdOpts=(${${CmdOpts}//(#m)(*)/"-${${(*M)MATCH%:*}##:(-|)}"})
	(( $#Modes )) || {
		Modes=( [VERSIONS]="" )
	}

	Args=(${(zs.=.)Args})

	local ArchiveBasePathIdx=${Args[(I)(#i)((-|--|)(dir(ectory|)|path)|(-|--)(d|p))(=*|)]}
	local ArchiveBasePath
	if (( ArchiveBasePathIdx )) {
		ArchiveBasePath=$Args[((ArchiveBasePathIdx+1))]
		Args=(${Args:#$ArchiveBasePath})
		Args=(${Args:#$Args[$ArchiveBasePathIdx]})
	} else {
		ArchiveBasePath=${ModDirs[ArchiveMod]}
	}

	local DryRun=${Args[(r)(#i)((-|--|)(dry|test)((-|)run|)|(-|--)((d((-|)r))|(t((-|)r|))))]}
	(( ${(c)#DryRun} )) && {
		Args=(${Args:#$DryRun})
		DryRun=1
	} || {
		DryRun=0
	}

	@debug:print -l -- \
		"Args:" "${Args}" \
		"DryRun: ${DryRun}" \
		"ArchiveBasePath: ${ArchiveBasePath}" \
		"Modes" "${(@)Modes}" \
		"CmdOpts" "${(@)CmdOpts}"

	for F ( $Args ) {
		(( DryRun )) && {
			print -P -- "%K{#AA0}%F{#000} [DryRun] archiving %U${F}%u %f%k"
		} || {
			print -P -u2 -- "%K{#09F}%F{#000} archiving %U${F}%u %f%k"
		}
		if ! [[ -e $F ]] {
			print -u2 -- "File ${F} was not found, skipping"
			continue
		}

		local FileName=${F:t}
		local Ext=${FileName:e}
		local FileBaseName=${FileName:r}
		local FilePrefix=${(M)FileName#@}
		local -a FilePathParts=(${FilePrefix} ${(s.:.)${FileBaseName#$FilePrefix}})
		local ArchiveFilePath=${ArchiveBasePath}/${(j./.)FilePathParts}
		local ArchiveFilePathExists=0
		if [[ -d $ArchiveFilePath ]] { ArchiveFilePathExists=1 }
		if ! (( ArchiveFilePathExists )) {
			(( DryRun )) && {
				print -P -- "%K{#AA0}%F{#000} [DryRun] \"mkdir -p ${ArchiveFilePath}\" %f%k"
			} || {
				local ErrMsg="failed to make directory ${ArchiveFilePath}"
				local ScsMsg="created directory ${ArchiveFilePath}"
				trap '${(ze)ModeCmds[FAIL]}' ZERR
				mkdir -p ${ArchiveFilePath} || return 1
				${(ze)ModeCmds[SUCCEED]}
			}
		}

		@debug:print -l -- \
		"FileName: ${FileName}" \
		"Ext: ${Ext}" \
		"FileBaseName: ${FileBaseName}" \
		"FilePrefix: ${FilePrefix}" \
		"FilePathParts: ${FilePathParts}" \
		"ArchiveBasePath: ${ArchiveBasePath}" \
		"ArchiveFilePath: ${ArchiveFilePath}"

		local ArchiveFileName=""
		local Destination=""
		local OrderedFiles=(${ArchiveFilePath}/*(Non^/))
		local LatestFile="${OrderedFiles[-1]}"
		if [[ -n $(2>/dev/null diff -u ${F} ${LatestFile}) ]] {
			local -i CreatingDestination=1
			while (( CreatingDestination )) { #probably overkill as name collisions should be very unlikely
				ArchiveFileName=${FileBaseName}.$(date +%s)${Ext:+".$Ext"}
				Destination=${ArchiveFilePath}/${ArchiveFileName}
				if ! [[ -e $Destination ]] {
					CreatingDestination=0
				} else {
					print -u2 -P -- "%K{#FF0}%F{#000} file naming collision. waiting 1 second  %k%f"
					sleep 1 #sleep until date +%s changes / act as rate limiter
				}
			}
		} else {
			local -a RemoveModes=( COPY MOVE )
			Modes=(${Modes:|RemoveModes})
			@debug:print -l -- "Modes:" ${Modes}
			print -u2 -P -- "%K{#FF0}%F{#000} content of ${F} and ${LatestFile} are the same  %k%f"
		}

		@debug:print -l -- \
		"ArchiveFileName: ${ArchiveFileName}" \
		"Destination: ${Destination}"

		local Mode=""
		local Cmd=""
		local Opts=""
		for J ( {0..${I}} ) {
			Mode="${Modes[$J]}";  Cmd="${ModeCmds[$Mode]}"; Opts="${CmdOpts[$J]}"
			if ! (( ${(c)#Mode} )) { continue }
			@debug:print -- "Mode: ${(ze)Mode}"
			@debug:print -- "Cmd: ${(ze)Cmd}"
			@debug:print -- "Opts: ${(ze)Opts}"
			(( DryRun )) && {
				print -P -- "%K{#AA0}%F{#000} [DryRun] \"${Cmd}\" %f%k"
			} || {
				local ErrMsg="failed ${(ze)Cmd}"
				local ScsMsg="${(ze)Cmd}"
				trap '${(ze)ModeCmds[FAIL]}' ZERR
				${(ze)Cmd} \
				|| return 1
				${(ze)ModeCmds[SUCCEED]}
			}
		}
	}
}

}
