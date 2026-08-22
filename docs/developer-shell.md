# Developer shell

Firstmate Homelab deliberately keeps the stable `node:24-bookworm-slim` base image, but layers a curated terminal environment on top of it.

The goal is not to reproduce CachyOS inside Docker. The goal is to bring the parts that matter during long interactive development sessions: a good shell, modern CLI tools, fast navigation, useful diagnostics and sensible defaults.

## Interactive shell

`fmh shell` opens **Fish** inside the Firstmate container:

```bash
fmh shell
```

Fish is also exposed through the container's `SHELL` environment variable.

Bash remains installed and is still used explicitly by the project scripts and automation. This keeps the interactive experience separate from script compatibility.

## Fish defaults

The image ships a reproducible configuration under:

```text
/etc/fish/conf.d/firstmate.fish
```

It is only applied to interactive Fish sessions.

The configuration includes:

- Fish's native syntax highlighting and autosuggestions
- a compact Matrix-green prompt
- Git branch display in the prompt
- `zoxide` directory jumping
- `fzf` defaults for fuzzy workflows
- ergonomic aliases for Debian's `batcat` and `fdfind`
- modern `ls`/`ll`/`tree` output through `exa`
- small Git aliases (`gs`, `gl`, `gd`, `gds`)
- directory shortcuts (`..`, `...`, `....`)

The project intentionally avoids a large Fish plugin manager and a long plugin list. Fish already provides the most important interactive features natively, and keeping the configuration in the image makes rebuilds predictable.

## CLI toolbox

The container includes a terminal-oriented toolbox for development and homelab troubleshooting:

| Area | Tools |
| --- | --- |
| shell/navigation | `fish`, `fzf`, `zoxide`, `direnv` |
| files/search | `exa`, `bat`, `fd`, `ripgrep`, `tree`, `less` |
| process/resources | `btop`, `htop`, `ncdu`, `procps`, `lsof` |
| networking | `curl`, `dnsutils`, `iproute2`, `ping`, `netcat`, `socat`, `ssh` |
| development | `git`, `gh`, `git-lfs`, `jq`, `make`, `shellcheck`, Python, Node |

Debian names two commands differently to avoid package conflicts:

```text
batcat  -> exposed as `bat` in interactive Fish
fdfind  -> exposed as `fd` in interactive Fish
```

## Rebuild after an update

Changes to the shell layer live in the Docker image, so update/rebuild the stack with:

```bash
fmh update
```

or during initial setup:

```bash
fmh setup
```

The persistent `/home/node` volume remains untouched.

## Why not CachyOS as the container base?

Using CachyOS/Arch as the runtime base would provide newer packages, but it would also make the image more volatile and move the project away from the upstream Node Debian image.

For this project, Debian provides a better boundary:

- stable and predictable image builds
- broad package availability
- upstream Node compatibility
- less maintenance churn

The interactive layer can still feel modern without coupling the runtime to a rolling-release distribution.
