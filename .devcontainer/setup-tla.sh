#!/usr/bin/env bash
set -euo pipefail

install_codex() {
  local release="${CODEX_RELEASE:-0.101.0}"
  local target="${CODEX_TARGET:-x86_64-unknown-linux-musl}"
  local tmpdir

  if codex --version >/dev/null 2>&1; then
    return
  fi

  tmpdir="$(mktemp -d)"
  curl --retry 5 --retry-delay 2 --retry-all-errors -fsSL \
    -o "$tmpdir/codex.tar.gz" \
    "https://github.com/openai/codex/releases/download/rust-v${release}/codex-${target}.tar.gz"
  tar -xzf "$tmpdir/codex.tar.gz" -C "$tmpdir"
  sudo install -m 0755 "$tmpdir/codex-${target}" /usr/local/bin/codex
  rm -rf "$tmpdir"
}

make tools
java -version
java -cp "${TLA2TOOLS:-.tools/tla2tools.jar}" tlc2.TLC -help >/dev/null
install_codex
codex --version >/dev/null
command -v gh >/dev/null
command -v jq >/dev/null
command -v tmux >/dev/null
sudo install -m 0755 .devcontainer/gh-login /usr/local/bin/gh-login
command -v gh-login >/dev/null
