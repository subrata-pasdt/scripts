#!/usr/bin/bash
source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)


# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

# Check if required environment variables are set
if [ -z "$MONGO_INITDB_ROOT_USERNAME" ] || [ -z "$MONGO_INITDB_ROOT_PASSWORD" ]; then
  show_colored_message error "Error: MongoDB credentials (MONGO_INITDB_ROOT_USERNAME and MONGO_INITDB_ROOT_PASSWORD) are not set in .env file!"
  exit 1
fi

MONGO_URL="mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@localhost:27017/admin"
show_colored_message success "$MONGO_URL"
