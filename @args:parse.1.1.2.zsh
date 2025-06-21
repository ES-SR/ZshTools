#!/bin/zsh


function __@iterators:arrays:initialize:Iterator_Indices {
        (( ${+Iterator_Indices} )) || {
                declare -HgAx Iterator_Indices         
        }                                                       
}                                                                            
        
function @iterators:arrays:next {   
        local ArrayName=${1:?}
        __@iterators:arrays:initialize:Iterator_Indices
        # Use the global Iterator_Indices for this array's index
        # Increment index, wrapping around to 1 if it exceeds array length   
        print -P - ${${(P)ArrayName}[(( \
                Iterator_Indices[ArrayName] = \
                        Iterator_Indices[ArrayName] + 1 > ${#${(P)ArrayName}} \
                        ? 1 \                  
                        : Iterator_Indices[ArrayName] + 1 \
        ))]}
}

function @iterators:arrays:previous {
        local ArrayName=${1:?}
        __@iterators:arrays:initialize:Iterator_Indices
        # Use the global Iterator_Indices for this array's index
        # Decrement index, wrapping around to array length if it goes below 1
        print -P - ${${(P)ArrayName}[(( \
                Iterator_Indices[ArrayName] = \
                        Iterator_Indices[ArrayName] - 1 < 1 \
                        ? ${#${(P)ArrayName}} \
                        : Iterator_Indices[ArrayName] - 1 \
        ))]}
}

function @iterators:arrays:cycle:forward { 
        local ArrayName=${1:?}
        local -a Array=( ${(P)ArrayName} )

        eval "${ArrayName}=( $Array[2,-1] $Array[1] )"
        #print -P - ${${(P)ArrayName}[1]
}

function @iterators:arrays:cycle:backward {
        local ArrayName=${1:?}                                        
        local -a Array=( ${(P)ArrayName} )                            
                                                                                       
        eval "${ArrayName}=( $Array[-1] $Array[1,-2] )"                                   
        #print -P - ${${(P)ArrayName}[1]}
}

function @iterators:arrays:asIterator {    
        local ArrayName=${1:?}                                        
        alias "${ArrayName}:next"="@iterators:arrays:next ${ArrayName}"       
        alias "${ArrayName}:previous"="@iterators:arrays:previous ${ArrayName}"        
        alias "${ArrayName}:cycle:forward"="@iterators:arrays:cycle:forward ${ArrayName}"  
        alias "${ArrayName}:cycle:backward"="@iterators:arrays:cycle:backward ${ArrayName}"
}


:<<-"EXAMPLE.@iterators:arrays:next+previous+asIterator+:cycle:forward+backward"
	<<| Nums=( {1..5} )
	<<| print -l - $Nums
	>| 1
	>| 2
	>| 3
	>| 4
	>| 5
	<<| @iterators:arrays:asIterator Nums
	<<| Nums:next                        
	>| 1
	<<| Nums:next
	>| 2
	<<| Nums:next
	>| 3
	<<| Nums:previous 
	>| 2
	<<| print -l - $Nums
	>| 1
	>| 2
	>| 3
	>| 4
	>| 5
	<<| Nums:cycle:forward; print -l - $Nums
	>| 2
	>| 3
	>| 4
	>| 5
	>| 1
	<<| Nums:cycle:forward; print -l - $Nums
	>| 3
	>| 4
	>| 5
	>| 1
	>| 2
	<<| Nums:cycle:backward; print -l - $Nums 
	>| 2
	>| 3
	>| 4
	>| 5
	>| 1
EXAMPLE.@iterators:arrays:next+previous+asIterator+:cycle:forward+backward
