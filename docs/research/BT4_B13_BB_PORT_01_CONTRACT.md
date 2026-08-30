# BT4 — B13 Bollinger-Gate Portability Replication 01

Status: `PREREGISTERED / READY_FOR_EXECUTION`
Hypothesis ID: `HYP-B13-BB-PORT-01`
Authority: `RESEARCH_ONLY`
Canonical base SHA: `4ad1b15f26644723f2954a1416f3662b58c0b565`
HOLDOUT: `UNSPENT`
Optimization: `NONE`

## Question and mechanism

Does the Bollinger outer-band gate contribute useful selectivity on a second accepted B13 home, GBPUSD/H4, or does RSI-extreme alone preserve the parent result?

One logical child change only:
`_13_RequireBB=true -> false`.

Canonical `Entry_MeanReversion.mqh` defines `RequireBB=false` as RSI-only. RSI thresholds, BB period/deviation, exits, sizing, stack/risk settings and execution assumptions remain frozen.

Known accepted evidence: BT1 on B13 XAUUSD/M15 found the same one-change RSI-only child `HYPOTHESIS_NOT_FALSIFIED / UNCLEAR`; MAIN net was slightly lower while BWD net improved. H02 independently identified B13 GBPUSD/H4 as a dual-window pulse: MAIN PF 1.05 / 256 trades / EqDD 1.63%; BWD PF 1.02 / 272 trades / EqDD 2.65%.
## Frozen identity

- Expert: `EALabTpl\Boss_13_MeanRev`
- Source SHA256: `733c4e395c3f0e32d3fe960742cba9d6fb98280ad740d369931328a31ae797ee`
- EX5 SHA256 on Meta5c: `23daca942b38ccb2927d4674471b69392fc445ee306d09d959350675e5408a06`
- Build receipt: `br-a2740eb18db349a58c3aa177b45389e6`
- Receipt registry SHA256: `6c5d70ba538123b24984ba9a62f547c66da7ea6353af738b4ebcc374fd28fef8`
- Parent set: `ea_template/sets/regression/Boss_13_MeanRev_defaults.set`
- Parent set SHA256: `65f3d4287effd5cf821bac6fff5f123eb17430608f32e9bfa5853216d053d9a6`
- Child set: `factory/runs/bt4_20260830/b13_bb_port01/B13_BB_PORT_01.set`
- Child set SHA256: `c21ce81236414edd35ea2d953b886d955ee398125a007f01e4cc397d01ea23ed`
- Deterministic child diff: exactly `_13_RequireBB=true -> false`.
- Runtime: `MT5-lane3 / D:\Meta 5c`; B16 characterization remains on `MT5-lane2` and is not touched.

## Same-install parent control

The current durable H02 pair matrix carries PF/trades/EqDD but not parent net profit. The original B13 BT1 falsifier uses parent net + EqDD. To reuse that criterion without inventing or silently changing it, this contract authorizes one same-install fixed-baseline control in MAIN and BWD immediately before the child runs.

This parent control is a diagnostic requirement for the new portability comparison, not optimizer/search work. It may not change parameters or consume HOLDOUT.
## Frozen execution plan

- Symbol / TF: `GBPUSD / H4`
- MAIN: `2023.01.01..2025.12.31`
- BWD: `2020.01.01..2022.12.31`
- Model: `1`; Optimization: `0`; Forward: `0`
- Deposit / currency / leverage: `10000 / USD / 1:100`
- Sequence: parent MAIN -> parent BWD -> child MAIN -> child BWD, all on Meta5c.
- No rescale, no second child parameter change, no HOLDOUT date.
- Runtime expectation: four fixed Model-1 H4 runs, `QUICK/NORMAL`; bottleneck `MT5-lane3`.

## Falsification and mechanical acceptance

The hypothesis that the BB gate is necessary for useful selectivity is falsified if the mechanically accepted RSI-only child has non-lower net profit AND non-higher EqDD% than the same-install parent control in BOTH MAIN and BWD.

Mechanical PASS requires, independently of profit:
- exact expert/source/EX5/build-receipt identity above;
- parent set exactly equals the frozen baseline and child set differs by exactly one assignment;
- logical/tester symbol GBPUSD and TF H4;
- exact windows, Model 1, Optimization 0, Forward 0, USD 10000 and leverage 1:100;
- fresh reports with SHA256, history quality, truncation/full-window checks;
- no HOLDOUT date.

A poor result is evidence, not a mechanical failure and not a reason to replay.

## Direct consumer / authority ceiling

Direct consumer: determine whether B13's BB-gate contribution is reusable across XAUUSD/M15 and GBPUSD/H4 before any B13 parameter-range work.

Authority ceiling: research evidence only. No optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, production risk/default change, KINT resolution, or Grade authority.