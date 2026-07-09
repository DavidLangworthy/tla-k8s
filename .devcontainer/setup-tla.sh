#!/usr/bin/env bash
set -euo pipefail

make tools
java -version
java -cp "${TLA2TOOLS:-.tools/tla2tools.jar}" tlc2.TLC -help >/dev/null
codex --version >/dev/null
command -v gh >/dev/null
command -v jq >/dev/null
command -v tmux >/dev/null
sudo install -m 0755 .devcontainer/gh-login /usr/local/bin/gh-login
command -v gh-login >/dev/null
