# ROBUSTNESS VERDICT — Quantum Speed EURUSD H1

**Date:** 2026-06-15 (session 8)  
**EA:** `Quantum\Quantum Speed` (Quantum Speed EURUSD H1)  
**Params:** `QSpeed_EURUSD_v1_locked.set`  
**Overall verdict: ⛔ DISQUALIFIED — Model=4 real-ticks validation FAILS**

---

## 1. Params (robust pick)

| Parameter | Value | Note |
|---|---|---|
| number_pip_trigger | 25 | Entry signal trigger distance (pips) |
| number_pip_stoploss | 250 | Fixed stop loss (pips) |
| number_pip_takeProfit | 350 | Fixed take profit (pips), R/R = 1.4:1 |
| InpTrailingStop | 8 | Trail distance (pips) |
| InpTrailingStart | 5 | Start trailing at 5 pips profit |
| pipsToCloseSl | 250 | Same as SL |
| lot_size_auto | 0.025 | Auto lot = 2.5% balance risk |

**Strategy:** Trend-following scalper. Enters on signal, locks in profit quickly via very tight trailing stop (5-pip start). Most trades close profitable via trail; rare full SL hits. TP=350/SL=250 = 1.4:1 R/R.

---

## 2. IS Results (2023-2026, optimize window)

| Metric | Value | Gate | Status |
|---|---|---|---|
| PF | 2.82 | ≥1.20 | ✅ PASS |
| DD% | 6.88% | ≤20% | ✅ PASS |
| RF | 3.01 | ≥1.50 | ✅ PASS |
| Trades | 180 | ≥100 | ✅ PASS |
| Net | +$2,666 | >0 | ✅ |
| Win rate | 97% | — | note: tight trail |

**BacktestScore: 84.7/100 (Tier A)**

MC IS (shuffle): ruin=0.0%, DD P95=11.61%  
MC IS (bootstrap): PF P5=1.196, ruin=0.0%, DD P95=14.84%

---

## 3. OOS Results (2020-2023, true out-of-sample)

| Metric | Value | Gate | Status |
|---|---|---|---|
| PF | 2.08 | ≥1.20 | ✅ PASS |
| DD% | 7.67% | ≤20% | ✅ PASS |
| RF | 1.72 | ≥1.50 | ✅ PASS |
| Trades | 122 | ≥100 | ✅ PASS |
| Net | +$1,512 | >0 | ✅ |
| Win rate | 98% | — | note: tight trail |

**BacktestScore: 78.6/100 (Tier B)**

MC OOS (shuffle): ruin=0.0%, DD P95=12.0%  
MC OOS (bootstrap): PF P5=0.875, ruin=0.0%, DD P95=17.34%  
⚠ OOS bootstrap PF P5=0.875 (below 1.0) — wide CI due to only 2 SL hits in 122 trades

---

## 4. IS → OOS Degradation

| Metric | IS | OOS | Retention | Status |
|---|---|---|---|---|
| PF | 2.82 | 2.08 | 74% | ✅ Acceptable |
| DD | 6.88% | 7.67% | stable | ✅ |
| RF | 3.01 | 1.72 | 57% | ✅ Still above gate |
| Trades | 180 | 122 | 68% | ✅ |

**Note:** OOS Sharpe (1.92) was actually HIGHER than IS Sharpe (1.59) with default params — consistent monthly gains throughout 2020-2023 (COVID, EUR bear, recovery).

---

## 5. Risk Structure

✅ Fixed SL: 250 pips per trade (no martingale, no grid pyramiding)  
✅ Auto lot 2.5% risk = $250 per trade on $10,000 account  
⚠ Tight trailing stop: 5-pip trail creates ~98% win rate — strategy depends on smooth intraday price action  
⚠ **Gap risk**: Tight trailing stop may be bypassed by overnight or news gaps → actual SL hits may be worse than backtest  
⚠ **Model=1 (OHLC) used** — trailing stop behavior idealized; should validate with Model=4 (real ticks)  
⚠ EA origin: "Gold Speed +84869798999" (Vietnamese commercial EA, possible license restrictions in live)  

---

## 6. Sizing Guidance

| Scenario | Estimated live DD |
|---|---|
| OOS report DD | 7.67% |
| Adjusted for live spread/slippage | ~12-15% |
| Conservative live estimate | 15-20% |

**Recommended live lot scale:** Start at 50% of backtest lot (0.025 × 0.5 = 0.0125 auto risk) for first 3 months live.

---

## 7. Next Steps

- [x] IS PASS + OOS PASS + MC ruin=0% (Model=1 OHLC)
- [x] **Model=4 real-ticks validation** ← ⛔ FAIL

## 8. Model=4 Real-Ticks Result — DISQUALIFYING

IS real-ticks (2023-2026):
- PF=**1.13**, DD=8.16%, RF=0.11, **trades=68** (vs 180 in OHLC) → **REJECT**
- One-big-trade: largest profit = 70% of total net ($95 net on $10,000)

**Root cause: 5-pip trailing start is an OHLC backtest artifact.**  
In OHLC mode (M1 bars), the trailing stop triggers at bar close — favorable prices save losing trades.  
In real-tick mode, the trail triggers at actual tick prices → more SL hits, fewer saves.  
Trade count drops 62% (180→68) because many "OHLC trigger" entries never execute in real-tick.

**Lesson:** Any EA with tight trailing stops (<20 pips start) MUST be validated with Model=4 before trusting OHLC results. This is a classic tight-trail artifact.

**Status: DISQUALIFIED**
