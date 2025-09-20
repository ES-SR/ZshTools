#!/usr/bin/env zsh
##  @script:inputDetails


() {


	autoload -Uz @script:inputDetails
	function @script:inputDetails {
		if [[ -p /dev/stdin ]] {
			print "[&0] /dev/stdin: Pipe"
		}

		local Args=( "$@" )
		local Type
		local -i ArgPos=0
		for A ( ${Args} ) {
			(( ArgPos++ ))
			print -n "[${ArgPos}] "
			if [[ -p "$A" ]] {
				print "FD : ${A}"
				continue
			}

			Type=${${(As.: .)="$(type -w ${(P)A} 2>/dev/null)"}[2]} \
			|| Type=${${(As.: .)="$(type -w $A 2>/dev/null)"}[2]} \
			|| Type=$(print ${(tP)A})
			if [[ -z $Type ]] {
				Type=$(print ${(t)A})
			}
			print -n ${Type}${Type:+" : $A\n"}
		}
	}


	@script:inputDetails "$@"
} "$@"


:<<-"Examples.@script:inputDetails"
	% source @/script/@script:inputDetails.zsh
	% Arr=( {1..4} )
	% echo "hello" | @script:inputDetails <( echo "hello" )  "$Arr" Arr ${(A):-"${options[(I)*pushd*]}"} echo "no more args"
	[&0] /dev/stdin: Pipe
	[1] FD : /proc/self/fd/12
	[2] array-special : 1 2 3 4
	[3] array : Arr
	[4] scalar : pushdignoredups autopushd pushdminus pushdtohome pushdsilent
	[5] builtin : echo
	[6] scalar : no more args
Examples.@script:inputDetails
