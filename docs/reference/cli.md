# CLI reference

`fmh` is the host-side launcher for Firstmate Homelab. The installer also creates the longer `firstmate-homelab` alias.

The launcher remembers the repository checkout path, so commands work from any current directory.

## Commands

| Command | Purpose |
| --- | --- |
| `fmh setup` | Build/start the stack and provision Firstmate tooling |
| `fmh login` | Authenticate Codex and GitHub CLI |
| `fmh doctor` | Verify tooling, authentication, DinD and shared workspaces |
| `fmh connect` | Attach to the persistent Herdr session |
| `fmh update` | Refresh the stack while preserving persistent state |
| `fmh up` | Start Firstmate and DinD |
| `fmh down` | Stop the Compose stack |
| `fmh status` | Show Compose service status |
| `fmh logs` | Follow Firstmate and DinD logs |
| `fmh shell` | Open the Fish developer shell |
| `fmh projects` | List Firstmate-managed projects |
| `fmh paths` | Show installation, volume and Docker paths |
| `fmh uninstall` | Remove launcher/runtime containers while keeping persistent data |
| `fmh uninstall --purge` | Delete persistent Firstmate and DinD data too |
| `fmh help` | Show command help |

## Work from any directory

These all target the same installation:

```bash
cd /tmp && fmh status
cd ~ && fmh doctor
cd ~/some-project && fmh connect
```

The caller's current directory is not implicitly treated as a Firstmate workspace.

## Inspect the runtime

```bash
fmh status
fmh logs
fmh paths
```

`fmh paths` reports the actual Docker volume mountpoints instead of assuming a host storage path.

## Interactive sessions

Open a regular Fish shell:

```bash
fmh shell
```

Leave with `exit` or `Ctrl+D`.

Attach to Herdr:

```bash
fmh connect
```

Detach without stopping panes or agents with:

```text
Ctrl+B, then Q
```

## Update

```bash
fmh update
```

The update flow pulls runtime images, rebuilds the disposable Firstmate image and refreshes persistent user-space tooling.

It preserves:

- Codex and GitHub authentication;
- Firstmate and Herdr state;
- projects and Treehouse worktrees;
- DinD images and BuildKit cache;
- project containers and inner Docker volumes;
- DinD TLS material.

## Uninstall

A safe uninstall keeps persistent data:

```bash
fmh uninstall
```

A full purge deletes Firstmate state, project clones, worktrees, DinD images, containers, build cache, inner volumes and TLS material:

```bash
fmh uninstall --purge
```

The purge requires typing `purge` explicitly. Automation can opt into destructive removal with:

```bash
fmh uninstall --purge --yes
```

The repository checkout itself is never deleted automatically.
