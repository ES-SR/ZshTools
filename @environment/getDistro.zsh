#!/bin/zsh
##  getDistro.zsh


:<<-"DOCS.@environment:getDistro"
	Detects the current Linux distribution by parsing system release files.
	
	Returns:
		String containing distribution name (lowercase, quotes removed)
		Empty string if detection fails
	
	Detection Methods:
		1. Parse /etc/*release files for ID= field
		2. Fallback to DISTRIB_ID= field if ID= not found
		3. Remove surrounding quotes from result
	
	Supported Distributions:
		Most modern Linux distributions that follow LSB standards
	
	Usage:
		Distro=$(@environment:getDistro)
		[[ -n "$Distro" ]] && echo "Running on: $Distro"
DOCS.@environment:getDistro

function @environment:getDistro {
	#* Returns empty string on detection failure *#
  
	local Distro="$(cat /etc/*release 2>/dev/null | grep -m 1 -E '^ID=' | cut -d'=' -f2)"
	Distro="${Distro:-"$(cat /etc/*release 2>/dev/null | grep -m 1 -E '^DISTRIB_ID=' | cut -d'=' -f2)"}"
  
	echo "${Distro//\"/}"  # Remove quotes if present
}
autoload -Uz @environment:getDistro


:<<-"EXAMPLE.@environment:getDistro"
	# Basic distribution detection
	Distro=$(@environment:getDistro)
	echo "Detected distribution: ${Distro:-unknown}"
	
EXAMPLE.@environment:getDistro
