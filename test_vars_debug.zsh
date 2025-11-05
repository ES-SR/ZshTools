#!/bin/zsh

# Test script for @vars:debug:info
# This demonstrates the combined colored output from @debug:print
# with the variable type detection from @vars:info

# Source the new function
source @/vars/debug/info.zsh

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Testing @vars:debug:info Function                     ║"
echo "║  Combines @debug:print colors with @vars:info functionality   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Create test variables
echo "Creating test variables..."
typeset TestScalar="Hello World"
typeset TestNumber=42
typeset -a TestArray=("item1" "item2" "item3" "item with spaces")
typeset -A TestAssoc=(
	key1 value1
	key2 value2
	longer_key "value with spaces"
	another_key "another value"
)
typeset -A options=(
	debug on
	verbose off
	color auto
)

echo "Done."
echo ""

# Test 1: Individual variables
echo "Test 1: Display individual scalar"
echo "-----------------------------------"
@vars:debug:info TestScalar
echo ""

echo "Test 2: Display array"
echo "-----------------------------------"
@vars:debug:info TestArray
echo ""

echo "Test 3: Display associative array"
echo "-----------------------------------"
@vars:debug:info TestAssoc
echo ""

# Test 4: Multiple variables at once
echo "Test 4: Display multiple variables"
echo "-----------------------------------"
@vars:debug:info TestScalar TestNumber TestArray

echo ""
echo "Test 5: Display complex association (options)"
echo "-----------------------------------"
@vars:debug:info options

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  All Tests Completed!                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "To test with DEBUG mode enabled, run:"
echo "  DEBUG=1 zsh $0"
