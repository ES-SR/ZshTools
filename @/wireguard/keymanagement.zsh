#!/bin/zsh
## WireGuard Key Management and Lifecycle
## Manages key lifecycles with time-based, usage-based, and failure-based policies

:<<-"DOCS.@wireguard:key:set_policy"
    Sets a lifecycle policy for a key.

    Policies can be:
    - time-based: Key expires after a duration (e.g., "30d", "24h", "7200s")
    - usage-based: Key expires after N bytes transferred
    - failure-based: Key is revoked after N connection failures

    @param $1 - Checkpoint name
    @param $2 - Key ID
    @param $3 - Policy type (time, usage, failure)
    @param $4 - Policy value (duration, bytes, or failure count)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:key:set_policy

function @wireguard:key:set_policy {
    local checkpoint_name="$1"
    local key_id="$2"
    local policy_type="$3"
    local policy_value="$4"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$checkpoint_name" ]] || [[ -z "$key_id" ]] || [[ -z "$policy_type" ]]; then
        echo "Error: Checkpoint name, key ID, and policy type required" >&2
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

    # Validate policy type
    case "$policy_type" in
        time|usage|failure)
            ;;
        *)
            echo "Error: Invalid policy type. Must be: time, usage, or failure" >&2
            return 1
            ;;
    esac

    # Create or update policy file
    local policy_file="$checkpoint_dir/keys/${key_id}.policy"

    # Calculate expiry for time-based policies
    local expiry=""
    if [[ "$policy_type" == "time" ]]; then
        # Parse duration (e.g., 30d, 24h, 7200s)
        local value="${policy_value%[a-z]}"
        local unit="${policy_value: -1}"

        local seconds=0
        case "$unit" in
            s) seconds=$value ;;
            m) seconds=$((value * 60)) ;;
            h) seconds=$((value * 3600)) ;;
            d) seconds=$((value * 86400)) ;;
            *)
                echo "Error: Invalid time unit. Use s, m, h, or d" >&2
                return 1
                ;;
        esac

        expiry=$(date -u -d "+${seconds} seconds" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v +${seconds}S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
    fi

    # Create policy file
    cat > "$policy_file" <<EOF
{
  "key_id": "$key_id",
  "policy_type": "$policy_type",
  "policy_value": "$policy_value",
  "set_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  $(if [[ -n "$expiry" ]]; then echo "\"expires_at\": \"$expiry\","; fi)
  "current_usage": 0,
  "current_failures": 0,
  "status": "active"
}
EOF

    echo "Policy set for key '$key_id'"
    echo "Type: $policy_type"
    echo "Value: $policy_value"
    if [[ -n "$expiry" ]]; then
        echo "Expires: $expiry"
    fi

    return 0
}

:<<-"DOCS.@wireguard:key:check_expiry"
    Checks if a key has expired based on its policy.

    @param $1 - Checkpoint name
    @param $2 - Key ID
    @return   - 0 if key is valid, 1 if expired
DOCS.@wireguard:key:check_expiry

function @wireguard:key:check_expiry {
    local checkpoint_name="$1"
    local key_id="$2"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$checkpoint_name" ]] || [[ -z "$key_id" ]]; then
        echo "Error: Checkpoint name and key ID required" >&2
        return 1
    fi

    local checkpoint_dir="$base_dir/$checkpoint_name"
    local policy_file="$checkpoint_dir/keys/${key_id}.policy"

    if [[ ! -f "$policy_file" ]]; then
        # No policy set, key is valid
        return 0
    fi

    local policy_type=$(grep -oP '"policy_type":\s*"\K[^"]+' "$policy_file")
    local status=$(grep -oP '"status":\s*"\K[^"]+' "$policy_file")

    # Check if already marked as expired
    if [[ "$status" == "expired" ]]; then
        echo "Key expired"
        return 1
    fi

    case "$policy_type" in
        time)
            local expires_at=$(grep -oP '"expires_at":\s*"\K[^"]+' "$policy_file")
            local current_time=$(date -u +%s)
            local expiry_time=$(date -u -d "$expires_at" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires_at" +%s 2>/dev/null)

            if [[ $current_time -ge $expiry_time ]]; then
                # Mark as expired
                sed -i 's/"status":\s*"[^"]*"/"status": "expired"/' "$policy_file"
                echo "Key expired (time-based)"
                return 1
            fi
            ;;

        usage)
            local policy_value=$(grep -oP '"policy_value":\s*"?\K[0-9]+' "$policy_file")
            local current_usage=$(grep -oP '"current_usage":\s*\K[0-9]+' "$policy_file")

            if [[ $current_usage -ge $policy_value ]]; then
                # Mark as expired
                sed -i 's/"status":\s*"[^"]*"/"status": "expired"/' "$policy_file"
                echo "Key expired (usage-based)"
                return 1
            fi
            ;;

        failure)
            local policy_value=$(grep -oP '"policy_value":\s*"?\K[0-9]+' "$policy_file")
            local current_failures=$(grep -oP '"current_failures":\s*\K[0-9]+' "$policy_file")

            if [[ $current_failures -ge $policy_value ]]; then
                # Mark as expired
                sed -i 's/"status":\s*"[^"]*"/"status": "expired"/' "$policy_file"
                echo "Key expired (failure-based)"
                return 1
            fi
            ;;
    esac

    echo "Key valid"
    return 0
}

