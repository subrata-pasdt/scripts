#!/bin/bash
source <(curl -s https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

show_header "Nginx Setup" "Script to install Nginx and Nginx Proxy Manager Installation" "16-Sept-2025" "1.0.0"
# Install nginx
sudo apt update
sudo apt install -y nginx

# Install nginx proxy manager
sudo apt install -y nginx-proxy-manager

# Create nginx configuration
sudo tee /etc/nginx/sites-available/default <<EOF
server {
    listen 80;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'keep-alive';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Create nginx proxy manager configuration
sudo tee /etc/nginx-proxy-manager/conf.json <<EOF
{
    "domains": ["localhost"],
    "port": 8080,
    "admin_username": "admin",
    "admin_password": "admin",
    "access_log": "/var/log/nginx-proxy-manager/access.log",
    "error_log": "/var/log/nginx-proxy-manager/error.log"
}
EOF

# Create log directory
sudo mkdir -p /var/log/nginx-proxy-manager

# Restart nginx
sudo service nginx restart
