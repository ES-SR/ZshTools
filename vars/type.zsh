#!/bin/zsh

() {


autoload -Uz @vars:type
function @vars:type {
  local VarName=${1:?}
  local Declaration=( ${(*M)$(
    typeset -p $VarName 2>/dev/null
    (( $? )) && echo -N
  )##-[AaN]##} )
  print - ${${Declaration:s/-A/AssociativeArray/:s/-a/Array/:s/-N/NotSet}:-Scalar}
}


@vars:type "$@"
}

:<<-"Example.@vars:type"
  typeset TStr; typeset -a TArr; typeset -A TAA
  @vars:type TStr; print $?
  @vars:type TArr; print $?
  @vars:type TAA; print $?
  @vars:type NotSet; print $?
Example.@vars:type
