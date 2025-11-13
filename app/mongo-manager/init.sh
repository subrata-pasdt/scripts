#!/bin/bash

# to run this you should call : 
# bash <(curl -s https://raw.githubusercontent.com/subrata-pasdt/scripts/main/app/mongo-manager/init.sh)


REPO="https://raw.githubusercontent.com/subrata-pasdt/scripts/main/app/mongo-manager"

load_module() {
  source <(curl -s "$REPO/modules/$1")
}

load_template() {
  curl -s "$REPO/templates/$1"
}

export -f load_template

# Load ALL modules into memory
load_module "deps.sh"
load_module "validator.sh"
load_module "check_files.sh"
load_module "generate_env.sh"
load_module "generate_compose.sh"
load_module "create_container.sh"
load_module "init_replicaset.sh"
load_module "create_users.sh"
load_module "connect_db.sh"
load_module "show_url.sh"
load_module "reset_all.sh"

# 1) Step: Check Dependencies
check_dependencies

# 2) Step: Check existing .env + compose validity
precheck_files

# 3) Load menu
source <(curl -s "$REPO/modules/main.sh")
