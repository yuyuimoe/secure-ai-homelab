#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SOCKET="${CONTAINER_HOST:-unix:///run/podman/podman.sock}"

# Load .env overrides (agent version pins, ai-memory endpoint/token).
if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT_DIR/.env"
  set +a
fi

# In-container path of the vibepod-config volume (same in the control plane
# and PinP, so VibePod's agent config-dir mounts resolve inside the inner daemon).
CFG="/home/developer/.config/vibepod"

# Ensure the pod + control plane are up first.
systemctl --user start vibepod-pod.service pinp.service vibepod.service 2>/dev/null || true

podman_in() { podman --url "$SOCKET" "$@"; }

echo "Building the Pi agent image (pi-bolt + claude + zcode) into PinP..."
# `podman build` targets the INNER daemon through the shared socket, so the
# image lands in PinP storage with no registry involved (fully self-hosted).
podman_in build \
  --build-arg "PI_BOLT_VERSION=${PI_BOLT_VERSION:-latest}" \
  --build-arg "CLAUDE_CODE_CHANNEL=${CLAUDE_CODE_CHANNEL:-latest}" \
  --build-arg "ZCODE_VERSION=${ZCODE_VERSION:-latest}" \
  -t vibepod/pi-bolt:latest -f "$ROOT_DIR/docker/pi/Containerfile" "$ROOT_DIR/docker/pi"

echo "Writing VibePod config (default agent pi, image vibepod/pi-bolt:latest)..."
podman exec vibepod sh -c "mkdir -p '$CFG' && cat > '$CFG/config.yaml'" <<'YAML'
version: 1
default_agent: pi
agents:
  pi:
    enabled: true
    image: vibepod/pi-bolt:latest
    env: {}
YAML

# ai-memory: reachable from PinP agents through the pasta gateway alias.
AI_MEMORY_URL="${AI_MEMORY_SERVER_URL:-http://host.containers.internal:49374}"
echo "Wiring ai-memory into the Pi and Claude config dirs (server: $AI_MEMORY_URL)..."

wire_ai_memory() {
  local agent_dir="$1" client="$2" agent="$3"
  podman exec vibepod sh -lc "
    export AI_MEMORY_SERVER_URL='$AI_MEMORY_URL'
    export AI_MEMORY_AUTH_TOKEN='${AI_MEMORY_AUTH_TOKEN:-}'
    mkdir -p '$agent_dir'
    HOME='$agent_dir' ai-memory install-mcp --client '$client' --apply || true
    HOME='$agent_dir' ai-memory install-hooks --agent '$agent' --apply || true
  "
}

wire_ai_memory "$CFG/agents/pi"     pi          pi
wire_ai_memory "$CFG/agents/claude" claude-code claude-code

echo
echo "Base stack ready."
echo "Next:"
echo "  ./scripts/login.sh   # authenticate agents + GitHub CLI"
echo "  ./scripts/doctor.sh  # verify"
echo "  ./scripts/connect.sh # open Herdr"
