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
    # Add apt repositories with GPG verification
    # docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(grep -oP '(?<=VERSION_CODENAME=).*' /etc/os-release) stable" | \
        tee /etc/apt/sources.list.d/docker.list && \
    \
    # gh cli
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
        tee /etc/apt/sources.list.d/github-cli.list && \
    \
    # azure-cli - Now managed by asdf
    # curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
    #     gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg && \
    # echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ jammy main" | \
    #     tee /etc/apt/sources.list.d/azure-cli.list && \
    \
    # common-fate granted/assume - Now managed by asdf
    # curl -fsSL https://apt.releases.commonfate.io/gpg | \
    #     gpg --dearmor -o /usr/share/keyrings/common-fate-linux.gpg && \
    # echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/common-fate-linux.gpg] https://apt.releases.commonfate.io stable main" | \
    #     tee /etc/apt/sources.list.d/common-fate.list && \
    \
    # OpenTofu - Not needed, using tenv
    # curl -fsSL https://get.opentofu.org/opentofu.gpg | \
    #     tee /etc/apt/keyrings/opentofu.gpg >/dev/null && \
    # curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | \
    #     gpg --dearmor -o /etc/apt/keyrings/opentofu-repo.gpg && \
    # chmod a+r /etc/apt/keyrings/opentofu.gpg /etc/apt/keyrings/opentofu-repo.gpg && \
    # echo "deb [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | \
    #     tee /etc/apt/sources.list.d/opentofu.list  && \
    # echo "deb-src [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | \
    #     tee -a /etc/apt/sources.list.d/opentofu.list  && \
    # chmod a+r /etc/apt/sources.list.d/opentofu.list && \
    \
    # Terraform - Not needed, using tenv
    # curl -fsSL https://apt.releases.hashicorp.com/gpg | \
    #   gpg --dearmor -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg && \
    # echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | \
    #   tee /etc/apt/sources.list.d/hashicorp.list && \
    \
    # kubectl - Now managed by asdf
    # curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | \
    #   gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    # echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | \
    #   tee /etc/apt/sources.list.d/kubernetes.list && \
    \
    # tenv
    curl -1sLf 'https://dl.cloudsmith.io/public/tofuutils/tenv/cfg/setup/bash.deb.sh' | bash

# 3: Install all apt packages
FROM aptsources AS aptinstalls

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # build-essential \
        git \
        sudo \
        zsh \
        openssh-server \
        procps \
        htop \
        less \
        nano \
        # jq \              # Now managed by asdf
        # yq \              # Now managed by asdf
        zip \
        sqlite3 \
        docker-ce-cli \
        gh \
        # azure-cli \       # Now managed by asdf
        python3-pygments \
        python3.12-venv \
        # tofu \
        # terraform \
        tenv \
        # kubectl \         # Now managed by asdf
        kubectx \
        zoxide \
        eza \
        bat \
        safe-rm \
        # granted \         # Now managed by asdf
        && \
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

# 5: Install asdf binary and other tools (except npm)
FROM aptupgrade AS custom

RUN set -eux && \
    # UV installer
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh && \
    \
    # AWS CLI v2 (for ARM64) - Now managed by asdf
    # AWS_CLI_VERSION="2.15.0" && \
    # curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64-${AWS_CLI_VERSION}.zip" -o "awscliv2.zip" && \
    # unzip awscliv2.zip && \
    # ./aws/install && \
    # rm -rf aws awscliv2.zip && \
    \
    # asdf version manager - download pre-built binary
    ASDF_VERSION="v0.18.0" && \
    ASDF_ARCH="arm64" && \
    curl -fsSL "https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/asdf-${ASDF_VERSION}-linux-${ASDF_ARCH}.tar.gz" | \
    tar -xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/asdf

# 5.5: Install asdf plugins and tools (pre-staged in image)
FROM custom AS asdftools

# Set asdf environment
ENV ASDF_DATA_DIR="/opt/asdf"
ENV PATH="/opt/asdf/shims:${PATH}"

# Copy asdf configuration files (build context is dotfiles root)
COPY manifests/asdf-plugins.txt /tmp/asdf-plugins.txt
COPY dotfiles/asdf-tool-versions /tmp/.tool-versions

# Install plugins and tools
RUN bash -c 'set -eux && \
    # Install each plugin from manifest
    while IFS= read -r line || [[ -n "$line" ]]; do \
        [[ -z "$line" ]] && continue; \
        [[ "$line" =~ ^[[:space:]]*# ]] && continue; \
        plugin_name=$(echo "$line" | awk "{print \$1}"); \
        plugin_url=$(echo "$line" | awk "{print \$2}"); \
        echo "Installing asdf plugin: $plugin_name from $plugin_url"; \
        asdf plugin add "$plugin_name" "$plugin_url" || true; \
    done < /tmp/asdf-plugins.txt && \
    \
    # Install tools from .tool-versions
    cd /tmp && \
    asdf install && \
    \
    # Set nodejs version globally (creates ~/.tool-versions)
    NODEJS_VERSION=$(grep "^nodejs" /tmp/.tool-versions | awk "{print \$2}") && \
    echo "nodejs $NODEJS_VERSION" > ~/.tool-versions && \
    \
    # Verify nodejs and npm are available
    asdf reshim nodejs && \
    which node && \
    which npm && \
    node --version && \
    npm --version && \
    \
    # Cleanup temporary files
    rm -f /tmp/asdf-plugins.txt /tmp/.tool-versions'

# 5.6: Install npm globals using asdf nodejs
FROM asdftools AS customtools

RUN bash -c 'set -eux && \
    # npm globals (nodejs now available from asdf)
    npm install -g @anthropic-ai/claude-code@latest'

# 6: Create non-root user with appropriate privileges for development
FROM customtools AS user

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
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/zsh && \
    # Add user to docker group for socket access
    groupadd -f docker && \
    usermod -aG docker $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:/usr/bin/apt-get,/usr/bin/docker,/usr/bin/systemctl" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME && \
    # Fix asdf permissions for vscode user
    chown -R $USERNAME:$USER_GROUP /opt/asdf

# 7: Custom JIM tweaks
FROM user AS tweaks

# mac & linux call batcat different things, make both work
RUN ln -s /bin/batcat /bin/bat

# 8: Docker Health Check
FROM tweaks AS healthcheck
# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ps aux | grep -v grep | grep -q sleep || exit 1


# 9: Finish
FROM tweaks AS finish
WORKDIR /home/$USERNAME
USER $USERNAME

# Use proper init process if available, fallback to sleep
ENTRYPOINT ["/bin/bash", "-c", "if command -v dumb-init >/dev/null 2>&1; then exec dumb-init -- sleep infinity; else exec sleep infinity; fi"]