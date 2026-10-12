#!/usr/bin/env bash
set -euo pipefail

# Install Caddy as a rootless Podman quadlet, terminating TLS for Rauthy on
# hosts where Pangolin is not in front of the IdP (local VMs, rehearsal boxes).
#
# Usage: ./scripts/install-caddy.sh <idp-domain> [port]
#
#   idp-domain   hostname Caddy serves for Rauthy, e.g. auth.yuyui.moe
#   port         HTTPS port (default 443). Rootless Podman cannot bind a port
#                below net.ipv4.ip_unprivileged_port_start (1024 by default),
#                so a rehearsal host uses e.g. 8443 and passes the same port to
#                install-rauthy.sh.
#
# The script renders ~/.config/secure-ai-homelab/Caddyfile, starts the quadlet,
# then installs Caddy's internal root CA into the system trust store so the
# OpenShell gateway's OIDC discovery / JWKS fetch succeeds.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/containers/systemd"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/secure-ai-homelab"
CADDYFILE="$CONFIG_DIR/Caddyfile"
DOMAIN="${1:-}"
PORT="${2:-443}"

if [[ -z $DOMAIN ]]; then
  echo "usage: $0 <idp-domain> [port]" >&2
  exit 2
fi

command -v podman >/dev/null 2>&1 || { echo "error: Podman is required." >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "error: curl is required." >&2; exit 1; }
if ! systemctl --user show-environment >/dev/null 2>&1; then
  {
    echo "error: cannot reach the $USER user systemd manager."
    echo "  XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-<unset>}"
    echo "Run this from a normal login session, or enable lingering and log back in:"
    echo "  sudo loginctl enable-linger $USER"
  } >&2
  exit 1
fi

mkdir -p "$SYSTEMD_DIR" "$CONFIG_DIR"
cp "$ROOT_DIR"/deploy/caddy/caddy.container \
   "$ROOT_DIR"/deploy/caddy/caddy-data.volume \
   "$ROOT_DIR"/deploy/caddy/caddy-config.volume "$SYSTEMD_DIR"/

sed -e "s|<idp>|$DOMAIN|g" -e "s|<port>|$PORT|g" \
  "$ROOT_DIR/deploy/caddy/Caddyfile" >"$CADDYFILE"
echo "Wrote $CADDYFILE: https://$DOMAIN:$PORT -> 127.0.0.1:8080."

systemctl --user daemon-reload
# restart (not start): the Caddyfile is re-rendered on every run, so a live
# container must pick it up.
systemctl --user restart caddy.service

# Force a handshake so Caddy issues the leaf and materialises its internal CA.
# --resolve means this works even before an /etc/hosts entry exists.
for _ in $(seq 1 30); do
  curl -sk --resolve "$DOMAIN:$PORT:127.0.0.1" -o /dev/null "https://$DOMAIN:$PORT/" || true
  if podman exec caddy test -f /data/caddy/pki/authorities/local/root.crt 2>/dev/null; then
    break
  fi
  sleep 1
done

CA_SRC=/data/caddy/pki/authorities/local/root.crt
CA_DEST="/usr/local/share/ca-certificates/secure-ai-homelab-caddy.crt"
if ! podman exec caddy test -f "$CA_SRC" 2>/dev/null; then
  echo "warning: Caddy's root CA did not appear at $CA_SRC; skipping trust install." >&2
elif sudo -n true 2>/dev/null; then
  podman exec caddy cat "$CA_SRC" | sudo tee "$CA_DEST" >/dev/null
  sudo update-ca-certificates >/dev/null
  echo "Installed Caddy's internal root CA into $CA_DEST and refreshed the bundle."
else
  echo "warning: no passwordless sudo; not touching the system trust store." >&2
  echo "  Install the CA by hand, or set SSL_CERT_FILE for the OpenShell gateway:" >&2
  echo "    podman exec caddy cat $CA_SRC \\" >&2
  echo "      | sudo tee $CA_DEST && sudo update-ca-certificates" >&2
fi

cat <<EOF

Caddy quadlet installed. Verify discovery (add '$DOMAIN' to /etc/hosts first):

  curl -s https://$DOMAIN:$PORT/auth/v1/.well-known/openid-configuration | head

Then set the same issuer in ~/.config/openshell/gateway.toml and restart the
gateway. See docs/guides/openshell-pangolin.md (Part 1).
EOF
