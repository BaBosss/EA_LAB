# Demo EAs — Plateau Robustness Check (2026-07-08)

User asked "optimize เพิ่มรึยัง" — the 3 MT4 demo EAs passed the funnel at DEFAULT/stock config only
(they're compiled, no source). Rather than a PF-chase (which would change the validated config + risk
overfitting a black box), ran a **plateau-robustness check**: swept the single most PF-relevant input
around its default, on BOTH regimes (BWD 2020-22 + forward), to confirm the default is a stable plateau
(neighbours also OK) and not a lucky spike. Raw: `_mt5_auto/DEMO3_PLATEAU.csv`.

| EA | swept input (default) | BWD 2020-22 (lo/def/hi) | forward (lo/def/hi) | verdict |
|---|---|---|---|---|
| UnNomGuai @ EURUSD | pairglobalprofit (8) | 1.84 / 1.89 / 1.85, DD~18.8 | 2.20 / 2.06 / 2.15, DD~4.7 | flat plateau ✅ |
| RSI-from-pips @ EURUSD | TP_pips (15) | 2.38 / 2.32 / 2.50, DD 6-9 | 3.07 / 2.59 / 2.76, DD~2 | plateau ✅ (TP20 marginally better) |
| swb-flat @ AUDCAD | tp_in_money (5) | 2.65 / 2.51 / 2.42, DD 8-11 | 4.95 / 3.42 / 3.39, DD 1-6 | plateau ✅ |

**Conclusion:** all three defaults sit on stable plateaus — no fragile spike, no losing neighbour.
**Deploy the DEFAULT config** (the one that passed the full funnel); the plateau just adds confidence
it wasn't a lucky point. Do NOT change the config for demo — the marginal improvements (RSI TP=20,
swb tp=3) are inside the plateau and not worth invalidating the validation. Re-optimize only if the
6-month re-opt cadence or live behaviour warrants it.
