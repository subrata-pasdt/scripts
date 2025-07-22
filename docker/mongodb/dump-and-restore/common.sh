
# Check if config file exists and contains the required keys. If not, create it.
# If the file exists but does not contain the required keys, show an error message
# and exit.
function check_config_file() {
    if [ -f config.json ] && jq -e '.user? and .password? and .host? and .database? and .container? and .backup_dir? and .auth_db?' config.json > /dev/null; then
        show_colored_message success "Config file found, reading..."
        username=$(jq -r '.user' config.json)
        password=$(jq -r '.password' config.json)
        host=$(jq -r '.host' config.json)
        database=$(jq -r '.database' config.json)
        container_name=$(jq -r '.container' config.json)
        backup_dir=$(jq -r '.backup_dir' config.json)
        auth_db=$(jq -r '.auth_db' config.json)
        show_colored_message success "Config file read successfully..."
    else
        show_colored_message warning "Config file not found"
        show_colored_message info "Creating config file..."
        cat > config.json <<EOF
{
"user": "root",
"password": "example",
"host": "localhost",
"database": "dbname",
"container": "mongo1",
"backup_dir": "backup_dbname_$(date +%d-%m-%Y_%H_%M)"
}
EOF

        check_last_command_status "Error creating config file" "Config file created at ${PWD}/config.json"
        show_colored_message info "Please update config file and run again..."
        show_colored_message debug "Bye Bye"
        exit 1
    fi
}


function prepare_uri() {
    uri="mongodb://${username}:${password}@${host}/${database}?authSource=${auth_db}"
}