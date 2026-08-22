# Architecture

This repository packages the Firstmate + Herdr + Codex workflow as one long-lived
Docker Compose service.

## Why one application container?

Firstmate is an agent distro, not a network service. Herdr owns real terminal
processes, while Firstmate launches workers into those terminals and Treehouse
provides isolated Git worktrees. Keeping those components in one container gives
them the same process namespace, filesystem, credentials, Git configuration, and
PTY environment.

```text
Host
└── Docker
    └── firstmate
        ├── /opt/firstmate        disposable upstream checkout
        ├── Herdr                 persistent terminal runtime
        │   ├── Codex captain
        │   ├── Codex worker A
        │   └── Codex worker B
        ├── Treehouse             isolated task worktrees
        ├── gh                    GitHub access
        └── /home/node            persistent named volume
            ├── .codex
            ├── .config
            ├── .firstmate
            ├── .local
            └── .treehouse
```

## Persistence boundary

`/opt/firstmate` belongs to the image and is deliberately disposable. Rebuilding
the image refreshes the upstream Firstmate checkout.

`/home/node` is a named Docker volume. It contains authentication caches,
Firstmate operational state, Herdr configuration/state, Treehouse data, cloned
projects, and user-space tools installed by Firstmate's bootstrap.

A container restart still terminates Linux processes. Herdr can restore compatible
agent sessions from its persisted state, but a restart is not equivalent to
detaching from a live Herdr session.

## Runtime selection

The stack sets both:

- `FM_BACKEND=herdr`
- `FM_HOME/config/backend` to `herdr`

and writes `codex` to `FM_HOME/config/crew-harness`.

The environment variable is explicit for the current process; the config files
also make the operational home self-describing.

## Networking

No inbound port is published. Codex, GitHub CLI, installers, and project tooling
use normal outbound network access.

For remote administration, SSH to the Docker host (optionally over Tailscale) and
run `./scripts/connect.sh`.

## Docker workloads launched by agents

The host Docker socket is intentionally **not** mounted into the agent container.
Mounting `/var/run/docker.sock` would give autonomous agents near-root control of
the homelab host.

If agent-managed projects need Docker, add an isolated Docker daemon sidecar
(DinD/rootless Docker) rather than exposing the host daemon.
