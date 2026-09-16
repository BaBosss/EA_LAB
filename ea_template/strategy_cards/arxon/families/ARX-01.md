# ARX-01 — Black Tide Wave

Status: **NON_EXECUTABLE_STRATEGY_DESIGN / SOURCE_BOUND_DOCUMENTATION**

This card is now part of the planned Template library, not an executable Factory StrategyRecord. The original source note is retained; public pages were freshly captured, while manual-page details below remain carried notes, not a fresh full-manual audit.

## What the source establishes

The manual identifies eight modules: VWAP, K2 Ribbon, Initial Balance, TPO/Market Profile, Degrees of Power, Alerts, OBV and MFI. K2 uses a close-confirmed fast/slow EMA cross; EMA 55/200 are context, not implicit cross filters. A2 is a separate confluence feature. DOP is structural context, not a buy/sell decision. [S08 pp.9–10,26–30]

## Proposed role

Reusable trend/event and auction-context modules; not one mandatory all-indicator EA.

## Design options — proposals only

- A K2 cross event mapped into a qualified parent.
- A single VWAP or IB feature for a new independently justified consumer; not a restart of the closed session branch.
- A2 as a separately version-pinned timing contract, after HTF confirmation semantics are settled.

## Known settings and source scope

```json
{
  "k2_fast_ema": 8,
  "k2_slow_ema": 21,
  "manual_version": "1.13.2",
  "DOP_missing_value": "na, not neutral 0"
}
```

## Unresolved before implementation freeze

- K2 price source/seeding/warmup and exact equality boundaries for a port.
- Exact session anchor, timezone/DST and feed mapping per market.
- TPO row/tie/VA expansion rules and causal developing-history construction.
- VWAP price/volume/reset/zero-volume and band variance definitions.
- A2 configuration and real-time versus historical HTF availability; do not infer safety merely from lookahead_off.
- A deterministic historical DOP series; a live last-bar gauge is insufficient evidence.

## Event timing contract

- Emit K2 after the observed bar closes; orders cannot use the earlier open of that signal bar.
- Freeze completed session references; never put final-day VA/IB values into earlier observations.
- Unknown DOP must block the affected decision, not silently become neutral.

## Planned acceptance cases — NOT RUN

- EMA-equality touch versus actual crossing.
- Restart does not re-emit an already consumed event.
- IB pre-lock/post-lock, missing sessions, DST transitions.
- DOP missing inputs and overlapping score predicates.
- A2 pending versus confirmed HTF and late confirmation.

## New information versus the existing intake

Adds manual-bounded inventory and timing hazards. Does not qualify an experiment or reopen HYP-SB-005.

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

- [S02] Black Tide Wave — TradingView publication — https://www.tradingview.com/script/Tk0FfG9y-Black-Tide-Wave/
- [S08] Black Tide Wave User Manual v1.13.2 — https://drive.google.com/file/d/1wdmbfQang4MNnARtcApMMzGhqwifv0Z9/view
- [R03] Existing canonical Arxon future backtest plan — https://github.com/BaBosss/EA_LAB/blob/c2189c4fef9d434981ee0224ff882bb4a33046c0/knowledge/10_synthesis/ARXON_TRADE_BACKTEST_PLAN_20260913.md


## Template integration contract

Inspected base: `a9c54b8f4e2924a4329ea502ba34ffb5ee435c53`. Target **V2**, not deprecated V1 `modules/`.

See [integration plan](../../../../docs/research/ARXON_TEMPLATE_INTEGRATION_PLAN_20260916.md). The pure indicator provider, the directional entry adapter, and chassis position/risk/exit mechanics are separate. `EntrySignal.confidence` must not become a made-up probability; its consumer/meaning is a freeze gate. No FamilyID or LAB_ENTRY is allocated.

Components: [W01](../components/W01.md), [W02](../components/W02.md), [W03](../components/W03.md), [W04](../components/W04.md), [W05](../components/W05.md), [W06](../components/W06.md), [W07](../components/W07.md), [W08](../components/W08.md).

Source notes: [sources](../catalog.json) and [fresh receipts](../source_receipts.json). Settings recorded above are publisher reference settings, **not EA defaults**. The earlier R03 link is historical intake context; current authority is the inspected canonical owner.
