
() {

function @mounts:type {
	emulate -L zsh; options[extendedglob]=on

	local -A Mounts=(${(z)"${(Af@)$(mount)}"//(#b)*on ([^[:space:]]#) type ([^[:space:]]#) */"${match[1]}" "${match[2]}"})
	#print -aC2 -- ${(kv)Mounts}

	local -a Types=("${(@)argv}")
	local TypePattern="(#i)(#s)(${(j.)|(.)Types})*"
	local K V
	for K V ( ${(kv)Mounts} ) {
		if [[ ${V} = ${~TypePattern} ]] { #"nfs"<-> ]] {
			print -- $K
		}
	}
	
}


function __@sfx:recurse {
	emulate -L zsh; setopt extendedglob typesetsilent

	local -a RemoteDirRoots=($(@mounts:type nfs\[34\]))
	local StartPath=${${1%.sfx}:-.}

	@sfx:recurse ${StartPath}
}

function @sfx:recurse {
	emulate -L zsh; setopt extendedglob typesetsilent
	[[ -z ${(M)funcstack:#__$0} ]] && {
		__@sfx:recurse $@
		return
	}
	local Path=${1%.sfx}
	Path=${Path//(#s).(#e)/$(pwd)}
	print -- $Path
	local -aU Children=(${Path:A}/*(N/F))
	Children=(${Children:|RemoteDirRoots})
	local Child
	for Child ( "${(@)Children}" ) {
		# the $Child.sfx method is not working when script is sourced automatically
		## but it works if sourced interactively - searching for a workaround. not
		## needed as standard recursion works, but i still want to find one
		@sfx:recurse ${Child:A}
	}	
}
alias -s sfx=@sfx:recurse

}

