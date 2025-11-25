#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

show_header "SWAP CREATION SCRIPT" "Create Swap" "v1.0.0"

show_colored_message question "Swap size (Example: 4G or 4096M):"
read -p "" SWAP_SIZE

# Validate user input
if [[ -z "$SWAP_SIZE" ]]; then
    show_colored_message error "Error: Swap size cannot be empty."
    exit 1
fi


show_colored_message info "Disabling all existing swap..."
sudo swapoff -a


show_colored_message info "Removing old swap entries from /etc/fstab..."
sudo sed -i '/swapfile/d' /etc/fstab

show_colored_message info "Removing old swap files (if any)..."
if [ -f /swapfile ]; then
    sudo rm -f /swapfile
fi

show_colored_message info "Creating new swap file of size: $SWAP_SIZE"
sudo fallocate -l $SWAP_SIZE /swapfile 2>/dev/null

# fallback if fallocate fails on some filesystems
if [ $? -ne 0 ]; then
    show_colored_message info "fallocate failed, using dd instead..."
    SIZE_MB=$(echo $SWAP_SIZE | sed 's/[^0-9]//g')
    sudo dd if=/dev/zero of=/swapfile bs=1M count=$SIZE_MB
fi

show_colored_message info "Setting correct permissions..."
sudo chmod 600 /swapfile

show_colored_message info "Creating swap area..."
sudo mkswap /swapfile

show_colored_message info "Enabling swap..."
sudo swapon /swapfile

show_colored_message info "Updating /etc/fstab..."
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab

show_colored_message success "Swap successfully created!"
show_colored_message success "Size: $SWAP_SIZE"

swapon --show
free -h