#!/bin/bash

# MongoDB Replica Set Setup - Bootstrap Module
# This script can be executed directly from GitHub or locally
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/[user]/[repo]/[branch]/initiate.sh)

# ============================================================================
# Configuration Variables
# ============================================================================

# GitHub repository configuration
GITHUB_REPO_BASE_URL="https://raw.githubusercontent.com/subrata-pasdt/scripts/main"
GITHUB_SCRIPTS_BASE_URL="${GITHUB_REPO_BASE_URL}/app/mongo-setup/scripts"

# Maximum retry attempts for GitHub downloads
MAX_RETRY_ATTEMPTS=3

# Required scripts to source from GitHub
REQUIRED_SCRIPTS=(
    "check-dependencies.sh"
    "config-manager.sh"
    "file-generator.sh"
    "network-utils.sh"
    "validators.sh"
)

# ============================================================================
# Source pasdt-devops-script for colored messages
# ============================================================================

source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

# ============================================================================
# Helper Functions
# ============================================================================

# Download and source a script from GitHub with retry logic
# Arguments:
#   $1 - script name (e.g., "check-dependencies.sh")
#   $2 - base URL (optional, defaults to GITHUB_SCRIPTS_BASE_URL)
# Returns:
#   0 if successful, 1 if failed after all retries
source_from_github() {
    local script_name="$1"
    local base_url="${2:-$GITHUB_SCRIPTS_BASE_URL}"
    local script_url="${base_url}/${script_name}"
    local attempt=1
    
    while [[ $attempt -le $MAX_RETRY_ATTEMPTS ]]; do
        show_colored_message info "Downloading ${script_name} (attempt ${attempt}/${MAX_RETRY_ATTEMPTS})..."
        
        # Try to download and source the script
        if source <(curl -fsSL "$script_url") 2>/dev/null; then
            show_colored_message success "Successfully sourced ${script_name}"
            return 0
        fi
        
        show_colored_message warning "Failed to download ${script_name}, retrying..."
        attempt=$((attempt + 1))
        sleep 2
    done
    
    show_colored_message error "Failed to download ${script_name} after ${MAX_RETRY_ATTEMPTS} attempts"
    return 1
}

# Validate that all required scripts are accessible from GitHub
# Returns:
#   0 if all scripts are accessible, 1 if any are missing
validate_github_access() {
    show_colored_message info "Validating GitHub access to required scripts..."
    echo ""
    
    local all_accessible=true
    
    for script in "${REQUIRED_SCRIPTS[@]}"; do
        local script_url="${GITHUB_SCRIPTS_BASE_URL}/${script}"
        
        show_colored_message info "Checking ${script}..."
        
        # Use curl to check if the script is accessible (HTTP 200)
        if curl -fsSL --head "$script_url" &>/dev/null; then
            show_colored_message success "${script} is accessible"
        else
            show_colored_message error "${script} is not accessible at ${script_url}"
            all_accessible=false
        fi
    done
    
    echo ""
    
    if [[ "$all_accessible" == true ]]; then
        show_colored_message success "All required scripts are accessible from GitHub"
        return 0
    else
        show_colored_message error "Some required scripts are not accessible from GitHub"
        show_colored_message info "Please check your internet connection and verify the repository URL"
        return 1
    fi
}

# Create directory structure under app/mongo-setup
# Returns:
#   0 if successful, 1 if failed
setup_workspace() {
    show_colored_message info "Setting up workspace directory structure..."
    echo ""
    
    # Define directories to create
    local directories=(
        "app/mongo-setup"
        "app/mongo-setup/scripts"
        "app/mongo-setup/secrets"
        "app/mongo-setup/data"
        "app/mongo-setup/logs"
    )
    
    # Create each directory
    for dir in "${directories[@]}"; do
        if [[ -d "$dir" ]]; then
            show_colored_message info "Directory already exists: ${dir}"
        else
            if mkdir -p "$dir" 2>/dev/null; then
                show_colored_message success "Created directory: ${dir}"
            else
                show_colored_message error "Failed to create directory: ${dir}"
                return 1
            fi
        fi
    done
    
    echo ""
    show_colored_message success "Workspace setup complete"
    return 0
}

