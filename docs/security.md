# Security notes

This stack executes autonomous coding agents with shell, GitHub, and Docker
capabilities. Treat the environment as a powerful development workstation.

## Current protections

- The agent-facing `firstmate` container runs as the unprivileged `node` user.
- No ordinary host directory is mounted by default.
- The physical host Docker socket is never mounted.
- Project Docker workloads run on a separate DinD daemon.
- The Docker API is not published as a host port and uses DinD-generated TLS.
- No project port is published on the physical host by Firstmate Homelab itself.
- `no-new-privileges` remains enabled on the agent-facing container.
- Secrets and state live in private Docker volumes rather than this Git repo.

## Sensitive data

The persistent home may contain:

- `~/.codex/auth.json` or other Codex credential-cache data;
- GitHub CLI credentials below `~/.config/gh`;
- SSH material if you explicitly add it later;
- source code cloned into `~/.firstmate/projects`;
- Treehouse worktrees under `~/.treehouse`;
- agent transcripts and Firstmate operational records.

Back up and expose that volume as if it contained credentials.

Never commit `.env`, Codex auth files, GitHub tokens, SSH private keys, or copies
of the volume.

## GitHub permissions

Authenticate `gh` with only the repositories and scopes the fleet actually needs.
For the initial rollout, prefer PR creation with manual merge approval over
fully autonomous merging.

## Host Docker socket

Do not add this to `compose.yaml`:

```yaml
- /var/run/docker.sock:/var/run/docker.sock
```

A process that controls the host Docker daemon can normally mount host paths and
effectively obtain root-level access to the machine.

Firstmate Homelab instead uses an isolated `docker:dind` daemon. The Docker CLI
inside Firstmate is configured to talk to that daemon only.

## What DinD can see

The DinD service receives its own `/var/lib/docker` volume and only the code-bearing
subpaths needed for bind mounts:

```text
/home/node/.firstmate/projects
/home/node/.treehouse
```

The normal Codex and GitHub credential paths are not mounted into DinD through
the Compose model.

This separation reduces accidental exposure and keeps agent-created images,
containers, networks and inner volumes separate from ordinary homelab Docker
workloads.

## Important DinD limitation

Classic Docker-in-Docker requires:

```yaml
privileged: true
```

That is a materially stronger privilege level than the Firstmate application
container and it is **not** a hard security boundary against the physical Linux
kernel. The isolation goal of this design is specifically to avoid handing agents
the existing homelab Docker daemon and its workloads.

If the threat model requires strong containment from the homelab kernel, run the
entire Firstmate Homelab stack inside a dedicated VM and treat that VM as
disposable.

## Docker API

The DinD daemon uses the official image's TLS certificate generation. Firstmate
connects to:

```text
tcp://localhost:2376
```

using a client certificate volume mounted read-only into the Firstmate container.
The two services share one network namespace so inner project ports remain
reachable at `localhost`, but the Docker API is not published on the physical
host.

## Persistent Docker state

The `dind-data` volume contains potentially sensitive development state too:

- project images and build layers;
- BuildKit cache;
- project containers;
- inner Docker named volumes, which may contain databases or application secrets.

A normal `fmh uninstall` keeps this data. `fmh uninstall --purge` deletes it along
with the Firstmate home and DinD certificate volumes.

## Supply chain

The image intentionally tracks configurable upstream references:

- `DOCKER_VERSION`
- `FIRSTMATE_REF`
- `CODEX_VERSION`

Herdr and Firstmate-managed helper tools are installed/updated by `scripts/setup.sh`
using their upstream installers and Firstmate's own bootstrap logic.

For a more reproducible deployment, pin the upstream references to reviewed
versions and record approved Herdr/helper-tool versions as part of a release
process.

See [docker-in-docker.md](docker-in-docker.md) for the detailed DinD architecture
and operational limitations.
