#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Refreshing runtime images..."
docker compose pull docker projects-init

echo "Rebuilding the disposable Firstmate image from current upstream versions..."
docker compose build --pull --no-cache firstmate
docker compose up -d

echo "Refreshing persistent user-space tools..."
"$ROOT_DIR/scripts/setup.sh" --no-build

echo
echo "Update complete. Authentication, projects, Firstmate state, and DinD data were preserved."
