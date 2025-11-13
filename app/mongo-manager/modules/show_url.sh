#!/bin/bash

show_url() {

  REPLICATION_HOST=$(grep REPLICATION_HOST .env | cut -d'=' -f2)
  BASE_PORT=$(grep MONGO_PORT .env | cut -d'=' -f2)
  ADMIN=$(grep MONGO_INITDB_ROOT_USERNAME .env | cut -d'=' -f2)
  PASS=$(grep MONGO_INITDB_ROOT_PASSWORD .env | cut -d'=' -f2)

  NODE_COUNT=$(grep -oP '^  mongo\K[0-9]+' docker-compose.yml | wc -l)

  HOSTS=""
  for ((i=1; i<=NODE_COUNT; i++)); do
    PORT=$((BASE_PORT + i - 1))
    HOSTS="${HOSTS}${REPLICATION_HOST}:${PORT},"
  done

  HOSTS="${HOSTS%,}"

  echo "mongodb://$ADMIN:$PASS@$HOSTS/?replicaSet=rs0"
}
