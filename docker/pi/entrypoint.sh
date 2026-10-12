#!/bin/sh
# VibePod Homelab — Pi agent entrypoint.
# Handles dynamic UID/GID mapping (VibePod passes USER_UID/USER_GID) so files
# written into the workspace and the mounted config dir belong to the host
# user. Adapted from VibePod's own pi entrypoint, using gosu (Debian ships it).

set -e

USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}
HOME=${HOME:-/config}

export HOME
export SHELL=/bin/bash

# Already non-root (OpenShell runs the workload as the image's USER): there is
# no privilege to drop, so just make sure the config dirs exist and exec.
if [ "$(id -u)" -ne 0 ]; then
    mkdir -p "$HOME/.pi/agent" "$HOME/.claude" "$HOME/.zcode" /workspace 2>/dev/null || true
    exec "$@"
fi

mkdir -p "$HOME" "$HOME/.pi/agent" "$HOME/.claude" "$HOME/.zcode" /workspace

if [ "$USER_UID" -eq 0 ]; then
    exec "$@"
fi

GROUP_NAME=pi
if getent group "$USER_GID" >/dev/null 2>&1; then
    EXISTING_GROUP=$(getent group "$USER_GID" | cut -d: -f1)
    [ -z "$EXISTING_GROUP" ] || GROUP_NAME="$EXISTING_GROUP"
else
    groupadd -g "$USER_GID" pi 2>/dev/null || true
fi

if ! getent passwd "$USER_UID" >/dev/null 2>&1; then
    useradd -m -u "$USER_UID" -g "$GROUP_NAME" -d "$HOME" -s /bin/sh pi 2>/dev/null || true
fi

chown "$USER_UID:$USER_GID" "$HOME" "$HOME/.pi" "$HOME/.pi/agent" 2>/dev/null || true
chown "$USER_UID:$USER_GID" "$HOME/.claude" "$HOME/.zcode" 2>/dev/null || true
chmod 755 "$HOME" "$HOME/.pi" "$HOME/.pi/agent" "$HOME/.claude" "$HOME/.zcode" /workspace 2>/dev/null || true

export USER="pi"
export LOGNAME="pi"

exec gosu "$USER_UID:$USER_GID" "$@"
