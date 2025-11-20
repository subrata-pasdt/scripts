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
  CONFIG_FILE="import_config.cfg"
fi








# Generate demo config if missing
# Generates a demo config file if not provided
# Config file is generated in the current directory and contains default values
# User needs to edit the config file and re-run this script for actual usage
generate_config_file(){
  show_colored_message info "Generating config file : $CONFIG_FILE"
  show_colored_message info "Please edit $CONFIG_FILE and re-run this script"
  
  cat > $CONFIG_FILE <<EOF
# Mongo Import Script Configuration

MONGO_CONTAINERS="mongo1,mongo2,mongo3"
IMPORT_DIR="/tmp/mongo_import"

DOWNLOAD_FROM_S3=false # make it true to download from s3
S3_BUCKET="your-s3-bucket-name"
BACKUP_ZIP_NAME="backup.zip"




MONGO_USERNAME="your_mongo_username"
MONGO_PASSWORD="your_mongo_password"
MONGO_AUTHDB="admin"
MONGO_PORT="27017"
MONGO_DBNAME="your_database_name"

NOTIFICATION_EMAIL=false # make it true to send email
MAILJET_API_KEY="your_mailjet_api_key"
MAILJET_API_SECRET="your_mailjet_api_secret"
FROM_EMAIL="from@example.com"
TO_EMAIL="to@example.com"
CC_EMAILS=""
BCC_EMAILS=""

CLEANUP=false # make it true to clean up after import

EOF
}

if [ ! -f "$CONFIG_FILE" ]; then
  show_colored_message error "Config file '$CONFIG_FILE' not found!"
  generate_config_file
  exit 1
fi

source "$CONFIG_FILE"





# Validate required config vars
required_vars=(CLEANUP DOWNLOAD_FROM_S3 NOTIFICATION_EMAIL MAILJET_API_KEY MAILJET_API_SECRET FROM_EMAIL TO_EMAIL MONGO_CONTAINERS IMPORT_DIR S3_BUCKET MONGO_USERNAME MONGO_PASSWORD MONGO_DBNAME MONGO_PORT MONGO_AUTHDB)

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
      --subject "⛔ MongoDB Import Configuration Error" \
      --body "Missing config vars: ${missing_vars[*]}"
  else
    show_colored_message error "Error: Missing config variables: ${missing_vars[*]}"

  fi
  exit 1
fi



if [ "${NOTIFICATION_EMAIL}" = "true" ]; then
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
fi





# getting primary mongo container

IFS=',' read -ra MONGO_ARR <<< "$MONGODB_CONTAINERS"

echo ${MONGO_ARR[@]}

for host in "${MONGO_ARR[@]}"; do
    host=$(echo "$host" | xargs)
    echo "$host"
    # Run command using sh (Mongo image doesn't have bash)
    is_primary=$(docker exec "$host" sh -c 'mongosh --quiet --eval "rs.isMaster().ismaster"' 2>/dev/null)

    # Normalize output (remove spaces + newlines)
    is_primary=$(echo "$is_primary" | tr -d '[:space:]')

    if [ "$is_primary" = "true" ]; then
        show_colored_message success "Found PRIMARY container: $host"
        MONGODB_CONTAINER="$host"
        break
    else
        show_colored_message info "Container $host is not PRIMARY"
    fi
done

if [[ -z "$MONGODB_CONTAINER" ]]; then
    show_colored_message error "No PRIMARY container found."
    exit 1
fi





# MONGODB_CONTAINER=""
# IFS=',' read -ra MONGO_ARR <<< "$MONGODB_CONTAINERS"
# for host in "${MONGO_ARR[@]}"; do
#     host=$(echo "$host" | xargs) # trim
#     # Check if this container is PRIMARY
#     is_primary=$(docker exec "$host" bash -c 'mongosh --quiet --eval "rs.isMaster().ismaster"' 2>/dev/null)
#     if [ "$is_primary" = "true" ]; then
#         show_colored_message success "Found PRIMARY container: $host"
#         MONGODB_CONTAINER="$host"
#         break
#     else
#         show_colored_message info "Container $host is not PRIMARY"
#     fi
# done
# if [[ -z "$MONGODB_CONTAINER" ]]; then
#     show_colored_message error "No PRIMARY container found."
#     exit 1
# fi





TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

if [ ! -d "$IMPORT_DIR" ]; then
  mkdir -p "$IMPORT_DIR"
fi

if [ "${DOWNLOAD_FROM_S3}" = "true" ]; then
  # Download backup zip from S3
  show_colored_message info "Downloading $BACKUP_ZIP_NAME from s3://$S3_BUCKET"
  aws s3 cp "s3://$S3_BUCKET/$BACKUP_ZIP_NAME" "$IMPORT_DIR/"

  if [ $? -ne 0 ]; then
    if [ "${NOTIFICATION_EMAIL}" = "true" ]; then
      curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
        --mailjet_api_key "$MAILJET_API_KEY" \
        --mailjet_api_secret "$MAILJET_API_SECRET" \
        --from_email "$FROM_EMAIL" \
        --to_email "$TO_EMAIL" \
        --cc "$CC_EMAILS" \
        --bcc "$BCC_EMAILS" \
        --subject "⛔ MongoDB Import Failed - Download Error" \
        --body "Failed to download backup file $BACKUP_ZIP_NAME from S3 bucket $S3_BUCKET at $TIMESTAMP."
    else
      show_colored_message error "Error downloading backup file $BACKUP_ZIP_NAME from S3 bucket $S3_BUCKET at $TIMESTAMP."
    fi
    exit 1
  fi
