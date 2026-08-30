# BT3 — B15 ST03 Edge-Latch Ablation 01

Status: `PREREGISTERED / READY_FOR_EXECUTION`
Hypothesis ID: `HYP-B15-EDGE-ABL-01`
Authority: `RESEARCH_ONLY`
Canonical base SHA: `4ad1b15f26644723f2954a1416f3662b58c0b565`
HOLDOUT: `UNSPENT`
Optimization: `NONE`

## Question and mechanism

Does the one-fire-per-MACD-state-run edge latch contribute useful selectivity to the accepted B15 GBPUSD/H4 dual-window pulse?

One logical change only:
`_15_EdgeTrigger=true -> false`.

Canonical `Entry_ST03.mqh` defines the default edge latch as firing once after `_15_CountBars` is reached and re-arming only when state changes (or via `_15_RearmBars`, frozen at 0 here). With `_15_EdgeTrigger=false`, the same MACD state and count mechanics may emit again on later bars. MACD periods, CountBars, RearmBars, exits, sizing, risk and execution remain frozen.

Supporting accepted evidence: H02 B15 GBPUSD/H4 is a narrow dual-window screening pulse: MAIN PF 1.10 / 214 trades / EqDD 0.97%; BWD PF 1.07 / 218 trades / EqDD 1.83%. H02 is screening evidence only and grants no optimization authority.
## Frozen identity

- Expert: `EALabTpl\Boss_15_ST03`
- Source SHA256: `e235105deac8c975093a920b34b84565d2d6e355fa64a7802b05dd6592c1d88f`
- EX5 SHA256 on Meta5c: `f3dd7c5f2e2c1eb5a9f30a95a120e8977aa071e86f5ea4d9929e84f74940803a`
- Build receipt: `br-58971201f0774c47bf5e6f423c47e1bc`
- Receipt registry SHA256: `6c5d70ba538123b24984ba9a62f547c66da7ea6353af738b4ebcc374fd28fef8`
- Parent set: `ea_template/sets/regression/Boss_15_ST03_defaults.set`
- Parent set SHA256: `ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c`
- Variant set: `factory/runs/bt3_20260830/b15_edge_abl01/B15_EDGE_ABL_01.set`
- Variant set SHA256: `df109ecc42016bf318f7f3de1bc936b00d9abe258ec58086f9db2152e5a295f8`
- Deterministic diff: exactly one assignment, `_15_EdgeTrigger=true -> false`; line count remains 160.
- H02 parent runtime owner: `MT5-lane3 / D:\Meta 5c`; B11/B13/B15 H02 lane is DONE.
- New runtime lineage: `MT5-lane3 / D:\Meta 5c`; MAIN then BWD sequentially.

## Frozen execution plan

- Symbol / TF: `GBPUSD / H4`
- MAIN: `2023.01.01..2025.12.31`
- BWD: `2020.01.01..2022.12.31`
- Model: `1`; Optimization: `0`; Forward: `0`
- Deposit / currency / leverage: `10000 / USD / 1:100`
- No rescale, no second parameter change, no HOLDOUT date.
- Runtime expectation: two fixed Model-1 H4 runs, `QUICK`; bottleneck `MT5-lane3`.
- Parallel safety: does not use `MT5-lane2`; B16 characterization remains untouched.
## Falsification and mechanical acceptance

The hypothesis that the edge latch contributes useful selectivity is falsified if a mechanically accepted no-edge-latch child has PF greater than or equal to the accepted parent PF AND EqDD% less than or equal to the accepted parent EqDD% in BOTH MAIN and BWD.

Accepted parent comparison from canonical H02:
- MAIN: PF `1.10`, trades `214`, EqDD `0.97%`.
- BWD: PF `1.07`, trades `218`, EqDD `1.83%`.

Mechanical PASS requires, independently of profit:
- exact expert/source/EX5/build-receipt identity above;
- exact variant-set SHA and exactly one parameter difference;
- logical/tester symbol GBPUSD and TF H4;
- exact window, Model 1, Optimization 0, Forward 0, USD 10000 and leverage 1:100;
- fresh report newer than run start and report SHA256;
- history quality captured;
- explicit truncation/full-window result;
- no HOLDOUT date.

A poor PF, high DD, or negative net is strategy evidence, not a mechanical failure and not a reason to replay.

## Direct consumer / authority ceiling

Direct consumer: decide whether B15 mechanism research should retain one-fire-per-run edge selectivity before any parameter-range or deeper build-on work is considered.

Authority ceiling: research evidence only. No optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, production risk/default change, KINT resolution, or Grade authority.