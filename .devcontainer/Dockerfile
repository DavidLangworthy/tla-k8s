FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG CODEX_RELEASE=0.144.1
ARG CODEX_TARGET=x86_64-unknown-linux-musl
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
    && tmpdir="$(mktemp -d)" \
    && curl --retry 5 --retry-delay 2 --retry-all-errors -fsSL \
      -o "$tmpdir/codex.tar.gz" \
      "https://github.com/openai/codex/releases/download/rust-v${CODEX_RELEASE}/codex-${CODEX_TARGET}.tar.gz" \
    && tar -xzf "$tmpdir/codex.tar.gz" -C "$tmpdir" \
    && install -m 0755 "$tmpdir/codex-${CODEX_TARGET}" /usr/local/bin/codex \
    && rm -rf "$tmpdir" \
    && rm -rf /var/lib/apt/lists/*

ENV TLA2TOOLS=/opt/tla2tools/tla2tools.jar
