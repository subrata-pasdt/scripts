#!/usr/bin/bash
source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)


CONTAINER_NAME=$1



# Function to generate replica set members array dynamically
generate_replica_members() {
  local replica_count=$1
  local host_ip=$2
  local starting_port=$3  
  local members=""
  for ((i=0; i<replica_count; i++)); do
    local port=$((starting_port + i))
    if [ $i -gt 0 ]; then
      members+=", "
    fi
    members+="{ _id: $i, host: '${host_ip}:${port}' }"
  done
  
  echo "$members"
}

# Function to initiate a replica set
initiate_replica_set() {
  local container_name=$1
  local mongo_url=$2
  local members_config=$3

  show_colored_message info "Initiating replica set with dynamic configuration..."
  show_colored_message info "Members configuration: $members_config"

  # Capture the output and exit status
  local output
  output=$(docker exec -i "$container_name" mongosh "$mongo_url" --eval "
    rs.initiate({
      _id: 'rs0',
      members: [ $members_config ]
    })
  " 2>&1)  # Capture both stdout and stderr

  local status=$?

  if [ $status -eq 0 ]; then
    show_colored_message success "Replica set initiated successfully."
    show_colored_message info "Waiting for replica set to stabilize..."
    sleep 5
  else
    show_colored_message error "Failed to initiate replica set!"
    echo "$output"
    exit 1
  fi
}




# Check if the required arguments are provided
if [ -f "docker-compose.yaml" ]; then
  show_colored_message infor "docker-compose.yaml file found!"
  # Read container names from docker-compose.yaml
  mapfile -t options < <(grep "container_name" docker-compose.yaml | cut -d ":" -f2 | tr -d ' ')
  select container in "${options[@]}" "Exit"; do
    if [[ "$container" == "Exit" ]]; then
       "Exiting."
      exit 0
    fi

    if [[ -n "$container" ]]; then
      show_colored_message ifo "You selected container: $container"
      CONTAINER_NAME=$container
      break 2
    else
      show_colored_message error "Invalid selection. Try again."
    fi
  done

else
  show_colored_message error "Error: docker-compose.yaml file not found!"
  show_colored_message info "Switching to arguments mode..."
fi


show_colored_message info "Container name: $CONTAINER_NAME"


if [ -z "$CONTAINER_NAME" ] && [ $# -eq 0 ]; then
  show_colored_message warning "Usage: $0 <container_name>"
  exit 1
fi

# Load environment variables from .env file
show_colored_message info "Loading configuration from .env file..."
export $(grep -v '^#' .env | xargs)

# Check if required environment variables are set
if [ -z "$MONGO_INITDB_ROOT_USERNAME" ] || [ -z "$MONGO_INITDB_ROOT_PASSWORD" ]; then
  show_colored_message error "Error: MongoDB credentials (MONGO_INITDB_ROOT_USERNAME and MONGO_INITDB_ROOT_PASSWORD) are not set in .env file!"
  read -p  $(show_colored_message "question" "Enter MongoDB root username: ") MONGO_INITDB_ROOT_USERNAME
  read -s -p $(show_colored_message "question" "Enter MongoDB root password: ") MONGO_INITDB_ROOT_PASSWORD
  echo 
fi

# Load replica set configuration from .env
if [ -z "$REPLICA_COUNT" ] || [ -z "$REPLICA_HOST_IP" ] || [ -z "$STARTING_PORT" ]; then
  show_colored_message error "Error: Replica set configuration (REPLICA_COUNT, REPLICA_HOST_IP, STARTING_PORT) not found in .env file!"
  show_colored_message info "Using default values: REPLICA_COUNT=3, REPLICA_HOST_IP=localhost, STARTING_PORT=27017"
  REPLICA_COUNT=${REPLICA_COUNT:-3}
  REPLICA_HOST_IP=${REPLICA_HOST_IP:-localhost}
  STARTING_PORT=${STARTING_PORT:-27017}
fi

show_colored_message success "Configuration loaded successfully:"
show_colored_message info "  - Replica Count: $REPLICA_COUNT"
show_colored_message info "  - Host IP: $REPLICA_HOST_IP"
show_colored_message info "  - Starting Port: $STARTING_PORT"

# Generate replica set members configuration
show_colored_message info "Generating replica set configuration for $replica_count members..."
MEMBERS_CONFIG=$(generate_replica_members "$REPLICA_COUNT" "$REPLICA_HOST_IP" "$STARTING_PORT")

MONGO_URL="mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@${CONTAINER_NAME}:27017/admin"

# Run the MongoDB shell command to initialize the replica set inside the container
show_colored_message info "Initializing replica set for container: $CONTAINER_NAME"
initiate_replica_set "$CONTAINER_NAME" "$MONGO_URL" "$MEMBERS_CONFIG"

