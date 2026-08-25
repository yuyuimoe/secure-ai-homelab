# Installation

## Requirements

The homelab host needs:

- Linux;
- Docker Engine 26 or newer;
- Docker Compose v2 with `volume.subpath` support;
- outbound HTTPS access.

Nothing else is required on the host.

## Install

Clone the repository and run the installer:

```bash
git clone https://github.com/sangimed/firstmate-homelab.git
cd firstmate-homelab
./scripts/install.sh
```

The installer:

1. validates Docker and Compose support;
2. records the checkout path under `~/.config/firstmate-homelab/`;
3. installs the global `fmh` launcher and `firstmate-homelab` alias in `~/.local/bin`;
4. creates `.env` from `.env.example` when needed;
5. initializes the shared project/worktree paths;
6. starts Firstmate and the isolated DinD daemon;
7. installs or updates Herdr in the persistent agent home;
8. runs Firstmate's bootstrap for supported helper tools;
9. installs the Herdr Codex integration.

To install only the global launcher without provisioning the stack:

```bash
./scripts/install.sh --skip-setup
```

## PATH

If `~/.local/bin` is not already in your `PATH`, the installer prints shell-specific instructions for Fish, Zsh, Bash and other common shells.

## Configure Git identity

Edit `.env` before first use if you want to customize the Git identity used by agents:

```dotenv
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=your-github-noreply@example.com
```

Version and volume settings are documented in [Configuration](../reference/configuration.md).

## Authenticate

Run:

```bash
fmh login
```

For Codex on a headless server, the login flow uses device authentication. Open the displayed URL in your normal browser and enter the one-time code.

The same command authenticates GitHub CLI and configures Git to use the GitHub CLI credential helper. Authentication is stored in the persistent Firstmate home.

## Verify

Run:

```bash
fmh doctor
```

The doctor checks the core toolchain, authentication, DinD connectivity, Firstmate configuration, Herdr integration and real bind-mount visibility for project and Treehouse paths.

## Connect

Attach to the persistent Herdr session:

```bash
fmh connect
```

On an empty Herdr pane, launch Codex:

```bash
codex
```

Because the working directory is `/opt/firstmate`, Codex reads Firstmate's `AGENTS.md` and can act as the Firstmate captain.

To detach from the Herdr session without stopping its panes or agents:

```text
Ctrl+B, then Q
```

Return later with `fmh connect`.

For an ordinary developer shell opened with `fmh shell`, leave with `exit` or `Ctrl+D`.

## Next steps

- [CLI reference](../reference/cli.md)
- [Docker development](../guides/docker-development.md)
- [Architecture](../concepts/architecture.md)
