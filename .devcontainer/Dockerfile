FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG TLA2TOOLS_URL=https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar
ARG CODEX_RELEASE=0.101.0
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
    && mkdir -p /opt/codex \
    && curl --retry 5 --retry-delay 2 --retry-all-errors -fsSL https://chatgpt.com/codex/install.sh | CODEX_HOME=/opt/codex CODEX_RELEASE="${CODEX_RELEASE}" CODEX_NON_INTERACTIVE=1 CODEX_INSTALL_DIR=/usr/local/bin sh \
    && chmod -R a+rX /opt/codex \
    && test -x /usr/local/bin/codex \
    && rm -rf /var/lib/apt/lists/*

ENV TLA2TOOLS=/opt/tla2tools/tla2tools.jar
