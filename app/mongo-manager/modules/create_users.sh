#!/bin/bash

create_users() {
  echo -n "JSON file path: "
  read FILE

  ADMIN=$(grep MONGO_INITDB_ROOT_USERNAME .env | cut -d'=' -f2)
  PASS=$(grep MONGO_INITDB_ROOT_PASSWORD .env | cut -d'=' -f2)

  for row in $(jq -c '.[]' "$FILE"); do
    USER=$(echo $row | jq -r '.user')
    PASSWORD=$(echo $row | jq -r '.pass')
    ROLES=$(echo $row | jq -c '.roles')

docker exec -i mongo1 mongosh -u "$ADMIN" -p "$PASS" --authenticationDatabase admin <<EOF
db = db.getSiblingDB('admin');
db.createUser({
  user: "$USER",
  pwd: "$PASSWORD",
  roles: $ROLES
});
EOF

    echo "User created: $USER"
  done
}
