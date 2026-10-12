#!/usr/bin/env bash
set -euo pipefail

# Authenticate the agents and the GitHub CLI inside the control plane.
# Pi/Claude auth is done through the agent itself (Pi: /login in the TUI;
# Claude: `claude` then the login flow). GitHub CLI is shared by agents for
# commits, so it is authenticated once here.

podman exec -it vibepod fish -c '
  echo "== GitHub CLI =="
  if gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI already authenticated."
  else
    gh auth login
    gh auth setup-git
  end

  echo
  echo "== Agents =="
  echo "Start an agent and authenticate in its TUI:"
  echo "  vp run pi        # Pi-Bolt  -> run /login"
  echo "  vp run claude    # Claude Code -> /login"
'
