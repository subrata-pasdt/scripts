#!/bin/bash

# RabbitMQ Setup Automation Script
# Automates RabbitMQ container deployment, configuration, and user management

set -euo pipefail

# Global variables
RABBITMQ_API="http://127.0.0.1:15672/api"
ENV_FILE=".env"

# ============================================================================
# DEPENDENCY CHECKER MODULE
# ============================================================================

# Helper function to check if a command exists
check_command() {
    local cmd=$1
    if command -v "$cmd" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if Docker daemon is running
check_docker_running() {
    if ! docker info &> /dev/null; then
        return 1
    fi
    return 0
}

# Main dependency verification function
check_dependencies() {
    echo "➡ Checking system dependencies..."
    echo ""
    
    local missing_deps=()
    local all_ok=true
    
    # Check Docker
    if ! check_command docker; then
        echo "❌ Docker is not installed"
        echo "   Install Docker: https://docs.docker.com/get-docker/"
        missing_deps+=("docker")
        all_ok=false
    else
        echo "✅ Docker is installed"
        
        # Check if Docker daemon is running
        if ! check_docker_running; then
            echo "❌ Docker daemon is not running"
            echo "   Start Docker: sudo systemctl start docker (Linux) or start Docker Desktop (Mac/Windows)"
            all_ok=false
        else
            echo "✅ Docker daemon is running"
        fi
    fi
    
    # Check Docker Compose
    if ! check_command docker-compose && ! docker compose version &> /dev/null; then
        echo "❌ Docker Compose is not installed"
        echo "   Install Docker Compose: https://docs.docker.com/compose/install/"
        missing_deps+=("docker-compose")
        all_ok=false
    else
        echo "✅ Docker Compose is installed"
    fi
    
    # Check jq
    if ! check_command jq; then
        echo "❌ jq is not installed"
        echo "   Install jq: sudo apt-get install jq (Ubuntu/Debian) or brew install jq (Mac)"
        missing_deps+=("jq")
        all_ok=false
    else
        echo "✅ jq is installed"
    fi
    
    # Check curl
    if ! check_command curl; then
        echo "❌ curl is not installed"
        echo "   Install curl: sudo apt-get install curl (Ubuntu/Debian) or brew install curl (Mac)"
        missing_deps+=("curl")
        all_ok=false
    else
        echo "✅ curl is installed"
    fi
    
    echo ""
    
    # Exit if any dependencies are missing
    if [ "$all_ok" = false ]; then
        echo "❌ Missing required dependencies. Please install the missing tools and try again."
        exit 1
    fi
    
    echo "✅ All dependencies are satisfied"
    echo ""
}

# ============================================================================
# ENVIRONMENT MANAGER MODULE
# ============================================================================

# Generate a secure random password using /dev/urandom
generate_password() {
    local length=16
    # Generate 16-character alphanumeric password
    # Use || true to prevent pipefail from causing issues when head closes the pipe
    tr -dc 'A-Za-z0-9' < /dev/urandom 2>/dev/null | head -c "$length" || true
}

# Prompt user for a value with a descriptive message
prompt_for_value() {
    local prompt_message=$1
    local value
    
    read -p "$prompt_message: " value
    echo "$value"
}

# Validate that the .env file contains all required variables
validate_env_file() {
    local env_file=$1
    local missing_vars=()
    
    # Check for required variables
    if ! grep -q "^RABBITMQ_DEFAULT_USER=" "$env_file" 2>/dev/null; then
        missing_vars+=("RABBITMQ_DEFAULT_USER")
    fi
    
    if ! grep -q "^RABBITMQ_DEFAULT_PASSWORD=" "$env_file" 2>/dev/null; then
        missing_vars+=("RABBITMQ_DEFAULT_PASSWORD")
    fi
    
    # Return the list of missing variables
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "${missing_vars[@]}"
        return 1
    fi
    
    return 0
}

# Update or add a variable in the .env file
update_env_file() {
    local env_file=$1
    local var_name=$2
    local var_value=$3
    
    # Check if variable already exists
    if grep -q "^${var_name}=" "$env_file" 2>/dev/null; then
        # Update existing variable (works on both Linux and macOS)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^${var_name}=.*|${var_name}=${var_value}|" "$env_file"
        else
            sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" "$env_file"
        fi
    else
        # Add new variable
        echo "${var_name}=${var_value}" >> "$env_file"
    fi
}

# Main environment setup function
setup_environment() {
    echo "➡ Setting up environment configuration..."
    echo ""
    
    # Check if .env file exists
    if [ ! -f "$ENV_FILE" ]; then
        echo "➡ .env file not found. Creating new environment configuration..."
        echo ""
        
        # Prompt for username
        local username
        username=$(prompt_for_value "Enter RabbitMQ admin username")
        
        # Generate password
        echo "➡ Generating secure password..."
        local password
        password=$(generate_password)
        
        # Create .env file
        echo "RABBITMQ_DEFAULT_USER=${username}" > "$ENV_FILE"
        echo "RABBITMQ_DEFAULT_PASSWORD=${password}" >> "$ENV_FILE"
        
        # Set secure permissions (read/write for owner only)
        chmod 600 "$ENV_FILE"
        
        echo ""
        echo "✅ Environment file created at $ENV_FILE"
        echo "✅ Admin username: $username"
        echo "✅ Admin password: $password"
        echo ""
        echo "⚠️  Please save these credentials securely!"
        echo ""
    else
        echo "➡ Loading existing environment configuration from $ENV_FILE..."
        echo ""
        
        # Validate existing .env file
        local missing_vars
        if ! missing_vars=$(validate_env_file "$ENV_FILE"); then
            echo "⚠️  Missing required variables in .env file: $missing_vars"
            echo "➡ Prompting for missing values..."
            echo ""
            
            # Prompt for missing variables
            for var in $missing_vars; do
                if [ "$var" = "RABBITMQ_DEFAULT_USER" ]; then
                    local username
                    username=$(prompt_for_value "Enter RabbitMQ admin username")
                    update_env_file "$ENV_FILE" "RABBITMQ_DEFAULT_USER" "$username"
                elif [ "$var" = "RABBITMQ_DEFAULT_PASSWORD" ]; then
                    echo "➡ Generating secure password..."
                    local password
                    password=$(generate_password)
                    update_env_file "$ENV_FILE" "RABBITMQ_DEFAULT_PASSWORD" "$password"
                    echo "✅ Generated password: $password"
                fi
            done
            
            # Set secure permissions
            chmod 600 "$ENV_FILE"
            
            echo ""
            echo "✅ Environment file updated"
            echo ""
        else
            echo "✅ Environment configuration loaded successfully"
            echo ""
        fi
        
        # Ensure proper permissions
        chmod 600 "$ENV_FILE"
    fi
    
    # Load environment variables
    set -a
    source "$ENV_FILE"
    set +a
    
    echo "✅ Environment ready"
    echo ""
}

# ============================================================================
# INTERACTIVE MENU MODULE
# ============================================================================

# Display menu options to the user
show_menu() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                      MAIN MENU                                ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Please select an option:"
    echo ""
    echo "  1) Start RabbitMQ Container"
    echo "  2) Create Users and Assign Permissions"
    echo "  3) Exit"
    echo ""
}

