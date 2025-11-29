#!/usr/bin/env bash

set -euo pipefail

# working dir independent
ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

is_wsl() {
  # Kernel string includes "Microsoft" or "WSL" on WSL1 and WSL2
  grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null \
    && return 0

  # Fallback hints
  [[ -n "${WSL_DISTRO_NAME:-}" ]] && return 0
  [[ -n "${WSL_INTEROP:-}" ]] && return 0

  return 1
}

if [[ "$(uname)" == "Darwin" ]]; then
  HOST_IP="localhost"
elif is_wsl; then
  HOST_IP=$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf)
else
  HOST_IP="localhost"
fi

export DATABASE_URL="postgres://postgres:postgres@${HOST_IP}:5432/glom_chat"

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
