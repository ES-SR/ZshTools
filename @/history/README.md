# History Export and Filtering Functions

## Overview

This directory contains Zsh functions for exporting and filtering shell history with formatted output.

## Functions

### @history:exportFormattedHistory

Converts the original command into a function that exports history with a timestamped filename.

**Original Command:**
```zsh
awk ' /^[[:space:]]*$/ { next }; { print $0 }; ' <(print -X 2 -- "$(fc -l 1 | awk ' { $1 = "#---------- " $1 " ----------#\n"; print $0 } ' )") | cat --squeeze-blank >| Hist.1 && kate Hist.1 &!
```

**Changes:**
- Output filename: `${HISTFILE:r}.$(date +%s)` (based on your history file with timestamp)
- Editor: Uses `$EDITOR` environment variable (default: vi)

**Usage:**
```zsh
# Basic usage - exports to ${HISTFILE:r}.<timestamp>
@history:exportFormattedHistory

# Start from specific history entry
@history:exportFormattedHistory 100

# Filter out specific commands (removes matching lines)
@history:exportFormattedHistory 1 "^cd " "^ls"

# Use custom editor
EDITOR=vim @history:exportFormattedHistory
```

### @history:filterHistory

Searches history for matching patterns (positive filter). Shows only lines that match at least one pattern.

**Usage:**
```zsh
# Find function definitions starting with @
@history:filterHistory 'function @'

# Find git or npm commands
@history:filterHistory 'git' 'npm'

# Use regex patterns
@history:filterHistory '^function @.*'
```

**Use Case Example:**
```zsh
# Extract all your custom function definitions
@history:filterHistory 'function @' > my_functions.txt
```

### @history:exportFilteredHistory

Exports history with unwanted commands removed (negative filter). Removes simple commands like cd, ls, pwd, etc.

**Default Excluded Commands:**
- Simple `cd` commands (cd, cd .., cd -)
- Simple `ls` commands (ls, ls -l, ll)
- `pwd`, `clear`, `exit`, `history`

**Usage:**
```zsh
# Export with default exclusions - exports to ${HISTFILE:r}.<timestamp>
@history:exportFilteredHistory

# Export with custom exclusion patterns
@history:exportFilteredHistory 1 '^echo' '^test'
```

### @history:filterPatterns:add

Add custom pattern to the default exclusion list.

**Usage:**
```zsh
@history:filterPatterns:add '^git status[[:space:]]*$'
```

### @history:filterPatterns:list

Display all current exclusion patterns.

**Usage:**
```zsh
@history:filterPatterns:list
```

### @history:filterPatterns:clear

Remove all exclusion patterns.

**Usage:**
```zsh
@history:filterPatterns:clear
```

## Configuration

### Custom Editor

Set the `EDITOR` environment variable (default: vi):

```zsh
export EDITOR=vim
# or
export EDITOR=nano
```

### Output File Location

Output files are automatically named based on your `HISTFILE`:
- Pattern: `${HISTFILE:r}.$(date +%s)`
- Example: If `HISTFILE=/home/user/.zsh_history`, output will be `/home/user/.zsh_history.1730901234`

### Custom Exclusion Patterns

Define exclusion patterns in your `.zshrc` before loading these functions:

```zsh
typeset -ga HISTORY_FILTER_PATTERNS=(
	'^cd '
	'^ls '
	'^git status[[:space:]]*$'
	'^echo '
	# Add your patterns here
)
```

## Loading Functions

Add to your `.zshrc`:

```zsh
# Load the functions
source /path/to/ZshTools/@/history/exportFormattedHistory.zsh
source /path/to/ZshTools/@/history/filterHistory.zsh

# Or use autoload (if in fpath)
autoload -Uz @history:exportFormattedHistory
autoload -Uz @history:filterHistory
```

## Examples

```zsh
# Quick export with default settings (output: ${HISTFILE:r}.<timestamp>)
@history:exportFormattedHistory

# Export filtered history (removes cd, ls, pwd, etc.)
@history:exportFilteredHistory

# Search for specific patterns in history
@history:filterHistory 'function @'           # Your custom functions
@history:filterHistory 'git commit' 'git push'  # Git commands
@history:filterHistory '^npm ' '^yarn '       # Package manager commands

# Customize exclusion patterns
@history:filterPatterns:add '^npm install'
@history:filterPatterns:add '^yarn '
@history:exportFilteredHistory

# Check what's being excluded
@history:filterPatterns:list

# Export with custom editor
EDITOR=vim @history:exportFilteredHistory

# Extract specific commands to file
@history:filterHistory 'function @' > my_functions.txt
```

## Pattern Syntax

Patterns use POSIX Extended Regular Expressions (ERE):
- `^` - Start of line
- `$` - End of line
- `[[:space:]]` - Whitespace
- `*` - Zero or more
- `+` - One or more
- `.*` - Any characters

Examples:
- `'^cd[[:space:]]*$'` - Matches "cd" with optional trailing spaces
- `'^ls[[:space:]]+-[[:alnum:]]+'` - Matches "ls -a", "ls -la", etc.
- `'^git (status|log)'` - Matches "git status" or "git log"
