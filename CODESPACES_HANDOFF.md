# Codespaces Handoff

Use this when continuing TLC exploration from the GitHub Codespace instead of
from the Mac.

## Current Target

- Repository: `DavidLangworthy/tla-k8s`
- Branch: `codex/codespaces-ci-security`
- PR: `#1`
- Codespace: `tla-k8s-tlc-vqjw6j4qv93xqgv`
- Machine: `basicLinux32gb`
- Idle shutdown: 30 minutes

## Start Or Resume

From the Mac, check that the Codespace is available:

```sh
gh codespace view -c tla-k8s-tlc-vqjw6j4qv93xqgv \
  --json name,state,machineName,idleTimeoutMinutes,retentionPeriodDays
```

SSH into it:

```sh
gh codespace ssh -c tla-k8s-tlc-vqjw6j4qv93xqgv
```

Inside the Codespace:

```sh
cd /workspaces/tla-k8s
git fetch origin
git switch codex/codespaces-ci-security
git pull --ff-only
command -v codex
codex --version
java -version
java -cp "${TLA2TOOLS:-/opt/tla2tools/tla2tools.jar}" tlc2.TLC -help >/dev/null
```

The current Codespace has Codex CLI `0.101.0` installed under
`/home/vscode/.local/bin/codex`. The devcontainer also installs that pinned
release during rebuilds because the `latest` standalone installer path failed
on July 9, 2026 while resolving Linux release metadata.

If Codex is installed but not authenticated, use device-code auth in the
Codespace terminal:

```sh
codex login --device-auth
codex doctor
```

Do not copy `~/.codex/auth.json` into the repo.

## TLC Exploration Plan

Default exploration should start with two pods. Run:

```sh
TOTAL_TIMEOUT_SECONDS=1800 TIMEOUT_SECONDS=600 make explore-sequence
```

The default sequence is:

1. `runs/configs/safety-2p1n-gen0.cfg`
2. `runs/configs/safety-2p2n-gen0.cfg`

Stop after the first timeout, failure, or interrupted run unless there is a
specific reason to continue. Commit the generated Markdown summaries under
`runs/results/`; raw `.log` files can stay uncommitted unless the full log is
needed for a counterexample or timeout audit.

For a single run:

```sh
TIMEOUT_SECONDS=600 make explore \
  CONFIG=runs/configs/safety-2p1n-gen0.cfg \
  LABEL=safety-2p1n-gen0
```

## Safety Checks Before Claiming Success

- Read the generated summary and confirm TLC reported a meaningful explored
  state space, not just exit status 0.
- For a complete run, look for a final line like
  `N states generated, M distinct states found, 0 states left on queue`.
- For a timeout or interrupted run, record the last `Progress(...)` line.
- When changing invariants or liveness properties, run a temporary negative
  control that TLC must catch, then remove the injected error before committing.

## Current Notes

- CI smoke checks are intentionally small and already exercise the safety,
  stable-liveness, and failure-liveness configs.
- `safety-1p1n-gen1` completed in Codespaces in 5 seconds:
  `267073 states generated`, `32256 distinct states found`.
- `safety-1p2n-gen0` was interrupted after 651 seconds because the next
  exploration should focus on two-pod cases. Last progress:
  `115580198 states generated`, `12280558 distinct states found`,
  `4601835 states left on queue`.
- The related research survey is checked in as `deep-research-report.md`; do
  not fold it into the model yet.
