# CLI reference

!!! note "Previous approach"
    This page documents the earlier VibePod Homelab stack. The recommended path is [OpenShell over Pangolin](../guides/openshell-pangolin.md).

`vph` is the global launcher. It works from any directory and targets the rootless Podman pod, never the host container socket.

## Commands

| Command | Action |
|---|---|
| `vph setup` | Build the Pi agent image into PinP + write VibePod config + wire ai-memory |
| `vph login` | Authenticate the GitHub CLI (and guide agent login) |
| `vph doctor` | Verify the whole stack end to end |
| `vph connect` | Open a Herdr multiplexer session |
| `vph update` | Rebuild control plane + PinP + ai-memory + Pi agent, restart the pod |
| `vph up` / `vph down` | Start / stop the pod via systemd |
| `vph status` | Show pod and container status |
| `vph logs` | Follow control-plane, PinP and ai-memory logs |
| `vph shell` | Open the Fish developer shell |
| `vph run <agent> [args…]` | Run a VibePod agent (`pi`, `claude`, `zcode`, …) |
| `vph board <args…>` | Run `vp board` in the control plane |
| `vph help` | Show this help |

## Work from any directory

The launcher resolves the installation directory from `~/.config/vibepod-homelab/config` (written by `scripts/install.sh`), so `vph` works regardless of the current directory.

## Inspect the runtime

```bash
vph status          # pod + containers
vph logs            # follow logs
podman volume ls    # persistent volumes
```

## Update

`vph update` rebuilds the images and restarts the pod. Credentials, memory, workspaces and PinP data are preserved.

## Uninstall

```bash
systemctl --user disable --now vibepod-pod.service pinp.service vibepod.service ai-memory.service init.service
rm -f ~/.config/containers/systemd/vibepod*.{pod,container} ~/.config/containers/systemd/{pinp,ai-memory,init,workspaces}*.*
rm -f ~/.local/bin/vph ~/.local/bin/vibepod-homelab
```

Persistent volumes are left in place; delete them with `podman volume rm` if you want to purge state.
