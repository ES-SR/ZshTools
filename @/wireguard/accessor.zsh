#!/bin/zsh
## WireGuard Accessor Abstraction
## Identity mapping and authorization for key/interface allocation

:<<-"DOCS.@wireguard:accessor:register"
    Registers a new accessor type with the checkpoint system.

    Accessors handle identity mapping and authorization for key/interface allocation.
    Different accessor implementations can address different identity domains: processes,
    users, containers, VMs, namespaces, directory services, or other entities.

    @param $1 - Accessor type (e.g., user, process, container, vm)
    @param $2 - Accessor ID
    @param $3 - Metadata (JSON format)
    @param $4 - Config directory (optional, defaults to /etc/wireguard/accessors)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:accessor:register

function @wireguard:accessor:register {
    local accessor_type="$1"
    local accessor_id="$2"
    local metadata="$3"
    local config_dir="${4:-/etc/wireguard/accessors}"

    if [[ -z "$accessor_type" ]] || [[ -z "$accessor_id" ]]; then
        echo "Error: Accessor type and ID required" >&2
        return 1
    fi

    mkdir -p "$config_dir/$accessor_type"

    local accessor_file="$config_dir/$accessor_type/${accessor_id}.json"

    # Create accessor registration
    cat > "$accessor_file" <<EOF
{
  "type": "$accessor_type",
  "id": "$accessor_id",
  "registered": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "metadata": $metadata,
  "status": "active"
}
EOF

    echo "Accessor registered: $accessor_type:$accessor_id"

    return 0
}

:<<-"DOCS.@wireguard:accessor:user:register"
    Registers a user accessor.

    @param $1 - Username
    @param $2 - User ID (UID)
    @param $3 - Additional metadata (optional)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:accessor:user:register

function @wireguard:accessor:user:register {
    local username="$1"
    local uid="$2"
    local additional_meta="$3"

    local metadata="{
  \"username\": \"$username\",
  \"uid\": $uid,
  \"type\": \"local_user\"
}"

    if [[ -n "$additional_meta" ]]; then
        # Merge metadata (simple approach, would need jq for complex cases)
        metadata="$additional_meta"
    fi

    @wireguard:accessor:register user "$username" "$metadata"

    return $?
}

:<<-"DOCS.@wireguard:accessor:process:register"
    Registers a process accessor.

    @param $1 - Process ID (PID)
    @param $2 - Process name
    @param $3 - User owner
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:accessor:process:register

function @wireguard:accessor:process:register {
    local pid="$1"
    local process_name="$2"
    local user="$3"

    local metadata="{
  \"pid\": $pid,
  \"name\": \"$process_name\",
  \"user\": \"$user\",
  \"cmdline\": \"$(cat /proc/$pid/cmdline 2>/dev/null | tr '\\0' ' ' || echo 'N/A')\"
}"

    @wireguard:accessor:register process "$pid" "$metadata"

    return $?
}

:<<-"DOCS.@wireguard:accessor:container:register"
    Registers a container accessor.

    @param $1 - Container ID
    @param $2 - Container name
    @param $3 - Container runtime (docker, podman, etc.)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:accessor:container:register

function @wireguard:accessor:container:register {
    local container_id="$1"
    local container_name="$2"
    local runtime="${3:-docker}"

    local metadata="{
  \"container_id\": \"$container_id\",
  \"name\": \"$container_name\",
  \"runtime\": \"$runtime\"
}"

    @wireguard:accessor:register container "$container_id" "$metadata"

    return $?
}

:<<-"DOCS.@wireguard:accessor:vm:register"
    Registers a virtual machine accessor.

    @param $1 - VM ID
    @param $2 - VM name
    @param $3 - Hypervisor (kvm, vmware, virtualbox, etc.)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:accessor:vm:register

function @wireguard:accessor:vm:register {
    local vm_id="$1"
    local vm_name="$2"
    local hypervisor="${3:-kvm}"

    local metadata="{
  \"vm_id\": \"$vm_id\",
  \"name\": \"$vm_name\",
  \"hypervisor\": \"$hypervisor\"
}"

    @wireguard:accessor:register vm "$vm_id" "$metadata"

    return $?
}

:<<-"DOCS.@wireguard:accessor:checkpoint:register"
    Registers a checkpoint as an accessor (for recursive composition).

    This enables checkpoint recursion where accessors can themselves be checkpoints,
    allowing recursive composition. Base checkpoints can spawn subsidiary checkpoints
    for specific connections.

    @param $1 - Checkpoint name
    @param $2 - Checkpoint public key
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:accessor:checkpoint:register

function @wireguard:accessor:checkpoint:register {
    local checkpoint_name="$1"
    local public_key="$2"

    local metadata="{
  \"checkpoint_name\": \"$checkpoint_name\",
  \"public_key\": \"$public_key\",
  \"is_checkpoint\": true
}"

    @wireguard:accessor:register checkpoint "$checkpoint_name" "$metadata"

    return $?
}

:<<-"DOCS.@wireguard:accessor:authorize"
    Checks if an accessor is authorized for a specific operation.

    This is a policy enforcement point. The default implementation always
    returns success, but can be extended with custom authorization logic.

    @param $1 - Accessor type
    @param $2 - Accessor ID
    @param $3 - Checkpoint name
    @param $4 - Operation (allocate, revoke, query, etc.)
    @return   - 0 if authorized, 1 if denied
