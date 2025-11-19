#!/bin/bash

# Usage: ./backup_mongo_docker.sh [config_file]
# If no config_file provided, creates demo config and exits.

if [ -z "$1" ]; then
  DEMO_CONFIG="backup_config.cfg"
  echo "No config file provided. Creating demo config file '$DEMO_CONFIG' in current directory."
  cat > "$DEMO_CONFIG" <<EOF
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
  echo "Demo config file created. Please edit it with your actual values and rerun the script."
  exit 0
fi

CONFIG_FILE="$1"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file '$CONFIG_FILE' not found!"
  exit 1
fi

# Load config
source "$CONFIG_FILE"

# Validate required variables
for var in MONGO_CONTAINER BACKUP_DIR S3_BUCKET MAILJET_API_KEY MAILJET_API_SECRET FROM_EMAIL TO_EMAIL; do
  if [ -z "${!var}" ]; then
    echo "Error: $var is not set in config file."
    exit 1
  fi
done

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="mongo_backup_$TIMESTAMP"
HOST_BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
ZIP_FILE="$BACKUP_NAME.zip"

mkdir -p "$BACKUP_DIR"

echo "Starting MongoDB dump from container: $MONGO_CONTAINER"

# Prepare mongodump auth options
MONGO_AUTH=""
if [ -n "$MONGO_USERNAME" ] && [ -n "$MONGO_PASSWORD" ]; then
  MONGO_AUTH="--username $MONGO_USERNAME --password $MONGO_PASSWORD --authenticationDatabase admin"
fi

MONGO_DB=""
if [ -n "$MONGO_DBNAME" ]; then
  MONGO_DB="--db $MONGO_DBNAME"
fi

# Run mongodump in docker container
docker exec "$MONGO_CONTAINER" bash -c \
"mongodump $MONGO_AUTH $MONGO_DB --host localhost --port $MONGO_PORT --out /backup/$BACKUP_NAME"

if [ $? -ne 0 ]; then
  echo "Error: mongodump failed in container $MONGO_CONTAINER"
  exit 1
fi

echo "Copying backup from container to host..."

docker cp "$MONGO_CONTAINER:/backup/$BACKUP_NAME" "$HOST_BACKUP_PATH"

if [ $? -ne 0 ]; then
  echo "Error: failed to copy backup from container"
  exit 1
fi

echo "Compressing backup..."

cd "$BACKUP_DIR"
zip -r "$ZIP_FILE" "$BACKUP_NAME"

if [ $? -ne 0 ]; then
  echo "Error: zip compression failed"
  exit 1
fi

echo "Uploading backup to S3 bucket: $S3_BUCKET"

aws s3 cp "$ZIP_FILE" "s3://$S3_BUCKET/"

if [ $? -ne 0 ]; then
  echo "Error uploading backup to S3"
  exit 1
fi

EMAIL_SUBJECT="MongoDB Backup Completed - $TIMESTAMP"
EMAIL_BODY="MongoDB backup completed successfully on $TIMESTAMP.

Backup file: $ZIP_FILE
Uploaded to S3 bucket: $S3_BUCKET

Regards,
Backup Script"

# echo "Sending email notification..."

EMAIL_BODY_ESCAPED=$(jq -Rn --arg txt "$EMAIL_BODY" '$txt')

read -r -d '' MAILJET_PAYLOAD <<EOF
{
  "Messages": [
    {
      "From": {
        "Email": "$FROM_EMAIL",
        "Name": "Backup Script"
      },
      "To": [
        {
          "Email": "$TO_EMAIL",
          "Name": "Recipient"
        }
      ],
      "Subject": "$EMAIL_SUBJECT",
      "TextPart": $EMAIL_BODY_ESCAPED
    }
  ]
}
EOF

curl -s -X POST https://api.mailjet.com/v3.1/send \
-u "$MAILJET_API_KEY:$MAILJET_API_SECRET" \
-H "Content-Type: application/json" \
-d "$MAILJET_PAYLOAD"


echo "Backup, upload, and email notification completed successfully."