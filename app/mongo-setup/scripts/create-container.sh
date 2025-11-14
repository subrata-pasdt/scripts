#!/usr/bin/env bash
set -e

# ------------------------------------------------------------
# Load PASDT DevOps helper functions from GitHub
# ------------------------------------------------------------
# source <(curl -s https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devos-scripts.sh)


# ------------------------------------------------------------
# Detect local IP address (non-docker, non-loopback)
# ------------------------------------------------------------
HOST_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')

if [[ -z "$HOST_IP" ]]; then
    show_colored_message error "Could not detect system IP address!"
    exit 1
fi

show_colored_message info "Detected system IP: $HOST_IP"


# ------------------------------------------------------------
# Ask user for replica count
# ------------------------------------------------------------
read -p "How many MongoDB replica set nodes do you want? (1-10): " REPLICA_COUNT

if ! [[ "$REPLICA_COUNT" =~ ^[1-9]$|^10$ ]]; then
    show_colored_message error "Invalid replica count. Must be between 1 and 10."
    exit 1
fi


# ------------------------------------------------------------
# Ask user for starting port (default: 27017)
# ------------------------------------------------------------
read -p "Enter starting port (default 27017): " START_PORT
START_PORT="${START_PORT:-27017}"

if ! [[ "$START_PORT" =~ ^[0-9]+$ ]]; then
    show_colored_message error "Port must be a number!"
    exit 1
fi

show_colored_message info "ReplicaSet will use ports starting from: $START_PORT"


# ------------------------------------------------------------
# Create .env if missing
# ------------------------------------------------------------
if [ ! -f ".env" ]; then
    show_colored_message info "Creating .env file..."

    echo "MONGO_INITDB_ROOT_USERNAME=$(openssl rand -hex 8)" > .env
    echo "MONGO_INITDB_ROOT_PASSWORD=$(openssl rand -hex 16)" >> .env
    echo "HOST_IP=$HOST_IP" >> .env
    echo "REPLICA_COUNT=$REPLICA_COUNT" >> .env
    echo "START_PORT=$START_PORT" >> .env

    show_colored_message success ".env created successfully!"
else
    # Update or append values
    grep -q "^HOST_IP=" .env  && sed -i "s/^HOST_IP=.*/HOST_IP=$HOST_IP/" .env  || echo "HOST_IP=$HOST_IP" >> .env
    grep -q "^REPLICA_COUNT=" .env  && sed -i "s/^REPLICA_COUNT=.*/REPLICA_COUNT=$REPLICA_COUNT/" .env  || echo "REPLICA_COUNT=$REPLICA_COUNT" >> .env
    grep -q "^START_PORT=" .env  && sed -i "s/^START_PORT=.*/START_PORT=$START_PORT/" .env  || echo "START_PORT=$START_PORT" >> .env
fi


# Load .env values
source .env


# ------------------------------------------------------------
# Ensure secrets/mongodb-keyfile exists
# ------------------------------------------------------------
if [ ! -f "secrets/mongodb-keyfile" ]; then
    show_colored_message info "Generating MongoDB keyfile..."

    mkdir -p secrets
    openssl rand -base64 512 > secrets/mongodb-keyfile
    chmod 600 secrets/mongodb-keyfile
    sudo chown 999:999 secrets/mongodb-keyfile

    show_colored_message success "mongodb-keyfile created!"
fi


# ------------------------------------------------------------
# Generate docker-compose.yaml dynamically
# ------------------------------------------------------------
show_colored_message info "Generating docker-compose.yaml..."

cat <<EOL > docker-compose.yaml
services:
EOL

for ((i=1; i<=REPLICA_COUNT; i++)); do
    NODE_PORT=$((START_PORT + i - 1))

cat <<EOL >> docker-compose.yaml
  mongo$i:
    image: mongo:6.0
    container_name: mongo$i
    restart: always
    command: ["mongod", "--replSet", "rs0", "--bind_ip_all", "--keyFile", "/etc/secrets/mongo-keyfile"]
    environment:
      - MONGO_INITDB_ROOT_USERNAME=\${MONGO_INITDB_ROOT_USERNAME}
      - MONGO_INITDB_ROOT_PASSWORD=\${MONGO_INITDB_ROOT_PASSWORD}
    volumes:
      - ./data/mongo$i:/data/db
      - ./secrets/mongodb-keyfile:/etc/secrets/mongo-keyfile:ro
    ports:
      - "$NODE_PORT:27017"

EOL
done

cat <<EOL >> docker-compose.yaml
volumes:
  data:
EOL

show_colored_message success "docker-compose.yaml created!"


# ------------------------------------------------------------
# Start all containers
# ------------------------------------------------------------
# docker compose up -d
# show_colored_message success "All $REPLICA_COUNT replica nodes started!"
# sleep 8


# ------------------------------------------------------------
# Run initiate-replicate.sh from GitHub
# ------------------------------------------------------------
# bash <(curl -s https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/scripts/initiate-replicate.sh)
