#!/bin/bash
source <(curl -s https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)
source <(curl -s https://raw.githubusercontent.com/subrata-pasdt/scripts/main/docker/mongodb/dump-and-restore/common.sh)


show_header "MongoDB Import" "Script to import a MongoDB database" "${current_date}" "${script_version}"
check_config_file
check_is_primary_container


uri="mongodb://${username}:${password}@${host}/${database}?authSource=admin"

show_colored_message success "Generated uri: ${uri}"


if [ ! -d ${backup_dir} ]; then
  show_colored_message warning "Backup directory not found"
  exit 1
else
  show_colored_message success "Backup directory found"
fi




show_colored_message info "Initiating restore..."
docker exec -it ${container_name} bash -c "if [ ! -d \"${backup_dir}\" ]; then mkdir -p \"${backup_dir}\"; fi"
check_last_command_status "Error creating restoration directory" "Restoration directory created successfully..."


show_colored_message info "Copying backup to container..."
docker cp $backup_dir/. $container_name:${backup_dir}/

check_last_command_status "Error copying backup" "Backup copied to ${container_name}:${backup_dir}"





show_colored_message info "Running restoration..."

docker exec -it ${container_name} bash -c "mongorestore --uri '${uri}' '${backup_dir}' &> /dev/null"

check_last_command_status "Error restoring database : ${database}" "${database} restored successfully..."


show_colored_message success "Import Completed"



show_colored_message info "Removing temporary files..."

docker exec -it ${container_name} bash -c "rm -rf '${backup_dir}'"

check_last_command_status "Error removing temporary files" "Temporary files removed successfully"

show_colored_message success "Import Done and Dusted"
show_colored_message success "Bye Bye"