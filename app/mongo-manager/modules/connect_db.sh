#!/bash

connect_db() {

  ADMIN=$(grep MONGO_INITDB_ROOT_USERNAME .env | cut -d'=' -f2)
  PASS=$(grep MONGO_INITDB_ROOT_PASSWORD .env | cut -d'=' -f2)

  docker exec -i mongo1 mongosh -u "$ADMIN" -p "$PASS" --authenticationDatabase admin --quiet <<EOF > dblist
show dbs;
EOF

  nl -ba dblist
  echo -n "Choose DB #: "
  read DB_NO

  DB_NAME=$(sed "${DB_NO}q;d" dblist | awk '{print $1}')

  docker exec -it mongo1 mongosh "$DB_NAME" -u "$ADMIN" -p "$PASS" --authenticationDatabase admin
}
