# BT5 — B12 Breakout Confirmation Ablation 01

Status: `PREREGISTERED / READY_FOR_EXECUTION`
Hypothesis ID: `HYP-B12-CONFIRM-ABL-01`
Authority: `RESEARCH_ONLY`
Canonical base SHA: `e62001c5a0163c5b65790e13010b3e56bd657714`
HOLDOUT: `UNSPENT`
Optimization: `NONE`

## Direct question

Does B12's one-closed-bar Donchian breakout confirmation contribute useful cross-window robustness versus the source-defined tick-level breakout mode?

One logical change only:
`_12_ConfirmBars=1 -> 0`.

The source defines `0` as tick-level ask/bid breakout and `>=1` as N closed bars beyond the pre-confirmation channel. `_12_Bars`, session filter, TradeDir, TrendFilter, exits, sizing, position engine, risk and all other inputs remain frozen.

Known accepted evidence — DO NOT REDISCOVER: H02 found no B12 dual-window positive pair. Two complementary cells are selected prospectively for mechanism diagnosis: XAUUSD/H4 had MAIN PF 1.26 and BWD PF 0.91; USDJPY/H1 had MAIN PF 0.93 and BWD PF 1.15. Those H02 values are context only; A/B comparison below uses same-install parent controls on Meta5c.
## Frozen identity

- Expert: `EALabTpl\Boss_12_Breakout`
- Source SHA256: `b455e2b36b679ccd5bb17d31ccae29261c9587e83e24775fdc76b63c6de4d349`
- EX5 SHA256 on Meta5c: `c4fef86203803165675063074e04fd1560a970c64a12eaa53125c1569a6de3a9`
- Build receipt: `br-c65dbb2519f84815adb3cfe950e80bc5`
- Receipt registry SHA256: `6c5d70ba538123b24984ba9a62f547c66da7ea6353af738b4ebcc374fd28fef8`
- Parent set: `ea_template/sets/regression/Boss_12_Breakout_defaults.set`
- Parent set SHA256: `62ffa4e95a08a483617046694309a8082c1d07bece39a778704f67cb389626c1`
- Child set: `factory/runs/bt5_20260830/b12_confirm_abl01/B12_CONFIRM_ABL_01.set`
- Child set SHA256: `6d4b3e12cdfe87cd555b2a91f147b2de8714ed623adf282d816e1142ee5dc00d`
- No relevant byte changes exist from accepted receipt base `cf32ba8d...` through this canonical base for B12 source/core/runner/parser/truncation paths.
- Runtime: `MT5-lane3 / D:\Meta 5c`, Model 1 only. No Model 4.

## Execution matrix

Run parent then child on the same install for each home:
1. XAUUSD/H4 MAIN `2023.01.01..2025.12.31`
2. XAUUSD/H4 BWD `2020.01.01..2022.12.31`
3. USDJPY/H1 MAIN `2023.01.01..2025.12.31`
4. USDJPY/H1 BWD `2020.01.01..2022.12.31`

This is 8 fixed Model-1 runs total: parent+child × four window cells. Deposit/currency/leverage = `10000 / USD / 1:100`; Optimization=0; Forward=0.
## Falsifier and acceptance

For each home separately, the hypothesis that closed-bar confirmation contributes useful selectivity is falsified only if the tick-level child has non-lower net profit AND non-higher EqDD% than its same-install parent in BOTH MAIN and BWD. Mixed evidence remains `UNCLEAR`; a failure to falsify is not proof of universal necessity.

Mechanical PASS is independent of profit and requires: exact expert/EX5/build receipt; full declared input surface; exact parent/child set hashes; exact logical/tester symbol and TF; exact windows; Model 1; Optimization 0; Forward 0; USD 10000; leverage 1:100; fresh report; history quality captured; truncation/full-window check; and no HOLDOUT date.

Parent reproduction on Meta5c is a same-install control, not a replacement for accepted H02 evidence. If a parent materially disagrees with H02, retain both and treat install/data identity as evidence rather than silently substituting one.

Runtime forecast: `QUICK/NORMAL`; bottleneck is eight sequential Model-1 runs on Meta5c. Parallel safety: this lane owns MT5-lane3 and does not use or modify B16 worktree/branch/runtime. Stop expansion after these eight runs; at most one bounded harness repair is allowed. No optimization or additional parameter change follows automatically.

Direct consumer: determine whether B12's cross-window weakness is materially tied to confirmation timing before any future B12 parameter-range or redesign proposal.

Authority ceiling: no HOLDOUT, optimization, Candidate, DEMO/LIVE, deployment, trading, risk/default change, KINT resolution, Grade mapping, or production-semantic authority.