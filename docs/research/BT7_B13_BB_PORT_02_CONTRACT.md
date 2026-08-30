# BT7 — B13 Bollinger-Gate Portability 02

Status: `PREREGISTERED / READY_FOR_EXECUTION`
Hypothesis ID: `HYP-B13-BB-PORT-02`
Authority: `RESEARCH_ONLY`
Canonical base SHA: `e62001c5a0163c5b65790e13010b3e56bd657714`
HOLDOUT: `UNSPENT`
Optimization: `NONE`

## Direct question

Does the B13 Bollinger outer-band gate retain useful selectivity on additional H4 homes, beyond the prior XAUUSD/M15 and GBPUSD/H4 mechanism evidence?

One logical change only:
`_13_RequireBB=true -> false`.

The source defines `false` as RSI-only. RSI thresholds, exits, sizing, stack/risk settings and all other inputs remain frozen.

Known accepted evidence — DO NOT REDISCOVER: XAUUSD/M15 removal was mixed/UNCLEAR; GBPUSD/H4 removal reduced net in both windows. H02 provides complementary H4 contexts: EURUSD/H4 MAIN PF 1.15 / BWD 0.98 and XAUUSD/H4 MAIN 0.79 / BWD 1.03. Canonical raw parent reports needed for net/year diagnostics are unavailable, so this contract authorizes same-install parent controls on Meta5c rather than guessing missing metrics.
## Frozen identity and execution

- Expert: `EALabTpl\Boss_13_MeanRev`
- Source SHA256: `733c4e395c3f0e32d3fe960742cba9d6fb98280ad740d369931328a31ae797ee`
- EX5 SHA256 on Meta5c: `23daca942b38ccb2927d4674471b69392fc445ee306d09d959350675e5408a06`
- Build receipt: `br-a2740eb18db349a58c3aa177b45389e6`
- Receipt registry SHA256: `6c5d70ba538123b24984ba9a62f547c66da7ea6353af738b4ebcc374fd28fef8`
- Parent set SHA256: `65f3d4287effd5cf821bac6fff5f123eb17430608f32e9bfa5853216d053d9a6`
- Child set SHA256: `c21ce81236414edd35ea2d953b886d955ee398125a007f01e4cc397d01ea23ed`
- Relevant source/core/runner/parser bytes are unchanged from accepted receipt lineage.
- Runtime: `MT5-lane3 / D:\Meta 5c`; Model 1 only.

Run parent then child on the same install for:
1. EURUSD/H4 MAIN + BWD
2. XAUUSD/H4 MAIN + BWD

Total = 8 fixed runs. MAIN = `2023.01.01..2025.12.31`; BWD = `2020.01.01..2022.12.31`; USD 10000; leverage 1:100; Optimization 0; Forward 0; HOLDOUT unused.
## Falsifier and acceptance

For each home separately, the hypothesis that the BB gate contributes useful selectivity is falsified only if the RSI-only child has non-lower net profit AND non-higher EqDD% than its same-install parent in BOTH MAIN and BWD. Mixed evidence remains `UNCLEAR`; failure to falsify is not universal proof.

Mechanical PASS requires exact expert/EX5/build receipt, full input surface, exact parent/child set hashes, exact logical/tester symbol and TF, exact windows, Model 1, Optimization 0, Forward 0, USD 10000, leverage 1:100, fresh reports, history quality, explicit truncation/full-window result, and no HOLDOUT date.

Runtime forecast: `QUICK/NORMAL`; bottleneck is eight sequential Model-1 H4 runs on Meta5c. This lane does not use B16 files, branch, or runtime. Stop after the eight cells; no automatic threshold tuning or optimization.

Direct consumer: decide whether the mixed B13 BB-gate evidence is broadly conditional or whether a reusable H4 selectivity contribution is visible across additional homes.

Authority ceiling: research evidence only; no optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default change, KINT resolution, or Grade mapping.