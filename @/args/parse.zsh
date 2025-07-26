#!/bin/zsh
##  parse.zsh

## default argument-pattern builder
######
function @args:parse:gerneratePattern {
	local Word="${(b)1:?}"                      
	local ShortFlag="(-|--)["$(  \            
		<<< ${(j.(-|).)$(               
			for P ( ${(As.-.)Word} ) {
				<<< "(#i)${P[1]}" \
			}
		)} \                            
	)"]"              
	local LongFlag="(-|--|)"$(  \
		<<< ${(j.(-|).)$(                  \
			for P ( ${(As.-.)Word} ) {
				<<< "(#i)${P}" \
			}
		)} \       
	)            
    
	local PATTERN="($LongFlag)|($ShortFlag)"
	print -- $PATTERN                                               
}

### Initial combined parsing function -- no value extraction yet
function __@args:parse_v1 {     
	declare -a Args=( "${(z@)1}" )        
	declare -a FlagNames=( ${(b)@[2,-1]} )
  
	for FN ( ${FlagNames} ) {                                   
		local -a Match=()
		local -i C=0              
		while (( $C <= $#Args )) {                                        
			Match+=(
				${(*Aw)Args[(wn.((C+=1)).r)$(@args:parse:gerneratePattern $FN)]} )
			}
			# method 1
			eval "${FN}=( ${Match} )"
			typeset -p $FN
		}
		# method 2
		#print -l -- ${${FlagNames}//(#m)(*)/${MATCH}:${(P)MATCH}}

		# updating script args
		declare -a MatchedArgs=( ${(z)${FlagNames}//(#m)(*)/${(P)MATCH}} )
		declare -a CleanedArgs=( ${Args:|MatchedArgs} )
		print -- "argv=( $CleanedArgs )"
}
alias @args:parse_v1="__@args:parse_v1 \"\${argv}\""

:<<-"EXAMPLE.__@args:parse_v1"
	function @test:argParseUse {
		@print:pel:cascade Before
		print -l -- "$@" | bat -n
		eval "$(@args:parse_v1 Verbose)"
		@print:pel:cascade After
		print -l -- "$@" | bat -n
	}
	@test:argParseUse -a --list --A no-match List Verbose add
	
	function @test:argParseUse {
		@print:pel:cascade Before
		print -l -- "$@" | bat -n
		eval "$(@args:parse_v1 List ADD)"
		@print:pel:cascade After
		print -l -- "$@" | bat -n
	}
	@test:argParseUse -a --list --A no-match List Verbose add
	
	............................................. Before .............................................
		1 -a
		2 --list
		3 --A
		4 no-match
		5 List
		6 Verbose
		7 add
	.............................................. After .............................................
		1 -a
		2 --list
		3 --A
		4 no-match
		5 List
		6 add
	............................................. Before .............................................
		1 -a
		2 --list
		3 --A
		4 no-match
		5 List
		6 Verbose
		7 add
	.............................................. After .............................................
		1 -a
		2 no-match
		3 Verbose
EXAMPLE.__@args:parse_v1

## set a bool value based on if a argument matches a patter
######
function @args:bool {                         
	local Args=( ${(P)1:?} )	#copy of arguments to parse passed by name
	local FlagName=${${2:?}//-/_}	#replace - with _ as - is not legal in variable names but common in flag names
	eval $(@args:word2pattern $FlagName)	#set PATTERN to the pattern generated for FlagName
	local ${FlagName}=${${${(M)Args##${~PATTERN}}:+true}:-false}	#create flagname var and set it to true or false
	typeset -p ${FlagName}	#ouput for eval to create the variable with bool value based on matched or not
	unset PATTERN	#dont pollute the namespace 
	#TODO:update to check for pattern and use instead of creating default. 
	#the updated arg parse functions unset pattern, so if it exists then it was set by the user and the
	#custom pattern should be used rather than building and using default still should unset pattern
}


	:<<-'EXAMPLE.@args:bool'
		<<| ExampleArgs=( some localport args --Local-Port here -V and local-Port more -lpmh )
		<<| @args:bool ExampleArgs verbose                                                    
		> typeset verbose=true
		<<| ($verbose) \                                                                   
		<<| 	&& {
		<<| 		echo "do this if verbose=true"
		<<| 	} || {
      		<<| 		echo "do this if verbose=false"
		<<|	}
		> do this if verbose=true
		<<| ExampleArgs=( some localport args --Local-Port here and local-Port more -lpmh ) #remove -V
		<<| eval $(@args:bool ExampleArgs verbose)
		<<| ($verbose) \                                                                   
		<<| 	&& {
      		<<|		echo "do this if verbose=true"
		<<| 	} || {
		<<| 		echo "do this if verbose=false"
		<<|	}
		> do this if verbose=false
	EXAMPLE.@args:bool


## extract value following a " " (space) or "=" (equal sign) of argument matching a pattern
######
function @args:value {               
	local Args=( ${(P)1:?} )
	eval $(@args:word2pattern ${2:?})
	Args=( ${(z)Args//=/ } )
	local Vals=()
	while [[ FoundIdx=${Args[(i)${~PATTERN}]} -lt $#Args ]] {
		Vals+=( ${Args[$FoundIdx,$((FoundIdx+1))]} )
		Args=( ${Args[0,$((FoundIdx-1))]} ${Args[$((FoundIdx+2)),-1]} )
	}
	unset PATTERN
	eval "local -A ${2}=( $Vals )"
	print -n  "$(typeset -p ${2});\n$(typeset -p Args)\n"
}


	:<<-"EXAMPLE.@args:value"
		<<| ExampleArgs=( some value=2 localport args -V 3 --Local-Port here and --value 4 local-Port more -lpmh )
		<<| @args:value ExampleArgs value
		> typeset -A value=( [--value]=4 [-V]=3 [value]=2 );
		> typeset -a Args=( some localport args --Local-Port here and local-Port more -lpmh )
		<<| eval $(@args:value ExampleArgs value)
		<<| print -aC2 - ${(kv)value}; print "==========================="; print -l - $Args
		> -V       3
		> value    2
		> --value  4
		> ===========================
		> some
		> localport
		> args
		> --Local-Port
		> here
		> and
		> local-Port
		> more
		> -lpmh
		<<| 
	EXAMPLE.@args:value



## display output of a function when an argument matches a pattern
######

function args:patternMatch:functionOutput {
  <<< ${${(*M)@##${~PATTERN}}:+$(eval "${OUTPUT_FUNCTION}")}
}

:<<-'EXAMPLE.args:patternMatch:functionOutput'
	<< PATTERN='((-|--)([hH](elp|))|((-|--|)([hH]elp)))'
	<< function testHelp {
  <<   cat<<-'EOF'
  <<     test help
  <<     output
  <<   EOF
  << }
  << OUTPUT_FUNCTION='testHelp'
  << args:patternMatch:functionOutput -h two help 4 -H Help seven --help 9 --Help
  > test help output
  << args:patternMatch:functionOutput 1 two 3 4 5 6 seven 8 9
	>
EXAMPLE.args:patternMatch:functionOutput

