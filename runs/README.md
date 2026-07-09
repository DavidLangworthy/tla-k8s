# TLC Run Records

This directory keeps exploratory TLC runs that are larger than the default CI
smoke checks.

## Layout

- `configs/` contains named TLC configs for exploratory runs.
- `results/` contains committed run summaries and, when useful, raw TLC logs.
- `scripts/run_tlc.sh` runs a config, captures wall-clock time, parses the TLC
  state-count lines, and writes a Markdown result.

## Running

From a Codespace or another machine with Java and `tla2tools.jar`:

```sh
TIMEOUT_SECONDS=600 make explore CONFIG=runs/configs/safety-2p1n-gen0.cfg LABEL=safety-2p1n-gen0
```

To take baby steps up in model size and stop when the total exploration budget
is reached:

```sh
TOTAL_TIMEOUT_SECONDS=1800 TIMEOUT_SECONDS=600 make explore-sequence
```

The runner writes `runs/results/<timestamp>-<label>.md` and a matching `.log`.
Commit the summaries for runs that matter. The raw log is useful when a timeout
or counterexample needs more detail.

## What To Record

Each run summary should make it clear whether TLC actually explored a meaningful
state space. At minimum check:

- TLC outcome: success, failure, or timeout.
- Duration.
- Final state summary, such as `N states generated, M distinct states found`.
- Complete-search depth, or the last progress line for bounded/timeout runs.
- The exact config constants.

For a new invariant or liveness property, run a temporary negative control when
practical. For example, add an invariant that is plainly false, verify TLC fails,
then remove the injected error before committing.
