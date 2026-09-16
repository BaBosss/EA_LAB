# Main Control Tower intake of Demo result draft — 2026-09-16
Scope: read-only pre-integration intake, not final exact-commit acceptance or a new tester/repair contract.
Canonical checked: `a9c54b8f4e2924a4329ea502ba34ffb5ee435c53`.
Sole result writer: `ct-demo-sameperiod-replay-results-20260916`.
Duplicate `ct-demo-sameperiod-result-20260916` is BLOCKED/SUPERSEDED; its untracked MD/JSON are preserved and must not be pushed.

## Verified
`DEMO_INTAKE_CHECKS.json` records exact inspected source hashes. All 15 report/truncation/run-log hashes match; all sources remained byte-stable during inspection. The preserved Demo subset has 120 rows, 0 duplicate tickets, and independently recomputed exit count/net/PF matching the displayed five rows. Non-exit swap/commission totals are zero in this subset.

## Required before result acceptance
1. **P2 — distinguish executed from full-window eligible.** C01/C02/C05 have typed `CHECK_PASS / checker_exit_code=0 / truncated=false`. C03/C04 instead have `UNKNOWN / truncated=null`. Informational quiet-tail prose is not a typed full-window PASS. Retain all raw files and report five execution attempts, three truncation-qualified cells, and two explicit `BLOCKED_TRUNCATION_UNRESOLVED` cells. Treat C03/C04 numbers and any combined basket containing C03 as descriptive/ineligible for a full-window conclusion. No rerun, sidecar rewrite, gate waiver or strategy-failure inference is requested.
2. **P2 — aggregate agreement does not prove original row identity.** `evidence_manifest.json` declares `original_whole_file_bytes_preserved=false`. `reconcile_demo_rows.py` compares only counts/net/PF against hardcoded expected tuples; it does not compare original ticket-level rows. The current subset/hash is valid observed evidence, but `ROW_LEVEL_RECONCILED` overstates the available historical provenance. Use `AGGREGATE_RECONCILED_ONLY / ORIGINAL_ROW_IDENTITY_UNPROVEN`, preserving the original missing-byte limitation. Do not claim the exporter only appended unless an archived prefix or equivalent row evidence proves it.

## Timing interpretation constraint
`parse_compare.py::best_offset` searches 25 whole-hour shifts (-12..+12), chooses the maximum one-to-one same-side matches within 20 minutes, then breaks ties using total timing error. These are post-outcome best-aligned match counts, not independently validated broker-clock or signal-parity evidence. Carry this method/limitation beside the counts and into machine-readable output; do not present the selected offsets as a qualified clock model.

## Gate and downstream consumer
Existing writer may correct its own draft and retain findings before its normal exact-head milestone review. This note grants no repeat review, reset repair budget, MT5, source/config substitution, risk/default, runtime, promotion or trading authority. Broker and legacy-identity confounds remain cumulative even for the three truncation-qualified cells.
