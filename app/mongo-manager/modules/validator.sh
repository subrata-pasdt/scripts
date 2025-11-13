#!/bin/bash

validate_env() {
  if [[ ! -f .env ]]; then return 1; fi

  source .env

  [[ -z "$MONGO_INITDB_ROOT_USERNAME" ]] && return 1
  [[ -z "$MONGO_INITDB_ROOT_PASSWORD" ]] && return 1
  [[ -z "$REPLICATION_HOST" ]] && return 1
  [[ -z "$MONGO_PORT" ]] && return 1

  return 0
}

validate_compose() {
  if [[ ! -f docker-compose.yml ]]; then return 1; fi

  # Check if YAML readable
  if grep -q "services:" docker-compose.yml; then
    return 0
  else
    return 1
  fi
}

precheck_files() {

  ENV_VALID=0
  COMPOSE_VALID=0

  validate_env
  ENV_VALID=$?

  validate_compose
  COMPOSE_VALID=$?

  if [[ $ENV_VALID -eq 0 && $COMPOSE_VALID -eq 0 ]]; then
    echo "✅ Existing .env and docker-compose.yml validated."
    return
  fi

  echo "⚠️ Configuration missing or invalid — generating fresh..."

  generate_env
  generate_compose
}
