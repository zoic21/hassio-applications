FROM debian:13-slim

ARG BUILD_ARCH
ARG BUILD_VERSION=dev
ARG CODE_SERVER_AMD64_SHA256=a38d26f4cb81f768feddff79e2937fd3f39c83d3da8be3da7225e1087e62e4ed
ARG CODE_SERVER_ARM64_SHA256=ade569a677d1c04ee66ef153382b7e15bf261f955407663c7ddc6b87f9ee29fc
ARG CODE_SERVER_VERSION=4.132.0
ARG CODEX_EXTENSION_AMD64_SHA256=0864adc5e1645a4d4f6b2cbe77de30dffa33d69ca89729fe0043a0124b8623ca
ARG CODEX_EXTENSION_ARM64_SHA256=9ebd2ba842ce1d8a3b14f962f8f6e564f0ac4587848a30e8b9b1891bb5e8ea3b
ARG CODEX_EXTENSION_VERSION=26.803.41515
ARG CODEX_INSTALLER_SHA256=ba92dd27e5c06f0d3bbc58bfa4b9cfb6599cd2742fbb1f92a2765e6c07dedb5a
ARG CODEX_VERSION=0.147.0
ARG GH_KEYRING_SHA256=6084d5d7bd8e288441e0e94fc6275570895da18e6751f70f057485dc2d1a811b
ARG TARGETARCH
ARG TTYD_VERSION=1.7.7

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV CODEX_HOME=/config/codex \
    CODE_SERVER_VERSION=${CODE_SERVER_VERSION} \
    CODEX_EXTENSION_VERSION=${CODEX_EXTENSION_VERSION} \
    CODEX_STANDALONE_VERSION=${CODEX_VERSION} \
    DEBIAN_FRONTEND=noninteractive \
    EDITOR=vim \
    GH_CONFIG_DIR=/config/gh \
    GIT_CONFIG_GLOBAL=/config/git/config \
    HISTFILE=/config/shell/bash_history \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    TERM=xterm-256color \
    XDG_CACHE_HOME=/config/code-server/xdg-cache \
    XDG_CONFIG_HOME=/config/code-server/xdg-config \
    XDG_DATA_HOME=/config/code-server/xdg-data

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
        nginx-core \
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

# Install Coder's pinned code-server release. This is the same tarball-based
# approach used by the Home Assistant Studio Code Server App.
RUN case "${TARGETARCH}" in \
        amd64) \
            code_server_arch="amd64"; \
            code_server_sha256="${CODE_SERVER_AMD64_SHA256}" \
            ;; \
        arm64) \
            code_server_arch="arm64"; \
            code_server_sha256="${CODE_SERVER_ARM64_SHA256}" \
            ;; \
        *) \
            echo "Unsupported architecture for code-server: ${TARGETARCH}" >&2; \
            exit 1 \
            ;; \
    esac \
    && curl -fsSL --retry 5 \
        "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-${code_server_arch}.tar.gz" \
        -o /tmp/code-server.tar.gz \
    && echo "${code_server_sha256}  /tmp/code-server.tar.gz" | sha256sum -c - \
    && install -d -m 0755 /usr/local/lib/code-server /usr/share/doc/code-server \
    && tar -xzf /tmp/code-server.tar.gz \
        --strip-components=1 -C /usr/local/lib/code-server \
    && ln -s /usr/local/lib/code-server/bin/code-server /usr/local/bin/code-server \
    && install -m 0644 /usr/local/lib/code-server/LICENSE \
        /usr/share/doc/code-server/copyright \
    && test "$(HOME=/tmp XDG_CACHE_HOME=/tmp/code-server/cache XDG_CONFIG_HOME=/tmp/code-server/config XDG_DATA_HOME=/tmp/code-server/data code-server --version | awk '/^[0-9]+\.[0-9]+\.[0-9]+/ { print $1; exit }')" = "${CODE_SERVER_VERSION}" \
    && rm -f /tmp/code-server.tar.gz

