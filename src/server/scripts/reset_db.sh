#!/usr/bin/env bash

set -euo pipefail

# working dir independent
cd "$(git rev-parse --show-toplevel)"
cd src/server

if [[ "$(uname)" == "Darwin" ]]; then
  # macOS
  HOST_IP="localhost"
else
  # openSUSE (WSL)
  HOST_IP=$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf)
fi

export DATABASE_URL="postgres://postgres:postgres@${HOST_IP}:5432/glom_chat"

echo " Dropping database 'glom_chat'..."
psql -h "${HOST_IP}" -U postgres -c "DROP DATABASE IF EXISTS glom_chat;"

echo "Creating database 'glom_chat'..."
psql -h "${HOST_IP}" -U postgres -c "CREATE DATABASE glom_chat;"

echo "Running migrations..."
gleam run -m cigogne last

echo "Database reset complete!"
