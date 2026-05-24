
function @bits:countSet {
        emulate -L zsh; setopt typesetsilent
        
        local Val
        for Val {
                local -i2 V
                Val="${Val#(-|)2\#}"
                Val="2#${Val}"
                (( V = Val ))
                local I=0
                while (( V )) {
                        (( V &= ( V-1 ) ))
                        (( I++ ))
                }
                print $I 
        }
}


:<<"Examples.@bits:countSet"
	Args=(); for A ( {1..10} ) { Args+=( ${(j..)$(@numbers:random:range 0,1 $(@numbers:random:range 0,16) )} ) }
	print -C2 -- $(@style 12 Arg) $Args $(@style 12 Result) $(@bits:countSet ${Args})
Examples.@bits:countSet

