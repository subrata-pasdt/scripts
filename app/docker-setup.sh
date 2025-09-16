#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)
show_header "Docker Setup" "Script to install and setup docker" "16-Sept-2025" "1.0.0"

# Install docker ce

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg_key.deb | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce-cli

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

