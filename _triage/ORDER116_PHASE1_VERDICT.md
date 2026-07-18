# ORDER-116 Phase 1 — split-entry retest-param sweep (XAU H1 Bars40/TP5) — Claude 2026-07-18

**Goal:** find the best "retest recipe" (RetestOffsetAtr) for the split-entry lever on the config where
ORDER-108 proved it works (Bars40/TP5 XAU H1), before carrying it to other symbols (Phase 2).
Model-4 (real ticks — pending fills tick-sensitive), both-window, on D:\Meta 5 (non-portable; Meta5b
portable can't write M4 reports — D1g lesson). Raw: `_mt5_auto/O116_P1.csv`.

Note: fresh tick data (Jul-11-vs-new-tick refresh) → absolute PF differs from ORDER-108 (market REC
2.49 here vs 2.07 there). Internal A/B stays valid — all arms on the same current data.

## Result — split lifts the weak window; plateau on the deep-retest side

| offset | REC (trend) | BWD (chop) | trades REC/BWD | DD |
|---|---:|---:|---|---|
| market-only (ref) | 2.49 | **1.75** ← weak window | 53 / 33 | ~2% |
| split −0.30 | 2.37 | 1.94 | 83 / 54 | ~4/1.6% |
| **split −0.15** | **2.40** | **1.96** | 90 / 59 | 4.1/1.6% |
| split 0.00 | 2.33 | 1.97 | 97 / 62 | 4.1/1.9% |
| split +0.15 | 2.26 | 1.67 | 62 / 36 | 4.0/1.3% |

- **Split raises the chop (BWD) window 1.75 → ~1.96** (+0.21) for a modest trend cost (2.49 → 2.33–2.40).
  Removes the market-only weak window = regime-robust. Reconfirms ORDER-108 on fresh data.
- **Plateau at offset ∈ {−0.30, −0.15, 0.00}** — all ~2.35/1.96. `+0.15` (shallower retest) degrades BWD
  to 1.67 → the edge lives on the **deeper-retest side** (small negative offset = better fill price),
  exactly the pre-registered hypothesis.
- Trade count ~doubles under split (retest leg fills a high fraction of breakouts). DD stays <4.1%.

## Pre-registered bar → PASS
Offset −0.15: REC 2.40 ≥1.80 ✓ · BWD 1.96 ≥1.80 ✓ · no weak window · DD low. **Recipe confirmed.**

## LOCKED RECIPE (carry to Phase 2)
`_07_UseSplitEntry=true · _07_MarketLot=0.02 · _07_PendingLot=0.01 · _07_RetestOffsetAtr=-0.15 ·
_07_ExpiryBars=5`. (ExpiryBars held at 5 — offset plateau is clean; a later expiry micro-sweep is
optional, not blocking.) Set: `_mt5_auto/ab_sets/order116/BRK40_split_offm0p15.set`.

## Next — Phase 2
Carry this recipe to other breakout symbols (GBPUSD/EURUSD/US30/XAG H1) both-window Model-4 → find legs
where split clears ≥1.4 both-window + corr <0.8 vs existing XAU/GBP legs = NEW regime-robust breakout
leg (the diversification payoff). Then Phase 3 retrofit demo EAs.