# Process user menu selection
handle_menu_selection() {
    local selection=$1
    
    case $selection in
        1)
            echo ""
            echo "➡ Starting RabbitMQ Container..."
            echo ""
            start_container
            return 0
            ;;
        2)
            echo ""
            echo "➡ Creating Users and Assigning Permissions..."
            echo ""
            setup_users
            return 0
            ;;
        3)
            echo ""
            echo "➡ Exiting RabbitMQ Setup Automation..."
            echo "✅ Goodbye!"
            echo ""
            exit 0
            ;;
        *)
            echo ""
            echo "❌ Invalid selection: '$selection'"
            echo "   Please enter 1, 2, or 3"
            return 1
            ;;
    esac
}

# Main menu loop - continues until valid selection or exit
run_menu() {
    local selection
    local valid_selection=false
    
    while [ "$valid_selection" = false ]; do
        show_menu
        read -p "Enter your choice [1-3]: " selection
        
        if handle_menu_selection "$selection"; then
            valid_selection=true
        fi
    done
}

# ============================================================================
# CONTAINER MANAGER MODULE
# ============================================================================

# Generate docker-compose.yml file with environment variable substitution
create_docker_compose() {
    local compose_file="docker-compose.yml"
    
    echo "➡ Creating docker-compose.yml..."
    
    cat > "$compose_file" << 'EOF'
services:
  rabbitmq:
    image: rabbitmq:3.8-management
    container_name: rabbitmq
    restart: always
    ports:
      - "0.0.0.0:5672:5672"
      - "0.0.0.0:15672:15672"
    environment:
      - RABBITMQ_DEFAULT_USER=${RABBITMQ_DEFAULT_USER}
      - RABBITMQ_DEFAULT_PASS=${RABBITMQ_DEFAULT_PASSWORD}
    volumes:
      - ./rabbitmq:/var/lib/rabbitmq

volumes:
  rabbitmq:
EOF
    
    echo "✅ docker-compose.yml created"
}