# Orchestrate the complete setup workflow
# Workflow: dependency check → config manager → file generator → create containers → initialize replica set → create users
# Returns:
#   0 if successful, 1 if any step fails
orchestrate_setup() {
    show_colored_message info "Starting MongoDB Replica Set setup orchestration..."
    echo ""
    
    # Step 1: Check dependencies
    show_colored_message info "Step 1: Checking system dependencies..."
    echo ""
    
    if ! check_all_dependencies; then
        show_colored_message error "Dependency check failed. Please install missing dependencies and try again."
        return 1
    fi
    
    echo ""
    show_colored_message success "Step 1 complete: All dependencies are satisfied"
    echo ""
    
    # Step 2: Gather configuration
    show_colored_message info "Step 2: Gathering configuration..."
    echo ""
    
    if ! gather_configuration ".env"; then
        show_colored_message error "Configuration gathering failed. Please check your inputs and try again."
        return 1
    fi
    
    echo ""
    show_colored_message success "Step 2 complete: Configuration gathered"
    echo ""
    
    # Step 3: Generate files
    show_colored_message info "Step 3: Generating configuration files..."
    echo ""
    
    # Generate .env file
    if ! generate_env_file \
        "$CONFIG_REPLICA_COUNT" \
        "$CONFIG_REPLICA_HOST_IP" \
        "$CONFIG_STARTING_PORT" \
        "$CONFIG_USERS_JSON_PATH" \
        "$CONFIG_KEYFILE_PATH" \
        "$CONFIG_MONGO_INITDB_ROOT_USERNAME" \
        "$CONFIG_MONGO_INITDB_ROOT_PASSWORD" \
        ".env"; then
        show_colored_message error "Failed to generate .env file. Please check file permissions and try again."
        return 1
    fi
    
    # Generate keyfile
    if ! generate_keyfile "$CONFIG_KEYFILE_PATH"; then
        show_colored_message error "Failed to generate keyfile. Please check file permissions and try again."
        return 1
    fi
    
    # Generate users.json template
    if ! generate_users_json_template "$CONFIG_USERS_JSON_PATH"; then
        show_colored_message error "Failed to generate users.json template. Please check file permissions and try again."
        return 1
    fi
    
    echo ""
    show_colored_message success "Step 3 complete: All configuration files generated"
    echo ""
    
    # Step 4: Create containers
    show_colored_message info "Step 4: Creating MongoDB containers..."
    echo ""
    
    if ! bash scripts/create-container.sh; then
        show_colored_message error "Failed to create MongoDB containers. Please check Docker status and try again."
        return 1
    fi
    
    echo ""
    show_colored_message success "Step 4 complete: MongoDB containers created and started"
    echo ""
    
    # Step 5: Initialize replica set
    show_colored_message info "Step 5: Initializing MongoDB replica set..."
    echo ""
    
    # Get the first container name from docker-compose.yaml
    FIRST_CONTAINER=$(grep "container_name" docker-compose.yaml | head -1 | cut -d ":" -f2 | tr -d ' ')
    
    if [ -z "$FIRST_CONTAINER" ]; then
        show_colored_message error "Failed to detect container name from docker-compose.yaml"
        return 1
    fi
    
    show_colored_message info "Using container: $FIRST_CONTAINER for replica set initialization"
    
    if ! bash scripts/initiate-replicate.sh "$FIRST_CONTAINER"; then
        show_colored_message error "Failed to initialize replica set. Please check MongoDB logs and try again."
        return 1
    fi
    
    echo ""
    show_colored_message success "Step 5 complete: Replica set initialized"
    echo ""
    
    # Step 6: Create users
    show_colored_message info "Step 6: Creating MongoDB users from users.json..."
    echo ""
    
    if ! bash scripts/user-management.sh "$FIRST_CONTAINER"; then
        show_colored_message error "Failed to create users. Please check users.json format and MongoDB status."
        return 1
    fi
    
    echo ""
    show_colored_message success "Step 6 complete: Users created successfully"
    echo ""
    
    # Display final success message with next steps
    echo "============================================================================"
    show_colored_message success "MongoDB Replica Set Setup Complete!"
    echo "============================================================================"
    echo ""
    show_colored_message info "Your MongoDB replica set is now running with the following configuration:"
    echo "  - Replica Count: ${CONFIG_REPLICA_COUNT}"
    echo "  - Host IP: ${CONFIG_REPLICA_HOST_IP}"
    echo "  - Starting Port: ${CONFIG_STARTING_PORT}"
    echo ""
    show_colored_message info "Root Credentials (stored in .env):"
    echo "  - Username: ${CONFIG_MONGO_INITDB_ROOT_USERNAME}"
    echo "  - Password: ${CONFIG_MONGO_INITDB_ROOT_PASSWORD}"
    echo ""
    show_colored_message info "Connection String:"
    echo "  mongodb://${CONFIG_MONGO_INITDB_ROOT_USERNAME}:${CONFIG_MONGO_INITDB_ROOT_PASSWORD}@${CONFIG_REPLICA_HOST_IP}:${CONFIG_STARTING_PORT}/?replicaSet=rs0"
    echo ""
    show_colored_message info "Next Steps:"
    echo "  1. Review and update user passwords in ${CONFIG_USERS_JSON_PATH}"
    echo "  2. Connect to your MongoDB replica set using the connection string above"
    echo "  3. Use 'bash scripts/show-url.sh' to display connection URLs"
    echo "  4. Use 'bash scripts/connect-to-db.sh' to connect via mongosh"
    echo ""
    show_colored_message info "Management Commands:"
    echo "  - View logs: docker compose logs -f"
    echo "  - Stop containers: docker compose down"
    echo "  - Restart containers: docker compose restart"
    echo "  - Reset everything: bash scripts/reset-all.sh"
    echo ""
    
    return 0
}

