#!/usr/bin/bash
source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

# Load configuration from .env file
if [ ! -f ".env" ]; then
    show_colored_message error "Error: .env file not found!"
    show_colored_message info "Please run the configuration manager first to generate .env file"
    exit 1
fi

show_colored_message info "Loading configuration from .env file..."
export $(grep -v '^#' .env | xargs)

# Validate required environment variables
if [ -z "$REPLICA_COUNT" ] || [ -z "$REPLICA_HOST_IP" ] || [ -z "$STARTING_PORT" ]; then
    show_colored_message error "Error: Required configuration variables not found in .env file!"
    show_colored_message info "Required: REPLICA_COUNT, REPLICA_HOST_IP, STARTING_PORT"
    exit 1
fi

if [ -z "$MONGO_INITDB_ROOT_USERNAME" ] || [ -z "$MONGO_INITDB_ROOT_PASSWORD" ]; then
    show_colored_message error "Error: MONGO_INITDB_ROOT_USERNAME and/or MONGO_INITDB_ROOT_PASSWORD are not set in .env file!"
    exit 1
fi

# Use KEYFILE_PATH from .env or default to secrets/mongodb-keyfile
KEYFILE_PATH=${KEYFILE_PATH:-"./secrets/mongodb-keyfile"}

# Check if keyfile exists
if [ ! -f "$KEYFILE_PATH" ]; then
    show_colored_message error "mongodb-keyfile not found at $KEYFILE_PATH!"
    show_colored_message info "Please run the file generator first to create the keyfile"
    exit 1
fi

show_colored_message info "Generating dynamic docker-compose.yaml for $REPLICA_COUNT replica members..."

# Start generating docker-compose.yaml
cat > docker-compose.yaml <<EOF
services:
EOF

# Generate service definitions for each replica member
for i in $(seq 1 $REPLICA_COUNT); do
    CURRENT_PORT=$((STARTING_PORT + i - 1))
    
    show_colored_message info "Configuring mongo$i on port $CURRENT_PORT..."
    
    cat >> docker-compose.yaml <<EOF
  mongo$i:
    image: mongo:latest
    container_name: mongo$i
    restart: always
    command: ["mongod", "--replSet", "rs0", "--bind_ip", "0.0.0.0", "--keyFile", "/etc/secrets/mongo-keyfile"]
    environment:
      - MONGO_INITDB_ROOT_USERNAME=\${MONGO_INITDB_ROOT_USERNAME}
      - MONGO_INITDB_ROOT_PASSWORD=\${MONGO_INITDB_ROOT_PASSWORD}
    volumes:
      - ./data/mongo$i:/data/db
      - $KEYFILE_PATH:/etc/secrets/mongo-keyfile:ro
    ports:
      - $CURRENT_PORT:27017
    networks:
      - mongo-network

EOF
done

# Add networks section
cat >> docker-compose.yaml <<EOF
networks:
  mongo-network:
    driver: bridge
EOF

show_colored_message success "docker-compose.yaml generated successfully!"

# Create data directories for each replica member
show_colored_message info "Creating data directories..."
for i in $(seq 1 $REPLICA_COUNT); do
    mkdir -p ./data/mongo$i
done
show_colored_message success "Data directories created!"

# Start containers
show_colored_message info "Starting MongoDB containers..."
docker compose -f docker-compose.yaml up -d

if [ $? -eq 0 ]; then
    show_colored_message success "MongoDB containers started successfully!"
else
    show_colored_message error "Failed to start MongoDB containers!"
    exit 1
fi

show_colored_message info "Waiting for MongoDB instances to be ready..."
sleep 10

show_colored_message success "MongoDB instances are ready for replica set initialization"
