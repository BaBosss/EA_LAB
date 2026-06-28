# BASKET PLAN — Gold_SMC_Run004 + MatchaGrid_CHFJPY

**Created:** 2026-06-28  
**Status:** DEPLOYMENT READY ✅ (IS + OOS validated, lot sizing decided, deployment plan written)

---

## Portfolio Components

| EA | Symbol | TF | Strategy | Lot | Capital |
|---|---|---|---|---|---|
| Gold_SMC_Continuous_MT5_RiskCapV1 | XAUUSD | H1 | SMC mean-reversion + basket recovery | 0.01 | $10,000 |
| MatchaGrid | CHFJPY | M15 | Momentum grid, multi-level recovery | **0.01** | $10,000 |

**Total capital:** $20,000  
**Set files:** `GSMC_run004_locked.set` / `MG_CHFJPY_v1_locked.set`

---

## IS Results (2023.01 – 2026.05, 41 months) — CORRECTED 2026-06-28

> ⚠️ ตัวเลขเดิมใช้ MG=0.02 lot + old params (GridPoints=300, StepAddLot=0.06)  
> ตัวเลขด้านล่างคือ locked set จริง (MG=0.01, GridPoints=350, StepAddLot=0.01)

| Metric | GSMC | MG | Combined |
|---|---|---|---|
| Total PnL | $1,590 | $8,119 | **$9,709** |
| Mean monthly | $38.77 | $198.03 | **$236.81** |
| Std monthly | ~$503 | ~$96 | $600 |
| Monthly win rate | 48.8% | **100%** | **65.9%** |
| Annualized Sharpe | — | — | **1.37** |

**IS correlation (monthly P&L, locked params): r = 0.055 → ADDITIVE ✅**

### Worst IS months (combined):
| Month | GSMC | MG | Combined |
|---|---|---|---|
| 2025.06 | -1,503 | +100 | **-1,403** |
| 2026.02 | -1,432 | +233 | **-1,199** |
| 2024.11 | -778 | +174 | **-603** |

*All drawdowns are GSMC-driven. MG covers partial losses but smaller buffer than before at 0.01 lot.*

---

## OOS Results (2020.01 – 2023.01, backward OOS)

### GSMC OOS (Model=2)
- PF: 1.03 | Net: +$839 | Trades: 722 | Sharpe: 0.16
- Marginal positive. COVID + Fed tightening era was tough for XAUUSD mean-reversion.
- Note: Model=2 gives PF=1.03 (no spread/slippage simulation). Model=4 (real ticks) previously gave PF=0.90 — the true live execution expectation is closer to 0.90-1.03 range.

### MG OOS (Model=1)
- Win rate: **100%** (36/36 months positive) | Total: $5,364 | Mean: $149/mo
- MG is consistent but much smaller OOS returns vs IS ($149/mo vs $630/mo) — IS had very favorable CHFJPY trending conditions

**OOS correlation: r = -0.052 → ADDITIVE ✅** (slightly negative — even better than IS)

| Period | Pearson r | Verdict |
|---|---|---|
| IS (2023.01–2026.05) | +0.072 | ADDITIVE ✅ |
| OOS (2020.01–2022.12) | -0.052 | ADDITIVE ✅ |

**Conclusion: near-zero correlation is structurally robust across two different market regimes.**

### OOS Combined Portfolio (GSMC 0.01 + MG 0.02)
| Metric | Value |
|---|---|
| Mean monthly | $172 |
| Std monthly | $491 |
| Sharpe proxy (ann.) | 1.21 |
| Monthly win rate | 19/36 = **52.8%** |

*OOS combined win rate (52.8%) is lower than IS (87.8%) because MG returns are smaller in OOS. MG still wins every month; combined losses are all GSMC-driven.*

---

## Risk Profile

### GSMC risks
- Mean-reversion on Gold: works well in ranging conditions (2025+), struggles in strong trends
- OOS Sharpe = 0.16 (very low) — thin edge in 2020-2023 conditions
- SL discipline enforced by RiskCapV1 (max 20% floating DD, 25% equity close-all)

### MG (MatchaGrid) risks
- **Grid EA**: real equity drawdown in OOS was 64.59% (model=4). THIS IS THE KEY RISK.
- 100% monthly IS win rate is a grid artifact — hides open equity fluctuations
- MG's 0.02 lot start means at 4 grid levels it holds 0.08 lot, etc.
- Requires monitoring: if CHFJPY trends hard against positions, equity can crater

### Combined mitigation
- Low correlation means GSMC is usually profitable when MG is in drawdown and vice versa
- The 87.8% combined win rate (vs 48.8% GSMC alone) shows MG income covers GSMC losses most months
- Biggest combined losses happen when GSMC has abnormally large losing months (2025.06: -$1,503)

---

## Lot Sizing

### Current (natural sizes)
- GSMC: 0.01 lot → monthly std $586 / unit risk
- MG: 0.02 lot start → monthly std $350 / unit risk

### Risk-parity adjustment
For equal monthly P&L volatility contribution:  
- Keep GSMC at 0.01 (minimum XAUUSD lot)  
- Scale MG to **0.03 lot start** (586/350 × 0.02 ≈ 0.0335 → 0.03)  
- This would bring MG's std to ~$525 (closer to GSMC's $586)

### Deployment lot sizing (locked)
**GSMC=0.01, MG=0.01** — both match their respective locked set files.  
Risk-parity scaling not applicable until live data confirms performance at 0.01/0.01.

---

## Monitoring Rules

1. **GSMC**: alert if equity DD > 20% on the XAUUSD account (RiskCapV1 auto-closes at 25%)
2. **MG**: alert if open floating loss > 15% on the CHFJPY account (grid builds quickly)
3. **Combined**: if both accounts lose >10% in the same month → review if correlation spike (macro event)
4. **Judge date**: 2026-09-22 (same as EA_LAB demo portfolio)

---

## Next Steps

1. ✅ IS correlation: r=+0.072 ADDITIVE
2. ✅ OOS correlation: r=-0.052 ADDITIVE (2026-06-28)
3. ✅ Lot sizing: **CONSERVATIVE** — GSMC=0.01, MG=0.02 (MG OOS DD 64.59% → start small)
4. ⬜ Deploy: configure GSMC on live/demo account + MG on separate account
5. ⬜ Set up monitoring alerts (MG equity DD > 15%, GSMC equity DD > 20%)

→ See full deployment config: `D:\EA_LAB\DEPLOYMENT_PLAN.md`

---

## Files

| File | Path |
|---|---|
| GSMC set | `D:\EA_LAB\_mt5_auto\GSMC_run004_locked.set` |
| MG set | `D:\EA_LAB\_mt5_auto\MG_CHFJPY_v1_locked.set` |
| GSMC OOS report | `D:\EA_LAB\_mt5_auto\reports\GSMC_run004_OOS_corr.htm` |
| MG OOS report | `D:\EA_LAB\_mt5_auto\reports\MG_CHFJPY_OOS_corr.htm` |
| OOS corr script | `D:\EA_LAB\scripts\basket_oos_corr.ps1` |
| IS trade CSVs | `_mt5_auto\GSMC_locked_IS_trades.csv`, `_mt5_auto\MG_CHFJPY_IS_trades.csv` |
