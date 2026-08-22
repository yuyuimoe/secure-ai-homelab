# Security notes

This stack executes autonomous coding agents with shell and GitHub access. Treat
the container as a privileged development environment even though it does not run
as root.

## Current protections

- The application runs as the unprivileged `node` user.
- No host directory is mounted by default.
- The host Docker socket is not mounted.
- No inbound container ports are published.
- `no-new-privileges` is enabled.
- Secrets and state live in the private Docker volume rather than this Git repo.

## Sensitive data

The persistent home may contain:

- `~/.codex/auth.json` or other Codex credential-cache data.
- GitHub CLI credentials below `~/.config/gh`.
- SSH material if you explicitly add it later.
- Source code cloned into `~/.firstmate/projects`.
- Agent transcripts and Firstmate operational records.

Back up and expose that volume as if it contained credentials.

Never commit `.env`, Codex auth files, GitHub tokens, SSH private keys, or copies
of the volume.

## GitHub permissions

Authenticate `gh` with only the repositories and scopes the fleet actually needs.
For the initial rollout, prefer PR creation with manual merge approval over
fully autonomous merging.

## Docker socket

Do not add this to `compose.yaml`:

```yaml
- /var/run/docker.sock:/var/run/docker.sock
```

A process that controls the host Docker daemon can normally mount host paths and
effectively obtain root-level access to the machine.

Use an isolated Docker daemon sidecar if project tests require Docker.

## Supply chain

The image intentionally tracks configurable upstream references:

- `FIRSTMATE_REF`
- `CODEX_VERSION`

Herdr and Firstmate-managed helper tools are installed/updated by `scripts/setup.sh`
using their upstream installers and Firstmate's own bootstrap logic.

For a more reproducible deployment, pin `FIRSTMATE_REF` to a reviewed commit and
`CODEX_VERSION` to a reviewed CLI version, and record approved Herdr/helper-tool
versions as part of a release process.
