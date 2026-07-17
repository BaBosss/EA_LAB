# ORDER-098-D — Currency-strength-meter naked probe verdict (Opus lead, 2026-07-17)

**Concept:** currency-strength meter (fxDreema CCI-Strength / correlation lineage — idea extracted,
built fresh with a real SL, NOT the no-SL Jobot arbitrage code). `CurrStrength_Naked.mq5`: 7-pair
USD-major basket → each currency's momentum vs USD → trade the chart cross toward its stronger leg
(strength(base)-strength(quote) > threshold). Flat-lot, ATR SL/TP, bar-open gate. mql-review PASS,
compile 0/0. Multi-symbol basket data confirmed working in tester (smoke EURJPY H1 = 215 trades).

## Funnel (Model-1, both-window; CSV `_mt5_auto/order098d_currstrength.csv`)
Levers swept: EntryThreshold {0.005, 0.010, 0.020} · exit RR {1.5, 2.0, 3.0} · TF {H1, H4} ·
symbol {EURJPY, GBPJPY, EURGBP}. Lookback held 24.

- **Threshold sweep (H1):** thr0.010 EURJPY 0.89/0.88 (win ~38%); GBPJPY 0.57/0.77; EURGBP 1.19 MAIN
  but 22t + BWD 0.64. thr0.005 = more trades, EURJPY BWD 1.04 but MAIN 0.82. thr0.020 = worse.
- **Exit-RR sweep (EURJPY):** wider TP HURTS — H1 0.89→0.86→0.58 as TP widens (win% drops faster than
  RR rises). Signal is short-horizon, NOT a let-run momentum tail. TP-widen thesis disproven.
- **TF (EURJPY, default RR1.5):** H4 beats H1. **H4 default = MAIN 1.01 / BWD 1.01, 177/119t,
  win 42.4%/41.2%** — the only both-window PF>1 cell with adequate sample.

## VERDICT — PARAMETRIC-marginal → BUILD-ON candidate (not deploy, not discard)
EURJPY H4 clears PF>1 in both windows but only razor-thin (1.01/1.01, win just above the RR1.5
breakeven of 40%), and its neighbors (H1 0.88, H4-RR2.0 0.86/0.96) are sub-1.0 → **marginal point,
NOT a robust plateau → NOT deploy-ready.** But per BUILD-ON≠DEPLOY doctrine, a both-window PF>1 on the
right home (JPY-cross trender, H4) = buildable, not benched. The meter is mechanically validated
(computes across the basket, trades, faint but symmetric both-window pulse).

## Build-on path (the real lift — matches user's vision, 2026-07-17)
The naked probe trades a FIXED chart pair whenever its diff exceeds a threshold. User's vision =
"detect strength → trade the STRONGEST" + "add conditions + many order-entry tricks". The high-EV
build-on is architectural, not parametric:
1. **Strongest-vs-weakest ranking** — scan ALL crosses each bar, trade only the single most extreme
   strength-differential pair (highest conviction), instead of a fixed chart. Should lift win% above
   the ~42% that currently sits on the breakeven line.
2. **Confluence conditions** — regime/trend filter (only take strength-diff when the pair's own trend
   agrees), min-ATR/vol gate, session gate. Each can raise accuracy.
3. **Exit tricks** — trailing / partial / break-even (the "ลูกเล่นออกไม้" the user wants), tuned to the
   short-horizon nature found here (NOT wide fixed TP — that was disproven).
→ next order ORDER-098-E (see taskboard). Meter core `CurrencyStrength()` is reusable as-is.

## Artifacts
- EA: `ea_projects/(EXP)_CurrencyStrength/CurrStrength_Naked.mq5` (+ .ex5)
- Sets: `_mt5_auto/ab_sets/order098d/` · Reports: `_mt5_auto/reports/O098D_*.htm` · CSV above.
