#!/bin/bash

# ============================================================================

# Redis Setup Automation Tool

# Features:

# - Dependency checker

# - Environment manager

# - Docker Compose deployment

# - Optional RedisInsight UI

# - Optional persistence (AOF)

# - Optional ACL user creation

# - Redis health checks

# - Password regeneration

# ============================================================================

set -euo pipefail

source <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/common/pasdt-devops-scripts.sh)

ENV_FILE=".env"
DOCKER_COMPOSE_CMD=""

# ============================================================================

# DEPENDENCY CHECKER

# ============================================================================

check_command() {
command -v "$1" >/dev/null 2>&1
}

check_docker_running() {
docker info >/dev/null 2>&1
}

detect_docker_compose_command() {
if docker compose version >/dev/null 2>&1; then
DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
DOCKER_COMPOSE_CMD="docker-compose"
else
return 1
fi
}

check_dependencies() {
    echo "➡ Checking dependencies..."
    echo

    local failed=false

    if ! check_command docker; then
        echo "❌ Docker not installed"
        failed=true
    else
        echo "✅ Docker installed"
    fi

    if ! check_docker_running; then
        echo "❌ Docker daemon not running"
        failed=true
    else
        echo "✅ Docker daemon running"
    fi

    if ! detect_docker_compose_command; then
        echo "❌ Docker Compose not found"
        failed=true
    else
        echo "✅ Docker Compose available ($DOCKER_COMPOSE_CMD)"
    fi

    if ! check_command redis-cli; then
        echo "⚠ redis-cli not installed (health checks unavailable)"
    else
        echo "✅ redis-cli installed"
    fi

    if [ "$failed" = true ]; then
        exit 1
    fi

    echo

}

# ============================================================================

# PASSWORD GENERATOR

# ============================================================================

generate_password() {
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20 || true
}

# ============================================================================

# ENVIRONMENT MANAGER

# ============================================================================

create_env() {

    local password
    password=$(generate_password)

    echo
    read -p "Deploy RedisInsight UI? (y/n): " ui_choice

    if [[ "$ui_choice" =~ ^[Yy]$ ]]; then
        ENABLE_UI=true
    else
        ENABLE_UI=false
    fi

    echo
    read -p "Enable Redis persistence (appendonly yes)? (y/n): " persistence_choice

    if [[ "$persistence_choice" =~ ^[Yy]$ ]]; then
        ENABLE_PERSISTENCE=true
    else
        ENABLE_PERSISTENCE=false
    fi

    echo
    echo "Redis interface:"
    echo "1) localhost (127.0.0.1)"
    echo "2) all interfaces (0.0.0.0)"
    read -p "Choice [1-2]: " redis_if

    case $redis_if in
        2) REDIS_BIND="0.0.0.0" ;;
        *) REDIS_BIND="127.0.0.1" ;;
    esac

    UI_BIND="127.0.0.1"

    if [ "$ENABLE_UI" = "true" ]; then
        echo
        echo "RedisInsight interface:"
        echo "1) localhost (127.0.0.1)"
        echo "2) all interfaces (0.0.0.0)"
        read -p "Choice [1-2]: " ui_if

        case $ui_if in
            2) UI_BIND="0.0.0.0" ;;
            *) UI_BIND="127.0.0.1" ;;
        esac
    fi

    cat > "$ENV_FILE" <<EOF

REDIS_PASSWORD=$password
ENABLE_UI=$ENABLE_UI
ENABLE_PERSISTENCE=$ENABLE_PERSISTENCE
REDIS_BIND=$REDIS_BIND
UI_BIND=$UI_BIND
EOF


    chmod 600 "$ENV_FILE"

    echo
    echo "✅ Environment created"
    echo "Password: $password"
    echo


}

load_env() {

    if [ ! -f "$ENV_FILE" ]; then
        create_env
    fi

    set -a
    source "$ENV_FILE"
    set +a

}

update_env_var() {

    local key=$1
    local value=$2

    if grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi


}

# ============================================================================

# ACL SUPPORT

# ============================================================================

setup_acl_user() {

    echo
    read -p "Create ACL user? (y/n): " choice

    if ! [[ "$choice" =~ ^[Yy]$ ]]; then
        return
    fi

    read -p "ACL username: " ACL_USER

    ACL_PASSWORD=$(generate_password)

    update_env_var ACL_USER "$ACL_USER"
    update_env_var ACL_PASSWORD "$ACL_PASSWORD"

    echo
    echo "ACL User Created"
    echo "Username: $ACL_USER"
    echo "Password: $ACL_PASSWORD"
    echo


}

# ============================================================================

# COMPOSE GENERATOR

# ============================================================================

create_compose() {

    local persistence_cmd=""

    if [ "$ENABLE_PERSISTENCE" = "true" ]; then
        persistence_cmd="--appendonly yes"
    fi

    cat > docker-compose.yml <<EOF
services:
    redis:
        image: redis:7-alpine
        container_name: redis
        restart: unless-stopped
        command: >
            redis-server
            --requirepass ${REDIS_PASSWORD}
        $persistence_cmd
        ports:
            - "${REDIS_BIND}:6379:6379"
        volumes:
            - ./redis-data:/data
EOF


    if [ "${ENABLE_UI}" = "true" ]; then

    cat >> docker-compose.yml <<EOF

    redisinsight:
        image: redis/redisinsight:latest
        container_name: redisinsight
        restart: unless-stopped
        ports:
            - "${UI_BIND}:5540:5540"
        volumes:
            - ./redisinsight:/data
EOF


    fi


}

