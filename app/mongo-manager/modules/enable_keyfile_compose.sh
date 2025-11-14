#!/bin/bash

enable_keyfile_compose() {
  if [[ ! -f .env ]]; then
    echo ".env missing"; return 1
  fi

  if [[ ! -f keyfile/mongo.key ]]; then
    echo "keyfile missing"; return 1
  fi

  BASE_PORT=$(grep MONGO_PORT .env | cut -d'=' -f2)
  REPLICATION_HOST=$(grep REPLICATION_HOST .env | cut -d'=' -f2)

  NODE_COUNT=$(grep -oP '^  mongo\K[0-9]+' docker-compose.yml | wc -l)

  echo "Rewriting compose file for $NODE_COUNT nodes with keyfile..."

  cat <<EOF > docker-compose.yml
version: "3.9"
services:
EOF

  for ((i=1; i<=NODE_COUNT; i++)); do
    PORT=$((BASE_PORT + i - 1))

cat <<EOF >> docker-compose.yml
  mongo$i:
    image: mongo:7
    container_name: mongo$i
    restart: always
    env_file: .env
    command: >
      bash -c "chown 999:999 /keyfile/mongo.key &&
               chmod 400 /keyfile/mongo.key &&
               exec mongod --replSet rs0 --bind_ip_all --port ${BASE_PORT} --keyFile /keyfile/mongo.key"
    privileged: true
    security_opt:
      - seccomp=unconfined
    ports:
      - "${PORT}:${BASE_PORT}"
    volumes:
      - ./data/mongo$i:/data/db
      - ./keyfile:/keyfile

EOF
  done

  echo "docker-compose.yml updated with keyfile support."
}
