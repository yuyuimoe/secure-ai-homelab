#!/usr/bin/env bash
set -euo pipefail

# Verify the stack end to end.
failed=0
ok()   { printf "OK   %-28s %s\n" "$1" "$2"; }
bad()  { printf "FAIL %-28s %s\n" "$1" "$2"; failed=1; }

echo "== systemd units =="
for u in vibepod-pod pinp vibepod ai-memory; do
  if systemctl --user --quiet is-active "$u.service" 2>/dev/null; then ok "$u" "active"; else bad "$u" "not active"; fi
done

echo
echo "== control plane =="
podman exec vibepod fish -c '
  for c in fish herdr vp podman ai-memory shellcheck gh git eza bat fzf zoxide rg btop direnv
    if command -v $c >/dev/null 2>&1
      echo "OK   $c"
    else
      echo "FAIL $c"
    end
  end
' || bad "control plane" "exec failed"

echo
echo "== PinP (inner podman) =="
if podman --url unix:///run/podman/podman.sock info >/dev/null 2>&1; then
  ok "pinp socket" "reachable"
  podman --url unix:///run/podman/podman.sock version --format "Client {{.Client.Version}} / Server {{.Server.Version}}" 2>/dev/null || true
else
  bad "pinp socket" "cannot reach inner podman"
fi

echo
echo "== ai-memory =="
if curl -fsS http://127.0.0.1:49374/mcp -X POST -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"doctor","version":"0"}}}' >/dev/null 2>&1; then
  ok "ai-memory" "MCP endpoint responds"
else
  bad "ai-memory" "MCP endpoint unreachable"
fi

echo
echo "== VibePod =="
podman exec vibepod vp --version 2>/dev/null && ok "vp" "installed" || bad "vp" "missing"
podman exec vibepod vp doctor pi 2>/dev/null || true

exit "$failed"
