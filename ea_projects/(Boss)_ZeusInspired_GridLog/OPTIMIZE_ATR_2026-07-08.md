# ZeusInspired AUDJPY — ATR optimization (2026-07-08, RSI-MR method)

Moved out of archive into EA_LAB home, then optimized the ATR-spacing lever (the one that mattered
most for RSI-MR) on AUDJPY (its prior CONDITIONAL symbol), both regimes, lot8x baseline held.

## BUY direction (default) — `ZIGL_ATR_OPT.csv`
| ATR | BWD 2020-22 | FWD 2025-26 |
|---|---|---|
| 1.0 | 1.01 / DD25 | 2.36 / DD7.6 |
| 1.5 | 0.93 / DD22 | 2.04 / DD6.2 |
| 2.2 (def) | 0.99 / DD15 | 1.73 / DD7.8 |
| 3.0 | 0.97 / DD13 | 1.04 / DD12 |
| 4.0 | 1.09 / DD11 | 0.69 / DD6.7 |
| 5.0 | 1.39 / DD4 | 0.92 / DD4 |
→ No ATR clears BOTH regimes with margin. Where FWD is strong (ATR 1-1.5) BWD is ~breakeven at
DD 22-25%; where BWD lifts (ATR 4-5) FWD collapses <1. Inverse-regime, no plateau (unlike RSI-MR).

## SELL direction — `ZIGL_SELL_ATR.csv`
| ATR | BWD | FWD |
|---|---|---|
| 1.0 | **422.72** / 49 trd | 0.97 / 299 trd |
| 2.2 | 2.81 / 27 trd | 1.25 / 35 trd |
| 4.0 | 4.82 / **15 trd** | 1.70 / **11 trd** |
→ "Passes" both regimes at ATR 2.2/4 BUT on 11-49 trades = THIN-SAMPLE ARTIFACT (PF 422 is a glaring
red flag, same class as Blessing-3 PF-67-on-25-trades that we reject). Not statistically trustworthy.

## VERDICT (Claude, 2026-07-08)
**ZeusInspired AUDJPY has no robust, statistically-meaningful both-regime edge** in either direction:
BUY = marginal + regime-dependent; SELL = thin-sample noise. The prior "CONDITIONAL (all 3 years
profitable)" was regime/sample-flattered. Gate satisfied: swept the key lever (ATR) both directions.

**Note on origin:** the reference EA (Zeus Gold Hedge) was a GOLD EA. ZeusInspired was only ever tested
on AUD pairs. If continuing, the highest-EV next step is **XAUUSD (its true instrument), properly
rescaled** (BaseLot/TP/SL sized to gold), swept ATR both regimes — NOT more AUDJPY tuning. Otherwise
**SHELVE** — no deployable config found on the symbols tested.
