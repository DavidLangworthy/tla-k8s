#!/usr/bin/env bash
set -euo pipefail

make tools
java -version
java -cp "${TLA2TOOLS:-.tools/tla2tools.jar}" tlc2.TLC -help >/dev/null
