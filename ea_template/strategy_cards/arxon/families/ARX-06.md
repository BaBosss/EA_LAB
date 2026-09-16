# ARX-06 — RSI Cross Alert

Status: **NON_EXECUTABLE_STRATEGY_DESIGN / SOURCE_BOUND_DOCUMENTATION**

This card is now part of the planned Template library, not an executable Factory StrategyRecord. The original source note is retained; public pages were freshly captured, while manual-page details below remain carried notes, not a fresh full-manual audit.

## What the source establishes

The main description confirms an RSI extreme after zone exit. Later release notes instead describe confirmation one bar after a turn while still inside the zone, with a new extreme rearming the marker. These are different event clocks, not cosmetic variations. Optional divergence and several smoothing modes are described. [S07]

## Proposed role

A version-pinned extreme-confirmation event after resolving timing; otherwise explicitly Arxon-inspired.

## Design options — proposals only

- Zone-exit confirmation as a separately labelled interpretation.
- One-bar-turn confirmation as a separately labelled interpretation. Neither is declared the authentic current code by this intake.

## Known settings and source scope

```json
{
  "documented_timing_variants": [
    "ZONE_EXIT",
    "ONE_BAR_TURN_INSIDE_ZONE"
  ],
  "selected_variant": null,
  "source_code_access": false
}
```

## Unresolved before implementation freeze

- Exact active version and authoritative event timing.
- RSI period/price/bands/smoothing settings.
- Ties, new extremes, rearming and repeated in-zone reversals.
- Optional divergence pivot definitions if ever separately contracted.
- Parent role, direction, invalidation and execution timing.

## Event timing contract

- Store extreme_at, confirmed_at and first_action_at separately.
- Never enter at the historical extreme just because a later label points there.
- Resolve using authorized source, author clarification, or bar-by-bar reference observation; until then no exact-parity claim.

## Planned acceptance cases — NOT RUN

- Long overbought stretch with several local peaks.
- A new extreme after an earlier in-zone turn.
- Equal RSI peaks and threshold equality.
- Zone exit versus inside-zone turn emits at different bars.
- No future label can change a past execution record.

## New information versus the existing intake

The existing SEMANTICS_REQUIRED blocker remains justified; new backtests must not choose the better-looking timing after observing outcomes.

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

- [S07] RSI Cross Alert — TradingView publication — https://www.tradingview.com/script/8T3APTKB-RSI-Cross-Alert/
- [R03] Existing canonical Arxon future backtest plan — https://github.com/BaBosss/EA_LAB/blob/c2189c4fef9d434981ee0224ff882bb4a33046c0/knowledge/10_synthesis/ARXON_TRADE_BACKTEST_PLAN_20260913.md


## Template integration contract

Inspected base: `a9c54b8f4e2924a4329ea502ba34ffb5ee435c53`. Target **V2**, not deprecated V1 `modules/`.

See [integration plan](../../../../docs/research/ARXON_TEMPLATE_INTEGRATION_PLAN_20260916.md). The pure indicator provider, the directional entry adapter, and chassis position/risk/exit mechanics are separate. `EntrySignal.confidence` must not become a made-up probability; its consumer/meaning is a freeze gate. No FamilyID or LAB_ENTRY is allocated.

Components: [O04](../components/O04.md).

Source notes: [sources](../catalog.json) and [fresh receipts](../source_receipts.json). Settings recorded above are publisher reference settings, **not EA defaults**. The earlier R03 link is historical intake context; current authority is the inspected canonical owner.
