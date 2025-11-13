#!/bin/bash

create_container() {
  docker compose up -d
  echo "Containers started."
}
