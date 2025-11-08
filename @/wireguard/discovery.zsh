#!/bin/zsh
## WireGuard Discovery and Routing (Sonar Ping Mechanism)
## Uses WireGuard's cryptokey routing as a discovery protocol

:<<-"DOCS.@wireguard:discovery:query"
    Queries a checkpoint about another checkpoint (Sonar Ping).

    The sonar ping mechanism enables discovery through the network:
    1. Checkpoint A sends query to B over their established tunnel
    2. B checks if C is known and whether policy allows sharing this information
    3. If allowed, B responds with information about C and notifies C about A
    4. A and C can establish connection based on configuration strategy

    @param $1 - Source checkpoint name (A)
    @param $2 - Intermediate checkpoint name (B)
    @param $3 - Target checkpoint name (C)
    @param $4 - Query type (info, route, trust)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:discovery:query

function @wireguard:discovery:query {
    local source_checkpoint="$1"
    local intermediate_checkpoint="$2"
    local target_checkpoint="$3"
    local query_type="${4:-info}"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$source_checkpoint" ]] || [[ -z "$intermediate_checkpoint" ]] || [[ -z "$target_checkpoint" ]]; then
        echo "Error: Source, intermediate, and target checkpoint names required" >&2
        return 1
    fi

    local source_dir="$base_dir/$source_checkpoint"
    local intermediate_dir="$base_dir/$intermediate_checkpoint"

    echo "Sonar Ping: $source_checkpoint -> $intermediate_checkpoint -> $target_checkpoint"
    echo "Query type: $query_type"

    # Check if source checkpoint exists
    if [[ ! -d "$source_dir" ]]; then
        echo "Error: Source checkpoint '$source_checkpoint' not found" >&2
        return 1
    fi

    # Check if intermediate checkpoint exists
    if [[ ! -d "$intermediate_dir" ]]; then
        echo "Error: Intermediate checkpoint '$intermediate_checkpoint' not found" >&2
        return 1
    fi

    # Create discovery query directory
    mkdir -p "$intermediate_dir/discovery/queries"

    # Generate query ID
    local query_id="query_$(date +%s)_$(od -An -N4 -tx /dev/urandom | tr -d ' ')"

    # Create query file
    cat > "$intermediate_dir/discovery/queries/${query_id}.json" <<EOF
{
  "query_id": "$query_id",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "source": "$source_checkpoint",
  "target": "$target_checkpoint",
  "query_type": "$query_type",
  "status": "pending"
}
EOF

    echo "Query created: $query_id"

    # Process query
    @wireguard:discovery:process_query "$intermediate_checkpoint" "$query_id"

    return $?
}

:<<-"DOCS.@wireguard:discovery:process_query"
    Processes a discovery query at the intermediate checkpoint.

    @param $1 - Intermediate checkpoint name
    @param $2 - Query ID
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:discovery:process_query

function @wireguard:discovery:process_query {
    local checkpoint_name="$1"
    local query_id="$2"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$checkpoint_name" ]] || [[ -z "$query_id" ]]; then
        echo "Error: Checkpoint name and query ID required" >&2
        return 1
    fi

    local checkpoint_dir="$base_dir/$checkpoint_name"
    local query_file="$checkpoint_dir/discovery/queries/${query_id}.json"

    if [[ ! -f "$query_file" ]]; then
        echo "Error: Query '$query_id' not found" >&2
        return 1
    fi

    # Read query details
    local source=$(grep -oP '"source":\s*"\K[^"]+' "$query_file")
    local target=$(grep -oP '"target":\s*"\K[^"]+' "$query_file")
    local query_type=$(grep -oP '"query_type":\s*"\K[^"]+' "$query_file")

    echo "Processing query $query_id at checkpoint $checkpoint_name"
    echo "  Source: $source"
    echo "  Target: $target"
    echo "  Type: $query_type"

    # Check if target checkpoint is known
    local target_dir="$base_dir/$target"

    if [[ ! -d "$target_dir" ]]; then
        # Target not known
        sed -i 's/"status":\s*"[^"]*"/"status": "target_unknown"/' "$query_file"
        echo "Target checkpoint not found"
        return 1
    fi

    # Check policy - can we share information about target with source?
    # Default policy: allow sharing if both source and target are known
    local policy_allows=true

    if [[ "$policy_allows" == "true" ]]; then
        # Get target information
        local target_pubkey=$(cat "$target_dir/keys/base.public" 2>/dev/null)

        # Create response
        mkdir -p "$checkpoint_dir/discovery/responses"

        cat > "$checkpoint_dir/discovery/responses/${query_id}.json" <<EOF
{
  "query_id": "$query_id",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "source": "$source",
  "target": "$target",
  "target_info": {
    "name": "$target",
    "public_key": "$target_pubkey"
  },
  "status": "allowed"
}
EOF

        # Notify target about source
        @wireguard:discovery:notify "$target" "$source" "$checkpoint_name"

        # Update query status
        sed -i 's/"status":\s*"[^"]*"/"status": "completed"/' "$query_file"

        echo "Query processed successfully"
        echo "Target public key: $target_pubkey"

        return 0
    else
        # Policy denies sharing information
        sed -i 's/"status":\s*"[^"]*"/"status": "policy_denied"/' "$query_file"
        echo "Policy denies sharing information about target"
        return 1
    fi
}

