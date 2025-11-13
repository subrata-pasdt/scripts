#!/bin/bash

init_replicaset() {

  REPLICATION_HOST=$(grep REPLICATION_HOST .env | cut -d'=' -f2)
  BASE_PORT=$(grep MONGO_PORT .env | cut -d'=' -f2)

  NODE_COUNT=$(grep -oP '^  mongo\K[0-9]+' docker-compose.yml | wc -l)

  echo "Detected $NODE_COUNT nodes."

  echo -n "Master container (default: mongo1): "
  read MASTER
  MASTER=${MASTER:-mongo1}

  MEMBERS=""
  for ((i=1; i<=NODE_COUNT; i++)); do
    IDX=$((i-1))
    PORT=$((BASE_PORT + i - 1))
    HOST="${REPLICATION_HOST}:${PORT}"

    if [[ $i -lt $NODE_COUNT ]]; then
      MEMBERS="${MEMBERS}{ _id: $IDX, host: '$HOST' },"
    else
      MEMBERS="${MEMBERS}{ _id: $IDX, host: '$HOST' }"
    fi
  done

docker exec -i "$MASTER" mongosh --eval "
rs.initiate({
  _id: 'rs0',
  members: [ $MEMBERS ]
})
"
  sleep 2
  docker exec -it "$MASTER" mongosh --eval "rs.status()"
}
