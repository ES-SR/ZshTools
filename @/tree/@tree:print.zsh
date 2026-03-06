function @tree:print {
        emulate -L zsh; setopt extendedglob typesetsilent nosourcetrace

        @args:parse Level:+ Range:+ Node:+

        function __Level {
                emulate -L zsh
                local Arg
                for Arg {
                        local NodesAtDepth=$(( 2 ** (Arg-1) ))
                        local FirstNodeAtDepthIdx=$(( NodesAtDepth - 1 ))
                        print -a -- ${${(P)TreeName}:$FirstNodeAtDepthIdx:$NodesAtDepth}
                }
        }
        function __Range {
                emulate -L zsh
                local -i Start End
                for Start End ( $@ ) {
                        print -a -- ${${(P)TreeName}[$Start,$End]}
                }
        }

        local TreeName=${1:?}

        (( ${#Level} )) && {
                __Level $Level
        }
        (( ${#Range} )) && {
                (( ${#Range} % 2 )) && { Range=(1 $Range) }
                __Range $Range      
        }


        (( ${#Level} + ${#Range} + ${#Node} )) || {
                local -i Size=${#${(P)TreeName}} I=0 FirstNodeAtDepthIdx=0
                while (( Size > 0 )) {
                        __Level $(( ++I ))
                        (( Size -= (2 ** I) ))
                }
        }
}


:<<"Examples.@tree:print"
	declare -a Tree            
	declare -i2 -Z34 TreePath=1
	Tree[$TreePath]=RootNode   
	@tree:print Tree
	#> RootNode
	Enterprise% (( TreePath <<= 1 ))                
	Enterprise% print $TreePath 
	2#00000000000000000000000000000010
	Enterprise% Tree[$TreePath]=level2  
	Enterprise% @tree:print Tree      
	#> RootNode
	#> level2
	(( TreePath += 1 ))   
	Tree[$TreePath]=level2Node2
	(( TreePath <<= 1 ))  
	Tree[$TreePath]=level3
	(( TreePath <<= 1 ))  
	Tree[$TreePath]=level4
	@tree:print Tree      
	#> RootNode
	#> level2 level2Node2
	#> level3
	#> level4
Examples.@tree:print
