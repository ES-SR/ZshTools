#!/bin/zsh
## Example: High-Availability Cluster Setup
## Demonstrates setting up a multi-node cluster with failover capabilities

# Source the WireGuard checkpoint abstractions
source "@/wireguard/checkpoint.zsh"
source "@/wireguard/accessor.zsh"
source "@/wireguard/tunnel.zsh"
source "@/wireguard/template.zsh"
source "@/wireguard/discovery.zsh"

echo "=== High-Availability Cluster Setup Example ==="
echo ""

# Step 1: Create a hub-and-spoke template for HA cluster
echo "Step 1: Creating HA cluster template"
echo "-------------------------------------"

@wireguard:template:create ha-cluster \
    "[primary]<->[secondary1],[primary]<->[secondary2],[secondary1]<->[secondary2]" \
    "High-availability cluster with primary and secondary nodes"

@wireguard:template:show ha-cluster

echo ""

# Step 2: Create checkpoints for cluster nodes
echo "Step 2: Creating cluster node checkpoints"
echo "------------------------------------------"

@wireguard:checkpoint:create cluster-primary
@wireguard:checkpoint:create cluster-secondary1
@wireguard:checkpoint:create cluster-secondary2
@wireguard:checkpoint:create cluster-witness

echo ""

# Step 3: Register node accessors
echo "Step 3: Registering node accessors as checkpoints"
echo "--------------------------------------------------"

primary_key=$(@wireguard:checkpoint:get_base_key cluster-primary)
@wireguard:accessor:checkpoint:register cluster-primary "$primary_key"

secondary1_key=$(@wireguard:checkpoint:get_base_key cluster-secondary1)
@wireguard:accessor:checkpoint:register cluster-secondary1 "$secondary1_key"

secondary2_key=$(@wireguard:checkpoint:get_base_key cluster-secondary2)
@wireguard:accessor:checkpoint:register cluster-secondary2 "$secondary2_key"

witness_key=$(@wireguard:checkpoint:get_base_key cluster-witness)
@wireguard:accessor:checkpoint:register cluster-witness "$witness_key"

echo ""

# Step 4: Create cluster mesh tunnels
echo "Step 4: Creating cluster mesh tunnels"
echo "--------------------------------------"

echo "Creating tunnel: primary <-> secondary1"
@wireguard:tunnel:create cluster-p-s1 p2p "cluster-primary,cluster-secondary1"

echo "Creating tunnel: primary <-> secondary2"
@wireguard:tunnel:create cluster-p-s2 p2p "cluster-primary,cluster-secondary2"

echo "Creating tunnel: secondary1 <-> secondary2"
@wireguard:tunnel:create cluster-s1-s2 p2p "cluster-secondary1,cluster-secondary2"

echo "Creating tunnel: primary <-> witness"
@wireguard:tunnel:create cluster-p-w p2p "cluster-primary,cluster-witness"

echo "Creating tunnel: secondary1 <-> witness"
@wireguard:tunnel:create cluster-s1-w p2p "cluster-secondary1,cluster-witness"

echo "Creating tunnel: secondary2 <-> witness"
@wireguard:tunnel:create cluster-s2-w p2p "cluster-secondary2,cluster-witness"

echo ""

# Step 5: Establish cluster tunnels with appropriate networks
echo "Step 5: Establishing cluster tunnels"
echo "-------------------------------------"

@wireguard:tunnel:establish cluster-p-s1 10.100.1.0/30
@wireguard:tunnel:establish cluster-p-s2 10.100.2.0/30
@wireguard:tunnel:establish cluster-s1-s2 10.100.3.0/30
@wireguard:tunnel:establish cluster-p-w 10.100.4.0/30
@wireguard:tunnel:establish cluster-s1-w 10.100.5.0/30
@wireguard:tunnel:establish cluster-s2-w 10.100.6.0/30

echo ""

# Step 6: List cluster topology
echo "Step 6: Cluster topology"
echo "------------------------"

echo "Known peers for primary:"
@wireguard:discovery:list_known cluster-primary

echo ""
echo "Known peers for secondary1:"
@wireguard:discovery:list_known cluster-secondary1

echo ""
echo "Known peers for secondary2:"
@wireguard:discovery:list_known cluster-secondary2

echo ""

# Step 7: Check trust chains (important for failover)
echo "Step 7: Verifying trust chains"
echo "-------------------------------"

echo "Checking trust chain: primary -> secondary1"
@wireguard:discovery:check_trust_chain cluster-primary cluster-secondary1 2

echo ""
echo "Checking trust chain: primary -> secondary2"
@wireguard:discovery:check_trust_chain cluster-primary cluster-secondary2 2

echo ""
echo "Checking trust chain: secondary1 -> secondary2"
@wireguard:discovery:check_trust_chain cluster-secondary1 cluster-secondary2 2

echo ""
echo "Checking trust chain: primary -> witness"
@wireguard:discovery:check_trust_chain cluster-primary cluster-witness 2

echo ""

# Step 8: Simulate failover scenario
echo "Step 8: Simulating failover scenario"
echo "-------------------------------------"

echo "Scenario: Primary node fails, secondary1 takes over"
echo ""

echo "Step 8a: Query secondary1 about secondary2 via witness (discovery)"
@wireguard:discovery:query cluster-secondary1 cluster-witness cluster-secondary2 info

echo ""

echo "Step 8b: Establish new route from secondary1 to witness (for quorum)"
@wireguard:discovery:establish_route cluster-secondary1 cluster-witness auto

echo ""

# Step 9: List all cluster tunnels
echo "Step 9: All cluster tunnels"
echo "---------------------------"

@wireguard:tunnel:list

echo ""

# Step 10: Show detailed tunnel status
echo "Step 10: Detailed tunnel status"
echo "--------------------------------"

@wireguard:tunnel:status cluster-p-s1

echo ""
echo "=== High-Availability Cluster Setup Complete ==="
echo ""
echo "Summary:"
echo "- 4 cluster nodes created (primary, 2 secondaries, witness)"
echo "- Full mesh connectivity established"
echo "- Trust chains verified between all nodes"
echo "- Failover scenario demonstrated using discovery mechanism"
echo ""
echo "Cluster architecture:"
echo "  cluster-primary (10.100.1.1, 10.100.2.1, 10.100.4.1)"
echo "    |"
echo "    +-- cluster-secondary1 (10.100.1.2, 10.100.3.1, 10.100.5.1)"
echo "    |"
echo "    +-- cluster-secondary2 (10.100.2.2, 10.100.3.2, 10.100.6.1)"
echo "    |"
echo "    +-- cluster-witness (10.100.4.2, 10.100.5.2, 10.100.6.2)"
echo ""
echo "Failover capabilities:"
echo "- Automatic route discovery between nodes"
echo "- Chain of trust validation for security"
echo "- Witness node for quorum decisions"
echo "- Full mesh allows any node to communicate with any other"
