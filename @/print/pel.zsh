#!/bin/zsh

() {


function @print:pel {
  local Content=${@[-1]:-"."}
  local argv=( ${@:#${@[-1]}} )
  local C=$Content
  local PaddingChars=${1:-${${(*M)Content##[^a-zA-Z0-9]##}:-" "}}
  PaddingChars=( ${(s.,.)PaddingChars} )
  local PCL=${PaddingChars[1]}
  local PCR=${${PaddingChars[2]}:-${PCL}}
  local MarginChars=${2:-"${${${(*M)PCL##[^a-zA-Z0-9 ]##}[1]}:-.},${${${(*M)PCR%%[^a-zA-Z0-9 ]##}[-1]}:-.}"}
  MarginChars=( ${(s.,.)MarginChars} )
  local MCL=${MarginChars[1]}
  local MCR=${${MarginChars[2]}:-${MCL}}
  local Justify=${3:-1}
  Justify=( ${(s.,.)Justify} )
  local -i JL="${Justify[1]}"
  local -i JR="${${Justify[2]}:-${JL}}"
  (( JL = JL * COLUMNS / ( JL + JR ) ))
  (( JR = COLUMNS - JL ))
  print -P -- ${(pel.((JL))..$MCL..$PCL.r.((JR))..$MCR..$PCR.)C}
}


@print:pel "$@"

} "$@"

alias @print:center='@print:pel \  \  1,1 '
alias @print:right='@print:pel \  \  1,0 '
alias @print:left='@print:pel \  \  0,1 '
alias @print:header:main='@print:pel "[ , ]"  =  1,1 '
alias @print:header:sub='@print:pel "| , |"  -  1,4 '
alias @print:header:right='@print:pel ": , :"  " ,-"  2,1 '


:<<-"Examples.@print:pel"
	<
	  alias @print:main='@print:pel:cascade:v2  "[ "," ]" = '
	  alias @print:sub='@print:pel:cascade:v2 "| "," |" \ -,-\  1,5'
	  alias @print:right='@print:pel:cascade:v2 "| , :" \ ,-  2,1'
	  alias @print:content:right='@print:pel:cascade:v2 \  \  5,1'
	<
	  @print:main "Main Section"
	  @print:sub "First Subsection"
	  print - "some content in first subsection"
	  @print:right "Minor Section"
	  @print:sub "Second Subsection"
	  print - "some content in second subsection"
	> ===================================[ Main Section ]====================================
	> main section content
	> - - - -| Sub Section |- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	> sub section content
	>                                                       | minor :------------------------
	>                                                            less important information
	> - - - -| Sub Section |- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	> sub section content
Examples.@print:pel
