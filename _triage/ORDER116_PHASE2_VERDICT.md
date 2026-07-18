# ORDER-116 Phase 2 — carry split recipe to other breakout symbols — Claude 2026-07-18

Locked recipe (buy-only Donchian Bars40/TP5 + split 0.02mkt/0.01pend, offset −0.15, expiry 5) run on
US30 / NAS100 / XAGUSD / GBPUSD, market vs split, both-window Model-4 (D:\Meta 5). Raw `_mt5_auto/O116_P2.csv`.

## Result

| symbol | market REC/BWD | split REC/BWD | read |
|---|---|---|---|
| **US30** | **1.46 / 1.40** | 1.54 / 1.38 | 🟢 both-window edge (market already robust, no weak window); split +trend, ~neutral chop |
| NAS100 | 0 trades | 0 trades | no data on this broker — skip |
| XAGUSD | 1.01 / 0.56 | 0.82 / 0.61 | ❌ no edge (BWD 0.56); split makes it WORSE + DD 17% (more trades into a no-edge signal) |
| GBPUSD | 0.81 / 0.74 | 0.91 / 0.73 | ❌ no-edge base (<1 both); split lifts REC 0.81→0.91 but can't cross 1.0 |

## Findings
1. **US30 = new diversifier leg.** Buy-only breakout is **both-window ≥1.40 on market-only** (1.46/1.40) —
   already regime-robust without split (indices trend up like gold, so buy-only long-breakout travels).
   Split adds trend (1.46→1.54) but marginally costs chop (1.40→1.38) → for US30 split is optional; the
   leg stands on market-only. Thin (26–34 trades/window) + tiny DD (0.16–0.37% at 0.01 lot) → PF is the
   signal; size at validation.
2. **Doctrine reconfirmed (split = refinement, not resurrector):** split only helps where the base has
   both-window edge (US30). On no-edge bases (XAG BWD 0.56, GBP <1) split can't create edge and can hurt
   (XAG DD 17%). Same law as pending (D1g) — **check the base breakout edge FIRST, then decide split.**
3. XAG/GBP buy-only breakout = dead for this lever. NAS100 = data-blocked.

## DECISION → Phase 2b (validate US30)
US30 buy-only Donchian breakout = **candidate new leg → full funnel before any demo:**
plateau (BreakoutBars/TP sensitivity) · holdout (a window not used to select) · **corr vs existing XAU
BRK + GBP London legs** (deciding gate — expect low, index vs metal/FX) · MC on continuous run ·
decide split-vs-market for US30 (market-only already robust; only add split if it lifts a weak window).
Carry XAG/GBP/NAS = closed for split-breakout.
