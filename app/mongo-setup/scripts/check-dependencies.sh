#!/bin/bash

# Dependency Checker Module for MongoDB Replica Set Setup
# Validates that all required system dependencies are installed

# Source the pasdt-devops-script for colored messages
source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

# Check if a command exists in PATH
# Arguments:
#   $1 - command name to check
# Returns:
#   0 if command exists, 1 if not found
check_command() {
    local cmd="$1"
    
    if command -v "$cmd" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Validate Docker installation and daemon status
# Returns:
#   0 if Docker is installed and running, 1 otherwise
check_docker() {
    show_colored_message info "Checking Docker installation..."
    
    # Check if Docker command exists
    if ! check_command docker; then
        show_colored_message error "Docker is not installed"
        return 1
    fi
    
    # Check Docker version
    local docker_version=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    if [[ -n "$docker_version" ]]; then
        show_colored_message success "Docker ${docker_version} is installed"
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        show_colored_message error "Docker daemon is not running. Please start Docker and try again."
        return 1
    fi
    
    show_colored_message success "Docker daemon is running"
    return 0
}

# Validate Docker Compose installation (v2.x or higher)
# Returns:
#   0 if Docker Compose v2.x+ is installed, 1 otherwise
check_docker_compose() {
    show_colored_message info "Checking Docker Compose installation..."
    
    # Check for docker compose (v2 plugin style)
    if docker compose version &> /dev/null; then
        local compose_version=$(docker compose version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
        
        if [[ -n "$compose_version" ]]; then
            # Extract major version
            local major_version=$(echo "$compose_version" | cut -d. -f1)
            
            if [[ "$major_version" -ge 2 ]]; then
                show_colored_message success "Docker Compose ${compose_version} is installed"
                return 0
            else
                show_colored_message error "Docker Compose version ${compose_version} is too old. Version 2.x or higher is required."
                return 1
            fi
        fi
    fi
    
    # Check for legacy docker-compose command
    if check_command docker-compose; then
        local compose_version=$(docker-compose --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
        
        if [[ -n "$compose_version" ]]; then
            local major_version=$(echo "$compose_version" | cut -d. -f1)
            
            if [[ "$major_version" -ge 2 ]]; then
                show_colored_message success "Docker Compose ${compose_version} is installed"
                return 0
            else
                show_colored_message warning "Docker Compose version ${compose_version} is too old. Version 2.x or higher is required."
                return 1
            fi
        fi
    fi
    
    show_colored_message error "Docker Compose is not installed or version could not be determined"
    return 1
}

# Display OS-specific installation instructions for missing dependencies
# Arguments:
#   $1 - dependency name
display_installation_instructions() {
    local dependency="$1"
    
    show_colored_message info "Installation instructions for ${dependency}:"
    echo ""
    
    case "$dependency" in
        docker)
            echo "Ubuntu/Debian:"
            echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
            echo "  sudo sh get-docker.sh"
            echo "  sudo usermod -aG docker \$USER"
            echo ""
            echo "Fedora/RHEL/CentOS:"
            echo "  sudo dnf install docker-ce docker-ce-cli containerd.io"
            echo "  sudo systemctl start docker"
            echo "  sudo systemctl enable docker"
            echo ""
            echo "macOS:"
            echo "  Download and install Docker Desktop from https://www.docker.com/products/docker-desktop"
            echo ""
            echo "For other systems, visit: https://docs.docker.com/engine/install/"
            ;;
        docker-compose)
            echo "Docker Compose v2 is included with Docker Desktop and recent Docker Engine installations."
            echo ""
            echo "If using Docker Engine on Linux:"
            echo "  sudo apt-get update"
            echo "  sudo apt-get install docker-compose-plugin"
            echo ""
            echo "Or install standalone:"
            echo "  sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
            echo "  sudo chmod +x /usr/local/bin/docker-compose"
            echo ""
            echo "For more information, visit: https://docs.docker.com/compose/install/"
            ;;
        bash)
            echo "Bash should be pre-installed on most Linux/Unix systems."
            echo ""
            echo "Ubuntu/Debian:"
            echo "  sudo apt-get install bash"
            echo ""
            echo "Fedora/RHEL/CentOS:"
            echo "  sudo dnf install bash"
            echo ""
            echo "macOS:"
            echo "  brew install bash"
            ;;
        curl)
            echo "Ubuntu/Debian:"
            echo "  sudo apt-get install curl"
            echo ""
            echo "Fedora/RHEL/CentOS:"
            echo "  sudo dnf install curl"
            echo ""
            echo "macOS:"
            echo "  brew install curl"
            ;;
        wget)
            echo "Ubuntu/Debian:"
            echo "  sudo apt-get install wget"
            echo ""
            echo "Fedora/RHEL/CentOS:"
            echo "  sudo dnf install wget"
            echo ""
            echo "macOS:"
            echo "  brew install wget"
            ;;
        jq)
            echo "Ubuntu/Debian:"
            echo "  sudo apt-get install jq"
            echo ""
            echo "Fedora/RHEL/CentOS:"
            echo "  sudo dnf install jq"
            echo ""
            echo "macOS:"
            echo "  brew install jq"
            echo ""
            echo "For more information, visit: https://stedolan.github.io/jq/download/"
            ;;
        openssl)
            echo "OpenSSL should be pre-installed on most Linux/Unix systems."
            echo ""
            echo "Ubuntu/Debian:"
            echo "  sudo apt-get install openssl"
            echo ""
            echo "Fedora/RHEL/CentOS:"
            echo "  sudo dnf install openssl"
            echo ""
            echo "macOS:"
            echo "  brew install openssl"
            ;;
        *)
            echo "No specific installation instructions available for ${dependency}"
            echo "Please refer to the official documentation for installation guidance."
            ;;
    esac
    echo ""
}

