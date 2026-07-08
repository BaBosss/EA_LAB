# RSI-MR GridLog rev01 — Validation Results (2026-07-08)

Chain `EA_RSI_MR_GRIDLOG_20260707_01`. Built from the reverse-engineered principle of
"RSI from pips_EA" + user design ideas, then validated **from scratch** (not trusting the
survivor's numbers). Thorough sweep per user direction 2026-07-08 ("ทำให้ครบ").

## Lot-law sweep — BWD 2020-22 EURUSD (wide SL 25×ATR/600pip), the discriminating window
| lot law | PF | net | eqDD% | trades |
|---|---|---|---|---|
| FIXED | 0.78 | -588 | 12.2 | 393 |
| LINEAR +0.01 | 1.19 | +1,021 | 30.5 | 887 |
| **LINEAR +0.02** | **2.63** | +5,674 | 17.6 | 1250 |
| LINEAR +0.03 | 2.56 | +6,639 | 18.8 | 1372 |
| MART 1.3 | 1.00 | -5 | 20.2 | 671 |
| MART 1.5 | 1.18 | +1,080 | 35.1 | 859 |
| LOG 2 | 1.13 | +464 | 24.1 | 536 |
| **LOG 5** | **2.96** | +7,519 | 18.8 | 1270 |
| LOG 10 | 1.03 | +322 | 60.9 | 1125 |
| LOG 20 | 0.54 | -8,332 | 95.3 | 1080 |

→ Corrected an earlier WRONG call: rev01 default (LOG 1.3, near-flat) gave 0.78 here and I
prematurely called the EA "regime-dead". Proper lot laws (LOG 5 / LINEAR +0.02) hit PF 2.6-3.0
at DD ~18% — matching the original's 2020-22 profile. **The edge IS there in the trend years.**

## Cross-regime confirm — top lot laws, EURUSD, FWD 2025-26
| config | 2020-22 | 2025-26 |
|---|---|---|
| LOG 1.3 | 0.78 | **1.43** |
| LOG 5 | **2.96** | 0.88 (DD 37%) |
| LINEAR +0.02 | **2.63** | 0.82 (DD 37%) |
| LINEAR +0.03 | **2.56** | 0.91 (DD 37%) |

→ **INVERSE relationship:** the deep-grid recovery that wins 2020-22 loses in 2025-26 (and DD
jumps to 37%). The flat grid that survives 2025-26 can't recover 2020-22 trends. No single
lot-law wins both regimes on EURUSD.

## Symbol sweep — LOG 5 config, both windows
| symbol | BWD 2020-22 | FWD 2025-26 |
|---|---|---|
| EURUSD | 2.96 (DD19) | 0.88 (DD37) |
| AUDUSD | 1.96 (DD34) | 0.78 (DD30) |
| GBPUSD | 1.22 (DD47) | 3.14 (DD34) |
| USDJPY | 0.49 (DD95 💀) | 1.63 (DD15) |

→ Same inverse pattern, per-symbol: each pair wins ONE regime, loses the other, and which
regime flips by symbol (EUR/AUD favour the trend years; GBP/JPY favour the recent years).
No symbol×config gives robust both-regime profit; DD breaches the 40% gate in most cells.

## Verdict (Claude, 2026-07-08)
**rev01 is mechanically sound but has NO durable cross-regime edge** on any symbol×lot-law
tested (22 backtests). The strategy is strongly profitable *in-regime* (PF 2-3) but the optimal
grid depth is regime-specific and the two conflict — a structural property of "mean-reversion
averaging + real SL", not a tuning miss. A full IS/OOS optimizer on 2020-22 would select a
deep-grid config (great IS) that the 2025-26 results predict fails OOS = textbook overfit.

**Why it differs from the compiled original** (which passed BWD 2020-22 AND forward at PF ~2.3):
the original ran NO stop loss + fixed 30-pip spacing + per-position 15-pip virtual TP. Our
real-SL + ATR-spacing + basket-$ exit redesign — safer — changed the recovery dynamics enough
that the both-regime edge didn't survive. The safety we added is exactly what the original
lacked, and it costs the cross-regime robustness.

**Genuine sub-finding worth keeping:** deep-grid RSI-MR is a strong *in-regime* harvester, and
the regime that favours it flips by symbol — a multi-symbol basket (EUR+GBP, or AUD+JPY) could
in principle diversify the regime risk, but each leg's DD (34-47%) is too high to combine safely
without a lower base lot + tighter cap. Parked as a research thread, not a deploy candidate.