# Check if the RabbitMQ container is running
check_container_status() {
    if docker ps --filter "name=rabbitmq" --filter "status=running" --format "{{.Names}}" | grep -q "^rabbitmq$"; then
        return 0
    else
        return 1
    fi
}

# Wait for RabbitMQ Management API to become available
wait_for_rabbitmq() {
    local timeout=60
    local interval=2
    local elapsed=0
    
    echo "➡ Waiting for RabbitMQ Management API to become available..."
    echo "   (timeout: ${timeout}s, checking every ${interval}s)"
    echo ""
    
    while [ $elapsed -lt $timeout ]; do
        # Try to connect to the Management API overview endpoint
        if curl -s -u "$RABBITMQ_DEFAULT_USER:$RABBITMQ_DEFAULT_PASSWORD" \
            "http://127.0.0.1:15672/api/overview" > /dev/null 2>&1; then
            echo ""
            echo "✅ RabbitMQ Management API is ready!"
            return 0
        fi
        
        # Show progress
        echo -n "."
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo ""
    echo ""
    echo "❌ Timeout waiting for RabbitMQ Management API"
    echo "   The API did not respond within ${timeout} seconds"
    echo "   Please check container logs: docker logs rabbitmq"
    return 1
}

# Main function to start the RabbitMQ container
start_container() {
    echo "➡ Starting RabbitMQ container setup..."
    echo ""
    
    # Check if container is already running
    if check_container_status; then
        echo "⚠️  RabbitMQ container is already running"
        echo ""
        read -p "Do you want to restart it? (y/n): " restart_choice
        
        if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
            echo ""
            echo "➡ Stopping existing container..."
            docker-compose down
            echo "✅ Container stopped"
            echo ""
        else
            echo ""
            echo "➡ Using existing container"
            echo ""
            return 0
        fi
    fi
    
    # Create docker-compose.yml
    create_docker_compose
    echo ""
    
    # Start the container
    echo "➡ Starting RabbitMQ container with docker-compose..."
    echo ""
    
    if docker-compose up -d; then
        echo ""
        echo "✅ Container started successfully"
        echo ""
    else
        echo ""
        echo "❌ Failed to start container"
        echo "   Check docker-compose logs for details: docker-compose logs"
        exit 1
    fi
    
    # Wait for RabbitMQ to be ready
    if ! wait_for_rabbitmq; then
        exit 1
    fi
    
    echo ""
    
    # Install delayed message exchange plugin
    if ! install_delayed_plugin; then
        echo "⚠️  Warning: Plugin installation failed, but container is running"
        echo "   You can try installing the plugin manually later"
        echo ""
    fi
    
    echo "✅ RabbitMQ container is ready!"
    echo ""
    echo "📊 Management UI: http://localhost:15672"
    echo "🔌 AMQP Port: 5672"
    echo "👤 Username: $RABBITMQ_DEFAULT_USER"
    echo "🔑 Password: $RABBITMQ_DEFAULT_PASSWORD"
    echo ""
}

# ============================================================================
# PLUGIN INSTALLER MODULE
# ============================================================================

