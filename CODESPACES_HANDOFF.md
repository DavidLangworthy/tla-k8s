# Codespaces Handoff

Use this when continuing TLC exploration from the GitHub Codespace instead of
from the Mac.

## Current Target

- Repository: `DavidLangworthy/tla-k8s`
- Branch: `codex/codespaces-ci-security`
- PR: `#1`
- Codespace: `tla-k8s-tlc-vqjw6j4qv93xqgv`
- Machine: `standardLinux32gb` (`4 cores, 16 GB RAM, 32 GB storage`)
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
command -v gh
command -v gh-login
command -v tmux
test -d /workspaces/jobtree/.git
tmux -V
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

If GitHub CLI is not authenticated in the Codespace, or if it needs the scopes
for PR comments, Actions inspection, Codespaces, GHCR package access, or code
scanning/security-event APIs, run:

```sh
gh-login
gh auth status
```

`gh-login` requests:

```text
repo,workflow,read:org,codespace,read:packages,write:packages,security_events
```

The devcontainer requests read access to `DavidLangworthy/jobtree` and clones it
as a sibling checkout at `/workspaces/jobtree` during post-create setup. Existing
Codespaces do not automatically gain new `devcontainer.json` repository
permissions just because the file changed. For the current public `jobtree`
repository, a manual clone works without a rebuild:

```sh
gh repo clone DavidLangworthy/jobtree /workspaces/jobtree
```

Rebuilding the current Codespace can rerun post-create setup, but GitHub does
not apply newly requested repository permissions to existing Codespaces. For a
future private `jobtree` checkout, create a new Codespace and approve the
requested `contents: read` access, or run `gh-login` inside the existing
Codespace and use those user credentials.

The repo declares `hostRequirements` for 4 cores, 16 GB RAM, and 32 GB storage
so new Codespaces should use the larger VM tier. Changing an existing Codespace
to the same storage size takes effect on its next restart if it was already
running. The current Codespace is already configured for `standardLinux32gb`,
but the running VM may still report the old 2-core/8 GB resources until the next
stop/start. Do not stop it while active verification work is still running.

## TLC Exploration Plan

Default exploration should start with two pods. Run:

```sh
tmux new -s tlc
TOTAL_TIMEOUT_SECONDS=1800 TIMEOUT_SECONDS=600 make explore-sequence
```

Detach from the run with `Ctrl-b d`. Reattach later with:

```sh
tmux attach -t tlc
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
