#!/usr/bin/zsh
##  @history:filterHistory
###   Filter history entries based on configurable patterns

() {

	# Default filter patterns (can be overridden)
	typeset -ga HISTORY_FILTER_PATTERNS=(
		'^cd[[:space:]]*$'           # Simple cd commands with no args
		'^cd[[:space:]]+\.\.[[:space:]]*$'  # cd ..
		'^cd[[:space:]]+-[[:space:]]*$'     # cd -
		'^ls[[:space:]]*$'            # Simple ls commands
		'^ls[[:space:]]+-[[:alnum:]]*[[:space:]]*$'  # ls with single flag
		'^ll[[:space:]]*$'            # ll alias
		'^pwd[[:space:]]*$'           # pwd commands
		'^clear[[:space:]]*$'         # clear commands
		'^history[[:space:]]*$'       # history commands
		'^exit[[:space:]]*$'          # exit commands
	)

	function @history:filterHistory {
		local -i StartEntry="${1:-1}"
		local -i EndEntry="${2:--1}"  # -1 means to current
		local -a CustomPatterns=()

		# Allow passing custom patterns as additional arguments
		if [[ $# -gt 2 ]]; then
			shift 2
			CustomPatterns=("$@")
		fi

		# Use custom patterns if provided, otherwise use defaults
		local -a Patterns=()
		if [[ ${#CustomPatterns[@]} -gt 0 ]]; then
			Patterns=("${CustomPatterns[@]}")
		else
			Patterns=("${HISTORY_FILTER_PATTERNS[@]}")
		fi

		# Build awk pattern
		local AwkScript='
		BEGIN {
			# Build pattern array from shell variable
			split(patterns, pattern_arr, "\n")
		}
		{
			line = $0
			skip = 0

			# Check each pattern
			for (i in pattern_arr) {
				if (pattern_arr[i] != "" && match(line, pattern_arr[i])) {
					skip = 1
					break
				}
			}

			if (!skip) {
				print line
			}
		}'

		# Get history and filter
		fc -l $StartEntry $EndEntry | awk -v patterns="${(F)Patterns}" "$AwkScript"
	}

	function @history:exportFilteredHistory {
		local OutputFile="Hist.$(date +%s)"
		local Editor="${HISTORY_EDITOR:-kate}"
		local StartEntry="${1:-1}"
		local -a CustomPatterns=()

		# Allow passing custom patterns
		if [[ $# -gt 1 ]]; then
			shift
			CustomPatterns=("$@")
		fi

		# Get filtered history
		local FilteredHistory
		if [[ ${#CustomPatterns[@]} -gt 0 ]]; then
			FilteredHistory=$(@history:filterHistory $StartEntry -1 "${CustomPatterns[@]}")
		else
			FilteredHistory=$(@history:filterHistory $StartEntry)
		fi

		# Format with decorative headers
		local FormattedHistory
		FormattedHistory=$(echo "$FilteredHistory" | awk '{
			$1 = "#---------- " $1 " ----------#\n"
			print $0
		}')

		# Clean up and write to file
		print -X 2 -- "$FormattedHistory" | \
		awk '
			/^[[:space:]]*$/ { next }
			{ print $0 }
		' | cat --squeeze-blank >| "$OutputFile"

		# Open in editor if available
		if command -v "$Editor" &>/dev/null; then
			"$Editor" "$OutputFile" &!
			print "Filtered history exported to $OutputFile and opened in $Editor"
		else
			print "Filtered history exported to $OutputFile"
			print "Editor '$Editor' not found. Set HISTORY_EDITOR variable or install the editor."
		fi

		print "Filtered using ${#HISTORY_FILTER_PATTERNS[@]} default patterns"
	}

	function @history:addFilterPattern {
		if [[ -z "$1" ]]; then
			print "Usage: @history:addFilterPattern <pattern>"
			print "Example: @history:addFilterPattern '^git status[[:space:]]*\$'"
			return 1
		fi

		HISTORY_FILTER_PATTERNS+=("$1")
		print "Added pattern: $1"
		print "Total patterns: ${#HISTORY_FILTER_PATTERNS[@]}"
	}

	function @history:listFilterPatterns {
		print "Current filter patterns (${#HISTORY_FILTER_PATTERNS[@]} total):"
		local -i i=1
		for pattern in "${HISTORY_FILTER_PATTERNS[@]}"; do
			print "$i: $pattern"
			((i++))
		done
	}

	function @history:clearFilterPatterns {
		HISTORY_FILTER_PATTERNS=()
		print "All filter patterns cleared"
	}

	:<<-'Usage'
	# Filter history using default patterns (cd, ls, etc.)
	@history:filterHistory

	# Filter specific range
	@history:filterHistory 100 200

	# Filter with custom patterns
	@history:filterHistory 1 -1 '^git status' '^echo'

	# Export filtered history with timestamp filename
	@history:exportFilteredHistory

	# Add custom pattern to default list
	@history:addFilterPattern '^git status[[:space:]]*$'

	# List current patterns
	@history:listFilterPatterns

	# Clear all patterns
	@history:clearFilterPatterns

	# Customize patterns in .zshrc before loading this file:
	HISTORY_FILTER_PATTERNS=(
		'^cd '
		'^ls '
		'^custom pattern here'
	)

	# Set custom editor (default: kate)
	export HISTORY_EDITOR=vim
	Usage

}
