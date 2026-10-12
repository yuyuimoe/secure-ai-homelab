#!/usr/bin/env bash
set -euo pipefail

# Open an interactive Fish shell in the control plane, then a Herdr session
# for multiplexed agent panes (run `vp run pi` inside a pane).
podman exec -it vibepod fish -c 'exec herdr'
