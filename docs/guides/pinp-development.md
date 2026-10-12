# PinP development

!!! note "Previous approach"
    This page documents the earlier VibePod Homelab stack. The recommended path is [OpenShell over Pangolin](openshell-pangolin.md).

Agents and their project containers run on **PinP** — the isolated inner Podman — not the host runtime.

## How it works

VibePod (`vp`) runs in the control plane and talks to the inner Podman over the shared socket. `vp run <agent>` spawns the agent container there. Inside an agent, project containers are built and run against the same inner Podman.

Inside an agent session, these work normally:

```bash
podman build .
podman run --rm ...
podman compose up --build
```

## Workspace mounts

VibePod mounts the current workspace at `/workspace` in the agent. The `workspaces` volume is mounted at the **same path** in both the control plane and PinP, so bind-mount sources resolve inside the inner daemon:

```text
/home/developer/workspaces
```

## Networking

Agents spawned in PinP reach the pod (and ai-memory) through the pasta gateway alias:

```text
http://host.containers.internal:49374
```

Ports an agent publishes are reachable from the control plane at `localhost`, but are not automatically published on the host. Publish explicitly with VibePod's `agents.<agent>.ports` if you need host access.

## Persistence

The inner Podman stores images, build cache, containers and inner volumes in the `pinp-data` volume. Normal restarts and `vph update` keep it.

## Diagnostics

```bash
vph doctor
podman --url unix:///run/podman/podman.sock ps -a    # inner containers
podman --url unix:///run/podman/podman.sock images   # inner images
```

See [Architecture](../concepts/architecture.md) for the underlying design and [Security](../concepts/security.md) for the trust boundary.