# ============================================================================
# Main Execution
# ============================================================================

# Display header
show_header "MongoDB Replica Set Setup" "Dynamic Configuration System" "2024" "2.0"

# Check if running in GitHub-sourced mode or local mode
if [[ -d "scripts" ]] && [[ -f "scripts/check-dependencies.sh" ]]; then
    # Local mode - scripts are available locally
    show_colored_message info "Running in local mode - using local scripts"
    echo ""
    
    # Make scripts executable
    for i in scripts/*.sh; do
        if [[ -f "$i" ]] && [[ ! -x "$i" ]]; then
            show_colored_message info "Adding executable permission to $i"
            chmod +x "$i"
        fi
    done
    
    # Source local scripts
    source scripts/check-dependencies.sh
    source scripts/validators.sh
    source scripts/network-utils.sh
    source scripts/config-manager.sh
    source scripts/file-generator.sh
    
    echo ""
else
    # GitHub mode - download scripts from GitHub
    show_colored_message info "Running in GitHub mode - downloading scripts from repository"
    echo ""
    
    # Validate GitHub access
    if ! validate_github_access; then
        show_colored_message error "Cannot proceed without access to required scripts"
        exit 1
    fi
    
    echo ""
    
    # Source required scripts from GitHub
    show_colored_message info "Downloading and sourcing required scripts..."
    echo ""
    
    for script in "${REQUIRED_SCRIPTS[@]}"; do
        if ! source_from_github "$script"; then
            show_colored_message error "Failed to source ${script}"
            show_colored_message error "Cannot proceed without all required scripts"
            exit 1
        fi
    done
    
    echo ""
    show_colored_message success "All scripts sourced successfully"
    echo ""
    
    # Setup workspace
    if ! setup_workspace; then
        show_colored_message error "Failed to setup workspace"
        exit 1
    fi
    
    echo ""
fi

# Display menu options
options=("Automated Setup" "Create Container" "Initialize Replicaset" "Create Users" "Connect to DB" "Reset Everything" "Show URL" "Exit")

echo ""
show_colored_message info "Please select an option:"
echo ""

select opt in "${options[@]}"; do
  case $REPLY in
    1)
      show_colored_message info "Starting automated setup..."
      echo ""
      if orchestrate_setup; then
          show_colored_message success "Automated setup completed successfully!"
      else
          show_colored_message error "Automated setup failed"
          exit 1
      fi
      break
      ;;
    2)
      show_colored_message info "Creating Container"
      bash scripts/create-container.sh
      break
      ;;
    3)
      show_colored_message info "Initializing Replicaset"
      bash scripts/initiate-replicate.sh
      break
      ;;
    4)
      show_colored_message info "Creating Users and Roles"
      bash scripts/user-management.sh
      ;;
    5)
      show_colored_message info "Connecting to DB"
      bash scripts/connect-to-db.sh
      break
      ;;
    6)
      show_colored_message error "Everything will be removed !"
      if confirm "Remove Everything"; then
        bash scripts/reset-all.sh
      else
        show_colored_message info "Operation canceled."
      fi
      break
      ;;
    7)
      show_colored_message info "Generating URL"
      bash scripts/show-url.sh
      ;;
    8)
       show_colored_message success "Thank You ! Bye."
      exit 0;
      ;;
    *)
      show_colored_message error "Invalid option. Try again."
      ;;
  esac
done
