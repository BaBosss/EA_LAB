# BT4 — B13 Bollinger-Gate Portability Replication 01 — Results

Status: `PASS / HYPOTHESIS_NOT_FALSIFIED / RESEARCH_ONLY`
Hypothesis ID: `HYP-B13-BB-PORT-01`
Report level: `R2 MECHANISM`
Preregistration commit: `da8029d2f83f99f9682f41df60fa246cadb5bc4d`
Canonical base SHA: `4ad1b15f26644723f2954a1416f3662b58c0b565`
Runtime: `MT5-lane3 / D:\Meta 5c`
Model: `1`
Optimization: `NONE`
HOLDOUT: `UNSPENT`

## Frozen intervention

Child change only:

`_13_RequireBB: true -> false`

The child is therefore RSI-only under canonical `Entry_MeanReversion.mqh`. RSI thresholds, BB parameters, exits, sizing, stack/risk and execution settings remained frozen. Child set SHA256: `c21ce81236414edd35ea2d953b886d955ee398125a007f01e4cc397d01ea23ed`.

The preregistered same-install parent control was run because the durable H02 pair matrix did not retain parent net profit needed by the original B13 falsifier. It was not parameter search or optimization.
## Mechanical acceptance

All four authorized control/child cells PASS mechanical acceptance: exact GBPUSD/H4, Model 1, Optimization 0, Forward 0, USD 10000, leverage 1:100, `FULL 157/157`, build receipt `br-a2740eb18db349a58c3aa177b45389e6`, EX5 SHA256 `23daca942b38ccb2927d4674471b69392fc445ee306d09d959350675e5408a06`, fresh reports, 99% history quality and no truncation.

The same-install parent control reproduced canonical H02 exactly on PF/trades/EqDD in both windows, strengthening the comparison identity. Git-byte reconciliation from accepted build ref `cf32ba8d...` to preregistration head found `NO_RELEVANT_BYTE_CHANGES`; the mtime-only stale warnings are worktree materialization false positives.

## Evidence — parent versus child

| Window | Parent PF | Child PF | Parent net | Child net | Parent EqDD% | Child EqDD% | Parent trades | Child trades |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| MAIN 2023-2025 | 1.05 | 1.02 | +46.71 | +22.38 | 1.63 | 1.57 | 256 | 265 |
| BWD 2020-2022 | 1.02 | 1.01 | +29.47 | +17.33 | 2.65 | 2.71 | 272 | 273 |

Parent-to-child deltas:
- MAIN: PF `-0.03`; net `-24.33`; EqDD `-0.06pp`; trades `+9`.
- BWD: PF `-0.01`; net `-12.14`; EqDD `+0.06pp`; trades `+1`.

The child remains aggregate-positive in both windows, but fails the preregistered non-lower-net requirement in both windows; BWD also has slightly higher EqDD.
## Child yearly distribution

| Window | Year | Trades | PF | Net |
|---|---:|---:|---:|---:|
| MAIN | 2023 | 84 | 0.99 | -2.40 |
| MAIN | 2024 | 87 | 0.87 | -39.81 |
| MAIN | 2025 | 94 | 1.17 | +64.59 |
| BWD | 2020 | 101 | 0.94 | -39.95 |
| BWD | 2021 | 72 | 1.25 | +68.09 |
| BWD | 2022 | 100 | 0.98 | -10.81 |

## Interpretation

The preregistered falsifier is not met. Removing the BB gate reduces net profit in both windows; the BWD child also has slightly higher EqDD. On GBPUSD/H4, the BB condition therefore contributes measurable value beyond RSI-extreme alone under the frozen parent settings.

Combined with BT1 XAUUSD/M15, both tested B13 homes fail to demonstrate BB-gate redundancy. The strength of the effect differs: XAUUSD/M15 was mixed/unclear, whereas GBPUSD/H4 shows lower child net in both windows. This supports retaining the two-factor BB+RSI thesis for current B13 research, not claiming universal cross-market superiority.

## Decision

`HYPOTHESIS_NOT_FALSIFIED`.

Research conclusion: **the second-home replication does not support deleting the Bollinger gate. RSI-only remains slightly profitable in aggregate on GBPUSD/H4, but loses net profit in both MAIN and BWD and does not improve BWD drawdown.**

No automatic optimization or additional parameter experiment is unlocked.

R2 evidence: `factory/runs/bt4_20260830/b13_bb_port01/` contains `evidence_summary.json`, `mechanical_acceptance.json`, equity/year CSVs, four SVG decision views, compressed parent/child raw reports, INIs, leverage/truncation sidecars and source-byte reconciliation. All SVGs are `VISUAL_ONLY_NO_AUTHORITY`.

## Authority ceiling

This result grants no optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default change, KINT resolution, Grade mapping, or production strategy-semantic authority.