#!/usr/bin/env bash
set -u

usage() {
  echo "usage: $0 <config.cfg> [label]" >&2
  exit 2
}

[ "$#" -ge 1 ] || usage

config="$1"
label="${2:-$(basename "$config" .cfg)}"
module="${MODULE:-K8sPodNodeGpu}"
outdir="${OUTDIR:-runs/results}"
timeout_seconds="${TIMEOUT_SECONDS:-600}"
jar="${TLA2TOOLS:-.tools/tla2tools.jar}"

if [ ! -f "$config" ]; then
  echo "config not found: $config" >&2
  exit 2
fi

if [ ! -f "$jar" ]; then
  echo "tla2tools.jar not found: $jar" >&2
  echo "Set TLA2TOOLS=/path/to/tla2tools.jar or run make tools." >&2
  exit 2
fi

safe_label="$(printf '%s' "$label" | tr -cs 'A-Za-z0-9._-' '-')"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$outdir"

log="$outdir/${timestamp}-${safe_label}.log"
result="$outdir/${timestamp}-${safe_label}.md"
start_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
start_epoch="$(date +%s)"
host="$(hostname 2>/dev/null || printf unknown)"
command_text="java -cp $jar tlc2.TLC -config $config $module"

echo "Running: $command_text"
echo "Timeout: ${timeout_seconds}s"
echo "Log: $log"

set +e
if command -v timeout >/dev/null 2>&1; then
  timeout "${timeout_seconds}s" java -cp "$jar" tlc2.TLC -config "$config" "$module" >"$log" 2>&1
  status=$?
else
  java -cp "$jar" tlc2.TLC -config "$config" "$module" >"$log" 2>&1
  status=$?
fi
set -e

end_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
end_epoch="$(date +%s)"
duration_seconds=$((end_epoch - start_epoch))

case "$status" in
  0) outcome="success" ;;
  124|137) outcome="timeout" ;;
  *) outcome="failure" ;;
esac

specification="$(awk '/^SPECIFICATION[[:space:]]+/ {print $2; exit}' "$config")"
state_summary="$(grep -E '^[0-9]+ states generated, [0-9]+ distinct states found' "$log" | tail -1 || true)"
depth_line="$(grep -E '^The depth of the complete state graph search is ' "$log" | tail -1 || true)"
diameter_line="$(grep -E '^The diameter of the state graph is ' "$log" | tail -1 || true)"
last_progress="$(grep -E '^Progress\([0-9]+\)' "$log" | tail -1 || true)"
completion_line="$(grep -E 'Model checking completed|Error:|Finished checking temporal properties' "$log" | tail -1 || true)"
constants_block="$(awk '
  /^CONSTANTS[[:space:]]*$/ {in_constants=1; next}
  /^(INVARIANTS|PROPERTIES)[[:space:]]*$/ {in_constants=0}
  in_constants && NF {print}
' "$config")"

{
  echo "# $label"
  echo
  echo "- Start UTC: $start_iso"
  echo "- End UTC: $end_iso"
  echo "- Duration: ${duration_seconds}s"
  echo "- Host: $host"
  echo "- Module: $module"
  echo "- Config: $config"
  echo "- Specification: ${specification:-unknown}"
  echo "- Timeout: ${timeout_seconds}s"
  echo "- Outcome: $outcome"
  echo "- Exit status: $status"
  echo "- Command: \`$command_text\`"
  echo "- Raw log: \`$(basename "$log")\`"
  echo "- State summary: ${state_summary:-not found}"
  echo "- Search depth: ${depth_line:-not found}"
  echo "- Graph diameter: ${diameter_line:-not found}"
  echo "- Last progress: ${last_progress:-not found}"
  echo "- Completion line: ${completion_line:-not found}"
  echo
  echo "## Constants"
  echo
  echo '```tla'
  printf '%s\n' "$constants_block"
  echo '```'
  echo
  echo "## Log Tail"
  echo
  echo '```text'
  tail -80 "$log"
  echo '```'
} >"$result"

echo "Result: $result"
exit "$status"
