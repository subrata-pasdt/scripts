#!/bin/bash

validate_ip() {
  local ip=$1
  local stat=1
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
    [[ $o1 -le 255 && $o2 -le 255 && $o3 -le 255 && $o4 -le 255 ]]
    stat=$?
  fi
  return $stat
}

validate_port() {
  PORT=$1
  if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then return 1; fi
  if [[ "$PORT" -lt 1024 || "$PORT" -gt 65535 ]]; then return 1; fi

  if ss -tuln | grep -q ":$PORT "; then
    return 2
  fi

  return 0
}

generate_env() {

  DETECTED_IP=$(ip route get 1 | grep -oP 'src \K[\d.]+')
  echo "Auto-detected host IP: $DETECTED_IP"

  echo -n "Replication host / IP ($DETECTED_IP)? "
  read HOST_IP

  if [[ -z "$HOST_IP" ]]; then
    HOST_IP="$DETECTED_IP"
  else
    until validate_ip "$HOST_IP"; do
      echo "❌ Invalid IP. Try again."
      echo -n "Replication host / IP ($DETECTED_IP)? "
      read HOST_IP
      [[ -z "$HOST_IP" ]] && HOST_IP="$DETECTED_IP" && break
    done
  fi

  DEFAULT_PORT=27017
  echo -n "Base MongoDB port ($DEFAULT_PORT)? "
  read BASE_PORT

  [[ -z "$BASE_PORT" ]] && BASE_PORT="$DEFAULT_PORT"

  while true; do
    validate_port "$BASE_PORT"
    status=$?

    if [[ $status -eq 0 ]]; then break; fi

    if [[ $status -eq 2 ]]; then
      echo "❌ Port already in use."
    else
      echo "❌ Invalid port."
    fi

    echo -n "Base MongoDB port ($DEFAULT_PORT)? "
    read BASE_PORT
    [[ -z "$BASE_PORT" ]] && BASE_PORT="$DEFAULT_PORT"
  done

  echo -n "Admin username: "
  read ADMIN

  echo -n "Admin password: "
  read PASS

cat <<EOF > .env
MONGO_INITDB_ROOT_USERNAME=$ADMIN
MONGO_INITDB_ROOT_PASSWORD=$PASS

REPLICATION_HOST=$HOST_IP
MONGO_PORT=$BASE_PORT
EOF

  echo ".env created successfully."
}
