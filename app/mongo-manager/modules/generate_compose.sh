#!/bin/bash
set -euo pipefail

generate_compose() {

  echo -n "How many replica nodes? "
  read REPLICAS

  [[ -f .env ]] || { echo ".env missing - run generate_env first"; return 1; }

  REPLICATION_HOST=$(grep -E '^REPLICATION_HOST=' .env | cut -d'=' -f2-)
  BASE_PORT=$(grep -E '^MONGO_PORT=' .env | cut -d'=' -f2-)
  [[ -z "$BASE_PORT" ]] && BASE_PORT=27017

  # Ensure keyfile directory exists
  mkdir -p keyfile
  if [[ ! -f keyfile/mongo.key ]]; then
    echo "Generating keyfile..."
    openssl rand -base64 756 > keyfile/mongo.key
  fi
  chmod 400 keyfile/mongo.key

  echo "Generating full docker-compose.yml with keyfile authentication..."

cat <<EOF > docker-compose.yml
version: "3.9"

services:
EOF

  for ((i=1; i<=REPLICAS; i++)); do
    NAME="mongo$i"
    PORT=$((BASE_PORT + i - 1))

cat <<EOF >> docker-compose.yml
  $NAME:
    image: mongo:7
    container_name: $NAME
    restart: always
    env_file: .env
    command: >
      bash -c "chown 999:999 /keyfile/mongo.key &&
               chmod 400 /keyfile/mongo.key &&
               exec mongod --replSet rs0
                            --bind_ip_all
                            --port ${BASE_PORT}
                            --keyFile /keyfile/mongo.key"
    privileged: true
    security_opt:
      - seccomp=unconfined
    ports:
      - "${PORT}:${BASE_PORT}"
    volumes:
      - ./data/$NAME:/data/db
      - ./keyfile:/keyfile

EOF

  done

  echo ""
  echo "✔ docker-compose.yml created with:"
  echo "  - KeyFile authentication enabled"
  echo "  - ReplicaSet mode configured"
  echo "  - Correct ownership handling"
  echo "  - Correct permissions enforcement"
  echo "  - Dynamic port mapping"
  echo "  - ${REPLICAS} replica nodes"
  echo ""
}



# #!/bin/bash
# # modules/generate_compose.sh
# set -euo pipefail

# generate_compose() {
#   echo -n "How many replica nodes? "
#   read REPLICAS

#   [[ -f .env ]] || { echo ".env missing - run generate_env first"; return 1; }

#   REPLICATION_HOST=$(grep -E '^REPLICATION_HOST=' .env | cut -d'=' -f2-)
#   BASE_PORT=$(grep -E '^MONGO_PORT=' .env | cut -d'=' -f2-)
#   [[ -z "$BASE_PORT" ]] && BASE_PORT=27017

#   cat <<EOF > docker-compose.yml
# version: "3.9"

# services:
# EOF

#   for ((i=1; i<=REPLICAS; i++)); do
#     NAME="mongo$i"
#     PORT=$((BASE_PORT + i - 1))

# cat <<EOF >> docker-compose.yml
#   $NAME:
#     image: mongo:7
#     container_name: $NAME
#     restart: always
#     env_file: .env
#     # Start WITHOUT keyFile so replica initiation & admin creation can happen
#     command: >
#       mongod --replSet rs0 --bind_ip_all --port ${BASE_PORT}
#     # security tweaks to avoid sysctl / seccomp problems on some hosts
#     privileged: true
#     security_opt:
#       - seccomp=unconfined
#     ports:
#       - "${PORT}:${BASE_PORT}"
#     volumes:
#       - ./data/$NAME:/data/db

# EOF

#   done

#   echo "docker-compose.yml created (no keyfile). Ports: ${BASE_PORT}..$((BASE_PORT + REPLICAS - 1))"
# }
