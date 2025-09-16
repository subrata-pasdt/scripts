#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)
show_header "Docker Setup" "Script to install and setup docker" "16-Sept-2025" "1.0.0"

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update


# Install the docker-ce
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Create docker group
sudo groupadd docker

# Add current user to docker group
sudo usermod -aG docker $USER

# Set permissions to allow non-root users to run docker
sudo chmod 666 /var/run/docker.sock

# Restart docker service
sudo systemctl restart docker.service

# Reload group permissions
newgrp $USER

