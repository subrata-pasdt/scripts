#!/bin/bash

reset_all() {
  docker compose down -v
  rm -rf keyfile
  rm -rf data
  rm -f docker-compose.yml .env dblist
  echo "System reset complete."
}
