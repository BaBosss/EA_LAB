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

## Tuning sweep — `_56_FibMaxStep` (AUDNZD H1 2024–25 benign, Model 1)
| config | PF | net | eqDD% | trades |
|---|---|---|---|---|
| LogPower base | **3.20** | 173.7 | **2.18** | 12 |
| Fib cap 2× (step1) | 1.53 | **280.6** | 5.55 | 34 |
| Fib cap 3× (step2) | 1.35 | 208.1 | 6.25 | 34 |
| Fib cap 5× (step3) | 1.26 | 166.7 | 6.65 | 34 |
| Fib cap 13× (step5, default) | 1.26 | 166.7 | 6.65 | 34 |

Lower cap helps (cap2× = best Fib: highest net, even beats baseline net $281>$174). cap5×==cap13× because
`MaxLevels=6` never reaches level>5. But every Fib variant runs 34 baskets vs LogPower's 12 — Fib's
level-1 lot (2×) is inherently steeper than LogPower's (1.2×), changing basket turnover.

## Both-window (VERDICT GATE) — LogPower vs best-Fib (cap2×), + 2022 stress
| config | benign 2024–25 | stress 2022 | 2-yr net |
|---|---|---|---|
| LogPower base | +$174 (PF3.20/DD2.18%) | −$275 (PF0.72/DD6.71%) | **−$101** |
| Fib cap2× | +$281 (PF1.53/DD5.55%) | **−$678** (PF0.53/DD8.89%) | **−$397** |

**Decisive:** Fib cap2×'s extra benign return is a false economy — it loses 2.5× more in the stress year
(−$678 vs −$275), so across the regime cycle LogPower wins outright (−$101 vs −$397).

## Conclusion (lane closed)
098-C `PROG_FIBONACCI` is a **validated, functional, tunable bounded-martingale module** — but on a chassis
already tuned with gentle LogPower it is a **strict downgrade at every FibMaxStep**, both-window confirmed.
The Fibonacci sequence is structurally too steep at low levels; capping bounds the tail but not the early
aggressiveness. **Use only where the target chassis has NO progression / a too-flat lot law** (adds bounded
recovery power); do NOT blanket-apply over a tuned LogPower. `dynamic close-money` module still untested
(separate future probe). Also noted: Boss_14 AUDNZD itself loses in 2022 (PF 0.72) = regime-dependent grid
(known demo-first caveat, not new). **098-C integration lane = characterized & closed; module shelved as
conditional-use, not a portfolio upgrade.**

## Artifacts
sets: `_mt5_auto/ab_sets/kangaroo_fib/{Boss14_AUDNZD_BASE,Boss14_AUDNZD_FIB,Kangaroo_XAU_BASE,Kangaroo_XAU_FIB}.set`
reports: `_mt5_auto/reports/{B14_AUDNZD_BASE_2425,B14_AUDNZD_FIB_2425,KANG_XAU_BASE_2425,KANG_XAU_FIB_2425}.htm`
