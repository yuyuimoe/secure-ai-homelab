# Developer shell

The control plane keeps a curated terminal environment on top of a Wolfi base. It is *not* a full desktop distribution — it is a comfortable, predictable environment for long sessions.

## Open the shell

```bash
vph shell
# or: podman exec -it vibepod fish
```

## Fish defaults

The image ships a reproducible configuration at `/etc/fish/conf.d/vibepod.fish`, applied only to interactive sessions:

- a compact prompt with Git branch information;
- `zoxide` directory jumping;
- `fzf` defaults;
- modern `ls` / `ll` / `tree` through `eza`;
- small Git aliases and directory shortcuts.

Wolfi names tools the same as Alpine, so no `batcat`/`fdfind` aliases are needed (unlike the old Debian base).

## Included toolbox

| Area | Tools |
| --- | --- |
| Shell / navigation | `fish`, `fzf`, `zoxide`, `direnv` |
| Files / search | `eza`, `bat`, `fd`, `ripgrep`, `tree`, `less` |
| Processes / resources | `btop`, `htop`, `procps`, `lsof` |
| Networking | `curl`, `bind-tools`, `iproute2`, `ping`, `netcat`, `socat`, `ssh` |
| Development | `git`, `gh`, `git-lfs`, `jq`, `make`, `shellcheck`, Python, Bun, `podman` |
| Agents / runtime | `vp` (VibePod), `herdr`, `ai-memory` |

## Why Wolfi instead of Debian?

Wolfi gives glibc (so `pi-bolt` and Claude Code's native binaries run) with apk packaging (Alpine-small). That is the combination musl/Alpine cannot provide for native agent binaries. See [Architecture](../concepts/architecture.md) for how the agent images themselves are built.

## Rebuild after image changes

```bash
vph update
```

The persistent volumes are kept across rebuilds.
