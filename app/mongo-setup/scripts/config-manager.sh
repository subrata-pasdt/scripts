#!/bin/bash

# Configuration Manager Module for MongoDB Replica Set Setup
# Handles interactive configuration gathering and existing config management

# Source the pasdt-devops-script for colored messages
source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

# Get the script directory to source other modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required modules
source "${SCRIPT_DIR}/network-utils.sh"
source "${SCRIPT_DIR}/validators.sh"

# Detect primary IPv4 address using network utilities
# Returns:
#   Primary IPv4 address
detect_ipv4() {
    get_primary_ipv4
}

# Generic prompt function with default value support
# Arguments:
#   $1 - prompt message
#   $2 - default value
#   $3 - variable name to store result
prompt_with_default() {
    local prompt_msg="$1"
    local default_value="$2"
    local result_var="$3"
    
    # Display prompt with default value
    show_colored_message question "${prompt_msg} [${default_value}]: "
    
    # Read user input
    read -r user_input
    
    # Use default if user pressed Enter without input
    if [[ -z "$user_input" ]]; then
        eval "$result_var='$default_value'"
    else
        eval "$result_var='$user_input'"
    fi
}

# Load configuration values from existing .env file
# Arguments:
#   $1 - path to .env file
# Returns:
#   0 if successful, 1 if file doesn't exist
# Side Effects:
#   Sets global variables with loaded values
load_existing_config() {
    local env_file="$1"
    
    if [[ ! -f "$env_file" ]]; then
        return 1
    fi
    
    show_colored_message info "Loading existing configuration from ${env_file}..."
    
    # Read .env file and export variables
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        if [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]]; then
            continue
        fi
        
        # Remove leading/trailing whitespace and quotes
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        
        # Export the variable
        case "$key" in
            REPLICA_COUNT)
                EXISTING_REPLICA_COUNT="$value"
                ;;
            REPLICA_HOST_IP)
                EXISTING_REPLICA_HOST_IP="$value"
                ;;
            STARTING_PORT)
                EXISTING_STARTING_PORT="$value"
                ;;
            USERS_JSON_PATH)
                EXISTING_USERS_JSON_PATH="$value"
                ;;
            KEYFILE_PATH)
                EXISTING_KEYFILE_PATH="$value"
                ;;
            MONGO_INITDB_ROOT_USERNAME)
                EXISTING_MONGO_INITDB_ROOT_USERNAME="$value"
                ;;
            MONGO_INITDB_ROOT_PASSWORD)
                EXISTING_MONGO_INITDB_ROOT_PASSWORD="$value"
                ;;
        esac
    done < "$env_file"
    
    show_colored_message success "Configuration loaded successfully"
    return 0
}

# Ask user if they want to use existing config or reconfigure
# Returns:
#   0 if user wants to reconfigure, 1 if user wants to use existing config
prompt_reconfigure() {
    show_colored_message question "Existing configuration found. Do you want to:"
    echo "  1) Use existing configuration"
    echo "  2) Reconfigure (existing .env will be backed up)"
    
    while true; do
        show_colored_message question "Enter your choice [1/2]: "
        read -r choice
        
        case "$choice" in
            1)
                show_colored_message info "Using existing configuration"
                return 1
                ;;
            2)
                show_colored_message info "Reconfiguring..."
                return 0
                ;;
            *)
                show_colored_message error "Invalid choice. Please enter 1 or 2"
                ;;
        esac
    done
}

# Create timestamped backup of .env file
# Arguments:
#   $1 - path to .env file
backup_config() {
    local env_file="$1"
    
    if [[ ! -f "$env_file" ]]; then
        show_colored_message warning "No existing .env file to backup"
        return 0
    fi
    
    # Create backup with timestamp
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${env_file}.backup_${timestamp}"
    
    cp "$env_file" "$backup_file"
    
    if [[ $? -eq 0 ]]; then
        show_colored_message success "Backup created: ${backup_file}"
        return 0
    else
        show_colored_message error "Failed to create backup"
        return 1
    fi
}

