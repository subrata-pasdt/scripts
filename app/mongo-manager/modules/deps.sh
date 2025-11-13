#!/bin/bash

check_dependencies() {

  echo "🔍 Checking dependencies..."

  NEED_RESTART=0

  # ---------------------------------------
  # Install basic required packages
  # ---------------------------------------
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release

  # ---------------------------------------
  # Remove Ubuntu's docker.io if present
  # ---------------------------------------
  if dpkg -l | grep -q "docker.io"; then
    echo "⚠️ docker.io detected — removing..."
    sudo apt-get remove -y docker.io
  fi

  # ---------------------------------------
  # Docker CE - Check if installed
  # ---------------------------------------
  if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker CE missing — installing official Docker CE..."

    # Prepare keyring directory
    sudo install -m 0755 -d /etc/apt/keyrings

    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
      sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker apt repository
    echo \
      "deb [arch=$(dpkg --print-architecture) \
 signed-by=/etc/apt/keyrings/docker.gpg] \
 https://download.docker.com/linux/ubuntu \
 $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update & install Docker CE
    sudo apt-get update -y
    sudo apt-get install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin

    # Add user to docker group
    sudo usermod -aG docker $USER
    NEED_RESTART=1
  else
    echo "✅ Docker CE already installed."
  fi

  # ---------------------------------------
  # jq install
  # ---------------------------------------
  if ! command -v jq >/dev/null 2>&1; then
    echo "❌ jq missing — installing..."
    sudo apt-get install -y jq
  else
    echo "✅ jq installed."
  fi

  # ---------------------------------------
  # docker-compose subcommand check
  # (CE plugin)
  # ---------------------------------------
  if ! docker compose version >/dev/null 2>&1; then
    echo "❌ docker-compose-plugin missing — installing..."
    sudo apt-get install -y docker-compose-plugin
  else
    echo "✅ Docker Compose plugin installed."
  fi

  # ---------------------------------------
  # Restart needed?
  # ---------------------------------------
  if [[ $NEED_RESTART -eq 1 ]]; then
    echo ""
    echo "⚠️ Docker CE installed."
    echo "➡️ You MUST log out & log in again for docker group to apply."
    exit 0
  fi

  echo "✅ All dependencies satisfied."
}
