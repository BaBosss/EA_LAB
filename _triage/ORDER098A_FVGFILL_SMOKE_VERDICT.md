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

## Acceptance result — rev01 (Model 1, 2023.01-2026.01, one-shot 4-bar detection)
`_mt5_auto/order098a_fvgfill_results.csv` (superseded, see rev02 below)

| symbol | tf | PF | Trades | DDpct | Win% |
|---|---|---|---|---|---|
| EURUSD | H1 | 1.13 | 5 | 0.05 | 60.00 |
| EURUSD | H4 | 0.75 | 2 | 0.02 | 50.00 |
| XAUUSD | H1 | 0.00 | 0 | 0.00 | 0.00 |
| XAUUSD | H4 | 0.00 | 0 | 0.00 | 0.00 |

**rev01 finding:** trade counts too thin to judge (max 5) — sampling failure, not edge failure.
Root cause: the detector checked only a fixed 4-bar snapshot per new bar with no persistent
gap-state — a gap not retested within that exact window was never seen again.

## Fix (rev02) — persistent gap-state tracking
Replaced the one-shot 4-bar check with a ring buffer (`ZONE_CAP=20`) that remembers every
detected gap's zone + formation bar and checks it for a retrace-fill on every subsequent bar
(aged out after `_01_MaxAgeBars=50`, default). FVG geometry and engulfing-confirm rule unchanged
— only the detection window widened. Compiled 0/0 (terminal64 `/compile` hung twice on this
rebuild — gotcha: use `MetaEditor64.exe /compile:<path> /log:<path>` directly instead, it
completed in 456ms both times vs terminal64 opening an idle GUI and never returning).

## Acceptance result — rev02 (same 4 cells, Model 1, 2023.01-2026.01)
| symbol | tf | PF | Trades | DDpct | Win% |
|---|---|---|---|---|---|
| EURUSD | H1 | 0.97 | 818 | 0.77 | 56.72 |
| EURUSD | H4 | 0.74 | 263 | 0.89 | 49.81 |
| XAUUSD | H1 | 0.83 | 942 | 1.73 | 52.55 |
| XAUUSD | H4 | 0.83 | 283 | 0.48 | 52.65 |

## VERDICT (lead) — PARAMETRIC, no edge at this RR (NOT a kill yet)
**Now well-powered (263-942 trades/cell) and PF<1.0 in all 4 cells.** The pattern is informative,
not noise: fixed SL20/TP15 = 0.75 RR needs win% ≥ 57.1% to break even (20/(20+15)). Win rates
land at 49.8-56.7% — EURUSD H1 (56.72%) sits right at the breakeven line (PF 0.97, essentially
flat before costs); the other three cells are further below it. The FVG-retrace geometry itself
fires often enough (263-942 signals over 3yr) — the entry is not rare, it's just not accurate
enough to clear this RR's breakeven bar.

**Per VERDICT GATE: this is PARAMETRIC not STRUCTURAL — only 1 window tested (no BWD 2020-22 yet)
and 0 levers swept (RR/TP never varied). Cannot reject yet.** The doctrine-consistent next step
(if pursued) is NOT more code — it's the standard funnel: (1) BWD window on the same 4 cells,
(2) vary RR (e.g. wider TP relative to SL, since win% is close to breakeven and a slightly better
RR could flip several cells over 1.0) before any kill call. Given win% is this close to the line,
a modest RR change plausibly rescues it — this is a "tune the exit, not redesign the entry" case,
distinct from ORDER-097 HexaGrid where every lever failed uniformly.

**Not touched (per order — no grid/MM until flat-lot clears the bar):** MM-parts integration
deferred regardless of this result.

---

## FINAL VERDICT (lead, 2026-07-16) — REJECT: naked FVG-fill entry has no edge at any exit geometry

Follow-up funnel completed (22 runs total, `_mt5_auto/order098a_bwd_rr.csv`, Model 1, all well-powered):
- **BWD 2020-22 (default RR 0.75):** all 4 cells PF 0.79-0.88 — worse than MAIN, both regimes negative.
- **RR sweep MAIN (SL20, TP ∈ {15,20,25,30,40,60}):** PF rose monotonically with wider TP on XAU
  (0.83→0.97 at H4) then **reversed at TP40/60 (0.90/0.92)** — the curve peaks at 0.97-0.98 and never
  crosses 1.0. EURUSD H1 flat at 0.93-0.98 throughout. Max PF observed anywhere = **0.98**.
- Interpretation: the TP-widening "improvement" was cost-dilution toward random-entry behavior, not
  edge emergence. Win% tracks the RR breakeven line from below at every setting — the FVG-retrace +
  engulfing-confirm entry carries no informational advantage on these instruments/TFs.

**Scope per VERDICT GATE:** closes naked-FVG-fill-entry (EX009 geometry) on EURUSD/XAUUSD × H1/H4 —
swept: exit-RR (6 values) × symbol (2) × TF (2) × window (both regimes). NOT a universal concept kill:
FVG-as-confluence-filter for other entries remains untested and stays open in EDGE_CATALOG. Never
produced PF>1 in any of 26 total cells (incl. rev02 smoke) → not build-on material per doctrine
(build-on requires PF>1 at least once).