# Main interactive configuration workflow
# Arguments:
#   $1 - path to .env file (default: .env)
# Side Effects:
#   Sets global configuration variables
gather_configuration() {
    local env_file="${1:-.env}"
    
    show_colored_message info "Starting configuration gathering..."
    echo ""
    
    # Check if .env file exists
    if [[ -f "$env_file" ]]; then
        load_existing_config "$env_file"
        
        if prompt_reconfigure; then
            # User wants to reconfigure
            backup_config "$env_file"
        else
            # User wants to use existing config
            CONFIG_REPLICA_COUNT="$EXISTING_REPLICA_COUNT"
            CONFIG_REPLICA_HOST_IP="$EXISTING_REPLICA_HOST_IP"
            CONFIG_STARTING_PORT="$EXISTING_STARTING_PORT"
            CONFIG_USERS_JSON_PATH="$EXISTING_USERS_JSON_PATH"
            CONFIG_KEYFILE_PATH="$EXISTING_KEYFILE_PATH"
            CONFIG_MONGO_INITDB_ROOT_USERNAME="$EXISTING_MONGO_INITDB_ROOT_USERNAME"
            CONFIG_MONGO_INITDB_ROOT_PASSWORD="$EXISTING_MONGO_INITDB_ROOT_PASSWORD"
            
            show_colored_message success "Configuration loaded from existing .env file"
            return 0
        fi
    fi
    
    # Interactive configuration gathering
    show_colored_message info "Please provide the following configuration parameters:"
    echo ""
    
    # Prompt for REPLICA_COUNT
    while true; do
        local default_replica_count="${EXISTING_REPLICA_COUNT:-3}"
        prompt_with_default "Number of replica set members" "$default_replica_count" "CONFIG_REPLICA_COUNT"
        
        if validate_replica_count "$CONFIG_REPLICA_COUNT"; then
            break
        fi
    done
    
    # Prompt for REPLICA_HOST_IP
    while true; do
        local detected_ip=$(detect_ipv4)
        local default_host_ip="${EXISTING_REPLICA_HOST_IP:-$detected_ip}"
        prompt_with_default "Replica set host IP address" "$default_host_ip" "CONFIG_REPLICA_HOST_IP"
        
        if validate_ipv4 "$CONFIG_REPLICA_HOST_IP"; then
            break
        fi
    done
    
    # Prompt for STARTING_PORT
    while true; do
        local default_port="${EXISTING_STARTING_PORT:-27017}"
        prompt_with_default "Starting port number" "$default_port" "CONFIG_STARTING_PORT"
        
        if validate_port "$CONFIG_STARTING_PORT"; then
            break
        fi
    done
    
    # Prompt for USERS_JSON_PATH
    while true; do
        local default_users_path="${EXISTING_USERS_JSON_PATH:-./configs/users.json}"
        prompt_with_default "Path to users.json file" "$default_users_path" "CONFIG_USERS_JSON_PATH"
        
        if validate_path "$CONFIG_USERS_JSON_PATH"; then
            break
        fi
    done
    
    # Prompt for KEYFILE_PATH
    while true; do
        local default_keyfile_path="${EXISTING_KEYFILE_PATH:-./secrets/mongodb-keyfile}"
        prompt_with_default "Path to MongoDB keyfile" "$default_keyfile_path" "CONFIG_KEYFILE_PATH"
        
        if validate_path "$CONFIG_KEYFILE_PATH"; then
            break
        fi
    done
    
    # Auto-generate root credentials if not in existing config
    if [[ -z "$EXISTING_MONGO_INITDB_ROOT_USERNAME" ]]; then
        CONFIG_MONGO_INITDB_ROOT_USERNAME="admin_$(openssl rand -hex 4)"
        show_colored_message info "Generated root username: ${CONFIG_MONGO_INITDB_ROOT_USERNAME}"
    else
        CONFIG_MONGO_INITDB_ROOT_USERNAME="$EXISTING_MONGO_INITDB_ROOT_USERNAME"
        show_colored_message info "Using existing root username: ${CONFIG_MONGO_INITDB_ROOT_USERNAME}"
    fi
    
    if [[ -z "$EXISTING_MONGO_INITDB_ROOT_PASSWORD" ]]; then
        CONFIG_MONGO_INITDB_ROOT_PASSWORD="$(openssl rand -hex 16)"
        show_colored_message info "Generated root password: ${CONFIG_MONGO_INITDB_ROOT_PASSWORD}"
    else
        CONFIG_MONGO_INITDB_ROOT_PASSWORD="$EXISTING_MONGO_INITDB_ROOT_PASSWORD"
        show_colored_message info "Using existing root password"
    fi
    
    echo ""
    show_colored_message success "Configuration gathering complete!"
    echo ""
    show_colored_message info "Configuration summary:"
    echo "  Replica Count: ${CONFIG_REPLICA_COUNT}"
    echo "  Host IP: ${CONFIG_REPLICA_HOST_IP}"
    echo "  Starting Port: ${CONFIG_STARTING_PORT}"
    echo "  Users JSON Path: ${CONFIG_USERS_JSON_PATH}"
    echo "  Keyfile Path: ${CONFIG_KEYFILE_PATH}"
    echo "  Root Username: ${CONFIG_MONGO_INITDB_ROOT_USERNAME}"
    echo "  Root Password: ${CONFIG_MONGO_INITDB_ROOT_PASSWORD}"
    echo ""
    
    return 0
}

