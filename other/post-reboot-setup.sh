#!/bin/bash

# --- CONFIGURATION ---
LOG_FILE="/var/log/post_reboot.log"
USER_TO_NOTIFY="antiamoah890"

sleep 60

# --- LOGGING FUNCTION ---
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# --- STAGE 1: Wait for Docker Daemon ---
log "Waiting for Docker daemon to be alive..."
until docker info >/dev/null 2>&1; do
    log "Docker daemon not ready yet. Sleeping 2s..."
    sleep 2
done

# --- STAGE 2: Wait for All Containers to be Ready ---
log "Checking container health..."

# This loop waits until there are NO containers in a 'starting' or 'unhealthy' state
# It also ensures at least one container is actually running.
while true; do
    # Get count of containers that are NOT 'healthy' (if they have healthchecks)
    # or NOT 'running' (if they don't)
    UNREADY=$(docker ps -a --format '{{.Status}}' | grep -v "Up" | grep -v "(healthy)" | wc -l)
    
    if [ "$UNREADY" -eq 0 ]; then
        log "All containers are verified ready/healthy."
        break
    else
        log "Waiting for $UNREADY container(s) to finish starting..."
        sleep 5
    fi
done


# --- STAGE 3: Your Logic Here ---
log "Executing post-container tasks..."


docker exec openvswitch_vswitchd ovs-ofctl add-flow br-ex "cookie=0x013,priority=1000,in_port=vlan20,actions=mod_vlan_vid:20,output:phy-br-ex"
docker exec openvswitch_vswitchd ovs-ofctl add-flow br-ex "cookie=0x014,priority=10000,in_port=phy-br-ex,actions=strip_vlan,output:vlan20"
docker exec -u  root -it neutron_openvswitch_agent ovs-vsctl set Port vlan20 trunks=20

log "Post-reboot tasks completed successfully."
