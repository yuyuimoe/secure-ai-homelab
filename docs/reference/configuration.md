# Configuration

Configuration is split across the environment template (`.env`), the VibePod config (`~/.config/vibepod/config.yaml`), and the quadlet units.

`scripts/install.sh`, `scripts/update.sh` and `scripts/setup.sh` source `.env` (via `set -a`), so it must be valid shell syntax — quote values containing spaces. The upstream pins are passed to `podman build --build-arg`; the `AI_MEMORY_*` settings are written to `~/.config/vibepod-homelab/ai-memory.env`, which the ai-memory quadlet reads with `EnvironmentFile=`. Re-run `vph update` after editing `.env` to rebuild images and refresh that file.

## Main settings (`.env`)

| Key | Default | Meaning |
|---|---|---|
| `CONTAINER_UID` / `CONTAINER_GID` | `1000` / `1000` | UID/GID owning the persistent volumes (match your host user) |
| `PI_BOLT_VERSION` | `latest` | pi-bolt version baked into the Pi agent image |
| `CLAUDE_CODE_CHANNEL` | `latest` | Claude Code installer channel |
| `ZCODE_VERSION` | `latest` | zcode-app-cli version |
| `SHELLCHECK_VERSION` | `0.10.0` | shellcheck release |
| `AI_MEMORY_VERSION` | `2.6.3` | ai-memory version for both the control-plane CLI and the server image |
| `AI_MEMORY_AUTH_TOKEN` | empty | bearer token for ai-memory (empty = unauthenticated, loopback only) |
| `AI_MEMORY_ALLOWED_HOSTS` | `localhost,127.0.0.1,host.containers.internal` | allowed ai-memory Host headers |
| `AI_MEMORY_LLM_PROVIDER` | empty | LLM provider for ai-memory (empty = no LLM calls) |
| `AI_MEMORY_SERVER_URL` | `http://host.containers.internal:49374` | URL `setup.sh` writes into each agent's MCP config |
| `GIT_USER_NAME` / `GIT_USER_EMAIL` | — | git identity agents use for commits |

## VibePod config

Written by `vph setup` to the `vibepod-config` volume:

```yaml
version: 1
default_agent: pi
agents:
  pi:
    enabled: true
    image: vibepod/pi-bolt:latest
```

Edit it inside the control plane (`podman exec -it vibepod $EDITOR ~/.config/vibepod/config.yaml`), or pass VibePod's own environment overrides (`VP_IMAGE_PI`, `VP_DEFAULT_AGENT`, `VP_PROXY_ENABLED`, `VP_BOARD_URL`, …). See the [VibePod configuration reference](https://vibepod.dev/docs/configuration/) for the full schema (profiles, env, volumes, ports, `init`, proxy, `llm`, `board`).

## Runtime environment inside the control plane

| Variable | Value | Purpose |
|---|---|---|
| `CONTAINER_HOST` | `unix:///run/podman/podman.sock` | podman-native hint to the PinP socket (VibePod auto-detects it anyway) |
| `HOME` | `/home/developer` | control-plane home |
| `VP_DEFAULT_AGENT` | `pi` | default agent |

No `DOCKER_HOST` is set — VibePod assumes Podman when the Docker env var is absent.

## Persistent volume names

| Volume | Purpose |
|---|---|
| `vibepod-config` | agent credentials, profiles, logs, proxy |
| `pinp-data` | inner Podman images/containers |
| `pinp-socket` | shared podman unix socket |
| `ai-memory-data` | memory wiki + index |
| `workspaces` | project source |
