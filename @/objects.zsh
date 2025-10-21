#!/bin/zsh

# -----------------------------------------------------------------------------
:<<-"Zsh.Object.Interface.System.v1.0"
	A toolkit for creating and interacting with complex data structures in Zsh.
	This system is built on three core concepts:

	1. Data Type Factories (@as:*):
		Functions that convert standard Zsh arrays into specialized associative
		arrays ("objects"). These objects bundle a serialized data payload with
		arbitrary metadata. The primary factory is `@as:object`.

	2. Interface "Class" Factories (@as:iterator, etc.):
		Higher-order functions that attach a specific, consistent API (a set of
		aliased actions) to an object. This allows for a clean, readable syntax
		like `MyObject:instanceName:action`.

	3. Pluggable Logic Functions (@iterator:logic:*):
		The stateless "brains" behind an interface. These functions contain the
		actual implementation for an action (e.g., how to get the "next" item)
		and are composed by factories to build an interface.
Zsh.Object.Interface.System.v1.0
# -----------------------------------------------------------------------------

:<<<"SECTION 1: DATA TYPE FACTORY"

:<<-"Doc.@as:object"
	Converts a standard array into a serialized "object" (associative array).
	The object stores the original array data as a null-delimited string
	under a key matching the object's name, alongside any other metadata.

	@param $1 - Name of the array to convert.
	@param $@[2,-1] - (Optional) Key-value pairs of metadata to add.
	@stdout - An `eval`-able string that performs the conversion.
Doc.@as:object
function @as:object {
	emulate -L zsh
	options[extendedglob]=on

	local ArrayName=${1:?'Error: An array name is required.'}
	local -a TempArray
	# Securely serialize the array into a null-delimited string.
	local -T SerializedData TempArray=(${${(P)ArrayName}}) $'\0'

	# Output the commands to perform the "type promotion".
	print - "unset ${ArrayName}"
	print - "typeset -A ${ArrayName}=( ${ArrayName} ${(q+)SerializedData} ${@[2,-1]} )"
}

:<<<"SECTION 2: INTERFACE FACTORIES & WIRING"

:<<-"Doc.@as:iterator"
	A specialized "class" factory for creating stateful, index-based iterators.
	It uses the generic wiring helper to attach a consistent `:next`, `:current`
	API to an object.

	@param $1 - The name of the target object.
	@param $2 - The unique, user-chosen name for this iterator instance.
Doc.@as:iterator
function @as:iterator {
	emulate -L zsh
	local ObjectName=${1:?'Usage: @as:iterator <ObjectName> <InstanceName>'}
	local InstanceName=${2:?'Usage: @as:iterator <ObjectName> <InstanceName>'}

	# Defines the contract for this interface type.
	# Maps the user-facing action name to its internal logic function.
	local -A InterfaceContract=(
		next	@iterator:logic:next:index
		current @iterator:logic:current:index
		# To add a 'previous' action, you would simply add it here.
		# previous @iterator:logic:previous:index
	)

	# Use the generic engine to wire up the interface.
	__object:attach:generic_interface $ObjectName $InstanceName $InterfaceContract

	print -r -- "Attached INDEXER interface '${InstanceName}' to object '${ObjectName}'"
}

:<<-"Doc.__object:attach:generic_interface"
	The generic "engine" that interface factories use. It's the core of the
	higher-order function design. It takes an object, an instance name, and a
	"contract" (an associative array mapping actions to logic functions) and
	creates all the necessary aliases and metadata.

	@param $1 - The name of the target object.
	@param $2 - The name for the interface instance.
	@param $3 - The name of the associative array defining the contract.
Doc.__object:attach:generic_interface
function __object:attach:generic_interface {
	emulate -L zsh
	local ObjectName=$1
	local InstanceName=$2
	local -n Contract=$3

	# The unique key for this interface's private state within the object.
	local StateKey="__InterfaceState_${InstanceName}"

	# Initialize state. The logic functions are responsible for its content.
	noglob typeset -g "${ObjectName}[${StateKey}]=''"

	# Pre-calculate and store the array size for efficiency if not already present.
	if ! [[ -v ${(P)ObjectName[ArraySize]} ]]; {
		local -a Payload=(${(0)${(P)ObjectName}[$ObjectName]})
		noglob typeset -g "${ObjectName}[ArraySize]=${#Payload}"
	}

	# Wire up the aliases according to the provided contract.
	for Action Func in ${(kv)Contract}; {
		local AliasName="${ObjectName}:${InstanceName}:${Action}"
		alias "${AliasName}"="${Func} ${ObjectName} ${StateKey}"
	}
}

