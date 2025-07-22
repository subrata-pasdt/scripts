#!/bin/bash

# PAS Digital Technologies
# Author: Subrata Kumar De
# Copyright (c) 2020 PAS Digital Technologies


function show_header() {
    local project_name=$1
    local project_details=$2
    local project_date=$3
    local project_version=$4

    echo -e "
\033[0;34m ███████████       █████████       █████████     ██████████      ███████████
\033[0;34m░░███░░░░░███     ███░░░░░███     ███░░░░░███   ░░███░░░░███    ░█░░░███░░░█
\033[0;34m ░███    ░███    ░███    ░███    ░███    ░░░     ░███   ░░███   ░   ░███  ░ 
\033[0;36m ░██████████     ░███████████    ░░█████████     ░███    ░███       ░███    
\033[0;36m ░███░░░░░░      ░███░░░░░███     ░░░░░░░░███    ░███    ░███       ░███    
\033[0;35m ░███            ░███    ░███     ███    ░███    ░███    ███        ░███    
\033[0;35m █████           █████   █████   ░░█████████     ██████████         █████   
\033[0;35m░░░░░           ░░░░░   ░░░░░     ░░░░░░░░░     ░░░░░░░░░░         ░░░░░    

\033[0;34m
$(printf "%-40s" "${project_name}") > Subrata Kumar De
$(printf "%-40s" "${project_details}") > ${project_date}
$(printf "%-40s" "") > v${project_version}

\033[0;35m--------------------------------------------------------------------------------
\033[0m"
}





#Function to show message based on type
function show_colored_message() {
    local type="$1"
    local message="$2"
    local color_code

    case "$type" in
        info)
            color_code="\033[0;34m[i] " # Blue
            ;;
        warning)
            color_code="\033[0;35m[!] " # Purple
            ;;
        error)
            color_code="\033[0;31m[x] " # Red
            ;;
        success)
            color_code="\033[0;32m[✔] " # Green
            ;;
        debug)
            color_code="\033[0;36m[D] " # Cyan
            ;;
        question)
            color_code="\033[0;33m[?] " # Yellow
            ;;
        *)
            color_code="\033[0;37m[>] " # Default (White)
            ;;
    esac

    echo -e "${color_code}${message}\033[0m"
}






# Function to prompt for confirmation
function confirm() {
    while true; do
        read -rp "$(show_colored_message "question" "$1 (y/n) [default: n]: ")" choice
        case "$choice" in 
            [Yy]* ) return 0;;
            [Nn]* | "" ) show_colored_message "error" "Operation canceled."; return 1;;
            * ) show_colored_message "error" "Please enter y or n.";;
        esac
    done
}



# Function to check the last command status
function check_last_command_status() {
    local error_message="An error occurred."
    local success_message="Operation completed successfully."

    if [ -n "$1" ]; then
        error_message="$1"
    fi

    if [ -n "$2" ]; then
        success_message="$2"
    fi

    if [ ! $? -eq 0 ]; then
        show_colored_message "error" "${error_message}"
        exit 1
    else
        show_colored_message "success" "${success_message}"
    fi
}
