#!/bin/zsh
##  @options:names.zsh
###   Zsh Options management helper


() {
emulate -L zsh
options[extendedglob]=on
options[multifuncdef]=on

	autoload -Uz @options:names @OptNames
	function @options:names @OptNames {
		local Key=${1:-All}
		Key=${(*)OptNames[(i)(#i)*${~Key//_/}*]}
		if [[ -z $Key ]] {
			print - "No key ${(q+)Key} found"
			return 1
		}
		print - ${(s.:.)OptNames[$Key]}
	}

	autoload -Uz @options:names:filter
	function @options:names:filter {
		local Pattern=${(bQ)OptNames[Filter]}
		print - ${(ok)options[(I)${~Pattern}]}
	}

	autoload -Uz @options:names:filter:set
	function @options:names:filter:set {
		local Pattern=${(bQ)1:?please provide a pattern to set}
		OptNames[Filter]=${Pattern}
	}

	autoload -Uz @options:names:filter:add
	function @options:names:filter:add {
		local FilterName=${1:?please provide a name for the filter}
		local Pattern=${(bQ)OptNames[Filter]}
		local Names=( $($OptNames[filter]) )
		(( $#Names )) || {
			print - "not adding filter with no results"
			return 1
		}
		OptNames[$FilterName]=${(j.:.)Names}
	}

	declare -Agx OptNames=(
		[All]=${(j.:.ok)options}
		[History]=${(j.:.)${(*o)options[(I)*hist*]}}
		[Glob]=${(j.:.)${(*o)options[(I)*glob^(al)*]}}
		[Prompt]=${(j.:.)${(*o)options[(I)*prompt*]}}
		[Local]=${(j.:.)${(*o)options[(I)*local*]}}
		[Braces]=${(j.:.)${(*o)options[(I)*brace*]}}
		[Ksh]=${(j.:.)${(*o)options[(I)*ksh*]}}
		[Csh]=${(j.:.)${(*o)options[(I)*csh*]}}
		[Function]=${(j.:.)${(*o)options[(I)*func*]}}
		[Error]=${(j.:.)${(*o)options[(I)*err*]}}
		[Auto]=${(j.:.)${(*o)options[(I)*auto*]}}
		[List]=${(j.:.)${(*o)options[(I)*list*]}}
		[Bash]=${(j.:.)${(*o)options[(I)*bash*]}}
		[Posix]=${(j.:.)${(*o)options[(I)*posix*]}}
		[Directories]=${(Aj.:.)${(*ok)options[(I)*(dirs|cd|pushd)*]}:#*func*}
		[Filter]=\*
		[filter]=@options:names:filter
		[setFilter]=@options:names:filter:set
		[addFilter]=@options:names:filter:add
	)

}

:<<-"Examples.@options:names"
	% @OptNames Ksh
	ksharrays kshautoload kshglob kshoptionprint kshtypeset kshzerosubscript

	% OptNames[Filter]=\*warn\*
	% $OptNames[filter]
	mailwarn mailwarning warncreateglobal warnnestedvar

	% @options:names:filter:add Warn
	% @OptNames Warn
	mailwarn mailwarning warncreateglobal warnnestedvar

	% @options:names func
	aliasfuncdef functionargzero histnofunctions multifuncdef
Examples.@options:names