# Orchestrate all dependency checks
# Checks for: Docker, Docker Compose, bash, curl/wget, jq, openssl
# Returns:
#   0 if all dependencies are present, 1 if any are missing
check_all_dependencies() {
    show_colored_message info "Starting dependency check..."
    echo ""
    
    local all_dependencies_met=true
    local missing_dependencies=()
    
    # Check Docker
    if ! check_docker; then
        all_dependencies_met=false
        missing_dependencies+=("docker")
    fi
    echo ""
    
    # Check Docker Compose
    if ! check_docker_compose; then
        all_dependencies_met=false
        missing_dependencies+=("docker-compose")
    fi
    echo ""
    
    # Check bash
    show_colored_message info "Checking bash installation..."
    if check_command bash; then
        local bash_version=$(bash --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1)
        show_colored_message success "bash ${bash_version} is installed"
    else
        show_colored_message error "bash is not installed"
        all_dependencies_met=false
        missing_dependencies+=("bash")
    fi
    echo ""
    
    # Check curl or wget (at least one required)
    show_colored_message info "Checking curl/wget installation..."
    local has_download_tool=false
    if check_command curl; then
        local curl_version=$(curl --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1)
        show_colored_message success "curl ${curl_version} is installed"
        has_download_tool=true
    elif check_command wget; then
        local wget_version=$(wget --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+(\.\d+)?' | head -1)
        show_colored_message success "wget ${wget_version} is installed"
        has_download_tool=true
    else
        show_colored_message error "Neither curl nor wget is installed (at least one is required)"
        all_dependencies_met=false
        missing_dependencies+=("curl")
    fi
    echo ""
    
    # Check jq
    show_colored_message info "Checking jq installation..."
    if check_command jq; then
        local jq_version=$(jq --version 2>/dev/null | grep -oP '\d+\.\d+(\.\d+)?' | head -1)
        show_colored_message success "jq ${jq_version} is installed"
    else
        show_colored_message error "jq is not installed"
        all_dependencies_met=false
        missing_dependencies+=("jq")
    fi
    echo ""
    
    # Check openssl
    show_colored_message info "Checking openssl installation..."
    if check_command openssl; then
        local openssl_version=$(openssl version 2>/dev/null | grep -oP '\d+\.\d+\.\d+[a-z]?' | head -1)
        show_colored_message success "openssl ${openssl_version} is installed"
    else
        show_colored_message error "openssl is not installed"
        all_dependencies_met=false
        missing_dependencies+=("openssl")
    fi
    echo ""
    
    # Display results
    if [[ "$all_dependencies_met" == true ]]; then
        show_colored_message success "All dependencies are installed and ready!"
        return 0
    else
        show_colored_message error "Some required dependencies are missing:"
        echo ""
        for dep in "${missing_dependencies[@]}"; do
            echo "  - ${dep}"
        done
        echo ""
        show_colored_message info "Please install the missing dependencies and try again."
        echo ""
        
        # Display installation instructions for each missing dependency
        for dep in "${missing_dependencies[@]}"; do
            display_installation_instructions "$dep"
        done
        
        return 1
    fi
}
