#!/usr/bin/env bash
set -euo pipefail

# bootstrap.sh
# One-shot bootstrap for MongoDB replica set with auth + keyfile + users.
# 2-phase correct flow: start without keyfile -> rs.initiate -> create admin -> enable keyfile -> restart -> verify -> create users.

RETRY_SLEEP=2
DEFAULT_BASE_PORT=27017
REPO_HINT="(run from your git/raw URL or save locally)"

echo "
===========================================
 MongoDB ReplicaSet One-Shot Bootstrap
===========================================
"

### -------------------------
### Helpers
### -------------------------
validate_ip() {
  local ip=$1
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
    [[ $o1 -le 255 && $o2 -le 255 && $o3 -le 255 && $o4 -le 255 ]]
    return
  fi
  return 1
}

validate_port() {
  local p=$1
  if ! [[ "$p" =~ ^[0-9]+$ ]]; then return 1; fi
  if (( p < 1024 || p > 65535 )); then return 1; fi
  if ss -tuln | grep -q ":$p "; then return 2; fi
  return 0
}

generate_password() {
  tr -dc 'A-Za-z0-9!@#$%&*()-_=+' </dev/urandom | head -c 16
}

_wait_mongo_ping_noauth() {
  local container=$1
  local timeout=${2:-120}
  local start=$(date +%s)
  while true; do
    if docker exec -i "$container" mongosh --quiet --eval 'db.adminCommand({ping:1})' >/dev/null 2>&1; then
      return 0
    fi
    if (( $(date +%s) - start > timeout )); then
      return 1
    fi
    sleep 2
  done
}

_wait_mongo_ping_auth() {
  local container=$1
  local user=$2
  local pass=$3
  local timeout=${4:-120}
  local start=$(date +%s)
  while true; do
    if docker exec -i "$container" mongosh -u "$user" -p "$pass" --authenticationDatabase admin --quiet --eval 'db.adminCommand({ping:1})' >/dev/null 2>&1; then
      return 0
    fi
    if (( $(date +%s) - start > timeout )); then
      return 1
    fi
    sleep 2
  done
}

# ensure we have docker/docker compose/jq installed (Docker CE)
install_deps() {
  echo "Checking and installing dependencies (Docker CE, docker-compose-plugin, jq) ..."

  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release

  # remove docker.io if present
  if dpkg -l 2>/dev/null | grep -q docker.io; then
    echo "Removing docker.io to install Docker CE..."
    sudo apt-get remove -y docker.io || true
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "Installing Docker CE from official repo..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker $USER
    echo ""
    echo "Docker CE installed. You may need to log out and log in again for docker group to apply."
    echo "If you were added to docker group, please re-run this script after re-login."
    exit 0
  else
    echo "✅ Docker CE already installed."
  fi

  # docker compose plugin
  if ! docker compose version >/dev/null 2>&1; then
    echo "Installing docker-compose-plugin..."
    sudo apt-get install -y docker-compose-plugin
  else
    echo "✅ Docker Compose plugin is installed."
  fi

  # jq
  if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq..."
    sudo apt-get install -y jq
  else
    echo "✅ jq found."
  fi

  echo "All dependencies satisfied."
}

# prompt for .env values and validate
generate_env_interactive() {
  echo ""
  echo "=== Create .env (admin credentials + replication host + base port) ==="

  # detect ip
  DETECTED_IP=$(ip route get 1 2>/dev/null | grep -oP 'src \K[\d.]+') || true
  DETECTED_IP=${DETECTED_IP:-127.0.0.1}
  while true; do
    read -rp "Replication host / IP ($DETECTED_IP)? " HOST_IP
    HOST_IP=${HOST_IP:-$DETECTED_IP}
    if validate_ip "$HOST_IP"; then break; fi
    echo "Invalid IP. Try again."
  done

  while true; do
    read -rp "Base MongoDB port ($DEFAULT_BASE_PORT)? " BASE_PORT
    BASE_PORT=${BASE_PORT:-$DEFAULT_BASE_PORT}
    validate_port "$BASE_PORT"
    status=$?
    if [[ $status -eq 0 ]]; then break; fi
    if [[ $status -eq 2 ]]; then
      echo "Port $BASE_PORT is already in use. Choose another."
    else
      echo "Invalid port. Must be 1024-65535."
    fi
  done

  read -rp "Admin username (default: admin): " ADMIN
  ADMIN=${ADMIN:-admin}
  while true; do
    read -rsp "Admin password (leave empty to auto-generate): " PASS
    echo ""
    if [[ -z "$PASS" ]]; then
      PASS=$(generate_password)
      echo "Generated admin password: $PASS"
      break
    fi
    # accept provided non-empty password
    break
  done

  cat > .env <<EOF
MONGO_INITDB_ROOT_USERNAME=$ADMIN
MONGO_INITDB_ROOT_PASSWORD=$PASS

REPLICATION_HOST=$HOST_IP
MONGO_PORT=$BASE_PORT
EOF

  echo ".env written ->"
  echo "  REPLICATION_HOST=$HOST_IP"
  echo "  MONGO_PORT=$BASE_PORT"
  echo "  ADMIN_USER=$ADMIN"
}

