# ARX-02 — Black Tide Map

Status: **NON_EXECUTABLE_STRATEGY_DESIGN / SOURCE_BOUND_DOCUMENTATION**

This card is now part of the planned Template library, not an executable Factory StrategyRecord. The original source note is retained; public pages were freshly captured, while manual-page details below remain carried notes, not a fresh full-manual audit.

## What the source establishes

The manual diagram lists eleven modules, although its heading says ten. It covers structure, order blocks, trend path, FVG, level groups, daily zones, anchor candles, session clock and consolidation. Several paragraphs retain older-version wording. Trend Path explicitly has provisional pivots; consolidation distinguishes provisional breaks from confirmed/failed breaks. [S09 pp.9,14,24–28,36–37,74–76]

## Proposed role

Reusable location/structure/event modules; split by causal hypothesis rather than one opaque score.

## Design options — proposals only

- One confirmed BOS/CHoCH event or one retest-location filter.
- One OB or FVG/IFVG state transition attached to an existing consumer.
- One confirmed consolidation break or failed-break event; do not combine both with multiple extra filters in the first attribution test.

## Known settings and source scope

```json
{
  "manual_cover_version": "1.15.0",
  "inventory_policy": "11 named functional slots; header/count/version discrepancies retained as evidence gaps"
}
```

## Unresolved before implementation freeze

- Pin actual selected publication/settings versus stale manual paragraphs.
- Exact swing, tie, break, initial bias and swept-level behavior.
- OB bounds/selection/mitigation/invalidation/breaker state machine and HTF rules.
- FVG size/displacement/fill/inversion priority and boundary treatment.
- Consolidation windows, range averaging, ATR, grace and reconfirmation semantics.
- Finality of Trend Path pivots and point-in-time snapshot storage.
- Candle detector thresholds and daily/session calendars.

## Event timing contract

- A pivot is tradable only when confirmed; its plotted historical location is not signal availability.
- Never backfill a provisional Trend Path pivot or a later-expanded consolidation box into past decisions.
- FVG creation and lifecycle must use completed bars and a frozen event priority.

## Planned acceptance cases — NOT RUN

- No duplicate break on an already swept swing.
- Same-bar OB touch and invalidation priority.
- FVG sweep-before-fill; previously spent gap cannot invert.
- Provisional breakout returning inside grace versus confirmed breakout.
- Bull/bear and chart/HTF event coverage; do not inherit documented alert omissions silently.

## New information versus the existing intake

Reconciles feature/version drift; does not claim every documented alert defect remains in the latest protected binary.

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

- [S01] Arxon Trade tools landing page — https://pmpenguin.github.io/arxon-trade/#tools
- [S03] Black Tide Map — TradingView publication — https://www.tradingview.com/script/5L9vbNRJ-Black-Tide-Map/
- [S09] Black Tide Map User Manual v1.15.0 — https://drive.google.com/file/d/1WXSMxoKQQ_RDR29gzTWmNcGbiuUNt4xg/view
- [R03] Existing canonical Arxon future backtest plan — https://github.com/BaBosss/EA_LAB/blob/c2189c4fef9d434981ee0224ff882bb4a33046c0/knowledge/10_synthesis/ARXON_TRADE_BACKTEST_PLAN_20260913.md


## Template integration contract

Inspected base: `a9c54b8f4e2924a4329ea502ba34ffb5ee435c53`. Target **V2**, not deprecated V1 `modules/`.

See [integration plan](../../../../docs/research/ARXON_TEMPLATE_INTEGRATION_PLAN_20260916.md). The pure indicator provider, the directional entry adapter, and chassis position/risk/exit mechanics are separate. `EntrySignal.confidence` must not become a made-up probability; its consumer/meaning is a freeze gate. No FamilyID or LAB_ENTRY is allocated.

Components: [M01](../components/M01.md), [M02](../components/M02.md), [M03](../components/M03.md), [M04](../components/M04.md), [M05](../components/M05.md), [M06](../components/M06.md), [M07](../components/M07.md), [M08](../components/M08.md), [M09](../components/M09.md), [M10](../components/M10.md), [M11](../components/M11.md).

Source notes: [sources](../catalog.json) and [fresh receipts](../source_receipts.json). Settings recorded above are publisher reference settings, **not EA defaults**. The earlier R03 link is historical intake context; current authority is the inspected canonical owner.
