# syntax=docker/dockerfile:1.4
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
    # Add repositories with GPG verification
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
        tee /etc/apt/sources.list.d/github-cli.list && \
    \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
        gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | \
        tee /etc/apt/sources.list.d/nodesource.list && \
    \
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
        gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ jammy main" | \
        tee /etc/apt/sources.list.d/azure-cli.list && \
    \
    curl -fsSL https://apt.releases.commonfate.io/gpg | \
        gpg --dearmor -o /usr/share/keyrings/common-fate-linux.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/common-fate-linux.gpg] https://apt.releases.commonfate.io stable main" | \
        tee /etc/apt/sources.list.d/common-fate.list

# 3: Install all apt packages
FROM aptsources AS aptinstalls

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        git \
        sudo \
        zsh \
        openssh-server \
        procps \
        htop \
        less \
        nano \
        jq \
        zip \
        sqlite3 \
        gh \
        nodejs \
        azure-cli \
        granted && \
    rm -rf /var/lib/apt/lists/*

# 4: System updates and comprehensive cleanup
FROM aptinstalls AS aptupgrade

RUN set -eux && \
    # Update package lists and upgrade all packages
    apt-get update && \
    apt-get upgrade -y && \
    \
    # Comprehensive apt/dpkg cleanup
    apt-get autoremove -y && \
    apt-get autoclean && \
    apt-get clean && \
    \
    # Remove package caches and temporary files
    rm -rf /var/lib/apt/lists/* \
           /var/cache/apt/archives/* \
           /var/cache/apt/archives/partial/* \
           /var/cache/debconf/* \
           /var/lib/dpkg/info/*.list \
           /tmp/* \
           /var/tmp/* && \
    \
    # Clean up dpkg status and logs
    find /var/lib/dpkg -name '*-old' -delete && \
    find /var/log -type f -name '*.log' -delete && \
    \
    # Ensure no leftover processes or lock files
    rm -f /var/lib/dpkg/lock* \
          /var/cache/apt/archives/lock \
          /var/lib/apt/lists/lock

# 5: Custom tools (npm + direct downloads)
FROM aptupgrade AS custom

RUN set -eux && \
    # npm globals (nodejs now available from aptinstalls)
    npm install -g @anthropic-ai/claude-code@latest && \
    \
    # UV installer
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh && \
    \
    # yq (YAML processor)
    YQ_VERSION="v4.40.5" && \
    curl -L "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_arm64" -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    \
    # AWS CLI v2 (for ARM64)
    AWS_CLI_VERSION="2.15.0" && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64-${AWS_CLI_VERSION}.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Create non-root user with appropriate privileges for development
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN set -eux && \
    # Handle existing groups gracefully
    EXISTING_GROUP=$(getent group $USER_GID | cut -d: -f1 || echo "") && \
    if [ -z "$EXISTING_GROUP" ]; then \
        groupadd --gid $USER_GID $USERNAME; \
        USER_GROUP=$USERNAME; \
    else \
        USER_GROUP=$EXISTING_GROUP; \
    fi && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:/usr/bin/apt-get,/usr/bin/docker,/usr/bin/systemctl" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ps aux | grep -v grep | grep -q sleep || exit 1

WORKDIR /home/$USERNAME
USER $USERNAME

# Use proper init process if available, fallback to sleep
ENTRYPOINT ["/bin/bash", "-c", "if command -v dumb-init >/dev/null 2>&1; then exec dumb-init -- sleep infinity; else exec sleep infinity; fi"]