# ORDER-091 build #1 — TSD OsMA+WPR naked probe = ❌ REJECT (structural DD) (2026-07-17)

First build from the 091 catalog's genuine NEVER-TOUCHED cluster (TSD/TheStrategyLab family:
OsMA direction + Williams%R filter — indicators the lab had never tested as signals).

## Build
`(EXP)_OsmaWpr_Naked_rev00.mq5` — faithful naked probe of `TSD_MR_Trade_OsMA_WPR_0_36.mq4`:
OsMA sign = direction · WPR = not-exhausted filter · breakout of prev-bar extreme = trigger ·
structural SL (prev-bar opposite extreme) · R-multiple TP · single-position, flat, bar-gated.
Compiled clean (0 err/0 warn, D:\Meta 5\MetaEditor64).

## Naked smoke (both-window Model-4, `_mt5_auto/OSMAWPR_SMOKE.csv`)
| sym | H4 MAIN/BWD | H1 MAIN/BWD |
|---|---|---|
| XAUUSD | 1.06/0.88 | 1.10/0.91 |
| GBPJPY | 0.73/0.89 | 0.76/0.77 |
| USDJPY | 0.98/0.86 | 0.80/0.81 |
| GBPUSD | 0.93/... | — |
Only XAU marginal (MAIN>1); FX/JPY dead. **DD already 34-60% at default = red flag.**

## Optimize XAU (OsMA-preset × RewardRisk × WprMax × both-window, `_mt5_auto/OSMAWPR_XAU_OPT.csv`)
3 levers swept on the right home. Representative:
| cfg | MAIN pf(DD) | BWD pf(DD) |
|---|---|---|
| fast/rr1.5/w30 | 1.21 (54%) | 1.06 (20%) |
| fast/rr2.5/w30 | 1.07 (39%) | 1.10 (29%) |
| def/rr2.5/w30 | 1.23 (41%) | 0.96 (19%) |
| fast/rr1.5/w15 | 1.16 (**93%**) | 0.92 (40%) |
| def/rr2.5/w15 | 1.11 (81%) | 1.05 (20%) |

**EVERY cell = DD 19-93%** (many 76-93% on MAIN = ruin). Best both-window = fast/w30 1.21/1.06 but 54% DD.
No cell clears both-window ≥1.2 with deployable DD (<20%).

## VERDICT: ❌ REJECT — STRUCTURAL DD-blowup
The OsMA+WPR breakout mechanism produces catastrophic drawdowns (40-93%) across ALL params — the
signal's marginal edge (PF ~1.0-1.23 when positive) cannot overcome it. DD-blowup (>90% at fast/w15) =
structural kill per VERDICT GATE. 3 levers swept (OsMA-period + RR + WprMax) on the right home (XAU)
both-window = kill gate satisfied.
- **Caveat:** naked probe simplified TSD's entry (market-on-break vs pending buy-stop) + R-multiple TP.
  DD may be partly the tight structural SL, but the core read = the direction/filter yields long losing
  streaks (weak signal quality), not a clean edge.
- **091 shortlist update:** the top NEVER-TOUCHED cluster (TSD OsMA+WPR) = tested → rejected. Remaining
  novel leads (iMACD|iForce = OsMA+Force; iSAR|iATR|iMomentum) = lower prior after this; pursue only if a
  specific famous EA (user recognizes) justifies it. Do NOT rebuild TSD-WPR naked.
