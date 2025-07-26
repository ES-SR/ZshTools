function @util:zsh:options:printStatusColor {
	zmodload zsh/nearcolor

	local -A FgColors=( [on]='#00FF00' [off]='#FF0000' )
	local -a BgColors=( '#000000' '#121212' )

	print -c ${(*%)${(ok)options}//(#m)(*)/"%K{${BgColors[((C=((C+1)%2)))+1]}} %F{${FgColors[${options[${MATCH}]}]}}${MATCH}%E%f"}   

	print -nP "%k" 
}
