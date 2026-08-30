# BT5 — B12 Breakout Confirmation Ablation 01 — Results

Status: `PASS / HYPOTHESIS_NOT_FALSIFIED / RESEARCH_ONLY`
Hypothesis ID: `HYP-B12-CONFIRM-ABL-01`
Canonical execution base: `e62001c5a0163c5b65790e13010b3e56bd657714`
Preregistration commit: `c13ae3eb1f06dce7e1bf8c4e1835dc0794b1f9e0`
Runtime: `MT5-lane3 / D:\Meta 5c`
Model: `1`; Optimization: `NONE`; HOLDOUT: `UNSPENT`

## Frozen intervention

Exactly one tester-input change from the canonical B12 regression default:
`_12_ConfirmBars: 1 -> 0`.

The source defines `1` as one closed bar beyond the pre-confirmation Donchian channel and `0` as tick-level ask/bid breakout. All other 154 declared inputs remained frozen. Parent set SHA256 = `62ffa4e95a08a483617046694309a8082c1d07bece39a778704f67cb389626c1`; child SHA256 = `6d4b3e12cdfe87cd555b2a91f147b2de8714ed623adf282d816e1142ee5dc00d`.

## Mechanical acceptance

All 8 preregistered parent/child cells PASS: full `155/155` surface, exact build receipt `br-c65dbb2519f84815adb3cfe950e80bc5`, EX5 SHA256 `c4fef862...de3a9`, Model 1, optimization 0, USD 10000, leverage 1:100, fresh reports, no truncation and no HOLDOUT use. The mtime-only stale warning is reconciled by unchanged relevant source/runner bytes.
## Evidence

| Home | Window | Parent PF | Child PF | Parent net | Child net | Parent EqDD | Child EqDD | Parent trades | Child trades |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| XAUUSD/H4 | MAIN | 1.26 | 1.05 | +1019.50 | +261.06 | 2.96% | 4.24% | 250 | 293 |
| XAUUSD/H4 | BWD | 0.91 | 0.79 | -249.43 | -799.45 | 5.45% | 9.92% | 233 | 289 |
| USDJPY/H1 | MAIN | 0.93 | 0.85 | -130.94 | -406.06 | 2.25% | 4.40% | 970 | 1261 |
| USDJPY/H1 | BWD | 1.15 | 0.99 | +212.75 | -19.55 | 0.70% | 1.87% | 956 | 1185 |

Parent→child deltas are adverse in every window: XAUUSD/H4 PF `-0.21/-0.12`, net `-758.44/-550.02`, EqDD `+1.28/+4.47 pp`; USDJPY/H1 PF `-0.08/-0.16`, net `-275.12/-232.30`, EqDD `+2.15/+1.17 pp`. Tick-level mode increases participation in all four cells but does not convert that extra participation into better aggregate results.

Year splits retain the regime asymmetry rather than averaging it away. XAUUSD/H4 parent MAIN gain is concentrated in 2025 while parent BWD is negative in 2020, 2021 and 2022; the tick-level child worsens the BWD years. USDJPY/H1 parent MAIN is negative in each of 2023–2025, while parent BWD is positive in each 2020–2022; the child makes 2021 BWD negative and the aggregate BWD slightly negative.

Machine-readable sources: `evidence_summary.json`, `parent_child.csv`, `year_split.csv`; raw reports and sidecars are under `factory/runs/bt5_20260830/b12_confirm_abl01/raw/`. `r2_parent_child.svg` is `VISUAL_ONLY_NO_AUTHORITY`.
## Interpretation

The preregistered selectivity hypothesis is not falsified on either home. Removing the closed-bar confirmation worsened PF, net and EqDD in both MAIN and BWD for both XAUUSD/H4 and USDJPY/H1 while increasing trade count. The confirmation mechanism therefore has positive measured contribution under these frozen controls.

This does **not** rescue B12 as a robust strategy. The parent itself remains strongly window-dependent: XAUUSD/H4 is positive only in MAIN, while USDJPY/H1 is positive only in BWD. The experiment supports retaining closed-bar confirmation for future B12 research, but it also strengthens the diagnosis that B12's unresolved problem is broader than confirmation timing.

## Decision

`HYPOTHESIS_NOT_FALSIFIED` for both homes. `MECHANISM_VALUE = SUPPORTED_BUT_NOT_SUFFICIENT`.

Do not switch B12 to tick-level mode and do not open optimization from this result. Any further B12 work needs a new prospective one-change hypothesis aimed at the remaining cross-window/regime instability rather than tuning `_12_ConfirmBars` from hindsight.

Authority ceiling remains research-only: no optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default change, KINT resolution or Grade mapping.