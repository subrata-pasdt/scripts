#!/bin/bash
source <(curl -s https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)
source <(curl -s https://raw.githubusercontent.com/subrata-pasdt/scripts/main/docker/mongodb/dump-and-restore/common.sh)


show_header "MongoDB Export" "Script to export a MongoDB database" "${current_date}" "${script_version}"
check_config_file
prepare_uri


show_colored_message success "Generated uri: ${uri}"

show_colored_message info "Starting backup..."
docker exec -it ${container_name} bash -c "if [ ! -d \"${backup_dir}\" ]; then mkdir -p \"${backup_dir}\"; fi"

check_last_command_status "Error creating backup directory" "Backup directory created successfully..."


show_colored_message info "Running backup..."

docker exec -it ${container_name} bash -c "mongodump --uri '${uri}' --out '${backup_dir}'"

check_last_command_status "Error generating backup" "Backup generated successfully..."


show_colored_message success "Backup generated"

if [ ! -d ${backup_dir} ]; then
  show_colored_message warning "Backup directory not found, creating..."
  mkdir -p ${backup_dir}
  check_last_command_status "Error creating backup directory" "Backup directory created successfully"
else
  show_colored_message success "Backup directory found, cleaning..."
  rm -rf ${backup_dir}
  check_last_command_status "Error cleaning backup directory" "Backup directory cleaned successfully"
  mkdir -p ${backup_dir}
  check_last_command_status "Error creating backup directory" "Backup directory created successfully"
fi


show_colored_message info "Copying backup..."
docker cp $container_name:${backup_dir}/${database}/. $backup_dir/

check_last_command_status "Error copying backup" "Backup copied to ${backup_dir}"

show_colored_message info "Removing temporary files..."

docker exec -it ${container_name} bash -c "rm -rf '${backup_dir}'"

check_last_command_status "Error removing temporary files" "Temporary files removed successfully"



# Zip the entire directory
ZIP_NAME="$backup_dir.zip"
if [ "$zip" -eq 1 ]; then
  if [ "$secure" -eq 1 ]; then
    PASSWORD=$(date '+%d%b%Y' | awk '{print $1 tolower(substr($2, 1, 1)) tolower(substr($2, 2, 1)) toupper(substr($2, 3, 1)) $3}')
    zip -r $ZIP_NAME $backup_dir/ -P $PASSWORD
  else
    zip -r $ZIP_NAME $backup_dir/
  fi
else
  show_colored_message info "Skipping zip"
fi




# Upload to S3
# S3_BUCKET="pasdt-backup"
# aws s3 cp "$ZIP_NAME" "s3://$S3_BUCKET/pasdtems/"

# Clean up (optional)
# rm -r $DIR_NAME $ZIP_NAME


show_colored_message success "Backup Done and Dusted"
show_colored_message success "Bye Bye"
