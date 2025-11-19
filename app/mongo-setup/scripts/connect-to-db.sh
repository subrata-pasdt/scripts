#!/bin/bash
source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)


export $(grep -v '^#' .env | xargs)

CONTAINERS=$(docker compose config --services)
show_colored_message question "Choose a container:"
select container in $CONTAINERS; do
  if [[ -n "$container" ]]; then
    echo "Connecting to $container"
    docker exec -it "$container" mongosh --eval "show dbs" --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD"
    read -p "Enter database name: " db
    if [[ -n "$db" ]]; then
      docker exec -it "$container" mongosh "mongodb://localhost:27017/$db" --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD"
    else
      echo "No database chosen. Exiting."
    fi
    break
  else
    echo "Invalid selection. Try again."
  fi
done
