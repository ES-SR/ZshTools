# WireGuard Checkpoint Abstraction

A comprehensive Zsh-based abstraction layer for WireGuard that enables advanced network management, dynamic routing, and secure communication through checkpoints, accessors, tunnels, and templates.

## Table of Contents

- [Overview](#overview)
- [Core Concepts](#core-concepts)
- [Architecture](#architecture)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Components](#components)
- [Use Cases](#use-cases)
- [Examples](#examples)
- [API Reference](#api-reference)
- [Configuration](#configuration)
- [Security](#security)
- [Contributing](#contributing)

## Overview

The WireGuard Checkpoint Abstraction provides a high-level framework for managing WireGuard VPN configurations through reusable patterns and dynamic discovery mechanisms. It enables:

- **Checkpoint Management**: Centralized control of WireGuard endpoints with key and interface allocation
- **Identity Mapping**: Flexible accessor system for different identity domains (users, processes, containers, VMs)
- **Dynamic Routing**: Sonar ping discovery mechanism for automatic route establishment
- **Template System**: Reusable configuration patterns for rapid deployment
- **Key Lifecycle**: Time-based, usage-based, and failure-based key policies
- **Chain of Trust**: Automatic configuration through trusted checkpoint relationships
- **Audit Trails**: Complete logging of all allocations and operations

## Core Concepts

### Checkpoints

Entities that manage WireGuard tunnel endpoints. Each checkpoint:

- Controls keys, interfaces, and routing knowledge
- Allocates keys/interfaces to accessors with defined policies
- Logs all allocations with timestamps, accessor identity, and metadata
- Enforces its own configuration
- Has a "base" key for checkpoint-to-checkpoint communication

### Accessors

Handle identity mapping and authorization for key/interface allocation. Accessor implementations address different identity domains:

- **Users**: Local user accounts
- **Processes**: Running processes (PIDs)
- **Containers**: Docker, Podman, etc.
- **Virtual Machines**: KVM, VMware, VirtualBox, etc.
- **Checkpoints**: Recursive composition (accessors can be checkpoints)

### Tunnels

Connections between 2 or more checkpoints with different types:

- **Point-to-point (p2p)**: Two checkpoints
- **Multipoint**: Three or more checkpoints
- **Shared**: Multiple accessors use the same tunnel
- **Private**: Dedicated to specific accessors
- **Restricted**: Policy-controlled access

### Templates

Reusable configuration patterns defining checkpoint properties and connection topologies:

```
[client]<->[server]<->[PublicInternet]
[hub]<->[spoke1],[hub]<->[spoke2],[hub]<->[spoke3]
[web]<->[app]<->[db]
```

### Discovery and Routing

**Sonar Ping Mechanism**: Uses WireGuard's cryptokey routing as a discovery protocol:

1. Checkpoint A queries B about checkpoint C
2. B checks if C is known and policy allows sharing
3. If allowed, B responds with C's information and notifies C about A
4. A and C can establish connection based on configuration

**Chain of Trust**: If A trusts B, and B trusts C, the chain enables automatic configuration alterations.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     WireGuard Checkpoint                     │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │Checkpoint│  │ Accessor │  │  Tunnel  │  │ Template │   │
│  │Management│  │  System  │  │ Manager  │  │  Engine  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │   Key    │  │Discovery │  │  Audit   │                 │
│  │Lifecycle │  │& Routing │  │   Logs   │                 │
│  └──────────┘  └──────────┘  └──────────┘                 │
├─────────────────────────────────────────────────────────────┤
│                      WireGuard Core                         │
└─────────────────────────────────────────────────────────────┘
```

## Installation

### Prerequisites

- Zsh shell
- WireGuard tools (`wg`, `wg-quick`)
- Root or sudo access (for network operations)

### Setup

1. Clone or copy the WireGuard abstraction files to your ZshTools directory:

```bash
cd ZshTools/@/wireguard
```

2. Source the required modules in your scripts:

```zsh
source "@/wireguard/checkpoint.zsh"
source "@/wireguard/accessor.zsh"
source "@/wireguard/tunnel.zsh"
source "@/wireguard/template.zsh"
source "@/wireguard/keymanagement.zsh"
source "@/wireguard/discovery.zsh"
```

3. Set environment variables (optional):

```zsh
export WIREGUARD_CHECKPOINT_BASE="/var/lib/wireguard/checkpoints"
export WIREGUARD_TUNNEL_CONFIG="/var/lib/wireguard/tunnels"
export WIREGUARD_TEMPLATE_DIR="/etc/wireguard/templates"
export WIREGUARD_ACCESSOR_CONFIG="/etc/wireguard/accessors"
```

## Quick Start

### Create a Simple VPN

```zsh
# Create server checkpoint
@wireguard:checkpoint:create vpn-server

# Register a user accessor
@wireguard:accessor:user:register alice 1001

# Allocate a key with 30-day expiry
key_id=$(@wireguard:checkpoint:allocate vpn-server user:alice "VPN Access" yes)
@wireguard:key:set_policy vpn-server "$key_id" time 30d

# Create client checkpoint
@wireguard:checkpoint:create client-alice

# Create and establish tunnel
@wireguard:tunnel:create vpn-tunnel p2p "vpn-server,client-alice"
@wireguard:tunnel:establish vpn-tunnel 10.200.0.0/24
```

### Use a Template

```zsh
# Create template
@wireguard:template:create roadwarrior \
    "[server]<->[client]" \
    "Road warrior VPN setup"

# Instantiate template
@wireguard:template:instantiate roadwarrior "production"
```

## Components

### checkpoint.zsh

Manages WireGuard checkpoints - entities that control keys, interfaces, and routing.

**Key Functions:**
- `@wireguard:checkpoint:create` - Create a new checkpoint
- `@wireguard:checkpoint:allocate` - Allocate key/interface to accessor
- `@wireguard:checkpoint:revoke` - Revoke a key allocation
- `@wireguard:checkpoint:list` - List all allocations
- `@wireguard:checkpoint:get_base_key` - Get checkpoint's base public key

### accessor.zsh

Handles identity mapping and authorization for different entity types.

**Key Functions:**
- `@wireguard:accessor:register` - Register generic accessor
- `@wireguard:accessor:user:register` - Register user accessor
- `@wireguard:accessor:process:register` - Register process accessor
- `@wireguard:accessor:container:register` - Register container accessor
- `@wireguard:accessor:vm:register` - Register VM accessor
- `@wireguard:accessor:checkpoint:register` - Register checkpoint as accessor
- `@wireguard:accessor:authorize` - Check authorization
- `@wireguard:accessor:list` - List registered accessors

### tunnel.zsh

Manages tunnels - connections between checkpoints.

**Key Functions:**
- `@wireguard:tunnel:create` - Create a tunnel
- `@wireguard:tunnel:add_peer` - Add peer configuration
- `@wireguard:tunnel:establish` - Establish tunnel connections
- `@wireguard:tunnel:list` - List tunnels
- `@wireguard:tunnel:status` - Show tunnel status
- `@wireguard:tunnel:teardown` - Tear down a tunnel

### template.zsh

Provides reusable configuration patterns.

**Key Functions:**
- `@wireguard:template:create` - Create a template
- `@wireguard:template:instantiate` - Apply template to create instances
- `@wireguard:template:list` - List available templates
- `@wireguard:template:show` - Show template details
- `@wireguard:template:compose` - Combine multiple templates

### keymanagement.zsh

Manages key lifecycles with various policies.

**Key Functions:**
- `@wireguard:key:set_policy` - Set lifecycle policy (time/usage/failure)
- `@wireguard:key:check_expiry` - Check if key has expired
- `@wireguard:key:update_usage` - Update usage counter
- `@wireguard:key:record_failure` - Record connection failure
- `@wireguard:key:rotate` - Rotate a key
- `@wireguard:key:scan_expired` - Scan for expired keys

### discovery.zsh

Implements sonar ping mechanism for dynamic route discovery.

**Key Functions:**
- `@wireguard:discovery:query` - Query checkpoint about another
- `@wireguard:discovery:process_query` - Process discovery query
- `@wireguard:discovery:notify` - Notify checkpoint about interested party
- `@wireguard:discovery:list_known` - List known checkpoints
- `@wireguard:discovery:establish_route` - Establish route between checkpoints
- `@wireguard:discovery:check_trust_chain` - Verify chain of trust

## Use Cases

### Road Warrior VPN

Traditional VPN setup with server and multiple clients.

- Template defines server and client checkpoint types
- Adding new device applies template automatically
- Keys generated with time-based expiry policies
- Audit trail of all connections

**Example:** See `examples/roadwarrior-vpn.zsh`

### Secure IPC

Processes communicate through checkpoints for encrypted IPC.

- Each process gets its own checkpoint
- Private tunnels between process pairs
- Usage-based and failure-based policies
- Complete audit trail for compliance

**Example:** See `examples/secure-ipc.zsh`

### High-Availability Clusters

Multi-node clusters with failover capabilities.

- Full mesh connectivity between nodes
- Witness node for quorum
- Automatic route discovery on failure
- Chain of trust for automatic reconfiguration

**Example:** See `examples/ha-cluster.zsh`

### Multi-Cloud Migration

Service architecture spanning multiple cloud providers.

- Template defines service topology
- Apply to new provider for automatic setup
- Dynamic routing adapts to failures
- Network transparency for applications

### Reverse Proxy Setup

Proxy and backend pool configuration.

- Template describes proxy topology
- Container deployment auto-configures networking
- Load balancing through multiple tunnels
- Health checks via failure policies

## Examples

See the `examples/` directory for complete working examples:

- **roadwarrior-vpn.zsh**: Complete VPN server/client setup
- **secure-ipc.zsh**: Inter-process communication using WireGuard
- **ha-cluster.zsh**: High-availability cluster configuration

Run examples:

```bash
zsh @/wireguard/examples/roadwarrior-vpn.zsh
```

## API Reference

### Environment Variables

- `WIREGUARD_CHECKPOINT_BASE`: Base directory for checkpoints (default: `/var/lib/wireguard/checkpoints`)
- `WIREGUARD_TUNNEL_CONFIG`: Tunnel configuration directory (default: `/var/lib/wireguard/tunnels`)
- `WIREGUARD_TEMPLATE_DIR`: Template directory (default: `/etc/wireguard/templates`)
- `WIREGUARD_ACCESSOR_CONFIG`: Accessor configuration directory (default: `/etc/wireguard/accessors`)

### Data Formats

#### Checkpoint Metadata
```json
{
  "name": "checkpoint-name",
  "created": "2025-11-08T12:00:00Z",
  "version": "1.0",
  "type": "checkpoint",
  "base_dir": "/var/lib/wireguard/checkpoints/checkpoint-name"
}
```

#### Key Allocation Metadata
```json
{
  "key_id": "key_1731067200_abc123",
  "accessor_id": "user:alice",
  "purpose": "VPN Access",
  "allocated": "2025-11-08T12:00:00Z",
  "public_key": "base64-encoded-key"
}
```

#### Policy File
```json
{
  "key_id": "key_1731067200_abc123",
  "policy_type": "time",
  "policy_value": "30d",
  "set_at": "2025-11-08T12:00:00Z",
  "expires_at": "2025-12-08T12:00:00Z",
  "current_usage": 0,
  "current_failures": 0,
  "status": "active"
}
```

### Log Formats

#### Allocation Log
```
TIMESTAMP|ACCESSOR_ID|KEY_ID|INTERFACE|ACTION|METADATA
2025-11-08T12:00:00Z|user:alice|key_abc123|wg_vpn_key_abc1|ALLOCATED|VPN Access
2025-11-08T13:00:00Z|user:alice|key_abc123||REVOKED|Key rotation
```

#### Tunnel Log
```
TIMESTAMP|CHECKPOINT|EVENT|DETAILS
2025-11-08T12:00:00Z|server1|TUNNEL_ESTABLISHED|checkpoints=2
2025-11-08T12:01:00Z|server1|PEER_ADDED|peer_id=peer_123,endpoint=203.0.113.1:51820
```

## Configuration

### Checkpoint Configuration

Located at `$CHECKPOINT_DIR/config/checkpoint.conf`:

```ini
[Checkpoint]
Name = checkpoint-name
BaseDir = /var/lib/wireguard/checkpoints/checkpoint-name
BasePublicKey = base64-encoded-public-key

[Policies]
# Key allocation policies
# Interface allocation policies
# Routing policies
```

### Template Syntax

Templates use a simple text-based syntax:

- `[name]` - Checkpoint definition
- `<->` - Bidirectional connection
- `->` - Unidirectional connection
- `,` - Multiple connections

Examples:
```
[client]<->[server]
[hub]<->[spoke1],[hub]<->[spoke2]
[web]<->[app]<->[db]
```

## Security

### Key Management

- Private keys stored with 600 permissions
- Public keys stored with 644 permissions
- Revoked keys moved to separate directory
- Key rotation maintains audit trail

### Authorization

- Accessor registration required before allocation
- Authorization check before key allocation
- Policy enforcement for all operations
- Complete audit logs for compliance

### Network Security

- WireGuard provides authenticated encryption
- Cryptokey routing ensures traffic isolation
- Chain of trust limits automatic configuration
- Discovery queries respect policy boundaries

### Best Practices

1. **Use time-based expiry** for all keys with appropriate durations
2. **Implement failure-based policies** for automated revocation
3. **Regular key rotation** for long-lived connections
4. **Monitor audit logs** for suspicious activity
5. **Limit chain of trust depth** to prevent over-extension
6. **Use private tunnels** for sensitive communications
7. **Scan for expired keys** regularly with auto-rotation

## Directory Structure

```
/var/lib/wireguard/
├── checkpoints/
│   └── checkpoint-name/
│       ├── metadata.json
│       ├── keys/
│       │   ├── base.private
│       │   ├── base.public
│       │   ├── key_123.private
│       │   ├── key_123.public
│       │   ├── key_123.meta
│       │   ├── key_123.policy
│       │   └── revoked/
│       ├── interfaces/
│       ├── config/
│       │   └── checkpoint.conf
│       ├── logs/
│       │   └── allocations.log
│       └── discovery/
│           ├── queries/
│           ├── responses/
│           └── notifications/
├── tunnels/
│   └── tunnel-name/
│       ├── metadata.json
│       ├── peers/
│       │   └── checkpoint-name/
│       ├── config/
│       └── logs/
│           └── tunnel.log

/etc/wireguard/
├── templates/
│   └── template-name.json
└── accessors/
    ├── user/
    ├── process/
    ├── container/
    ├── vm/
    └── checkpoint/
```

## Contributing

This WireGuard Checkpoint Abstraction is part of ZshTools. Contributions are welcome!

### Development Guidelines

1. Follow existing Zsh function naming conventions (`@wireguard:module:function`)
2. Include documentation blocks (`:<<-"DOCS.*"`)
3. Provide usage examples (`:<<-"EXAMPLE.*"`)
4. Maintain consistent error handling (return 0 for success, 1 for failure)
5. Log all significant operations
6. Preserve audit trails

## License

Part of ZshTools project.

## Author

Developed as part of the WireGuard Checkpoint Abstraction specification.

## Version

1.0.0 (2025-11-08)
