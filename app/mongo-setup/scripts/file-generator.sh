#!/bin/bash

# File Generator Module for MongoDB Replica Set Setup
# Creates required configuration files with proper formatting and permissions

# Source the pasdt-devops-script for colored messages
source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

# Create directories if they don't exist
# Arguments:
#   $1 - directory path to create
# Returns:
#   0 if successful, 1 if failed
ensure_directory_exists() {
    local dirpath="$1"
    
    # Check if directory already exists
    if [[ -d "$dirpath" ]]; then
        return 0
    fi
    
    # Create directory with parent directories
    if mkdir -p "$dirpath" 2>/dev/null; then
        show_colored_message success "Created directory: ${dirpath}"
        return 0
    else
        show_colored_message error "Failed to create directory: ${dirpath}"
        return 1
    fi
}

# Generate .env file with all configuration parameters and comments
# Arguments:
#   $1 - REPLICA_COUNT
#   $2 - REPLICA_HOST_IP
#   $3 - STARTING_PORT
#   $4 - USERS_JSON_PATH
#   $5 - KEYFILE_PATH
#   $6 - MONGO_INITDB_ROOT_USERNAME
#   $7 - MONGO_INITDB_ROOT_PASSWORD
#   $8 - output file path (optional, defaults to .env)
# Returns:
#   0 if successful, 1 if failed
generate_env_file() {
    local replica_count="$1"
    local replica_host_ip="$2"
    local starting_port="$3"
    local users_json_path="$4"
    local keyfile_path="$5"
    local root_username="$6"
    local root_password="$7"
    local output_file="${8:-.env}"
    
    # Get current timestamp
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create .env file content
    cat > "$output_file" << EOF
# MongoDB Replica Set Configuration
# Generated on: ${timestamp}

# Root Credentials
# These credentials are used to create the initial root user in MongoDB
MONGO_INITDB_ROOT_USERNAME=${root_username}
MONGO_INITDB_ROOT_PASSWORD=${root_password}

# Replica Set Configuration
# Number of MongoDB replica set members (1-50)
REPLICA_COUNT=${replica_count}

# IP address for replica set communication
# Use the primary IPv4 address of the host machine
REPLICA_HOST_IP=${replica_host_ip}

# Starting port number for MongoDB instances
# Each replica member will use sequential ports (e.g., 27017, 27018, 27019)
STARTING_PORT=${starting_port}

# File Paths
# Path to the users.json file containing user definitions
USERS_JSON_PATH=${users_json_path}

# Path to the MongoDB keyfile for replica set authentication
KEYFILE_PATH=${keyfile_path}
EOF
    
    if [[ $? -eq 0 ]]; then
        show_colored_message success "Generated .env file: ${output_file}"
        return 0
    else
        show_colored_message error "Failed to generate .env file: ${output_file}"
        return 1
    fi
}

# Generate secure MongoDB keyfile with proper permissions
# Arguments:
#   $1 - keyfile path
# Returns:
#   0 if successful, 1 if failed
generate_keyfile() {
    local keyfile_path="$1"
    
    # Check if keyfile already exists
    if [[ -f "$keyfile_path" ]]; then
        show_colored_message info "Keyfile already exists: ${keyfile_path}"
        return 0
    fi
    
    # Ensure parent directory exists
    local keyfile_dir=$(dirname "$keyfile_path")
    if ! ensure_directory_exists "$keyfile_dir"; then
        return 1
    fi
    
    # Generate keyfile using openssl
    if openssl rand -base64 756 > "$keyfile_path" 2>/dev/null; then
        show_colored_message success "Generated keyfile: ${keyfile_path}"
    else
        show_colored_message error "Failed to generate keyfile: ${keyfile_path}"
        return 1
    fi
    
    # Set permissions to 400 (read-only for owner)
    if chmod 400 "$keyfile_path" 2>/dev/null; then
        show_colored_message success "Set keyfile permissions to 400"
    else
        show_colored_message error "Failed to set keyfile permissions"
        return 1
    fi
    
    # Set ownership to 999:999 (MongoDB user in Docker)
    # Note: This may require sudo privileges, so we'll try but not fail if it doesn't work
    if chown 999:999 "$keyfile_path" 2>/dev/null; then
        show_colored_message success "Set keyfile ownership to 999:999"
    else
        show_colored_message warning "Could not set keyfile ownership to 999:999 (may require sudo)"
        show_colored_message info "Docker will handle ownership when mounting the keyfile"
    fi
    
    return 0
}

# Generate example users.json template with admin and app user examples
# Arguments:
#   $1 - users.json file path
# Returns:
#   0 if successful, 1 if failed
generate_users_json_template() {
    local users_json_path="$1"
    
    # Check if users.json already exists
    if [[ -f "$users_json_path" ]]; then
        show_colored_message info "users.json already exists: ${users_json_path}"
        return 0
    fi
    
    # Ensure parent directory exists
    local users_json_dir=$(dirname "$users_json_path")
    if ! ensure_directory_exists "$users_json_dir"; then
        return 1
    fi
    
    # Create users.json template
    cat > "$users_json_path" << 'EOF'
[
  {
    "user": "admin_user",
    "pass": "change_this_password",
    "roles": [
      {
        "role": "root",
        "db": "admin"
      }
    ]
  },
  {
    "user": "app_user",
    "pass": "change_this_password",
    "roles": [
      {
        "role": "readWrite",
        "db": "myapp_db"
      }
    ]
  }
]
EOF
    
    if [[ $? -eq 0 ]]; then
        show_colored_message success "Generated users.json template: ${users_json_path}"
        show_colored_message warning "Please update the passwords in ${users_json_path} before proceeding"
        return 0
    else
        show_colored_message error "Failed to generate users.json template: ${users_json_path}"
        return 1
    fi
}
