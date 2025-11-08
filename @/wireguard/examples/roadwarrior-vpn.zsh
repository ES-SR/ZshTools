#!/bin/zsh
## Example: Road Warrior VPN Setup
## Demonstrates setting up a VPN server and multiple clients

# Source the WireGuard checkpoint abstractions
source "@/wireguard/checkpoint.zsh"
source "@/wireguard/accessor.zsh"
source "@/wireguard/tunnel.zsh"
source "@/wireguard/template.zsh"
source "@/wireguard/keymanagement.zsh"

echo "=== Road Warrior VPN Setup Example ==="
echo ""

# Step 1: Create a template for road warrior VPN
echo "Step 1: Creating VPN template"
echo "------------------------------"

@wireguard:template:create roadwarrior \
    "[server]<->[client]" \
    "Road warrior VPN: server and client setup"

echo ""

# Step 2: Create VPN server checkpoint
echo "Step 2: Creating VPN server checkpoint"
echo "---------------------------------------"

@wireguard:checkpoint:create vpn-server

# Get server's base public key
server_pubkey=$(@wireguard:checkpoint:get_base_key vpn-server)
echo "Server public key: $server_pubkey"

echo ""

# Step 3: Register user accessors (clients)
echo "Step 3: Registering client accessors"
echo "-------------------------------------"

@wireguard:accessor:user:register alice 1001
@wireguard:accessor:user:register bob 1002
@wireguard:accessor:user:register charlie 1003

echo ""

# Step 4: Allocate keys to clients with time-based expiry
echo "Step 4: Allocating keys to clients"
echo "-----------------------------------"

alice_key=$(@wireguard:checkpoint:allocate vpn-server user:alice "VPN Access" yes)
echo "Alice's key: $alice_key"

# Set 30-day expiry policy for Alice
@wireguard:key:set_policy vpn-server "$alice_key" time 30d

bob_key=$(@wireguard:checkpoint:allocate vpn-server user:bob "VPN Access" yes)
echo "Bob's key: $bob_key"

# Set 30-day expiry policy for Bob
@wireguard:key:set_policy vpn-server "$bob_key" time 30d

charlie_key=$(@wireguard:checkpoint:allocate vpn-server user:charlie "VPN Access" yes)
echo "Charlie's key: $charlie_key"

# Set 7-day expiry policy for Charlie (temporary access)
@wireguard:key:set_policy vpn-server "$charlie_key" time 7d

echo ""

# Step 5: Create client checkpoints
echo "Step 5: Creating client checkpoints"
echo "------------------------------------"

@wireguard:checkpoint:create client-alice
@wireguard:checkpoint:create client-bob
@wireguard:checkpoint:create client-charlie

echo ""

# Step 6: Create tunnels between server and clients
echo "Step 6: Creating tunnels"
echo "------------------------"

@wireguard:tunnel:create tunnel-alice p2p "vpn-server,client-alice"
@wireguard:tunnel:create tunnel-bob p2p "vpn-server,client-bob"
@wireguard:tunnel:create tunnel-charlie p2p "vpn-server,client-charlie"

echo ""

# Step 7: Establish tunnels
echo "Step 7: Establishing tunnels"
echo "----------------------------"

@wireguard:tunnel:establish tunnel-alice 10.200.0.0/24
@wireguard:tunnel:establish tunnel-bob 10.200.1.0/24
@wireguard:tunnel:establish tunnel-charlie 10.200.2.0/24

echo ""

# Step 8: List all allocations
echo "Step 8: Server allocations"
echo "--------------------------"

@wireguard:checkpoint:list vpn-server

echo ""

# Step 9: List all tunnels
echo "Step 9: Active tunnels"
echo "----------------------"

@wireguard:tunnel:list

echo ""

# Step 10: Demonstrate key rotation
echo "Step 10: Rotating Bob's key"
echo "---------------------------"

new_bob_key=$(@wireguard:key:rotate vpn-server "$bob_key" user:bob "VPN Access")
echo "Bob's new key: $new_bob_key"

echo ""

# Step 11: Scan for expired keys
echo "Step 11: Scanning for expired keys"
echo "-----------------------------------"

@wireguard:key:scan_expired vpn-server

echo ""
echo "=== Road Warrior VPN Setup Complete ==="
echo ""
echo "Summary:"
echo "- VPN server checkpoint created"
echo "- 3 client accessors registered (alice, bob, charlie)"
echo "- 3 client checkpoints created"
echo "- 3 tunnels established"
echo "- Key policies set (30d for alice/bob, 7d for charlie)"
echo "- Bob's key rotated successfully"
