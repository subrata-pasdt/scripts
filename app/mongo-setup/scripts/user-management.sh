#!/bin/bash
source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

# Function to check if users.json exists and create a demo one if not
check_and_create_json() {
  JSON_FILE="scripts/users.json"

  # Check if the JSON file exists
  if [ ! -f "$JSON_FILE" ]; then
    show_colored_message error "Error: JSON file '$JSON_FILE' not found!"

    # Create a demo users.json file with sample data
    cat <<EOL > "$JSON_FILE"
[
  {
    "user": "demo_user1",
    "pass": "demo_pass1",
    "roles": [
      {
        "role": "readWrite",
        "db": "demo_db1"
      }
    ]
  },
  {
    "user": "demo_user2",
    "pass": "demo_pass2",
    "roles": [
      {
        "role": "readWrite",
        "db": "demo_db2"
      },
      {
        "role": "readWrite",
        "db": "demo_db3"
      }
    ]
  }
]
EOL
    show_colored_message info "'users.json' has been created with demo data. Please edit it accordingly and run again."
    exit 1
  fi
}

CONTAINER_NAME=$1

# Check if the required arguments are provided
if [ "$#" -ne 1 ]; then
  mapfile -t options < <(grep "container_name" docker-compose.yaml | cut -d ":" -f2 | tr -d ' ')
  select container in "${options[@]}" "Exit"; do
    if [[ "$container" == "Exit" ]]; then
      show_colored_message info "Exiting."
      exit 0
    fi

    if [[ -n "$container" ]]; then
      show_colored_message info "You selected container: $container"
      CONTAINER_NAME=$container
      break
    else
      show_colored_message error "Invalid selection. Try again."
    fi
  done
fi


# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

# Check if required environment variables are set
if [ -z "$MONGO_INITDB_ROOT_USERNAME" ] || [ -z "$MONGO_INITDB_ROOT_PASSWORD" ]; then
  show_colored_message error "Error: MongoDB credentials (MONGO_INITDB_ROOT_USERNAME and MONGO_INITDB_ROOT_PASSWORD) are not set in .env file!"
  exit 1
fi

MONGO_URL="mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@${CONTAINER_NAME}:27017"

# Call the function to check for users.json file
check_and_create_json

# Read the JSON file and process users
for user_data in $(jq -c '.[]' "$JSON_FILE"); do
  # Extract user details from the JSON
  USER=$(echo "$user_data" | jq -r '.user')
  PASS=$(echo "$user_data" | jq -r '.pass')
  ROLES=$(echo "$user_data" | jq -c '.roles')
  echo 
  show_colored_message "" "----- Processing : $USER -------"

  # Remove existing user if present
  if docker exec -i "$CONTAINER_NAME" mongosh "$MONGO_URL/admin" --eval "db.dropUser('$USER')" > /dev/null 2>&1; then
    show_colored_message info "Dropped existing user: $USER"
  else
    show_colored_message error "User not found: $USER, proceeding to create a new one..."
  fi

  # Prepare roles as MongoDB command syntax
  ROLES_ARRAY=""
  for role_data in $(echo "$ROLES" | jq -c '.[]'); do
    ROLE_NAME=$(echo "$role_data" | jq -r '.role')
    ROLE_DB=$(echo "$role_data" | jq -r '.db')
    ROLES_ARRAY="$ROLES_ARRAY{ role: \"$ROLE_NAME\", db: \"$ROLE_DB\" },"
  done

  # Remove the trailing comma if it exists
  ROLES_ARRAY=$(echo "$ROLES_ARRAY" | sed 's/,$//')

  # Create the new user with the specified roles
  if docker exec -i "$CONTAINER_NAME" mongosh "$MONGO_URL/admin" --eval "
    db.createUser({
      user: '$USER',
      pwd: '$PASS',
      roles: [$ROLES_ARRAY]
    })
  " > /dev/null 2>&1; then
    show_colored_message success "Created new user: $USER"
  else
    show_colored_message error "Error: Failed to create new user for: $USER"
  fi
done

exit 0
