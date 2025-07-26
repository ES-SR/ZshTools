#!/bin/zsh
##  getPackageManager.zsh

:<<-"DOCS.@environment:getPackageManager"
	Returns the primary package manager for the detected distribution.
	Uses ZSH associative array with glob pattern keys for efficient lookup.
	
	Dependencies:
		@environment:getDistro
	
	Returns:
		String containing package manager name
		Exit code 0 if package manager found, 1 if unknown distribution
	
	Supported Package Managers:
		- apt: Debian, Ubuntu, Linux Mint, Raspbian
		- dnf: Fedora, CentOS, RHEL
		- pacman: Arch Linux, Manjaro
		- zypper: openSUSE, SUSE
	
	Technical Details:
		Uses [(k)${Distro}] subscript for pattern matching against associative array keys.
		Keys are glob patterns, values are package manager names.
		No iteration required - direct ZSH pattern lookup.
	
	Usage:
		PM=$(@environment:getPackageManager) && echo "Use: $PM install package"
DOCS.@environment:getPackageManager

function @environment:getPackageManager {
	#* Uses ZSH associative array with pattern keys for direct lookup *#
	
	local -A Distros_PackageManagers=(
		"*(debian|ubuntu|mint|raspbian)*"  "apt"
		"*(fedora|centos|rhel)*"           "dnf" 
		"*(arch|manjaro)*"                 "pacman"
		"*(open|)suse*"                    "zypper"
	)
	
	local Distro="$(@environment:getDistro)"
	local PackageManager=${Distros_PackageManagers[(k)${Distro}]}
	
	echo ${PackageManager}
	return $(( 1 - ${+PackageManager} ))
}
autoload -Uz @environment:getPackageManager


:<<-"EXAMPLE.@environment:getPackageManager"
	# Get package manager for current system
	PM=$(@environment:getPackageManager)
	RetCode=$?
	
	if [[ $RetCode -eq 0 ]] {
		echo "Package manager: $PM"
		echo "Install command: $PM install <package>"
	} else {
		echo "Unknown distribution - package manager not detected"
	}
	
	# One-liner usage
	echo "Install git: $(@environment:getPackageManager) install git"
EXAMPLE.@environment:getPackageManager
