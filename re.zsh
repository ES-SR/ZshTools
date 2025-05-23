#!/usr/bin/zsh
##  re.zsh
###   shell regex commands



() {


## the subcommand functions
function __sub {	
	if [[ $# -eq 0 ]] { return }	# done processing
	if [[ $# -lt 2 ]] { return 1 }	# wrong number of args 
	#* can use modulo for a one time check before run. as is will recurse
		# and then finally fail on the last one
	
	local Pat="${1}"
    	local Replace="${2}"
	shift 2

	WorkingText=(
		"$(awk			\
			-v PAT="${Pat}"			\
			-v REPLACE="${Replace}"		\
  			'
			{
	  			gsub( PAT, REPLACE ) 
	  			print $0
			}
		' <<< ${(F)WorkingText}	\
		2>/dev/null)"
	)
      __sub "$@"
}
  
function __rm {
	if [[ $# -eq 0 ]] { return }	#done processing
	#if [[ $# -lt 1 ]] { return 1 } #because only one arg is needed, only exit when $# is zero

	local Pat="${1}"
	shift

	WorkingText=(
		"$(awk			\
			-v PAT="${Pat}"		\
			'
			{
				gsub( PAT, "" )
				print $0
			}       
		' <<< ${(F)WorkingText}	\
		2>/dev/null)"
	)

	__rm "$@"
}
  
function __has {
	if [[ $# -eq 0 ]] { return }	# done processing

	local Pat="${1}"
	shift

	local HAS=$(	\
		awk '
			BEGIN {
				HAS = "false"
			}

			/'${Pat}'/ {
				HAS = "true"
				exit
			}

			END {
				print HAS
			}       
		' <<< ${(F)WorkingText}	\
 		2>/dev/null			\
	)

	( $HAS ) || { return 1 }

	__has "$@"
}
  
function __match {
	if [[ $# -eq 0 ]] { return }	# done processing

	local Pat="${1}"
	shift
	
	WorkingText=( 
		"${(@f)$(awk '/'${Pat}'/' <<< ${(F)WorkingText} 2>/dev/null)}"
	)

	__match "$@"
}

function getPipedInput {
	if [[ -p /dev/stdin ]] {
		typeset -ga OriginalText=( "${(@f)$(read -u 0 -d EOF -sre)}" )
	}
}
 
# the main function
function __re {
	getPipedInput
	typeset -ga WorkingText=( ${OriginalText} )
	
	local SubCmdPat=":(rm|sub|has|match)"
	local -a SubCommands
	local ArgCp=( "$@" )
	while [[ -n ${(M)ArgCp#${~SubCmdPat}} ]] {
		I=${ArgCp[(I)${~ArgCp[(R)${~SubCmdPat}]}]}
		local SC="${ArgCp[$I]/:/__} ${(@q)ArgCp[((I + 1)),-1]}"
		SubCommands=( $SC $SubCommands )
		if [[ $I -eq 0 ]] { break } # in case of bad arguments
		ArgCp=( ${ArgCp[1,((I-1))]} )
	}

	for SC ( $SubCommands ) {
		eval $SC
		if [[ $? -ne 0 ]] {
			break
		}
	}
	<<< ${(F)WorkingText}
	set +x
}

__re  "$@"

} "$@"

