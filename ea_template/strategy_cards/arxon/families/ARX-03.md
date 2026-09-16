# ARX-03 — Arxon OBV+

Status: **NON_EXECUTABLE_STRATEGY_DESIGN / SOURCE_BOUND_DOCUMENTATION**

This card is now part of the planned Template library, not an executable Factory StrategyRecord. The original source note is retained; public pages were freshly captured, while manual-page details below remain carried notes, not a fresh full-manual audit.

## What the source establishes

The standalone publication retains standard OBV and adds slope, regular/hidden divergence, smoothing and cross alerts; it explicitly is not an entry generator. The Wave manual supplies OBV-engine settings, but that is not proof that every standalone OBV+ setting and edge case is identical. [S04; S08 pp.32,72–74]

## Proposed role

Volume-activity confirmation, or one independently registered divergence event.

## Design options — proposals only

- OBV slope only as one parent filter.
- OBV versus smoothing MA only as another separate child.
- A single divergence definition only after pivot semantics are frozen.

## Known settings and source scope

```json
{
  "standalone_core": "standard OBV per publication",
  "embedded_wave_only": {
    "smoothing_type": "EMA",
    "smoothing_length": 14,
    "pivot_left": 5,
    "pivot_right": 5,
    "pivot_separation_min": 5,
    "pivot_separation_max": 60
  },
  "embedded_defaults_transfer_to_standalone": "NOT_AUTHORIZED_WITHOUT_PARITY"
}
```

## Unresolved before implementation freeze

- Standalone slope formula/window/flat rule.
- Standalone smoothing defaults and cross/equality definition.
- Which series supplies pivots and how price/OBV pivots pair.
- Regular/hidden definitions, separation count endpoints, duplicates and event expiry.
- Volume source, missing/zero handling and initial accumulation.

## Event timing contract

- Record pivot time and later confirmation time separately.
- Only consume the event at confirmation; an earlier marker position cannot authorize an earlier order.
- Do not call broker tick activity actual traded-money flow.

## Planned acceptance cases — NOT RUN

- Equal closes and OBV zero contribution.
- Missing volume is invalid, not quietly bullish/bearish.
- Equal pivot values and minimum/maximum separation edges.
- No event before required right-hand bars.
- Cross-feed differences reported rather than hidden as parity failures.

## New information versus the existing intake

Manual provides a useful separate embedded-engine reference; standalone additions remain partially unqualified.

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

- [S04] Arxon OBV+ — TradingView publication — https://www.tradingview.com/script/K0cUsn6T-Arxon-OBV/
- [S08] Black Tide Wave User Manual v1.13.2 — https://drive.google.com/file/d/1wdmbfQang4MNnARtcApMMzGhqwifv0Z9/view
- [R03] Existing canonical Arxon future backtest plan — https://github.com/BaBosss/EA_LAB/blob/c2189c4fef9d434981ee0224ff882bb4a33046c0/knowledge/10_synthesis/ARXON_TRADE_BACKTEST_PLAN_20260913.md


## Template integration contract

Inspected base: `a9c54b8f4e2924a4329ea502ba34ffb5ee435c53`. Target **V2**, not deprecated V1 `modules/`.

See [integration plan](../../../../docs/research/ARXON_TEMPLATE_INTEGRATION_PLAN_20260916.md). The pure indicator provider, the directional entry adapter, and chassis position/risk/exit mechanics are separate. `EntrySignal.confidence` must not become a made-up probability; its consumer/meaning is a freeze gate. No FamilyID or LAB_ENTRY is allocated.

Components: [O01](../components/O01.md).

Source notes: [sources](../catalog.json) and [fresh receipts](../source_receipts.json). Settings recorded above are publisher reference settings, **not EA defaults**. The earlier R03 link is historical intake context; current authority is the inspected canonical owner.
