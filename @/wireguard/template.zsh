#!/bin/zsh
## WireGuard Template System
## Reusable configuration patterns for checkpoints and networks

:<<-"DOCS.@wireguard:template:create"
    Creates a reusable template for checkpoint and network configurations.

    Templates define checkpoint properties and connection topologies without
    instance-specific details. Templates can be composed to build complex
    networks from simple patterns.

    Template Syntax Examples:
      [client]<->[server]<->[PublicInternet]
      [hub]<->[spoke1],[hub]<->[spoke2],[hub]<->[spoke3]
      [web]<->[app]<->[db]

    @param $1 - Template name
    @param $2 - Template topology (string describing connections)
    @param $3 - Template description
    @param $4 - Template directory (optional, defaults to /etc/wireguard/templates)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:template:create

function @wireguard:template:create {
    local template_name="$1"
    local topology="$2"
    local description="$3"
    local template_dir="${4:-/etc/wireguard/templates}"

    if [[ -z "$template_name" ]] || [[ -z "$topology" ]]; then
        echo "Error: Template name and topology required" >&2
        return 1
    fi

    mkdir -p "$template_dir"

    local template_file="$template_dir/${template_name}.json"

    # Check if template already exists
    if [[ -f "$template_file" ]]; then
        echo "Error: Template '$template_name' already exists" >&2
        return 1
    fi

    # Parse topology to extract checkpoints and connections
    local checkpoints=()
    local connections=()

    # Extract checkpoint names (between [ and ])
    while [[ "$topology" =~ \[([^\]]+)\] ]]; do
        local checkpoint="${match[1]}"
        if [[ ! " ${checkpoints[@]} " =~ " ${checkpoint} " ]]; then
            checkpoints+=("$checkpoint")
        fi
        topology="${topology[@]/\[$checkpoint\]/}"
    done

    # Reset topology for connection parsing
    topology="$2"

    # Extract connections (patterns like [A]<->[B])
    while [[ "$topology" =~ \[([^\]]+)\](\<-\>|\-\>|\<-)\[([^\]]+)\] ]]; do
        local source="${match[1]}"
        local direction="${match[2]}"
        local target="${match[3]}"

        local connection_type="bidirectional"
        case "$direction" in
            "<->") connection_type="bidirectional" ;;
            "->")  connection_type="unidirectional" ;;
            "<-")  connection_type="reverse" ;;
        esac

        connections+=("$source|$connection_type|$target")

        # Remove this connection from topology for next iteration
        topology="${topology[@]/\[$source\]$direction\[$target\]/}"
    done

    # Create template file
    cat > "$template_file" <<EOF
{
  "name": "$template_name",
  "description": "$description",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "topology": "$2",
  "checkpoints": [
$(for cp in "${checkpoints[@]}"; do echo "    \"$cp\","; done | sed '$ s/,$//')
  ],
  "connections": [
$(for conn in "${connections[@]}"; do
    IFS='|' read -r src type dst <<< "$conn"
    echo "    {\"source\": \"$src\", \"type\": \"$type\", \"target\": \"$dst\"},"
done | sed '$ s/,$//')
  ]
}
EOF

    echo "Template '$template_name' created successfully"
    echo "Checkpoints: ${checkpoints[@]}"
    echo "Connections: ${#connections[@]}"

    return 0
}

:<<-"DOCS.@wireguard:template:instantiate"
    Instantiates a template with specific configuration values.

    Creates actual checkpoints and tunnels based on a template, applying
    instance-specific details like IP addresses, endpoints, etc.

    @param $1 - Template name
    @param $2 - Instance name
    @param $3 - Instance configuration file (JSON format)
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:template:instantiate

