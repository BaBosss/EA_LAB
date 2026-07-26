# Lane A — JumStoch Trend-block → Boss V2 (entry 18) — VERDICT (2026-07-18)

## Result = DEAD-OPTIMIZED (port/cell level — NOT a kill of standalone JUMSTOCH)

The JUMSTOCH "Trend" block (LWMA-displacement + Stoch filter) ported as a chassis SEED signal has **no
standalone edge on the Boss V2 DCA chassis.** 28 Model-4 runs, uniformly sub-1.0 PF both-window.

### Evidence (Model-4 real ticks, EURUSD right-home)
| round | config | cells | PF range | verdict |
|---|---|---|---|---|
| base-gate | fixed-TP=30 exit, 2 DirMode × 2 sym(EUR/AUD) × 2 dir × 2 win = 16 | all | **0.58–0.71** | no pulse |
| last-optimize (exit lever) | faithful basket ATR-TP exit (Boss14 pattern), EURUSD, 4 cells × 2 win = 8 | all | **0.82–0.94** | lifted, still <1.0 |
| TF round | H4, 2 best cells × 2 win = 4 | all | **0.85–0.92** | same, still <1.0 |

### VERDICT GATE
1. **Levers swept (≥3 × ≥2 TF ✓):** DirMode(faithful/reversion) · direction(BUY/SELL) · symbol(EUR/AUD) ·
   exit-mode(fixed-TP / basket-ATR-TP) · TF(H1/H4) · window(MAIN/BWD). Held: spacing(21pip), SL(253), entry-thresh.
2. **Surface:** uniform sub-1 plateau (not spike/hole) — a robust "no edge", not an unlucky cell.
3. **Both regimes:** MAIN + BWD both <1.0 everywhere.
4. **REJECT class:** PARAMETRIC (trades, flat-lot, has source) → swept before reject ✓. **LAST-OPTIMIZE round
   done** = the exit-lever swap (diagnosis-indicated), which lifted 0.65→0.94 but did not cross 1.0.
5. Not structural (flat-lot, capped, SL present).

### Key findings (the durable value)
- **The JUMSTOCH edge is NOT in the Trend seed.** The standalone's PF 1.18 (EURUSD H1) came from the combined
  4-basket structure (BuyTrend+SellTrend+BuyCounter+SellCounter) + BEP-shift-to-basket-avg + trailing engine
  running together — NOT the LWMA+Stoch seed in isolation. Porting only the Trend seed onto a generic DCA
  chassis strips the actual edge source. → matches the standing lesson: *confirm/MM layers multiply an existing
  edge, they don't manufacture one; here the "edge" was the basket-engine composition, not the signal.*
- **Direction A/B resolved empirically = moot.** faithful momentum-join and reversion mappings score ~equal
  (both 0.85–0.94), both losing → the LWMA+Stoch seed is directionless on EURUSD; the brief-vs-source direction
  discrepancy did not matter because neither reading has edge as a chassis seed.
- **Exit-lever finding (reusable):** on a flat-lot DCA grid, a crude fixed-TP(30)/big-SL(253) exit bleeds
  (PF 0.65); swapping to a basket-level ATR-TP (SuppressLegTP + BasketTP_ATRmult, Boss14 pattern) lifts it to
  0.94 — a ~0.30 PF swing from exit geometry alone. Basket-close beats per-leg-TP for DCA. (Confirms Boss14 exit design.)

### Standalone JUMSTOCH = untouched
This kills only the **chassis-seed port**. The standalone `(EXP)_JUMSTOCH_MT5` (4-basket, ORDER-091C-D1) remains
its own artifact — not deployed, not re-judged here.

### Boss_18 code = KEPT (built + caged green), marked NOT-DEPLOY.
The entry module compiles clean and is cage-verified; left in the chassis as a documented dead-seed (like
Boss_15 ST03's "not deploy-approved" banner) rather than deleted — cheap to keep, and the exit-lever finding
is reusable.
