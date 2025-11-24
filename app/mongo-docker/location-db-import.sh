#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)
set -e

show_header "Location DB Import" "PASDT Location API" "2025" "1.0.0"

DEMO_CONFIG_CONTENT='user="user"
pass="pass"
database="location"
authDb="admin"

containers="mongo1 mongo2 mongo3"
backup="world-mongodb-dump.tar.gz"

dumpDir="mongodb-dump"
databaseDir="world"
'

# ---------------------------------------------------------
# Parse optional --config=
# ---------------------------------------------------------
CONFIG_FILE="config.cfg"

for arg in "$@"; do
    case $arg in
        --config=*)
            CONFIG_FILE="${arg#*=}"
            shift
            ;;
        *)
            show_colored_message info "Unknown argument: $arg"
            show_colored_message info "Usage: ./restore.sh [--config=/path/file.cfg]"
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------
# Create demo config if missing
# ---------------------------------------------------------
if [[ ! -f "$CONFIG_FILE" ]]; then
    show_colored_message warning "Config file '$CONFIG_FILE' not found."
    show_colored_message info "Generating demo config file..."
    show_colored_message info "$DEMO_CONFIG_CONTENT" > "$CONFIG_FILE"
    show_colored_message info "Demo config created at: $CONFIG_FILE"
    show_colored_message default "Please edit it and run again."
    exit 0
fi

# ---------------------------------------------------------
# Load config
# ---------------------------------------------------------
show_colored_message success "Using config file: $CONFIG_FILE"
source "$CONFIG_FILE"

required=(user pass database authDb containers backup dumpDir databaseDir)

for key in "${required[@]}"; do
    if [[ -z "${!key}" ]]; then
        show_colored_message error "ERROR: '$key' is missing in $CONFIG_FILE"
        exit 1
    fi
done

show_colored_message info "MongoDB Restore Script"
show_colored_message info "Database        : $database"
show_colored_message info "Backup          : $backup"
show_colored_message info "Dump Dir        : $dumpDir"
show_colored_message info "Database Dir    : $databaseDir"

# ---------------------------------------------------------
# Detect PRIMARY node
# ---------------------------------------------------------
show_colored_message info "Detecting PRIMARY node..."

primary=""

for c in $containers; do
    is_primary=$(docker exec "$c" mongosh --quiet --eval "rs.isMaster().ismaster" 2>/dev/null)

    if [[ "$is_primary" == "true" ]]; then
        primary="$c"
        break
    fi
done

if [[ -z "$primary" ]]; then
    show_colored_message error "ERROR: No PRIMARY found!"
    exit 1
fi

show_colored_message success "PRIMARY = $primary"

# ---------------------------------------------------------
# Copy backup into PRIMARY
# ---------------------------------------------------------
show_colored_message info "Copying backup ($backup) to $primary ..."
docker cp "$backup" "$primary:/backup.tar.gz"

# ---------------------------------------------------------
# Extract backup
# ---------------------------------------------------------
show_colored_message info "Extracting backup..."
docker exec "$primary" sh -c "
    rm -rf /restore &&
    mkdir /restore &&
    tar -xzf /backup.tar.gz -C /restore
"

TARGET_PATH="/restore/$dumpDir/$databaseDir"

# ---------------------------------------------------------
# Validate extracted directory
# ---------------------------------------------------------
show_colored_message info "Checking extracted directory..."
docker exec "$primary" sh -c "test -d '$TARGET_PATH'" || {
    show_colored_message error "ERROR: Extracted directory '$TARGET_PATH' not found!"
    exit 1
}

show_colored_message success "Restore path OK: $TARGET_PATH"

# ---------------------------------------------------------
# Run mongorestore
# ---------------------------------------------------------
show_colored_message info "Running mongorestore..."


# ---------------------------------------------------------
# Rename extracted subfolder
# ---------------------------------------------------------
OLD_PATH="/restore/$dumpDir/$databaseDir"
NEW_PATH="/restore/$dumpDir/$database"

show_colored_message info "Renaming folder:"
show_colored_message info "$OLD_PATH  →  $NEW_PATH"

docker exec "$primary" sh -c "
    rm -rf '$NEW_PATH';
    mv '$OLD_PATH' '$NEW_PATH'
"

# ---------------------------------------------------------
# Run mongorestore normally
# ---------------------------------------------------------
show_colored_message info "Running mongorestore..."

docker exec "$primary" mongorestore \
    --username "$user" \
    --password "$pass" \
    --authenticationDatabase "$authDb" \
    --drop \
    --db "$database" \
    "$NEW_PATH"

show_colored_message success "Restore Completed Successfully"
show_colored_message info "Database: $database"
show_colored_message info "PRIMARY:  $primary"
show_colored_message info "Path:     $TARGET_PATH"
