#!/bin/bash

# Validation Module for MongoDB Replica Set Setup
# Provides input validation functions for configuration parameters

# Source the pasdt-devops-script for colored messages
source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

# Validate if value is a positive integer within specified range
# Arguments:
#   $1 - value to validate
#   $2 - minimum value (inclusive)
#   $3 - maximum value (inclusive)
#   $4 - parameter name (for error messages)
# Returns:
#   0 if valid, 1 if invalid
validate_integer() {
    local value="$1"
    local min="$2"
    local max="$3"
    local param_name="$4"
    
    # Check if value is empty
    if [[ -z "$value" ]]; then
        show_colored_message error "Error: ${param_name} cannot be empty"
        return 1
    fi
    
    # Check if value is a valid integer
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        show_colored_message error "Error: ${param_name} must be a positive integer"
        return 1
    fi
    
    # Check if value is within range
    if [[ "$value" -lt "$min" ]] || [[ "$value" -gt "$max" ]]; then
        show_colored_message error "Error: ${param_name} must be between ${min} and ${max}"
        return 1
    fi
    
    return 0
}

# Validate IPv4 address format
# Arguments:
#   $1 - IPv4 address to validate
# Returns:
#   0 if valid, 1 if invalid
validate_ipv4() {
    local ip="$1"
    
    # Check if value is empty
    if [[ -z "$ip" ]]; then
        show_colored_message error "Error: IP address cannot be empty"
        return 1
    fi
    
    # IPv4 regex pattern: matches xxx.xxx.xxx.xxx where xxx is 0-255
    local ipv4_pattern='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    # Check basic format
    if ! [[ "$ip" =~ $ipv4_pattern ]]; then
        show_colored_message error "Error: Invalid IPv4 address format. Expected format: xxx.xxx.xxx.xxx"
        return 1
    fi
    
    # Validate each octet is between 0-255
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ "$octet" -lt 0 ]] || [[ "$octet" -gt 255 ]]; then
            show_colored_message error "Error: Invalid IPv4 address. Each octet must be between 0 and 255"
            return 1
        fi
    done
    
    return 0
}

# Validate port number is between 1024-65535
# Arguments:
#   $1 - port number to validate
# Returns:
#   0 if valid, 1 if invalid
validate_port() {
    local port="$1"
    
    # Use validate_integer for basic validation
    if ! validate_integer "$port" 1024 65535 "Port number"; then
        return 1
    fi
    
    return 0
}

# Validate file path - verify directory exists and is writable
# Arguments:
#   $1 - file path to validate
# Returns:
#   0 if valid, 1 if invalid
validate_path() {
    local filepath="$1"
    
    # Check if value is empty
    if [[ -z "$filepath" ]]; then
        show_colored_message error "Error: File path cannot be empty"
        return 1
    fi
    
    # Get the directory path
    local dirpath=$(dirname "$filepath")
    
    # Check if directory exists
    if [[ ! -d "$dirpath" ]]; then
        show_colored_message error "Error: Directory does not exist: ${dirpath}"
        return 1
    fi
    
    # Check if directory is writable
    if [[ ! -w "$dirpath" ]]; then
        show_colored_message error "Error: Directory is not writable: ${dirpath}"
        return 1
    fi
    
    return 0
}

# Validate replica count is between 1-50
# Arguments:
#   $1 - replica count to validate
# Returns:
#   0 if valid, 1 if invalid
validate_replica_count() {
    local count="$1"
    
    # Use validate_integer for validation
    if ! validate_integer "$count" 1 50 "Replica count"; then
        return 1
    fi
    
    return 0
}
