#!/usr/bin/env bash
# Diagnose an OpenShell gateway.toml that `config preflight` rejects as
# "category=malformed". The preflight deliberately prints no detail, so this
# locates the offending key/line instead.
#
# Usage: scripts/check-openshell-gateway-config.sh [path]
#   default path: ~/.config/openshell/gateway.toml
#
# Exit: 0 = valid, 1 = a problem was found, 2 = usage/environment error.

set -uo pipefail

GW="${OPENSHELL_GATEWAY_BIN:-/usr/bin/openshell-gateway}"
CFG="${1:-$HOME/.config/openshell/gateway.toml}"

[[ -r $CFG ]] || { echo "error: cannot read '$CFG'" >&2; exit 2; }
command -v "$GW" >/dev/null 2>&1 || { echo "error: openshell-gateway not found" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "error: python3 required" >&2; exit 2; }

echo "config: $CFG"

# --- 1. TOML syntax, duplicate keys and duplicate tables -------------------
if ! python3 - "$CFG" <<'PY'
import sys, tomllib
try:
    tomllib.load(open(sys.argv[1], "rb"))
except Exception as e:
    print(f"syntax: FAIL\n  {e}")
    sys.exit(1)
print("syntax: OK")
PY
then
  exit 1
fi

# --- 2. Does preflight actually fail? --------------------------------------
if "$GW" config preflight --path "$CFG" >/dev/null 2>&1; then
  echo "preflight: PASS — nothing to diagnose"
  exit 0
fi
echo "preflight: FAIL (category=malformed)"

# --- 3. Find the offending line by removing candidates ---------------------
# Try removing each assignment line and keep the first removal that makes
# preflight pass. Unknown keys, wrong types and duplicate assignments are all
# single lines, so this pinpoints them.
echo "searching..."
mapfile -t LINES < <(grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_.-]*[[:space:]]*=' "$CFG" | cut -d: -f1)
culprit=""
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
for ln in "${LINES[@]}"; do
  sed "${ln}d" "$CFG" >"$tmp"
  if "$GW" config preflight --path "$tmp" >/dev/null 2>&1; then
    culprit="$ln"
    break
  fi
done

if [[ -n $culprit ]]; then
  echo "offending line $culprit:"
  sed -n "${culprit}p" "$CFG" | sed 's/^/    /'
  echo
  echo "Fix or remove that line. Note the key is compute_driver (singular);"
  echo "'compute_drive' and 'compute_drivers' are rejected as unknown fields."
  exit 1
fi

echo "could not isolate a single line. Common causes:"
echo "  - a duplicate [table] header"
echo "  - a key in the wrong table"
echo "  - a value of the wrong type"
echo "Compare against the schema:"
echo "  https://docs.nvidia.com/openshell/latest/how-it-works/gateways/configuration"
exit 1
