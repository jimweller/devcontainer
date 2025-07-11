FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color

COPY packages.txt /tmp/packages.txt

RUN apt-get update && \
    apt-get install -y --no-install-recommends $(cat /tmp/packages.txt) && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /tmp/packages.txt

ARG CACHE_BUSTER=1
COPY install.sh /tmp/install.sh
RUN chmod +x /tmp/install.sh

RUN /tmp/install.sh && \
    rm /tmp/install.sh

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN set -eux; \
    useradd --uid "${USER_UID}" -m "${USERNAME}"; \
    EXISTING_GROUP_NAME=$(getent group "${USER_GID}" | cut -d: -f1); \
    if [ -z "$EXISTING_GROUP_NAME" ]; then \
        groupadd --gid "${USER_GID}" "${USERNAME}"; \
        usermod -g "${USER_GID}" "${USERNAME}"; \
    else \
        usermod -a -G "${EXISTING_GROUP_NAME}" "${USERNAME}"; \
    fi; \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}"; \
    chmod 0440 "/etc/sudoers.d/${USERNAME}"

WORKDIR /home/${USERNAME}

USER ${USERNAME}