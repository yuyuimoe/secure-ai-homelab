#!/bin/sh
# PinP entrypoint: start the inner podman daemon on the shared socket.
set -eu

mkdir -p /run/podman /run/containers/storage

# Storage driver is vfs (see Containerfile). Serve the Docker-compatible API
# on the shared socket; VibePod's podman client auto-detects it (no DOCKER_HOST).
exec podman system service --time 0 --log-level info unix:///run/podman/podman.sock
