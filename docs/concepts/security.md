# Security

!!! note "Previous approach"
    This page documents the earlier VibePod Homelab stack. The recommended path is [OpenShell over Pangolin](../guides/openshell-pangolin.md).

VibePod Homelab runs autonomous coding agents with shell, GitHub and container capabilities. Treat it as a powerful development workstation, not as an untrusted sandbox.

## Current protections

- the pod and all containers run **rootless** (no host root, no daemon socket mounted);
- the host Podman/Docker socket is never mounted into the control plane or agents;
- agent and project containers run on a dedicated inner Podman (PinP);
- PinP is isolated in its own user namespace (`SYS_ADMIN` is granted *within* the userns, not on the host);
- project ports are not automatically published on the physical host;
- persistent secrets and state live in named volumes, not the Git repository;
- `ai-memory` binds loopback on the host and is reachable from agents only through the pod network.

## Sensitive data

Persistent volumes can contain:

- VibePod agent credentials and profiles (`vibepod-config`);
- ai-memory's memory wiki — prompts, tool calls, decisions (`ai-memory-data`);
- source code (`workspaces`);
- agent-created images, containers and inner volumes (`pinp-data`).

Treat backups or exports of these volumes as sensitive.

Never commit `.env`, agent auth files, GitHub tokens, SSH private keys, or copies of persistent volumes.

## Host socket

Do not mount these into the pod or the agent image:

```yaml
# /run/user/$UID/podman/podman.sock
# /var/run/docker.sock
```

A process controlling the host container runtime can mount host paths and effectively gain root-level control of the machine. VibePod Homelab deliberately targets the isolated PinP daemon instead.

## What PinP can see

PinP receives its own `pinp-data` volume and only the code-bearing paths VibePod needs for agent bind mounts:

```text
/home/developer/.config/vibepod   (agent config dirs)
/home/developer/workspaces        (project source)
```

The host container runtime, host filesystem and unrelated homelab workloads are not visible to PinP.

## PinP privilege limitation

Podman-in-Podman grants `CAP_SYS_ADMIN` *inside the pod's user namespace* so the inner podman can create nested user namespaces. That is a materially stronger capability than an ordinary application container, so **PinP must not be considered a hard security boundary against the Linux kernel**.

The isolation goal is narrower:

- do not hand agents the host container runtime;
- isolate agent/project container resources from normal homelab workloads;
- avoid arbitrary host-directory mounts;
- limit persistent-volume visibility to the config and workspace paths.

If you need strong isolation from the homelab kernel itself, run the whole pod inside a dedicated VM and treat that VM as disposable.

## ai-memory

ai-memory stores agent prompts, tool calls and consolidated memory. It is a server you run: set `AI_MEMORY_AUTH_TOKEN` and `AI_MEMORY_ALLOWED_HOSTS` before exposing it beyond loopback. Bearer auth does not encrypt traffic — put TLS in front (Caddy/Cloudflare templates ship with ai-memory) for LAN or remote access. See [Deployment](../reference/deployment.md).

## Supply chain

The control-plane, PinP and ai-memory images track configurable upstream versions (Wolfi bun, podman, VibePod, Herdr, ai-memory, Pi-Bolt, Claude Code, ZCode). `ai-memory` is built locally from the upstream release tarball (pinned via `AI_MEMORY_VERSION`) on a `chainguard/wolfi-base` runtime rather than pulled from Docker Hub; the Pi workload image is Wolfi + Pi-Bolt plus the native Claude Code binary. For a more reproducible deployment, pin reviewed versions and update them deliberately.

See [Architecture](architecture.md) for the complete runtime model.