else
  # Download backup zip from URL
  show_colored_message info "Downloading from S3 is disabled. Going with local file $BACKUP_ZIP_NAME"
  if [ ! -f "$IMPORT_DIR/$BACKUP_ZIP_NAME" ]; then
    if [ "${NOTIFICATION_EMAIL}" = "true" ]; then
      curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
        --mailjet_api_key "$MAILJET_API_KEY" \
        --mailjet_api_secret "$MAILJET_API_SECRET" \
        --from_email "$FROM_EMAIL" \
        --to_email "$TO_EMAIL" \
        --cc "$CC_EMAILS" \
        --bcc "$BCC_EMAILS" \
        --subject "⛔ MongoDB Import Failed - File Not Found" \
        --body "Backup file $BACKUP_ZIP_NAME not found in directory $IMPORT_DIR at $TIMESTAMP."
    else
      show_colored_message error "Backup file $BACKUP_ZIP_NAME not found in directory $IMPORT_DIR at $TIMESTAMP."
    fi
    exit 1
  fi
fi




# Unzip the backup
show_colored_message info "Unzipping $BACKUP_ZIP_NAME"
unzip -o "$IMPORT_DIR/$BACKUP_ZIP_NAME" -d "$IMPORT_DIR"


if [ $? -ne 0 ]; then
  if [ "${NOTIFICATION_EMAIL}" = "true" ]; then
    curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
      --mailjet_api_key "$MAILJET_API_KEY" \
      --mailjet_api_secret "$MAILJET_API_SECRET" \
      --from_email "$FROM_EMAIL" \
      --to_email "$TO_EMAIL" \
      --cc "$CC_EMAILS" \
      --bcc "$BCC_EMAILS" \
      --subject "⛔ MongoDB Import Failed - Unzip Error" \
      --body "Failed to unzip backup $BACKUP_ZIP_NAME at $TIMESTAMP."
  else
    show_colored_message error "Error unzipping backup $BACKUP_ZIP_NAME at $TIMESTAMP."
  fi
  exit 1
fi



# Copy unzipped backup folder to container
BACKUP_FOLDER_NAME="${BACKUP_ZIP_NAME%.zip}"


show_colored_message info "Copying backup folder $BACKUP_FOLDER_NAME to container $MONGO_CONTAINER:/import/"
if ! docker exec "$MONGO_CONTAINER" [ -d "/import" ]; then
  docker exec "$MONGO_CONTAINER" mkdir /import
fi

docker cp "$IMPORT_DIR/$BACKUP_FOLDER_NAME" "$MONGO_CONTAINER:/import/$BACKUP_FOLDER_NAME"

if [ $? -ne 0 ]; then
  if [ "${NOTIFICATION_EMAIL}" = "true" ]; then
    curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
      --mailjet_api_key "$MAILJET_API_KEY" \
      --mailjet_api_secret "$MAILJET_API_SECRET" \
      --from_email "$FROM_EMAIL" \
      --to_email "$TO_EMAIL" \
      --cc "$CC_EMAILS" \
      --bcc "$BCC_EMAILS" \
      --subject "⛔ MongoDB Import Failed - Copy to Container Error" \
      --body "Failed to copy backup folder into container $MONGO_CONTAINER at $TIMESTAMP."
  else
    show_colored_message error "Failed to copy backup folder into container $MONGO_CONTAINER at $TIMESTAMP."
  fi
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
show_colored_message info "mongorestore command: mongorestore $MONGO_AUTH --host localhost --port $MONGO_PORT $MONGO_DB_ARG /import/$BACKUP_FOLDER_NAME"
show_colored_message info "Running mongorestore inside container..."

result=$(docker exec "$MONGO_CONTAINER" bash -c "mongorestore $MONGO_AUTH --host localhost --port $MONGO_PORT $MONGO_DB_ARG /import/$BACKUP_FOLDER_NAME")

if [ $? -ne 0 ]; then
  if [ "${NOTIFICATION_EMAIL}" = "true" ]; then
    curl -s "$MAIL_SCRIPT_URL" | bash -s -- \
      --mailjet_api_key "$MAILJET_API_KEY" \
      --mailjet_api_secret "$MAILJET_API_SECRET" \
      --from_email "$FROM_EMAIL" \
      --to_email "$TO_EMAIL" \
      --cc "$CC_EMAILS" \
      --bcc "$BCC_EMAILS" \
      --subject "⛔ MongoDB Import Failed - mongorestore Error" \
      --body "mongorestore command failed inside container at $TIMESTAMP."
  else

    show_colored_message error $result
    show_colored_message error "mongorestore command failed inside container at $TIMESTAMP."
  fi
  exit 1
fi



# Cleanup: remove import folder from container and local files
docker exec "$MONGO_CONTAINER" rm -rf "/import/$BACKUP_FOLDER_NAME"

if [ "${CLEANUP}" = "true" ]; then
  rm -rf "$IMPORT_DIR/$BACKUP_FOLDER_NAME"
  rm -f "$IMPORT_DIR/$BACKUP_ZIP_NAME"
fi


if [ "${NOTIFICATION_EMAIL}" = "true" ]; then
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
else
  show_colored_message success "Backup $BACKUP_ZIP_NAME imported successfully into MongoDB on container $MONGO_CONTAINER at $TIMESTAMP."
fi
