#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

docker compose up -d >/dev/null

exec docker compose exec -it firstmate bash -lc '
  export PATH="$HOME/.local/bin:$PATH"
  cd /opt/firstmate
  exec herdr --session "${HERDR_SESSION:-firstmate}"
'
