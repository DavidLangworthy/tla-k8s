FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG TLA2TOOLS_URL=https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      openjdk-21-jre-headless \
      make \
      openssh-server \
    && mkdir -p /opt/tla2tools /run/sshd \
    && curl -fsSL -o /opt/tla2tools/tla2tools.jar "${TLA2TOOLS_URL}" \
    && chmod 0644 /opt/tla2tools/tla2tools.jar \
    && rm -rf /var/lib/apt/lists/*

ENV TLA2TOOLS=/opt/tla2tools/tla2tools.jar
