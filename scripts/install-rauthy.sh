#!/usr/bin/env bash
set -euo pipefail

# Install the Rauthy OIDC identity provider as rootless Podman quadlets.
#
# Mirrors scripts/install.sh: copies deploy/rauthy/*.container|*.volume into
# ~/.config/containers/systemd/ and seeds the env file, then reloads systemd.
#
# Usage: ./scripts/install-rauthy.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/containers/systemd"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/secure-ai-homelab"
ENV_FILE="$CONFIG_DIR/rauthy.env"

command -v podman >/dev/null 2>&1 || { echo "Podman is required." >&2; exit 1; }
systemctl --user --quiet is-system-running 2>/dev/null || {
  printf 'A user systemd session is required (loginctl enable-linger %s).\n' "$USER" >&2
  exit 1
}

mkdir -p "$SYSTEMD_DIR" "$CONFIG_DIR"
cp "$ROOT_DIR"/deploy/rauthy/rauthy.container "$ROOT_DIR"/deploy/rauthy/rauthy-data.volume "$SYSTEMD_DIR"/

if [[ -f $ENV_FILE ]]; then
  echo "Keeping existing $ENV_FILE"
else
  command -v openssl >/dev/null 2>&1 || { echo "openssl is required to generate secrets." >&2; exit 1; }
  key_id="$(openssl rand -hex 4)"
  enc_key="$(openssl rand -base64 32)"
  raft="$(openssl rand -base64 48)"
  api="$(openssl rand -base64 48)"
  # Replace the placeholders in the template with generated values. Rauthy needs
  # both ENC_KEYS and ENC_KEY_ACTIVE, so generate both together.
  sed -e "s|<key-id>/<base64-32-bytes>|$key_id/$enc_key|" \
      -e "s|<key-id>|$key_id|" \
      -e "s|<raft-secret>|$raft|" \
      -e "s|<api-secret>|$api|" \
      "$ROOT_DIR/deploy/rauthy/rauthy.env.example" >"$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "Wrote $ENV_FILE with generated secrets (mode 600)."
fi

systemctl --user daemon-reload

cat <<EOF

Rauthy quadlets installed into $SYSTEMD_DIR and $ENV_FILE.

Next:
  1. edit $ENV_FILE   (PUB_URL + admin email; secrets already generated)
  2. systemctl --user start rauthy.service    # [Install] enables it at boot
  3. podman logs -f rauthy      # copy the generated admin password (once)
  4. expose auth.<domain> in Pangolin -> localhost:8080

See docs/guides/openshell-pangolin.md (Part 1).
EOF
