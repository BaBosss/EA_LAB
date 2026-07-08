# (BRK)_SqueezeBreakout_rev01 — Verdict (2026-07-08)

New mechanism per user request: TTM-style volatility-squeeze breakout (Bollinger contracting inside
Keltner = squeeze; fire on release + directional range break). L1 single-position, real SL, no grid.
Compiled 0/0. Distinct from the 6 cohort EAs (Donchian/ATR-channel/session/RSI-MR/grids).

## Results (XAUUSD H1, best config = KcAtrMult 2.0 / TpAtrMult 3.0)
| test | PF | trades |
|---|---|---|
| BWD 2020-22 | 1.12 | 74 |
| Holdout 2023-24 | 1.53 | 51 |
| FWD 2025-26 | 1.08 | 44 |
| Full-span | 1.17, DD 3.6% | 169 |
| MC ruin | 0% |
| **MC PF-5th (bootstrap)** | **0.837 — below 1.0** |
| MC DD-95th | 4.44% |
| OOS split PF | 1.15 (degrade 8%) |

## Verdict: NOT_ROBUST — research, not demo (same tier as the trendline breakout)
The mechanism WORKS (169 trades good sample, passes all 3 independent windows including holdout 1.53,
tiny DD, looser squeeze KcAtrMult=2.0 beat the tight default which was selection-fit). BUT the edge
magnitude is marginal (PF ~1.1-1.2) and **MC PF-5th 0.837 < 1** = doesn't survive bootstrap stress.
Below the deploy bar. Demo cohort stays 6.

## Meta-finding after 4 new builds this session
RSI-MR = ROBUST (1/4). Trendline + Squeeze both land at MC PF-5th ~0.84 = a recurring "real but
sub-robustness" floor — easy to find a weak-momentum edge, hard to push it over the bar. The STRONG
breakouts (BRK-XAU Donchian PF-5th 1.53, Zeus ATR-channel) are the exception, not the rule. Kept as
research; the squeeze-release concept is validated as a genuine (if marginal) gold-momentum edge and
could serve as a confluence FILTER for a stronger primary signal later.
