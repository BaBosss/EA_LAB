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
| BUY STOP | 519.88 | 2.33 | 35 | 412.60 (4.11%) |
| BUY LIMIT | 261.47 | 2.91 | 23 | 543.18 (5.23%) |

The repaired helper and Probe wrapper compile 0 errors / 0 warnings. Tester log 20260828 emits `[PASS] AdaptiveTrendGrid_Test`. A negative full-surface run with `SLMode=SL_ATR` returns INIT failure with `Boss19 owns exits and requires SLMode=SL_NONE`. Tester logs also show repeated `[B19] finite pending ladder complete`, confirming the repaired short ladder is no longer silently one-leg-deep on the pinned XAUUSD environment. These remain V0 triage results only; neither is a source-parity claim, optimization verdict, candidate promotion, or permission to attach to DEMO/LIVE.

## Independent review and bounded repair

Claude Code / Opus reviewed frozen SHA `ad45b685ef473a1d80fb8ac1746f8869c3721cef` read-only and returned `VERDICT: PASS`, `ORIGINAL_SCOPE_PRESERVED: YES`, `INTEGRATION_RECOMMENDATION: INTEGRATE`. The review nevertheless identified concrete PRE-BASELINE defects: sub-minimum DOWN lots made later ladder levels unplaceable, non-NONE `SLMode` was silently unreachable, a transient ambiguity latch could suppress strategy exits, and an empty arm could retry stale targets indefinitely.

One bounded repair keeps the hard risk ceiling supreme while flooring DOWN decay at broker minimum only when `RC_MaxLot` still permits it, requires `SLMode=SL_NONE`, recomputes ambiguity from broker state each tick, resets a fully empty failed arm for a fresh reference, and corrects Probe-facing labels. The post-repair smoke values above supersede the earlier 64.15/4.62 smoke values. Exact source coefficients remain engineering hypotheses and the strategy remains PRE-BASELINE.