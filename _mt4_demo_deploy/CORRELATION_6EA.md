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

## Combined-portfolio simulation (2026-07-08, `scripts/portfolio_sim.py`, equal profit-weight)
| | maxDD (% of gain) | positive months |
|---|---|---|
| RSI_MR solo | 12.0% | 78% |
| Zeus solo | 10.4% | 80% |
| BRK solo | 8.2% | 53% |
| **COMBINED 6-EA** | **1.2%** | **91%** |
| gold pair (Zeus+BRK) | 3.8% | 64% |

- Running all 6 together: combined DD (1.2% of gain) is FAR below any single EA (8-12%) — the
  diversification is real; 91% positive months. Confirms the corr matrix.
- The gold pair (Zeus+BRK, shared XAUUSD) combined DD = 3.8% — safe to run on one account; the 0.42
  correlation does NOT create a dangerous gold stack.
- **HONEST caveat:** the 3 MT4 grid EAs show ~0% realized DD / 95-100% positive months — the signature
  of no-SL grids whose tail (a disconnect / deep-grid blowup) isn't in the tested window. So the 1.2%
  combined is backtest-realized, NOT true tail. This is exactly why the whole cohort is demo-only with
  hard kill-switches. Trust the diversification shape, not the absolute smoothness.
