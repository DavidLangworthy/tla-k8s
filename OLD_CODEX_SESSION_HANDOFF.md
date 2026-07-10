# Old Codespace Codex Handoff

This captures the work recovered from the old Codespace after it was restarted
on July 10, 2026.

## Source Codespace

- Codespace: `tla-k8s-tlc-vqjw6j4qv93xqgv`
- Display name: `tla-k8s-tlc`
- Repository: `DavidLangworthy/tla-k8s`
- Branch when recovered: `codex/codespaces-ci-security`
- Codex thread/session id: `019f487b-98e6-7b51-8c65-2d643720c8e8`
- Raw Codex rollout path on that Codespace:
  `/home/vscode/.codex/sessions/2026/07/09/rollout-2026-07-09T20-04-47-019f487b-98e6-7b51-8c65-2d643720c8e8.jsonl`

Do not commit `/home/vscode/.codex/auth.json`. The raw rollout JSONL is also
not committed because both `tla-k8s` and `jobtree` are public repositories.

## Resuming The Same Codex Session

While the old Codespace still exists, the closest exact resume is:

```sh
gh codespace ssh -c tla-k8s-tlc-vqjw6j4qv93xqgv
cd /workspaces/jobtree
codex resume 019f487b-98e6-7b51-8c65-2d643720c8e8
```

If a future fresh Codespace must resume the exact same session, copy the rollout
file out-of-band into the same `~/.codex/sessions/2026/07/09/` path in the new
Codespace. Do not move it through a public git repository.

## `tla-k8s` Work Recovered

The old Codespace had uncommitted `tla-k8s` work for symmetry-reduced safety
exploration:

- `K8sPodNodeGpu.tla` now imports `TLC`, asserts `Pods \cap Nodes = {}`, and
  defines `ModelSymmetry` from role-preserving pod permutations plus node
  permutations.
- `runs/configs/safety-1p2n-gen0-sym.cfg` and
  `runs/configs/safety-2p2n-gen0-sym.cfg` enable `SYMMETRY ModelSymmetry`.
- `runs/scripts/run_tlc.sh` records the symmetry operator in result summaries.
- `runs/scripts/run_sequence.sh` defaults the second run to
  `safety-2p2n-gen0-sym`.
- `runs/results/20260709T201951Z-safety-1p2n-gen0-sym.md` records a 120 second
  timeout with `17,306,358 states generated`, `2,257,424 distinct states found`,
  and `1,129,102 states left on queue`.

## Sibling `jobtree` Work Recovered

The same Codex session spent most of its later proof work in
`/workspaces/jobtree`. Preserve that repository separately. The recovered final
Codex answer said:

- Added accounting witness states and properties in
  `specs/LedgerCompactionAccounting.tla`.
- Added clean configs:
  `LedgerCompactionAccountingClassHours.cfg`,
  `LedgerCompactionAccountingLender.cfg`,
  `LedgerCompactionAccountingCompositional.cfg`,
  `LedgerCompactionAccountingRepairedStart.cfg`, and
  `LedgerCompactionAccountingRepairedEnd.cfg`.
- Added counterexample configs:
  `LedgerCompactionAccountingStaleClassHours.cfg` and
  `LedgerCompactionAccountingStaleLender.cfg`.
- Added Make targets:
  `ledger-compaction-accounting-witness-check` and
  `ledger-compaction-accounting-witness-counterexamples`.
- Verified the TLC witness rail and the TLC stale counterexamples.
- Kept the main Apalache rail for summary representation, stateful round trip,
  representative seeded-fold steps, stale consumed-history witness, and stale
  aggregate-history witness.

Next larger-VM candidates from the old session:

1. Retry universal `SeededSettlementFold` in
   `specs/LedgerCompactionAccounting.tla`.
2. Decide whether the new witness checks should remain TLC-based or move back
   to Apalache without making the proof rail brittle.
