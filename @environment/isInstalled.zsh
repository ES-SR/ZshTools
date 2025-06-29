#!/bin/zsh
##  isInstalled.zsh

:<<-"DOCS.@environment:isInstalled"
	Checks if a command is available for execution in PATH or current directory.
	Uses mathematical combination of PATH depth detection and local executable detection.
	
	Parameters:
		$1: Command name to check (required)
	
	Returns:
		0 if command is available, 1 if not found
		Echoes the same value for capture in variables
	
	Detection Logic:
		- PATH commands: Split command path on '/' and count parts (3+ = found in PATH)
		- Local executables: Count glob matches for command(*) in current directory
		- Available if sum > 1 (either PATH depth OR local matches contribute)
	
	Technical Details:
		Uses ${(ws./.)#${1:?}:c} for path part counting with empty string elision.
		Uses ${#$(print ${1}(*))} for local executable matching.
		Single arithmetic expression replaces conditional branching.
	
	Usage:
		if [[ $(@environment:isInstalled git) -eq 0 ]] {
			echo "Git is available"
		}
DOCS.@environment:isInstalled

function @environment:isInstalled {
	local Result
	echo ${Result::=$(( ${(ws./.)#${1:?}:c} + ${#$(print ${1}(*))} > 1 ? 0 : 1 ))}
	return $Result
}
autoload -Uz @environment:isInstalled


:<<-"EXAMPLE.@environment:isInstalled"
	# Test various command types
	Commands=(vim git nonexistent)
	
	for Cmd ( $Commands ) {
		if [[ $(@environment:isInstalled $Cmd) -eq 0 ]] {
			echo "✓ $Cmd is available"
		} else {
			echo "✗ $Cmd not found"
		}
	}
	
	# Check local executables (if you have scripts in current directory)
	if [[ $(@environment:isInstalled myscript.sh) -eq 0 ]] {
		echo "Local script found"
	}
	
	# Combined usage - install if missing
	if [[ $(@environment:isInstalled curl) -ne 0 ]] {
		PM=$(@environment:getPackageManager)
		echo "curl not found. Install with: $PM install curl"
	}
EXAMPLE.@environment:isInstalled
