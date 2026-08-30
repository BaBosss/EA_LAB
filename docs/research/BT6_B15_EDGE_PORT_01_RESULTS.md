# BT6 — B15 Edge-Latch Portability 01 — Results

Status: `PASS / HYPOTHESIS_NOT_FALSIFIED / RESEARCH_ONLY`
Hypothesis ID: `HYP-B15-EDGE-PORT-01`
Canonical execution base: `e62001c5a0163c5b65790e13010b3e56bd657714`
Preregistration commit: `1522fe0b474f1c91cb084d6cf1dfb4c06bb69e40`
Runtime: `MT5-lane3 / D:\Meta 5c`
Model: `1`; Optimization: `NONE`; HOLDOUT: `UNSPENT`

## Frozen intervention

Exactly one tester-input change:
`_15_EdgeTrigger: true -> false`.

The child uses source-defined level mode, allowing repeated firing inside a continuing MACD state-run. All other inputs remained frozen. Parent set SHA256 = `ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c`; child SHA256 = `df109ecc42016bf318f7f3de1bc936b00d9abe258ec58086f9db2152e5a295f8`.

## Mechanical acceptance

All 8 preregistered parent/child cells PASS: full `157/157` input surface, exact build receipt `br-58971201f0774c47bf5e6f423c47e1bc`, exact EX5, Model 1, Optimization 0, USD 10000, leverage 1:100, fresh reports, no truncation, no HOLDOUT use. Relevant source/core/runner/parser bytes are unchanged from the accepted build lineage.
## Evidence

| Home | Window | Parent PF | Child PF | Parent net | Child net | Parent EqDD | Child EqDD | Parent trades | Child trades |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| USDJPY/H4 | MAIN | 1.24 | 0.83 | +173.71 | -279.05 | 1.45% | 3.49% | 199 | 360 |
| USDJPY/H4 | BWD | 0.97 | 0.90 | -18.83 | -122.43 | 1.61% | 2.55% | 204 | 345 |
| EURUSD/H4 | MAIN | 0.96 | 0.86 | -30.63 | -164.15 | 0.97% | 1.95% | 206 | 325 |
| EURUSD/H4 | BWD | 1.25 | 1.00 | +179.25 | -2.76 | 0.92% | 1.88% | 217 | 335 |

Removing the latch is adverse in every measured window. USDJPY/H4 parent→child deltas: PF `-0.41/-0.07`, net `-452.76/-103.60`, EqDD `+2.04/+0.94 pp`; EURUSD/H4: PF `-0.10/-0.25`, net `-133.52/-182.01`, EqDD `+0.98/+0.96 pp`. Trade count increases substantially in all four cells.

Year splits show the same mechanism pattern without hiding parent regime dependence. USDJPY/H4 parent MAIN is positive in 2023 and 2025 but BWD is negative in 2020/2021; level mode creates a large 2023 MAIN loss and a large 2022 BWD loss. EURUSD/H4 parent BWD is positive in all three BWD years, while level mode turns 2021 negative; parent MAIN remains weak in 2023/2024 regardless.

Machine-readable sources: `evidence_summary.json`, `parent_child.csv`, `year_split.csv`; raw reports/sidecars are under `factory/runs/bt6_20260830/b15_edge_port01/raw/`. `r2_parent_child.svg` is `VISUAL_ONLY_NO_AUTHORITY`.
## Interpretation

The edge-latch hypothesis is not falsified on either portability home. Together with the prior GBPUSD/H4 result, three H4 symbols now show that removing one-fire-per-MACD-run selectivity increases participation while degrading aggregate PF/net and increasing EqDD under frozen controls.

This supports the edge latch as a portable B15 mechanism contribution. It does **not** establish B15 as broadly robust: the parent remains window-dependent on USDJPY and EURUSD, so the unresolved research problem is the family’s regime/home sensitivity rather than lack of signal frequency.

## Decision

`HYPOTHESIS_NOT_FALSIFIED / PORTABLE_MECHANISM_SUPPORTED`.

Retain `_15_EdgeTrigger=true` for future B15 research. Do not use level mode as a rescue path and do not open optimization from this result. A future B15 experiment should target the remaining cross-window/regime instability with a separately preregistered one-change hypothesis.

Authority ceiling remains research-only: no optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default change, KINT resolution or Grade mapping.