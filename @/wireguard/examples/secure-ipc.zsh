#!/bin/zsh
## Example: Secure IPC (Inter-Process Communication)
## Demonstrates using WireGuard tunnels for secure process communication

# Source the WireGuard checkpoint abstractions
source "@/wireguard/checkpoint.zsh"
source "@/wireguard/accessor.zsh"
source "@/wireguard/tunnel.zsh"
source "@/wireguard/keymanagement.zsh"

echo "=== Secure IPC Example ==="
echo ""

# Step 1: Create a checkpoint for the host system
echo "Step 1: Creating host checkpoint"
echo "---------------------------------"

@wireguard:checkpoint:create ipc-host

echo ""

# Step 2: Register process accessors
echo "Step 2: Registering process accessors"
echo "--------------------------------------"

# In a real scenario, these would be actual PIDs
# For this example, we'll use placeholder PIDs

@wireguard:accessor:process:register 12345 "webserver" "www-data"
@wireguard:accessor:process:register 23456 "database" "postgres"
@wireguard:accessor:process:register 34567 "cache" "redis"
@wireguard:accessor:process:register 45678 "worker" "www-data"

echo ""

# Step 3: Allocate keys to processes with usage-based policies
echo "Step 3: Allocating keys to processes"
echo "-------------------------------------"

# Web server - high usage limit (10GB)
web_key=$(@wireguard:checkpoint:allocate ipc-host process:12345 "Web Server IPC" yes)
echo "Web server key: $web_key"
@wireguard:key:set_policy ipc-host "$web_key" usage 10737418240

# Database - medium usage limit (5GB)
db_key=$(@wireguard:checkpoint:allocate ipc-host process:23456 "Database IPC" yes)
echo "Database key: $db_key"
@wireguard:key:set_policy ipc-host "$db_key" usage 5368709120

# Cache - high usage limit (10GB)
cache_key=$(@wireguard:checkpoint:allocate ipc-host process:34567 "Cache IPC" yes)
echo "Cache key: $cache_key"
@wireguard:key:set_policy ipc-host "$cache_key" usage 10737418240

# Worker - low usage limit (1GB), failure-based policy
worker_key=$(@wireguard:checkpoint:allocate ipc-host process:45678 "Worker IPC" yes)
echo "Worker key: $worker_key"
@wireguard:key:set_policy ipc-host "$worker_key" usage 1073741824
@wireguard:key:set_policy ipc-host "$worker_key" failure 5

echo ""

# Step 4: Create private tunnels for sensitive communication
echo "Step 4: Creating private IPC tunnels"
echo "-------------------------------------"

# Create checkpoints for each process (in a real scenario, these would be
# created in separate network namespaces)
@wireguard:checkpoint:create process-web
@wireguard:checkpoint:create process-db
@wireguard:checkpoint:create process-cache
@wireguard:checkpoint:create process-worker

echo ""

# Create private tunnels
echo "Creating private tunnel: web <-> database"
@wireguard:tunnel:create ipc-web-db private "process-web,process-db"
@wireguard:tunnel:establish ipc-web-db 172.16.1.0/30

echo ""
echo "Creating private tunnel: web <-> cache"
@wireguard:tunnel:create ipc-web-cache private "process-web,process-cache"
@wireguard:tunnel:establish ipc-web-cache 172.16.2.0/30

echo ""
echo "Creating private tunnel: worker <-> database"
@wireguard:tunnel:create ipc-worker-db private "process-worker,process-db"
@wireguard:tunnel:establish ipc-worker-db 172.16.3.0/30

echo ""

# Step 5: Simulate usage and check policies
echo "Step 5: Simulating usage"
echo "------------------------"

echo "Simulating web server data transfer (100MB)..."
@wireguard:key:update_usage ipc-host "$web_key" 104857600

echo "Simulating database data transfer (50MB)..."
@wireguard:key:update_usage ipc-host "$db_key" 52428800

echo "Checking key validity..."
@wireguard:key:check_expiry ipc-host "$web_key"
@wireguard:key:check_expiry ipc-host "$db_key"

echo ""

# Step 6: Simulate connection failures for worker
echo "Step 6: Simulating worker connection failures"
echo "----------------------------------------------"

for i in {1..3}; do
    echo "Recording failure #$i for worker..."
    @wireguard:key:record_failure ipc-host "$worker_key"
done

echo "Checking worker key validity..."
@wireguard:key:check_expiry ipc-host "$worker_key"

echo ""

# Step 7: List all process allocations
echo "Step 7: Process allocations"
echo "---------------------------"

@wireguard:checkpoint:list ipc-host

echo ""

# Step 8: List IPC tunnels
echo "Step 8: IPC tunnels"
echo "-------------------"

@wireguard:tunnel:list

echo ""

# Step 9: Show audit trail
echo "Step 9: Audit trail"
echo "-------------------"

echo "Allocation log:"
tail -n 20 /var/lib/wireguard/checkpoints/ipc-host/logs/allocations.log

echo ""
echo "=== Secure IPC Example Complete ==="
echo ""
echo "Summary:"
echo "- Host checkpoint created for IPC coordination"
echo "- 4 process accessors registered"
echo "- 4 process checkpoints created with allocated keys"
echo "- 3 private tunnels established for process communication"
echo "- Usage-based and failure-based policies set"
echo "- Usage tracking and failure recording demonstrated"
echo "- Audit trail maintained for all operations"
echo ""
echo "Benefits:"
echo "- Encryption for all inter-process communication"
echo "- Process-level identity and authentication"
echo "- Automatic key lifecycle management"
echo "- Complete audit trails for compliance"
echo "- Network transparency (processes use normal sockets)"