:<<<"SECTION 3: PLUGGABLE LOGIC FUNCTIONS"

:<<<"Logic Set 1: Index-Based Traversal"

:<<-"Doc.@iterator:logic:next:index"
	Logic to get the next item based on an index stored in the object's metadata.
	This is stateful but does not mutate the object's data payload.

	@param $1 - ObjectName (context)
	@param $2 - StateKey for this iterator instance (context)
Doc.@iterator:logic:next:index
function @iterator:logic:next:index {
	local ObjectName=$1 StateKey=$2
	# Read the current index from metadata, defaulting to 1 on first run.
	local -i CurrentIdx=${${(P)ObjectName}[$StateKey]:-1}
	local -i ArraySize=${${(P)ObjectName}[ArraySize]}
	local -a Payload=(${(0)${(P)ObjectName}[$ObjectName]})

	# Output the value at the current position.
	print -r -- "${Payload[$CurrentIdx]}"

	# Calculate the next index, wrapping around.
	local -i NextIdx=$(( CurrentIdx + 1 > ArraySize ? 1 : CurrentIdx + 1 ))
	# Write the new state back into the object.
	noglob typeset -g "${ObjectName}[${StateKey}]"=$NextIdx
}

:<<-"Doc.@iterator:logic:current:index"
	Logic to get the current item without advancing the iterator's state.

	@param $1 - ObjectName (context)
	@param $2 - StateKey for this iterator instance (context)
Doc.@iterator:logic:current:index
function @iterator:logic:current:index {
	local ObjectName=$1 StateKey=$2
	local -i CurrentIdx=${${(P)ObjectName}[$StateKey]:-1}
	local -a Payload=(${(0)${(P)ObjectName}[$ObjectName]})
	print -r -- "${Payload[$CurrentIdx]}"
}


:<<<"EXAMPLE USAGE"

echo "--- Example 1: Basic Object Creation ---"
MyData=( k-gram similarity analysis )
# Use eval to execute the output of the factory.
eval "$( @as:object MyData ArrayType "String List" )"
print "MyData is now a ${(t)MyData}."
print "Initial Metadata:"
print -l ${(kv)MyData}
echo ""

# --- Example 2: Attaching a Typed, Named Interface ---"
# Use our specialized factory to create an iterator named 'mainLoop'.
@as:iterator MyData mainLoop
echo ""

echo "--- Example 3: Using the Interface ---"
print -n "1st call to MyData:mainLoop:next -> "
MyData:mainLoop:next
print -n "2nd call to MyData:mainLoop:next -> "
MyData:mainLoop:next
print -n "Current value is now -> "
MyData:mainLoop:current
echo ""

# --- Example 4: Proving Iterator Independence (Nested Loop) ---"
print "--- Attaching a second iterator to the same object... ---"
@as:iterator MyData outerLoop
@as:iterator MyData innerLoop
echo ""
print "--- Running a nested loop test ---"
# This proves the 'outerLoop' and 'innerLoop' states are independent.
for i in {1..2}; {
	print -n "Outer loop at: "
	MyData:outerLoop:next
	for j in {1..3}; {
		print -n "  -> Inner loop at: "
		MyData:innerLoop:next
	}
}
echo ""

echo "--- Final Object State ---"
print "The object now contains the independent states for all three iterators:"
print -l ${(kv)MyData}
echo ""

# --- Example 5: Building a New "Class" Factory (Advanced) ---"
print "--- Demonstrating extensibility by creating a new 'Cycler' factory ---"

# 1. Define the logic for the new interface type.
function @iterator:logic:cycle:forward {
	local ObjectName=$1 StateKey=$2
	local -a Payload=(${(0)${(P)ObjectName}[$ObjectName]})
	Payload=($Payload[2,-1] $Payload[1]) # Rotate the array
	local -T SerializedData Payload=($Payload) $'\0'
	noglob typeset -g "${ObjectName}[${ObjectName}]"=${(q+)SerializedData} # MUTATE object
	print -r -- "$Payload[1]"
}

# 2. Create the new specialized factory.
function @as:cycler {
	local ObjectName=$1 InstanceName=$2
	local -A Contract=( next @iterator:logic:cycle:forward )
	__object:attach:generic_interface $ObjectName $InstanceName $Contract
	print -r -- "Attached CYCLER interface '${InstanceName}' to object '${ObjectName}'"
}

# 3. Use the new factory.
MyCycler=( 1 2 3 )
eval "$( @as:object MyCycler )"
@as:cycler MyCycler main
print -n "Cycling: "; MyCycler:main:next
print -n "Cycling: "; MyCycler:main:next
print "Final cycler data: ${(0)MyCycler[MyCycler]}"

