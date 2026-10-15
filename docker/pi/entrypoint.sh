#!/bin/sh
# Pi workload entrypoint.
#
# OpenShell runs the workload as the image's USER (1000:1000), so there is no
# privilege to drop: just make sure the agent config dirs exist and exec.

set -e

HOME=${HOME:-/config}
export HOME
export SHELL=/bin/bash

mkdir -p "$HOME/.pi/agent" "$HOME/.claude" "$HOME/.zcode" /workspace 2>/dev/null || true

exec "$@"
