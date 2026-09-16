# ARX-05 — Stochastic + Dual Zone Entry

Status: **NON_EXECUTABLE_STRATEGY_DESIGN / SOURCE_BOUND_DOCUMENTATION**

This card is now part of the planned Template library, not an executable Factory StrategyRecord. The original source note is retained; public pages were freshly captured, while manual-page details below remain carried notes, not a fresh full-manual audit.

## What the source establishes

The publication marks one event when K and D enter the same extreme zone and does not repeat it on every bar inside. Bands are adjustable, with published 80/20 defaults. The public wording alone does not specify every computational setting or imply an order direction. [S06]

## Proposed role

One event provider. ENTRY / ENTRY_FILTER / EXIT / CONTEXT must be selected explicitly.

## Design options — proposals only

- Use one explicit role in one exact qualified parent. No direction or default reversal/continuation is selected by this intake.

## Known settings and source scope

```json
{
  "upper_band": 80,
  "lower_band": 20,
  "event_repetition": "one-shot zone entry per description"
}
```

## Unresolved before implementation freeze

- K length, K smoothing, D smoothing and MA/price method.
- Whether both lines must cross individually on the same bar, or the joint in-zone state must first become true.
- Equality-at-band behavior, missing-value behavior, rearming after zone exit.
- Event direction mapping and parent consumer.
- Do not borrow the 9,3,3 Trend Path settings as standalone defaults.

## Event timing contract

- Create fixtures for K entering first and D entering later to resolve the two interpretations.
- Do not infer sell from a red overbought marker, or buy from a green oversold marker.
- Freeze closed-bar availability and next admissible execution before testing.

## Planned acceptance cases — NOT RUN

- Both lines enter together.
- K enters early and D later.
- Several bars inside emit once only.
- Leave and re-enter emits a new event.
- Equal thresholds, warmup and missing series.

## New information versus the existing intake

Retains canonical priority A / waiting parent and preregistration. Event wording ambiguity is explicitly tracked rather than guessed.

## Preserved unknowns

Selected parent, final entry, final exit, risk configuration and build are **unset**. Exact parity, compilation and backtests are **not performed**. No trading direction is inferred from a colour or a context score.

## Gates

1. Select an exact qualified canonical parent/direct consumer, or obtain a separately approved new-family contract; no parent is selected by this intake.
2. Freeze source/version/config, one component role, direction mapping, availability time, execution time, and a falsifier BEFORE observing result data.
3. Inspect the real template, PARAM_REGISTRY and current lane ownership; this package does not prove adapter compatibility.
4. Implement under the sole Main Control Tower contract, with required compile/deterministic gates and different-family review where applicable.
5. Verify event/value parity on an agreed feed and time basis; synthetic checks are not TradingView parity.
6. Only then open authorized parent/control versus one-change child MAIN/BWD testing; no retuning on BWD, no automatic HOLDOUT or deployment.

## Sources

- [S06] Stochastic + Dual Zone Entry — TradingView publication — https://www.tradingview.com/script/cQJIPUHO-Stochastic-Dual-Zone-Entry/
- [R03] Existing canonical Arxon future backtest plan — https://github.com/BaBosss/EA_LAB/blob/c2189c4fef9d434981ee0224ff882bb4a33046c0/knowledge/10_synthesis/ARXON_TRADE_BACKTEST_PLAN_20260913.md


## Template integration contract

Inspected base: `a9c54b8f4e2924a4329ea502ba34ffb5ee435c53`. Target **V2**, not deprecated V1 `modules/`.

See [integration plan](../../../../docs/research/ARXON_TEMPLATE_INTEGRATION_PLAN_20260916.md). The pure indicator provider, the directional entry adapter, and chassis position/risk/exit mechanics are separate. `EntrySignal.confidence` must not become a made-up probability; its consumer/meaning is a freeze gate. No FamilyID or LAB_ENTRY is allocated.

Components: [O03](../components/O03.md).

Source notes: [sources](../catalog.json) and [fresh receipts](../source_receipts.json). Settings recorded above are publisher reference settings, **not EA defaults**. The earlier R03 link is historical intake context; current authority is the inspected canonical owner.
