# Security

Firstmate Homelab runs autonomous coding agents with shell, GitHub and Docker capabilities. Treat it as a powerful development workstation, not as an untrusted sandbox.

## Current protections

- the agent-facing `firstmate` container runs as the unprivileged `node` user;
- no ordinary host directory is mounted by default;
- the physical host Docker socket is never mounted into Firstmate;
- project Docker workloads run on a dedicated DinD daemon;
- the Docker API is not published as a physical host port and uses TLS;
- project ports are not automatically published on the physical host;
- `no-new-privileges` remains enabled on the Firstmate container;
- persistent secrets and state live in Docker volumes instead of the Git repository.

## Sensitive data

The persistent Firstmate home can contain:

- Codex authentication data;
- GitHub CLI credentials;
- source code cloned into `~/.firstmate/projects`;
- Treehouse worktrees under `~/.treehouse`;
- agent transcripts and Firstmate operational state;
- SSH material if you explicitly add it later.

Treat backups or exports of that volume as sensitive.

Never commit `.env`, Codex auth files, GitHub tokens, SSH private keys or copies of persistent volumes.

## Host Docker socket

Do not add this mount to `compose.yaml`:

```yaml
- /var/run/docker.sock:/var/run/docker.sock
```

A process controlling the host Docker daemon can normally mount host paths and effectively gain root-level control of the machine.

Firstmate Homelab deliberately uses an isolated `docker:dind` daemon instead. The Docker CLI inside Firstmate is configured to talk only to that daemon.

## What DinD can see

DinD receives its own `/var/lib/docker` volume and only the code-bearing Firstmate paths required for project bind mounts:

```text
/home/node/.firstmate/projects
/home/node/.treehouse
```

The normal Codex and GitHub credential paths are not exposed to DinD through ordinary workspace mounts.

This separation keeps agent-created images, containers, networks and inner volumes away from normal homelab Docker workloads.

## DinD privilege limitation

Classic Docker-in-Docker requires the DinD service to run with:

```yaml
privileged: true
```

That is a materially stronger privilege level than the Firstmate application container. DinD therefore **must not be considered a hard security boundary against the physical Linux kernel**.

The isolation goal is narrower:

- do not hand agents the existing homelab Docker daemon;
- isolate project Docker resources from normal homelab workloads;
- avoid arbitrary host-directory mounts;
- limit normal persistent-home visibility to project and worktree paths.

If you need strong isolation from the homelab kernel itself, run the entire Firstmate Homelab stack inside a dedicated VM and treat that VM as disposable.

## Docker API

The official DinD image generates TLS material. Firstmate connects to:

```text
tcp://localhost:2376
```

with read-only client certificates. No Docker API port is published on the physical host.

## Persistent Docker state

The `dind-data` volume may contain sensitive development state too:

- project images and build layers;
- BuildKit cache;
- project containers;
- inner Docker volumes containing databases or application secrets.

A normal `fmh uninstall` keeps this data. `fmh uninstall --purge` deletes it together with the Firstmate home and DinD certificate volumes.

## Supply chain

The image tracks configurable upstream versions for Docker, Firstmate and Codex. Herdr and helper tools are installed through their upstream installation/bootstrap mechanisms.

For a more reproducible deployment, pin reviewed versions and update them deliberately.

See [Architecture](architecture.md) for the complete runtime model.
