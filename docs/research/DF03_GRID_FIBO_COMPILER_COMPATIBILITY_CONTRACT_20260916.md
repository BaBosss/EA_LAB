# DF03 Grid Horizontal Line / Fibonacci — Compiler Compatibility Contract — 2026-09-16

Status: `PROSPECTIVE / SOURCE-BOUND / NO IMPLEMENTATION AUTHORITY / NO_MT5`.

## Question

Can the exact frozen DF03 parent be represented on the current EA Template/toolchain without changing its causal mechanics, despite the recovered MQ5 bytes no longer compiling directly under the current MetaEditor?

## Source identity

- frozen parent SHA256: `2aba9437319e214c82b63313a049f73da364052eddfa24f7f1661279593ffd89`
- semantic owner: `docs/research/DF03_GRID_FIBO_PARENT_FREEZE_20260916.md`
- external freeze receipt SHA256: `e49ebd1aca26329f68b9dfcb9bfc4281c2cef03c349cce9cf02c94343c7c55ea`

The evidence source is immutable for this contract. Do not edit it, regenerate it, or substitute old rev4.x as the parent.

## Required compatibility work

1. Isolate generated compatibility failures (`Bars`, `Digits`, `Point`, `::Bars` family) from strategy-owned blocks.
2. Produce a deterministic causal map for all 15 OnTick roots, 2 OnTrade roots, their outbound closure, source inputs and source-owned state.
3. Preserve internal `Timeframe=PERIOD_D1` semantics separately from branches that use `CurrentTimeframe()`.
4. Preserve the ten `Hedging_mode_1_on_0_off == 1.0` gates and the hedge legs they control.
5. Preserve source lot ladder, pull-back/nearby logic, close-all ownership, TP/SL semantics and magic ownership exactly as proven from the parent.
6. Define explicit fail-closed behavior for any source construct whose causal meaning cannot be recovered deterministically.
## Implementation boundary

This contract does not allocate the next FamilyID/LAB_ENTRY and does not authorize code generation. Identity allocation belongs to a later implementation contract after the compatibility map is accepted and collision-checked against current canonical state.

A later implementation may use a family-native pipeline or explicit adapter. It must not route DF03 through generic Stack/Recovery/Hedge defaults merely because those seams exist in the Template.

## Acceptance before implementation contract

- exact parent hash reverified;
- causal map complete enough to account for every strategy-owned root and order-producing branch;
- compiler failures classified as compatibility-layer defects rather than silently repaired strategy logic;
- candidate-vs-old-revision differences retained as explicit evidence;
- Home symbol and chart timeframe either source-qualified or left unresolved;
- no historical same-filename EX5/profile accepted unless its parameter surface/build identity matches the frozen source;
- no current source/core mutation and no MT5 execution.

## Later implementation gates

Any execution/position/money implementation requires deterministic source-parity tests, MetaEditor compile, impacted regression cages, normal commit hooks, and mandatory qualified different-model-family review before canonical integration. ChatGPT/Codex/GPT-Hermes are same-family for this gate.

## Forbidden

No performance claim, optimizer, BWD tuning, HOLDOUT access, arbitrary Home selection, source-patching-as-truth, E-record promotion, deployment/runtime change, LIVE/DEMO trading, risk/default change, or silent semantic repair.

Direct consumer: one bounded DF03 implementation-contract proposal only after this compatibility contract is accepted.