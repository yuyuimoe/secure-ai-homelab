# VibePod Homelab — control plane.
#
# Long-lived developer + agent-runner environment. It holds the VibePod CLI
# (`vp`), Herdr (terminal multiplexer), the Fish developer shell, the podman
# client (talks to the PinP socket) and the ai-memory CLI (wires memory into
# agent config dirs).
#
# Base: Chainguard Wolfi (glibc + apk). Wolfi is glibc (so native agent binaries
# run) but apk-based (Alpine-small); Bun comes from the Wolfi package, so the
# image stays a plain `wolfi-base` rather than an apko-built distroless variant
# (which has no shell and cannot run `apk`/`RUN` steps). The agent runtime
# itself lives in the PinP podman, not here; this container is the control plane
# only.

FROM docker.io/chainguard/wolfi-base:latest

# Wolfi runs as non-root (UID 65532) by default; install as root, drop back.
USER root

ARG SHELLCHECK_VERSION=0.10.0
ARG AI_MEMORY_VERSION=2.6.3
ENV HERDR_INSTALL_DIR=/usr/local/bin

# --- Developer toolbox (Wolfi apk). Names differ from Debian:               ---
#     exa -> eza, batcat -> bat, fd-find -> fd, dnsutils -> bind-tools.       ---
RUN apk add --no-cache \
        bash bun ca-certificates curl git gh git-lfs jq make less rsync unzip xz \
        fish fzf zoxide eza bat btop direnv ripgrep htop procps lsof tree \
        netcat-openbsd socat iproute2 bind-tools openssh \
        python-3.12 py3.12-pip vim podman \
    && ln -sf /usr/bin/eza /usr/local/bin/exa \
    && ln -sf /usr/bin/fd  /usr/local/bin/fdfind \
    && rm -rf /var/cache/apk/*

# shellcheck is not packaged for Wolfi; install the static release binary
# (glibc-linked, so it runs on Wolfi).
RUN set -eux; \
    curl -fsSL "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz" -o /tmp/sc.tar.xz \
    && tar -xJf /tmp/sc.tar.xz -C /tmp \
    && cp "/tmp/shellcheck-v${SHELLCHECK_VERSION}/shellcheck" /usr/local/bin/shellcheck \
    && chmod 0755 /usr/local/bin/shellcheck \
    && rm -rf /tmp/sc.tar.xz "/tmp/shellcheck-v${SHELLCHECK_VERSION}"

# --- VibePod CLI (container-based agent runner) -----------------------------
RUN python3 -m pip install --no-cache-dir vibepod

# --- Herdr (terminal multiplexer) ------------------------------------------
RUN curl -fsSL https://herdr.dev/install.sh | sh \
    && test -x "${HERDR_INSTALL_DIR}/herdr"

# --- ai-memory CLI (installs MCP config + lifecycle hooks into agents) ------
RUN set -eux; \
    curl -fsSL "https://github.com/akitaonrails/ai-memory/releases/download/v${AI_MEMORY_VERSION}/ai-memory-linux-x86_64.tar.gz" -o /tmp/aim.tar.gz \
    && mkdir -p /opt/ai-memory \
    && tar -xzf /tmp/aim.tar.gz -C /opt/ai-memory \
    && ln -sf /opt/ai-memory/ai-memory /usr/local/bin/ai-memory \
    && chmod 0755 /opt/ai-memory/ai-memory \
    && rm -f /tmp/aim.tar.gz

# --- Fish configuration -----------------------------------------------------
COPY docker/fish/vibepod.fish /etc/fish/conf.d/vibepod.fish

# --- developer user (uid/gid 1000) that owns the persistent config dirs -----
RUN addgroup -g 1000 developer \
    && adduser -u 1000 -G developer -h /home/developer -s /usr/bin/fish -D developer \
    && mkdir -p /home/developer/.config/vibepod /home/developer/workspaces \
    && chown -R developer:developer /home/developer

ENV HOME=/home/developer \
    USER=developer \
    SHELL=/usr/bin/fish \
    PATH=/home/developer/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

USER developer
WORKDIR /home/developer

# Long-lived: the operator attaches with `podman exec -it vibepod fish` (or
# starts a herdr session). VibePod itself is invoked per-run (`vp run pi`).
CMD ["sleep", "infinity"]
