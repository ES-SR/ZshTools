#!/usr/bin/env zsh
##  @script:inputDetails
###   get information on a functions inputs

() {


	autoload -Uz @script:inputDetails
	function @script:inputDetails {
		if [[ -p /dev/stdin ]] {
			print "/dev/stdin: Pipe"
		}

		for A ( "$@" ) {
			pint -n - "${A}: "
			if [[ -p "${A}" ]] {
				print "File Descriptor or Named Pipe"
				continue
			}

			local Type
			Type=${${(As.: .)="$(type -w ${(P)A} 2>/dev/null)"}[2]} \
			|| Type=${${(As.: .)="$(type -w $A 2>/dev/null)"}[2]} \
			|| Type=$(print ${(tP)A})
			if [[ -z $Type ]] {
				Type=$(print ${(t)A})
			}
			print -n ${Type}${Type:+"\n"}
		}
	}


	@script:inputDetails "$@"
} "$@"

:<<-"Examples.@script:inputDetails"
	% Arr=( {1..4} )
	% echo "hello" | @script:input:type <( echo "hello" )  "$Arr" Arr ${(A):-"${options[(I)*pushd*]}"} echo "no more args"
	/dev/stdin: Pipe
	/proc/self/fd/12: FD
	1 2 3 4: array-special
	Arr: array
	pushdignoredups autopushd pushdminus pushdtohome pushdsilent: scalar
	echo: builtin
	no more args: scalar
Examples.@script:inputDetails
