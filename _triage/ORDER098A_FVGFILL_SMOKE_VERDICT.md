# ORDER-098-A — FVG-fill naked entry smoke verdict (Opus lead, 2026-07-14)

Built `ea_projects/(EXP)_FVGFill_Naked/FVGFill_Naked.mq5` per taskboard spec (EX009/EX196 algo):
bullish FVG = Low[shift2] > High[shift4] (3-bar gap), entry when Close[shift1] retraces back inside
the gap + confirm-candle body bigger than previous (engulfing-size proxy per spec). Mirror for SELL.
Flat-lot: single order, fixed 0.01, SL 20 / TP 15 "pip" (EX009 spec).

**Self-review caught 1 BLOCKER before compile:** FX pip formula applied to XAUUSD would have given
SL $0.20 / TP $0.15 — smaller than typical gold spread (pure execution artifact). Fixed: added
`IsForexSymbol()` split + configurable `_02_NonFxPipMult` (default 10x point = $0.10/pip gold
convention) so non-FX symbols get sane, broker-plausible distances. Re-reviewed clean: bar-open
gate ✓, tester-gate (`_06_AllowLive || MQL_TESTER`) ✓, magic-scoped position check ✓, `OnTester`
Sharpe-floor ✓. Compiled 0 errors (ex5 40276 bytes).

## Acceptance result (Model 1, 2023.01-2026.01)
`_mt5_auto/order098a_fvgfill_results.csv`

| symbol | tf | PF | Trades | DDpct | Win% |
|---|---|---|---|---|---|
| EURUSD | H1 | 1.13 | 5 | 0.05 | 60.00 |
| EURUSD | H4 | 0.75 | 2 | 0.02 | 50.00 |
| XAUUSD | H1 | 0.00 | 0 | 0.00 | 0.00 |
| XAUUSD | H4 | 0.00 | 0 | 0.00 | 0.00 |

## VERDICT (lead) — INCONCLUSIVE, not REJECT
**Trade counts are too thin to judge (max 5) — this is a sampling failure, not an edge failure.**
XAUUSD's 0 trades is not an init/code crash (the same binary fires fine on EURUSD) — it's the
entry logic being too narrow to detect meaningfully within 3 years on either symbol.

**Root cause (documented in the code's own header comment, known going in):** the detector checks
only a fixed 4-bar snapshot on each newly-closed bar (shift1..4) with NO persistent gap-state —
a gap that isn't retested within that exact window is never seen again. Real FVG fills in fxDreema-
style ICT strategies often happen many bars after the gap forms; this MVP scope structurally
under-samples the very pattern it's testing.

**Per VERDICT GATE:** cannot call this dead (0 lever swept in the sense that matters here — the
detection window itself was never varied) and cannot call it validated (n=5 is statistically
empty). This is neither PASS nor REJECT — it's an under-powered probe.

**Next step if pursued (build-on, cheap, same EA):** add persistent gap-state tracking — store
each detected gap's zone + formation bar, check every subsequent bar (up to a max-age cap, e.g.
50 bars) for a retrace-fill instead of only the bar immediately following. Re-run the same 4-cell
acceptance matrix. This is a detection-scope fix, not an entry-logic redesign — the FVG geometry
and engulfing-confirm rule are unchanged, only how many bars we're willing to wait for the retest.

**Not touched (per order — no grid/MM until flat-lot proves PF>1 on a real sample):** MM-parts
integration deferred regardless of this result.
