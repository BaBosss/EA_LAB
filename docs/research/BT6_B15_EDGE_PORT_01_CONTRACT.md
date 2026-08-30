# BT6 — B15 Edge-Latch Portability 01

Status: `PREREGISTERED / READY_FOR_EXECUTION`
Hypothesis ID: `HYP-B15-EDGE-PORT-01`
Authority: `RESEARCH_ONLY`
Canonical base SHA: `e62001c5a0163c5b65790e13010b3e56bd657714`
HOLDOUT: `UNSPENT`
Optimization: `NONE`

## Direct question

Does the B15 one-fire-per-MACD-run edge latch retain useful selectivity beyond the accepted GBPUSD/H4 mechanism result?

One logical change only:
`_15_EdgeTrigger=true -> false`.

The source-defined level mode may re-fire repeatedly inside a continuing MACD state-run. MACD periods, CountBars, RearmBars, exits, sizing, risk and all other inputs remain frozen.

Known accepted evidence — DO NOT REDISCOVER: BT3 GBPUSD/H4 showed that removing the edge latch reduced PF from 1.10 to 0.85 MAIN and 1.07 to 0.88 BWD while increasing DD and trades. H02 provides two complementary H4 portability contexts: USDJPY/H4 MAIN 1.24 / BWD 0.97 and EURUSD/H4 MAIN 0.96 / BWD 1.25. H02 values are context only; A/B comparison uses same-install Meta5c controls.
## Frozen identity and execution

- Expert: `EALabTpl\Boss_15_ST03`
- Source SHA256: `e235105deac8c975093a920b34b84565d2d6e355fa64a7802b05dd6592c1d88f`
- EX5 SHA256 on Meta5c: `f3dd7c5f2e2c1eb5a9f30a95a120e8977aa071e86f5ea4d9929e84f74940803a`
- Build receipt: `br-58971201f0774c47bf5e6f423c47e1bc`
- Receipt registry SHA256: `6c5d70ba538123b24984ba9a62f547c66da7ea6353af738b4ebcc374fd28fef8`
- Parent set SHA256: `ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c`
- Child set SHA256: `df109ecc42016bf318f7f3de1bc936b00d9abe258ec58086f9db2152e5a295f8`
- Relevant source/core/runner/parser bytes are unchanged from accepted receipt lineage.
- Runtime: `MT5-lane3 / D:\Meta 5c`; Model 1 only.

Run parent then child on the same install for:
1. USDJPY/H4 MAIN + BWD
2. EURUSD/H4 MAIN + BWD

Total = 8 fixed runs. Windows are MAIN `2023.01.01..2025.12.31` and BWD `2020.01.01..2022.12.31`; USD 10000; leverage 1:100; Optimization 0; Forward 0; HOLDOUT unused.
## Falsifier and acceptance

For each home separately, the hypothesis that edge-latch selectivity contributes useful mechanism value is falsified only if the level-mode child has non-lower net profit AND non-higher EqDD% than its same-install parent in BOTH MAIN and BWD. Mixed evidence remains `UNCLEAR`; failure to falsify is not universal proof.

Mechanical PASS requires exact expert/EX5/build receipt, full input surface, exact parent/child set hashes, exact logical/tester symbol and TF, exact windows, Model 1, Optimization 0, Forward 0, USD 10000, leverage 1:100, fresh reports, captured history quality, explicit truncation/full-window result, and no HOLDOUT date.

Runtime forecast: `QUICK/NORMAL`; bottleneck is eight sequential Model-1 H4 runs on Meta5c. This lane does not use B16 files, branch, or runtime. Stop after the eight cells; no automatic optimization, threshold tuning, or second parameter change.

Direct consumer: determine whether the positive edge-latch contribution observed on GBPUSD/H4 is portable enough to retain as a B15 family mechanism before any later B15 research proposal.

Authority ceiling: research evidence only; no optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default change, KINT resolution, or Grade mapping.