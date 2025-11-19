#!/bin/bash

# Network Utilities Module for MongoDB Replica Set Setup
# Provides network-related operations, primarily IPv4 detection

# Source the pasdt-devops-script for colored messages
source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

# Detect primary non-loopback IPv4 address
# Returns:
#   Primary IPv4 address or "localhost" as fallback
get_primary_ipv4() {
    # Get all IP addresses using hostname -I
    local all_ips=$(hostname -I 2>/dev/null)
    
    # Check if hostname -I returned any addresses
    if [[ -z "$all_ips" ]]; then
        echo "localhost"
        return 0
    fi
    
    # Convert space-separated IPs to array
    local ip_array=($all_ips)
    
    # Filter out loopback (127.x.x.x) and link-local (169.254.x.x) addresses
    for ip in "${ip_array[@]}"; do
        # Skip if it's a loopback address (127.x.x.x)
        if [[ "$ip" =~ ^127\. ]]; then
            continue
        fi
        
        # Skip if it's a link-local address (169.254.x.x)
        if [[ "$ip" =~ ^169\.254\. ]]; then
            continue
        fi
        
        # Skip if it's an IPv6 address (contains colons)
        if [[ "$ip" =~ : ]]; then
            continue
        fi
        
        # Return the first valid IPv4 address found
        echo "$ip"
        return 0
    done
    
    # If no valid address found, return localhost as fallback
    echo "localhost"
    return 0
}