DOCS.@wireguard:accessor:authorize

function @wireguard:accessor:authorize {
    local accessor_type="$1"
    local accessor_id="$2"
    local checkpoint="$3"
    local operation="$4"
    local config_dir="${WIREGUARD_ACCESSOR_CONFIG:-/etc/wireguard/accessors}"

    # Check if accessor is registered
    local accessor_file="$config_dir/$accessor_type/${accessor_id}.json"

    if [[ ! -f "$accessor_file" ]]; then
        echo "Error: Accessor $accessor_type:$accessor_id not registered" >&2
        return 1
    fi

    # Check if accessor is active
    local status=$(grep -oP '"status":\s*"\K[^"]+' "$accessor_file" 2>/dev/null)

    if [[ "$status" != "active" ]]; then
        echo "Error: Accessor $accessor_type:$accessor_id is not active (status: $status)" >&2
        return 1
    fi

    # Default policy: allow all operations for registered, active accessors
    # Custom authorization logic can be added here

    return 0
}

:<<-"DOCS.@wireguard:accessor:list"
    Lists all registered accessors of a specific type.

    @param $1 - Accessor type (user, process, container, vm, checkpoint, or "all")
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:accessor:list

function @wireguard:accessor:list {
    local accessor_type="${1:-all}"
    local config_dir="${WIREGUARD_ACCESSOR_CONFIG:-/etc/wireguard/accessors}"

    if [[ ! -d "$config_dir" ]]; then
        echo "No accessors registered"
        return 0
    fi

    if [[ "$accessor_type" == "all" ]]; then
        echo "All registered accessors:"
        echo "========================="

        for type_dir in "$config_dir"/*; do
            if [[ -d "$type_dir" ]]; then
                local type=$(basename "$type_dir")
                echo ""
                echo "Type: $type"
                echo "----------"

                for accessor_file in "$type_dir"/*.json; do
                    if [[ -f "$accessor_file" ]]; then
                        local id=$(basename "$accessor_file" .json)
                        local status=$(grep -oP '"status":\s*"\K[^"]+' "$accessor_file" 2>/dev/null)
                        local registered=$(grep -oP '"registered":\s*"\K[^"]+' "$accessor_file" 2>/dev/null)

                        echo "  ID: $id"
                        echo "    Status: $status"
                        echo "    Registered: $registered"
                    fi
                done
            fi
        done
    else
        echo "Accessors of type: $accessor_type"
        echo "================================="

        if [[ ! -d "$config_dir/$accessor_type" ]]; then
            echo "No accessors of this type registered"
            return 0
        fi

        for accessor_file in "$config_dir/$accessor_type"/*.json; do
            if [[ -f "$accessor_file" ]]; then
                local id=$(basename "$accessor_file" .json)
                local status=$(grep -oP '"status":\s*"\K[^"]+' "$accessor_file" 2>/dev/null)
                local registered=$(grep -oP '"registered":\s*"\K[^"]+' "$accessor_file" 2>/dev/null)

                echo ""
                echo "ID: $id"
                echo "  Status: $status"
                echo "  Registered: $registered"
            fi
        done
    fi

    return 0
}

:<<-"DOCS.@wireguard:accessor:deactivate"
    Deactivates an accessor without removing its registration.

    @param $1 - Accessor type
    @param $2 - Accessor ID
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:accessor:deactivate

function @wireguard:accessor:deactivate {
    local accessor_type="$1"
    local accessor_id="$2"
    local config_dir="${WIREGUARD_ACCESSOR_CONFIG:-/etc/wireguard/accessors}"

    if [[ -z "$accessor_type" ]] || [[ -z "$accessor_id" ]]; then
        echo "Error: Accessor type and ID required" >&2
        return 1
    fi

    local accessor_file="$config_dir/$accessor_type/${accessor_id}.json"

    if [[ ! -f "$accessor_file" ]]; then
        echo "Error: Accessor $accessor_type:$accessor_id not found" >&2
        return 1
    fi

    # Update status to inactive
    sed -i 's/"status":\s*"[^"]*"/"status": "inactive"/' "$accessor_file"

    echo "Accessor $accessor_type:$accessor_id deactivated"

    return 0
}

:<<-"EXAMPLE.accessor"
    # Register a user accessor
    @wireguard:accessor:user:register alice 1001

    # Register a process accessor
    @wireguard:accessor:process:register 12345 "nginx" "www-data"

    # Register a container accessor
    @wireguard:accessor:container:register abc123def "webserver" docker

    # Register a VM accessor
    @wireguard:accessor:vm:register vm-001 "production-web-01" kvm

    # Register a checkpoint as an accessor (recursive composition)
    checkpoint_key=$(@wireguard:checkpoint:get_base_key myserver)
    @wireguard:accessor:checkpoint:register myserver "$checkpoint_key"

    # List all accessors
    @wireguard:accessor:list all

    # List accessors of a specific type
    @wireguard:accessor:list user

    # Check authorization
    @wireguard:accessor:authorize user alice myserver allocate

    # Deactivate an accessor
    @wireguard:accessor:deactivate user alice
EXAMPLE.accessor
