# @vars:debug:info

Display variable information with colored box output, combining the visual style of `@debug:print` with the type detection capabilities of `@vars:info`.

## Features

- **Colored Output**: Cyan background boxes with black text for clear visibility
- **Unicode Box Drawing**: Uses Unicode box drawing characters (╭╮╯╰│─) for clean borders
- **Type Detection**: Automatically detects and handles:
  - Scalars (strings, numbers)
  - Arrays
  - Associative arrays
  - Undefined variables
- **Formatted Display**: Content is formatted appropriately based on variable type
- **Debug Mode**: Set `DEBUG=1` for verbose execution tracing

## Usage

```zsh
# Source the function
source @/vars/debug/info.zsh

# Display one or more variables
@vars:debug:info variable_name [variable_name...]
```

## Examples

### Basic Usage

```zsh
# Create test variables
typeset MyString="Hello World"
typeset MyNumber=42
typeset -a MyArray=("apple" "banana" "cherry")
typeset -A MyAssoc=(name "John Doe" age 30 city "New York")

# Display all variables
@vars:debug:info MyString MyNumber MyArray MyAssoc
```

### Output Format

**Scalar Variables:**
```
╭────────────── MyString | Type: scalar ──────────────╮
│  Hello World                                        │
╰────────────── MyString | Type: scalar ──────────────╯
```

**Array Variables:**
```
╭────────────── MyArray | Type: array ───────────────╮
│  apple                                              │
│  banana                                             │
│  cherry                                             │
╰────────────── MyArray | Type: array ───────────────╯
```

**Associative Arrays:**
```
╭─────────── MyAssoc | Type: association ───────────╮
│  age   => 30                                       │
│  city  => New York                                 │
│  name  => John Doe                                 │
╰─────────── MyAssoc | Type: association ───────────╯
```

### Debug Mode

Enable verbose output with execution trace:

```zsh
DEBUG=1 @vars:debug:info MyString MyArray
```

## Differences from @vars:info

| Feature | @vars:info | @vars:debug:info |
|---------|-----------|------------------|
| Output Style | Uses `bat` with pager | Direct colored terminal output |
| Paging | Yes (through bat) | No (direct output) |
| Colors | Bat theme colors | Cyan/blue boxes |
| Border Style | Grid style | Unicode box drawing |
| Terminal Control | Uses tput (smcup/rmcup) | Direct output to stderr |

## Differences from @debug:print

| Feature | @debug:print | @vars:debug:info |
|---------|-------------|------------------|
| Type Detection | No | Yes (automatic) |
| Variable Expansion | Manual via ${(P)var} | Automatic based on type |
| Array Handling | Basic | Formatted with quoting |
| Association Handling | Basic | Aligned key-value pairs |
| Purpose | Generic debug output | Variable inspection |

## Technical Details

- Output is sent to stderr (fd 2) for proper stream handling
- Uses zsh prompt expansion (`print -P`) for colors
- Color codes:
  - `%K{cyan}%F{black}` - Cyan background, black foreground (borders)
  - `%K{blue}%F{black}` - Blue background, black foreground (content)
- Box drawing uses Unicode characters (U+256D through U+2570, U+2500, U+2502)
- Column width calculations use `${(c)#var}` for proper character counting

## Integration with Existing Code

This function is designed to work alongside your existing debugging functions:

```zsh
# Use in place of @debug:print for variable inspection
function my_function {
    local -a args=(foo bar baz)
    local -A config=(debug on verbose off)

    # Instead of:
    # @debug:print args config

    # Use:
    @vars:debug:info args config
}
```

## Requirements

- Zsh with extended glob support
- Terminal with Unicode support
- Color terminal (256 color recommended)
