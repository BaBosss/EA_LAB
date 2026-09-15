# DF02 Gold Robot Scalping Time Bomb — Prospective Implementation Contract — 2026-09-15

Status: `CONTRACT_FROZEN / IMPLEMENTATION_NEXT / NO_MT5 / REVIEW_GATED`

Can do: `Codex Primary` author under this exact contract; deterministic local tooling for compile/tests · Suggested: `Codex Primary`.
Required final reviewer for execution/position/money code: qualified different-model-family reviewer. ChatGPT/Codex/GPT-Hermes do not satisfy that seat.

## Identity and parent

- recovered family: `DF02`
- prospective FamilyID: `B20`
- prospective build token: `LAB_ENTRY_20`
- proposed wrapper name: `Boss_20_GoldTimeBomb`
- exact parent: `(Boss) Gold Robot Scalping Time Bomb rev1.mq5`
- exact parent SHA256: `795c446093bc0ef888bad84f162646f94d303831e8becf10955d7e016ed1f93c`
- semantic owner: `docs/research/DF02_GOLD_TIME_BOMB_PARENT_FREEZE_20260915.md`

`B20/LAB_ENTRY_20` is implementation identity only. Do not add an `E020` Strategy Catalog record in this contract.

## Objective

Create a source-faithful, bounded Template-native implementation of the frozen DF02 parent while preserving its causal mechanics and making the implementation testable. The implementation must not “improve”, normalize, simplify, or silently substitute generic chassis semantics for source-owned behavior.

## Architecture choice

Use a `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` path. The family owns trigger timing, retained grid state, flat-side gating, initial pending/market behavior, same-side adds, free-margin sizing, and group trailing.

If the existing new-entry scaffold is used, its mandatory shared-stack values are `STACK_SINGLE` and `CONF_DISTANCE` only as inert registration values. The native DF02 lifecycle must not depend on generic Stack/Recovery/Hedge to reproduce source adds.

## Required source-parity behaviors

1. TimeBombUp: Ask rise `>= Pips_to_raise` within `<= Time_to_wait` seconds; TimeBombDown mirrors on Bid.
2. BUY and SELL flat gates count positions, not pending orders.
3. Trigger success passes a current-timeframe once-per-bar gate before the initial helper.
4. `Grid_Distance_x2` starts at zero after EA initialization and changes only through add-path writes to `2 * Grid_Distance`.
5. Zero-offset initial helper must preserve the source’s market-order consequence; non-zero retained state must preserve stop-pending placement.
6. Pending expiration remains `today`; initial order path has no source SL/TP.
7. BUY and SELL each retain favorable and adverse same-side add branches using current-bar close versus newest same-side position open price.
8. All four add branches set/use the `2 * Grid_Distance` state and enforce same-side nearby-position exclusion before market add.
9. Sizing preserves source `block-freemargin` semantics; `Freeze_lot` must not be recast as literal lots.
10. Broker normalization remains part of sizing parity: lot step/min/max and margin-read failure handling must be explicit and fail-safe.
11. Group trailing applies to the source-owned group/symbol basket, both directions, `TrailWhat=1`, fixed `Trailing_Stop`, fixed `Trailing_step`, no start delay, reset-on-trade-change, and `TrailingTPmode=none`.
12. Existing TP is preserved during trailing-stop modification; this implementation must not synthesize a TP merely because the generated model contains `ftTP` storage.
13. Restart behavior is part of parity: state reinitialization to zero may change the first order type after restart exactly as in the frozen source.

## Explicit non-goals / prohibitions

- no parameter optimization, rescue search, BWD tuning, HOLDOUT use, Candidate/Grade/KINT or performance claim;
- no risk/default change and no substitution of a generic ATR×2 chassis rule for source fixed `Grid_Distance=60` semantics;
- no rewrite from free-margin sizing to fixed lot, balance-percent, FirstLotMode, or another chassis money law;
- no adding SL/TP, news/regime filter, circuit breaker, hedge/recovery, partial close, or portfolio logic not present in this parent;
- no Home symbol/TF inference from the word “Gold”; Home/TF remain unresolved until a separate freeze;
- no DEMO/LIVE attach, runtime activation, deployment, trading, or owner attestation;
- no Strategy Catalog `E020` allocation under this contract.

## Acceptance and validation

Before any MT5 tester execution is considered, the implementation lane must provide all of the following on one clean frozen head:

- exact parent hash check against `795c446093bc0ef888bad84f162646f94d303831e8becf10955d7e016ed1f93c`;
- source-parity unit/focused tests for TimeBomb reset/trigger, position-vs-pending flat gate, once-per-bar, retained grid-state/restart behavior, both favorable/adverse add branches, nearby exclusion, block-freemargin lot calculation, and SL-only group trailing;
- negative tests proving pending orders alone do not satisfy the source position gate and `ftTP` does not create a TP;
- registration tests proving `LAB_ENTRY_20` does not fall through to another entry;
- MetaEditor compile of the B20 wrapper/test expert with `0 errors / 0 warnings`;
- impacted Template deterministic tests plus `tpl_regression.ps1` or its current canonical equivalent, with existing accepted B11-B18 behavior unchanged unless a test is explicitly inapplicable to a fully native B20 path;
- `git diff --check`, normal hooks, clean-head verification, and exact changed-path review;
- independent qualified different-family review of the execution/position/money implementation. If that reviewer remains unavailable, classification is `BLOCKED_REQUIRED_DIFFERENT_FAMILY_REVIEWER`, not PASS.

One bounded repair is permitted only for an implementation/review finding under this new contract. It does not reset repair budgets of other exhausted work.

## Downstream gate

Implementation acceptance does not itself authorize a backtest. Tester execution requires a later fixed Home symbol/timeframe/settings freeze plus a prospectively registered MAIN+BWD contract. BWD is validation, not a search surface; HOLDOUT remains unspent.

## Direct consumer

A bounded Codex implementation lane for DF02/B20. If implementation and required review pass, the next consumer is Home/TF/settings freeze and then one fixed MAIN+BWD screen contract. If review cannot be satisfied, preserve the implementation head/evidence locally and stop before canonical core integration.
