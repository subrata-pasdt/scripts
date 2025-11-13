#!/bin/bash

check_and_generate_files() {
  if [[ ! -f .env ]]; then
    echo ".env missing — generating..."
    generate_env
  fi

  if [[ ! -f docker-compose.yml ]]; then
    echo "docker-compose.yml missing — generating..."
    generate_compose
  fi


  if [[ ! -f keyfile/mongo.key ]]; then
    mkdir -p keyfile
    openssl rand -base64 756 > keyfile/mongo.key
    chmod 600 keyfile/mongo.key
    echo "🔐 KeyFile created at keyfile/mongo.key"
  fi
}
