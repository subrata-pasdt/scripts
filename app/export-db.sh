#!/bin/bash
source <(curl -s https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

if [ -z "$1" ]; then
  echo "Usage: $0 <config_file>"
  exit 1
fi

CONFIG_FILE="$1"
MAIL_SCRIPT_URL="https://raw.githubusercontent.com/subrata-pasdt/scripts/refs/heads/main/library/mailjet-email.sh"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file '$CONFIG_FILE' not found!"
  cat > backup_config.cfg <<EOF
# Mongo Backup Script Configuration

MONGO_CONTAINER="your_mongo_container_name"
BACKUP_DIR="/tmp/mongodump_backups"
S3_BUCKET="your-s3-bucket-name"

# MongoDB connection details
MONGO_USERNAME="your_mongo_username"
MONGO_PASSWORD="your_mongo_password"
MONGO_DBNAME="your_database_name"      # Leave empty for all databases
MONGO_PORT="27017"

# Mailjet API credentials
MAILJET_API_KEY="your_mailjet_api_key"
MAILJET_API_SECRET="your_mailjet_api_secret"
FROM_EMAIL="from@example.com"
TO_EMAIL="to@example.com"
EOF
  exit 1
fi

source "$CONFIG_FILE"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="mongo_backup_$TIMESTAMP"
HOST_BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
ZIP_FILE="$BACKUP_NAME.zip"

mkdir -p "$BACKUP_DIR"

echo "Starting MongoDB dump from container: $MONGO_CONTAINER"

MONGO_AUTH=""
if [ -n "$MONGO_USERNAME" ] && [ -n "$MONGO_PASSWORD" ]; then
  MONGO_AUTH="--username $MONGO_USERNAME --password $MONGO_PASSWORD --authenticationDatabase admin"
fi

MONGO_DB=""
if [ -n "$MONGO_DBNAME" ]; then
  MONGO_DB="--db $MONGO_DBNAME"
fi

docker exec "$MONGO_CONTAINER" bash -c \
"mongodump $MONGO_AUTH $MONGO_DB --host localhost --port $MONGO_PORT --out /backup/$BACKUP_NAME"

if [ $? -ne 0 ]; then
  echo "mongodump failed"
  exit 1
fi

docker cp "$MONGO_CONTAINER:/backup/$BACKUP_NAME" "$HOST_BACKUP_PATH"

cd "$BACKUP_DIR"
zip -r "$ZIP_FILE" "$BACKUP_NAME"

aws s3 cp "$ZIP_FILE" "s3://$S3_BUCKET/"

if [ $? -ne 0 ]; then
  echo "S3 upload failed"
  exit 1
fi

echo "Calling mail script..."

curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
  --mailjet_api_key "$MAILJET_API_KEY" \
  --mailjet_api_secret "$MAILJET_API_SECRET" \
  --from_email "$FROM_EMAIL" \
  --to_email "$TO_EMAIL" \
  --subject "MongoDB Backup Completed - $TIMESTAMP" \
  --body "Backup $ZIP_FILE uploaded to S3 bucket $S3_BUCKET at $TIMESTAMP."

echo "Backup and email notification done."
