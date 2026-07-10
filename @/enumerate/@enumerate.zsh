function @enumerate {                      
	emulate -L zsh; setopt extendedglob
        
	local -a Elements=()
	local VarName                                          
	while [[ -n ${VarName::=${(k)parameters[(I)${1}]}} ]] {
		local -a VarNames=(${(z)VarName})

		for VarName ( $VarNames ) {                  
			[[ ${(Pt)VarName} = *"assoc"* ]] && {   
				Elements+=(${(z)${(ok)${(P)VarName}}//(#m)*/${(q+)MATCH}${(q+)${(P)VarName}[$MATCH]}})                                                     
			} || {
				Elements+=(${${(P)VarName}//(#m)*/${(q+)MATCH}})
			} 
		}

		argv[1]=()                  
	}                                         

	set -- "${(@)Elements}" "${(@)argv}"
	local -a Arr=(${${(e):-{1..$ARGC}}:^argv})

	print -- "${(@)Arr}"
}                        


: <<"Examples.@enumerate"
	@enumerate {a..h}
	@enumerate "(#i)path"
	() {
		local Arg
		for Arg {
			local -a Res=($(@enumerate $Arg))
			print -aC2 -- ${Res[1,8]}
		}
		local -a Res=($(@enumerate "${(@)argv}"))
		print -aC2 -- ${Res[1,18]}

		local -a Array=( one two options four )
		@enumerate $Array
		@enumerate Array five six
	} path options
Examples.@enumerate
