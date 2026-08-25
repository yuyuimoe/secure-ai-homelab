# Docker development

Firstmate Homelab gives agents a normal Docker development workflow without mounting the physical homelab Docker socket.

## How it works

The `firstmate` container contains the Docker CLI. The Docker daemon itself runs in the dedicated `docker:dind` service.

Inside `fmh shell`, Herdr panes or Treehouse worktrees, these commands work normally:

```bash
docker version
docker info
docker build .
docker compose up --build
```

The client connects to the isolated daemon over TLS at:

```text
tcp://localhost:2376
```

## Project bind mounts

A remote Docker daemon resolves bind-mount source paths in the daemon filesystem. To keep normal project-relative mounts working, Firstmate exposes its two code-bearing roots to DinD at exactly the same absolute paths:

```text
/home/node/.firstmate/projects
/home/node/.treehouse
```

That means a Compose file inside a managed project can use a normal relative bind mount:

```yaml
services:
  api:
    volumes:
      - .:/app
```

Arbitrary bind mounts from unrelated Firstmate paths are not guaranteed. Keep bind-mount sources inside a Firstmate project or Treehouse worktree, or use an inner Docker named volume.

## Networking

Firstmate and DinD share a network namespace. If a project publishes:

```yaml
services:
  web:
    ports:
      - "3000:3000"
```

agents can access it at:

```bash
curl http://localhost:3000
```

Those ports are not automatically published on the physical homelab host.

## Persistence

The inner Docker daemon stores its state in the `firstmate-homelab-dind-data` volume mounted at `/var/lib/docker`.

It preserves:

- images and layers;
- BuildKit cache;
- project containers;
- project networks;
- inner Docker named volumes such as databases.

Normal restarts and `fmh update` keep that state.

## Performance

DinD does not create another virtual machine. Inner containers still execute on the homelab Linux kernel, so CPU overhead is generally small. The most sensitive areas are storage copy-on-write, build context size, networking and filesystem-heavy dependency trees.

Use a good `.dockerignore`, especially for Node/TypeScript projects:

```dockerignore
.git
node_modules
.next
dist
coverage
```

Warm builds benefit from the persistent BuildKit and image cache.

## Diagnostics

Run:

```bash
fmh doctor
```

The doctor validates both Docker API connectivity and actual bind-mount visibility. It creates temporary markers under the project and Treehouse roots and verifies that an inner container can mount and read them.

Useful commands while troubleshooting:

```bash
fmh status
fmh logs
fmh paths
```

For the underlying design and security boundary, see [Architecture](../concepts/architecture.md) and [Security](../concepts/security.md).
