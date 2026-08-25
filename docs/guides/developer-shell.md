# Developer shell

Firstmate Homelab keeps the stable `node:24-bookworm-slim` base image and layers a curated terminal environment on top.

The goal is not to reproduce a full desktop distribution inside Docker. It is to provide a comfortable, predictable environment for long development sessions.

## Open the shell

```bash
fmh shell
```

This opens **Fish** inside the Firstmate container. Bash remains installed and is used explicitly by project scripts and automation.

## Fish defaults

The image ships its reproducible configuration under:

```text
/etc/fish/conf.d/firstmate.fish
```

It is applied only to interactive Fish sessions and includes:

- Fish syntax highlighting and autosuggestions;
- a compact prompt with Git branch information;
- `zoxide` directory jumping;
- `fzf` defaults;
- aliases for Debian's `batcat` and `fdfind`;
- modern `ls`, `ll` and `tree` output through `exa`;
- small Git aliases;
- directory shortcuts such as `..`, `...` and `....`.

The project deliberately avoids a large plugin manager so the interactive environment remains reproducible from the image.

## Included toolbox

| Area | Tools |
| --- | --- |
| Shell / navigation | `fish`, `fzf`, `zoxide`, `direnv` |
| Files / search | `exa`, `bat`, `fd`, `ripgrep`, `tree`, `less` |
| Processes / resources | `btop`, `htop`, `ncdu`, `procps`, `lsof` |
| Networking | `curl`, `dnsutils`, `iproute2`, `ping`, `netcat`, `socat`, `ssh` |
| Development | `git`, `gh`, `git-lfs`, `jq`, `make`, `shellcheck`, Python, Node, Docker CLI |

Debian installs two commands under different executable names to avoid package conflicts:

```text
batcat  -> exposed as `bat` in interactive Fish
fdfind  -> exposed as `fd` in interactive Fish
```

## Rebuild after image changes

Changes to the developer shell live in the Firstmate image. Apply them with:

```bash
fmh update
```

or during setup:

```bash
fmh setup
```

The persistent `/home/node` volume is kept across rebuilds.

## Why Debian instead of a rolling base?

Using an Arch-derived container would provide newer packages, but it would also increase runtime volatility and diverge from the upstream Node image.

Debian gives this project a useful balance:

- predictable image builds;
- broad package availability;
- upstream Node compatibility;
- lower maintenance churn.

The interactive layer can still feel modern without coupling the runtime to a rolling-release base.