:<<-"DOCS.@wireguard:discovery:notify"
    Notifies a checkpoint about another checkpoint that is interested in connecting.

    @param $1 - Target checkpoint name
    @param $2 - Source checkpoint name
    @param $3 - Intermediate checkpoint name (who facilitated the discovery)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:discovery:notify

function @wireguard:discovery:notify {
    local target_checkpoint="$1"
    local source_checkpoint="$2"
    local intermediate_checkpoint="$3"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$target_checkpoint" ]] || [[ -z "$source_checkpoint" ]]; then
        echo "Error: Target and source checkpoint names required" >&2
        return 1
    fi

    local target_dir="$base_dir/$target_checkpoint"

    if [[ ! -d "$target_dir" ]]; then
        echo "Error: Target checkpoint '$target_checkpoint' not found" >&2
        return 1
    fi

    # Create notifications directory
    mkdir -p "$target_dir/discovery/notifications"

    # Generate notification ID
    local notification_id="notify_$(date +%s)_$(od -An -N4 -tx /dev/urandom | tr -d ' ')"

    # Create notification
    cat > "$target_dir/discovery/notifications/${notification_id}.json" <<EOF
{
  "notification_id": "$notification_id",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "interested_party": "$source_checkpoint",
  "facilitator": "$intermediate_checkpoint",
  "status": "pending"
}
EOF

    echo "Notification sent to $target_checkpoint about $source_checkpoint"

    return 0
}

:<<-"DOCS.@wireguard:discovery:list_known"
    Lists all known checkpoints (direct peers and discovered).

    @param $1 - Checkpoint name
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:discovery:list_known

