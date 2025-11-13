#!/bin/bash
# modules/enable_keyfile_compose.sh
set -euo pipefail

# This function rewrites docker-compose.yml to enable keyFile usage.
# It expects .env to have MONGO_PORT present and keyfile/mongo.key to exist.
enable_keyfile_compose() {
  if [[ ! -f .env ]]; then
    echo ".env not found"
    return 1
  fi
  if [[ ! -f keyfile/mongo.key ]]; then
    echo "keyfile/mongo.key not found"
    return 1
  fi

  REPLICATION_HOST=$(grep -E '^REPLICATION_HOST=' .env | cut -d'=' -f2-)
  BASE_PORT=$(grep -E '^MONGO_PORT=' .env | cut -d'=' -f2-)
  [[ -z "$BASE_PORT" ]] && BASE_PORT=27017

  # Count services previously defined by pattern mongoN in current compose if exists, otherwise ask
  if [[ -f docker-compose.yml ]]; then
    NODE_COUNT=$(grep -oP '^  mongo\K[0-9]+' docker-compose.yml | wc -l)
  else
    echo "docker-compose.yml missing"
    return 1
  fi

  if [[ "$NODE_COUNT" -le 0 ]]; then
    echo "No mongo services found in docker-compose.yml"
    return 1
  fi

  cat <<EOF > docker-compose.yml
version: "3.9"

services:
EOF

  for ((i=1; i<=NODE_COUNT; i++)); do
    NAME="mongo$i"
    PORT=$((BASE_PORT + i - 1))

cat <<EOF >> docker-compose.yml
  $NAME:
    image: mongo:7
    container_name: $NAME
    restart: always
    env_file: .env
    # wrapper ensures the key file inside the container has correct owner/perms before mongod starts
    command: >
      bash -c "chown 999:999 /keyfile/mongo.key && chmod 400 /keyfile/mongo.key && exec mongod --replSet rs0 --bind_ip_all --port ${BASE_PORT} --keyFile /keyfile/mongo.key"
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

  echo "docker-compose.yml rewritten to enable keyfile for $NODE_COUNT nodes."
}
