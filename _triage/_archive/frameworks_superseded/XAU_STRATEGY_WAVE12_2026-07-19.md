# XAU Strategy Design + Wave 1/2 Build & Test — 2026-07-19

User request: design 10 XAU strategies (+5 small-TF), then "build all + test". Phased into waves
(pacing rule). This session: designed 15, built+compiled+tested 6 (Wave 1 + Wave 2).

## Design (15 strategies)
- **S1–S10** (H4/D1/M30/M15/M5 mixed): trend×2, mean-reversion×2, breakout×2, session, news/vol, +2.
- **SS1–SS5** (5m/15m small-TF): London ORB, NY ignition, VWAP reversion, sweep reversal, squeeze micro.
- Full specs (hypothesis / TF+session / entry / exit ATR-multiples / sizing / regime filter / failure modes /
  freq×WR×RR) in session transcript. Cost realism: all distances ATR-based (≥1 ATR) to survive 40-70pt round-trip.

## Built + tested (6 EAs, all compile 0/0, chassis L1: single-position, real SL, bar-open gate, magic-scope, hard caps)

| EA | file | magic | TF | verdict | evidence |
|---|---|---|---|---|---|
| S2 TsMom | (TRND)_TsMom_XAU | 992001 | D1 | **PARKED-VERIFY(user)** | MAIN PF 3-5 / BWD <1 all params; ADX last-opt no help |
| S5 AsianRange | (BRK)_AsianRange_XAU | 992002 | M30 | **DEAD-OPTIMIZED (cell)** | healthy-n MAIN 0.81 / BWD 0.9 both <1; ladder+TpRR complete |
| SS1 LondonORB | (BRK)_LondonORB_XAU | 992003 | M15 | **BUILD-ON** ⭐ | plateau MAIN 1.14-1.17 / BWD 1.02-1.07 @ n700 |
| S1 TrendRider | (TRND)_TrendRider_XAU | 992004 | H4 | PROCEED (smoke 1.77/72) | needs BWD (may be bull-flattered like S2) |
| SS2 NyIgnition | (TRND)_NyIgnition_XAU | 992005 | M15 | WATCH (smoke 1.02/639) | thin |
| SS4 SweepReversal | (MR)_SweepReversal_XAU | 992006 | M15 | PROCEED (smoke 1.31/146) | reversion pulse, less regime-risk |

Windows: MAIN 2023.01-2025.12 · BWD 2020-2022. Bars: smoke PF≥1.2 · CANDIDATE MAIN≥1.2 hard AND BWD≥1.0 soft.

## Key findings
1. **SS1 LondonORB is the real find** — robust both-window-positive plateau at 700+ trades, cost-survived, just
   under the 1.2 hard bar. Build-on next (partial-TP, trend filter, symbol×TF).
2. **Trend/momentum on XAU (S2, likely S1) = bull-regime-flattered** — huge MAIN, fails BWD whipsaw. Real but
   regime-dependent. ADX can't fix (V-reversals fire at high ADX). Deploy = demo-isolate / macro-regime overlay.
3. **S5 Asian-range M30 = wrong vehicle** — breakout concept alive but not on this session/TF (repo's home = XAU H4 NY).
4. **SS4 sweep-reversal** and **SS2 ignition** = reversion/intraday pulses worth the both-window optimize next.

## Queue (next tester-free rounds)
S1 + SS4 both-window optimize → SS1 build-on campaign → SS2 decide → Wave 3 (S6/SS5 squeeze, SS3 VWAP, S3
Asian fade — Model-4 from smoke, cost-marginal test-to-kill). Formal registry rows (scorecard/index/EDGE_CATALOG/B1)
pending. Sweep scripts + result CSVs in `_mt5_auto/` (s2/s5/ss1/wave1/wave2 *.ps1 + *.csv).
