#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

UPDATE=0
if [[ "${1:-}" == "--update" ]]; then
  UPDATE=1
elif [[ $# -gt 0 ]]; then
  echo "error: unknown option: $1" >&2
  exit 1
fi

docker compose up -d >/dev/null

if [[ $UPDATE -eq 1 ]]; then
  echo "Installing/updating Herdr in the persistent agent home..."
else
  if docker compose exec -T firstmate bash -lc 'export PATH="$HOME/.local/bin:$PATH"; command -v herdr >/dev/null 2>&1'; then
    exit 0
  fi
  echo "Herdr is missing from the persistent agent home; installing it now..."
fi

docker compose exec -T firstmate bash -lc '
  set -euo pipefail
  export PATH="$HOME/.local/bin:$PATH"
  export HERDR_INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$HERDR_INSTALL_DIR"
  curl -fsSL https://herdr.dev/install.sh | sh
  command -v herdr >/dev/null 2>&1
'
