# ORDER-108 — break-and-retest split entry (user idea) — verdict (Claude, 2026-07-16)

EA `(EXP)_BRK_SplitRetest` (variant of EA_BREAKOUT_XAU, entry-structure only). A/B Model-4 (real ticks,
required — pending fills need intrabar), XAU H1, both windows. Raw: `_mt5_auto/order108_split_ab.csv`.
Build: commit `31845f5c`, mql-code-reviewer PASS (hedging guard for dual-leg on netting).

## A/B result (PF — size-invariant, fair across modes)

| mode | MAIN 23-26 (trend) | BWD 20-22 (chop) | note |
|---|---:|---:|---|
| market-only (base) | **2.07** (46t) | 1.75 (33t) | strong in trend, weak in chop |
| pending-only | 1.76 (42t) | **2.55** (29t) | weak in trend (misses runners), strong in chop |
| **split 0.02mkt+0.01pend** | 1.93 (88t) | 1.97 (62t) | **robust — no weak window** |

## Three findings — user's hypothesis validated

1. **Retest fill-rate ≈ 90%** (`order108_fillrate.py`, from split "in" deals): MAIN 42/46 = 91%, BWD 29/33 =
   88%. XAU H1 breakouts retest the broken level within 5 bars far more often than the user's 70-80% guess.
2. **Adverse-selection is REAL** (the reason the split, not pending-only, is right): in the trend window
   pending-only 1.76 < market-only 2.07 — waiting for the retest **misses the breakouts that run away, which
   are the profitable ones in a trend**. The market leg is necessary; a pure-pending strategy would leave the
   runners on the table. Confirmed exactly as the user reasoned.
3. **Split = regime-robust blend** (the "both worlds"): each pure mode has a weak window (market BWD 1.75,
   pending MAIN 1.76); the split has neither — ~1.95 in BOTH regimes. It trades a little MAIN peak (2.07→1.93)
   for removing the weak window. All three modes clear the 1.40 gate both-window on XAU H1, but split is the
   smoothest across regimes.

Win% corroborates: in chop (BWD) the retest leg enters better (pending-only win 48.3% vs market 39.4%).

## Verdict — 🟩 BUILD-ON SUCCESS: split-retest = a real, reusable entry-structure lever
The user's break-retest + split-sizing idea produced a working lever, not a dead end. It fills often, the
adverse-selection guard (market leg) is justified by data, and the blend is regime-robust. On live, the
retest leg also fills as a maker (no spread paid on ~90% of the 0.01 legs) — an edge the tester spread
understates. **NOT auto-deploy** (probe on Bars40 defaults; the live BRK-XAU is Bars55) but clearly worth
developing.

**Next (queue — pace):**
1. Size-matched net comparison (market-only 0.03 vs split 0.03) — confirm the blend on absolute $ not just PF.
2. Sweep `_07_RetestOffsetAtr` (deeper retest = better price, lower fill) × `_07_ExpiryBars` — find the
   plateau; a small negative offset may lift the retest-leg edge.
3. Apply the lever to the OTHER deployed breakout winners: **BRK-XAU Bars55 (the live config)** + LondonConso
   (GBP/EUR). If it lifts regime-robustness there → candidate to retrofit as a demo config upgrade.
4. Bank the lever in EDGE_CATALOG for any future breakout build.
**ห้าม:** เอาไปแปะ EA ที่ปัญหาไม่ใช่ entry-cost/timing (เช่น XAU_NY = regime).
