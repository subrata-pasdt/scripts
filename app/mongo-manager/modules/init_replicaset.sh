#!/bin/bash
# modules/init_replicaset.sh
set -euo pipefail

# Wait helper: wait until mongosh ping succeeds on a container
_wait_mongo_ready() {
  local container=$1
  local port=$2
  local timeout=${3:-120}
  local start ts
  start=$(date +%s)
  while true; do
    if docker exec -i "$container" mongosh --quiet --eval 'db.adminCommand({ping:1})' >/dev/null 2>&1; then
      return 0
    fi
    ts=$(date +%s)
    if (( ts - start > timeout )); then
      return 1
    fi
    sleep 2
  done
}

init_replicaset() {
  # Ensure .env and compose exist
  if [[ ! -f .env ]]; then
    echo ".env missing. Run generate_env first."
    return 1
  fi
  if [[ ! -f docker-compose.yml ]]; then
    echo "docker-compose.yml missing. Run generate_compose first."
    return 1
  fi

  REPLICATION_HOST=$(grep -E '^REPLICATION_HOST=' .env | cut -d'=' -f2-)
  BASE_PORT=$(grep -E '^MONGO_PORT=' .env | cut -d'=' -f2-)
  ADMIN_USER=$(grep -E '^MONGO_INITDB_ROOT_USERNAME=' .env | cut -d'=' -f2-)
  ADMIN_PASS=$(grep -E '^MONGO_INITDB_ROOT_PASSWORD=' .env | cut -d'=' -f2-)

  NODE_COUNT=$(grep -oP '^  mongo\K[0-9]+' docker-compose.yml | wc -l)
  echo "Detected $NODE_COUNT nodes."

  if [[ "$NODE_COUNT" -le 0 ]]; then
    echo "No mongo nodes found in docker-compose.yml"
    return 1
  fi

  # 1) Start containers (no keyfile mode expected)
  echo "Bringing up containers (initial no-key mode)..."
  docker compose up -d

  # 2) Wait for each mongod ready (ping)
  echo "Waiting for mongod to be ready on each node..."
  for ((i=1; i<=NODE_COUNT; i++)); do
    NAME="mongo$i"
    PORT=$((BASE_PORT + i - 1))
    echo -n "Waiting $NAME (port $PORT) ... "
    if _wait_mongo_ready "$NAME" "$PORT" 120; then
      echo "ready"
    else
      echo "timeout waiting for $NAME"
      docker logs "$NAME" --tail 100
      return 1
    fi
  done

  # 3) Build replica members array using REPLICATION_HOST:port
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

  # 4) Initiate replica set on the first node
  MASTER="mongo1"
  echo "Initiating replica set on $MASTER ..."
  docker exec -i "$MASTER" mongosh --eval "rs.initiate({_id:'rs0', members:[ $MEMBERS ]})" || true

  # Wait until replica set has PRIMARY
  echo "Waiting for PRIMARY..."
  local start now
  start=$(date +%s)
  while true; do
    # check without auth since auth not yet enabled
    if docker exec -i "$MASTER" mongosh --quiet --eval "rs.isMaster().ismaster" 2>/dev/null | grep -q "true"; then
      echo "PRIMARY elected."
      break
    fi
    now=$(date +%s)
    if (( now - start > 120 )); then
      echo "Timeout waiting for PRIMARY. Showing rs.status():"
      docker exec -i "$MASTER" mongosh --eval "printjson(rs.status())"
      return 1
    fi
    sleep 2
  done

  # 5) Create admin/root user (if not exists) - do this BEFORE enabling keyfile/auth
  echo "Creating admin user '$ADMIN_USER' on admin DB (if not present)..."
  # Create user only if not exists
  docker exec -i "$MASTER" mongosh --quiet --eval "
    const u = '$ADMIN_USER';
    const p = '$ADMIN_PASS';
    const exists = db.getSiblingDB('admin').getUser(u);
    if (!exists) {
      db.getSiblingDB('admin').createUser({user:u, pwd:p, roles:[{role:'root',db:'admin'}]});
      print('admin user created');
    } else {
      print('admin user already exists');
    }
  "

  # 6) Generate keyfile on host (if not present)
  mkdir -p keyfile
  if [[ ! -f keyfile/mongo.key ]]; then
    echo "Generating keyfile at keyfile/mongo.key ..."
    # 756 bytes base64 is standard recommendation, we use 1024 bytes to be safe
    openssl rand -base64 756 > keyfile/mongo.key
    chmod 400 keyfile/mongo.key
    echo "Keyfile generated with 400 perms."
  else
    echo "keyfile/mongo.key already exists - keeping it."
    chmod 400 keyfile/mongo.key
  fi

  # 7) Rewrite docker-compose.yml to add keyfile (use the helper if provided)
  if type enable_keyfile_compose >/dev/null 2>&1; then
    echo "Rewriting docker-compose.yml to enable keyfile..."
    enable_keyfile_compose
  else
    echo "enable_keyfile_compose function not found - aborting."
    return 1
  fi

  # 8) Restart containers so they pick up keyFile (this will enable internal auth)
  echo "Restarting containers to enable keyfile + authentication..."
  docker compose down
  docker compose up -d

  # 9) Wait for nodes to come back and for replica to be healthy (authenticate as admin)
  echo "Waiting for nodes to come back with authentication..."
  for ((i=1; i<=NODE_COUNT; i++)); do
    NAME="mongo$i"
    echo -n "Waiting $NAME ... "
    # After enabling keyfile, mongosh requires auth; to check readiness we run a ping with creds
    local ok=0
    for attempt in {1..40}; do
      if docker exec -i "$NAME" mongosh -u "$ADMIN_USER" -p "$ADMIN_PASS" --authenticationDatabase admin --quiet --eval 'db.adminCommand({ping:1})' >/dev/null 2>&1; then
        ok=1
        echo "ready"
        break
      fi
      sleep 2
    done
    if [[ $ok -ne 1 ]]; then
      echo "timeout waiting for $NAME (auth ping failed)"
      docker logs "$NAME" --tail 100
      return 1
    fi
  done

  # 10) Finally verify replica set status with auth
  echo "Verifying replica set status (authenticated)..."
  docker exec -i "$MASTER" mongosh -u "$ADMIN_USER" -p "$ADMIN_PASS" --authenticationDatabase admin --quiet --eval 'printjson(rs.status())'

  echo "✅ Replica set initialized, keyfile enabled, admin user in place."
}
