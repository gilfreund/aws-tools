#!/usr/bin/env bash
# Run the full test suite
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v bats &>/dev/null; then
  echo "bats-core is required. Install with: brew install bats-core"
  exit 1
fi

echo "Running ectools test suite..."
echo ""

bats --tap "$SCRIPT_DIR"/test_*.bats
