#!/usr/bin/env bash
set -euo pipefail

# Install ai-memory (long-term memory) as a standalone rootless Podman quadlet
# for the OpenShell path. Mirrors scripts/install-rauthy.sh.
#
# Usage: ./scripts/install-ai-memory.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/containers/systemd"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/secure-ai-homelab"
ENV_FILE="$CONFIG_DIR/ai-memory.env"
IMAGE="localhost/secure-ai-homelab/ai-memory:latest"

# --no-build: use an already-present image instead of building the Wolfi one.
# Needed on CPUs without x86-64-v2, where the Wolfi glibc cannot run. Tag the
# upstream image as $IMAGE first, e.g.
#   podman pull docker.io/akitaonrails/ai-memory:latest
#   podman tag  docker.io/akitaonrails/ai-memory:latest $IMAGE
NO_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --no-build) NO_BUILD=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# Reuse AI_MEMORY_VERSION from the repo .env if present.
if [[ -f $ROOT_DIR/.env ]]; then
  # shellcheck disable=SC1091
  set -a; . "$ROOT_DIR/.env"; set +a
fi
AI_MEMORY_VERSION="${AI_MEMORY_VERSION:-2.6.3}"

command -v podman >/dev/null 2>&1 || { echo "error: Podman is required." >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "error: openssl is required." >&2; exit 1; }
if ! systemctl --user show-environment >/dev/null 2>&1; then
  {
    echo "error: cannot reach the $USER user systemd manager."
    echo "  XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-<unset>}"
    echo "Run this from a normal login session, or enable lingering and log back in:"
    echo "  sudo loginctl enable-linger $USER"
  } >&2
  exit 1
fi

if [[ $NO_BUILD == 1 ]]; then
  podman image exists "$IMAGE" || {
    echo "error: --no-build given but image '$IMAGE' is not present." >&2
    echo "  podman pull docker.io/akitaonrails/ai-memory:latest" >&2
    echo "  podman tag  docker.io/akitaonrails/ai-memory:latest $IMAGE" >&2
    exit 1
  }
  echo "Using existing image $IMAGE (--no-build)."
else
  echo "Building ai-memory $AI_MEMORY_VERSION..."
  podman build \
    --build-arg "AI_MEMORY_VERSION=$AI_MEMORY_VERSION" \
    -t "$IMAGE" -f "$ROOT_DIR/docker/ai-memory/Containerfile" "$ROOT_DIR/docker/ai-memory"
fi

mkdir -p "$SYSTEMD_DIR" "$CONFIG_DIR"
cp "$ROOT_DIR"/deploy/ai-memory/ai-memory.container "$ROOT_DIR"/deploy/ai-memory/ai-memory-data.volume "$SYSTEMD_DIR"/

if [[ -f $ENV_FILE ]]; then
  echo "Keeping existing $ENV_FILE"
else
  root_token="$(openssl rand -base64 36 | tr -d '\n/+= ' | cut -c1-44)"
  token_pepper="$(openssl rand -base64 48 | tr -d '\n/+= ' | cut -c1-64)"
  recovery_token="$(openssl rand -base64 48 | tr -d '\n/+= ' | cut -c1-48)"
  sed -e "s|<root-token>|$root_token|" \
      -e "s|<token-pepper>|$token_pepper|" \
      -e "s|<recovery-token>|$recovery_token|" \
    "$ROOT_DIR/deploy/ai-memory/ai-memory.env.example" >"$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "Wrote $ENV_FILE with a generated root token (mode 600)."
fi

systemctl --user daemon-reload

cat <<EOF

ai-memory quadlets installed into $SYSTEMD_DIR and $ENV_FILE.

Next:
  1. systemctl --user start ai-memory.service
  2. curl -s http://127.0.0.1:49374/mcp   # 401 = auth is on
  3. ./scripts/ai-memory-user.sh add <name>      # create a person
     ./scripts/ai-memory-user.sh key <name>      # mint their aim_ API key

See docs/guides/openshell-pangolin.md.
EOF
