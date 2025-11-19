#!/usr/bin/bash

docker compose down
docker system prune -f
sudo rm -R data
sudo rm -R secrets
rm docker-compose.yaml
rm .env
