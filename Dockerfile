FROM node:24-bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG FIRSTMATE_REF=main
ARG CODEX_VERSION=latest

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        curl \
        gh \
        git \
        git-lfs \
        jq \
        less \
        lsof \
        make \
        openssh-client \
        procps \
        python3 \
        python3-pip \
        ripgrep \
        rsync \
        unzip \
    && rm -rf /var/lib/apt/lists/*

RUN npm install --global "@openai/codex@${CODEX_VERSION}" \
    && npm cache clean --force

RUN git clone --filter=blob:none https://github.com/kunchenguid/firstmate.git /opt/firstmate \
    && git -C /opt/firstmate checkout "${FIRSTMATE_REF}" \
    && chown -R node:node /opt/firstmate

COPY --chown=node:node docker/entrypoint.sh /usr/local/bin/firstmate-entrypoint

RUN chmod 0755 /usr/local/bin/firstmate-entrypoint

ENV HOME=/home/node \
    USER=node \
    SHELL=/bin/bash \
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
