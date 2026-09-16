# ARX-04 — Arxon MFI+

Status: **NON_EXECUTABLE_STRATEGY_DESIGN / SOURCE_BOUND_DOCUMENTATION**

This card is now part of the planned Template library, not an executable Factory StrategyRecord. The original source note is retained; public pages were freshly captured, while manual-page details below remain carried notes, not a fresh full-manual audit.

## What the source establishes

The public standalone specification gives length 7, hlc3, Bull above 55, Neutral 45–55, Bear below 45, and extremes 90/10. The state depends on the current level without hysteresis. Standalone levels are constants in the described v1.0. The Wave version has separately adjustable bands. [S05; S08 pp.74–75]

## Proposed role

A three-state context filter, not an automatic green=buy/red=sell system.

## Design options — proposals only

- One qualified parent gate that uses only the published three-state context.
- Extreme detection as a separate hypothesis, not an unregistered addition to the three-state filter.

## Known settings and source scope

```json
{
  "length": 7,
  "price_source": "hlc3",
  "bull_above": 55,
  "bear_below": 45,
  "neutral_inclusive": [
    45,
    55
  ],
  "overbought": 90,
  "oversold": 10,
  "state_hysteresis": false
}
```

## Unresolved before implementation freeze

- Exact parent/role/direction and treatment of neutral for entries versus already-open positions.
- Feed volume semantics and missing data policy.
- Numerical warmup and zero positive/negative flow edge cases for platform parity.
- Completed-bar sampling and first admissible order time.
- Do not transfer Wave-adjustable bands into the standalone definition silently.

## Event timing contract

- Read the completed-bar MFI state for a close-confirmed contract.
- Neutral is valid data; missing data is a separate invalid state.
- A state change is not automatically a trade event.

## Planned acceptance cases — NOT RUN

- MFI 44.999 / 45 / 50 / 55 / 55.001 boundary classification.
- Bull -> neutral -> bear has no sticky previous state.
- Flat prices and zero-flow edge cases.
- No duplicated orders on repeated bull bars.
- Same price and volume fixtures agree with frozen platform reference.

## New information versus the existing intake

NEW PARTIAL SOURCE CLOSURE: period, source, thresholds and state semantics now have primary-source support. Parent/role/feed/parity gates remain open; no canonical status was edited.

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

- [S05] Arxon MFI+ — TradingView publication — https://www.tradingview.com/script/eBoUoU2u-Arxon-MFI/
- [S08] Black Tide Wave User Manual v1.13.2 — https://drive.google.com/file/d/1wdmbfQang4MNnARtcApMMzGhqwifv0Z9/view
- [R03] Existing canonical Arxon future backtest plan — https://github.com/BaBosss/EA_LAB/blob/c2189c4fef9d434981ee0224ff882bb4a33046c0/knowledge/10_synthesis/ARXON_TRADE_BACKTEST_PLAN_20260913.md


## Template integration contract

Inspected base: `a9c54b8f4e2924a4329ea502ba34ffb5ee435c53`. Target **V2**, not deprecated V1 `modules/`.

See [integration plan](../../../../docs/research/ARXON_TEMPLATE_INTEGRATION_PLAN_20260916.md). The pure indicator provider, the directional entry adapter, and chassis position/risk/exit mechanics are separate. `EntrySignal.confidence` must not become a made-up probability; its consumer/meaning is a freeze gate. No FamilyID or LAB_ENTRY is allocated.

Components: [O02](../components/O02.md).

Source notes: [sources](../catalog.json) and [fresh receipts](../source_receipts.json). Settings recorded above are publisher reference settings, **not EA defaults**. The earlier R03 link is historical intake context; current authority is the inspected canonical owner.
