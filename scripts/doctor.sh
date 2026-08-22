#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

docker compose up -d >/dev/null

docker compose exec -T firstmate bash -lc '
  set -u
  export PATH="$HOME/.local/bin:$PATH"

  failed=0

  check_command() {
    if command -v "$1" >/dev/null 2>&1; then
      printf "OK   %-22s %s\n" "$1" "$("$1" --version 2>/dev/null | head -n 1)"
    else
      printf "FAIL %-22s missing\n" "$1"
      failed=1
    fi
  }

  echo "== Core =="
  check_command node
  check_command git
  check_command gh
  check_command codex
  check_command herdr
  check_command treehouse
  check_command no-mistakes
  check_command gh-axi
  check_command chrome-devtools-axi
  check_command lavish-axi
  check_command tasks-axi
  check_command quota-axi

  echo
  echo "== Developer shell =="
  check_command fish
  check_command fzf
  check_command zoxide
  check_command rg
  check_command exa
  check_command batcat
  check_command fdfind
  check_command btop
  check_command direnv
  check_command shellcheck

  echo
  echo "== Configuration =="
  printf "SHELL:         %s\n" "${SHELL:-<unset>}"
  printf "FM_HOME:       %s\n" "$FM_HOME"
  printf "FM_BACKEND:    %s\n" "${FM_BACKEND:-<unset>}"
  printf "backend file:  %s\n" "$(cat "$FM_HOME/config/backend" 2>/dev/null || echo missing)"
  printf "crew harness:  %s\n" "$(cat "$FM_HOME/config/crew-harness" 2>/dev/null || echo missing)"

  echo
  echo "== Authentication =="
  if codex login status; then
    :
  else
    failed=1
  fi

  if gh auth status; then
    :
  else
    failed=1
  fi

  echo
  echo "== Herdr integration =="
  if herdr integration status; then
    :
  else
    failed=1
  fi

  echo
  echo "== Firstmate bootstrap =="
  cd /opt/firstmate
  bootstrap="$(
    FM_BOOTSTRAP_DETECT_ONLY=1 \
    ./bin/fm-bootstrap.sh
  )"
  if [[ -n "$bootstrap" ]]; then
    printf "%s\n" "$bootstrap"
  else
    echo "OK   Firstmate bootstrap reports no actionable problems."
  fi

  if printf "%s\n" "$bootstrap" | grep -Eq "^(MISSING|MISSING_MANUAL|NEEDS_GH_AUTH|BACKEND_INVALID):"; then
    failed=1
  fi

  exit "$failed"
'
