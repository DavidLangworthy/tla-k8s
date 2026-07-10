#!/usr/bin/env bash
set -euo pipefail

install_codex() {
  local release="${CODEX_RELEASE:-0.144.1}"
  local target="${CODEX_TARGET:-x86_64-unknown-linux-musl}"
  local current_version=""
  local tmpdir

  if current_version="$(codex --version 2>/dev/null | awk '{print $2}')" && [ "$current_version" = "$release" ]; then
    return
  fi

  echo "Installing Codex CLI ${release}"
  tmpdir="$(mktemp -d)"
  curl --retry 5 --retry-delay 2 --retry-all-errors -fsSL \
    -o "$tmpdir/codex.tar.gz" \
    "https://github.com/openai/codex/releases/download/rust-v${release}/codex-${target}.tar.gz"
  tar -xzf "$tmpdir/codex.tar.gz" -C "$tmpdir"
  sudo install -m 0755 "$tmpdir/codex-${target}" /usr/local/bin/codex
  rm -rf "$tmpdir"
}

clone_jobtree() {
  local repo="${JOBTREE_REPO:-DavidLangworthy/jobtree}"
  local target="${JOBTREE_DIR:-/workspaces/jobtree}"

  if [ -d "$target/.git" ]; then
    echo "jobtree already cloned at $target"
    return
  fi

  if [ -e "$target" ]; then
    echo "Refusing to clone $repo: $target exists but is not a git checkout" >&2
    return 1
  fi

  mkdir -p "$(dirname "$target")"
  if command -v gh >/dev/null 2>&1 && gh auth status -h github.com >/dev/null 2>&1; then
    gh repo clone "$repo" "$target"
  else
    git clone "https://github.com/${repo}.git" "$target"
  fi
}

make tools
java -version
tlc_help="$(java -cp "${TLA2TOOLS:-.tools/tla2tools.jar}" tlc2.TLC -help 2>&1 || true)"
grep -q "TLC" <<<"$tlc_help"
install_codex
clone_jobtree
codex --version >/dev/null
command -v gh >/dev/null
command -v jq >/dev/null
command -v tmux >/dev/null
sudo install -m 0755 .devcontainer/gh-login /usr/local/bin/gh-login
command -v gh-login >/dev/null
