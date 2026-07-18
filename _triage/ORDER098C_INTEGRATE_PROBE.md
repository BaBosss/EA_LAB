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

## Part 2 — dynamic close-money module (`_57_DynClose*`) both-window (Boss_14 AUDNZD)
Existing exit = fixed `_2_BasketTP_Money=175`. dyn-close adds a depth-scaling target
`base + (openCount/C)*base` (whichever target hits first closes the basket).
| config | benign 2024–25 | stress 2022 | 2-yr net |
|---|---|---|---|
| baseline fixed $175 | +$174 (PF3.20/DD2.18%) | −$275 (PF0.72/DD6.71%) | −$101 |
| dyn base50/C4 (target 62→150, **below** $175 = tighter everywhere) | −$349 (PF0.69/DD7.0%) | +$99 (PF1.07/DD2.7%) | −$250 ❌ |
| **dyn base100/C4 (target 125→300, **exceeds** $175 at depth≥4)** | +$123 (PF1.25/DD2.95%) | −$171 (PF0.87/DD6.33%) | **−$48 ✅** |

**Direction matters:** a target that scales *below* the baseline (base50) = premature exit = worse both-window.
A target that scales *above* baseline at depth (base100 = "demand more profit when deep, let deep baskets run")
= genuine **regime-robustness dial**: trades some benign upside ($174→$123) for materially smaller stress loss
(−$275→−$171) → best 2-yr net of all configs (−$48 vs baseline −$101) with lower stress DD. (Still net-negative
because AUDNZD Boss_14 loses across this regime cycle anyway — the module makes a losing config *less* losing;
on a profitable chassis it should genuinely improve robustness.)

## Conclusion (098-C lane fully characterized & closed — BOTH modules tested)
- **`PROG_FIBONACCI`** = strict downgrade at every FibMaxStep on a tuned-LogPower chassis (Fib sequence too
  steep at low levels; loses both-window). Use only on flat/no-progression chassis. **Shelved.**
- **`dynamic close-money`** = **conditional WIN** when tuned to demand-more-at-depth (base>baseline TP): a real
  regime-robustness dial (best 2-yr net here). Tighter-everywhere config (base<TP) hurts. **Keep as an
  opt-in robustness modifier**; worth a proper follow-up on a *profitable* stacking chassis + Model-4 + multi-symbol.
- Both modules function correctly (OFF-by-default, byte-identical regression). Neither is a blanket upgrade;
  dyn-close (deep-scale) is the one with demonstrated positive value. Also noted: Boss_14 AUDNZD loses in 2022
  (PF 0.72) = known regime-dependent grid caveat, not new.

## Artifacts
sets: `_mt5_auto/ab_sets/kangaroo_fib/{Boss14_AUDNZD_BASE,Boss14_AUDNZD_FIB,Kangaroo_XAU_BASE,Kangaroo_XAU_FIB}.set`
reports: `_mt5_auto/reports/{B14_AUDNZD_BASE_2425,B14_AUDNZD_FIB_2425,KANG_XAU_BASE_2425,KANG_XAU_FIB_2425}.htm`
