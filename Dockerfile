# syntax=docker/dockerfile:1.4
# Requires BuildKit. Docker Desktop enables this by default.
# On bare Docker Engine (Linux), set DOCKER_BUILDKIT=1 before docker build.
# Without BuildKit, --mount=type=cache directives below will hard-fail.

# 1: Minimal essential tools for subsequent layers
FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        gpg \
        unzip \
        locales && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# 2: Setup apt sources (no package installs)
FROM base AS aptsources

RUN set -eux && \
    install -dm 755 /etc/apt/keyrings && \
    \
    # gh cli
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list && \
    \
    # node 24.x
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
        gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list && \
    \
    # microsoft (azure-cli + dotnet-sdk-10.0)
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
        gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg && \
    { \
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ noble main"; \
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main"; \
    } > /etc/apt/sources.list.d/microsoft.list && \
    \
    # common-fate granted/assume
    curl -fsSL https://apt.releases.commonfate.io/gpg | \
        gpg --dearmor -o /usr/share/keyrings/common-fate-linux.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/common-fate-linux.gpg] https://apt.releases.commonfate.io stable main" \
        > /etc/apt/sources.list.d/common-fate.list && \
    \
    # OpenTofu
    curl -fsSL https://get.opentofu.org/opentofu.gpg | \
        tee /etc/apt/keyrings/opentofu.gpg >/dev/null && \
    curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | \
        gpg --dearmor -o /etc/apt/keyrings/opentofu-repo.gpg && \
    chmod a+r /etc/apt/keyrings/opentofu.gpg /etc/apt/keyrings/opentofu-repo.gpg && \
    { \
        echo "deb [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main"; \
        echo "deb-src [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main"; \
    } > /etc/apt/sources.list.d/opentofu.list && \
    chmod a+r /etc/apt/sources.list.d/opentofu.list && \
    \
    # HashiCorp (Terraform)
    curl -fsSL https://apt.releases.hashicorp.com/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com noble main" \
        > /etc/apt/sources.list.d/hashicorp.list && \
    \
    # kubectl v1.34
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | \
        gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" \
        > /etc/apt/sources.list.d/kubernetes.list && \
    \
    # helm
    curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | \
        gpg --dearmor -o /etc/apt/keyrings/helm.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" \
        > /etc/apt/sources.list.d/helm.list && \
    \
    # mise
    curl -fsSL https://mise.jdx.dev/gpg-key.pub | \
        gpg --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=$(dpkg --print-architecture)] https://mise.jdx.dev/deb stable main" \
        > /etc/apt/sources.list.d/mise.list

# 3: Install and upgrade all apt packages
FROM aptsources AS aptinstalls

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        # core
        git \
        sudo \
        wget \
        zip \
        procps \
        build-essential \
        # shell + terminal
        zsh \
        less \
        nano \
        vim \
        bat \
        eza \
        zoxide \
        safe-rm \
        dtach \
        # net diagnostics
        dnsutils \
        iputils-ping \
        # monitoring + utilities
        htop \
        sqlite3 \
        jq \
        # language runtimes
        nodejs \
        python3 \
        python3-yaml \
        python3-pygments \
        # cloud + iac
        gh \
        azure-cli \
        kubectl \
        kubectx \
        helm \
        granted \
        mise \
        # .net
        dotnet-sdk-10.0 \
        # encryption
        age \
        # entrypoint helper
        dumb-init \
        # ssh
        openssh-server && \
    apt-get autoremove -y && \
    apt-get clean

# 4: Custom binary downloads (sops, yq, AWS CLI, Go, uv, Rust, Bun)
FROM aptinstalls AS binaries

ENV GOROOT=/usr/local/go
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/go/bin:/usr/local/cargo/bin:${PATH}

