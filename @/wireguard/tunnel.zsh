#!/bin/zsh
## WireGuard Tunnel Abstraction
## Manages connections between 2 or more checkpoints

:<<-"DOCS.@wireguard:tunnel:create"
    Creates a tunnel between two or more checkpoints.

    A tunnel represents the connection between checkpoints. Tunnels can be:
    - Point-to-point (2 checkpoints)
    - Multi-point (3+ checkpoints)
    - Shared (multiple accessors use the same tunnel)
    - Private (dedicated to specific accessors)
    - Restricted (policy-controlled access)

    @param $1 - Tunnel name
    @param $2 - Tunnel type (p2p, multipoint, shared, private, restricted)
    @param $3 - Comma-separated list of checkpoint names
    @param $4 - Tunnel configuration directory (optional, defaults to /var/lib/wireguard/tunnels)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:tunnel:create

function @wireguard:tunnel:create {
    local tunnel_name="$1"
    local tunnel_type="$2"
    local checkpoints="$3"
    local config_dir="${4:-/var/lib/wireguard/tunnels}"

    if [[ -z "$tunnel_name" ]] || [[ -z "$tunnel_type" ]] || [[ -z "$checkpoints" ]]; then
        echo "Error: Tunnel name, type, and checkpoints required" >&2
        return 1
    fi

    # Validate tunnel type
    case "$tunnel_type" in
        p2p|multipoint|shared|private|restricted)
            ;;
        *)
            echo "Error: Invalid tunnel type. Must be: p2p, multipoint, shared, private, or restricted" >&2
            return 1
            ;;
    esac

    # Split checkpoints into array
    local checkpoint_array=(${(s:,:)checkpoints})

    # Validate minimum checkpoints based on type
    if [[ "$tunnel_type" == "p2p" ]] && [[ ${#checkpoint_array[@]} -ne 2 ]]; then
        echo "Error: p2p tunnels require exactly 2 checkpoints" >&2
        return 1
    fi

    if [[ ${#checkpoint_array[@]} -lt 2 ]]; then
        echo "Error: Tunnels require at least 2 checkpoints" >&2
        return 1
    fi

    local tunnel_dir="$config_dir/$tunnel_name"

    # Check if tunnel already exists
    if [[ -d "$tunnel_dir" ]]; then
        echo "Error: Tunnel '$tunnel_name' already exists" >&2
        return 1
    fi

    # Create tunnel directory
    mkdir -p "$tunnel_dir"/{peers,config,logs}

    # Create tunnel metadata
    cat > "$tunnel_dir/metadata.json" <<EOF
{
  "name": "$tunnel_name",
  "type": "$tunnel_type",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "checkpoints": [
$(for cp in "${checkpoint_array[@]}"; do echo "    \"$cp\","; done | sed '$ s/,$//')
  ],
  "status": "created"
}
EOF

    # Create peer configuration directory for each checkpoint
    for checkpoint in "${checkpoint_array[@]}"; do
        mkdir -p "$tunnel_dir/peers/$checkpoint"
    done

    # Initialize tunnel log
    cat > "$tunnel_dir/logs/tunnel.log" <<EOF
# WireGuard Tunnel Log
# Tunnel: $tunnel_name
# Type: $tunnel_type
# Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Format: TIMESTAMP|CHECKPOINT|EVENT|DETAILS
EOF

    echo "Tunnel '$tunnel_name' created successfully"
    echo "Type: $tunnel_type"
    echo "Checkpoints: $checkpoints"

    return 0
}

:<<-"DOCS.@wireguard:tunnel:add_peer"
    Adds a peer configuration to a tunnel for a specific checkpoint.

    @param $1 - Tunnel name
    @param $2 - Checkpoint name
    @param $3 - Peer public key
    @param $4 - Peer endpoint (IP:PORT)
    @param $5 - Allowed IPs (comma-separated)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:tunnel:add_peer

function @wireguard:tunnel:add_peer {
    local tunnel_name="$1"
    local checkpoint="$2"
    local peer_public_key="$3"
    local peer_endpoint="$4"
    local allowed_ips="$5"
    local config_dir="${WIREGUARD_TUNNEL_CONFIG:-/var/lib/wireguard/tunnels}"

    if [[ -z "$tunnel_name" ]] || [[ -z "$checkpoint" ]] || [[ -z "$peer_public_key" ]]; then
        echo "Error: Tunnel name, checkpoint, and peer public key required" >&2
        return 1
    fi

    local tunnel_dir="$config_dir/$tunnel_name"

    if [[ ! -d "$tunnel_dir" ]]; then
        echo "Error: Tunnel '$tunnel_name' not found" >&2
        return 1
    fi

    # Generate peer ID
    local peer_id="peer_$(date +%s)_$(echo -n "$peer_public_key" | md5sum | cut -c1-8)"

    # Create peer configuration
    cat > "$tunnel_dir/peers/$checkpoint/${peer_id}.conf" <<EOF
[Peer]
PublicKey = $peer_public_key
$(if [[ -n "$peer_endpoint" ]]; then echo "Endpoint = $peer_endpoint"; fi)
$(if [[ -n "$allowed_ips" ]]; then echo "AllowedIPs = $allowed_ips"; fi)

# Peer ID: $peer_id
# Added: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

    # Log peer addition
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "$timestamp|$checkpoint|PEER_ADDED|peer_id=$peer_id,endpoint=$peer_endpoint" >> "$tunnel_dir/logs/tunnel.log"

    echo "Peer added to tunnel '$tunnel_name' for checkpoint '$checkpoint'"
    echo "Peer ID: $peer_id"

    return 0
}

:<<-"DOCS.@wireguard:tunnel:establish"
    Establishes a tunnel by connecting checkpoints using their base keys.

    This automatically retrieves base keys from checkpoints and creates
    peer configurations for the tunnel.

    @param $1 - Tunnel name
    @param $2 - Network configuration (optional: subnet for auto IP assignment)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:tunnel:establish

function @wireguard:tunnel:establish {
    local tunnel_name="$1"
    local network="$2"
    local config_dir="${WIREGUARD_TUNNEL_CONFIG:-/var/lib/wireguard/tunnels}"
    local checkpoint_base="${WIREGUARD_CHECKPOINT_BASE:-/var/lib/wireguard/checkpoints}"

    if [[ -z "$tunnel_name" ]]; then
        echo "Error: Tunnel name required" >&2
        return 1
    fi

    local tunnel_dir="$config_dir/$tunnel_name"

    if [[ ! -d "$tunnel_dir" ]]; then
        echo "Error: Tunnel '$tunnel_name' not found" >&2
        return 1
    fi

    # Read checkpoint list from metadata
    local checkpoints=($(grep -oP '"checkpoints":\s*\[\s*\K[^\]]+' "$tunnel_dir/metadata.json" | tr -d '",' | tr '\n' ' '))

    echo "Establishing tunnel: $tunnel_name"
    echo "Checkpoints: ${checkpoints[@]}"

    # For each checkpoint, get its base key and create peer configs for all other checkpoints
    local idx=1
    for checkpoint in "${checkpoints[@]}"; do
        local checkpoint_dir="$checkpoint_base/$checkpoint"

        if [[ ! -d "$checkpoint_dir" ]]; then
            echo "Warning: Checkpoint '$checkpoint' not found, skipping" >&2
            continue
        fi

        # Get base public key
        local public_key=$(cat "$checkpoint_dir/keys/base.public" 2>/dev/null)

        if [[ -z "$public_key" ]]; then
            echo "Warning: Base key not found for checkpoint '$checkpoint', skipping" >&2
            continue
        fi

        # Add this checkpoint as a peer to all other checkpoints
        for other_checkpoint in "${checkpoints[@]}"; do
            if [[ "$checkpoint" != "$other_checkpoint" ]]; then
                # For now, we'll use placeholder endpoint and allowed IPs
                # In a real deployment, these would be configured based on network topology
                local endpoint=""
                local allowed_ips=""

                if [[ -n "$network" ]]; then
                    # Auto-assign IP from network
                    allowed_ips="${network%.*}.$idx/32"
                fi

                @wireguard:tunnel:add_peer "$tunnel_name" "$other_checkpoint" "$public_key" "$endpoint" "$allowed_ips"
            fi
        done

        ((idx++))
    done

    # Update tunnel status
    sed -i 's/"status":\s*"[^"]*"/"status": "established"/' "$tunnel_dir/metadata.json"

    # Log establishment
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "$timestamp|ALL|TUNNEL_ESTABLISHED|checkpoints=${#checkpoints[@]}" >> "$tunnel_dir/logs/tunnel.log"

    echo "Tunnel '$tunnel_name' established successfully"

    return 0
}

:<<-"DOCS.@wireguard:tunnel:list"
    Lists all tunnels or tunnels for a specific checkpoint.

    @param $1 - Checkpoint name (optional, lists all if not specified)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:tunnel:list

function @wireguard:tunnel:list {
    local filter_checkpoint="$1"
    local config_dir="${WIREGUARD_TUNNEL_CONFIG:-/var/lib/wireguard/tunnels}"

    if [[ ! -d "$config_dir" ]]; then
        echo "No tunnels configured"
        return 0
    fi

    echo "WireGuard Tunnels"
    echo "================="

    for tunnel_dir in "$config_dir"/*; do
        if [[ -d "$tunnel_dir" ]]; then
            local tunnel_name=$(basename "$tunnel_dir")
            local metadata_file="$tunnel_dir/metadata.json"

            if [[ ! -f "$metadata_file" ]]; then
                continue
            fi

            # If filtering by checkpoint, check if this tunnel includes it
            if [[ -n "$filter_checkpoint" ]]; then
                if ! grep -q "\"$filter_checkpoint\"" "$metadata_file"; then
                    continue
                fi
            fi

            local tunnel_type=$(grep -oP '"type":\s*"\K[^"]+' "$metadata_file")
            local status=$(grep -oP '"status":\s*"\K[^"]+' "$metadata_file")
            local created=$(grep -oP '"created":\s*"\K[^"]+' "$metadata_file")

            echo ""
            echo "Tunnel: $tunnel_name"
            echo "  Type: $tunnel_type"
            echo "  Status: $status"
            echo "  Created: $created"

            # List checkpoints
            echo "  Checkpoints:"
            local checkpoints=($(grep -oP '"checkpoints":\s*\[\s*\K[^\]]+' "$metadata_file" | tr -d '",' | tr '\n' ' '))
            for cp in "${checkpoints[@]}"; do
                echo "    - $cp"
            done
        fi
    done

    return 0
}

:<<-"DOCS.@wireguard:tunnel:status"
    Shows detailed status of a tunnel.

    @param $1 - Tunnel name
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:tunnel:status

function @wireguard:tunnel:status {
    local tunnel_name="$1"
    local config_dir="${WIREGUARD_TUNNEL_CONFIG:-/var/lib/wireguard/tunnels}"

    if [[ -z "$tunnel_name" ]]; then
        echo "Error: Tunnel name required" >&2
        return 1
    fi

    local tunnel_dir="$config_dir/$tunnel_name"

    if [[ ! -d "$tunnel_dir" ]]; then
        echo "Error: Tunnel '$tunnel_name' not found" >&2
        return 1
    fi

    local metadata_file="$tunnel_dir/metadata.json"

    echo "Tunnel: $tunnel_name"
    echo "===================="
    echo ""

    local tunnel_type=$(grep -oP '"type":\s*"\K[^"]+' "$metadata_file")
    local status=$(grep -oP '"status":\s*"\K[^"]+' "$metadata_file")
    local created=$(grep -oP '"created":\s*"\K[^"]+' "$metadata_file")

    echo "Type: $tunnel_type"
    echo "Status: $status"
    echo "Created: $created"
    echo ""

    echo "Checkpoints:"
    local checkpoints=($(grep -oP '"checkpoints":\s*\[\s*\K[^\]]+' "$metadata_file" | tr -d '",' | tr '\n' ' '))
    for cp in "${checkpoints[@]}"; do
        echo "  - $cp"

        # Count peers for this checkpoint
        local peer_count=$(ls -1 "$tunnel_dir/peers/$cp"/*.conf 2>/dev/null | wc -l)
        echo "    Peers: $peer_count"
    done

    echo ""
    echo "Recent Events:"
    echo "--------------"
    tail -n 10 "$tunnel_dir/logs/tunnel.log" 2>/dev/null | grep -v "^#" || echo "No events logged"

    return 0
}

:<<-"DOCS.@wireguard:tunnel:teardown"
    Tears down a tunnel, marking it as inactive.

    @param $1 - Tunnel name
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:tunnel:teardown

function @wireguard:tunnel:teardown {
    local tunnel_name="$1"
    local config_dir="${WIREGUARD_TUNNEL_CONFIG:-/var/lib/wireguard/tunnels}"

    if [[ -z "$tunnel_name" ]]; then
        echo "Error: Tunnel name required" >&2
        return 1
    fi

    local tunnel_dir="$config_dir/$tunnel_name"

    if [[ ! -d "$tunnel_dir" ]]; then
        echo "Error: Tunnel '$tunnel_name' not found" >&2
        return 1
    fi

    # Update status
    sed -i 's/"status":\s*"[^"]*"/"status": "torn_down"/' "$tunnel_dir/metadata.json"

    # Log teardown
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "$timestamp|ALL|TUNNEL_TEARDOWN|" >> "$tunnel_dir/logs/tunnel.log"

    echo "Tunnel '$tunnel_name' torn down"

    return 0
}

:<<-"EXAMPLE.tunnel"
    # Create a point-to-point tunnel
    @wireguard:tunnel:create mytunnel p2p server1,server2

    # Create a multi-point tunnel
    @wireguard:tunnel:create clustertunnel multipoint node1,node2,node3,node4

    # Establish the tunnel (auto-configure peers)
    @wireguard:tunnel:establish mytunnel 10.100.0.0/24

    # Add a peer manually
    @wireguard:tunnel:add_peer mytunnel server1 "abc123..." "203.0.113.1:51820" "10.100.0.2/32"

    # List all tunnels
    @wireguard:tunnel:list

    # List tunnels for a specific checkpoint
    @wireguard:tunnel:list server1

    # Show tunnel status
    @wireguard:tunnel:status mytunnel

    # Tear down tunnel
    @wireguard:tunnel:teardown mytunnel
EXAMPLE.tunnel
