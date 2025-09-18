#!/usr/bin/env bash

set -euo pipefail

# working dir independent
ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

if [[ "$(uname)" == "Darwin" ]]; then
  # macOS
  HOST_IP="localhost"
else
  # openSUSE (WSL)
  HOST_IP=$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf)
fi

export DATABASE_URL="postgres://postgres:postgres@${HOST_IP}:5432/glom_chat"

# # Function to build frontend and copy to server static dir
# echo "Building frontend..."
# cd "$ROOT_DIR/src/client"
# gleam run -m lustre/dev build app --outdir="$ROOT_DIR/src/server/priv/static/"
# 
# # Function to run server
# cd "$ROOT_DIR/src/server" && gleam run

watchexec \
  --watch src/client/src \
  --watch src/shared/src \
  --watch src/server/src \
  --exts gleam \
  --restart \
  -- bash -c "
    ROOT_DIR=$(git rev-parse --show-toplevel)
    export DATABASE_URL="postgres://postgres:postgres@${HOST_IP}:5432/glom_chat"
    echo "Building frontend..."
    cd "$ROOT_DIR/src/client"
    gleam run -m lustre/dev build app --outdir="$ROOT_DIR/src/server/priv/static/"
    cd "$ROOT_DIR/src/server" && gleam run
  "
