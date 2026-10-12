#!/usr/bin/env bash
set -euo pipefail

# Install the Rauthy OIDC identity provider as rootless Podman quadlets.
#
# Mirrors scripts/install.sh: copies deploy/rauthy/*.container|*.volume into
# ~/.config/containers/systemd/, generates the env file, reloads systemd.
#
# Usage: ./scripts/install-rauthy.sh [idp-domain] [port]
#
#   idp-domain   public hostname of Rauthy, for example auth.yuyui.moe.
#                Fills PUB_URL, RP_ID and RP_ORIGIN. If omitted, the <idp> /
#                <pub-url> / <rp-origin> placeholders are left for you to edit.
#   port         public HTTPS port, default 443. Only needed when the public
#                URL uses a non-standard port (e.g. 8443 behind Caddy on a
#                rehearsal host); pass the same port to install-caddy.sh.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/containers/systemd"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/secure-ai-homelab"
ENV_FILE="$CONFIG_DIR/rauthy.env"
DOMAIN="${1:-}"
PORT="${2:-443}"

command -v podman >/dev/null 2>&1 || { echo "Podman is required." >&2; exit 1; }
# Probe reachability, not `is-system-running`: that returns non-zero for a
# degraded (but perfectly usable) user manager, which caused false failures.
if ! systemctl --user show-environment >/dev/null 2>&1; then
  {
    echo "error: cannot reach the $USER user systemd manager."
    echo "  XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-<unset>}"
    echo "  DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-<unset>}"
    echo "Run this from a normal login session, or enable lingering and log back in:"
    echo "  sudo loginctl enable-linger $USER"
  } >&2
  exit 1
fi
command -v openssl >/dev/null 2>&1 || { echo "openssl is required to generate secrets." >&2; exit 1; }

mkdir -p "$SYSTEMD_DIR" "$CONFIG_DIR"
cp "$ROOT_DIR"/deploy/rauthy/rauthy.container "$ROOT_DIR"/deploy/rauthy/rauthy-data.volume "$SYSTEMD_DIR"/

if [[ -f $ENV_FILE ]]; then
  echo "Keeping existing $ENV_FILE (delete it and re-run to regenerate)."
else
  key_id="$(openssl rand -hex 4)"
  enc_key="$(openssl rand -base64 32)"
  raft="$(openssl rand -base64 48)"
  api="$(openssl rand -base64 48)"
  sed_args=(
    -e "s|<key-id>/<base64-32-bytes>|$key_id/$enc_key|"
    -e "s|<key-id>|$key_id|"
    -e "s|<raft-secret>|$raft|"
    -e "s|<api-secret>|$api|"
  )
  if [[ -n $DOMAIN ]]; then
    # PUB_URL carries the port only when it is not the default 443; RP_ID is
    # always the bare domain, and RP_ORIGIN always carries a port.
    if [[ $PORT == 443 ]]; then pub_url="$DOMAIN"; else pub_url="$DOMAIN:$PORT"; fi
    sed_args+=(
      -e "s|<pub-url>|$pub_url|g"
      -e "s|<rp-origin>|https://$DOMAIN:$PORT|g"
      -e "s|<idp>|$DOMAIN|g"
    )
  fi
  sed "${sed_args[@]}" "$ROOT_DIR/deploy/rauthy/rauthy.env.example" >"$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "Wrote $ENV_FILE with generated secrets (mode 600)."
fi

systemctl --user daemon-reload

cat <<EOF

Rauthy quadlets installed into $SYSTEMD_DIR and $ENV_FILE.

Next:
  1. edit $ENV_FILE   (set BOOTSTRAP_ADMIN_EMAIL${DOMAIN:+, and check PUB_URL / RP_ID / RP_ORIGIN})
  2. systemctl --user start rauthy.service    # [Install] enables it at boot
  3. podman logs -f rauthy      # copy the generated admin password (once)
  4. expose auth.<domain> in Pangolin -> 127.0.0.1:8080

See docs/guides/openshell-pangolin.md (Part 1).
EOF
