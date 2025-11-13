#!/bin/bash

generate_compose() {

  echo -n "How many replica nodes? "
  read REPLICAS

  REPLICATION_HOST=$(grep REPLICATION_HOST .env | cut -d'=' -f2)
  BASE_PORT=$(grep MONGO_PORT .env | cut -d'=' -f2)

  [[ -z "$BASE_PORT" ]] && BASE_PORT=27017

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
      mongod --replSet rs0 --bind_ip_all --port $BASE_PORT
    ports:
      - "$PORT:$BASE_PORT"
    volumes:
      - ./data/$NAME:/data/db

EOF
  done

  echo "docker-compose.yml created."
}
