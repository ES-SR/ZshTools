#!/bin/zsh
##  String Levenshtein Distance Function v1.0
###   Pure ZSH implementation of string distance algorithms

:<<-"DOCS.@string:distance:levenshtein"
	function documentation here
DOCS.@string:distance:levenshtein

function @string:distance:levenshtein {
	local Str1="$1"
	local Str2="$2"
	local Str1Len=${#Str1}
	local Str2Len=${#Str2}

	# Create matrix using associative array
	local -A CompareMatrix

	# Initialize first row and column
	for I ( {0..$Str1Len} ) {
  	CompareMatrix[$I,0]=$I
	}

	for J ( {0..$Str2Len} ) {
		CompareMatrix[0,$J]=$J
	}

	# Fill the matrix
	for I ( {1..$Str1Len} ) {
		for J ( {1..$Str2Len} ) {
			local Cost=1
			[[ "${Str1[$I]}" = "${Str2[$J]}" ]] && Cost=0

			local Deletions=$((CompareMatrix[$((I-1)),$J] + 1))
			local Insertions=$((CompareMatrix[$I,$((J-1))] + 1))
			local Substitutions=$((CompareMatrix[$((I-1)),$((J-1))] + Cost))

			# Find minimum
			local Min=$Deletions
			[[ $Insertions -lt $Min ]] && Min=$Insertions
			[[ $Substitutions -lt $Min ]] && Min=$Substitutions

			CompareMatrix[$I,$J]=$Min
		}
	}

	echo ${CompareMatrix[$Str1Len,$Str2Len]}
}


:<<-"EXAMPLES.@string:distance:levenshtein"
	Example(s) go here
EXAMPLES.@string:distance:levenshtein
