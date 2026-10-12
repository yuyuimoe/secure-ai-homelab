#!/usr/bin/env bash
set -euo pipefail

# Manage ai-memory users and native API keys for the OpenShell path.
#
# Runs the ai-memory CLI inside the running container, which already carries
# the root bearer token from its EnvironmentFile.
#
# Usage:
#   scripts/ai-memory-user.sh add  <username> [email]     # create a person
#   scripts/ai-memory-user.sh key  <username> [label]     # mint an aim_ API key
#   scripts/ai-memory-user.sh list                        # list users
#   scripts/ai-memory-user.sh keys <username>             # list a user's keys
#   scripts/ai-memory-user.sh revoke <api-key-id>         # revoke a key
#
# The minted key is the value to store in the OpenShell provider for that
# person (never pass it to a sandbox directly).

CONTAINER="${AI_MEMORY_CONTAINER:-ai-memory}"
AIM=(podman exec "$CONTAINER" ai-memory)

die() { printf 'error: %s\n' "$1" >&2; exit 1; }
run() { "${AIM[@]}" "$@"; }

container_up() {
  podman container exists "$CONTAINER" 2>/dev/null || die "container '$CONTAINER' not found; run systemctl --user start ai-memory.service"
  [[ "$(podman inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" == "true" ]] || die "container '$CONTAINER' is not running"
}

case "${1:-}" in
  add)
    shift
    name="${1:-}"; email="${2:-${1:-}@localhost}"
    [[ -n $name ]] || die "usage: $0 add <username> [email]"
    container_up
    run user add-human --username "$name" --email "$email" --name "$name"
    ;;
  key)
    shift
    name="${1:-}"; label="${2:-${1:-}-sandbox}"
    [[ -n $name ]] || die "usage: $0 key <username> [label]"
    container_up
    run api-key add --username "$name" --label "$label"
    ;;
  list)
    container_up
    run user list
    ;;
  keys)
    shift
    name="${1:-}"
    [[ -n $name ]] || die "usage: $0 keys <username>"
    container_up
    run api-key list --username "$name" 2>/dev/null || run api-key list
    ;;
  revoke)
    shift
    id="${1:-}"
    [[ -n $id ]] || die "usage: $0 revoke <api-key-id>"
    container_up
    run api-key revoke "$id"
    ;;
  -h|--help|help|"")
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    die "unknown command: $1"
    ;;
esac
