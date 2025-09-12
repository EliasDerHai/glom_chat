#!/usr/bin/env bash

set -euo pipefail

# working dir independent
cd "$(git rev-parse --show-toplevel)"

test_dirs="src/shared src/server src/client"

for dir in $test_dirs; do
  echo "--- Running tests in $dir ---"
  (cd "$dir" && gleam test)
  echo "--- Tests passed in $dir ---"
done
