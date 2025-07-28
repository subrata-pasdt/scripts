#!/bin/bash

# Exit on error
set -e

# Variables (customize as needed)
GIT_USER="git"
REPO_NAME="myproject.git"
REPO_PATH="/home/$GIT_USER/repos/$REPO_NAME"
AUTHORIZED_KEY_PATH="/tmp/git-authorized-key.pub"

# Install Git if not installed
if ! command -v git &> /dev/null; then
    echo "Installing Git..."
    sudo apt update
    sudo apt install -y git
fi

# Create git user if it doesn't exist
if ! id "$GIT_USER" &> /dev/null; then
    echo "Creating user '$GIT_USER'..."
    sudo adduser --disabled-password --gecos "" $GIT_USER
fi

# Prompt for public key if not found
if [[ ! -f "$AUTHORIZED_KEY_PATH" ]]; then
    echo "⚠️ Public key not found at $AUTHORIZED_KEY_PATH"
    echo "Paste your SSH public key below (usually found in ~/.ssh/id_rsa.pub):"
    read -r PUBKEY_INPUT

    if [[ -z "$PUBKEY_INPUT" ]]; then
        echo "❌ No input provided. Exiting."
        exit 1
    fi

    echo "$PUBKEY_INPUT" > "$AUTHORIZED_KEY_PATH"
fi

# Create SSH directory for git user
echo "Setting up SSH access..."
sudo mkdir -p /home/$GIT_USER/.ssh
sudo touch /home/$GIT_USER/.ssh/authorized_keys
sudo chmod 700 /home/$GIT_USER/.ssh
sudo chmod 600 /home/$GIT_USER/.ssh/authorized_keys
sudo chown -R $GIT_USER:$GIT_USER /home/$GIT_USER/.ssh

# Add public key
echo "Adding authorized key..."
sudo cat "$AUTHORIZED_KEY_PATH" | sudo tee -a /home/$GIT_USER/.ssh/authorized_keys > /dev/null

# Create directory and bare repo
echo "Creating bare repo at $REPO_PATH..."
sudo mkdir -p "$(dirname "$REPO_PATH")"
sudo git init --bare "$REPO_PATH"
sudo chown -R $GIT_USER:$GIT_USER "$(dirname "$REPO_PATH")"

# Output success message
echo ""
echo "✅ Git server setup complete."
echo "You can now clone your repo using:"
echo "git clone git@<your-server-ip>:$REPO_PATH"
