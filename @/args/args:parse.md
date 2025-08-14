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
```
## The Post-Parsing Environment

After `@args:parse` runs, it modifies your shell's environment in three key ways:

1.  **Flag Arrays Are Created:** The parser creates arrays for each matched flag (e.g., `verbose`, `file`) containing their respective values or counts.

2.  **`argv` is Cleaned:** **All flags and any arguments they consumed are removed from the `$argv` array.** The `argv` array is then repopulated with only the remaining positional arguments, in their original order.

3.  **Iterators Are Attached:** The full iterator interface (`:next`, `:previous`, etc.) is automatically attached to **every flag array created AND to the final `argv` array**, allowing you to easily cycle through all parsed results.

## Flag Specification Syntax

You define how flags are parsed by providing string specifications.

### Boolean Flags
A flag name by itself is treated as a boolean that counts its occurrences. The result is a **single-element array** containing the total count. As with all flags, **each matched instance is removed** from the final `$argv` array.

* **Spec:** `verbose`
* **Usage:** `./script -v --verbose other-arg`
* **Result:** `verbose=(2)`, `argv=(other-arg)`

### Flags with a Maximum Number of Arguments
Use `=N` to specify that a flag takes a **maximum** of `N` arguments.

* **Spec:** `file=1`
* **Usage:** `./script --file /etc/hosts`
* **Result:** `file=(/etc/hosts)`

### Flags That Consume All Following Arguments
Use `=*` to have a flag consume all subsequent arguments until it hits the next flag. This is the key to creating subcommands.

* **Spec:** `exec=*`
* **Usage:** `./script --exec ls -l /tmp`
* **Result:** `exec=(ls -l /tmp)`

### Flags with Custom Patterns (Advanced)
You can provide your own regex pattern. The `+` characters are used as delimiters and are not part of the pattern itself.

* **Spec:** `+(-|--)i(n(clude|)|)+include=*`
* **Usage:** Matches `-i`, `--in`, and `--include`.
* **Result:** `include=(...)`

## Examples 💡

### Common Use Cases

#### Simple Help Flag
This pattern executes a `help` function if `--help` or `-h` is found.
```zsh
help() {
  cat <<-"EndOfHelp"
  USAGE: ./my_script [options] <file>
  
  Options:
    --verbose, -v   Enable verbose output.
    --help, -h      Show this help message.
  EndOfHelp
}

@args:parse Help

