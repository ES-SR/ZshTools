
function @bits:not {
	emulate -L zsh
	
	local Val
	for Val {
		local -i2 V
		Val="${Val#(-|)2\#}"
		local Len=${(c)#Val}
		Val="2#${Val}"
		(( V = Val ))
		local -Z $Len Output
		Output=$(( [##2] V ^ -(2**63 + 1) ))
		print $Output
	}
}


:<<"Examples.@bits:not"
	Args=( 0 1 00 01 10 11 000 001 010 011 100 101 110 111 0000 0001 0010 0011 0100 0101 0110 1000 1001 1010 1100 1101 1110 1111 )
	print -C2 -- $(@style 12 Arg) $Args $(@style 12 Result) $(@bits:not ${Args})
Examples.@bits:not

