#!/usr/bin/env bash
set -e

# Load PASDT DevOps common functions
source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

show_header "PASDT Devops Script" "Install Docker CE inside Ubuntu Server" "19/11/2025" "v1.0.0"
show_colored_message info "Initializing installation..."

# Ensure script is run on Debian/Ubuntu
if ! command -v apt &> /dev/null; then
  show_colored_message error "This script only supports Debian/Ubuntu systems."
  exit 1
fi

show_colored_message info "Updating system packages..."
sudo apt update -y
sudo apt upgrade -y

show_colored_message info "Installing required dependencies..."
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

show_colored_message info "Adding Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg

show_colored_message info "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

show_colored_message info "Updating package index..."
sudo apt update -y

show_colored_message info "Installing Docker Engine & plugins..."
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

show_colored_message success "Docker installed successfully!"

USER_NAME=$(whoami)

show_colored_message info "Adding user '${USER_NAME}' to docker group..."
sudo groupadd -f docker
sudo usermod -aG docker "$USER_NAME"

show_colored_message success "User added to docker group."

show_colored_message info "Enabling and starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

show_colored_message success "Installation completed!"
show_colored_message info "You must logout/login OR run: newgrp docker"
show_colored_message info "Then verify using: docker run hello-world"
