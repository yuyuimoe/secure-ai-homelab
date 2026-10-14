#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SOCKET="${CONTAINER_HOST:-unix:///run/podman/podman.sock}"
AI_ENV_DIR="$HOME/.config/vibepod-homelab"
AI_ENV_FILE="$AI_ENV_DIR/ai-memory.env"

# Load .env overrides (version pins, ai-memory secrets).
if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT_DIR/.env"
  set +a
fi

echo "Refreshing runtime base images..."
podman pull quay.io/podman/stable:latest

# ai-memory is built locally from the upstream release binary on Wolfi, not
# pulled: rebuild it here so version bumps in .env/Containerfile take effect.
echo "Rebuilding control plane, PinP and ai-memory images..."
podman build \
  --build-arg "SHELLCHECK_VERSION=${SHELLCHECK_VERSION:-0.10.0}" \
  --build-arg "AI_MEMORY_VERSION=${AI_MEMORY_VERSION:-2.6.3}" \
  -t localhost/vibepod-homelab/control-plane:latest -f "$ROOT_DIR/Containerfile" "$ROOT_DIR"
podman build -t localhost/vibepod-homelab/pinp:latest -f "$ROOT_DIR/docker/pinp/Containerfile" "$ROOT_DIR/docker/pinp"
podman build \
  --build-arg "AI_MEMORY_VERSION=${AI_MEMORY_VERSION:-2.6.3}" \
  -t localhost/vibepod-homelab/ai-memory:latest -f "$ROOT_DIR/docker/ai-memory/Containerfile" "$ROOT_DIR/docker/ai-memory"

echo "Rebuilding the Pi agent image into PinP..."
podman --url "$SOCKET" build \
  --build-arg "PI_BOLT_VERSION=${PI_BOLT_VERSION:-latest}" \
  --build-arg "CLAUDE_CODE_CHANNEL=${CLAUDE_CODE_CHANNEL:-latest}" \
  --build-arg "ZCODE_VERSION=${ZCODE_VERSION:-latest}" \
  --build-arg "AI_MEMORY_CLI_IMAGE=${AI_MEMORY_CLI_IMAGE:-docker.io/akitaonrails/ai-memory:latest}" \
  -t vibepod/pi:latest -f "$ROOT_DIR/docker/pi/Containerfile" "$ROOT_DIR/docker/pi"

# Refresh the ai-memory runtime env file (the unit's EnvironmentFile=).
mkdir -p "$AI_ENV_DIR"
( umask 077; cat > "$AI_ENV_FILE" <<EOF
AI_MEMORY_AUTH_TOKEN=${AI_MEMORY_AUTH_TOKEN:-}
AI_MEMORY_LLM_PROVIDER=${AI_MEMORY_LLM_PROVIDER:-}
AI_MEMORY_ALLOWED_HOSTS=${AI_MEMORY_ALLOWED_HOSTS:-localhost,127.0.0.1,host.containers.internal}
EOF
)

echo "Restarting the pod..."
systemctl --user restart vibepod-pod.service

echo
echo "Update complete. Agent credentials, memory, workspaces and PinP data were preserved."