# Download the rabbitmq_delayed_message_exchange plugin from GitHub
download_plugin() {
    local plugin_url="https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/3.8.17/rabbitmq_delayed_message_exchange-3.8.17.8f537ac.ez"
    local plugin_file="rabbitmq_delayed_message_exchange-3.8.17.8f537ac.ez"
    
    echo "➡ Downloading delayed message exchange plugin..."
    
    # Download with curl, checking exit code
    if ! curl -L -f -o "$plugin_file" "$plugin_url" 2>&1; then
        echo "❌ Failed to download plugin from $plugin_url"
        echo "   Please check your internet connection and try again"
        return 1
    fi
    
    # Verify file was downloaded and has content
    if [ ! -f "$plugin_file" ]; then
        echo "❌ Plugin file not found after download"
        return 1
    fi
    
    if [ ! -s "$plugin_file" ]; then
        echo "❌ Plugin file is empty"
        rm -f "$plugin_file"
        return 1
    fi
    
    echo "✅ Plugin downloaded: $plugin_file ($(stat -c%s "$plugin_file" 2>/dev/null || stat -f%z "$plugin_file" 2>/dev/null) bytes)"
    return 0
}

# Copy the plugin file into the RabbitMQ container
copy_plugin_to_container() {
    local plugin_file="rabbitmq_delayed_message_exchange-3.8.17.8f537ac.ez"
    local container_name="rabbitmq"
    local container_path="/opt/rabbitmq/plugins/"
    
    echo "➡ Copying plugin to container..."
    
    # Check if container is running
    if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo "❌ Container '$container_name' is not running"
        echo "   Please ensure the container is running: docker ps"
        return 1
    fi
    
    # Copy the plugin file
    if ! docker cp "$plugin_file" "$container_name:$container_path" 2>/dev/null; then
        echo "❌ Failed to copy plugin to container"
        return 1
    fi
    
    echo "✅ Plugin copied to container"
    return 0
}

# Enable the plugin using rabbitmq-plugins command
enable_plugin() {
    local container_name="rabbitmq"
    local plugin_name="rabbitmq_delayed_message_exchange"
    
    echo "➡ Enabling plugin in RabbitMQ..."
    
    # Enable the plugin and capture output
    local output
    if ! output=$(docker exec "$container_name" rabbitmq-plugins enable "$plugin_name" 2>&1); then
        echo "❌ Failed to enable plugin"
        echo "   Error: $output"
        return 1
    fi
    
    echo "✅ Plugin enabled"
    return 0
}

# Verify the plugin is active via rabbitmq-plugins command
verify_plugin() {
    local plugin_name="rabbitmq_delayed_message_exchange"
    local container_name="rabbitmq"
    
    echo "➡ Verifying plugin status..."
    
    # Use rabbitmq-plugins list to check if plugin is enabled
    local plugin_list
    if ! plugin_list=$(docker exec "$container_name" rabbitmq-plugins list 2>&1); then
        echo "❌ Failed to retrieve plugin list"
        return 1
    fi
    
    # Check if the plugin is in the list and is enabled (marked with [E*])
    if echo "$plugin_list" | grep -q "\[E.\?] $plugin_name"; then
        echo "✅ Plugin verified: $plugin_name is enabled"
        return 0
    else
        echo "❌ Plugin verification failed: $plugin_name is not enabled"
        echo "   Plugin list output:"
        echo "$plugin_list" | grep "$plugin_name" || echo "   Plugin not found in list"
        return 1
    fi
}

# Main function to orchestrate plugin installation
install_delayed_plugin() {
    local plugin_file="rabbitmq_delayed_message_exchange-3.8.17.8f537ac.ez"
    
    echo ""
    echo "➡ Installing delayed message exchange plugin..."
    echo ""
    
    # Download the plugin
    if ! download_plugin; then
        echo ""
        echo "❌ Plugin installation failed at download stage"
        echo "   You can manually install the plugin later"
        return 1
    fi
    
    echo ""
    
    # Copy plugin to container
    if ! copy_plugin_to_container; then
        echo ""
        echo "❌ Plugin installation failed at copy stage"
        # Clean up downloaded file
        rm -f "$plugin_file"
        return 1
    fi
    
    echo ""
    
    # Enable the plugin
    if ! enable_plugin; then
        echo ""
        echo "❌ Plugin installation failed at enable stage"
        # Clean up downloaded file
        rm -f "$plugin_file"
        return 1
    fi
    
    echo ""
    
    # Verify the plugin is active
    if ! verify_plugin; then
        echo ""
        echo "❌ Plugin installation failed at verification stage"
        # Clean up downloaded file
        rm -f "$plugin_file"
        return 1
    fi
    
    # Clean up downloaded file
    rm -f "$plugin_file"
    
    echo ""
    echo "✅ Delayed message exchange plugin installed successfully!"
    echo ""
    
    return 0
}