:<<-"DOCS.@wireguard:key:update_usage"
    Updates the usage counter for a key.

    @param $1 - Checkpoint name
    @param $2 - Key ID
    @param $3 - Bytes transferred
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:key:update_usage

function @wireguard:key:update_usage {
    local checkpoint_name="$1"
    local key_id="$2"
    local bytes="$3"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$checkpoint_name" ]] || [[ -z "$key_id" ]] || [[ -z "$bytes" ]]; then
        echo "Error: Checkpoint name, key ID, and bytes required" >&2
        return 1
    fi

    local checkpoint_dir="$base_dir/$checkpoint_name"
    local policy_file="$checkpoint_dir/keys/${key_id}.policy"

    if [[ ! -f "$policy_file" ]]; then
        echo "Error: No policy set for key '$key_id'" >&2
        return 1
    fi

    # Get current usage
    local current_usage=$(grep -oP '"current_usage":\s*\K[0-9]+' "$policy_file")
    local new_usage=$((current_usage + bytes))

    # Update usage
    sed -i "s/\"current_usage\":\s*[0-9]*/\"current_usage\": $new_usage/" "$policy_file"

    return 0
}

:<<-"DOCS.@wireguard:key:record_failure"
    Records a connection failure for a key.

    @param $1 - Checkpoint name
    @param $2 - Key ID
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:key:record_failure

function @wireguard:key:record_failure {
    local checkpoint_name="$1"
    local key_id="$2"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$checkpoint_name" ]] || [[ -z "$key_id" ]]; then
        echo "Error: Checkpoint name and key ID required" >&2
        return 1
    fi

    local checkpoint_dir="$base_dir/$checkpoint_name"
    local policy_file="$checkpoint_dir/keys/${key_id}.policy"

    if [[ ! -f "$policy_file" ]]; then
        echo "Error: No policy set for key '$key_id'" >&2
        return 1
    fi

    # Get current failures
    local current_failures=$(grep -oP '"current_failures":\s*\K[0-9]+' "$policy_file")
    local new_failures=$((current_failures + 1))

    # Update failures
    sed -i "s/\"current_failures\":\s*[0-9]*/\"current_failures\": $new_failures/" "$policy_file"

    return 0
}

:<<-"DOCS.@wireguard:key:rotate"
    Rotates a key by revoking the old one and allocating a new one.

    @param $1 - Checkpoint name
    @param $2 - Old key ID
    @param $3 - Accessor ID (for the new key)
    @param $4 - Purpose
    @return   - 0 on success, 1 on failure

    Outputs the new key ID.
DOCS.@wireguard:key:rotate

