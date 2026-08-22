#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/firstmate-homelab"
CONFIG_FILE="$CONFIG_DIR/config"
RUN_SETUP=1

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh [--skip-setup]

Installs the global `fmh` command (and `firstmate-homelab` alias) into
~/.local/bin and records this repository as the installation directory.

By default the normal stack setup is run as part of installation. Use
--skip-setup to install only the launcher.
EOF
}

print_path_instructions() {
  local shell_name
  shell_name="$(basename "${SHELL:-sh}")"

  printf '\nNote: %s is not currently in PATH.\n' "$BIN_DIR"
  printf 'Detected login shell: %s\n\n' "$shell_name"

  case "$shell_name" in
    fish)
      cat <<'EOF'
Fish persists paths added with `fish_add_path` automatically:

  fish_add_path ~/.local/bin

The command is available immediately in the current Fish session; no shell
restart is required.
EOF
      ;;
    zsh)
      cat <<'EOF'
Add ~/.local/bin to Zsh and reload your configuration:

  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
  source ~/.zshrc
EOF
      ;;
    bash)
      cat <<'EOF'
Add ~/.local/bin to Bash and reload your configuration:

  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  source ~/.bashrc
EOF
      ;;
    ksh)
      cat <<'EOF'
Add ~/.local/bin to KornShell and reload your configuration:

  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.kshrc
  . ~/.kshrc
EOF
      ;;
    sh|dash|ash)
      cat <<'EOF'
Add ~/.local/bin to your POSIX shell profile and reload it:

  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
  . ~/.profile
EOF
      ;;
    *)
      cat <<EOF
Your shell is not one of the shells handled explicitly by the installer.
Add this directory to PATH using your shell's normal configuration mechanism:

  $BIN_DIR

For POSIX-compatible shells, this is typically:

  export PATH="\$HOME/.local/bin:\$PATH"
EOF
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-setup) RUN_SETUP=0 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "error: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

command -v docker >/dev/null 2>&1 || {
  echo "Docker is required." >&2
  exit 1
}

docker compose version >/dev/null 2>&1 || {
  echo "Docker Compose v2 is required (the 'docker compose' command)." >&2
  exit 1
}

mkdir -p "$BIN_DIR" "$CONFIG_DIR"

# Keep the global command independent from the caller's current directory.
# The config file points back to the checkout that owns compose.yaml and scripts/.
printf 'FIRSTMATE_HOMELAB_DIR=%q\n' "$ROOT_DIR" > "$CONFIG_FILE"

install -m 0755 "$ROOT_DIR/bin/fmh" "$BIN_DIR/fmh"
ln -sfn "$BIN_DIR/fmh" "$BIN_DIR/firstmate-homelab"

if [[ $RUN_SETUP -eq 1 ]]; then
  "$ROOT_DIR/scripts/setup.sh"
fi

cat <<EOF

Firstmate Homelab launcher installed.

Commands:
  fmh doctor
  fmh login
  fmh connect
  fmh help

Long name:
  firstmate-homelab <command>

Installation directory:
  $ROOT_DIR
EOF

case ":${PATH}:" in
  *":${BIN_DIR}:"*) ;;
  *) print_path_instructions ;;
esac
