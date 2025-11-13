#!/bin/bash

show_menu() {
  echo "======================================="
  echo " MongoDB ReplicaSet Manager"
  echo "======================================="
  echo "1) Create Container"
  echo "2) Initialize ReplicaSet"
  echo "3) Create Users"
  echo "4) Connect to DB"
  echo "5) Reset Everything"
  echo "6) Show URL"
  echo "7) Exit"
  echo -n "#? "
}

menu_controller() {
  clear
  check_and_generate_files

  show_menu
  read choice

  case "$choice" in
    1)
      echo ""
      echo "▶ Creating containers..."
      create_container
      ;;
    2)
      echo ""
      echo "▶ Initializing ReplicaSet..."
      init_replicaset
      ;;
    3)
      echo ""
      echo "▶ Creating Users..."
      create_users
      ;;
    4)
      echo ""
      echo "▶ Connecting to DB..."
      connect_db
      ;;
    5)
      echo ""
      echo "▶ Resetting Everything..."
      reset_all
      ;;
    6)
      echo ""
      echo "▶ Showing connection URL..."
      show_url
      ;;
    7)
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "❌ Invalid option"
      ;;
  esac

  echo ""
  read -p "Press ENTER to continue..."
  menu_controller   # RECURSIVE CALL (NO LOOP)
}

# Entry point
menu_controller




# check_and_generate_files

# while true; do
#   clear
#   echo "======================================="
#   echo " MongoDB ReplicaSet Manager"
#   echo "======================================="
#   echo "1) Create Container"
#   echo "2) Initialize ReplicaSet"
#   echo "3) Create Users"
#   echo "4) Connect to DB"
#   echo "5) Reset Everything"
#   echo "6) Show URL"
#   echo "7) Exit"
#   echo -n "#? "
#   read choice

#   case $choice in
#     1) create_container ;;
#     2) init_replicaset ;;
#     3) create_users ;;
#     4) connect_db ;;
#     5) reset_all ;;
#     6) show_url ;;
#     7) exit 0 ;;
#     *) echo "Invalid option"; sleep 1 ;;
#   esac
# done
