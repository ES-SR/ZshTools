#!/bin/zsh
## WireGuard Checkpoint Abstraction
## Core checkpoint management for WireGuard tunnel endpoints

:<<-"DOCS.@wireguard:checkpoint:create"
    Creates a new WireGuard checkpoint instance.

    A checkpoint manages WireGuard tunnel endpoints, controlling keys, interfaces,
    and routing knowledge. Each checkpoint can allocate keys/interfaces to accessors
    with defined policies and maintains audit logs.

    @param $1 - Checkpoint name (unique identifier)
    @param $2 - Base directory for checkpoint data (optional, defaults to /var/lib/wireguard/checkpoints)
    @return   - 0 on success, 1 on failure

    Creates:
      - Checkpoint metadata file
      - Key storage directory
      - Interface configuration directory
      - Allocation log file
      - Base key for checkpoint-to-checkpoint communication
DOCS.@wireguard:checkpoint:create

function @wireguard:checkpoint:create {
    local checkpoint_name="$1"
    local base_dir="${2:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$checkpoint_name" ]]; then
        echo "Error: Checkpoint name required" >&2
        return 1
    fi

    local checkpoint_dir="$base_dir/$checkpoint_name"

    # Check if checkpoint already exists
    if [[ -d "$checkpoint_dir" ]]; then
        echo "Error: Checkpoint '$checkpoint_name' already exists" >&2
        return 1
    fi

    # Create directory structure
    mkdir -p "$checkpoint_dir"/{keys,interfaces,config,logs}

    # Create metadata file
    local metadata_file="$checkpoint_dir/metadata.json"
    cat > "$metadata_file" <<EOF
{
  "name": "$checkpoint_name",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "1.0",
  "type": "checkpoint",
  "base_dir": "$checkpoint_dir"
}
EOF

    # Generate base key for checkpoint-to-checkpoint communication
    local base_private_key=$(wg genkey)
    local base_public_key=$(echo "$base_private_key" | wg pubkey)

    echo "$base_private_key" > "$checkpoint_dir/keys/base.private"
    echo "$base_public_key" > "$checkpoint_dir/keys/base.public"
    chmod 600 "$checkpoint_dir/keys/base.private"
    chmod 644 "$checkpoint_dir/keys/base.public"

    # Initialize allocation log
    local log_file="$checkpoint_dir/logs/allocations.log"
    cat > "$log_file" <<EOF
# WireGuard Checkpoint Allocation Log
# Checkpoint: $checkpoint_name
# Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Format: TIMESTAMP|ACCESSOR_ID|KEY_ID|INTERFACE|TUNNEL|ACTION|METADATA
EOF

    # Create empty configuration
    cat > "$checkpoint_dir/config/checkpoint.conf" <<EOF
# WireGuard Checkpoint Configuration
# Checkpoint: $checkpoint_name

[Checkpoint]
Name = $checkpoint_name
BaseDir = $checkpoint_dir
BasePublicKey = $base_public_key

[Policies]
# Key allocation policies
# Interface allocation policies
# Routing policies
EOF

    echo "Checkpoint '$checkpoint_name' created successfully at $checkpoint_dir"
    echo "Base public key: $base_public_key"

    return 0
}

:<<-"DOCS.@wireguard:checkpoint:allocate"
    Allocates a key/interface to an accessor.

    Creates a new WireGuard key pair and optionally an interface, associating
    them with the specified accessor. Logs the allocation with timestamp and
    metadata for audit trails.

    @param $1 - Checkpoint name
    @param $2 - Accessor ID
    @param $3 - Allocation purpose/metadata
    @param $4 - Create interface (yes/no, default: no)
    @return   - 0 on success, 1 on failure

    Outputs the allocated key ID.
DOCS.@wireguard:checkpoint:allocate

function @wireguard:checkpoint:allocate {
    local checkpoint_name="$1"
    local accessor_id="$2"
    local purpose="$3"
    local create_interface="${4:-no}"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$checkpoint_name" ]] || [[ -z "$accessor_id" ]]; then
        echo "Error: Checkpoint name and accessor ID required" >&2
        return 1
    fi

    local checkpoint_dir="$base_dir/$checkpoint_name"

    if [[ ! -d "$checkpoint_dir" ]]; then
        echo "Error: Checkpoint '$checkpoint_name' not found" >&2
        return 1
    fi

    # Generate unique key ID
    local key_id="key_$(date +%s)_$(od -An -N4 -tx /dev/urandom | tr -d ' ')"

    # Generate key pair
    local private_key=$(wg genkey)
    local public_key=$(echo "$private_key" | wg pubkey)

    # Store keys
    echo "$private_key" > "$checkpoint_dir/keys/${key_id}.private"
    echo "$public_key" > "$checkpoint_dir/keys/${key_id}.public"
    chmod 600 "$checkpoint_dir/keys/${key_id}.private"
    chmod 644 "$checkpoint_dir/keys/${key_id}.public"

    # Store allocation metadata
    cat > "$checkpoint_dir/keys/${key_id}.meta" <<EOF
{
  "key_id": "$key_id",
  "accessor_id": "$accessor_id",
  "purpose": "$purpose",
  "allocated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "public_key": "$public_key"
}
EOF

    local interface_name=""

    # Create interface if requested
    if [[ "$create_interface" == "yes" ]]; then
        interface_name="wg_${checkpoint_name}_${key_id:0:8}"

        # Store interface configuration
        cat > "$checkpoint_dir/interfaces/${interface_name}.conf" <<EOF
[Interface]
PrivateKey = $private_key
# Additional configuration will be added by the user or automation

# Allocated to: $accessor_id
# Purpose: $purpose
# Key ID: $key_id
EOF
    fi

    # Log allocation
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "$timestamp|$accessor_id|$key_id|$interface_name|ALLOCATED|$purpose" >> "$checkpoint_dir/logs/allocations.log"

    # Output key ID
    echo "$key_id"

    return 0
}