function @wireguard:template:instantiate {
    local template_name="$1"
    local instance_name="$2"
    local instance_config="$3"
    local template_dir="${WIREGUARD_TEMPLATE_DIR:-/etc/wireguard/templates}"

    if [[ -z "$template_name" ]] || [[ -z "$instance_name" ]]; then
        echo "Error: Template name and instance name required" >&2
        return 1
    fi

    local template_file="$template_dir/${template_name}.json"

    if [[ ! -f "$template_file" ]]; then
        echo "Error: Template '$template_name' not found" >&2
        return 1
    fi

    echo "Instantiating template: $template_name"
    echo "Instance: $instance_name"

    # Read checkpoints from template
    local checkpoints=($(grep -oP '"checkpoints":\s*\[\s*\K[^\]]+' "$template_file" | tr -d '",' | tr '\n' ' '))

    # Create checkpoints
    echo ""
    echo "Creating checkpoints..."
    for cp in "${checkpoints[@]}"; do
        local checkpoint_instance="${instance_name}_${cp}"
        echo "  - Creating checkpoint: $checkpoint_instance"

        @wireguard:checkpoint:create "$checkpoint_instance" || {
            echo "Warning: Failed to create checkpoint $checkpoint_instance" >&2
        }
    done

    # Read connections from template
    echo ""
    echo "Creating tunnels..."

    # Parse connections (simplified - would need jq for production)
    local in_connections=false
    local connection_idx=0

    while IFS= read -r line; do
        if [[ "$line" =~ '"connections":' ]]; then
            in_connections=true
            continue
        fi

        if [[ "$in_connections" == "true" ]]; then
            if [[ "$line" =~ '"source":\s*"([^"]+)"' ]]; then
                local source="${match[1]}"
            fi
            if [[ "$line" =~ '"target":\s*"([^"]+)"' ]]; then
                local target="${match[1]}"

                # Create tunnel for this connection
                local tunnel_name="${instance_name}_${source}_${target}"
                local source_instance="${instance_name}_${source}"
                local target_instance="${instance_name}_${target}"

                echo "  - Creating tunnel: $tunnel_name"
                @wireguard:tunnel:create "$tunnel_name" "p2p" "${source_instance},${target_instance}" || {
                    echo "Warning: Failed to create tunnel $tunnel_name" >&2
                }

                ((connection_idx++))
            fi

            if [[ "$line" =~ ']' ]] && [[ ! "$line" =~ '\[' ]]; then
                break
            fi
        fi
    done < "$template_file"

    echo ""
    echo "Template instantiation complete"
    echo "Instance: $instance_name"
    echo "Checkpoints created: ${#checkpoints[@]}"
    echo "Tunnels created: $connection_idx"

    return 0
}

:<<-"DOCS.@wireguard:template:list"
    Lists all available templates.

    @return - 0 on success, 1 on failure
DOCS.@wireguard:template:list

