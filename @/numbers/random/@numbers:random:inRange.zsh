#!/usr/bin/zsh
## Random number generator with range support

() {

  autoload -Uz @numbers:random:inRange
  function @numbers:random:inRange {
    emulate -l zsh
    local -a Args=( "${(@)argv}" )

    function __@seed {
      date +%s
    }

    local Pat='<->,<->'
    local RangeIdx=${(*)Args[(I)${~Pat}]}
    local -a Range=( 0 10 )
    (( RangeIdx )) && {
      Range=(${(s.,.)Args[$RangeIdx]})
      Args[$RangeIdx]=()
    }

    local -i Count=${1:-1}
    local -a OutputNums=()
    local Run=""; for Run ( {1..$Runs} ) {
      local -i Num=$(( ( $RANDOM % ( Range[2] - Range[1] + 1 ) ) + Range[1] ))
      OutputNums+=($Num)
    }

    print -- "${(@)OutputNums}"
  }

}
