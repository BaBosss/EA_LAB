# Boss19 P4B Source-Bound Unit Export Contract

Status: `PREREGISTERED / RESEARCH_ONLY / NO ATTRIBUTION YET`
Base: `3207b4372a296e1fe6fc60f0b8c1ce3f0e18e4f1`
Direct consumer: `ORDER-RND-P4` P4B unit-attribution prerequisite.

## Objective

Replace the current H3 HTML evidence-shape blocker with a new, source-emitted MT5 deal export that carries a durable `DEAL_POSITION_ID` for every Boss19 trading deal. Build realized DEAL units only by exact position-ID linkage to a source-emitted opening deal timestamp.

This contract does not change Boss19 mechanics, P4A, the frozen classifier timeline, H3 reference configuration, risk/defaults, optimization, HOLDOUT, candidate status, deployment, or trading authority.

## Frozen parent identity

- H3 parent head: `47c7732048406277096c1ccc31734b4122ae7285`.
- Accepted H3 package SHA-256: `3d62d6d358831dc3897357d3d2008e9c0f1c9211716844112f8af96f79c7eeb2`.
- Parent expert: `EALabTpl\Probe_19_AdaptiveTrendGrid`.
- Fixed set: `ea_template/sets/probe/Boss_19_AdaptiveTrendGrid_V0_STOP_VALIDATION_CENTER.set`.
- Set SHA-256: `671ced2169bdda6812cf1ceb70bbc5a53bcb0985563dcbce92cc64e04f81f0d2`.
- Model `1`, deposit `10000`, leverage `1:100`.
- Universe/windows remain the accepted 36-cell H3 matrix; `2026H1` HOLDOUT is excluded.

## Instrumentation child

Create sibling expert `ea_template/Probe_19_AdaptiveTrendGrid_P4BUnitExport.mq5`. It must compile the same `LAB_ENTRY_19` / `LabCore.mqh` strategy code and add only a diagnostic `OnTradeTransaction` callback.

The callback may write source data but must not branch into, mutate, delay, or replace any entry/exit/risk decision. The original parent source remains untouched.

Each source row must carry at least:
`schema_version, symbol, timeframe, magic, account_margin_mode, deal_id, position_id, order_id, deal_entry, deal_type, deal_time_msc, volume, price, commission, swap, profit`.

Only MT5 `HistoryDealGet*` properties from the emitted deal are admissible. `position_id` must be `DEAL_POSITION_ID`; it must not be reconstructed from order sequence, time, volume, comment, P&L, or ticket proximity.

## Deterministic unit-link rule

For one run, a realized `OUT`/`OUT_BY` deal is eligible only when:
1. `deal_id` is unique and nonzero;
2. `position_id` is nonzero;
3. exactly one source `IN` deal exists for that same `position_id`;
4. no `INOUT`/unsupported reversal shape exists for the position; and
5. opening time comes directly from that exact `IN` row.

Multiple opening candidates, missing opening rows, missing IDs, duplicate deals, or unsupported reversal shapes are fail-closed. They are not repaired by FIFO, nearest-time, volume, order, comment, or P&L matching.

## Pilot gate before any broad rerun

Pilot exactly one preregistered cell: `H3-C03-MAIN`, `XAUUSD/H4`, MAIN `2023.01.01..2025.12.31`, Model 1, on the same `D:\Meta 5` install and the same fixed set.

The broad 36-cell rerun remains locked until all pilot checks pass:
1. diagnostic child compiles `0 errors, 0 warnings`;
2. child report is full-window eligible and mechanically valid;
3. child report trade count and comparable tester metrics reproduce the accepted H3-C03-MAIN parent evidence; instrumentation is not allowed to create a better or different strategy result;
4. the source CSV contains the expected schema and nonzero MT5 position IDs for eligible trading deals;
5. realized `OUT/OUT_BY` count reconciles to the child tester trade count; and
6. the deterministic builder produces one realized DEAL unit per eligible close using exact source ID linkage only.

Any parity mismatch, source-ID ambiguity, missing source file, reconciliation failure, or unsupported account-history shape returns `BLOCKED`; do not widen the pilot or modify strategy behavior to make it pass.

## Broad rerun and evidence boundary

If and only if the pilot passes, execute the same instrumentation child over the frozen 36-cell H3 matrix on `D:\Meta 5`, serially, Model 1, using the same fixed set and the same MAIN/BWD windows. No 2026H1 run and no optimization is permitted.

Each run must be bound to its run ID by an external runner that deletes the expected Common-Files export before launch, checks freshness after launch, copies the exact CSV into a run-scoped evidence location, hashes it, and records the diagnostic child EX5/source identity.

The source-bound package must preserve per-run raw CSV hashes and deterministic unit-detail output. Aggregate counts must reconcile to each child report independently; do not force equality to the historical total `1549` if the diagnostic rerun itself does not reproduce the accepted H3 evidence.

A completed source package is still only a P4B prerequisite. Before any regime join, freeze and independently review the package manifest and exact diagnostic source/build identity. The existing classifier timeline remains unchanged and must be referenced by its already accepted hash.

## Explicit exclusions

- no inferred basket ID; `BASKET = UNAVAILABLE_NO_SOURCE_BASKET_ID` unless MT5/source strategy later emits one prospectively;
- no P4A edits or classifier rebuild;
- no performance interpretation during export/parity work;
- no HOLDOUT, optimization, risk/default, strategy redesign, candidate, DEMO/LIVE, deployment, or trading authority;
- no Grade/KINT/sample-policy decision.

Acceptance for this contract is either `SOURCE_BOUND_UNIT_EVIDENCE_READY_FOR_REVIEW` or a named fail-closed blocker. It is never a Boss19 strategy verdict.

## Timestamp normalization

The raw diagnostic source must preserve MT5 tester/server time (`deal_time_server`) and `DEAL_TIME_MSC`. P4B must not relabel tester server time as UTC.

UTC normalization reuses the already accepted local-OHLC rule in `tools/P4BMarketDataExporter/normalize_ohlc.py`: ThinkMarkets server time is GMT+2 standard and GMT+3 between the US DST transition dates. The transition server dates themselves remain ambiguous and are quarantined as `UNKNOWN_DST_TRANSITION`; no inferred switch instant is permitted.

The unit builder records both raw server time and normalized `entry_utc`/`exit_utc`. A realized position whose required opening or closing timestamp falls on an ambiguous transition date remains source-linked but is not eligible for a regime label; it must surface as unknown-time coverage rather than being shifted by guesswork.

### First-version cost/reconciliation shape

The first unit builder accepts only one source `IN` and one realized `OUT/OUT_BY` per `position_id`. Multiple entry fills or multiple realized exits for one position are `BLOCKED(UNSUPPORTED_MULTI_DEAL_POSITION)` rather than allocating opening commission or P&L across partial fills by an invented rule. Positions with no realized exit are reported as open/unrealized and excluded from realized-unit aggregates.
