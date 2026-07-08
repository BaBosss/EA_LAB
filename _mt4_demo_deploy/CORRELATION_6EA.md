# 6-EA Demo Cohort — Correlation Matrix (2026-07-08)

Monthly-P&L Pearson correlation over the common window (`scripts/corr_matrix.py` on each EA's
closed-trade list). Rule: >0.60 = reduce lot (don't cut) · 0.40-0.60 = watch · <=0.40 = additive.

```
           UnNom  RSIorig  swb   RSI_MR  Zeus   BRK
UnNomGuai   1.00   0.36   0.29  -0.11  -0.62  -0.29
RSIorig     0.36   1.00   0.59   0.18  -0.24   0.26
swb         0.29   0.59   1.00  -0.12  -0.29   0.28
RSI_MR     -0.11   0.18  -0.12   1.00   0.23   0.08
Zeus       -0.62  -0.24  -0.29   0.23   1.00   0.42
BRK_XAU    -0.29   0.26   0.28   0.08   0.42   1.00
```
months/EA: UnNom 41 · RSIorig 41 · swb 42 · RSI_MR 77 · Zeus 30 · BRK 49

## Verdict: cohort is well-diversified — NO pair needs a lot cut (none > 0.60)
- **Watch:** RSIorig×swb 0.59 (both grid-style) · **Zeus×BRK 0.42 (both XAUUSD gold breakouts)**.
- **Best diversifiers:** UnNomGuai×Zeus = **-0.62** (anti-correlated); RSI_MR ~uncorrelated with all
  (a mean-reversion EA hedging the breakout/grid cohort).
- **One live caveat (not a corr-rule breach):** Zeus + BRK are BOTH on XAUUSD. Their 0.42 is only
  "watch", but their gold-specific tail risk STACKS on the same instrument — if both run on the same
  MT5 demo account, watch combined XAUUSD exposure; consider a slightly smaller lot on the gold pair,
  or accept it and let the demo reveal the combined behaviour. All other cross-instrument pairs are
  additive-to-negative = the cohort as a whole is genuinely diversified.
