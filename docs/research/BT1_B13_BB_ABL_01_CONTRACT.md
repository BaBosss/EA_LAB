# BT1 — B13 Bollinger-Gate Ablation 01

Status: `PREREGISTERED / READY_FOR_EXECUTION`
Hypothesis ID: `HYP-B13-BB-ABL-01`
Authority: `RESEARCH_ONLY`
Canonical base SHA: `b26af204faf7907fe7e78a2b5f90a5dfa8c6bc02`
HOLDOUT: `UNSPENT`
Optimization: `NONE`

## Question and mechanism

Does the Bollinger outer-band gate contribute useful selectivity to the accepted B13 XAUUSD/M15 mean-reversion pulse, versus RSI-extreme alone?

One logical change only:
`_13_RequireBB=true -> false`.

Canonical `Entry_MeanReversion.mqh` explicitly defines `RequireBB=false` as RSI-only. RSI thresholds, exits, sizing, stack/risk settings and execution assumptions remain frozen.

Supporting accepted evidence: H02 B13 XAUUSD/M15 was a weak dual-window screening pulse. This experiment isolates one component rather than adding indicators or tuning thresholds.

## Frozen identity

- Expert: `EALabTpl\Boss_13_MeanRev`
- Current source SHA256: `733c4e395c3f0e32d3fe960742cba9d6fb98280ad740d369931328a31ae797ee`
- EX5 SHA256 on Meta5c: `23daca942b38ccb2927d4674471b69392fc445ee306d09d959350675e5408a06`
- Build receipt: `br-a2740eb18db349a58c3aa177b45389e6`
- Receipt registry SHA256: `6c5d70ba538123b24984ba9a62f547c66da7ea6353af738b4ebcc374fd28fef8`
- Parent set: `ea_template/sets/regression/Boss_13_MeanRev_defaults.set`
- Parent set SHA256: `65f3d4287effd5cf821bac6fff5f123eb17430608f32e9bfa5853216d053d9a6`
- Variant set: `factory/runs/bt1_20260830/b13_bb_abl01/B13_BB_ABL_01.set`
- Variant set SHA256: `c21ce81236414edd35ea2d953b886d955ee398125a007f01e4cc397d01ea23ed`
- Byte-preserving semantic replacement: only `_13_RequireBB=true` -> `_13_RequireBB=false`
- Runtime lineage: `MT5-lane3 / D:\Meta 5c`; MAIN and BWD stay on this install.

## Accepted parent comparison — same install only

| Window | PF | Trades | Net | EqDD | Quality | Report SHA256 |
|---|---:|---:|---:|---|---|---|
| MAIN | 1.06 | 3929 | 1063.38 | 696.10 (6.32%) | 98% | `121cd1458c7efe25e933399692a89282f534b65c14127393e9a530d22817713f` |
| BWD | 1.02 | 3300 | 253.56 | 377.02 (3.72%) | 99% | `684456e1890cdd470540f588958c967408360b943632d81fabfdad9fb4c22041` |

These parent numbers were accepted H02 evidence on the same `D:\Meta 5c` install and are not rerun.

## Frozen execution plan

- Symbol / TF: `XAUUSD / M15`
- MAIN: `2023.01.01..2025.12.31`
- BWD: `2020.01.01..2022.12.31`
- Model: `1`; Optimization: `0`; Forward: `0`
- Deposit / currency / leverage: `10000 / USD / 1:100`
- Execution order: MAIN then BWD, sequential on Meta5c.
- No rescale, no second parameter change, no HOLDOUT date.
## Falsification and mechanical acceptance

The hypothesis that the BB gate is necessary for useful selectivity is falsified if a mechanically accepted RSI-only variant has non-lower net profit AND non-higher EqDD% than the accepted parent in BOTH MAIN and BWD.

Mechanical PASS requires, independently of profit:
- exact expert/source/EX5/build-receipt identity above;
- exact variant set SHA256 above and no additional parameter difference;
- logical/tester symbol XAUUSD and TF M15;
- exact window, Model 1, Optimization 0, Forward 0, USD 10000 and leverage 1:100;
- fresh report newer than the run start and report SHA256;
- history quality captured;
- explicit truncation result and full-window eligibility;
- no HOLDOUT date.

A poor PF or negative net is evidence, not a mechanical failure and not a reason to replay the run.

Runtime expectation: two fixed Model-1 M15 runs; normally QUICK/NORMAL. This lane is parallel-safe with independent Model-1 work on MT5-lane2, subject to Lane Registry ownership.

## Direct consumer / authority ceiling

Direct consumer: decide whether B13 research should retain the two-factor BB+RSI entry thesis before any parameter-range work is considered.

Authority ceiling: research evidence only. No optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, production risk/default change, KINT resolution, or grade authority.