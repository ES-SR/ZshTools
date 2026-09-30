function @assoc:keyValueLines {
  emulate -LR zsh -o extendedglob -o typesetsilent  

  local -a KVLines=()
  local -A AA=()
  
  (( ${#parameters[(I)${1}]} )) && {
    AA=("${(@Pkv)1}")
  } || {
    AA=("${(@)argv}")
  }

  KVLines=(${(Af)"$(print -aC2 -- "${(@kv)AA}")"})
  print -l -- "${(@-o)KVLines}"
}
