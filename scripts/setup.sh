#!/usr/bin/env bash

set -euo pipefail

# working dir independent
cd "$(git rev-parse --show-toplevel)"

check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ Error: '$1' is not installed or not in your PATH."
    echo "   Please follow the installation instructions at:"
    echo "   https://gleam.run/getting-started/installing/"
    exit 1
  fi
}

echo "🔎 Checking for required dependencies..."
check_command "gleam"
check_command "erl"
check_command "rebar3"
echo "✅ All dependencies are present."

echo "
🔧 Configuring Git hooks..."
git config core.hooksPath ./scripts/githooks
echo "✅ Git hooks path configured."

echo "
🧪 Running tests to verify setup..."
./scripts/test.sh

echo "
🚀 Development environment setup complete!"
