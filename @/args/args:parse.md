# @args:parse: A Lightweight Zsh Argument Parser

`@args:parse` is a powerful, lightweight, and idiomatic argument parser for Zsh. It's designed as a flexible toolkit, not a rigid framework. It handles the tedious parts of parsing and then gets out of your way, allowing you to use standard shell features to implement your script's logic in a clean and powerful way. 🚀

---

## Features

* **No Dependencies:** Written in pure Zsh.
* **Automatic Flag Generation:** Automatically creates patterns for long (`--verbose`) and short (`-v`) flags.
* **Powerful Specifications:** Control the number of arguments a flag takes (`file=1`, `exec=*`).
* **Occurrence Counting:** Boolean flags naturally count how many times they are used, perfect for verbosity levels.
* **Subcommand & DSL Patterns:** The design makes it trivial to create scripts with subcommands (e.g., `git push ...`).
* **Built-in Array Iterators:** Every parsed flag array automatically gets iterator aliases (`:next`, `:previous`, `:cycle`) for free.

---

## Installation

There are two ways to use the parser in your scripts:

1.  **Simple Sourcing (Recommended for standalone scripts):**
    Simply save the parser code to a file (e.g., `args_parser.zsh`) and source it at the top of your script:
    ```zsh
    source /path/to/your/args_parser.zsh
    ```

2.  **Standard `fpath` Installation (Recommended for shared functions):**
    For a more robust, system-wide installation that follows standard Zsh practices:
    * Save the parser script into a file named exactly `@args:parse`.
    * Move this file into a directory included in your Zsh function path (`$fpath`), such as `~/.zsh/functions`.
    * Ensure your `.zshrc` contains the line: `fpath=(~/.zsh/functions $fpath)`

---

## Core Usage

You use the parser by calling its alias within your script. It reads the shell's `$argv` array, processes it according to your specifications, and creates new arrays in your shell's scope that hold the results.

The basic syntax is:
`@args:parse 'spec1' 'spec2' ...`

**Example:**
```zsh
#!/bin/zsh
# Assume this script is called with: --verbose --file /tmp/log.txt data.csv
@args:parse verbose 'file=1'

# The post-parsing environment now contains these variables:
# typeset -a verbose=(1)
# typeset -a file=('/tmp/log.txt')
# typeset -a argv=('data.csv')
