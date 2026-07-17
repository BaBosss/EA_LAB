# ORDER-098-F — Pairs-spread stat-arb verdict (Opus lead, 2026-07-17)

**Concept:** fxDreema Jobot "Arbitrage N-Pairs" IDEA (correlated-basket) extracted and REBUILT with a
real SL cage (the course files were NO_SL / uncapped — unshippable). `PairSpread_StatArb.mq5`: two
correlated symbols, spread = log(A)-log(B), rolling z-score (window 100), fade |z|>entry → SELL rich
/ BUY cheap leg, exit on mean-revert (|z|<exit) OR z-stop cage (|z|>stop). 2-leg hedged, equal flat
lots, one basket at a time, no martingale. mql-review PASS (hedging-guard, partial-fill → close-all
so no naked leg). compile 0/0. **Mechanically clean: SL-cage caps tails — largest single loss ~2% of
gross loss, no blowup spike (the course's exact failure mode, fixed).**

## Funnel (Model-1, both-window; CSV `_mt5_auto/order098f_statarb.csv`)
Swept: EntryZ {1.5,2.0,2.5,3.0} · ExitZ {0.0,0.5} · TF {H1,H4} · pair {EURUSD/GBPUSD, AUDUSD/NZDUSD}.

- **H1 EURUSD/GBPUSD:** z2.0 0.96/0.95, z2.5 0.96/0.99, z1.5 0.95/0.93 — all sub-1 (cost drag: 500-1270
  trades × 2 legs × spread eats the reversion edge). AUDUSD/NZDUSD weaker (0.85/0.87).
- **TF raise H1→H4 (the cost-drag fix):** cuts trade count ~6× → **H4 z2.5 = MAIN 1.07 (130t) / BWD
  1.04 (110t), win 49-51%, eqDD 4.1%/13.1%** — the only both-window PF>1 cell with adequate sample.
- Raising Z beyond 2.5 does NOT help (H4 z3.0 = 1.05/0.94, thins + BWD dips); ExitZ=0.0 hurts (0.97/0.81).

## VERDICT — PARAMETRIC candidate (session's strongest result) — NOT deploy yet
H4 z2.5 EURUSD/GBPUSD clears PF>1 in **both** windows (1.07/1.04) with ~120 trades/window and low DD —
a genuine both-window edge on a NEW diversifier class (pairs mean-reversion, orthogonal to every
momentum/grid/breakout EA in the book). Stronger than the 098-D currency-strength marginal (1.01/1.01).
BUT margins are thin (1.04-1.07) and H4 z2.5 was chosen by looking at both MAIN+BWD → per the DEPLOY
gate this is **selection-fit until validated**: needs (1) plateau-center confirmation (neighbors z2.0/
z2.75, ExitZ 0.3/0.7, ZWindow 80/120 must not collapse — currently z3.0 BWD dips to 0.94, so the ridge
is narrow), (2) a holdout window not used to select, (3) Monte Carlo. Do NOT promote to demo before that.

## Next step (ORDER-098-G, stocked)
Run the robustness-validator funnel on H4 z2.5 EURUSD/GBPUSD: plateau map around z2.5 → holdout →
MC. If plateau holds + holdout PF>1 + MC survives → demo candidate (new diversifier leg). Also worth:
2-3 more correlated pairs (EURGBP legs, EURCHF/USDCHF, GBPUSD/EURUSD variants) to see if the H4-z2.5
config generalizes (unlike currency-strength, this is a cleaner mechanism so cross-pair may hold).

## Artifacts
- EA: `ea_projects/(EXP)_PairSpreadArb/PairSpread_StatArb.mq5` (+ .ex5)
- Sets: `_mt5_auto/ab_sets/order098f/` · Reports: `_mt5_auto/reports/O098F_*.htm` · CSV above.

---

# ORDER-098-G — Robustness validation (Mode B, robustness-validator, 2026-07-17)

Validated the H4 z2.5 EURUSD/GBPUSD center config (EntryZ 2.5 / ExitZ 0.5 / ZWindow 100 / StopZ 3.5).
Runner `_mt5_auto/order098g_validate.ps1` · results `_mt5_auto/order098g_validate.csv` · MC JSON
`_mt5_auto/order098g_mc.json` · center trade list `_mt5_auto/order098g_center_trades.csv` · reports `O098G_*.htm`.

## Test 1 — Plateau map (OFAT around center, both-window PF MAIN/BWD) — **HOLDS**
| axis | config | MAIN | BWD |
|---|---|---|---|
| EntryZ | 2.0 | 1.16 | 1.07 |
| EntryZ | 2.25 | 1.07 | 1.06 |
| **EntryZ** | **2.5 (center)** | **1.07** | **1.04** |
| EntryZ | 2.75 | 1.02 | **0.92** ✗ |
| ExitZ | 0.3 | 1.14 | 1.15 |
| ExitZ | 0.7 | 1.02 | 1.01 |
| ZWindow | 80 | 1.01 | 1.00 (flat) |
| ZWindow | 120 | 1.07 | 1.14 |

Broad plateau, **not a spike**: 6/8 neighbors clear PF≥1.0 in *both* windows. Only `EntryZ 2.75/BWD`
(0.92) collapses — the edge is bounded above z2.5 (consistent with 098-F z3.0=0.94), so center sits on
the SAFE lower-Z side of the ridge, not on a peak. `w80/BWD` is flat (1.00). Best cell = ExitZ 0.3
(1.14/1.15) but NOT re-selected (would be selection-fit); center is mid-plateau. **PASS.**

## Test 2 — True holdout 2017-2019 (window never used to select) — **PASS**
PF **1.13**, 96 trades, eqDD 6.17%, net +527.87. Edge generalizes to genuinely unseen data — the
strongest single piece of evidence that this is a real edge, not a both-window fit.

## Test 3 — Monte Carlo (skill script, 1000 perm, shuffle+bootstrap, oos-split 0.7) — MIXED
- Ruin prob **0.0%** (SL-cage works; deposit 10k, 50% ruin threshold) — GREEN.
- Shuffle PF band degenerate (single realized sequence → 0 range); informative signal is bootstrap:
  **bootstrap PF_5th = 0.721** (RED), PF_median 1.058, range 0.877 (YELLOW). Edge is **thin**.
- DD_95th: shuffle 13.99% / bootstrap 19.65% (≈ worst-window MaxDD 13% × 1.5 — borderline).
- **Date-split OOS (last 30% ≈ 2025 tail): PF 0.837, degradation 33.9%, oos net -312.5** — recent
  sub-period softness. OOS PF 0.837 is in the 0.7-0.9 weak band (< CANDIDATE_OK's 0.9 floor).

## Test 4 — Cross-pair generalization (center z2.5, both-window) — **DOES NOT GENERALIZE**
- GBPUSD/EURUSD (legs reversed): 1.09 / **0.93** — fails BWD.
- EURCHF/USDCHF: 1.15 / **0.88** — fails BWD.
The edge is specific to the EURUSD/GBPUSD ordering; this is **one diversifier leg, not a family**.

## VERDICT — **CANDIDATE_WEAK** (Mode B) → portfolio-selector with WARNING, NOT direct live
Score band 40-54 / OOS PF 0.837 (<0.9) caps below CANDIDATE_OK. But true-holdout 1.13 + broad plateau +
0% ruin keep it well clear of CANDIDATE_REJECT (OOS PF 0.837 > 0.7). The weakness is **edge thinness**
(bootstrap PF_5th 0.72, OOS-tail 0.84), which is lot-scale-invariant → **RESIZE-FIRST does not apply**
(not a ruin/DD breach). Verdict per user doctrine [[feedback-buildon-pf-gt-1]]: PF>1 both-window +
holdout = **buildable diversifier candidate, not dead** — but promote as a SMALL-size portfolio leg
under corr-check, watch the recent-regime softness. NOT a standalone deploy.

## Portfolio corr-check (portfolio-selector, 36-mo BWD overlap 2020-2022) — **ADDITIVE, not redundant**
Merged stat-arb center-config BWD monthly P/L into the 6-EA cohort matrix (`order098g_corr_returns.csv`),
ran `portfolio_analysis.py` (`order098g_corr.json`). StatArb_EURGBP vs cohort correlations:
MACD_USDCAD **−0.73**, MG_v1 **−0.56**, MACD_GBPUSD **−0.52**, NuiIndy −0.13, GoldReaper +0.20,
ST03_replica **+0.36**. Highest positive = +0.36 → **clears the ≤0.40 additive gate against every EA**;
several strongly negative (hedges the MACD/MG_v1 momentum legs). Orthogonality thesis CONFIRMED — genuine
new diversifier class. Combined-portfolio DD stays 5.25%, worst same-month −3.0% (< 10% target).

**Watch-item:** StatArb~ST03_replica DD-overlap 69% RED (both GBP mean-reversion → soft the same months),
though severe-overlap only 13.9% and both are small-DD EAs. → don't stack full weight on both GBP-reversion
legs at once. NOTE: the skill's other RED dd-overlap/`corr>0.7` blocking flags are **cohort-internal
artifacts** (the 4 always-profitable EAs compute MaxDD≈0 → degenerate 100% severe-overlap; the 0.768 pair
is MG_v1~MACD_GBPUSD, not StatArb) — not attributable to the new leg. Corr-gate on the NEW leg = PASS.

## Recommendation (Claude, sole judge)
Add PairSpread_StatArb (H4 z2.5 EURUSD/GBPUSD) as a **small-weight DEMO diversifier leg**: CANDIDATE_WEAK
cap 25% × candidate 20% lot-cut → effective small size. Corr-check passed; edge real-but-thin. **DEMO
only, NOT direct live** (Mode-B rule + user doctrine). Watch ST03 DD-timing overlap post-deploy.

## Build-on (later, not now)
ExitZ 0.3 looked stronger across the plateau (1.14/1.15) — a *fresh* both-window+holdout validation of
ExitZ 0.3 (not a re-pick off this map) could lift the edge out of the thin band before committing weight.
