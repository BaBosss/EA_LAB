# Zone-Compressed Adaptive Grid — EA Template V2 design library

Status: **DESIGN_ONLY / NON_EXECUTABLE / NO_RUNTIME_AUTHORITY**
Owner concept date: 2026-09-22
Primary card: `ZCAG-01.md`

This library adapts the owner's Adaptive Grid + Zone Recovery idea into the existing EA Template V2 without changing current grid EAs.
The key distinction is physical versus virtual stacking:

- existing `STACK_GRID_AGAINST` places real add orders as price moves against the basket;
- ZCAG tracks those grid levels virtually while flat;
- once trend, mean-reversion and structural-support gates align, ZCAG compresses the reached virtual levels into one bounded entry;
- the position exits at the next virtual grid level or is invalidated by the frozen contract.

The design is intended to reduce time-underwater and intermediate knife-catching while keeping the same or lower maximum notional than its sequential-grid comparator. It does **not** claim lower drawdown, higher Sharpe, or better performance until an approved same-lineage test demonstrates it.

## Template placement

V0 is designed as an entry-owned strategy with `STACK_SINGLE`, not as a modification of `STACK_GRID_AGAINST`.
That preserves current B11/B13/B14/B18 semantics and avoids changing shared stack behavior.

Future executable integration, if separately authorized, should use a new wrapper/identity (prospective Boss_23 / LAB_ENTRY_23) and a dedicated entry engine. Any lot aggregation seam that touches `MoneyManagement`, `Execution`, `RiskControl`, or shared core requires the normal core-code deterministic gates and exact-head GPT Scrutiny.

## V0 direction

The owner's supplied concept is explicitly a **bull-trend pullback BUY** design. V0 therefore stays long-only. A mirrored short implementation is not inferred automatically.

## Scientific comparator

The future proof must compare:

1. Sequential grid: same anchor, step, maximum notional, invalidation and exit, but real fills at each reached level.
2. Zone-compressed grid: identical virtual ladder, but no intermediate fills; one aggregated entry only after all entry gates pass.

The physical-fill policy is the intended primary treatment difference. Any other difference must be declared before the run.

## Authority ceiling

This design creates no FamilyID, LAB_ENTRY, PARAM_REGISTRY rows, `.set`, MT5 deployment, backtest, optimization, HOLDOUT use, DEMO/LIVE status, risk-default change, or trading authority.

See `../../../docs/research/ZONE_COMPRESSED_ADAPTIVE_GRID_TEMPLATE_INTEGRATION_20260922.md` for the implementation route and test contract.
