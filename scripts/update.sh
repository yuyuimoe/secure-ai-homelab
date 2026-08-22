#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Rebuilding the disposable image from current upstream versions..."
docker compose build --pull --no-cache
docker compose up -d

echo "Refreshing persistent user-space tools..."
"$ROOT_DIR/scripts/setup.sh" --no-build

echo
echo "Update complete. Authentication and Firstmate state remain in the named volume."
