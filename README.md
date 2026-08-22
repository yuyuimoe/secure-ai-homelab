# firstmate-homelab

Self-hosted Docker stack for **Firstmate + Herdr + Codex CLI**.

The goal is to keep the agent runtime, Git worktrees, GitHub credentials, and
Firstmate state on a homelab server while using Codex through a ChatGPT login.

> Herdr and Firstmate run on your infrastructure. Codex model inference still
> runs through OpenAI.

## Architecture

```text
Laptop / desktop
      |
   SSH / Tailscale
      |
Docker host
      |
      +-- firstmate container
            |
            +-- Herdr
            |    +-- Codex captain (Firstmate)
            |    +-- Codex worker
            |    +-- Codex worker
            |    +-- ...
            |
            +-- Firstmate
            +-- Treehouse worktrees
            +-- Git + GitHub CLI
            |
            +-- persistent /home/node volume
```

Firstmate's Herdr backend is currently experimental upstream. Firstmate requires
Herdr protocol 14 or newer; Herdr 0.8.0+ is preferred for its default presentation
spaces behavior.

## Requirements

On the homelab host:

- Linux
- Docker Engine
- Docker Compose v2 (`docker compose`)
- outbound HTTPS access

Nothing else needs to be installed on the host.

## Quick start

```bash
git clone https://github.com/sangimed/firstmate-homelab.git
cd firstmate-homelab

./scripts/setup.sh
./scripts/login.sh
./scripts/doctor.sh
./scripts/connect.sh
```

Or with `make`:

```bash
make setup
make login
make doctor
make connect
```

### 1. Setup

`./scripts/setup.sh`:

1. creates `.env` from `.env.example` if needed;
2. builds and starts the container;
3. installs the latest stable Herdr into the persistent agent home;
4. asks Firstmate's own bootstrap which helper tools are missing and installs
   the supported ones;
5. installs the Herdr Codex integration.

Edit `.env` to set your Git commit identity:

```dotenv
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=your-github-noreply@example.com
```

### 2. Authenticate

Run:

```bash
./scripts/login.sh
```

For Codex on a headless server, the script uses:

```bash
codex login --device-auth
```

Open the displayed URL on your normal browser and enter the one-time code. This
uses your ChatGPT/Codex entitlement rather than an OpenAI API key.

The same script then starts `gh auth login` and configures Git to use GitHub CLI
credentials.

Authentication persists in the Docker named volume.

### 3. Verify

```bash
./scripts/doctor.sh
```

The doctor checks:

- Node, Git and GitHub CLI
- Codex authentication
- Herdr
- Treehouse
- Firstmate's required `*-axi` tooling
- `no-mistakes`
- Herdr integration status
- Firstmate bootstrap diagnostics

### 4. Connect

```bash
./scripts/connect.sh
```

This attaches to the named Herdr session inside the container.

On the first empty Herdr pane, launch:

```bash
codex
```

Because the working directory is `/opt/firstmate`, Codex reads Firstmate's
`AGENTS.md` and becomes the Firstmate captain.

A useful first message is:

```text
Ahoy. Bootstrap this Firstmate installation.
Use Herdr as the runtime backend and Codex as the crew harness.
Check the toolchain and report any blocker before changing a project.
```

From that point, talk to the captain rather than manually starting workers.

## Persistence

The named volume defaults to:

```text
firstmate-homelab-home
```

It is mounted as `/home/node` and preserves:

- Codex authentication and sessions
- GitHub CLI authentication
- Herdr configuration/state
- Firstmate `config/`, `data/`, `state/` and `projects/`
- Treehouse worktrees/state
- helper tools installed in `~/.local`

Normal lifecycle commands:

```bash
docker compose down
docker compose up -d
```

Do **not** use `docker compose down -v` unless you intentionally want to delete
credentials, cloned projects, sessions, and Firstmate state.

## Updating

```bash
./scripts/update.sh
```

or:

```bash
make update
```

The image is rebuilt and the persistent toolchain is refreshed. The home volume
is kept.

For reproducibility, pin these in `.env`:

```dotenv
FIRSTMATE_REF=<firstmate commit/tag>
CODEX_VERSION=<codex npm version>
```

The defaults (`main` and `latest`) intentionally favor easy updates.

## Remote use

No port is exposed from the container.

A simple remote workflow is:

```bash
ssh homelab
cd ~/firstmate-homelab
./scripts/connect.sh
```

Using Tailscale for the SSH path avoids exposing an SSH port publicly.

## Security

The stack deliberately does **not** mount `/var/run/docker.sock`. Giving coding
agents access to the host Docker daemon is effectively giving them control over
the homelab host.

See [docs/security.md](docs/security.md) for the threat model and
[docs/architecture.md](docs/architecture.md) for the persistence/runtime design.

## Upstream documentation

- Firstmate: https://github.com/kunchenguid/firstmate
- Firstmate Herdr backend: https://github.com/kunchenguid/firstmate/blob/main/docs/herdr-backend.md
- Herdr: https://herdr.dev/
- Herdr integrations: https://herdr.dev/docs/integrations/
- Treehouse: https://github.com/kunchenguid/treehouse
- Codex authentication: https://developers.openai.com/codex/auth
