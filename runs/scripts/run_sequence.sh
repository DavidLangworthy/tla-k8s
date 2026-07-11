#!/usr/bin/env bash
set -u

total_timeout_seconds="${TOTAL_TIMEOUT_SECONDS:-1800}"
per_run_timeout_seconds="${TIMEOUT_SECONDS:-600}"

if [ "$#" -eq 0 ]; then
  set -- \
    "runs/configs/safety-2p1n-gen0.cfg:safety-2p1n-gen0" \
    "runs/configs/safety-2p2n-gen0-sym.cfg:safety-2p2n-gen0-sym"
fi

suite_start="$(date +%s)"

for entry in "$@"; do
  now="$(date +%s)"
  elapsed=$((now - suite_start))
  remaining=$((total_timeout_seconds - elapsed))

  if [ "$remaining" -le 0 ]; then
    echo "Total exploration budget exhausted after ${elapsed}s."
    exit 124
  fi

  config="${entry%%:*}"
  label="${entry#*:}"
  if [ "$label" = "$entry" ]; then
    label="$(basename "$config" .cfg)"
  fi

  run_timeout="$per_run_timeout_seconds"
  if [ "$remaining" -lt "$run_timeout" ]; then
    run_timeout="$remaining"
  fi

  echo
  echo "=== $label ==="
  echo "Remaining suite budget: ${remaining}s"
  echo "This run timeout: ${run_timeout}s"

  TIMEOUT_SECONDS="$run_timeout" runs/scripts/run_tlc.sh "$config" "$label"
  status=$?

  if [ "$status" -ne 0 ]; then
    echo "Stopping after $label exited with status $status."
    exit "$status"
  fi
done
