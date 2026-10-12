# Deployment

VibePod Homelab deploys as **rootless Podman quadlets** — systemd user units generated from `.pod`, `.container` and `.volume` files. No root, no Docker, no daemon.

## Prerequisites

- Podman 5+ (pasta rootless networking is the default; `podman info` should report `networkBackend: netavark` and rootless).
- A user systemd session with lingering enabled:
  ```bash
  loginctl enable-linger "$USER"
  ```
- Subordinate uid/gid ranges for PinP's nested user namespaces:
  ```bash
  sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USER"
  # then log out and back in so the ranges take effect
  ```
  `scripts/install.sh` checks for this and prints the command if missing.

## Unit layout

The quadlets live in `systemd/` and are copied to `~/.config/containers/systemd/` by `scripts/install.sh`:

| File | Generated unit | Role |
|---|---|---|
| `vibepod.pod` | `vibepod-pod.service` | the shared network namespace |
| `init.container` | `init.service` | one-shot seed (replaces the old `projects-init`) |
| `pinp.container` | `pinp.service` | inner Podman (Podman-in-Podman) |
| `vibepod.container` | `vibepod.service` | control plane (vp + Herdr + Fish) |
| `ai-memory.container` | `ai-memory.service` | memory server |
| `*.volume` | `*-volume.service` | named volumes |

Startup order is enforced with `After=`/`Requires=`:

```text
init.service → pinp.service → vibepod.service
                                └→ ai-memory.service
```

## Rootless PinP

PinP is the trickiest part. The pod runs rootless; inside the `pinp` container the inner podman runs as root *within the pod's user namespace*. Three things make nested containers work:

1. `UserNS=keep-id` — the container's UID maps to the host user, so volumes get correct ownership.
2. `AddCapability=SYS_ADMIN` + `Annotation=run.oci.keep_original_groups=1` — lets the inner podman create nested user namespaces and map subuid/subgid ranges.
3. `vfs` storage — no nested overlay/fuse; correctness over speed (see `docker/pinp/Containerfile`).

The inner daemon serves on `unix:///run/podman/podman.sock` (the shared `pinp-socket` volume). The control plane mounts that socket read-only at the same path; its podman client and VibePod auto-detection find it there. No `DOCKER_HOST` is set.

## The one-shot init

The old compose `projects-init` service existed only because Docker Compose `volume.subpath` requires a subdirectory to exist before the sidecar mounts it. With whole-volume mounts that quirk is gone; `init.container` still creates the agent config dirs and workspaces up front (`mkdir -p` + `chown 1000:1000`) so the first `vp run` and PinP start clean.

## ai-memory

The server runs in the pod (`ai-memory.container`), listening on `127.0.0.1:49374` on the host. Its image is built locally from `docker/ai-memory/Containerfile` — the upstream release binary on a `chainguard/wolfi-base` runtime, pinned with `AI_MEMORY_VERSION` (no Docker Hub pull). Agents spawned in PinP reach it at:

```text
http://host.containers.internal:49374
```

(`host.containers.internal` is pasta's gateway alias — from inside the inner podman network it resolves to the pod's namespace, where ai-memory listens.)

`scripts/setup.sh` wires each agent by running `ai-memory install-mcp` / `install-hooks` against the persisted agent config dirs with `AI_MEMORY_SERVER_URL` set to that URL. Configure the server in `.env`:

```bash
AI_MEMORY_AUTH_TOKEN=            # empty = zero-LLM mode
AI_MEMORY_ALLOWED_HOSTS=localhost,127.0.0.1,host.containers.internal
AI_MEMORY_LLM_PROVIDER=          # anthropic | openai | ... (empty = no LLM)
```

`.env` is sourced by the install/update/setup scripts; the three values above are written to `~/.config/vibepod-homelab/ai-memory.env`, which the ai-memory quadlet reads via `EnvironmentFile=`. Run `vph update` (or `scripts/install.sh`) after changing them.

For LAN access put TLS in front (see ai-memory's `docker/compose.tls.caddy.yml`).

## VibePod Board

`vibepod-board` is an optional task board that `vp board work` can pull tasks from. Run it as a separate compose/pod, then point the control plane at it:

```yaml
# ~/.config/vibepod/config.yaml (in the vibepod-config volume)
board:
  url: http://localhost:3000
  token: vbp_...   # project-scoped board API token
```

or export `VP_BOARD_URL` / `VP_BOARD_TOKEN` in the control plane. The token stays with `vp` and is never passed to agents.

## Herdr

Herdr is baked into the control-plane image. Start a session with `vph connect` (or `podman exec -it vibepod herdr`), then run `vp run <agent>` inside a pane — VibePod detects `HERDR_ENV=1` and wires the agent into the multiplexer with live working/blocked/idle state. No setup needed; disable with `herdr: false` in `.vibepod/config.yaml`.

## Update / teardown

```bash
vph update     # rebuild control plane + PinP + ai-memory + Pi agent, restart the pod
vph down       # stop the pod (persistent volumes survive)
```

To wipe everything (deletes credentials, memory, workspaces, PinP images):

```bash
systemctl --user stop vibepod-pod.service
for v in vibepod-config pinp-data pinp-socket ai-memory-data workspaces; do
  podman volume rm "vibepod-homelab_$v" 2>/dev/null || podman volume rm "$v"
done
```
