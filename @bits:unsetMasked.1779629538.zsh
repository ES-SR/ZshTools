
function @bits:unsetMasked {
        emulate -L zsh

        local Val Mask
        for Val Mask {
                local -i2 V M                                     
                Val="${Val#(-|)2\#}"                       
                Mask="${Mask#(-|)2\#}"                   
                local Len=${(c)#Val}                       
                Val="2#${Val}"                                   
                Mask="2#${Mask}"                               
                (( V = Val , M = Mask ))               
                local -Z $Len I                                 
                I=$(( [##2] V & ( M ^ -(2**63 + 1) ) ))
                (( V= 2#${I} ))                                 
                print $V                                               
	}
}


:<<"Examples.@bits:unsetMasked"
	Args=( 0 1 00 01 10 11 000 001 010 011 100 101 110 111 0000 0001 0010 0011 0100 0101 0110 1000 1001 1010 1100 1101 1110 1111 )
	Masks=( ${Args//(#m)*/${(j..)=$(@numbers:random:range 0,1 ${(c)#MATCH})}} )
	print -C3 -- $(@style 12 Arg) $Args $(@style 12 Mask) $Masks $(@style 12 Result) $(@bits:unsetMasked ${Args:^Masks})
:<<"Examples.@bits:unsetMasked

