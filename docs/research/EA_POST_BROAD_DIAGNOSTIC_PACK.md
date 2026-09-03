# EA_LAB Post-Broad Diagnostic Pack

Authority: `DIAGNOSTIC_ONLY` / no strategy or production authority.
Canonical acceptance/status remains owned by `PROJECT_STATE.md`.

## Purpose

Run deterministic descriptive diagnostics after a broad evidence package is complete and before a future model interpretation/reporting step. The pack removes repeated manual/model regrouping, participation recount, sign scans, and source/count/net reconciliation.

The current Boss19 P4 package is a regression fixture only. Its interpretation and 2022 confound diagnostic are already closed canonically; this tool must not reopen them or manufacture a P5 lever.

## Inputs

The tool consumes existing accepted evidence shapes rather than reparsing MT5 HTML:

- source-bound realized-unit CSV;
- source-bound package JSON binding the aggregate unit bytes and per-cell counts;
- deterministic regime-attribution detail CSV;
- regime-attribution package JSON binding the detail bytes;
- an explicit `direct_consumer` supplied by the caller.

`tools/reporting/report_package_integrity.py` is reused for output hashing and tamper validation. This capability does not create a second report schema or evidence parser.
## Deterministic outputs

1. `year_symbol_tf.csv` — entry-year × symbol × TF counts, realized net/sign, profitable/adverse/zero unit counts.
2. `month_symbol_concentration.csv` — realized exit-month × symbol participation and absolute realized-P&L concentration inside each window/symbol population.
3. `regime_year_stability.csv` — macro/local/vol state × entry-year net/sign plus observed-year sign stability.
4. `participation_no_entry.csv` — exact broad-cell participation versus package/report counts; zero diagnostic units are explicitly `NO_ENTRY`.
5. `episodes.csv` — contiguous equal-sign realized-unit runs ordered by exit/entry/source IDs. These are realized-sign diagnostic episodes, not source baskets and not native floating-equity drawdown.
6. `counterexamples_sign_reversals.csv` — observed regime-year sign reversals plus symbol/TF MAIN-vs-BWD sign reversals when present.
7. `reconciliation.json` — exact byte/source/count/net identity checks plus authority, UNIQUE OUTPUT, DOWNSTREAM SKIP and direct consumer.
8. `report_package_spec.json` and `report_package_manifest.json` — existing reporting-integrity seam over the outputs above.

## Fail-closed reconciliation

Publishing is refused when source-unit bytes do not match the source package, regime detail bytes do not match the regime package, source/detail keys differ, a key changes symbol/TF/time/net, per-cell package/report/source/detail counts disagree, extra cells appear, or aggregate source/detail counts/net fail to reconcile.

No missing row is silently imputed. No unknown regime is converted to neutral. No source basket is reconstructed from time or P&L proximity.

## Authority boundary

The pack creates no universal threshold, participation floor, Candidate/Grade/KINT result, filter/kill-switch, optimizer authority, HOLDOUT use, risk/default change, runtime action, deployment, or trading authority. Evidence presentation is not a strategy decision.
## Usage

```text
python tools/reporting/post_broad_diagnostic_pack.py \
  --units <source_bound_units.csv> \
  --source-package <source_bound_package.json> \
  --regime-detail <regime_attribution_detail.csv> \
  --regime-package <regime_attribution_package.json> \
  --out-dir <new_output_directory> \
  --direct-consumer "<named downstream consumer>"
```

Focused cage: `scripts/_test/run_post_broad_diagnostic_pack_tests.ps1`.

The accepted Boss19 P4 broad36 fixture contains 36 cells and 1,549 source-bound realized units. It is used only to prove deterministic compatibility and exact reconciliation against already accepted evidence; no new Boss19 interpretation follows from a successful fixture run.
