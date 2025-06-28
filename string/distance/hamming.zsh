#!/bin/zsh
##  String Hamming Distance Function v1.0

:<<-"DOCS.@string:distance:hamming"
	function documentation here
DOCS.@string:distance:hamming

function @string:distance:hamming {
	local Str1="$1"
	local Str2="$2"
	local StrLen=${#Str1}

	if [[ ${#Str2} -ne ${StrLen} ]] { 
		echo "Error: Strings must have equal length" >&2
		return 1
	}

	local Distance=$StrLen
	for I ( {1..$StrLen} ) {
		(( Distance -= ${(N)Str1[$I]:#${Str2[$I]}} ))
	}
	echo $Distance
}


:<<-"EXAMPLES.@string:distance:hamming"
	Example(s) go here
EXAMPLES.@string:distance:hamming