# ============================================================================
# API CLIENT MODULE
# ============================================================================

# Generic API call wrapper with HTTP status code checking
api_call() {
    local method=$1
    local endpoint=$2
    local data=${3:-}
    
    # Make the API call and capture both response body and HTTP status code
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -u "$RABBITMQ_DEFAULT_USER:$RABBITMQ_DEFAULT_PASSWORD" \
        -X "$method" \
        -H "content-type: application/json" \
        ${data:+-d "$data"} \
        "$RABBITMQ_API/$endpoint" 2>&1)
    
    # Extract HTTP status code (last line) and body (everything else)
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')
    
    # Check if HTTP status code indicates success (2xx)
    if [[ $http_code -ge 200 && $http_code -lt 300 ]]; then
        echo "$body"
        return 0
    else
        echo "❌ API Error: HTTP $http_code - $body" >&2
        return 1
    fi
}

# Create a new RabbitMQ user
create_user() {
    local username=$1
    local password=$2
    local tags=$3
    
    local data
    data=$(jq -n \
        --arg password "$password" \
        --arg tags "$tags" \
        '{password: $password, tags: $tags}')
    
    if api_call "PUT" "users/$username" "$data" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Delete a RabbitMQ user
delete_user() {
    local username=$1
    
    if api_call "DELETE" "users/$username" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check if a user exists
user_exists() {
    local username=$1
    
    if api_call "GET" "users/$username" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Create a new vhost
create_vhost() {
    local vhost=$1
    
    if api_call "PUT" "vhosts/$vhost" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if a vhost exists
vhost_exists() {
    local vhost=$1
    
    if api_call "GET" "vhosts/$vhost" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Set permissions for a user on a vhost
set_permissions() {
    local vhost=$1
    local username=$2
    
    local data
    data=$(jq -n \
        '{configure: ".*", write: ".*", read: ".*"}')
    
    if api_call "PUT" "permissions/$vhost/$username" "$data" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Get list of plugins (kept for potential future use)
get_plugins() {
    # Note: The /api/plugins endpoint is not available in RabbitMQ 3.8
    # Use rabbitmq-plugins list command instead (see verify_plugin function)
    echo "❌ API endpoint /api/plugins not available in RabbitMQ 3.8"
    return 1
}

# ============================================================================
# CONFIG PARSER MODULE
# ============================================================================

# Validate JSON structure and verify required arrays and fields exist
validate_json_structure() {
    local config_file=$1
    
    echo "➡ Validating JSON structure..."
    
    # Check if file exists
    if [ ! -f "$config_file" ]; then
        echo "❌ Config file not found: $config_file"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "$config_file" 2>/dev/null; then
        echo "❌ Invalid JSON syntax in config file"
        echo "   Please check the file for syntax errors"
        return 1
    fi
    
    # Check for required arrays
    if ! jq -e '.users' "$config_file" >/dev/null 2>&1; then
        echo "❌ Missing required field: 'users' array"
        return 1
    fi
    
    if ! jq -e '.vhosts' "$config_file" >/dev/null 2>&1; then
        echo "❌ Missing required field: 'vhosts' array"
        return 1
    fi
    
    if ! jq -e '.permissions' "$config_file" >/dev/null 2>&1; then
        echo "❌ Missing required field: 'permissions' array"
        return 1
    fi
    
    # Validate users array structure - check all at once
    local invalid_users
    invalid_users=$(jq -r '.users | to_entries[] | select(.value | has("name") and has("password") and has("tags") | not) | .key' "$config_file" 2>/dev/null)
    
    if [ -n "$invalid_users" ]; then
        echo "❌ Users at indices $invalid_users are missing required fields (name, password, tags)"
        return 1
    fi
    
    # Validate permissions array structure - check all at once
    local invalid_permissions
    invalid_permissions=$(jq -r '.permissions | to_entries[] | select(.value | has("user") and has("hosts") | not) | .key' "$config_file" 2>/dev/null)
    
    if [ -n "$invalid_permissions" ]; then
        echo "❌ Permissions at indices $invalid_permissions are missing required fields (user, hosts)"
        return 1
    fi
    
    echo "✅ JSON structure is valid"
    return 0
}

# Extract users array from config file
extract_users() {
    local config_file=$1
    
    # Extract users array as JSON
    local users
    users=$(jq -c '.users[]' "$config_file" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to extract users from config file" >&2
        return 1
    fi
    
    echo "$users"
    return 0
}

# Extract vhosts array from config file
extract_vhosts() {
    local config_file=$1
    
    # Extract vhosts array as JSON array of strings
    local vhosts
    vhosts=$(jq -r '.vhosts[]' "$config_file" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to extract vhosts from config file" >&2
        return 1
    fi
    
    echo "$vhosts"
    return 0
}

# Extract permissions array from config file
extract_permissions() {
    local config_file=$1
    
    # Extract permissions array as JSON
    local permissions
    permissions=$(jq -c '.permissions[]' "$config_file" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to extract permissions from config file" >&2
        return 1
    fi
    
    echo "$permissions"
    return 0
}

# Main config parsing function - orchestrates validation and extraction
parse_config() {
    local config_file=$1
    
    echo "➡ Parsing configuration file: $config_file"
    echo ""
    
    # Validate JSON structure
    if ! validate_json_structure "$config_file"; then
        echo ""
        echo "❌ Configuration validation failed"
        echo "   Please fix the errors in your config file and try again"
        return 1
    fi
    
    echo ""
    echo "✅ Configuration file parsed successfully"
    echo ""
    
    return 0
}

# ============================================================================
# USER MANAGER MODULE
# ============================================================================

# Prompt user for config file path
prompt_for_config_file() {
    local config_path
    
    read -p "Config file path: " config_path
    
    echo "$config_path"
}

# Process users from config - delete existing and create new
process_users() {
    local config_file=$1
    
    echo "➡ Processing users..."
    echo ""
    
    local users
    if ! users=$(extract_users "$config_file"); then
        echo "❌ Failed to extract users from config"
        return 1
    fi
    
    # Process each user
    while IFS= read -r user_json; do
        local username
        local password
        local tags
        
        username=$(echo "$user_json" | jq -r '.name')
        password=$(echo "$user_json" | jq -r '.password')
        tags=$(echo "$user_json" | jq -r '.tags')
        
        echo "➡ Processing user: $username"
        
        # Check if user exists and delete if so
        if user_exists "$username"; then
            echo "  ➡ User exists, deleting..."
            if delete_user "$username"; then
                echo "  ✅ Existing user deleted"
            else
                echo "  ❌ Failed to delete existing user"
                continue
            fi
        fi
        
        # Create the user
        echo "  ➡ Creating user..."
        if create_user "$username" "$password" "$tags"; then
            echo "  ✅ User created: $username (tags: $tags)"
        else
            echo "  ❌ Failed to create user: $username"
        fi
        
        echo ""
    done <<< "$users"
    
    echo "✅ User processing complete"
    echo ""
}

# Process vhosts from config
process_vhosts() {
    local config_file=$1
    
    echo "➡ Processing vhosts..."
    echo ""
    
    local vhosts
    if ! vhosts=$(extract_vhosts "$config_file"); then
        echo "❌ Failed to extract vhosts from config"
        return 1
    fi
    
    # Process each vhost
    while IFS= read -r vhost; do
        [ -z "$vhost" ] && continue
        
        echo "🏠 Processing vhost: $vhost"
        
        # Check if vhost exists
        if vhost_exists "$vhost"; then
            echo "  ➡ Vhost already exists, skipping creation"
        else
            # Create the vhost
            echo "  ➡ Creating vhost..."
            if create_vhost "$vhost"; then
                echo "  ✅ Vhost created: $vhost"
            else
                echo "  ❌ Failed to create vhost: $vhost"
            fi
        fi
        
        echo ""
    done <<< "$vhosts"
    
    echo "✅ Vhost processing complete"
    echo ""
}

# Process permissions from config
process_permissions() {
    local config_file=$1
    
    echo "➡ Processing permissions..."
    echo ""
    
    local permissions
    if ! permissions=$(extract_permissions "$config_file"); then
        echo "❌ Failed to extract permissions from config"
        return 1
    fi
    
    # Process each permission entry
    while IFS= read -r perm_json; do
        local username
        local hosts
        
        username=$(echo "$perm_json" | jq -r '.user')
        hosts=$(echo "$perm_json" | jq -r '.hosts[]')
        
        # Check if user exists
        if ! user_exists "$username"; then
            echo "❌ User does not exist: $username"
            echo "   Skipping permissions for this user"
            echo ""
            continue
        fi
        
        # Process each host for this user
        while IFS= read -r vhost; do
            [ -z "$vhost" ] && continue
            
            echo "🔑 Setting permissions for user '$username' on vhost '$vhost'"
            
            if set_permissions "$vhost" "$username"; then
                echo "  ✅ Permissions set: $username @ $vhost (configure: .*, write: .*, read: .*)"
            else
                echo "  ❌ Failed to set permissions: $username @ $vhost"
            fi
            
            echo ""
        done <<< "$hosts"
        
    done <<< "$permissions"
    
    echo "✅ Permission processing complete"
    echo ""
}

# Main user setup function - orchestrates config file prompt, parsing, and processing
setup_users() {
    echo "➡ Starting user and permission setup..."
    echo ""
    
    # Prompt for config file
    local config_file
    config_file=$(prompt_for_config_file)
    
    echo ""
    
    # Check if file exists
    if [ ! -f "$config_file" ]; then
        echo "❌ Config file not found: $config_file"
        echo "   Please ensure the file exists and try again"
        return 1
    fi
    
    echo "✅ Config file found: $config_file"
    echo ""
    
    # Parse and validate config
    if ! parse_config "$config_file"; then
        return 1
    fi
    
    # Process users
    if ! process_users "$config_file"; then
        echo "❌ User processing failed"
        return 1
    fi
    
    # Process vhosts
    if ! process_vhosts "$config_file"; then
        echo "❌ Vhost processing failed"
        return 1
    fi
    
    # Process permissions
    if ! process_permissions "$config_file"; then
        echo "❌ Permission processing failed"
        return 1
    fi
    
    echo "✅ User and permission setup complete!"
    echo ""
    echo "📊 You can verify the configuration in the Management UI:"
    echo "   http://localhost:15672"
    echo ""
    
    return 0
}

# ============================================================================
# BANNER MODULE
# ============================================================================

# Display ASCII art banner with project information
show_banner() {
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ██████╗  █████╗ ██████╗ ██████╗ ██╗████████╗███╗   ███╗ ██████╗  ║
║   ██╔══██╗██╔══██╗██╔══██╗██╔══██╗██║╚══██╔══╝████╗ ████║██╔═══██╗ ║
║   ██████╔╝███████║██████╔╝██████╔╝██║   ██║   ██╔████╔██║██║   ██║ ║
║   ██╔══██╗██╔══██║██╔══██╗██╔══██╗██║   ██║   ██║╚██╔╝██║██║▄▄ ██║ ║
║   ██║  ██║██║  ██║██████╔╝██████╔╝██║   ██║   ██║ ╚═╝ ██║╚██████╔╝ ║
║   ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝     ╚═╝ ╚══▀▀═╝  ║
║                                                               ║
║              Setup Automation Tool v1.0                       ║
║         Automated Container Deployment & Configuration        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF
}

# Main function - orchestrates the overall flow
main() {
    # Display welcome banner
    show_banner
    
    echo "➡ Starting RabbitMQ Setup Automation..."
    echo ""
    
    # Check dependencies
    check_dependencies
    
    # Setup environment
    setup_environment
    
    # Display interactive menu
    run_menu
    
    echo ""
    echo "✅ Operation complete!"
    echo ""
}

# Execute main function
main "$@"
