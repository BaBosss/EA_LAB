# ORDER-084 rescue #2 — EA_XAU_NY (NY-session Donchian breakout) — verdict (Claude, 2026-07-16)

Rescue of a cell ORDER-084 flagged under-swept (default smoke only, PF 1.12/350t). 3 levers swept
(Bars × SL × Direction) × H1/H4 × both windows = 44 runs. Raw: `_mt5_auto/order084_xauny_sweep.csv`
(36, BuyOnly=true) + `order084_xauny_buyboth.csv` (8, BuyOnly=false probe).

## Read

**H4 = strong MAIN, fails BWD everywhere (regime-dependent):** every H4 buy-only cell MAIN 1.79-2.43,
but BWD 0.80-1.01 (best BWD = bars40/sl3.0 1.01 breakeven, its MAIN 2.03). The H4 2.0+ is a
**gold-bull-2023-26 artifact** — 2020-22 (choppier/COVID) kills it. VERDICT GATE #3 (both regimes) = fail.

**H1 bars40 buy-only = only marginal both-window survivor:** sl2.0 MAIN 1.41/BWD 1.05 · sl3.0 MAIN
1.32/BWD 1.07. Both-window >1.0 but modest (MAIN far below the 1.40 OOS deploy gate) and it's naked breakout.

**Direction lever (BuyOnly=false probe) = does NOT rescue BWD:** allowing shorts drops MAIN hard (H4
bars40/sl1.5 2.43→1.57) and BWD stays weak/worse (H4 0.86→0.69; H1 ~same). The short side loses —
the NY-breakout edge on gold is a **long-only** phenomenon; gold's 2020-22 down-legs aren't clean
NY-session breakout-shortable. So the BWD failure is genuine regime-dependence, not a missing short side.

## Verdict — REGIME-DEPENDENT long-gold momentum. NOT both-window robust. NOT dead, NOT deploy.
Unlike GBPJPY (ORDER-106, passed both-window + Model-4 clean), XAU_NY's edge is **real but regime-bound**:
a strong long-gold NY-breakout that prints in bull regimes and fails in others. 3 levers swept per
rescue-ladder → the both-window robustness genuinely isn't there under any (Bars,SL,Direction) combo.

**Disposition:**
- **PARK as regime-dependent** (not a clean revive; the retro-audit "regime" class-claim was correct here).
- **Build-on branch (the interesting part):** the H4 MAIN 2.0-2.43 edge is real *in-regime* → natural fit
  for the **ORDER-057 `Regime.mqh` trend-gate** (deploy only when gold is in an uptrend regime; block
  otherwise). This is exactly the "lever ให้ EA ที่ตายเพราะ regime" use case ORDER-057 was built for.
  Queue as a regime-gated build-on IF the regime lever gets adopted into a funnel — not a standalone deploy.
- H1 bars40 both-window marginal (~1.35/~1.06) = kept on record but sub-gate; not worth a standalone push.

**Rescue-queue tally (ORDER-084 gong ข):** #1 GBPJPY = ✅ revive (Model-4 confirmed). #2 XAU_NY =
🟡 regime-dependent (edge real but not both-window). Next in queue: ZSCORE → ICHIMOKU → KELTNER.
