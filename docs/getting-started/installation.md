# Installation

!!! note "Previous approach"
    This page documents the earlier VibePod Homelab stack. The recommended path is [OpenShell over Pangolin](../guides/openshell-pangolin.md).

Deploy VibePod Homelab as rootless Podman quadlets (systemd user units).

## Requirements

- Linux with Podman 5+ (pasta rootless networking)
- a user systemd session
- subordinate uid/gid ranges for PinP (see [Deployment](../reference/deployment.md#prerequisites))

## Install

```bash
git clone https://github.com/<you>/secure-ai-homelab.git
cd secure-ai-homelab

cp .env.example .env      # edit GIT_USER_NAME/EMAIL, AI_MEMORY_*, pins
./scripts/install.sh
```

`install.sh`:

1. checks Podman, the user systemd session and `/etc/subuid` ranges;
2. copies `systemd/*` quadlets into `~/.config/containers/systemd/`;
3. builds the control-plane, PinP and ai-memory images (locally, from pinned base images — no registry pull);
4. enables and starts the pod and its containers;
5. installs the `vph` launcher into `~/.local/bin`.

## Bootstrap

```bash
vph setup
```

`setup.sh` builds the Pi agent image (standard Pi + Claude Code + ZCode) **into PinP**, writes the VibePod config (default agent `pi`, image `vibepod/pi:latest`), and wires ai-memory into the Pi and Claude config dirs.

## Authenticate

```bash
vph login
```

Authenticates the GitHub CLI (shared by agents for commits). Then start each agent once and authenticate in its TUI:

```bash
vph run pi        # Pi-Bolt  -> run /login
vph run claude    # Claude Code -> /login
```

## Verify

```bash
vph doctor
```

Checks the systemd units, the control-plane tooling, the PinP socket, the ai-memory MCP endpoint, and VibePod.

## Connect

```bash
vph connect
```

Opens a Herdr multiplexer session. Run `vp run <agent>` inside a pane.

## Next steps

- [Architecture](../concepts/architecture.md) — how the pod is put together.
- [PinP development](../guides/pinp-development.md) — building/running project containers.
- [CLI reference](../reference/cli.md) — every `vph` command.
