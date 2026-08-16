FROM debian:13-slim

ARG BUILD_ARCH
ARG BUILD_VERSION=dev
ARG CODEX_VERSION=0.147.0
ARG GH_KEYRING_SHA256=6084d5d7bd8e288441e0e94fc6275570895da18e6751f70f057485dc2d1a811b
ARG TARGETARCH
ARG TTYD_VERSION=1.7.7

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV CODEX_HOME=/config/codex \
    DEBIAN_FRONTEND=noninteractive \
    EDITOR=vim \
    GH_CONFIG_DIR=/config/gh \
    GIT_CONFIG_GLOBAL=/config/git/config \
    HISTFILE=/config/shell/bash_history \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    TERM=xterm-256color

# Debian security updates are resolved when the App image is built.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash-completion \
        bubblewrap \
        build-essential \
        ca-certificates \
        curl \
        dnsutils \
        file \
        git \
        gzip \
        iproute2 \
        iputils-ping \
        jq \
        less \
        lsof \
        nano \
        netcat-openbsd \
        nodejs \
        npm \
        openssh-client \
        openssh-server \
        procps \
        python3 \
        python3-pip \
        python3-venv \
        ripgrep \
        rsync \
        sudo \
        tar \
        tini \
        tmux \
        tzdata \
        unzip \
        vim \
        wget \
        zip \
    && rmdir /root/.ssh \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI from GitHub's official APT repository.
# hadolint ignore=DL3008
RUN install -d -m 0755 /etc/apt/keyrings /etc/apt/sources.list.d \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /tmp/githubcli-archive-keyring.gpg \
    && echo "${GH_KEYRING_SHA256}  /tmp/githubcli-archive-keyring.gpg" | sha256sum -c - \
    && install -m 0644 /tmp/githubcli-archive-keyring.gpg \
        /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -f /tmp/githubcli-archive-keyring.gpg \
    && rm -rf /var/lib/apt/lists/* \
    && gh --version

# Install the official OpenAI Codex CLI at a reproducible stable version.
RUN npm install --global --no-audit --no-fund "@openai/codex@${CODEX_VERSION}" \
    && codex --version \
    && npm cache clean --force

# ttyd is the proven Web terminal used by Home Assistant's official
# Terminal & SSH App. Upstream publishes static amd64 and aarch64 binaries.
RUN case "${TARGETARCH}" in \
        amd64) \
            ttyd_asset="ttyd.x86_64"; \
            ttyd_sha256="8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55" \
            ;; \
        arm64) \
            ttyd_asset="ttyd.aarch64"; \
            ttyd_sha256="b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165" \
            ;; \
        *) \
            echo "Unsupported architecture for ttyd: ${TARGETARCH}" >&2; \
            exit 1 \
            ;; \
    esac \
    && curl -fsSL \
        "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/${ttyd_asset}" \
        -o /tmp/ttyd \
    && echo "${ttyd_sha256}  /tmp/ttyd" | sha256sum -c - \
    && install -m 0755 /tmp/ttyd /usr/local/bin/ttyd \
    && rm -f /tmp/ttyd \
    && ttyd --version

COPY github_known_hosts /etc/ssh/ssh_known_hosts
COPY profile.sh /etc/profile.d/codex-app.sh
COPY root_bash_profile /root/.bash_profile
COPY root_bashrc /root/.bashrc
COPY run.sh /usr/local/bin/run-codex-app
COPY sshd_config /usr/local/share/codex-app/sshd_config
COPY third_party/ttyd-LICENSE /usr/share/doc/ttyd/copyright

RUN chmod 0644 \
        /etc/profile.d/codex-app.sh \
        /etc/ssh/ssh_known_hosts \
        /root/.bash_profile \
        /root/.bashrc \
        /usr/share/doc/ttyd/copyright \
        /usr/local/share/codex-app/sshd_config \
    && chmod 0755 /usr/local/bin/run-codex-app \
    && mkdir -p /config /data /run/sshd /usr/local/share/codex-app

EXPOSE 22 8099

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/run-codex-app"]

LABEL io.hass.arch="${BUILD_ARCH}" \
    io.hass.description="OpenAI Codex CLI development environment" \
    io.hass.name="Codex" \
    io.hass.type="app" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.description="OpenAI Codex CLI development environment for Home Assistant" \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.source="https://github.com/zoic21/hassio-applications" \
    org.opencontainers.image.title="Codex" \
    org.opencontainers.image.version="${BUILD_VERSION}"
