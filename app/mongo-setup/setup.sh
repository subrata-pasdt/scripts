#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)


REPO="https://raw.githubusercontent.com/subrata-pasdt/scripts/main/app/mongo-setup"

# for i in scripts/*; do
#   filename=$(basename "$i")
  
#   if [[ "$filename" == *.sh ]]; then
#     if [ ! -x "$i" ]; then
#       show_colored_message info "Added executable permission to $i"
#       chmod +x "$i"
#     fi
#   fi
# done

show_header "PASDT DevOps" "Subrata Kumar De" "2023" "1.0"


options=("Create Container" "Initialize Replicaset" "Create Users" "Connect to DB" "Reset Everything" "Show URL" "Exit")



select opt in "${options[@]}"; do
  case $REPLY in
    1)
      show_colored_message info "Creating Container"
      bash <(curl -s "$REPO/scripts/create-container.sh")
      break
      ;;
    2)
      show_colored_message info "Initializing Replicaset"
      bash scripts/initiate-replicate.sh
      break
      ;;
    3)
      show_colored_message info "Creating Users and Roles"
      bash scripts/user-management.sh
      ;;
    4)
      show_colored_message info "Connecting to DB"
      bash scripts/connect-to-db.sh
      break
      ;;
    5)
      show_colored_message error "Everything will be removed !"
      if confirm "Remove Everything"; then
        bash scripts/reset-all.sh
      else
        show_colored_message info "Operation canceled."
      fi
      break
      ;;
    6)
      show_colored_message info "Generating URL"
      bash scripts/show-url.sh
      ;;
    7)
       show_colored_message success "Thank You ! Bye."
      exit 0;
      ;;
    *)
      show_colored_message error "Invalid option. Try again."
      ;;
  esac
done
