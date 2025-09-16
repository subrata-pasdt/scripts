# Install docker


source <(curl -s https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

show_header "Docker Setup" "Script to install and setup docker" "16-Sept-2025" "1.0.0"


sudo apt update
sudo apt install -y docker.io docker-compose

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
