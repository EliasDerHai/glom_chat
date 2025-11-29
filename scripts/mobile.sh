#!/usr/bin/env bash

set -euo pipefail

# working dir independent
cd $(git rev-parse --show-toplevel) 

(cd ./src/mobile_client/ && pnpm dev)
