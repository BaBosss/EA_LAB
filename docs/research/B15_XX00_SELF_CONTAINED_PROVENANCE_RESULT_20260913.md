# B15 self-contained provenance result - 2026-09-13

PACKAGE STATUS: PASS_DETERMINISTIC_WORKER_CHECKS / READY_FOR_CONTROL_TOWER_INTAKE.
SAFE_FOR_CONTROL_TOWER_COMMIT: YES.
Independent exact-head review: PENDING_CONTROL_TOWER.
Fresh-clone status: PENDING_COMMIT. No committed-candidate/fresh-clone PASS claimed.

Lane: `b15-selfcontained-provenance-v1-20260913`; device BaBoss.
Exact base and read-only remote master observation:
`a1a0965b4ca6fef05340b810fdc6b09adbe560f8`.
One implementation pass; `MT5_runs=0`; `repair_budget=0/1` (independent-review repair unused).
No staging, commit or push. No tester/terminal/process invocation for MT5,
compile, optimization, rerun, retune, HOLDOUT, deployment or trading.

STRATEGY STATUS: unchanged. This new package does not repair/reopen
ORDER-XX00-MODEL1-SCREEN-V1 or the exhausted 2026-09-12 salvage contract.
Original blocked screen acceptance remains blocked. No new strategy verdict,
Home, Candidate, Grade, KINT, risk/default or runtime authority is created.

## Preserved observations

All numbers belong to MT5-lane3 / `D:\Meta 5c`, GBPUSD/H4, Model1
(`M1_M1_OHLC_RESEARCH`), leverage 1:100, deposit 10000 USD,
Optimization=0, ForwardMode=0.

| Window | Dates | PF | Net USD | Closed tickets | Native maximal EqDD |
|---|---|---:|---:|---:|---:|
| MAIN | 2023.01.01-2025.12.31 | 0.28 | -357.84 | 13 | 5.83% |
| BWD | 2020.01.01-2022.12.31 | 2.12 | +137.96 | 24 | 6.37% |

Both set/INI/report maps reconcile at 157/157/157. Set-to-INI assignment values
are exact; report-only numeric lexical formatting uses the preserved Decimal
normalization. Duplicate, missing, unexpected-key and value-mismatch inputs
are refused. The preserved canonical parser JSON, deal rows, yearly splits and
participation outputs reproduce from raw package reports. Existing parser zero
defaults for unsupported fields are preserved, not promoted to new observations.

## Historical acquisition provenance

The preferred read-only salvage directory supplied raw reports/INIs/set/sidecars,
derived summaries, four R1 views and provenance extracts. Exact bytes are retained;
52 acquisition records carry local package path, source path, acquisition locator,
SHA256 and size in `provenance_manifest.json`.

Five missing provenance containers were acquired with read-only `git show` from
historical object `a0a3b5b13cb5b1f4b9585954b91ee89ac17f5dc2`: source manifest,
build receipt registry, run identity, original log extract and B15 source wrapper.
All five matched the already recorded SHA256 pins. Small shared identity/build/log
containers are provenance-only; no other family's results are assessed. The wrapper
also matches the recorded source identity
`24125ea69ad8f4410f8501d3ea005a60fb92936b` and receipt source hash.

Historical salvage lineage and failed review findings remain visible as data;
`historical/` contains exact old cells/report/manifests/checks, and
`provenance/reviews/` preserves both supplied failed review records. Those old PASS
or scope strings do not grant current acceptance. No acquisition is performed by
`validate.py`; historical absolute paths and SHAs are never resolved during validation.

## EX5 observation semantics

Exactly one current retained EX5 byte read matched receipt
`br-7ee5343c5278419fa6dfafbd3a1db100`:
`2c8ce48431dea995661e149edf064d4b33faec9c883a0eb9e0209625bb7ffa9f`.
The package copy is `raw/retained/Boss_15_ST03.ex5`, labeled
`PACKAGING_TIME_RETAINED_ARTIFACT_MATCH`. Observation time is recorded in
`ex5_observation.json`. This is packaging-time retained artifact evidence;
historical loaded-memory identity remains UNKNOWN. Later validation uses the copy
only, so deleting/replacing the current runtime binary cannot affect it.
The package-local Git ignore exception makes this exact evidence binary available
for normal intake without staging or changing repository-wide ignore policy.

## MISSING / UNKNOWN

Native references remain **8 x MISSING**, native graph closure **INCOMPLETE**.
The four R1 SVGs are exact copied derived views, each byte-reproduced from the
package cells and report hashes. No native-lookalike images were created.
Independent baskets and episodes remain UNKNOWN; raw L0 entry tags (MAIN 5, BWD 6)
are not independent baskets. Sample adequacy, time in market, exposure months,
immutable Bases snapshot, complete historical tester logs, original launch INI
path and full transitive compiled source graph remain UNKNOWN/unavailable.
Zero-close years do not establish zero exposure. No new mechanism, sizing or risk
interpretation is made. Model4, robustness, MC and regime work were NOT RUN here.

## Deterministic worker checks

- Package-local validator PASS, including exact inventory and all acquired byte/hash pins.
- Report/INI/set identities and 157/157/157 maps PASS for both cells.
- Headline, canonical parser, yearly split and participation reconciliation PASS.
- Eight unique native missing references and four source-bound R1 views PASS.
- 26/26 tests PASS: physical raw mutation/deletion, refreshed-manifest tampering,
  six absolute/traversal forms, undeclared artifact, duplicate/missing/key/value
  input mutations in all three formats, duplicate JSON and tester identity refusal.
- Relocated package-only validation PASS. Runtime audit denies external opens,
  writes and process/network calls; static import/call-boundary check PASS.
- Initial authoring probes exposed helper initialization and serialized deal-row
  adapter issues; fixed during the single implementation pass. Acquired evidence
  never changed. Details remain in `worker_checks.json`.
- `git diff --check` PASS; per-new-file whitespace checks PASS with preserved CRLF
  accepted. Exact write allowlist PASS, index empty, base unchanged.

The integrity manifest follows `EA_LAB_REPORT_PACKAGE_INTEGRITY_V1` and covers
all package artifacts except itself. Package Git attributes preserve exact bytes
through checkout. The candidate Git identity remains the outer trust anchor;
unkeyed hashes cannot authenticate a replacement of both program and inventory.

## Control Tower post-commit gate

Run with Python 3.12+ stdlib (dot-source `scripts/use_python.ps1` on this device):

```text
python -B factory/runs/b15_selfcontained_provenance_20260913/validate.py --audit
python -B factory/runs/b15_selfcontained_provenance_20260913/test_package.py
python -B factory/runs/b15_selfcontained_provenance_20260913/test_fresh_clone.py <full-candidate-HEAD-SHA>
```

`test_fresh_clone.py` requires a clean committed package, bundles only candidate
HEAD, clones without a shared object database, requires the historical rejected
object to be absent, and reruns validator/audit and all negative tests. It remains
**PENDING_COMMIT** at this handoff. Required independent review belongs to Control
Tower; worker self-tests are not independent acceptance.

## Exact files changed

Only this result document and the new package were written. The complete exact
path list is in
[FILES_CHANGED.txt](../../factory/runs/b15_selfcontained_provenance_20260913/FILES_CHANGED.txt).
Per-artifact SHA256/size is in
[report_package_manifest.json](../../factory/runs/b15_selfcontained_provenance_20260913/report_package_manifest.json),
with acquisition source/path/hash bindings in
[provenance_manifest.json](../../factory/runs/b15_selfcontained_provenance_20260913/provenance_manifest.json).