function @wireguard:discovery:list_known {
    local checkpoint_name="$1"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"
    local tunnel_dir="${WIREGUARD_TUNNEL_CONFIG:-/var/lib/wireguard/tunnels}"

    if [[ -z "$checkpoint_name" ]]; then
        echo "Error: Checkpoint name required" >&2
        return 1
    fi

    echo "Known checkpoints for: $checkpoint_name"
    echo "========================================"

    # Find all tunnels involving this checkpoint
    echo ""
    echo "Direct Peers (via tunnels):"
    echo "---------------------------"

    for tunnel in "$tunnel_dir"/*; do
        if [[ -d "$tunnel" ]]; then
            local tunnel_name=$(basename "$tunnel")
            local metadata_file="$tunnel/metadata.json"

            if [[ -f "$metadata_file" ]]; then
                # Check if this checkpoint is part of the tunnel
                if grep -q "\"$checkpoint_name\"" "$metadata_file"; then
                    # List other checkpoints in this tunnel
                    local checkpoints=($(grep -oP '"checkpoints":\s*\[\s*\K[^\]]+' "$metadata_file" | tr -d '",' | tr '\n' ' '))

                    for cp in "${checkpoints[@]}"; do
                        if [[ "$cp" != "$checkpoint_name" ]]; then
                            echo "  - $cp (tunnel: $tunnel_name)"
                        fi
                    done
                fi
            fi
        fi
    done

    # List discovered checkpoints (from notifications)
    echo ""
    echo "Discovered Checkpoints:"
    echo "-----------------------"

    local checkpoint_dir="$base_dir/$checkpoint_name"

    if [[ -d "$checkpoint_dir/discovery/notifications" ]]; then
        for notification_file in "$checkpoint_dir/discovery/notifications"/*.json; do
            if [[ -f "$notification_file" ]]; then
                local interested_party=$(grep -oP '"interested_party":\s*"\K[^"]+' "$notification_file")
                local facilitator=$(grep -oP '"facilitator":\s*"\K[^"]+' "$notification_file")

                echo "  - $interested_party (via $facilitator)"
            fi
        done
    fi

    return 0
}

:<<-"DOCS.@wireguard:discovery:establish_route"
    Establishes a route between two checkpoints based on discovery.

    This uses the sonar ping mechanism to find a path and establish a connection.

    @param $1 - Source checkpoint name
    @param $2 - Target checkpoint name
    @param $3 - Strategy (direct, relay, auto)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:discovery:establish_route

function @wireguard:discovery:establish_route {
    local source_checkpoint="$1"
    local target_checkpoint="$2"
    local strategy="${3:-auto}"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$source_checkpoint" ]] || [[ -z "$target_checkpoint" ]]; then
        echo "Error: Source and target checkpoint names required" >&2
        return 1
    fi

    echo "Establishing route: $source_checkpoint -> $target_checkpoint"
    echo "Strategy: $strategy"

    case "$strategy" in
        direct)
            # Attempt direct connection
            echo "Creating direct tunnel..."
            @wireguard:tunnel:create "direct_${source_checkpoint}_${target_checkpoint}" p2p "$source_checkpoint,$target_checkpoint"
            @wireguard:tunnel:establish "direct_${source_checkpoint}_${target_checkpoint}"
            ;;

        relay)
            # Find intermediate checkpoint and establish relay
            echo "Finding relay checkpoint..."
            # This would involve more complex logic to find a suitable relay
            echo "Relay strategy not fully implemented in this example"
            ;;

        auto)
            # Try direct first, fall back to relay if needed
            echo "Trying direct connection..."
            @wireguard:tunnel:create "auto_${source_checkpoint}_${target_checkpoint}" p2p "$source_checkpoint,$target_checkpoint" 2>/dev/null

            if [[ $? -eq 0 ]]; then
                @wireguard:tunnel:establish "auto_${source_checkpoint}_${target_checkpoint}"
            else
                echo "Direct connection failed, falling back to relay..."
                @wireguard:discovery:establish_route "$source_checkpoint" "$target_checkpoint" relay
            fi
            ;;

        *)
            echo "Error: Invalid strategy. Must be: direct, relay, or auto" >&2
            return 1
            ;;
    esac

    return 0
}

:<<-"DOCS.@wireguard:discovery:check_trust_chain"
    Checks the chain of trust between two checkpoints.

    If checkpoint A has base-level trust with B, and B has base-level trust with C,
    this checks whether the chain of trust from A to B to C is valid.

    @param $1 - Source checkpoint name
    @param $2 - Target checkpoint name
    @param $3 - Maximum chain length (default: 3)
    @return   - 0 if trust chain exists, 1 otherwise
DOCS.@wireguard:discovery:check_trust_chain

function @wireguard:discovery:check_trust_chain {
    local source_checkpoint="$1"
    local target_checkpoint="$2"
    local max_length="${3:-3}"
    local base_dir="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"
    local tunnel_dir="${WIREGUARD_TUNNEL_CONFIG:-/var/lib/wireguard/tunnels}"

    if [[ -z "$source_checkpoint" ]] || [[ -z "$target_checkpoint" ]]; then
        echo "Error: Source and target checkpoint names required" >&2
        return 1
    fi

    echo "Checking trust chain: $source_checkpoint -> $target_checkpoint"
    echo "Max chain length: $max_length"

    # BFS to find path
    local visited=()
    local queue=("$source_checkpoint:0")

    while [[ ${#queue[@]} -gt 0 ]]; do
        # Dequeue
        local current="${queue[1]}"
        queue=("${queue[@]:2}")

        IFS=':' read -r checkpoint depth <<< "$current"

        # Check if we've reached target
        if [[ "$checkpoint" == "$target_checkpoint" ]]; then
            echo "Trust chain found! Length: $depth"
            return 0
        fi

        # Check if we've exceeded max depth
        if [[ $depth -ge $max_length ]]; then
            continue
        fi

        # Mark as visited
        visited+=("$checkpoint")

        # Find direct peers
        for tunnel in "$tunnel_dir"/*; do
            if [[ -d "$tunnel" ]]; then
                local metadata_file="$tunnel/metadata.json"

                if [[ -f "$metadata_file" ]]; then
                    # Check if this checkpoint is part of the tunnel
                    if grep -q "\"$checkpoint\"" "$metadata_file"; then
                        # Get other checkpoints in this tunnel
                        local checkpoints=($(grep -oP '"checkpoints":\s*\[\s*\K[^\]]+' "$metadata_file" | tr -d '",' | tr '\n' ' '))

                        for cp in "${checkpoints[@]}"; do
                            if [[ "$cp" != "$checkpoint" ]] && [[ ! " ${visited[@]} " =~ " ${cp} " ]]; then
                                # Add to queue
                                queue+=("$cp:$((depth + 1))")
                            fi
                        done
                    fi
                fi
            fi
        done
    done

    echo "No trust chain found within length $max_length"
    return 1
}

:<<-"EXAMPLE.discovery"
    # Query checkpoint B about checkpoint C from checkpoint A
    @wireguard:discovery:query serverA serverB serverC info

    # List all known checkpoints
    @wireguard:discovery:list_known serverA

    # Establish a route between two checkpoints
    @wireguard:discovery:establish_route serverA serverC auto

    # Check trust chain
    @wireguard:discovery:check_trust_chain serverA serverC 3

    # Process a discovery query
    @wireguard:discovery:process_query serverB $query_id

    # Notify a checkpoint about an interested party
    @wireguard:discovery:notify serverC serverA serverB
EXAMPLE.discovery
