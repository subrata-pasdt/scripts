#!/bin/bash


#     ███████████       █████████       █████████     ██████████      ███████████
#    ░░███░░░░░███     ███░░░░░███     ███░░░░░███   ░░███░░░░███    ░█░░░███░░░█
#     ░███    ░███    ░███    ░███    ░███    ░░░     ░███   ░░███   ░   ░███  ░ 
#     ░██████████     ░███████████    ░░█████████     ░███    ░███       ░███    
#     ░███░░░░░░      ░███░░░░░███     ░░░░░░░░███    ░███    ░███       ░███    
#     ░███            ░███    ░███     ███    ░███    ░███    ███        ░███    
#     █████           █████   █████   ░░█████████     ██████████         █████   
#    ░░░░░           ░░░░░   ░░░░░     ░░░░░░░░░     ░░░░░░░░░░         ░░░░░    
#    Subrata Kumar De 
#    07/11/2025



source <(curl -s https://raw.githubusercontent.com/subrata-pasdt/scripts/main/app/mongo-docker/helper.sh)
CONFIG_FILE="$1"
MAIL_SCRIPT_URL="https://raw.githubusercontent.com/subrata-pasdt/scripts/refs/heads/main/library/mailjet-email.sh"

if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 <config_file>"
  exit 1
fi

# Generate demo config if missing
generate_config_file(){
  echo "Generating config file : $CONFIG_FILE"
  echo "Please edit $CONFIG_FILE and re-run this script"
  
  cat > $CONFIG_FILE <<EOF
# Mongo Import Script Configuration

MONGO_CONTAINER="your_mongo_container_name"
IMPORT_DIR="/tmp/mongo_import"

S3_BUCKET="your-s3-bucket-name"
BACKUP_ZIP_NAME="backup.zip"


MONGO_USERNAME="your_mongo_username"
MONGO_PASSWORD="your_mongo_password"
MONGO_AUTHDB="admin"
MONGO_PORT="27017"
MONGO_DBNAME="your_database_name"

MAILJET_API_KEY="your_mailjet_api_key"
MAILJET_API_SECRET="your_mailjet_api_secret"
FROM_EMAIL="from@example.com"
TO_EMAIL="to@example.com"
CC_EMAILS=""
BCC_EMAILS=""
EOF
}

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file '$CONFIG_FILE' not found!"
  generate_config_file
  exit 1
fi

source "$CONFIG_FILE"


# Validate required config vars
required_vars=(MAILJET_API_KEY MAILJET_API_SECRET FROM_EMAIL TO_EMAIL MONGO_CONTAINER IMPORT_DIR S3_BUCKET MONGO_USERNAME MONGO_PASSWORD MONGO_DBNAME MONGO_PORT MONGO_AUTHDB)

missing_vars=()
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    missing_vars+=("$var")
  fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
  echo "Error: Missing config variables: ${missing_vars[*]}"
  curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
    --mailjet_api_key "$MAILJET_API_KEY" \
    --mailjet_api_secret "$MAILJET_API_SECRET" \
    --from_email "$FROM_EMAIL" \
    --to_email "$TO_EMAIL" \
    --cc "$CC_EMAILS" \
    --bcc "$BCC_EMAILS" \
    --subject "⛔ MongoDB Import Configuration Error" \
    --body "Missing config vars: ${missing_vars[*]}"
  exit 1
fi

# Validate emails
validate_email "$FROM_EMAIL" || exit 1

IFS=',' read -ra TO_EMAILS_ARRAY <<< "$TO_EMAIL"
for to_email in "${TO_EMAILS_ARRAY[@]}"; do
  to_email=$(echo "$to_email" | xargs)
  validate_email "$to_email" || exit 1
done

if [ -n "$CC_EMAILS" ]; then
  IFS=',' read -ra CC_EMAILS_ARRAY <<< "$CC_EMAILS"
  for cc_email in "${CC_EMAILS_ARRAY[@]}"; do
    cc_email=$(echo "$cc_email" | xargs)
    validate_email "$cc_email" || exit 1
  done
fi

if [ -n "$BCC_EMAILS" ]; then
  IFS=',' read -ra BCC_EMAILS_ARRAY <<< "$BCC_EMAILS"
  for bcc_email in "${BCC_EMAILS_ARRAY[@]}"; do
    bcc_email=$(echo "$bcc_email" | xargs)
    validate_email "$bcc_email" || exit 1
  done
fi

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

mkdir -p "$IMPORT_DIR"

# Download backup zip from S3
echo "Downloading $BACKUP_ZIP_NAME from s3://$S3_BUCKET"
aws s3 cp "s3://$S3_BUCKET/$BACKUP_ZIP_NAME" "$IMPORT_DIR/"

if [ $? -ne 0 ]; then
  echo "Failed to download $BACKUP_ZIP_NAME from S3"
  curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
    --mailjet_api_key "$MAILJET_API_KEY" \
    --mailjet_api_secret "$MAILJET_API_SECRET" \
    --from_email "$FROM_EMAIL" \
    --to_email "$TO_EMAIL" \
    --cc "$CC_EMAILS" \
    --bcc "$BCC_EMAILS" \
    --subject "⛔ MongoDB Import Failed - Download Error" \
    --body "Failed to download backup file $BACKUP_ZIP_NAME from S3 bucket $S3_BUCKET at $TIMESTAMP."
  exit 1
fi

# Unzip the backup
echo "Unzipping $BACKUP_ZIP_NAME"
unzip -o "$IMPORT_DIR/$BACKUP_ZIP_NAME" -d "$IMPORT_DIR"

if [ $? -ne 0 ]; then
  echo "Error unzipping $BACKUP_ZIP_NAME"
  curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
    --mailjet_api_key "$MAILJET_API_KEY" \
    --mailjet_api_secret "$MAILJET_API_SECRET" \
    --from_email "$FROM_EMAIL" \
    --to_email "$TO_EMAIL" \
    --cc "$CC_EMAILS" \
    --bcc "$BCC_EMAILS" \
    --subject "⛔ MongoDB Import Failed - Unzip Error" \
    --body "Failed to unzip backup $BACKUP_ZIP_NAME at $TIMESTAMP."
  exit 1
fi

# Copy unzipped backup folder to container
BACKUP_FOLDER_NAME="${BACKUP_ZIP_NAME%.zip}"

echo "Copying backup folder $BACKUP_FOLDER_NAME to container $MONGO_CONTAINER:/import/"
docker cp "$IMPORT_DIR/$BACKUP_FOLDER_NAME" "$MONGO_CONTAINER:/import/$BACKUP_FOLDER_NAME"

if [ $? -ne 0 ]; then
  echo "Failed to copy backup folder into container"
  curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
    --mailjet_api_key "$MAILJET_API_KEY" \
    --mailjet_api_secret "$MAILJET_API_SECRET" \
    --from_email "$FROM_EMAIL" \
    --to_email "$TO_EMAIL" \
    --cc "$CC_EMAILS" \
    --bcc "$BCC_EMAILS" \
    --subject "⛔ MongoDB Import Failed - Copy to Container Error" \
    --body "Failed to copy backup folder into container $MONGO_CONTAINER at $TIMESTAMP."
  exit 1
fi

# Build mongorestore command with auth
MONGO_AUTH=""
if [ -n "$MONGO_USERNAME" ] && [ -n "$MONGO_PASSWORD" ]; then
  MONGO_AUTH="--username $MONGO_USERNAME --password $MONGO_PASSWORD --authenticationDatabase $MONGO_AUTHDB"
fi

MONGO_DB_ARG=""
if [ -n "$MONGO_DBNAME" ]; then
  MONGO_DB_ARG="--db $MONGO_DBNAME"
fi

# Run mongorestore inside container
echo "Running mongorestore inside container..."

docker exec "$MONGO_CONTAINER" bash -c \
"mongorestore $MONGO_AUTH --host localhost --port $MONGO_PORT $MONGO_DB_ARG /import/$BACKUP_FOLDER_NAME"

if [ $? -ne 0 ]; then
  echo "mongorestore failed"
  curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
    --mailjet_api_key "$MAILJET_API_KEY" \
    --mailjet_api_secret "$MAILJET_API_SECRET" \
    --from_email "$FROM_EMAIL" \
    --to_email "$TO_EMAIL" \
    --cc "$CC_EMAILS" \
    --bcc "$BCC_EMAILS" \
    --subject "⛔ MongoDB Import Failed - mongorestore Error" \
    --body "mongorestore command failed inside container at $TIMESTAMP."
  exit 1
fi

# Cleanup: remove import folder from container and local files
docker exec "$MONGO_CONTAINER" rm -rf "/import/$BACKUP_FOLDER_NAME"
rm -rf "$IMPORT_DIR/$BACKUP_FOLDER_NAME"
rm -f "$IMPORT_DIR/$BACKUP_ZIP_NAME"

# Success notification
curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
  --mailjet_api_key "$MAILJET_API_KEY" \
  --mailjet_api_secret "$MAILJET_API_SECRET" \
  --from_email "$FROM_EMAIL" \
  --to_email "$TO_EMAIL" \
  --cc "$CC_EMAILS" \
  --bcc "$BCC_EMAILS" \
  --subject "✅ MongoDB Import Completed for $MONGO_DBNAME - $TIMESTAMP" \
  --body "Backup $BACKUP_ZIP_NAME imported successfully into MongoDB on container $MONGO_CONTAINER at $TIMESTAMP."

echo "Import process completed successfully."
