#!/bin/zsh


autoload -Uz __@tree:unpack:toArray
function __@tree:unpack:toArray {
	local AAName=${1:?}
	local Key=${2:?}
	declare -H __${AAName}__${Key}__Str="${${(P)AAName}[$Key]}"
	declare -Ha __${AAName}__${Key}
	typeset -T __${AAName}__${Key}__Str __${AAName}__${Key}
	typeset -p __${AAName}__${Key}
}


autoload -Uz @tree:new
function @tree:new {
	local AAName=${1:?}
	for K ( ${(Pk)AAName} ) {
		eval "function ${AAName}:${K} {
			eval \$(__@tree:unpack:toArray ${AAName} ${K})
			print -l -- \$__${AAName}__${K}   
		}"
	}
}


:<<-"Example.@tree"
	% NumberArray=( {1..10} )
	% LetterArray=( {A..J} )
	% declare -A LNAA=( ${NumberArray:^LetterArray} )
	% print -aC2 -- ${(A)=${(nk)LNAA//(#m)(*)/$MATCH $LNAA[$MATCH]}}
	1   A
	2   B
	3   C
	4   D
	5   E
	6   F
	7   G
	8   H
	9   I
	10  J
	% @tree:new LNAA
	% LNAA:1
	A
	% LNAA:10
	J
	% LNAA[1]+=":add:more:elements"
	% LNAA:1
	A
	add
	more
	elements
Example.@tree
