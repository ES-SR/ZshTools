#!/usr/bin/zsh
##  @history:exportFormattedHistory
###   Export shell history with formatted headers and optional filtering

() {

	function @history:exportFormattedHistory {
		local OutputFile="Hist.$(date +%s)"
		local Editor="${HISTORY_EDITOR:-kate}"
		local StartEntry="${1:-1}"
		local -a FilterCommands=()

		# Allow passing filter commands as additional arguments
		if [[ $# -gt 1 ]]; then
			shift
			FilterCommands=("$@")
		fi

		# Build the awk filter pattern if filters are specified
		local FilterPattern=""
		if [[ ${#FilterCommands[@]} -gt 0 ]]; then
			local -a AwkPatterns=()
			for cmd in "${FilterCommands[@]}"; do
				# Escape special characters for awk regex
				AwkPatterns+=("/$cmd/")
			done
			# Join patterns with OR operator
			FilterPattern="${(j: || :)AwkPatterns}"
		fi

		# Process history with formatting
		local FormattedHistory
		FormattedHistory=$(fc -l $StartEntry | awk '{
			$1 = "#---------- " $1 " ----------#\n"
			print $0
		}')

		# Apply formatting and optional filtering
		if [[ -n "$FilterPattern" ]]; then
			print -X 2 -- "$FormattedHistory" | \
			awk -v filter="$FilterPattern" '
				/^[[:space:]]*$/ { next }
				{
					# Skip lines matching filter patterns
					if ('"$FilterPattern"') { next }
					print $0
				}
			' | cat --squeeze-blank >| "$OutputFile"
		else
			print -X 2 -- "$FormattedHistory" | \
			awk '
				/^[[:space:]]*$/ { next }
				{ print $0 }
			' | cat --squeeze-blank >| "$OutputFile"
		fi

		# Open in editor if available
		if command -v "$Editor" &>/dev/null; then
			"$Editor" "$OutputFile" &!
			print "History exported to $OutputFile and opened in $Editor"
		else
			print "History exported to $OutputFile"
			print "Editor '$Editor' not found. Set HISTORY_EDITOR variable or install the editor."
		fi
	}

	:<<-'Usage'
	# Basic usage - export all history
	@history:exportFormattedHistory

	# Export from specific history entry
	@history:exportFormattedHistory 100

	# Export with filtering (removes matching lines)
	@history:exportFormattedHistory 1 "^cd " "^ls"

	# Set custom editor
	HISTORY_EDITOR=vim @history:exportFormattedHistory

	# Or set globally in your .zshrc
	export HISTORY_EDITOR=nano
	Usage

}