# generate stage1 compose (no keyfile)
generate_compose_stage1() {
  local REPLICAS=$1
  local BASE_PORT
  BASE_PORT=$(grep -E '^MONGO_PORT=' .env | cut -d'=' -f2-)
  [[ -z "$BASE_PORT" ]] && BASE_PORT=$DEFAULT_BASE_PORT

  mkdir -p data
  cat > docker-compose.yml <<EOF
version: "3.9"

services:
EOF

  for ((i=1; i<=REPLICAS; i++)); do
    local NAME="mongo${i}"
    local HOST_PORT=$((BASE_PORT + i - 1))
    mkdir -p "data/$NAME"
cat >> docker-compose.yml <<EOM
  $NAME:
    image: mongo:7
    container_name: $NAME
    restart: always
    env_file: .env
    command: >
      mongod --replSet rs0 --bind_ip_all --port ${BASE_PORT}
    ports:
      - "${HOST_PORT}:${BASE_PORT}"
    volumes:
      - ./data/$NAME:/data/db

EOM
  done

  echo "Stage-1 docker-compose.yml generated (no keyfile)."
}

# generate stage2 compose (with keyfile mount and wrapper)
generate_compose_stage2() {
  local REPLICAS=$1
  local BASE_PORT
  BASE_PORT=$(grep -E '^MONGO_PORT=' .env | cut -d'=' -f2-)
  [[ -z "$BASE_PORT" ]] && BASE_PORT=$DEFAULT_BASE_PORT

  cat > docker-compose.yml <<EOF
version: "3.9"

services:
EOF

  for ((i=1; i<=REPLICAS; i++)); do
    local NAME="mongo${i}"
    local HOST_PORT=$((BASE_PORT + i - 1))
cat >> docker-compose.yml <<EOM
  $NAME:
    image: mongo:7
    container_name: $NAME
    restart: always
    env_file: .env
    command: >
      bash -c "chown 999:999 /keyfile/mongo.key && chmod 400 /keyfile/mongo.key && exec mongod --replSet rs0 --bind_ip_all --port ${BASE_PORT} --keyFile /keyfile/mongo.key"
    privileged: true
    security_opt:
      - seccomp=unconfined
    ports:
      - "${HOST_PORT}:${BASE_PORT}"
    volumes:
      - ./data/$NAME:/data/db
      - ./keyfile:/keyfile

EOM
  done

  echo "Stage-2 docker-compose.yml generated (with keyfile)."
}

# create containers
create_containers() {
  echo "Bringing up containers..."
  docker compose up -d
  echo "Containers started."
}

