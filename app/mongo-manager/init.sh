#!/bin/bash

REPO="https://raw.githubusercontent.com/subrata-pasdt/scripts/main/mongo-manager"

load_module() {
  local file=$1
  echo "Loading $file ..."
  source <(curl -s "$REPO/modules/$file")
}

load_template() {
  curl -s "$REPO/templates/$1"
}

# Make template loader available to modules
export -f load_template

# Load all modules
load_module "check_files.sh"
load_module "generate_env.sh"
load_module "generate_compose.sh"
load_module "create_container.sh"
load_module "init_replicaset.sh"
load_module "create_users.sh"
load_module "connect_db.sh"
load_module "show_url.sh"
load_module "reset_all.sh"

# Load main menu
source <(curl -s "$REPO/modules/main.sh")
