function @files:compare  {
	local -a Files=("$@")
	local -aU Unique Duplicates
	while (( #Files )) {
		local BaseFile=""
		until [[ -e $BaseFile ]] {
			local BaseFile=$Files[1]; Files=(${Files[2,-1]})
		}
		local Output=("${(@AF):-"$(diff -w -q -s --from-file=${BaseFile} ${Files})"}")
		local -a Differ Ident
		local -i FilesIdx DifferIdx IdentIdx; (( FilesIdx = 1 , DifferIdx = 1 , IdentIdx = 1 ))
		: ${(*)${Output}//(#b)(${Files[((FilesIdx++))]}) (differ|)(are identical|)/ ${${match[2]}:+${Differ[((DifferIdx++))]::=${match[1]}}} ${${match[3]}:+${Ident[((IdentIdx++))]::=${match[1]}}}}
		if (( #Files > #Ident )) { Unique+=($BaseFile) ; Files=(${Files:|Ident});  Duplicates+=(${Ident})  }
		if (( #Differ >= #Files )) { Unique+=($BaseFile $Differ) ; Files=(${Files:|Differ}) }
	}
	@debug:print -l -- "Unique Files" ${Unique}
	print -- "$(typeset -p Unique);"
	@debug:print -l -- "Duplicate Files" ${Duplicates}
	print -- "$(typeset -p Duplicates);"
}
