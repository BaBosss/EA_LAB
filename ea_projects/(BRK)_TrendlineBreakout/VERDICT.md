# (BRK)_TrendlineBreakout_rev01 — Verdict (2026-07-08)

Built per user request 2026-07-08: a **diagonal trendline / triangle breakout** (converging pivot
lines), NOT horizontal S/R. Fits upper line through last 2 pivot highs + lower through last 2 pivot
lows, projects to the current bar, trades a close beyond + ATR buffer, with a convergence (triangle)
filter, EMA200 trend gate, real ATR SL/TP, single position (L1). Compiled 0/0, review-clean (fixed a
slope-sign bug in ProjectLine before testing).

## Results (XAUUSD H1, best config = converge=true, TpAtrMult=6)
| test | value |
|---|---|
| BWD 2020-22 | PF 1.20 |
| Holdout 2023-24 | PF 1.21 |
| FWD 2025-26 | PF 1.04 |
| Full-span | PF 1.08, DD 3.1%, 396 trades (~60/yr — healthy frequency) |
| MC ruin | 0% |
| **MC PF-5th (bootstrap)** | **0.867 — below 1.0** |
| MC DD-95th | 7.5% |
| OOS split PF | 1.178 (degradation -14%) |

## Verdict: NOT_ROBUST (real but too-weak edge) — RESEARCH, not demo
The mechanism WORKS: it trades a healthy ~60/yr, passes all 3 independent windows (1.04-1.21), and
the **triangle-convergence filter genuinely helps** (converge=true beat converge=false in every cell
of the TP sweep — validates the user's intuition that triangle breaks carry more signal than any
trendline). BUT the edge MAGNITUDE is marginal (PF ~1.1-1.2) and **MC PF-5th 0.867 < 1** means it does
not survive bootstrap resampling stress — below the deploy bar. Unlike BRK-XAU (PF-5th 1.53) and Zeus,
this edge is too thin to demo.

Kept as a research/framework EA (source in this folder). Not added to the demo cohort (stays 6).
If revisited: sweep BufferAtrMult / PivotLeftRight / other symbols — but the gold MC (0.87) suggests
the edge is structurally weak, so treat further tuning as overfit-prone. The clean finding worth
keeping: **triangle-convergence adds signal over plain trendline breaks.**