# The official Codex extension is not available from OpenVSX. Download the
# pinned, target-specific VSIX from the official Visual Studio Marketplace,
# verify it, and install it as an image-bundled extension. User-installed
# extensions remain separate and persistent under /config at runtime.
RUN case "${TARGETARCH}" in \
        amd64) \
            codex_extension_url="https://openai.gallerycdn.vsassets.io/extensions/openai/chatgpt/${CODEX_EXTENSION_VERSION}/1786067052683/Microsoft.VisualStudio.Services.VSIXPackage"; \
            codex_extension_sha256="${CODEX_EXTENSION_AMD64_SHA256}"; \
            codex_extension_bin="linux-x86_64" \
            ;; \
        arm64) \
            codex_extension_url="https://openai.gallerycdn.vsassets.io/extensions/openai/chatgpt/${CODEX_EXTENSION_VERSION}/1786067097435/Microsoft.VisualStudio.Services.VSIXPackage"; \
            codex_extension_sha256="${CODEX_EXTENSION_ARM64_SHA256}"; \
            codex_extension_bin="linux-aarch64" \
            ;; \
        *) \
            echo "Unsupported architecture for the Codex extension: ${TARGETARCH}" >&2; \
            exit 1 \
            ;; \
    esac \
    && extension_dir="/usr/local/lib/code-server/lib/vscode/extensions/openai.chatgpt-${CODEX_EXTENSION_VERSION}" \
    && curl -fsSL --compressed --retry 5 \
        -H "User-Agent: Mozilla/5.0" \
        "${codex_extension_url}" \
        -o /tmp/openai-chatgpt.vsix \
    && echo "${codex_extension_sha256}  /tmp/openai-chatgpt.vsix" | sha256sum -c - \
    && install -d -m 0755 "${extension_dir}" /tmp/openai-chatgpt-extension \
    && unzip -q /tmp/openai-chatgpt.vsix "extension/*" \
        -d /tmp/openai-chatgpt-extension \
    && cp -a /tmp/openai-chatgpt-extension/extension/. "${extension_dir}/" \
    && test "$(jq -r '.publisher + "." + .name' "${extension_dir}/package.json")" = "openai.chatgpt" \
    && test "$(jq -r '.version' "${extension_dir}/package.json")" = "${CODEX_EXTENSION_VERSION}" \
    && test -x "${extension_dir}/bin/${codex_extension_bin}/codex" \
    && rm -rf /tmp/openai-chatgpt.vsix /tmp/openai-chatgpt-extension

# Install the official standalone Codex CLI at a reproducible stable version.
# Remote control requires this managed layout instead of the npm package.
RUN curl -fsSL https://chatgpt.com/codex/install.sh \
        -o /tmp/codex-install.sh \
    && echo "${CODEX_INSTALLER_SHA256}  /tmp/codex-install.sh" | sha256sum -c - \
    && CODEX_HOME=/opt/codex \
        CODEX_INSTALL_DIR=/usr/local/bin \
        CODEX_NON_INTERACTIVE=1 \
        sh /tmp/codex-install.sh --release "${CODEX_VERSION}" \
    && test "$(codex --version | awk '{print $NF}')" = "${CODEX_VERSION}" \
    && test -x /opt/codex/packages/standalone/current/codex \
    && codex remote-control --help >/dev/null \
    && rm -f /tmp/codex-install.sh

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
COPY health.sh /usr/local/bin/codex-app-health
COPY launcher/ /usr/local/share/codex-app/launcher/
COPY nginx.conf /etc/nginx/nginx.conf
COPY profile.sh /etc/profile.d/codex-app.sh
COPY root_bash_profile /root/.bash_profile
COPY root_bashrc /root/.bashrc
COPY run.sh /usr/local/bin/run-codex-app
COPY sshd_config /usr/local/share/codex-app/sshd_config
COPY third_party/ttyd-LICENSE /usr/share/doc/ttyd/copyright

RUN chmod 0644 \
        /etc/nginx/nginx.conf \
        /etc/profile.d/codex-app.sh \
        /etc/ssh/ssh_known_hosts \
        /root/.bash_profile \
        /root/.bashrc \
        /usr/share/doc/ttyd/copyright \
        /usr/local/share/codex-app/sshd_config \
    && chmod 0755 \
        /usr/local/bin/codex-app-health \
        /usr/local/bin/run-codex-app \
    && mkdir -p \
        /config \
        /data \
        /run/sshd \
        /usr/local/share/codex-app

EXPOSE 22 8099

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl --fail --silent http://127.0.0.1:8099/healthz >/dev/null || exit 1

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
