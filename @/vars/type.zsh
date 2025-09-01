#!/bin/zsh

() {


autoload -Uz @vars:type
function @vars:type {
	local VarName=${1:?}
	local Declaration=( ${(*M)$(
		typeset -p $VarName 2>/dev/null
		(( $? )) && echo NotSet
	)##((-[AaT](T|))|(NotSet))##} )

	Declaration=${Declaration:s/-aT/TiedArray/:s/-T/TiedString/}
	Declaration=${Declaration:s/-A/AssociativeArray/:s/-a/Array/}
	Declaration=${Declaration:-Scalar}

	print - $Declaration
}


}


:<<-"Example.@vars:type"
	<
		typeset Str; typeset -a Arr; typeset -A AA; typeset -T TStr TArr;
		@vars:type Str
		@vars:type Arr
		@vars:type AA
		@vars:type TStr
		@vars:type TArr
		@vars:type NotSet
	>
		Scalar
		Array
		AssociativeArray
		TiedString
		TiedArray
		NotSet
Example.@vars:type