function @wireguard:key:rotate {
    local checkpoint_name="$1"
    local old_key_id="$2"
    local accessor_id="$3"
    local purpose="$4"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$checkpoint_name" ]] || [[ -z "$old_key_id" ]]; then
        echo "Error: Checkpoint name and old key ID required" >&2
        return 1
    fi

    # If accessor_id not provided, try to get it from old key metadata
    if [[ -z "$accessor_id" ]]; then
        local checkpoint_dir="$base_dir/$checkpoint_name"
        local meta_file="$checkpoint_dir/keys/${old_key_id}.meta"

        if [[ -f "$meta_file" ]]; then
            accessor_id=$(grep -oP '"accessor_id":\s*"\K[^"]+' "$meta_file")
        fi

        if [[ -z "$accessor_id" ]]; then
            echo "Error: Accessor ID required for key rotation" >&2
            return 1
        fi
    fi

    # If purpose not provided, try to get it from old key metadata
    if [[ -z "$purpose" ]]; then
        local checkpoint_dir="$base_dir/$checkpoint_name"
        local meta_file="$checkpoint_dir/keys/${old_key_id}.meta"

        if [[ -f "$meta_file" ]]; then
            purpose=$(grep -oP '"purpose":\s*"\K[^"]+' "$meta_file")
        fi

        if [[ -z "$purpose" ]]; then
            purpose="Key rotation"
        fi
    fi

    echo "Rotating key '$old_key_id' for checkpoint '$checkpoint_name'"

    # Allocate new key
    local new_key_id=$(@wireguard:checkpoint:allocate "$checkpoint_name" "$accessor_id" "$purpose (rotated from $old_key_id)")

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to allocate new key" >&2
        return 1
    fi

    # Revoke old key
    @wireguard:checkpoint:revoke "$checkpoint_name" "$old_key_id" "Key rotation"

    # Copy policy from old key to new key if it exists
    local checkpoint_dir="$base_dir/$checkpoint_name"
    local old_policy_file="$checkpoint_dir/keys/revoked/${old_key_id}.policy"
    local new_policy_file="$checkpoint_dir/keys/${new_key_id}.policy"

    if [[ -f "$old_policy_file" ]]; then
        # Update policy for new key
        sed "s/\"key_id\":\s*\"[^\"]*\"/\"key_id\": \"$new_key_id\"/" "$old_policy_file" > "$new_policy_file"
        sed -i "s/\"set_at\":\s*\"[^\"]*\"/\"set_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"/" "$new_policy_file"
        sed -i "s/\"current_usage\":\s*[0-9]*/\"current_usage\": 0/" "$new_policy_file"
        sed -i "s/\"current_failures\":\s*[0-9]*/\"current_failures\": 0/" "$new_policy_file"
        sed -i "s/\"status\":\s*\"[^\"]*\"/\"status\": \"active\"/" "$new_policy_file"
    fi

    echo "Key rotated successfully"
    echo "Old key: $old_key_id (revoked)"
    echo "New key: $new_key_id"

    # Output new key ID
    echo "$new_key_id"

    return 0
}

:<<-"DOCS.@wireguard:key:scan_expired"
    Scans all keys in a checkpoint for expired keys.

    @param $1 - Checkpoint name
    @param $2 - Auto-rotate expired keys (yes/no, default: no)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:key:scan_expired

function @wireguard:key:scan_expired {
    local checkpoint_name="$1"
    local auto_rotate="${2:-no}"
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

    echo "Scanning for expired keys in checkpoint: $checkpoint_name"
    echo "=========================================================="

    local expired_count=0

    for key_file in "$checkpoint_dir/keys/"*.private; do
        if [[ -f "$key_file" ]]; then
            local key_id=$(basename "$key_file" .private)

            # Skip base key
            if [[ "$key_id" == "base" ]]; then
                continue
            fi

            # Check if key has a policy
            if [[ ! -f "$checkpoint_dir/keys/${key_id}.policy" ]]; then
                continue
            fi

            # Check expiry
            @wireguard:key:check_expiry "$checkpoint_name" "$key_id" &>/dev/null

            if [[ $? -ne 0 ]]; then
                echo ""
                echo "Expired key: $key_id"

                # Get accessor info
                local accessor_id=""
                if [[ -f "$checkpoint_dir/keys/${key_id}.meta" ]]; then
                    accessor_id=$(grep -oP '"accessor_id":\s*"\K[^"]+' "$checkpoint_dir/keys/${key_id}.meta")
                    echo "  Accessor: $accessor_id"
                fi

                ((expired_count++))

                # Auto-rotate if requested
                if [[ "$auto_rotate" == "yes" ]]; then
                    echo "  Rotating key..."
                    local new_key_id=$(@wireguard:key:rotate "$checkpoint_name" "$key_id")
                    echo "  New key: $new_key_id"
                fi
            fi
        fi
    done

    echo ""
    echo "Scan complete. Expired keys found: $expired_count"

    return 0
}

:<<-"EXAMPLE.keymanagement"
    # Set a time-based policy (expire after 30 days)
    @wireguard:key:set_policy myserver $key_id time 30d

    # Set a usage-based policy (expire after 1GB)
    @wireguard:key:set_policy myserver $key_id usage 1073741824

    # Set a failure-based policy (expire after 3 failures)
    @wireguard:key:set_policy myserver $key_id failure 3

    # Check if a key has expired
    @wireguard:key:check_expiry myserver $key_id

    # Update usage for a key
    @wireguard:key:update_usage myserver $key_id 1048576

    # Record a connection failure
    @wireguard:key:record_failure myserver $key_id

    # Rotate a key
    new_key=$(@wireguard:key:rotate myserver $old_key_id user:alice "VPN Access")

    # Scan for expired keys
    @wireguard:key:scan_expired myserver

    # Scan and auto-rotate expired keys
    @wireguard:key:scan_expired myserver yes
EXAMPLE.keymanagement
