# B15 XX00 preserved evidence package

PACKAGE STATUS: PREPARED_FOR_REVIEW / deterministic packaging checks PASS. Independent acceptance PENDING.
STRATEGY STATUS: NOT_ASSESSED_NO_VERDICT_CHANGE. Original shared ORDER remains acceptance-blocked and repair-exhausted.
Native graph closure INCOMPLETE (8 MISSING). Basket/episode semantics UNKNOWN; sample adequacy UNKNOWN_NOT_ASSESSED.

Exact rejected input: `a0a3b5b13cb5b1f4b9585954b91ee89ac17f5dc2:factory/runs/xx00_b13_b15_screen_20260909/`. Source: `24125ea69ad8f4410f8501d3ea005a60fb92936b`. Packaging base: `45319cd5941607403279aeed2c100aab78e9bc65`.
Home is the already-frozen GBPUSD/H4; all observations below are MT5-lane3 / `D:\Meta 5c`, Model1, report build6140.
This is a new B15 packaging-only contract, not an experiment, retuning pass, native graph reconstruction or old-order repair.

| Cell/window | PF | Net USD | Closed tickets | L0 entry tags | Native maximal EqDD | Entry / close / deal months |
|---|---:|---:|---:|---:|---|---|
| XX00_B15_GBPUSD_H4_MAIN_M1 | 0.28 | -357.84 | 13 | 5 | 5.83% / USD591.01 | 3/36 / 4/36 / 4/36 |
| XX00_B15_GBPUSD_H4_BWD_M1 | 2.12 | 137.96 | 24 | 6 | 6.37% / USD654.16 | 8/36 / 8/36 / 9/36 |

All metrics and identity fields point to exact report hashes in [cells.json](cells.json); full 157-key maps, raw deals, canonical parser output and annual rows are under `derived/`. Raw INI, reports, set and sidecars are byte-identical Git copies. `provenance/raw_origins.json` binds every copy to its original ref/path/hash.
Tickets are report Total Trades, reconciled to out-deal rows. Raw L0 counts are exact Direction=in / Comment=15_ST03 L0 rows, not independent baskets or episodes. Entry/deal/close active months measure ledger activity only. Time-in-market, exposure months, basket count and independent episode count remain UNKNOWN.

## Identity and coverage

Each record explicitly serializes Expert, Report, Symbol, Period, leverage, Model, Optimization, ForwardMode, deposit, currency, dates, install lineage, preserved INI absolute path/name/hash and all source/build/set/report references. Original launch INI path remains UNKNOWN. Report inputs normalize numeric lexical formatting only; all 157 keys and values match the exact set/INI surface.
Build receipt `br-7ee5343c5278419fa6dfafbd3a1db100` pins retained EX5 SHA256 `2c8ce48431dea995661e149edf064d4b33faec9c883a0eb9e0209625bb7ffa9f` and wrapper SHA256. `source_pins.json` under provenance records the original manifest and registry hashes. Coverage is wrapper/set/receipt registry, not a transitive compiled source graph or historical loaded-memory proof.
Both original leverage sidecars remain MATCH; both original truncation sidecars remain CHECK_PASS / truncated=false. This package reconciles preserved mechanical evidence and does not recreate runtime acceptance. History quality is 99% in each report. Tick/bar counts and report company are serialized per cell; no cross-install comparison is made.

## R1 presentation views

- [PF by frozen Home/window](views/pf_home_window.svg)
- [Opportunity counts and participation](views/opportunity_participation.svg)
- [PF versus entry-active months](views/pf_vs_participation.svg)
- [Native report maximal EqDD scalar](views/native_eqdd.svg)

The EqDD view displays the native HTML field Equity Drawdown Maximal (percentage and corresponding USD). It is a derived presentation, not a native equity/underwater series. No native images were recreated. Each SVG includes run/source/lane, report hashes, ticket and L0 counts, unknown baskets/episodes and explicit missing state.

## Annual coverage and missing native assets

**MAIN**: literal INI dates `2023.01.01..2025.12.31`. Annual closed-ticket counts: 2023=10, 2024=0, 2025=3.
Canonical year-split functions use close-deal P/L including commission/swap; annual balance DD resets to USD10000 and is not floating EqDD. Zero-close rows are supported by complete report-deal reconciliation and unchanged full-window sidecars; they never imply zero exposure. PF without gross loss is undefined/null.
- `XX00_B15_GBPUSD_H4_MAIN_M1-holding.png`: **MISSING**
- `XX00_B15_GBPUSD_H4_MAIN_M1-hst.png`: **MISSING**
- `XX00_B15_GBPUSD_H4_MAIN_M1-mfemae.png`: **MISSING**
- `XX00_B15_GBPUSD_H4_MAIN_M1.png`: **MISSING**

**BWD**: literal INI dates `2020.01.01..2022.12.31`. Annual closed-ticket counts: 2020=14, 2021=0, 2022=10.
Canonical year-split functions use close-deal P/L including commission/swap; annual balance DD resets to USD10000 and is not floating EqDD. Zero-close rows are supported by complete report-deal reconciliation and unchanged full-window sidecars; they never imply zero exposure. PF without gross loss is undefined/null.
- `XX00_B15_GBPUSD_H4_BWD_M1-holding.png`: **MISSING**
- `XX00_B15_GBPUSD_H4_BWD_M1-hst.png`: **MISSING**
- `XX00_B15_GBPUSD_H4_BWD_M1-mfemae.png`: **MISSING**
- `XX00_B15_GBPUSD_H4_BWD_M1.png`: **MISSING**

## Explicit schema limits and authority

Family=B15, variant=xx-00, entry family=ST03; original screen hypothesis/parent authority is referenced in the frozen original contract. No parent delta or new hypothesis is introduced. Entry/BUY/SELL/filter/state semantics, basket grouping, max concurrent positions, max aggregate lots, relative exposure, normalized grid span, broker volume step and validated lot ladder are UNKNOWN in this bounded packaging analysis; raw inputs and CFG excerpts are retained for the consumer. No missing mechanics are supplied from current source or another Home.
Optimization, sensitivity, Model4, MC, regime attribution and portability analysis: NOT RUN by this package. HOLDOUT: NOT ACCESSED. Verdict, Grade, KINT and build-potential assignments: NOT ASSIGNED by this contract. No new sample floor or R1 pulse classification is applied. Missing independent-basket semantics blocks basket-aware/sample-adequacy closure; native closure remains incomplete even when byte/identity checks pass.
Direct consumer: Control Tower reviews this exact committed packaging result. No strategy conclusion, Candidate eligibility, risk/default/runtime/deployment/trading authority or canonical acceptance follows from these checks.

## Reproduce and validate

Dot-source `scripts/use_python.ps1` first. Existing portable runtime `D:\EA_LAB\tools\python312\python.exe -B` was used read-only because this worktree lacks its stdlib archive. No Python provisioning or external writes occurred.
Run `python -B factory/runs/salvage_b15_xx00_20260912/package.py --validate` from the repo with a complete portable runtime. `--build` is single-pass and refuses an existing cells.json or a different base HEAD. Canonical reporting modules and their exact base hashes are listed in provenance. The canonical integrity validator is also directly runnable against `report_package_manifest.json`.
Budget: one packaging pass; bounded repair used=0 at initial generation, maximum=1. Consult final validation and handoff for any later repair. Normal commit hooks and final staged allowlist checks are required. No push.
