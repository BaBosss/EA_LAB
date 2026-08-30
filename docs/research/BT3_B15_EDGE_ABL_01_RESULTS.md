# BT3 — B15 ST03 Edge-Latch Ablation 01 — Results

Status: `PASS / HYPOTHESIS_NOT_FALSIFIED / RESEARCH_ONLY`
Hypothesis ID: `HYP-B15-EDGE-ABL-01`
Report level: `R2 MECHANISM`
Preregistration commit: `87ef6cea1506c08a41b1c7d84a45112797139071`
Canonical base SHA: `4ad1b15f26644723f2954a1416f3662b58c0b565`
Runtime: `MT5-lane3 / D:\Meta 5c`
Model: `1`
Optimization: `NONE`
HOLDOUT: `UNSPENT`

## Frozen intervention

Exactly one tester-input change from the accepted B15 baseline:

`_15_EdgeTrigger: true -> false`

All MACD periods, `_15_CountBars=2`, `_15_RearmBars=0`, exits, sizing, risk and execution settings remained frozen. Child set SHA256: `df109ecc42016bf318f7f3de1bc936b00d9abe258ec58086f9db2152e5a295f8`.

## Mechanical acceptance

Both authorized cells PASS mechanical acceptance: exact GBPUSD/H4, Model 1, Optimization 0, Forward 0, USD 10000, leverage 1:100, `FULL 157/157`, build receipt `br-58971201f0774c47bf5e6f423c47e1bc`, EX5 SHA256 `f3dd7c5f2e2c1eb5a9f30a95a120e8977aa071e86f5ea4d9929e84f74940803a`, fresh reports, 99% history quality, and no truncation.

The runner emitted an mtime-only `STALE` warning. Git-byte reconciliation from accepted build ref `cf32ba8d...` to preregistration head found `NO_RELEVANT_BYTE_CHANGES` for `Boss_15_ST03.mq5` and `ea_template/core`, so this warning is reconciled as worktree materialization timing rather than a source/binary mismatch.
## Evidence — parent versus child

| Window | Parent PF | Child PF | Parent EqDD% | Child EqDD% | Parent trades | Child trades | Child net | Report SHA256 |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| MAIN 2023-2025 | 1.10 | 0.85 | 0.97 | 2.99 | 214 | 318 | -210.43 | `e38877b96ccbb9fe8adc0a0ed0bdccb75a467c3b4c03de71449c83e8bf4d2d20` |
| BWD 2020-2022 | 1.07 | 0.88 | 1.83 | 4.18 | 218 | 341 | -223.98 | `3cd154484e465a52604dac8df14575f976b06c2225b30d997f91b2d74755d49d` |

Parent-to-child deltas from canonical H02 parent fields:
- MAIN: PF `-0.25`; EqDD `+2.02pp`; trades `+104`.
- BWD: PF `-0.19`; EqDD `+2.35pp`; trades `+123`.

The current durable H02 pair matrix does not carry parent net profit, so parent net is reported as `UNKNOWN / NOT RERUN`; accepted parent evidence was not rediscovered merely to fill that field.

## Child yearly distribution

| Window | Year | Trades | PF | Net |
|---|---:|---:|---:|---:|
| MAIN | 2023 | 122 | 0.67 | -208.21 |
| MAIN | 2024 | 104 | 0.95 | -19.22 |
| MAIN | 2025 | 92 | 1.04 | +17.00 |
| BWD | 2020 | 125 | 0.93 | -53.39 |
| BWD | 2021 | 109 | 0.60 | -205.31 |
| BWD | 2022 | 107 | 1.05 | +34.72 |

Removing the edge latch increased trade count in both windows while aggregate PF fell below 1 and EqDD rose materially. Four of six calendar years are net-negative under the child.
## Interpretation

The preregistered falsifier is not met in either window. The no-edge-latch child has both lower PF and higher EqDD than the accepted parent in MAIN and BWD. This is directionally consistent with the source comment that the edge latch exists to prevent level-mode over-trading within one MACD state run.

Within GBPUSD/H4, the evidence supports retaining one-fire-per-run edge selectivity in the B15 mechanism. It does not establish that the current MACD parameters are optimal, that the mechanism transfers to other symbols/timeframes, or that B15 is a Candidate.

## Decision

`HYPOTHESIS_NOT_FALSIFIED`.

Research conclusion: **on the accepted B15 GBPUSD/H4 pulse, removing the ST03 edge latch increases participation but destroys the dual-window positive PF profile and increases drawdown. The current mechanism evidence favors retaining the edge latch before any future B15 parameter-range work.**

No automatic optimization or next experiment is unlocked by this result.

## R2 evidence artifacts

- `factory/runs/bt3_20260830/b15_edge_abl01/evidence_summary.json`
- `factory/runs/bt3_20260830/b15_edge_abl01/mechanical_acceptance.json`
- `factory/runs/bt3_20260830/b15_edge_abl01/equity_curve.csv`
- `factory/runs/bt3_20260830/b15_edge_abl01/year_split.csv`
- `factory/runs/bt3_20260830/b15_edge_abl01/r2_equity_curve.svg`
- `factory/runs/bt3_20260830/b15_edge_abl01/r2_underwater.svg`
- `factory/runs/bt3_20260830/b15_edge_abl01/r2_year_distribution.svg`
- `factory/runs/bt3_20260830/b15_edge_abl01/r2_parent_child.svg`
- deterministic compressed raw reports plus leverage/truncation/INI evidence in `raw/`.

All SVGs are `VISUAL_ONLY_NO_AUTHORITY`.

## Authority ceiling

This result grants no optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default change, KINT resolution, Grade mapping, or production strategy-semantic authority.