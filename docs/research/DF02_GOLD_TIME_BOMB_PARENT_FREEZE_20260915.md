# DF02 Gold Robot Scalping Time Bomb — Parent Freeze — 2026-09-15

Status: `OWNER-DIRECTED / SOURCE_BOUND / PARENT_FROZEN / NO_MT5 / NO_PERFORMANCE_CLAIM`

Canonical base: `0287a3d1b466d9183e23f6687126479681cb74e5`.
Draft family: `DF02 — Gold Robot Scalping Time Bomb`.
Prospective implementation identity: `FamilyID=B20`, build token `LAB_ENTRY_20`.
This does not mint an `E020` Strategy Catalog record or any Candidate/Grade/deployment identity.

## Frozen parent

- file: `(Boss) Gold Robot Scalping Time Bomb rev1.mq5`
- SHA256: `795c446093bc0ef888bad84f162646f94d303831e8becf10955d7e016ed1f93c`
- recovered evidence: `D:\EA_LAB_CONTROL\evidence\strategy-source-recovery-20260915-r1`
- exact freeze receipt: `D:\EA_LAB_CONTROL\evidence\df02-parent-freeze-20260915\DF02_PARENT_FREEZE_RECEIPT.json`
- receipt result: PASS; 43/43 block topology captured and exact source hash matched.

Alternate `[Boss] Gold Robot Scalping Time Bomb*.mq5` SHA256 `a4290bfe419d0c3660fd2e4dc3ed0a40448ae4d677eccb0206279c44a3623c64` remains alternate lineage only. Its parameters are not merged into the frozen parent.

## Material parent defaults

`Pips_to_raise=10`, `Pips_to_fall=10`, `Time_to_wait=10s`, `Grid_Distance=60`, `Trailing_Stop=30`, `Trailing_step=1.0`, `Freeze_lot=0.0001`, `MagicStart=7292`.

The alternate source materially differs: rise/fall 20, trailing 50/5, and `Lots=0.01`. Same 43-block topology does not make those configurations interchangeable.

## Frozen causal behavior

1. Flat BUY side: if no BUY position exists, TimeBombUp watches Ask. It triggers when Ask rises by at least `Pips_to_raise` within at most `Time_to_wait` seconds.
2. Flat SELL side mirrors this on Bid with `Pips_to_fall`.
3. A TimeBomb trigger passes a current-timeframe once-per-bar gate before the order helper.
4. The flat-position gate uses `PositionsTotal()` semantics. Pending orders are not counted as open positions for this gate.
5. Initial helper prices are Ask + `Grid_Distance_x2` for BUY and Bid - `Grid_Distance_x2` for SELL, with no initial SL or TP and `ExpMode=today`.
6. `Grid_Distance_x2` initializes to zero and is written only by four add branches as `2 * Grid_Distance`; it is not reset merely because the basket becomes flat.
7. Consequently, after an EA restart the first zero-offset `BuyLater`/`SellLater` call becomes a market order. After an add branch has written the state, later flat cycles can place stop orders at the retained offset.
8. BUY and SELL each have two same-side add paths, covering favorable and adverse current-close versus newest-position-open relationships. Both use the `2 * Grid_Distance` nearby-position exclusion before a market add.
9. All source order blocks use `block-freemargin` sizing. `Freeze_lot=0.0001` is therefore a percentage-like input to the fxDreema free-margin formula, not a literal fixed lot.
10. The formula is `(value / 100) * AccountFreeMargin() / margin_required_for_1_lot`, followed by broker lot-step/min/max alignment.
11. Group trailing runs when at least one position exists across the configured group/symbol filter, uses `TrailWhat=1`, fixed stop distance `Trailing_Stop`, fixed step `Trailing_step`, no trailing-start delay, and resets its group stop when the trade set changes.
12. `TrailingTPmode=none`; the source therefore trails SL only. The internal `ftTP=40` function input is inactive in this configuration. Existing TP is preserved when SL is modified; source order blocks begin with TP absent.
13. The empty ModifyVariables blocks after pending-order creation are non-causal in this revision.

## Source-bound interpretation

DF02 is not an entry-only TimeBomb signal. The causal family includes trigger state, restart-sensitive retained grid-distance state, position-only flat gating, pending/market dual behavior, free-margin sizing, both-direction same-side adds, and group trailing ownership.

The implementation path is therefore `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER`. Shared chassis stack/recovery/exit paths must not silently duplicate or replace these source-owned mechanics.

Home symbol and Home timeframe remain unresolved by source: the code uses `CurrentSymbol()` and `CurrentTimeframe()`. The product name contains “Gold”, but a name is not sufficient evidence to freeze XAUUSD or a timeframe.

## Authority boundary

This owner-directed continuation freezes the exact parent revision and reserves prospective `B20 / LAB_ENTRY_20` because no collision exists at this canonical base. It does not freeze Home/TF, authorize MT5 execution, change risk defaults, spend HOLDOUT, establish performance, create an `E020` catalog entry, or authorize DEMO/LIVE/trading.
