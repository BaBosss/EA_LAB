# (Boss)_AdaptiveGrid_Oil

**Origin:** independent build of an "Adaptive Grid Trading System" idea from a public
Facebook post (mean-reversion grid for WTI oil). No source used — concept-only.
`chain_id: EA_ADAPTGRID_OIL_20260717_01` · Magic 990201+ · L3 (grid, FIXED lot, no hedge).

## The 6 source components → code
1. Trend filter = Linear Regression slope on EMA, normalized by ATR → `[01]`
2. Dynamic grid spacing via ATR → `[03] _03_DistAtrMult`
3. Refresh-rate delay between adds → `[03] _03_RefreshDelayBars`
4. Overlap-prevention (min distance floor) → `[03] _03_MinDistPips`
5. Volume-weighted basket exit (VWAP ± ATR×mult) → `[04]`
6. Emergency circuit breaker (equity-DD) → `[07] _07_EmergencyDdPct`

Design note: mean-reversion seeding (market entry, adds AGAINST the basket toward VWAP).
Per-order SL is OPTIONAL and OFF by default (faithful to source); circuit breaker +
max_positions + max_total_lot are the mandatory protection. Everything is an `input`.

## STATUS: PARKED-VERIFY(user) — buildable, NOT a deploy candidate  → see [VERDICT.md](VERDICT.md)
Full campaign complete (Phases 1–4, ~50 backtests). Compiles 0/0. **Verdict: no robust portable
edge** — fixed direction = drift capture, spacing×TP surface is spike/hole (no plateau), and no
config survives cross-symbol + cross-TF (config A holds WTI H1/H4 but dies on BRENT; config B holds
WTI H1 + BRENT H1 but dies WTI H4). Marketed PF 5x not reproducible (direction curve-fit). One real
reusable insight extracted: **add-gating** cuts grid counter-trend bleed (DD 40%→11-20%). Details +
evidence tables in VERDICT.md.

Latest EA = `(Boss)_AdaptiveGrid_Oil_rev03.mq5` (dynamic direction). rev01/02 kept for lineage.

### Probe results (Model 2, WTI H1, default params except direction)
| window | oil | BUY (dir=1) | SELL (dir=-1) |
|---|---|---|---|
| 2023.01–2026.01 | down | PF 0.59, −$1886, DD 31%, maxLoss −334 | PF 3.17, +$3716, DD 21%, maxLoss −55 |
| 2019.01–2022.01 | up | PF 1.10, +$440, DD 47% | PF 0.53, −$4177, DD 55% |

**Finding:** a FIXED direction just captures that window's drift and INVERTS across regimes
(classic grid trap, VERDICT GATE #3). Real edge — if any — lives in the trend filter doing
adaptive direction selection, which default `SlopeThresh=0.05` does NOT achieve (too permissive:
BUY still traded heavily and lost through the 2023–26 downtrend).

## NEXT STEP (open) — trend-filter-driven adaptive direction
Coarse sweep on BOTH windows simultaneously, run BOTH directions each gated by the filter:
- Levers (≥3): `_01_SlopeThresh` · `_01_LrLookback` · `_03_DistAtrMult` · `_04_BasketTpAtrMult`
- Goal: each direction trades only its favorable regime → net-positive across BOTH windows.
- Then: holdout window never used in selection + Monte Carlo before any verdict.
- Then: `_06_UsePerOrderSl=true` with-SL variant (Zeus lesson: no-SL grid hit ~102% DD on gold).
- Also test M30/H4 (VERDICT GATE requires ≥2 TF).

Model 2 used for speed; re-confirm survivors on Model 4 (real ticks) — grid fill-order is
intrabar-sensitive.