# initialize replset (stage1): start without keyfile -> rs.initiate -> create admin user
bootstrap_stage1_init() {
  local REPLICAS=$1
  local BASE_PORT ADMIN_USER ADMIN_PASS REPLICATION_HOST
  REPLICATION_HOST=$(grep -E '^REPLICATION_HOST=' .env | cut -d'=' -f2-)
  BASE_PORT=$(grep -E '^MONGO_PORT=' .env | cut -d'=' -f2-)
  ADMIN_USER=$(grep -E '^MONGO_INITDB_ROOT_USERNAME=' .env | cut -d'=' -f2-)
  ADMIN_PASS=$(grep -E '^MONGO_INITDB_ROOT_PASSWORD=' .env | cut -d'=' -f2-)

  echo "Waiting for mongod on each node (unauthenticated) ..."
  for ((i=1;i<=REPLICAS;i++)); do
    local name="mongo${i}"
    echo -n " - waiting for $name ... "
    if _wait_mongo_ping_noauth "$name" 120; then
      echo "ready"
    else
      echo "FAILED (showing logs last 200 lines)"
      docker logs "$name" --tail 200
      return 1
    fi
  done

  # build member array using REPLICATION_HOST:port
  local MEMBERS=""
  for ((i=1;i<=REPLICAS;i++)); do
    local id=$((i-1))
    local port=$((BASE_PORT + i - 1))
    local host="${REPLICATION_HOST}:${port}"
    if (( i < REPLICAS )); then
      MEMBERS="${MEMBERS}{ _id: $id, host: '$host' },"
    else
      MEMBERS="${MEMBERS}{ _id: $id, host: '$host' }"
    fi
  done

  echo "Initiating replica set on mongo1 ..."
  if ! docker exec -i mongo1 mongosh --quiet --eval "rs.initiate({_id:'rs0', members: [ $MEMBERS ]})"; then
    echo "rs.initiate may have already been run; continuing."
  fi

  # wait for primary election (no auth)
  echo -n "Waiting for PRIMARY (unauthenticated check) ... "
  local start=$(date +%s)
  while true; do
    if docker exec -i mongo1 mongosh --quiet --eval "rs.isMaster().ismaster" 2>/dev/null | grep -q "true"; then
      echo "PRIMARY elected."
      break
    fi
    if (( $(date +%s) - start > 120 )); then
      echo "Timeout waiting for PRIMARY"
      docker exec -i mongo1 mongosh --eval "printjson(rs.status())"
      return 1
    fi
    sleep 2
  done

  # create admin user (on admin db) if not present
  echo "Creating admin user '${ADMIN_USER}' if not present..."
  docker exec -i mongo1 mongosh --quiet --eval "
    const u = '${ADMIN_USER}';
    const p = '${ADMIN_PASS}';
    const db = db.getSiblingDB('admin');
    if (!db.getUser(u)) {
      db.createUser({ user: u, pwd: p, roles: [ { role: 'root', db: 'admin' } ] });
      print('admin user created');
    } else {
      print('admin user already exists');
    }
  "
  echo "Stage-1 complete: replset initiated and admin created."
}

# produce secure keyfile on host
generate_keyfile() {
  mkdir -p keyfile
  if [[ -f keyfile/mongo.key ]]; then
    echo "Keyfile already exists at keyfile/mongo.key (will reuse)"
    chmod 400 keyfile/mongo.key
    return
  fi
  echo "Generating keyfile at keyfile/mongo.key ..."
  openssl rand -base64 756 > keyfile/mongo.key
  chmod 400 keyfile/mongo.key
  echo "Keyfile created (mode 400)."
}

# restart with stage2 compose (keyfile/auth)
restart_with_keyfile() {
  echo "Stopping containers..."
  docker compose down
  echo "Bringing up containers with keyfile/auth..."
  docker compose up -d
}

# wait for auth-enabled nodes to respond
wait_for_auth_nodes() {
  local REPLICAS=$1
  local ADMIN_USER ADMIN_PASS
  ADMIN_USER=$(grep -E '^MONGO_INITDB_ROOT_USERNAME=' .env | cut -d'=' -f2-)
  ADMIN_PASS=$(grep -E '^MONGO_INITDB_ROOT_PASSWORD=' .env | cut -d'=' -f2-)

  echo "Waiting for authenticated mongod on each node..."
  for ((i=1;i<=REPLICAS;i++)); do
    local name="mongo${i}"
    echo -n " - waiting for $name ... "
    if _wait_mongo_ping_auth "$name" "$ADMIN_USER" "$ADMIN_PASS" 120; then
      echo "ready"
    else
      echo "FAILED (showing logs)"
      docker logs "$name" --tail 200
      return 1
    fi
  done

  # verify replica status with auth
  echo "Verifying replica set status (authenticated) ..."
  docker exec -i mongo1 mongosh -u "$ADMIN_USER" -p "$ADMIN_PASS" --authenticationDatabase admin --quiet --eval "printjson(rs.status())"
}

