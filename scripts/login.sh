#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

docker compose up -d

bash "$ROOT_DIR/scripts/ensure-herdr.sh"

if docker compose exec -T firstmate codex login status >/dev/null 2>&1; then
  echo "Codex is already authenticated."
else
  echo "Starting Codex device-code authentication..."
  docker compose exec -it firstmate codex login --device-auth
fi

if docker compose exec -T firstmate gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is already authenticated."
else
  echo "Starting GitHub CLI authentication..."
  docker compose exec -it firstmate gh auth login
fi

docker compose exec -T firstmate gh auth setup-git

docker compose exec -T firstmate bash -lc '
  set -euo pipefail
  export PATH="$HOME/.local/bin:$PATH"
  herdr integration install codex
'

echo
echo "Authentication complete."
echo "Run 'fmh doctor' to verify the complete stack."
