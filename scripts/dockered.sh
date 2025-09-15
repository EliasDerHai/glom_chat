#!/usr/bin/env bash

set -euo pipefail

# working dir independent
cd "$(git rev-parse --show-toplevel)"

echo "--- Stopping existing containers ---"
docker-compose down

echo "--- Building backend image ---"
docker-compose build backend

echo "--- Starting the stack ---"
docker-compose up -d

echo "--- Container status ---"
docker-compose ps

echo "--- Recent backend logs ---"
docker-compose logs backend --tail=10

