ARG DOCKER_VERSION=29
FROM docker:${DOCKER_VERSION}-cli AS docker-cli

FROM node:24-bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG FIRSTMATE_REF=main
ARG CODEX_VERSION=latest

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        bat \
        btop \
        build-essential \
        ca-certificates \
        curl \
        direnv \
        dnsutils \
        exa \
        fd-find \
        fish \
        fzf \
        gh \
        git \
        git-lfs \
        htop \
        iproute2 \
        iputils-ping \
        jq \
        less \
        lsof \
        make \
        netcat-openbsd \
        ncdu \
        openssh-client \
        procps \
        python3 \
        python3-pip \
        ripgrep \
        rsync \
        shellcheck \
        socat \
        tree \
        unzip \
        vim-tiny \
        zoxide \
    && rm -rf /var/lib/apt/lists/*

# Only the Docker client lives in the agent container. The daemon runs in the
# dedicated DinD sidecar and the homelab host socket is never mounted.
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins

RUN npm install --global "@openai/codex@${CODEX_VERSION}" \
    && npm cache clean --force

RUN git clone --filter=blob:none https://github.com/kunchenguid/firstmate.git /opt/firstmate \
    && git -C /opt/firstmate checkout "${FIRSTMATE_REF}" \
    && chown -R node:node /opt/firstmate

COPY --chown=node:node docker/entrypoint.sh /usr/local/bin/firstmate-entrypoint
COPY docker/fish/firstmate.fish /etc/fish/conf.d/firstmate.fish

RUN chmod 0755 /usr/local/bin/firstmate-entrypoint \
    && chmod 0644 /etc/fish/conf.d/firstmate.fish

ENV HOME=/home/node \
    USER=node \
    SHELL=/usr/bin/fish \
    FM_HOME=/home/node/.firstmate \
    FM_ROOT_OVERRIDE=/opt/firstmate \
    FM_BACKEND=herdr \
    HERDR_SESSION=firstmate \
    CODEX_HOME=/home/node/.codex \
    NPM_CONFIG_PREFIX=/home/node/.local \
    PATH=/home/node/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

USER node
WORKDIR /opt/firstmate

ENTRYPOINT ["/usr/local/bin/firstmate-entrypoint"]
CMD ["sleep", "infinity"]
