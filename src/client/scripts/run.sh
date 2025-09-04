#!/usr/bin/env bash

set -euo pipefail

# working dir independent
cd "$(git rev-parse --show-toplevel)"
cd src/client

gleam run -m lustre/dev start --proxy-from="/api" --proxy-to="http://localhost:8000"
