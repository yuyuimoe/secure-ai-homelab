#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/containers/systemd"
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vibepod-homelab"
CONFIG_FILE="$CONFIG_DIR/config"
# The ai-memory unit reads its runtime environment from here (EnvironmentFile=).
# Deliberately $HOME/.config so it matches the unit's %h/.config path.
AI_ENV_DIR="$HOME/.config/vibepod-homelab"
AI_ENV_FILE="$AI_ENV_DIR/ai-memory.env"

# Load .env overrides (version pins, ai-memory secrets). Values become the
# defaults for --build-arg and the generated ai-memory env file.
if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT_DIR/.env"
  set +a
fi

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh

Deploys the VibePod Homelab as rootless Podman quadlets (systemd user units):
  1. copies systemd/*.pod|*.container|*.volume into ~/.config/containers/systemd/
  2. builds the control-plane, PinP and ai-memory images
  3. enables and starts the pod + its containers

Requires Podman 5+ (pasta rootless networking) and a user systemd session.
EOF
}

command -v podman >/dev/null 2>&1 || { echo "Podman is required." >&2; exit 1; }
systemctl --user --quiet is-system-running 2>/dev/null || {
  printf 'A user systemd session is required (loginctl enable-linger %s).\n' "$USER" >&2
  exit 1
}

# Rootless subuid/subgid range for nested PinP containers.
if ! grep -qE "^${USER}:[0-9]+:[0-9]+" /etc/subuid 2>/dev/null; then
  cat <<'EOF' >&2
PinP needs subordinate uid/gid ranges to run nested rootless containers.
Run as root once:
    usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
then log out and back in.
EOF
  exit 1
fi

mkdir -p "$SYSTEMD_DIR"
cp "$ROOT_DIR"/systemd/*.pod "$ROOT_DIR"/systemd/*.container "$ROOT_DIR"/systemd/*.volume "$SYSTEMD_DIR"/

echo "Building control-plane image..."
podman build \
  --build-arg "SHELLCHECK_VERSION=${SHELLCHECK_VERSION:-0.10.0}" \
  --build-arg "AI_MEMORY_VERSION=${AI_MEMORY_VERSION:-2.6.3}" \
  -t localhost/vibepod-homelab/control-plane:latest -f "$ROOT_DIR/Containerfile" "$ROOT_DIR"

echo "Building PinP image..."
podman build -t localhost/vibepod-homelab/pinp:latest -f "$ROOT_DIR/docker/pinp/Containerfile" "$ROOT_DIR/docker/pinp"

echo "Building ai-memory image..."
podman build \
  --build-arg "AI_MEMORY_VERSION=${AI_MEMORY_VERSION:-2.6.3}" \
  -t localhost/vibepod-homelab/ai-memory:latest -f "$ROOT_DIR/docker/ai-memory/Containerfile" "$ROOT_DIR/docker/ai-memory"

# ai-memory runtime overrides, read by the quadlet's EnvironmentFile=. Always
# written (even empty) so the unit has a file to read after a fresh install.
mkdir -p "$AI_ENV_DIR"
( umask 077; cat > "$AI_ENV_FILE" <<EOF
AI_MEMORY_AUTH_TOKEN=${AI_MEMORY_AUTH_TOKEN:-}
AI_MEMORY_LLM_PROVIDER=${AI_MEMORY_LLM_PROVIDER:-}
AI_MEMORY_ALLOWED_HOSTS=${AI_MEMORY_ALLOWED_HOSTS:-localhost,127.0.0.1,host.containers.internal}
EOF
)

systemctl --user daemon-reload

for unit in init.service pinp.service vibepod.service ai-memory.service vibepod-pod.service; do
  systemctl --user enable --now "$unit"
done

# Install the `vph` launcher.
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
printf 'VIBEPOD_HOMELAB_DIR=%q\n' "$ROOT_DIR" > "$CONFIG_FILE"
install -m 0755 "$ROOT_DIR/bin/vph" "$BIN_DIR/vph"
ln -sfn "$BIN_DIR/vph" "$BIN_DIR/vibepod-homelab"

cat <<'EOF'

VibePod Homelab installed. Persistent volumes, the pod and the control plane
are running. Next:
  ./scripts/setup.sh      # build the Pi agent image into PinP + wire ai-memory
  ./scripts/login.sh      # authenticate agents (Pi/Claude) + GitHub CLI
  ./scripts/doctor.sh     # verify the stack
  ./scripts/connect.sh    # open a Herdr multiplexer session

EOF