# ============================================================================

# REDIS ACL CONFIG

# ============================================================================

apply_acl_user() {

    if [ -z "${ACL_USER:-}" ]; then
        return
    fi

    echo "➡ Applying ACL user..."

    docker exec redis redis-cli \
        -a "$REDIS_PASSWORD" \
        ACL SETUSER "$ACL_USER" on ">$ACL_PASSWORD" allcommands allkeys
        
    echo "✅ ACL user applied"


}

# ============================================================================

# HEALTH CHECK

# ============================================================================

health_check() {

    echo
    echo "➡ Running Redis health check..."
    if ! check_command redis-cli; then
        echo "⚠ redis-cli not installed"
        return
    fi

    if redis-cli -h 127.0.0.1 -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q PONG; then
        echo "✅ Redis healthy"
    else
        echo "❌ Redis unhealthy"
    fi

    echo


}

# ============================================================================

# CONTAINER MANAGEMENT

# ============================================================================

container_running() {

    docker ps \
        --filter name=redis \
        --filter status=running \
        --format "{{.Names}}" | grep -q "^redis$"

}


start_redis() {

    load_env
    create_compose
    echo
    echo "➡ Starting Redis..."
    $DOCKER_COMPOSE_CMD up -d
    sleep 5
    apply_acl_user
    health_check
    echo
    echo "Redis Endpoint:"
    echo "redis://:${REDIS_PASSWORD}@localhost:6379"
    if [ "$ENABLE_UI" = "true" ]; then
        echo
        echo "RedisInsight:"
        echo "http://localhost:5540"
    fi
    echo

}

stop_redis() {

    if [ -f docker-compose.yml ]; then
        $DOCKER_COMPOSE_CMD down
        echo "✅ Redis stopped"
    else
        echo "No compose file found"
    fi


}

restart_redis() {
    stop_redis
    start_redis

}

# ============================================================================

# CREDENTIALS

# ============================================================================

show_credentials() {
    load_env

    echo
    echo "══════════════════════════════════════"
    echo "Redis Credentials"
    echo "══════════════════════════════════════"
    echo

    echo "Password: $REDIS_PASSWORD"
    echo "Redis Bind: $REDIS_BIND"

    if [ "$ENABLE_UI" = "true" ]; then
        echo "RedisInsight: enabled"
        echo "UI Bind: $UI_BIND"
        echo "URL: http://localhost:5540"
    else
        echo "RedisInsight: disabled"
    fi

    if [ -n "${ACL_USER:-}" ]; then
        echo
        echo "ACL User: $ACL_USER"
        echo "ACL Password: $ACL_PASSWORD"
    fi

echo


}

# ============================================================================

# PASSWORD REGENERATION

# ============================================================================

regenerate_password() {

    load_env
    local new_pass
    new_pass=$(generate_password)
    update_env_var REDIS_PASSWORD "$new_pass"
    REDIS_PASSWORD="$new_pass"

    echo
    echo "✅ Password regenerated"
    echo "New Password: $new_pass"
    echo

    if container_running; then
        echo "Restarting Redis..."
        restart_redis
    fi

}

# ============================================================================

# MENU

# ============================================================================

show_menu() {


echo
echo "══════════════════════════════════════"
echo " Redis Setup Automation"
echo "══════════════════════════════════════"
echo
echo "1) Start Redis"
echo "2) Stop Redis"
echo "3) Restart Redis"
echo "4) Show Credentials"
echo "5) Regenerate Password"
echo "6) Health Check"
echo "7) Create ACL User"
echo "8) Exit"
echo


}

run_menu() {


while true; do

    show_menu

    read -p "Choice: " choice

    case $choice in

        1)
            start_redis
            ;;

        2)
            stop_redis
            ;;

        3)
            restart_redis
            ;;

        4)
            show_credentials
            ;;

        5)
            regenerate_password
            ;;

        6)
            load_env
            health_check
            ;;

        7)
            load_env
            setup_acl_user
            apply_acl_user
            ;;

        8)
            exit 0
            ;;

        *)
            echo "Invalid option"
            ;;

    esac

done


}

# ============================================================================

# BANNER

# ============================================================================

show_banner() {

cat <<'EOF'
    ██████╗ ███████╗██████╗ ██╗███████╗
    ██╔══██╗██╔════╝██╔══██╗██║██╔════╝
    ██████╔╝█████╗  ██║  ██║██║███████╗
    ██╔══██╗██╔══╝  ██║  ██║██║╚════██║
    ██║  ██║███████╗██████╔╝██║███████║
    ╚═╝  ╚═╝╚══════╝╚═════╝ ╚═╝╚══════╝

    Redis Setup Automation Tool

EOF

}

# ============================================================================

# MAIN

# ============================================================================

main() {
    show_banner
    check_dependencies
    load_env
    run_menu
}

main "$@"