:<<-"DOCS.@wireguard:checkpoint:revoke"
    Revokes a key/interface allocation.

    Marks the specified key as revoked and optionally removes the associated
    interface. Logs the revocation for audit purposes.

    @param $1 - Checkpoint name
    @param $2 - Key ID
    @param $3 - Reason for revocation
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:checkpoint:revoke

function @wireguard:checkpoint:revoke {
    local checkpoint_name="$1"
    local key_id="$2"
    local reason="$3"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$checkpoint_name" ]] || [[ -z "$key_id" ]]; then
        echo "Error: Checkpoint name and key ID required" >&2
        return 1
    fi

    local checkpoint_dir="$base_dir/$checkpoint_name"

    if [[ ! -d "$checkpoint_dir" ]]; then
        echo "Error: Checkpoint '$checkpoint_name' not found" >&2
        return 1
    fi

    if [[ ! -f "$checkpoint_dir/keys/${key_id}.private" ]]; then
        echo "Error: Key '$key_id' not found" >&2
        return 1
    fi

    # Read metadata to get accessor info
    local accessor_id=""
    if [[ -f "$checkpoint_dir/keys/${key_id}.meta" ]]; then
        accessor_id=$(grep -oP '"accessor_id":\s*"\K[^"]+' "$checkpoint_dir/keys/${key_id}.meta")
    fi

    # Move keys to revoked directory
    mkdir -p "$checkpoint_dir/keys/revoked"
    mv "$checkpoint_dir/keys/${key_id}".* "$checkpoint_dir/keys/revoked/"

    # Log revocation
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "$timestamp|$accessor_id|$key_id||REVOKED|$reason" >> "$checkpoint_dir/logs/allocations.log"

    echo "Key '$key_id' revoked successfully"

    return 0
}

:<<-"DOCS.@wireguard:checkpoint:list"
    Lists all allocations for a checkpoint.

    @param $1 - Checkpoint name
    @param $2 - Filter by accessor ID (optional)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:checkpoint:list

function @wireguard:checkpoint:list {
    local checkpoint_name="$1"
    local filter_accessor="$2"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$checkpoint_name" ]]; then
        echo "Error: Checkpoint name required" >&2
        return 1
    fi

    local checkpoint_dir="$base_dir/$checkpoint_name"

    if [[ ! -d "$checkpoint_dir" ]]; then
        echo "Error: Checkpoint '$checkpoint_name' not found" >&2
        return 1
    fi

    echo "Allocations for checkpoint: $checkpoint_name"
    echo "----------------------------------------"

    # List active keys
    for key_file in "$checkpoint_dir/keys/"*.private; do
        if [[ -f "$key_file" ]]; then
            local key_id=$(basename "$key_file" .private)

            # Skip base key
            if [[ "$key_id" == "base" ]]; then
                continue
            fi

            if [[ -f "$checkpoint_dir/keys/${key_id}.meta" ]]; then
                local accessor_id=$(grep -oP '"accessor_id":\s*"\K[^"]+' "$checkpoint_dir/keys/${key_id}.meta")
                local purpose=$(grep -oP '"purpose":\s*"\K[^"]+' "$checkpoint_dir/keys/${key_id}.meta")
                local allocated=$(grep -oP '"allocated":\s*"\K[^"]+' "$checkpoint_dir/keys/${key_id}.meta")

                # Apply filter if specified
                if [[ -n "$filter_accessor" ]] && [[ "$accessor_id" != "$filter_accessor" ]]; then
                    continue
                fi

                echo "Key ID: $key_id"
                echo "  Accessor: $accessor_id"
                echo "  Purpose: $purpose"
                echo "  Allocated: $allocated"
                echo ""
            fi
        fi
    done

    return 0
}

:<<-"DOCS.@wireguard:checkpoint:get_base_key"
    Gets the base public key for checkpoint-to-checkpoint communication.

    @param $1 - Checkpoint name
    @return   - 0 on success, 1 on failure

    Outputs the base public key.
DOCS.@wireguard:checkpoint:get_base_key

function @wireguard:checkpoint:get_base_key {
    local checkpoint_name="$1"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$checkpoint_name" ]]; then
        echo "Error: Checkpoint name required" >&2
        return 1
    fi

    local checkpoint_dir="$base_dir/$checkpoint_name"

    if [[ ! -f "$checkpoint_dir/keys/base.public" ]]; then
        echo "Error: Base key not found for checkpoint '$checkpoint_name'" >&2
        return 1
    fi

    cat "$checkpoint_dir/keys/base.public"

    return 0
}

:<<-"EXAMPLE.checkpoint"
    # Create a new checkpoint
    @wireguard:checkpoint:create myserver

    # Allocate a key to an accessor
    key_id=$(@wireguard:checkpoint:allocate myserver user:alice "VPN Access")

    # Allocate a key with interface
    key_id=$(@wireguard:checkpoint:allocate myserver process:1234 "IPC Channel" yes)

    # List allocations
    @wireguard:checkpoint:list myserver

    # Filter by accessor
    @wireguard:checkpoint:list myserver user:alice

    # Revoke a key
    @wireguard:checkpoint:revoke myserver $key_id "User left organization"

    # Get base public key
    @wireguard:checkpoint:get_base_key myserver
EXAMPLE.checkpoint
