#!/bin/zsh

() {
emulate -L zsh

autoload -Uz @vars:debug:info
function @vars:debug:info {
	emulate -L zsh
	options[extendedglob]=on

	# Setup output redirection for debug mode
	(( DEBUG )) && {
		set -x
		exec 3>&2
	} || {
		exec 3>/dev/null
	}

	# Box drawing characters (from @debug:print)
	local HLine=$'\u2500'
	local VLine=$'\u2502'
	local TL=$'\u256D'
	local TR=$'\u256E'
	local BR=$'\u256F'
	local BL=$'\u2570'

	# Helper function to print variable content with colored boxes
	function @debug:print:var {
		emulate -L zsh
		options[extendedglob]=on
		set +x
		exec >&2

		local VarName=${1:?}
		local Type=${(t)${(P)VarName}}

		# If variable doesn't exist, show as text
		(( $#Type )) || {
			Type="undefined"
		}

		# Create header with variable name and type
		local Header="$VarName | Type: $Type"

		# Top border with header (cyan background, black text)
		print -P -- "%K{cyan}%F{black}$TL${(pl.((COLUMNS/2))..$HLine.. .r.(((COLUMNS/2)-1))..$HLine.. .)Header}$TR%E"

		# Print content based on type
		case $Type in
			(scalar*)
				# Print scalar value
				local Val=${(P)VarName}
				print -P -- "%K{cyan}%F{black}$VLine %K{blue}%F{black}  $Val${(l.((COLUMNS-${(c)#Val}-7)).)}%K{cyan}%F{black} $VLine%E"
				;;
			(array*)
				# Print each array element
				local -a Arr=(${(P)VarName})
				local Elem
				for Elem in ${Arr[@]}; do
					print -P -- "%K{cyan}%F{black}$VLine %K{blue}%F{black}  ${(q)Elem}${(l.((COLUMNS-${(c)#${(q)Elem}}-7)).)}%K{cyan}%F{black} $VLine%E"
				done
				;;
			(association*)
				# Get the association
				local -A Assoc=(${(kv)${(P)VarName}})

				# Find max key length for alignment
				local -i MaxKeyLen=0
				local Key
				for Key in ${(k)Assoc}; do
					(( MaxKeyLen = $#Key > MaxKeyLen ? $#Key : MaxKeyLen ))
				done

				# Print each key-value pair (sorted by key)
				for Key in ${(ok)Assoc}; do
					local Val=${Assoc[$Key]}
					local KeyPadded="${(l.((MaxKeyLen+2)).. .r.((MaxKeyLen+2)).. .)Key}"
					local Line="$KeyPadded => $Val"
					local LineLen=${(c)#Line}
					print -P -- "%K{cyan}%F{black}$VLine %K{blue}%F{black}  $Line${(l.((COLUMNS-LineLen-7)).)}%K{cyan}%F{black} $VLine%E"
				done
				;;
			(*)
				# For other types or undefined, try to print as text
				if (( $#Type )) && [[ $Type != "undefined" ]]; then
					local Val=${(P)VarName}
					print -P -- "%K{cyan}%F{black}$VLine %K{blue}%F{black}  $Val${(l.((COLUMNS-${(c)#Val}-7)).)}%K{cyan}%F{black} $VLine%E"
				else
					print -P -- "%K{cyan}%F{black}$VLine %K{blue}%F{black}  (undefined)${(l.((COLUMNS-17)).)}%K{cyan}%F{black} $VLine%E"
				fi
				;;
		esac

		# Bottom border with variable name and type
		print -P -- "%K{cyan}%F{black}$BL${(pl.((COLUMNS/2))..$HLine.. .r.(((COLUMNS/2)-1))..$HLine.. .)Header}$BR%E%f%k"
	}

	# Process each variable argument
	local VarName
	for VarName in "$@"; do
		@debug:print:var "$VarName"
	done
}

@vars:debug:info "$@"
}

:<<-"Example.@vars:debug:info"
	# @vars:debug:info - Display variable information with colored box output
	#
	# This function combines:
	#   - The colored box drawing style from @debug:print
	#   - The variable type detection from @vars:info
	#
	# Features:
	#   - Cyan background boxes with black text
	#   - Unicode box drawing characters
	#   - Automatic type detection (scalar, array, association)
	#   - Formatted output based on variable type
	#   - Support for DEBUG mode (set DEBUG=1 for verbose output)
	#
	# Usage: @vars:debug:info <variable_name> [variable_name...]
	#
	# Example:

	# Create some test variables
	typeset TestScalar="Hello World"
	typeset TestNumber=42
	typeset -a TestArray=("item1" "item2" "item3" "item with spaces")
	typeset -A TestAssoc=(
		key1 value1
		key2 value2
		longer_key "value with spaces"
	)

	# Display them with colored debug output
	@vars:debug:info TestScalar TestNumber TestArray TestAssoc

	# With DEBUG enabled for verbose execution trace
	DEBUG=1 @vars:debug:info TestScalar TestArray TestAssoc

	# Output shows:
	#   ╭────────────── TestScalar | Type: scalar ──────────────╮
	#   │  Hello World                                          │
	#   ╰────────────── TestScalar | Type: scalar ──────────────╯
	#
	#   ╭────────────── TestArray | Type: array ───────────────╮
	#   │  item1                                                │
	#   │  item2                                                │
	#   │  item3                                                │
	#   │  'item with spaces'                                   │
	#   ╰────────────── TestArray | Type: array ───────────────╯
	#
	#   ╭─────────── TestAssoc | Type: association ───────────╮
	#   │  key1        => value1                               │
	#   │  key2        => value2                               │
	#   │  longer_key  => value with spaces                    │
	#   ╰─────────── TestAssoc | Type: association ───────────╯

Example.@vars:debug:info
