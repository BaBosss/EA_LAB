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