RUN set -eux && \
    DPKG_ARCH="$(dpkg --print-architecture)" && \
    case "$DPKG_ARCH" in \
        amd64) ARCH_GO=amd64 ARCH_AWS=x86_64 ARCH_SOPS=amd64 ARCH_YQ=amd64 ARCH_UV=x86_64 ;; \
        arm64) ARCH_GO=arm64 ARCH_AWS=aarch64 ARCH_SOPS=arm64 ARCH_YQ=arm64 ARCH_UV=aarch64 ;; \
        *) echo "Unsupported architecture: $DPKG_ARCH" && exit 1 ;; \
    esac && \
    \
    # sops v3.12.2
    curl -fsSL "https://github.com/getsops/sops/releases/download/v3.12.2/sops-v3.12.2.linux.${ARCH_SOPS}" \
        -o /usr/local/bin/sops && \
    chmod +x /usr/local/bin/sops && \
    \
    # yq v4.53.2 (mikefarah Go binary)
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/v4.53.2/yq_linux_${ARCH_YQ}" \
        -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    \
    # AWS CLI v2 (latest, multi-arch)
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH_AWS}.zip" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip && \
    \
    # Go 1.26.0
    curl -fsSL "https://go.dev/dl/go1.26.0.linux-${ARCH_GO}.tar.gz" | \
        tar -C /usr/local -xz && \
    \
    # uv (latest, musl static binary)
    mkdir -p /tmp/uv-download && \
    curl -fsSL "https://github.com/astral-sh/uv/releases/latest/download/uv-${ARCH_UV}-unknown-linux-musl.tar.gz" | \
        tar -xz -C /tmp/uv-download && \
    mv /tmp/uv-download/uv-${ARCH_UV}-unknown-linux-musl/uv /usr/local/bin/uv && \
    mv /tmp/uv-download/uv-${ARCH_UV}-unknown-linux-musl/uvx /usr/local/bin/uvx && \
    rm -rf /tmp/uv-download && \
    \
    # Rust (rustup, system-wide)
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
        sh -s -- -y --no-modify-path --default-toolchain stable --profile minimal && \
    chmod -R a+w /usr/local/rustup /usr/local/cargo && \
    \
    # Bun (system-wide)
    curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local bash

# 5: npm globals
FROM binaries AS npm-globals

RUN set -eux && \
    npm install -g \
        @anthropic-ai/claude-code@latest \
        opencode-ai@latest

# 6: Create non-root user with appropriate privileges for development
FROM npm-globals AS user

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

RUN set -eux && \
    # Group: create if no group owns USER_GID yet
    if ! getent group "${USER_GID}" > /dev/null 2>&1; then \
        groupadd --gid "${USER_GID}" "${USERNAME}"; \
    fi && \
    \
    # User: rename existing uid-USER_UID user (e.g. ubuntu) if necessary, else create fresh
    if getent passwd "${USER_UID}" > /dev/null 2>&1; then \
        EXISTING_USER="$(getent passwd "${USER_UID}" | cut -d: -f1)"; \
        if [ "${EXISTING_USER}" != "${USERNAME}" ]; then \
            usermod -l "${USERNAME}" -d "/home/${USERNAME}" -m "${EXISTING_USER}"; \
            groupmod -n "${USERNAME}" "${EXISTING_USER}" 2>/dev/null || true; \
        fi; \
    else \
        useradd --uid "${USER_UID}" --gid "${USER_GID}" -m "${USERNAME}" -s /bin/zsh; \
    fi && \
    \
    chsh -s /bin/zsh "${USERNAME}" && \
    \
    # Sudoers: passwordless ALL for dev container ergonomics
    echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME} && \
    \
    # Hand Rust toolchain ownership to the dev user (numeric IDs since
    # primary group may not be named ${USERNAME} when USER_GID is a system gid)
    chown -R ${USER_UID}:${USER_GID} /usr/local/cargo /usr/local/rustup

# 7: Custom JIM tweaks
FROM user AS tweaks

# mac & linux call batcat different things, make both work
RUN ln -sf /usr/bin/batcat /usr/local/bin/bat

# 8: Finish
FROM tweaks AS finish

ARG USERNAME=vscode

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ps aux | grep -v grep | grep -q sleep || exit 1

WORKDIR /home/${USERNAME}
USER ${USERNAME}

ENTRYPOINT ["/usr/bin/dumb-init", "--", "sleep", "infinity"]
