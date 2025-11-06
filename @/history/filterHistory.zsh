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
		# Search history for matching patterns (positive filter)
		# Shows only lines that match at least one of the provided patterns

		if [[ $# -eq 0 ]]; then
			print "Usage: @history:filterHistory <pattern> [pattern2 ...]"
			print "Examples:"
			print "  @history:filterHistory 'function @'     # Show function definitions starting with @"
			print "  @history:filterHistory 'git' 'npm'       # Show git or npm commands"
			print "  @history:filterHistory '^function @.*'   # Regex: functions starting with @"
			return 1
		fi

		local -a SearchPatterns=("$@")

		# Build awk script for pattern matching
		local AwkScript='
		BEGIN {
			# Build pattern array from shell variable
			split(patterns, pattern_arr, "\n")
		}
		{
			line = $0
			matched = 0

			# Check each pattern - if any match, include the line
			for (i in pattern_arr) {
				if (pattern_arr[i] != "" && match(line, pattern_arr[i])) {
					matched = 1
					break
				}
			}

			if (matched) {
				print line
			}
		}'

		# Get history and filter for matching patterns
		fc -l 1 | awk -v patterns="${(F)SearchPatterns}" "$AwkScript"
	}

	function @history:exportFilteredHistory {
		# Exports history with unwanted commands removed (cd, ls, pwd, etc.)
		local OutputFile="${HISTFILE:r}.$(date +%s)"
		local Editor="${EDITOR:-vi}"
		local StartEntry="${1:-1}"
		local -a CustomExcludePatterns=()

		# Allow passing custom exclude patterns
		if [[ $# -gt 1 ]]; then
			shift
			CustomExcludePatterns=("$@")
		fi

		# Use custom patterns if provided, otherwise use defaults
		local -a ExcludePatterns=()
		if [[ ${#CustomExcludePatterns[@]} -gt 0 ]]; then
			ExcludePatterns=("${CustomExcludePatterns[@]}")
		else
			ExcludePatterns=("${HISTORY_FILTER_PATTERNS[@]}")
		fi

		# Build awk script for exclusion filtering
		local AwkScript='
		BEGIN {
			split(patterns, pattern_arr, "\n")
		}
		{
			line = $0
			skip = 0

			# Check each pattern - if any match, exclude the line
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

		# Get filtered history (exclude unwanted commands)
		local FilteredHistory
		FilteredHistory=$(fc -l $StartEntry | awk -v patterns="${(F)ExcludePatterns}" "$AwkScript")

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
			print "Editor '$Editor' not found. Set EDITOR variable or install the editor."
		fi

		local PatternCount=${#ExcludePatterns[@]}
		print "Excluded $PatternCount pattern(s) from history"
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
	# Search history for patterns (shows matching lines only)
	@history:filterHistory 'function @'           # Show function definitions starting with @
	@history:filterHistory 'git' 'npm'            # Show git or npm commands
	@history:filterHistory '^function @.*'        # Regex: functions starting with @

	# Export history with unwanted commands removed (cd, ls, pwd, etc.)
	# Output: ${HISTFILE:r}.$(date +%s)
	@history:exportFilteredHistory

	# Export with custom exclude patterns
	@history:exportFilteredHistory 1 '^echo' '^test'

	# Add custom pattern to default exclusion list
	@history:addFilterPattern '^git status[[:space:]]*$'

	# List current exclusion patterns
	@history:listFilterPatterns

	# Clear all exclusion patterns
	@history:clearFilterPatterns

	# Customize exclusion patterns in .zshrc before loading this file:
	HISTORY_FILTER_PATTERNS=(
		'^cd '
		'^ls '
		'^custom pattern here'
	)

	# Set custom editor (uses $EDITOR by default)
	export EDITOR=vim
	Usage

}