function @wireguard:template:list {
    local template_dir="${WIREGUARD_TEMPLATE_DIR:-/etc/wireguard/templates}"

    if [[ ! -d "$template_dir" ]]; then
        echo "No templates available"
        return 0
    fi

    echo "Available WireGuard Templates"
    echo "============================="

    for template_file in "$template_dir"/*.json; do
        if [[ -f "$template_file" ]]; then
            local template_name=$(basename "$template_file" .json)
            local description=$(grep -oP '"description":\s*"\K[^"]+' "$template_file" 2>/dev/null)
            local topology=$(grep -oP '"topology":\s*"\K[^"]+' "$template_file" 2>/dev/null)
            local created=$(grep -oP '"created":\s*"\K[^"]+' "$template_file" 2>/dev/null)

            echo ""
            echo "Template: $template_name"
            echo "  Description: $description"
            echo "  Topology: $topology"
            echo "  Created: $created"
        fi
    done

    return 0
}

:<<-"DOCS.@wireguard:template:show"
    Shows detailed information about a specific template.

    @param $1 - Template name
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:template:show

function @wireguard:template:show {
    local template_name="$1"
    local template_dir="${WIREGUARD_TEMPLATE_DIR:-/etc/wireguard/templates}"

    if [[ -z "$template_name" ]]; then
        echo "Error: Template name required" >&2
        return 1
    fi

    local template_file="$template_dir/${template_name}.json"

    if [[ ! -f "$template_file" ]]; then
        echo "Error: Template '$template_name' not found" >&2
        return 1
    fi

    echo "Template: $template_name"
    echo "======================="
    echo ""

    local description=$(grep -oP '"description":\s*"\K[^"]+' "$template_file")
    local topology=$(grep -oP '"topology":\s*"\K[^"]+' "$template_file")
    local created=$(grep -oP '"created":\s*"\K[^"]+' "$template_file")

    echo "Description: $description"
    echo "Topology: $topology"
    echo "Created: $created"
    echo ""

    echo "Checkpoints:"
    local checkpoints=($(grep -oP '"checkpoints":\s*\[\s*\K[^\]]+' "$template_file" | tr -d '",' | tr '\n' ' '))
    for cp in "${checkpoints[@]}"; do
        echo "  - $cp"
    done

    echo ""
    echo "Connections:"

    # Parse and display connections
    local in_connections=false
    while IFS= read -r line; do
        if [[ "$line" =~ '"connections":' ]]; then
            in_connections=true
            continue
        fi

        if [[ "$in_connections" == "true" ]]; then
            local source=""
            local target=""
            local type=""

            if [[ "$line" =~ '"source":\s*"([^"]+)"' ]]; then
                source="${match[1]}"
            fi
            if [[ "$line" =~ '"type":\s*"([^"]+)"' ]]; then
                type="${match[1]}"
            fi
            if [[ "$line" =~ '"target":\s*"([^"]+)"' ]]; then
                target="${match[1]}"

                echo "  - $source <-> $target ($type)"
            fi

            if [[ "$line" =~ ']' ]] && [[ ! "$line" =~ '\[' ]]; then
                break
            fi
        fi
    done < "$template_file"

    return 0
}

:<<-"DOCS.@wireguard:template:compose"
    Composes multiple templates into a new combined template.

    @param $1 - New template name
    @param $2 - Comma-separated list of template names to compose
    @param $3 - Description
    @return   - 0 on success, 1 on failure
DOCS.@wireguard:template:compose

function @wireguard:template:compose {
    local new_template="$1"
    local templates="$2"
    local description="$3"
    local template_dir="${WIREGUARD_TEMPLATE_DIR:-/etc/wireguard/templates}"

    if [[ -z "$new_template" ]] || [[ -z "$templates" ]]; then
        echo "Error: Template name and component templates required" >&2
        return 1
    fi

    # Split templates into array
    local template_array=(${(s:,:)templates})

    echo "Composing templates: ${template_array[@]}"

    local all_checkpoints=()
    local all_connections=()
    local combined_topology=""

    # Collect checkpoints and connections from all templates
    for tmpl in "${template_array[@]}"; do
        local template_file="$template_dir/${tmpl}.json"

        if [[ ! -f "$template_file" ]]; then
            echo "Error: Template '$tmpl' not found" >&2
            return 1
        fi

        # Read topology
        local topo=$(grep -oP '"topology":\s*"\K[^"]+' "$template_file")
        if [[ -n "$combined_topology" ]]; then
            combined_topology="${combined_topology},"
        fi
        combined_topology="${combined_topology}${topo}"

        # Read checkpoints
        local checkpoints=($(grep -oP '"checkpoints":\s*\[\s*\K[^\]]+' "$template_file" | tr -d '",' | tr '\n' ' '))
        for cp in "${checkpoints[@]}"; do
            if [[ ! " ${all_checkpoints[@]} " =~ " ${cp} " ]]; then
                all_checkpoints+=("$cp")
            fi
        done
    done

    echo "Creating composed template: $new_template"

    # Create the new template with the combined topology
    @wireguard:template:create "$new_template" "$combined_topology" "$description"

    return $?
}

:<<-"EXAMPLE.template"
    # Create a simple client-server template
    @wireguard:template:create vpn "[client]<->[server]" "Simple VPN setup"

    # Create a hub-and-spoke template
    @wireguard:template:create hub-spoke "[hub]<->[spoke1],[hub]<->[spoke2],[hub]<->[spoke3]" "Hub and spoke network"

    # Create a three-tier application template
    @wireguard:template:create three-tier "[web]<->[app]<->[db]" "Three-tier application architecture"

    # List all templates
    @wireguard:template:list

    # Show template details
    @wireguard:template:show vpn

    # Instantiate a template
    @wireguard:template:instantiate vpn "production"

    # Compose multiple templates
    @wireguard:template:compose complex "vpn,hub-spoke" "Complex network combining VPN and hub-spoke"
EXAMPLE.template
