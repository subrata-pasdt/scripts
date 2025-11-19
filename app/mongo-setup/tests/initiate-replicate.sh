#!/usr/bin/bash
source ~/tools/scripts/pasdt-devops-scripts.sh


CONTAINER_NAME=$1



# Function to initiate a replica set
initiate_replica_set() {
  local container_name=$1
  local mongo_url=$2

  show_colored_message info "Initiating replica set..."

  # Capture the output and exit status
  local output
  output=$(docker exec -i "$container_name" mongosh "$mongo_url" --eval "
    rs.initiate({
      _id: 'rs0',
      members: [
        { _id: 0, host: '168.220.243.242:27019' }
      ]
    })
  " 2>&1)  # Capture both stdout and stderr

  local status=$?

  if [ $status -eq 0 ]; then
    show_colored_message success "Replica set initiated successfully."
    show_colored_message info "Initiating User Creation ..."
    sleep 10
    bash scripts/user-management.sh "$container_name"
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
export $(grep -v '^#' .env | xargs)

# Check if required environment variables are set
if [ -z "$MONGO_INITDB_ROOT_USERNAME" ] || [ -z "$MONGO_INITDB_ROOT_PASSWORD" ]; then
  show_colored_message error "Error: MongoDB credentials (MONGO_INITDB_ROOT_USERNAME and MONGO_INITDB_ROOT_PASSWORD) are not set in .env file!"
  read -p  $(show_colored_message "question" "Enter MongoDB root username: ") MONGO_INITDB_ROOT_USERNAME
  read -s -p $(show_colored_message "question" "Enter MongoDB root password: ") MONGO_INITDB_ROOT_PASSWORD
  echo 
fi

MONGO_URL="mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@${CONTAINER_NAME}:27017/admin"

# Run the MongoDB shell command to initialize the replica set inside the container
show_colored_message info "Initializing replica set for container: $CONTAINER_NAME"
initiate_replica_set $CONTAINER_NAME $MONGO_URL