# Use (( $#Help )) to robustly check if the flag was present.
(( $#Help )) && { help; exit 0; }
```

Examining Recurring Issue

I'm focusing on the user's report of a persistent markdown rendering issue. It's crucial to understand the exact conditions that trigger this recurring problem, as it suggests a fundamental flaw. I'm digging into potential causes by scrutinizing the rendering logic and identifying potential edge cases. My priority is isolating the precise steps to reproduce the error and pinpointing the root of the problem.

Probing for Trigger Conditions

I've been analyzing the user's report of the recurring markdown issue. The key is to understand why this specific line, # typeset -a argv=('data.csv'), consistently causes problems.  I'm now investigating potential interactions between the Markdown parser and the code block delimiters. My focus now is on understanding why the process is terminating, not simply that it is terminating.

Diagnosing Markdown Conflict

I'm now investigating a potential Markdown-code block conflict, as the problem persists even after trying again. It appears the rogue character # may be the culprit. I am analyzing the parser's logic, to see if there is a way to tell the renderer to treat the character as literal text, instead of a header. The user's suggestion of separate blocks is a very useful workaround while I continue testing!

Adopting Suggested Fix

I've carefully considered the user's report and re-evaluated the recurring markdown issue. I believe the # character's unintended interaction is the primary trigger. After analyzing the root of the problem, I've re-formatted the documentation using their suggestion of separating markdown blocks. This should resolve the recurring problem.

Confirming Markdown Interpretation

I'm now investigating the recurring issue. Your analysis is insightful. It appears the rogue character # may indeed be the trigger, as you proposed. I am now focused on evaluating the markdown rendering engine's behavior within code blocks and how it interacts with the specific character.

Reframing for Resolution

I've been analyzing the recurring markdown issue and your insights have been valuable. It is highly probable that the # character in the code block is indeed the root cause, leading to rendering errors. I agree that another attempt with the same text will likely fail again, due to this specific character interaction. I will now re-format the documentation into separate, copy-and-paste friendly markdown blocks, as you suggested, which should offer a more reliable solution.

That is incredibly frustrating, and I sincerely apologize that the same glitch happened again. There's nothing worse than a tool not behaving as expected, and your diagnosis is almost certainly correct.

Some markdown renderers are overly aggressive and misinterpret characters like the # from the Zsh comment (# typeset...) as a heading, which breaks the code block's formatting. Simply retrying with the exact same text is unlikely to fix it.

Your suggestion to use separate markdown blocks for each section is an excellent solution. It will isolate any potential rendering issues and should be much more robust.

Here is the complete documentation again, broken down into separate, copy-paste-friendly blocks as you suggested.

Main Title & Introduction

Markdown

# @args:parse: A Lightweight Zsh Argument Parser

`@args:parse` is a powerful, lightweight, and idiomatic argument parser for Zsh. It's designed as a flexible toolkit, not a rigid framework. It handles the tedious parts of parsing and then gets out of your way, allowing you to use standard shell features to implement your script's logic in a clean and powerful way. 🚀

Features

Markdown

## Features

* **No Dependencies:** Written in pure Zsh.
* **Automatic Flag Generation:** Automatically creates patterns for long (`--verbose`) and short (`-v`) flags.
* **Powerful Specifications:** Control the number of arguments a flag takes (`file=1`, `exec=*`).
* **Occurrence Counting:** Boolean flags naturally count how many times they are used, perfect for verbosity levels.
* **Subcommand & DSL Patterns:** The design makes it trivial to create scripts with subcommands (e.g., `git push ...`).
* **Built-in Array Iterators:** Every parsed flag array automatically gets iterator aliases (`:next`, `:previous`, `:cycle`) for free.

Installation

Markdown

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

Core Usage

Markdown

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

The Post-Parsing Environment

Markdown

## The Post-Parsing Environment

After `@args:parse` runs, it modifies your shell's environment in three key ways:

1.  **Flag Arrays Are Created:** The parser creates arrays for each matched flag (e.g., `verbose`, `file`) containing their respective values or counts.

2.  **`argv` is Cleaned:** **All flags and any arguments they consumed are removed from the `$argv` array.** The `argv` array is then repopulated with only the remaining positional arguments, in their original order.

3.  **Iterators Are Attached:** The full iterator interface (`:next`, `:previous`, etc.) is automatically attached to **every flag array created AND to the final `argv` array**, allowing you to easily cycle through all parsed results.

Flag Specification Syntax

Markdown

## Flag Specification Syntax

You define how flags are parsed by providing string specifications.

### Boolean Flags
A flag name by itself is treated as a boolean that counts its occurrences. The result is a **single-element array** containing the total count. As with all flags, **each matched instance is removed** from the final `$argv` array.

* **Spec:** `verbose`
* **Usage:** `./script -v --verbose other-arg`
* **Result:** `verbose=(2)`, `argv=(other-arg)`

### Flags with a Maximum Number of Arguments
Use `=N` to specify that a flag takes a **maximum** of `N` arguments.

* **Spec:** `file=1`
* **Usage:** `./script --file /etc/hosts`
* **Result:** `file=(/etc/hosts)`

### Flags That Consume All Following Arguments
Use `=*` to have a flag consume all subsequent arguments until it hits the next flag. This is the key to creating subcommands.

* **Spec:** `exec=*`
* **Usage:** `./script --exec ls -l /tmp`
* **Result:** `exec=(ls -l /tmp)`

### Flags with Custom Patterns (Advanced)
You can provide your own regex pattern. The `+` characters are used as delimiters and are not part of the pattern itself.

* **Spec:** `+(-|--)i(n(clude|)|)+include=*`
* **Usage:** Matches `-i`, `--in`, and `--include`.
* **Result:** `include=(...)`

Examples

Markdown

## Examples 💡

### Common Use Cases

#### Simple Help Flag
This pattern executes a `help` function if `--help` or `-h` is found.
```zsh
help() {
  cat <<-"EndOfHelp"
  USAGE: ./my_script [options] <file>
  
  Options:
    --verbose, -v   Enable verbose output.
    --help, -h      Show this help message.
  EndOfHelp
}

@args:parse Help

# Use (( $#Help )) to robustly check if the flag was present.
(( $#Help )) && { help; exit 0; }
```

Handling Input/Output Files

A classic use case for a flag that takes a single argument.
```zsh

@args:parse 'input=1' 'output=1'

# Use default values if flags are not provided
: ${input:="stdin"}
: ${output:="stdout"}

print "Reading from '$input[1]' and writing to '$output[1]'."
```

Advanced Patterns & Techniques 🚀

Subcommand Dispatcher

By naming flags after your functions, you can create elegant git-like interfaces.
```zsh

# Define functions to act as subcommands
push() { print "Executing: git push $@" }
commit() { print "Executing: git commit -m '$1'" }

# Use '=1' for commit (takes one message) and '=*' for push (takes multiple args)
@args:parse 'commit=1' 'push=*'

# Dispatcher logic
(( $#commit )) && commit "${commit[@]}"
(( $#push )) && push "${push[@]}"

# USER INVOCATION:
# ./git-helper.sh --commit "Initial commit" --push origin main
```

Multi-Level Verbosity Control

This shows two powerful ways to handle verbosity.

1. Using a case Statement:
```zsh

@args:parse verbose

case ${verbose[1]:-0} in
  1) print "Verbosity level 1: Basic status messages." ;;
  2) print "Verbosity level 2: Detailed debug output." ;;
  3) set -x ;; # Level 3 enables xtrace
esac
```

2. Dynamic Output Redirection:
```zsh

# Define output targets. Index 1 is for no verbosity (level 0).
VerboseTargets=(/dev/null /dev/stderr /proc/self/fd/1)
@args:parse 'Verbose=3'

# Redirect fd 3 to the chosen target based on the number of -v flags.
exec 3>$VerboseTargets[${Verbose[1]:-0}+1]

# Now, you can selectively write to the verbose stream.
print -u 3 "This is a verbose message."
```

Pro Tip: Namespacing Functions and Variables

Because the parser's pattern matching is case-insensitive but the variable creation is case-sensitive (it uses the name from your spec), you can create a powerful separation between a function and its corresponding flag variable.
```zsh

# A function named 'verbose' in all lowercase
verbose() {
  print -u 3 -P "%F{cyan}VERBOSE:%f $@"
}

# A spec using 'Verbose' with a capital V
@args:parse Verbose

# Now, 'verbose' is the function, and '$Verbose' is the array!
(( $#Verbose )) && verbose "Verbose mode is on (level ${Verbose[1]})."
```

---

## Future Direction: The "Parser 2.0" Vision 🗺️

This parser is an evolving project. The planned next major version aims to move from creating individual global variables for each flag to building a unified **tree data structure**.

This architectural shift would transform the parser from a "flag processor" to an **"argument data structure builder,"** providing several key benefits:

* **Clean Namespace:** All parsed data would live under a single entry point (e.g., `Args`), preventing pollution of the global variable space. Instead of `$verbose` and `$file`, you would access `Args:Flags:verbose` and `Args:Flags:file`.
* **Rich Metadata:** The tree structure makes it easy to attach metadata to the parsed results, such as the order in which flags appeared, the specific pattern that matched a flag, or overall parsing statistics.
* **Multi-Level Iteration:** The existing iterator system would be integrated directly into the tree, allowing for powerful, hierarchical iteration:
    ```zsh
    # Cycle through the names of all flags that were found
    Args:Flags:next

    # Cycle through the values of a specific flag
    Args:Flags:SomeFlagName:next
    ```

This future direction aims to make the post-parsing environment even more powerful, organized, and intuitive to work with.

