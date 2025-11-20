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
source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

source <(curl -s https://raw.githubusercontent.com/subrata-pasdt/scripts/main/app/mongo-docker/helper.sh)



CONFIG_FILE="$1"
MAIL_SCRIPT_URL="https://raw.githubusercontent.com/subrata-pasdt/scripts/refs/heads/main/library/mailjet-email.sh"

if [ -z "$CONFIG_FILE" ]; then
  show_colored_message info "Usage: $0 <config_file>"
  CONFIG_FILE="export_config.cfg"
fi


generate_config_file(){
  echo "Generating config file : $CONFIG_FILE"
  echo "Please edit $CONFIG_FILE and re run this script"
  
  cat > $CONFIG_FILE <<EOF
# Mongo Backup Script Configuration

MONGO_CONTAINER="your_mongo_container_name"
BACKUP_DIR="/tmp/mongodump_backups"

UPLOAD_TO_S3=false # make it true to upload to s3
S3_BUCKET="your-s3-bucket-name"

# MongoDB connection details
MONGO_USERNAME="your_mongo_username"
MONGO_PASSWORD="your_mongo_password"
MONGO_DBNAME="your_database_name"
MONGO_AUTHDB="admin"
MONGO_PORT="27017"

NOTIFICATION_EMAIL=true # make it true to send email
# Mailjet API credentials
MAILJET_API_KEY="your_mailjet_api_key"
MAILJET_API_SECRET="your_mailjet_api_secret"
FROM_EMAIL="from@example.com"
TO_EMAIL="to@example.com"
CC_EMAILS="cc1@example.com,cc2@example.com" # optional / can be empty
BCC_EMAILS="bcc1@example.com,bcc2@example.com" # optional / can be empty


CLEANUP=false # make it true to clean up after backup
EOF

}




if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file '$CONFIG_FILE' not found!"
  generate_config_file
  exit 1
fi

# Load config
source "$CONFIG_FILE"

# Required configs validation
required_vars=(UPLOAD_TO_S3 NOTIFICATION_EMAIL MAILJET_API_KEY MAILJET_API_SECRET FROM_EMAIL TO_EMAIL MONGO_CONTAINER BACKUP_DIR S3_BUCKET MONGO_USERNAME MONGO_PASSWORD MONGO_DBNAME MONGO_PORT MONGO_AUTHDB)

missing_vars=()
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    missing_vars+=("$var")
  fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
  if [ "${NOTIFICATION_EMAIL}" = "true" ]; then
    curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
      --mailjet_api_key "$MAILJET_API_KEY" \
      --mailjet_api_secret "$MAILJET_API_SECRET" \
      --from_email "$FROM_EMAIL" \
      --to_email "$TO_EMAIL" \
      --cc "$CC_EMAILS" \
      --bcc "$BCC_EMAILS" \
      --subject "⛔ Configuration Mismatched for Backup of $MONGO_DBNAME" \
      --body "Backup Configuration Mismatched with these missing variables : ${missing_vars[*]}"
  else
    echo "Backup Configuration Mismatched with these missing variables : ${missing_vars[*]}"
  fi
  exit 1
fi


if [ "${NOTIFICATION_EMAIL}" = "true" ]; then

  validate_email "$FROM_EMAIL" || exit 1

  # TO_EMAIL can be multiple emails comma separated
  IFS=',' read -ra TO_EMAILS_ARRAY <<< "$TO_EMAIL"
  for to_email in "${TO_EMAILS_ARRAY[@]}"; do
    to_email=$(echo "$to_email" | xargs)  # trim spaces
    validate_email "$to_email" || exit 1
  done

  # If CC or BCC provided, validate their emails as well (optional)
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
else
  show_colored_message info "NOTIFICATION_EMAIL is set to false. Skipping email notification."
fi

# echo "All required config variables are set and valid."


TIMESTAMP=$(date +%Y%m%d_%H%M%S)
EMAIL_TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
BACKUP_NAME="$MONGO_DBNAME-backup-$TIMESTAMP"
HOST_BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
ZIP_FILE="$BACKUP_NAME.zip"

mkdir -p "$BACKUP_DIR"

# echo "Starting MongoDB dump from container: $MONGO_CONTAINER"

MONGO_AUTH=""
if [ -n "$MONGO_USERNAME" ] && [ -n "$MONGO_PASSWORD" ]; then
  MONGO_AUTH="--username $MONGO_USERNAME --password $MONGO_PASSWORD --authenticationDatabase $MONGO_AUTHDB"
fi

MONGO_DB=""
if [ -n "$MONGO_DBNAME" ]; then
  MONGO_DB="--db $MONGO_DBNAME"
fi

docker exec "$MONGO_CONTAINER" bash -c \
"mongodump $MONGO_AUTH $MONGO_DB --host localhost --port $MONGO_PORT --out /backup/"

docker exec "$MONGO_CONTAINER" bash -c \
"mv /backup/$MONGO_DBNAME /backup/$BACKUP_NAME"

if [ $? -ne 0  ]; then
  if [ "${NOTIFICATION_EMAIL}" = "true" ]; then
    # echo "mongodump failed"
    curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
      --mailjet_api_key "$MAILJET_API_KEY" \
      --mailjet_api_secret "$MAILJET_API_SECRET" \
      --from_email "$FROM_EMAIL" \
      --to_email "$TO_EMAIL" \
      --cc "$CC_EMAILS" \
      --bcc "$BCC_EMAILS" \
      --subject "⛔ MongoDB Backup Failed for $MONGO_DBNAME - $EMAIL_TIMESTAMP" \
      --body "Failed to run mongodump on docker container at $EMAIL_TIMESTAMP."
  else
    show_colored_message error "mongodump failed"
  fi

  exit 1
fi



docker cp "$MONGO_CONTAINER:/backup/$BACKUP_NAME" "$HOST_BACKUP_PATH"


cd "$BACKUP_DIR"
zip -r "$ZIP_FILE" "$BACKUP_NAME"

if [ "${UPLOAD_TO_S3}" = "true"]; then
  aws s3 cp "$ZIP_FILE" "s3://$S3_BUCKET/"

  if [ $? -ne 0 ]; then
    if [ "${NOTIFICATION_EMAIL}" = "true" ]; then
      curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
        --mailjet_api_key "$MAILJET_API_KEY" \
        --mailjet_api_secret "$MAILJET_API_SECRET" \
        --from_email "$FROM_EMAIL" \
        --to_email "$TO_EMAIL" \
        --cc "$CC_EMAILS" \
        --bcc "$BCC_EMAILS" \
        --subject "⛔ MongoDB Backup Failed for $MONGO_DBNAME - $EMAIL_TIMESTAMP" \
        --body "Backup $ZIP_FILE unable to upload to S3 bucket $S3_BUCKET at $EMAIL_TIMESTAMP."
    else
      show_colored_message error "S3 upload failed"
    fi

    exit 1
  fi
else
  show_colored_message info "UPLOAD_TO_S3 is set to false. Skipping S3 upload."
fi

if [ "${CLEANUP}" = "true" ]; then
  # Delete the backup folder copied from container on host
  rm -rf "$HOST_BACKUP_PATH"
  # Delete the zipped backup file on host
  rm -f "$BACKUP_DIR/$ZIP_FILE"
fi


# Delete the backup folder inside the container
docker exec "$MONGO_CONTAINER" rm -rf "/backup/$BACKUP_NAME"

# echo "Calling mail script..."

if [ "${NOTIFICATION_EMAIL}" = "true" ]; then
  curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
    --mailjet_api_key "$MAILJET_API_KEY" \
    --mailjet_api_secret "$MAILJET_API_SECRET" \
    --from_email "$FROM_EMAIL" \
    --to_email "$TO_EMAIL" \
    --cc "$CC_EMAILS" \
    --bcc "$BCC_EMAILS" \
    --subject "✅ MongoDB Backup Completed for $MONGO_DBNAME - $EMAIL_TIMESTAMP" \
    --body "Backup $ZIP_FILE Completed and uploaded to S3 bucket $S3_BUCKET at $EMAIL_TIMESTAMP."
else
    show_colored_message success "✅ MongoDB Backup Completed for $MONGO_DBNAME - $EMAIL_TIMESTAMP"
fi