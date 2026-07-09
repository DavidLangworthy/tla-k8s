FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG TLA2TOOLS_URL=https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bubblewrap \
      ca-certificates \
      curl \
      gh \
      jq \
      less \
      openjdk-21-jre-headless \
      make \
      openssh-server \
      procps \
      time \
      tmux \
    && mkdir -p /opt/tla2tools /run/sshd \
    && curl --retry 5 --retry-delay 2 --retry-all-errors -fsSL -o /opt/tla2tools/tla2tools.jar "${TLA2TOOLS_URL}" \
    && chmod 0644 /opt/tla2tools/tla2tools.jar \
    && rm -rf /var/lib/apt/lists/*

ENV TLA2TOOLS=/opt/tla2tools/tla2tools.jar
