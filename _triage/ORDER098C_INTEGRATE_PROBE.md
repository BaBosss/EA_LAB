# ORDER-098-C integrate probe — PROG_FIBONACCI vs native lot-law on a stacking chassis

**Date:** 2026-07-18 · **Judge:** Claude (Opus-seat) · Model-1 exploratory (confirm Model-4 if pursued)

## Vehicle selection (de-risk)
- **Kangaroo val078 = WRONG vehicle:** `LotProg=50` (PROG_NONE, single-order) — BASE==FIB byte-identical
  (net 272.56/PF 1.82/70t both) because no order stacking occurs → lot-progression law never exercised.
- **Boss_14 GridLog = correct vehicle:** `LotProg=55` (PROG_LOG_POWER) + `_9_MaxLevels=6`/`RC_MaxLevelsOverride=6`
  = genuine 6-level stacking → progression IS exercised.

## Result — Fibonacci-cap vs native LogPower (Boss_14 AUDNZD H1, 2024.01–2025.01, Model 1)
| metric | LogPower (base, factor 1.3) | Fibonacci-cap (FibMaxStep 5) |
|---|---|---|
| PF | **3.20** | 1.26 |
| net | +$173.7 | +$166.7 |
| eqDD | **2.18%** | 6.65% (≈3×) |
| trades | 12 | 34 |
| recovery | 0.78 | 0.24 |

## Reading
The `PROG_FIBONACCI` module **functions correctly** (clearly different, valid behavior — lot changes shift
basket-close timing → more baskets). But the Fibonacci sequence (1,2,3,5,8,13) is **far steeper** than
Boss_14's tuned `LogPower(1.3^ln(orderN))` at these levels → same net profit but **3× the drawdown and PF
1.26 vs 3.20**. On an already-well-tuned chassis, Fib-cap is a *downgrade*.

**Conclusion:** 098-C Fib-cap is a validated drop-in that **needs its own tuning** (lower `_56_FibMaxStep`
or a gentler custom sequence), NOT a free upgrade. It helps a chassis with NO progression or a too-flat
lot law (bounded recovery power added); it hurts one already tuned with gentle LogPower. `dynamic
close-money` module untested here (separate probe). Integration = per-chassis tuning exercise, not blanket apply.

## Artifacts
sets: `_mt5_auto/ab_sets/kangaroo_fib/{Boss14_AUDNZD_BASE,Boss14_AUDNZD_FIB,Kangaroo_XAU_BASE,Kangaroo_XAU_FIB}.set`
reports: `_mt5_auto/reports/{B14_AUDNZD_BASE_2425,B14_AUDNZD_FIB_2425,KANG_XAU_BASE_2425,KANG_XAU_FIB_2425}.htm`
