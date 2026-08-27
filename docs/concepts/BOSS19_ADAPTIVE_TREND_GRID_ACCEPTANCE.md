# Boss19 V0 acceptance evidence

## Regression RCA

The archived Build-6090 numeric baseline became non-reproducible on 2026-08-27 even when its exact source commit `3d5df443d9b43bc65845b77a8a09bbf2c3a009ae`, original full `.set` files, Build 6090 terminal binary, bars, and tick counts were reused. Boss16 also showed materially different swap charges and its first divergent basket close shifted by one minute. This is classified **C — ENVIRONMENT/DATA (broker economics/swap drift)**, not a Boss19 core regression.

A same-environment A/B then compiled exact baseline source and candidate source `76d2af28648a605e2bb6c58c4ded79ffdaa38a9f` sequentially against the same current XAUUSD tester environment. Results matched exactly for all eight baseline Boss EAs:

| EA | Net | PF | Trades | Max equity DD abs | BASE vs candidate |
|---|---:|---:|---:|---:|---|
| Boss_11_GridTrend | -433.54 | 0.87 | 480 | 668.57 | exact |
| Boss_12_Breakout | -176.71 | 0.85 | 164 | 263.55 | exact |
| Boss_13_MeanRev | -18.79 | 0.99 | 209 | 317.82 | exact |
| Boss_14_GridLog | 623.09 | 20.89 | 81 | 153.50 | exact |
| Boss_15_ST03 | -157.56 | 0.84 | 136 | 304.83 | exact |
| Boss_16_KangarooGrid | 305.19 | 1.83 | 71 | 458.13 | exact |
| Boss_17_Wave5 | -86.05 | 0.46 | 26 | 102.79 | exact |
| Boss_18_JumStoch | 366.29 | 1.21 | 298 | 199.62 | exact |

The old baseline must not be silently treated as current economics. Existing baseline governance should be re-pinned only through its declared provenance-migration path after the final source HEAD is clean; no strategy/risk semantics are changed by that re-pin.

## Boss19 V0 evidence boundary

The earlier `584.14 / PF 8.34 / 8 trades` run used generic template defaults (`ATR14 × 1.0`) and is infrastructure smoke only. It is **not** evidence for the visible adaptive-grid strategy. V0 strategy triage must use the explicit ATR30 × 0.30 STOP/LIMIT probe sets and treat all still-unresolved coefficients as hypotheses.

## ATR30 x 0.30 V0 probe smoke

On the current XAUUSD / H1 / 2024-01-01..2024-07-01 / Model-1 environment, both explicit full-surface V0 sets compiled and ran with stamped temporary build identity:

| UP hypothesis | Net | PF | Trades | Max equity DD |
|---|---:|---:|---:|---:|
| BUY STOP | 64.15 | 1.25 | 18 | 443.33 (4.41%) |
| BUY LIMIT | 4.62 | 1.03 | 15 | 300.46 (2.96%) |

The helper smoke compiled 0 errors / 0 warnings and emitted `[PASS] AdaptiveTrendGrid_Test: mapping and lot-law helpers OK`. The Probe wrapper also compiled 0/0. These are low-trade V0 triage results only: STOP is the stronger hypothesis in this one bounded smoke, but neither result is a source-parity claim, optimization verdict, candidate promotion, or permission to attach to DEMO/LIVE.
