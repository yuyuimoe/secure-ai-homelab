#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 is required (the 'docker compose' command)." >&2
  exit 1
fi

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example."
  echo "You can edit GIT_USER_NAME/GIT_USER_EMAIL now or later."
fi

if [[ "${1:-}" == "--no-build" ]]; then
  echo "Starting the already-built Firstmate container..."
  docker compose up -d
else
  echo "Building and starting the Firstmate container..."
  docker compose up -d --build
fi

echo "Installing/updating Herdr in the persistent agent home..."
docker compose exec -T firstmate bash -lc '
  set -euo pipefail
  export PATH="$HOME/.local/bin:$PATH"
  export HERDR_INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$HERDR_INSTALL_DIR"
  curl -fsSL https://herdr.dev/install.sh | sh
'

echo "Installing any missing Firstmate-managed toolchain dependencies..."
docker compose exec -T firstmate bash -lc '
  set -euo pipefail
  export PATH="$HOME/.local/bin:$PATH"
  cd /opt/firstmate

  diagnostics="$(
    FM_BOOTSTRAP_DETECT_ONLY=1 \
    FM_BOOTSTRAP_NETWORK=skip \
    ./bin/fm-bootstrap.sh
  )"

  if [[ -n "$diagnostics" ]]; then
    printf "%s\n" "$diagnostics"
  fi

  missing="$(
    printf "%s\n" "$diagnostics" \
      | sed -n "s/^MISSING: \([^ ]*\).*/\1/p" \
      | sort -u \
      | tr "\n" " "
  )"

  if [[ -n "${missing// }" ]]; then
    # shellcheck disable=SC2086
    ./bin/fm-bootstrap.sh install $missing
  fi

  # These setup commands are idempotent and are intentionally re-run because
  # /opt/firstmate belongs to the disposable container image.
  for tool in gh-axi chrome-devtools-axi lavish-axi; do
    if command -v "$tool" >/dev/null 2>&1; then
      "$tool" setup hooks
    fi
  done

  remaining="$(
    FM_BOOTSTRAP_DETECT_ONLY=1 \
    FM_BOOTSTRAP_NETWORK=skip \
    ./bin/fm-bootstrap.sh
  )"

  if printf "%s\n" "$remaining" | grep -Eq "^(MISSING|MISSING_MANUAL|BACKEND_INVALID):"; then
    echo "Toolchain bootstrap is still incomplete:" >&2
    printf "%s\n" "$remaining" >&2
    exit 1
  fi
'

echo "Installing the Herdr Codex integration..."
docker compose exec -T firstmate bash -lc '
  set -euo pipefail
  export PATH="$HOME/.local/bin:$PATH"
  mkdir -p "${CODEX_HOME:-$HOME/.codex}"
  herdr integration install codex
'

echo
echo "Base stack is ready."
echo "Next:"
echo "  ./scripts/login.sh"
echo "  ./scripts/doctor.sh"
echo "  ./scripts/connect.sh"
