#!/bin/zsh
##  parse.zsh

## default argument-pattern builder
######
function @args:word2pattern {
	local Word="${(b)1:?}"
	local ShortFlag="(-|--)["$(  \
		<<<                            \
		${(j.][.)$(                    \
			for P ( ${(As.-.)Word} ) {
				<<<                                \
				${(U)P[1]}${(L)P[1]}
			}
		)}                              \
	)"]"
	local LongFlag="(-|--|)"$(  \
		<<<                            \
		${(j.(-|).)$(                  \
			for P ( ${(As.-.)Word} ) {
				<<<                                \
				${P//#[a-zA-Z0-9]/[${(U)P[1]}${(L)P[1]}]}
			}
		)}                              \
	)

	local PATTERN="($LongFlag)|($ShortFlag)"
	typeset -p PATTERN
}

	:<<-'EXAMPLE.@args:word2pattern'
		~% @args:word2pattern local-port-more-hyphens
		> typeset PATTERN='((-|--)[Ll][Pp][Mm][Hh])|((-|--|)[Ll]ocal(-|)[Pp]ort(-|)[Mm]ore(-|)[Hh]yphens)'
		~% ExampleArgs=( some localport args --Local-Port here -V and local-Port more -lpmh )
		~% eval $(@args:word2pattern local-port-more-hyphens)
		~% print -l - ${(M)ExampleArgs##${~PATTERN}}
		> -lpmh
	EXAMPLE.@args:word2pattern


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