# create users from users.json, support pass:auto/null/"" → auto-gen and write back
create_users_from_json() {
  local FILE=${1:-users.json}
  if [[ ! -f "$FILE" ]]; then
    echo "users file '$FILE' not found — writing demo and exiting."
    cat > "$FILE" <<EOF
[
  {
    "user": "demo-user",
    "pass": "auto",
    "roles": [
      { "role": "readWrite", "db": "testdb" }
    ]
  }
]
EOF
    echo "Demo '$FILE' created. Edit it and run Create Users separately."
    return 0
  fi

  # validate json
  if ! jq empty "$FILE" 2>/dev/null; then
    echo "Invalid JSON in $FILE"
    return 1
  fi

  local ADMIN_USER ADMIN_PASS
  ADMIN_USER=$(grep -E '^MONGO_INITDB_ROOT_USERNAME=' .env | cut -d'=' -f2-)
  ADMIN_PASS=$(grep -E '^MONGO_INITDB_ROOT_PASSWORD=' .env | cut -d'=' -f2-)

  local updated="[]"
  updated=$(jq -c '.[]' "$FILE" | while read -r row; do
    u=$(echo "$row" | jq -r '.user')
    rawp=$(echo "$row" | jq -r '.pass // "auto"')
    roles=$(echo "$row" | jq -c '.roles')
    if [[ -z "$rawp" || "$rawp" == "null" || "$rawp" == "auto" ]]; then
      p=$(generate_password)
      echo "Generated password for $u : $p"
    else
      p="$rawp"
    fi

    # create in mongodb
    docker exec -i mongo1 mongosh -u "$ADMIN_USER" -p "$ADMIN_PASS" --authenticationDatabase admin <<MONGO
db = db.getSiblingDB('admin');
db.createUser({ user: "$u", pwd: "$p", roles: $roles });
MONGO

    # output updated json object for later rewriting
    echo "{\"user\": \"$u\", \"pass\": \"$p\", \"roles\": $roles}"
  done | jq -s '.')

  # write back updated file
  echo "$updated" | jq '.' > "$FILE"
  echo "Users created and $FILE updated with generated passwords."
}

### -------------------------
### Main bootstrap flow
### -------------------------
main() {
  install_deps

  # env file
  if [[ ! -f .env ]]; then
    generate_env_interactive
  else
    echo ".env exists. Validating..."
    # quick validation
    if ! (grep -q '^MONGO_INITDB_ROOT_USERNAME=' .env && grep -q '^MONGO_INITDB_ROOT_PASSWORD=' .env && grep -q '^REPLICATION_HOST=' .env && grep -q '^MONGO_PORT=' .env); then
      echo ".env invalid or incomplete. Recreating."
      generate_env_interactive
    else
      echo ".env looks ok."
    fi
  fi

  read -rp "How many replica nodes do you want (default 3)? " REPLICAS
  REPLICAS=${REPLICAS:-3}
  if ! [[ "$REPLICAS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid replicas number; using 3."
    REPLICAS=3
  fi

  echo ""
  echo "----------------- PHASE 1: Create stage-1 compose & start (no auth keyfile) -----------------"
  generate_compose_stage1 "$REPLICAS"
  create_containers

  echo ""
  echo "Running replica-set initiation and admin creation..."
  bootstrap_stage1_init "$REPLICAS"

  echo ""
  echo "----------------- PHASE 2: Generate keyfile, rewrite compose & restart with auth -----------------"
  generate_keyfile
  generate_compose_stage2 "$REPLICAS"

  echo "Restarting containers with keyfile/auth..."
  restart_with_keyfile

  echo ""
  echo "Waiting for nodes with authentication to come online..."
  wait_for_auth_nodes "$REPLICAS"

  echo ""
  echo "Bootstrap complete ✅"
  echo ""
  echo "Now checking users.json to create app users (if any)."
  if [[ -f users.json ]]; then
    echo "users.json exists — creating users now..."
    create_users_from_json "users.json"
  else
    echo "users.json not found — creating demo users.json and exiting. Edit it and run Create Users option later."
    create_users_from_json "users.json"
  fi

  echo ""
  echo "All done. Connection URL (example):"
  ADMIN_USER=$(grep -E '^MONGO_INITDB_ROOT_USERNAME=' .env | cut -d'=' -f2-)
  ADMIN_PASS=$(grep -E '^MONGO_INITDB_ROOT_PASSWORD=' .env | cut -d'=' -f2-)
  REPL_HOST=$(grep -E '^REPLICATION_HOST=' .env | cut -d'=' -f2-)
  BASE_PORT=$(grep -E '^MONGO_PORT=' .env | cut -d'=' -f2-)
  NODES=()
  for ((i=1;i<=REPLICAS;i++)); do
    p=$((BASE_PORT + i - 1))
    NODES+=("${REPL_HOST}:${p}")
  done
  IFS=','; HOSTS_STR="${NODES[*]}"; unset IFS
  echo "mongodb://${ADMIN_USER}:${ADMIN_PASS}@${HOSTS_STR}/?replicaSet=rs0"

  echo ""
  echo "If you were added to 'docker' group during install, log out and log in again before rerunning docker commands."
}

main "$@"
