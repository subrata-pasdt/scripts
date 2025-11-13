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
}
