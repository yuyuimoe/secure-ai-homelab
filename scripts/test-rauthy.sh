#!/usr/bin/env bash
# Validate the Rauthy quadlets and the installer's generated env file without
# touching real systemd state. Run before committing changes to deploy/rauthy/.
#
#   ./scripts/test-rauthy.sh
#
# Exit: 0 = all checks passed (or were skipped), 1 = a check failed.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FAILED=0
pass() { printf 'PASS  %s\n' "$1"; }
skip() { printf 'SKIP  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; FAILED=1; }

# --- 1. Quadlet renders under a real Podman generator ----------------------

GEN=""
for c in /usr/lib/systemd/user-generators/podman-user-generator \
         /usr/lib/systemd/system-generators/podman-system-generator \
         /usr/libexec/podman/quadlet; do
  [[ -x $c ]] && { GEN=$c; break; }
done

if [[ -z $GEN ]]; then
  skip "quadlet generator not found (podman < 4.4) — cannot render quadlets"
else
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/n" "$tmp/e" "$tmp/l"
  if QUADLET_UNIT_DIRS="$ROOT_DIR/deploy/rauthy" "$GEN" "$tmp/n" "$tmp/e" "$tmp/l" 2>"$tmp/err"; then
    unit="$tmp/n/rauthy.service"
    if [[ ! -f $unit ]]; then
      fail "generator produced no rauthy.service"
      sed 's/^/      /' "$tmp/err"
    else
      grep -q -- '--network host' "$unit" \
        && pass "quadlet uses host networking" \
        || fail "generated unit is missing --network host"
      grep -q -- '--env-file' "$unit" \
        && pass "quadlet reads the env file" \
        || fail "generated unit is missing --env-file"
      grep -q 'systemd-rauthy-data:/app/data' "$unit" \
        && pass "quadlet mounts the data volume" \
        || fail "generated unit is missing the data volume"
      [[ -e "$tmp/n/default.target.wants/rauthy.service" ]] \
        && pass "quadlet is auto-enabled by [Install]" \
        || fail "generated unit is not wired into default.target"
    fi
  else
    fail "quadlet generator errored"
    sed 's/^/      /' "$tmp/err"
  fi
  rm -rf "$tmp"
fi

# --- 2. Installer generates a valid env file -------------------------------

if ! systemctl --user show-environment >/dev/null 2>&1; then
  skip "no reachable user systemd manager — cannot run install-rauthy.sh"
else
  tmp="$(mktemp -d)"
  if XDG_CONFIG_HOME="$tmp" "$ROOT_DIR/scripts/install-rauthy.sh" rauthy.example.test >/dev/null 2>&1; then
    env_file="$tmp/secure-ai-homelab/rauthy.env"
    if [[ ! -f $env_file ]]; then
      fail "installer wrote no env file"
    else
      get() { grep -m1 -E "^$1=" "$env_file" | cut -d= -f2-; }
      PUB_URL="$(get PUB_URL)"
      RP_ID="$(get RP_ID)"
      RP_ORIGIN="$(get RP_ORIGIN)"
      ENC_KEYS="$(get ENC_KEYS)"
      ENC_KEY_ACTIVE="$(get ENC_KEY_ACTIVE)"
      TRUSTED_PROXIES="$(get TRUSTED_PROXIES)"
      RFC_8252_ENABLE="$(get RFC_8252_ENABLE)"
      HQL_LISTEN_ADDR_API="$(get HQL_LISTEN_ADDR_API)"
      HQL_LISTEN_ADDR_RAFT="$(get HQL_LISTEN_ADDR_RAFT)"
      HQL_NODES="$(get HQL_NODES)"
      [[ ${PUB_URL:-} == "rauthy.example.test" ]] \
        && pass "PUB_URL filled with the domain" || fail "PUB_URL not filled"
      [[ ${PUB_URL:-} != *"://"* ]] \
        && pass "PUB_URL has no scheme" || fail "PUB_URL contains a scheme"
      [[ ${RP_ID:-} == "rauthy.example.test" ]] \
        && pass "RP_ID set" || fail "RP_ID missing"
      [[ ${RP_ORIGIN:-} == "https://rauthy.example.test:443" ]] \
        && pass "RP_ORIGIN set with a port" || fail "RP_ORIGIN wrong or missing a port"
      [[ -n ${ENC_KEYS:-} && ${ENC_KEYS:-} != *"<"* ]] \
        && pass "ENC_KEYS generated" || fail "ENC_KEYS is a placeholder"
      kid="${ENC_KEYS%%/*}"
      [[ ${ENC_KEY_ACTIVE:-} == "$kid" ]] \
        && pass "ENC_KEY_ACTIVE matches ENC_KEYS key id" || fail "ENC_KEY_ACTIVE mismatch"
      [[ ${TRUSTED_PROXIES:-} == "127.0.0.1/32" ]] \
        && pass "TRUSTED_PROXIES set for host networking" || fail "TRUSTED_PROXIES wrong"
      [[ ${RFC_8252_ENABLE:-} == "true" ]] \
        && pass "RFC_8252_ENABLE set (loopback redirects match any port)" || fail "RFC_8252_ENABLE not true"
      [[ ${HQL_LISTEN_ADDR_API:-} == "127.0.0.1" && ${HQL_LISTEN_ADDR_RAFT:-} == "127.0.0.1" ]] \
        && pass "Hiqlite listeners bound to loopback" || fail "Hiqlite listeners not loopback"
      [[ ${HQL_NODES:-} == "1 localhost:8100 localhost:8200" ]] \
        && pass "HQL_NODES unquoted (podman --env-file keeps quotes)" || fail "HQL_NODES wrong: [$HQL_NODES]"
      if grep -qE '^[A-Za-z_][A-Za-z0-9_]*=.*"' "$env_file"; then
        fail "env file has a quoted value; podman --env-file passes quotes literally"
      else
        pass "no quoted values in the env file"
      fi
    fi
  else
    fail "install-rauthy.sh failed in a clean XDG_CONFIG_HOME"
  fi
  rm -rf "$tmp"
fi

if (( FAILED )); then
  printf '\nRauthy checks failed.\n'
  exit 1
fi
printf '\nRauthy checks passed.\n'
