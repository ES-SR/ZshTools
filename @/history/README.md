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

**Usage:**
```zsh
# Basic usage - exports to Hist.<timestamp>
@history:exportFormattedHistory

# Start from specific history entry
@history:exportFormattedHistory 100

# Filter out specific commands (removes matching lines)
@history:exportFormattedHistory 1 "^cd " "^ls"

# Use custom editor
HISTORY_EDITOR=vim @history:exportFormattedHistory
```

### @history:filterHistory

Filters history based on configurable patterns to remove simple/repetitive commands.

**Default Filtered Commands:**
- Simple `cd` commands (cd, cd .., cd -)
- Simple `ls` commands (ls, ls -l, ll)
- `pwd`, `clear`, `exit`
- `history` commands

**Usage:**
```zsh
# Filter using default patterns
@history:filterHistory

# Filter specific range
@history:filterHistory 100 200

# Use custom patterns
@history:filterHistory 1 -1 '^git status' '^echo'
```

### @history:exportFilteredHistory

Combines filtering and export with formatted output.

**Usage:**
```zsh
# Export filtered history with timestamp
@history:exportFilteredHistory

# Export with custom patterns
@history:exportFilteredHistory 1 '^custom pattern'
```

### @history:addFilterPattern

Add custom pattern to the default filter list.

**Usage:**
```zsh
@history:addFilterPattern '^git status[[:space:]]*$'
```

### @history:listFilterPatterns

Display all current filter patterns.

**Usage:**
```zsh
@history:listFilterPatterns
```

### @history:clearFilterPatterns

Remove all filter patterns.

**Usage:**
```zsh
@history:clearFilterPatterns
```

## Configuration

### Custom Editor

Set the `HISTORY_EDITOR` environment variable (default: kate):

```zsh
export HISTORY_EDITOR=vim
# or
export HISTORY_EDITOR=nano
```

### Custom Filter Patterns

Define patterns in your `.zshrc` before loading these functions:

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
# Quick export with default settings
@history:exportFormattedHistory

# Export filtered history (removes cd, ls, etc.)
@history:exportFilteredHistory

# Customize filter patterns
@history:addFilterPattern '^npm install'
@history:addFilterPattern '^yarn '
@history:exportFilteredHistory

# Check what's being filtered
@history:listFilterPatterns

# Export to specific file with vim
HISTORY_EDITOR=vim @history:exportFilteredHistory 1
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
