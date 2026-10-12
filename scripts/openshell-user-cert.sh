#!/usr/bin/env bash
# Mint and inspect break-glass mTLS client certificates for the OpenShell gateway.
#
# OpenShell's Debian/RPM package keeps a local PKI under
# ~/.local/state/openshell/tls/ with the CA certificate AND its private key
# (ca.crt, ca.key). This script signs one client certificate per user from that
# CA, producing a ready-to-copy mTLS bundle for the openshell CLI.
#
# Usage:
#   scripts/openshell-user-cert.sh mint <name>   # create a client bundle
#   scripts/openshell-user-cert.sh list          # list issued certificates
#   scripts/openshell-user-cert.sh revoke <name> # delete a client bundle
#
# Overridable environment:
#   OPENSHELL_TLS_DIR      gateway PKI dir   (default ~/.local/state/openshell/tls)
#   OPENSHELL_CLIENT_DIR   output dir        (default ~/.local/state/openshell/clients)
#   OPENSHELL_CLIENT_DAYS  certificate life  (default 90)
#
# NOTE: OpenShell's local CA has no CRL/OCSP, so "revoke" only removes the local
# copy. To truly invalidate a distributed certificate you must regenerate the
# gateway PKI (delete ~/.local/state/openshell/tls/ and restart the gateway),
# which invalidates EVERY client certificate. Prefer short lifetimes.

set -euo pipefail

TLS_DIR="${OPENSHELL_TLS_DIR:-$HOME/.local/state/openshell/tls}"
OUT_DIR="${OPENSHELL_CLIENT_DIR:-$HOME/.local/state/openshell/clients}"
DAYS="${OPENSHELL_CLIENT_DAYS:-90}"
CA_CRT="$TLS_DIR/ca.crt"
CA_KEY="$TLS_DIR/ca.key"
SERIAL="$OUT_DIR/.ca.srl"

die() { printf 'error: %s\n' "$1" >&2; exit 1; }
note() { printf '%s\n' "$1" >&2; }

usage() { sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

open_ui() {
  printf '\nGateway OIDC (daily):\n'
  printf '  openshell gateway add https://<alias>:17670 \\\n'
  printf '    --name homelab --oidc-issuer https://<idp>/auth/v1/ \\\n'
  printf '    --oidc-client-id openshell-cli --oidc-audience openshell-cli \\\n'
  printf '    --oidc-scopes "openid profile email roles"\n'
  printf '\nBreak-glass mTLS bundle for this user (copy the three files to):\n'
  printf '  ~/.config/openshell/gateways/homelab-mtls/mtls/\n'
  printf '  ca.crt  tls.crt  tls.key\n'
  printf 'Then:\n'
  printf '  openshell gateway add https://<alias>:17670 --name homelab-mtls\n'
}

require_pki() {
  [[ -f $CA_CRT ]] || die "CA certificate not found: $CA_CRT"
  [[ -f $CA_KEY ]] || die "CA private key not found: $CA_KEY (is the gateway installed?)"
  command -v openssl >/dev/null 2>&1 || die "openssl is required"
}

valid_name() {
  [[ $1 =~ ^[a-z0-9][a-z0-9._-]{0,62}$ ]]
}

cmd_mint() {
  local name=${1:-}
  [[ -n $name ]] || die "usage: $0 mint <name>"
  valid_name "$name" || die "invalid name '$name' (lowercase letters, digits, . _ -; max 63)"
  require_pki

  local dir="$OUT_DIR/$name"
  [[ -e $dir ]] && die "already exists: $dir (revoke it first)"

  mkdir -p "$dir"
  chmod 700 "$OUT_DIR" "$dir"

  local key="$dir/tls.key" crt="$dir/tls.crt" csr="$dir/.csr"
  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$key" 2>/dev/null
  chmod 600 "$key"

  openssl req -new -key "$key" -out "$csr" -subj "/CN=$name" \
    -addext "extendedKeyUsage=clientAuth" \
    -addext "keyUsage=digitalSignature" 2>/dev/null

  openssl x509 -req -in "$csr" \
    -CA "$CA_CRT" -CAkey "$CA_KEY" -CAserial "$SERIAL" -CAcreateserial \
    -days "$DAYS" -out "$crt" -copy_extensions copy 2>/dev/null
  rm -f "$csr"

  openssl verify -CAfile "$CA_CRT" "$crt" >/dev/null 2>&1 \
    || die "signature verification failed for $crt"

  cp "$CA_CRT" "$dir/ca.crt"
  chmod 644 "$dir/ca.crt" "$crt"

  local serial subject enddate
  serial="$(openssl x509 -in "$crt" -noout -serial | cut -d= -f2)"
  subject="$(openssl x509 -in "$crt" -noout -subject | sed 's/^subject=//')"
  enddate="$(openssl x509 -in "$crt" -noout -enddate | cut -d= -f2)"
  {
    printf 'name: %s\n' "$name"
    printf 'serial: %s\n' "$serial"
    printf 'subject: %s\n' "$subject"
    printf 'expires: %s\n' "$enddate"
  } >"$dir/mint.info"

  note "minted $name"
  note "  bundle : $dir"
  note "  serial : $serial"
  note "  expires: $enddate"
  open_ui
}

cmd_list() {
  [[ -d $OUT_DIR ]] || die "no client directory yet: $OUT_DIR"
  local found=0
  printf '%-20s %-20s %-24s %s\n' NAME SERIAL EXPIRES SUBJECT
  for crt in "$OUT_DIR"/*/tls.crt; do
    [[ -e $crt ]] || continue
    found=1
    local name serial end subject
    name="$(basename "$(dirname "$crt")")"
    serial="$(openssl x509 -in "$crt" -noout -serial 2>/dev/null | cut -d= -f2)"
    end="$(openssl x509 -in "$crt" -noout -enddate 2>/dev/null | cut -d= -f2)"
    subject="$(openssl x509 -in "$crt" -noout -subject 2>/dev/null | sed 's/^subject=//')"
    printf '%-20s %-20s %-24s %s\n' "$name" "$serial" "$end" "$subject"
  done
  (( found == 1 )) || note "no certificates issued"
}

cmd_revoke() {
  local name=${1:-}
  [[ -n $name ]] || die "usage: $0 revoke <name>"
  local dir="$OUT_DIR/$name"
  [[ -d $dir ]] || die "not found: $dir"
  rm -rf "$dir"
  note "removed $dir"
  note "WARNING: removal is local only. A copy already delivered still works."
  note "To invalidate it, regenerate the gateway PKI and restart the gateway:"
  note "  rm -rf $TLS_DIR && systemctl --user restart openshell-gateway"
  note "That invalidates every client certificate."
}

case "${1:-}" in
  mint) shift; cmd_mint "$@" ;;
  list) cmd_list ;;
  revoke) shift; cmd_revoke "$@" ;;
  -h|--help|help|"") usage 0 ;;
  *) die "unknown command: $1" ;;
esac
