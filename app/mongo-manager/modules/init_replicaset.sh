#!/bin/bash
set -euo pipefail

# Wait for a MongoDB node to respond to an authenticated ping
_wait_node_ready() {
  local container=$1
  local user=$2
  local pass=$3
  local timeout=${4:-120}
  local start=$(date +%s)
  local now

  while true; do
    if docker exec -i "$container" \
        mongosh -u "$user" -p "$pass" --authenticationDatabase admin \
        --quiet --eval 'db.adminCommand({ ping: 1 })' >/dev/null 2>&1; then
      return 0
    fi
    now=$(date +%s)
    if (( now - start > timeout )); then
      return 1
    fi
    sleep 2
  done
}

init_replicaset() {

  # Validate prerequisites
  if [[ ! -f .env ]]; then
    echo "❌ Error: .env missing. Run generate_env first."
    return 1
  fi

  if [[ ! -f docker-compose.yml ]]; then
    echo "❌ Error: docker-compose.yml missing. Run generate_compose first."
    return 1
  fi

  REPLICATION_HOST=$(grep -E '^REPLICATION_HOST=' .env | cut -d'=' -f2-)
  BASE_PORT=$(grep -E '^MONGO_PORT=' .env | cut -d'=' -f2-)
  ADMIN_USER=$(grep -E '^MONGO_INITDB_ROOT_USERNAME=' .env | cut -d'=' -f2-)
  ADMIN_PASS=$(grep -E '^MONGO_INITDB_ROOT_PASSWORD=' .env | cut -d'=' -f2-)

  NODE_COUNT=$(grep -oP '^  mongo\K[0-9]+' docker-compose.yml | wc -l)
  if [[ "$NODE_COUNT" -le 0 ]]; then
    echo "❌ No mongoN services found in docker-compose.yml."
    return 1
  fi

  echo "🟦 ReplicaSet bootstrap starting..."
  echo "Nodes detected: $NODE_COUNT"

  # 1️⃣ Start containers
  echo "▶ Starting containers..."
  docker compose up -d

  # 2️⃣ Wait for nodes to become ready (auth-mode expected)
  echo "▶ Waiting for all nodes to accept authenticated connections..."

  for ((i=1; i<=NODE_COUNT; i++)); do
    NAME="mongo$i"
    echo -n "  - Waiting for $NAME ... "
    if _wait_node_ready "$NAME" "$ADMIN_USER" "$ADMIN_PASS" 120; then
      echo "ready"
    else
      echo "FAILED"
      docker logs "$NAME" --tail 200
      return 1
    fi
  done

  # 3️⃣ Build replica members list
  MEMBERS=""
  for ((i=1; i<=NODE_COUNT; i++)); do
    ID=$((i-1))
    PORT=$((BASE_PORT + i - 1))
    HOST="${REPLICATION_HOST}:${PORT}"

    if [[ $i -lt $NODE_COUNT ]]; then
      MEMBERS="${MEMBERS}{ _id: $ID, host: '$HOST' },"
    else
      MEMBERS="${MEMBERS}{ _id: $ID, host: '$HOST' }"
    fi
  done

  # 4️⃣ Initiate replica set on mongo1
  MASTER="mongo1"
  echo "▶ Initiating Replica Set on $MASTER..."

  docker exec -i "$MASTER" \
    mongosh -u "$ADMIN_USER" -p "$ADMIN_PASS" --authenticationDatabase admin \
    --eval "rs.initiate({ _id: 'rs0', members: [ $MEMBERS ] })" \
    || echo "Replica set may already be initiated, continuing..."

  # 5️⃣ Wait for PRIMARY
  echo -n "▶ Waiting for PRIMARY election..."

  local start=$(date +%s)
  while true; do
    if docker exec -i "$MASTER" \
      mongosh -u "$ADMIN_USER" -p "$ADMIN_PASS" --authenticationDatabase admin \
      --quiet --eval "rs.isMaster().ismaster" | grep -q "true"; then
        echo " PRIMARY active"
        break
    fi

    now=$(date +%s)
    if (( now - start > 120 )); then
      echo " TIMEOUT"
      docker exec -i "$MASTER" \
        mongosh -u "$ADMIN_USER" -p "$ADMIN_PASS" --authenticationDatabase admin \
        --eval "printjson(rs.status())"
      return 1
    fi
    sleep 2
  done

  # 6️⃣ Verified working
  echo ""
  echo "==========================================="
  echo "  ✅ Replica Set Initialization Complete"
  echo "  ReplicaSet: rs0"
  echo "  Primary: $MASTER"
  echo "==========================================="
  echo ""

  # 7️⃣ Show rs.status()
  docker exec -i "$MASTER" \
    mongosh -u "$ADMIN_USER" -p "$ADMIN_PASS" --authenticationDatabase admin \
    --eval "printjson(rs.status())"
}
