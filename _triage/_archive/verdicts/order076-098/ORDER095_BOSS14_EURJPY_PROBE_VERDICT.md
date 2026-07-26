# ORDER-095 Boss_14 EURJPY optimizer-config probe — VERDICT: **VALIDATED but NO NEW VALUE (symbol already demo-staged)**

**Date:** 2026-07-18 · **Judge:** Claude (Opus-seat) · judged from EXISTING reports (no new backtest — "prior results judged" gap closed)

## Evidence (existing reports, `_mt5_auto/reports/BOSS14_EURJPY_*`)
| run | window | PF | net | DD% | trades | note |
|---|---|---|---|---|---|---|
| IS-PICK M1 | 2023.01–2026.07 (full) | 2.49 | +$2,586 | 6.0 | 114 | in-sample optimizer-picked = selection-fit |
| OOS M1 | 2025.07–2026.07 (fresh) | 2.15 | +$473 | 4.25 | **23** | retention IS→OOS 0.86 (≥0.8 gate ✓) but thin sample |
| **M4CONFIRM** (99% real tick) | 2024.01–2026.07 | **1.51** | +$1,250 | 10.0 | 110 | honest every-tick number — passes ≥1.2 gate, DD 10% ok |

## Judgment
The optimizer-refined EURJPY config is **real** (M4 real-tick PF 1.51 / DD 10% / 110t clears the gate;
OOS retention 0.86 holds though 23t is thin). Model-1→Model-4 haircut (2.49→1.51) is the normal grid
optimism-correction, not a failure.

**BUT EURJPY is ALREADY in Boss_14 DEMO cohort #1** (magic 990203, staged 2026-07-04). This probe is a
*config refinement on an already-demo'd symbol*, not a new symbol. Net-new portfolio value = low →
confirms the user's standing assessment that Boss_14 symbol-expansion is **coverage-saturated (labor
high, upside low)**.

## Decision
- **No new demo action.** EURJPY already demo-staged; the refined config is marginally different, not
  worth a second magic. If the demo cohort-1 EURJPY underperforms at its judge date (2026-10), this
  refined config (higher IS PF, similar M4) is a documented fallback to swap in — not before.
- **Boss_14 lane = effectively closed for symbol expansion.** Remaining PARKED-pending-probe symbols
  (EURCAD/USDJPY/etc.) are lower-ranked than EURJPY and share the same saturation → not worth the
  slow-backtest labor vs other lanes. Stock as cold, not queued.

## Artifacts
Reports: `_mt5_auto/reports/BOSS14_EURJPY_{FULL_ISPICK_M1,OOS_M1,M4CONFIRM}.htm` ·
XML: `_mt5_auto/optimizations/BOSS14_OPT_EURJPY_1.xml` · sets: `_mt5_auto/ab_sets/Boss14_GridLog_EURJPY_SENS_V*.set`
