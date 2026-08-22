#!/usr/bin/env bash
set -euo pipefail

mkdir -p \
  "$HOME/.local/bin" \
  "$CODEX_HOME" \
  "$FM_HOME/config" \
  "$FM_HOME/data" \
  "$FM_HOME/projects" \
  "$FM_HOME/state"

if [[ ! -s "$FM_HOME/config/backend" ]]; then
  printf 'herdr\n' > "$FM_HOME/config/backend"
fi

if [[ ! -s "$FM_HOME/config/crew-harness" ]]; then
  printf 'codex\n' > "$FM_HOME/config/crew-harness"
fi

if [[ -n "${GIT_USER_NAME:-}" ]]; then
  git config --global user.name "$GIT_USER_NAME"
fi

if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
  git config --global user.email "$GIT_USER_EMAIL"
fi

git config --global init.defaultBranch main

exec "$@"
