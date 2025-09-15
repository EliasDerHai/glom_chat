#!/usr/bin/env bash

set -euo pipefail

# working dir independent
cd "$(git rev-parse --show-toplevel)"

# Build from project root so Docker can access both src/server and src/shared
docker build -f src/server/Dockerfile -t glom-chat-server .
docker run -p 8000:8000 --env-file src/server/.env glom-chat-server
