
function @numbers:sort {
  emulate -LR zsh -o extendedglob -o typesetsilent
{ #set -x

  @args:parse "(#s)-(#e)":HighToLow "(#s)+(#e)":LowToHigh "[rR]":Reverse
  set -- "${(@)PositionalArgs}"
  
  (( $#Reverse )) && {
    print -r -- "${(Oa@)argv}"
    return
  }

  (( $#LowToHigh + $#HighToLow )) || {
    print -r -- "${(a@)argv}"
    return
  }

  set -- ${argv//(#m)<->/$((MATCH))}
  local -A IdxdArgs=(${${(e):-{0..$ARGC}}:^argv})
  local Factor=${(-O)${(A)${(M)argv:#*.*}//(#m)*/${#${MATCH#<->.}}}[1]}
  local -a Arr=(${argv//(#m)*/$(( MATCH * 10**Factor ))})
  local -A IdxdArr=(${${(e):-{0..$ARGC}}:^Arr})

  (( $#LowToHigh )) && {
    Arr=(${${(-)Arr}//(#m)*/$(( MATCH / 10**Factor ))})
  } || {
    Arr=(${${(-O)Arr}//(#m)*/$(( MATCH / 10**Factor ))})
  }
  
  print -- ${Arr//(#m)*/${IdxdArgs[${(k)IdxdArr[(r)$((MATCH*10**Factor))]}]}}

} always {
  set +x
} }


