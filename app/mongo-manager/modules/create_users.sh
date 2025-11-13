#!/bin/bash

# ---------------------------------------------------------
# Function: Generate a random secure password
# ---------------------------------------------------------
generate_password() {
  # 16-character password, safe for MongoDB
  tr -dc 'A-Za-z0-9!@#$%^&*()-_=+' </dev/urandom | head -c 16
}


# ---------------------------------------------------------
# Create Users Entry Function
# ---------------------------------------------------------
create_users() {

  echo -n "Enter users JSON file path (default: users.json): "
  read FILE
  FILE=${FILE:-users.json}

  # -----------------------------------------------------
  # STEP 1 — If file doesn't exist, create demo and exit
  # -----------------------------------------------------
  if [[ ! -f "$FILE" ]]; then

    echo "⚠️ '$FILE' not found — generating demo users.json..."

cat <<EOF > "$FILE"
[
  {
    "user": "demo-user",
    "pass": "auto",
    "roles": [
      {
        "role": "readWrite",
        "db": "testdb"
      }
    ]
  }
]
EOF

    echo ""
    echo "📄 Demo '$FILE' created with auto-generated password enabled."
    echo "➡️ Edit the file & run Create Users again."
    echo "⛔ Exiting..."
    return
  fi


  # -----------------------------------------------------
  # STEP 2 — Validate JSON
  # -----------------------------------------------------
  if ! jq empty "$FILE" 2>/dev/null; then
    echo "❌ '$FILE' contains invalid JSON."
    return
  fi


  # -----------------------------------------------------
  # STEP 3 — Load Admin Credentials
  # -----------------------------------------------------
  ADMIN=$(grep MONGO_INITDB_ROOT_USERNAME .env | cut -d'=' -f2)
  PASS=$(grep MONGO_INITDB_ROOT_PASSWORD .env | cut -d'=' -f2)


  echo ""
  echo "🔍 Creating users from '$FILE'..."
  echo ""


  # -----------------------------------------------------
  # STEP 4 — Iterate Through Users
  # -----------------------------------------------------
  UPDATED_JSON="["

  FIRST=1
  for row in $(jq -c '.[]' "$FILE"); do

    USER=$(echo $row | jq -r '.user')

    RAW_PASS=$(echo $row | jq -r '.pass // "auto"')

    # Auto-generate if needed
    if [[ -z "$RAW_PASS" || "$RAW_PASS" == "null" || "$RAW_PASS" == "auto" ]]; then
      PASSWORD=$(generate_password)
      echo "🔐 Auto-generated password for user '$USER': $PASSWORD"
    else
      PASSWORD="$RAW_PASS"
    fi

    ROLES=$(echo $row | jq -c '.roles')

    # Create user in MongoDB
docker exec -i mongo1 mongosh -u "$ADMIN" -p "$PASS" --authenticationDatabase admin <<EOF
db = db.getSiblingDB('admin');
db.createUser({
  user: "$USER",
  pwd: "$PASSWORD",
  roles: $ROLES
});
EOF

    echo "✅ User created: $USER"

    # Rebuild updated JSON with real password included
    [[ $FIRST -eq 0 ]] && UPDATED_JSON+=","
    FIRST=0

    UPDATED_JSON+="$(jq -n \
        --arg u "$USER" \
        --arg p "$PASSWORD" \
        --argjson r "$ROLES" \
        '{user:$u, pass:$p, roles:$r}')"
  done

  UPDATED_JSON+="]"


  # -----------------------------------------------------
  # STEP 5 — Write updated file with generated passwords
  # -----------------------------------------------------
  echo "$UPDATED_JSON" | jq '.' > "$FILE"

  echo ""
  echo "📄 Updated '$FILE' saved with generated passwords."
  echo "🎉 All users created successfully."
}
