# EA Deployment Plan — 2026-06-28

> ⚠️ canonical entry = **`PROJECT_STATE.md`**. ไฟล์นี้ = plan ของ **standalone EA_RUNNER_v1**
> (Donchian breakout, XAUUSD H1, magic **5001**) — **แยกคนละเรื่องกับ 9-EA demo portfolio**
> (นั่นอยู่ `DEMO_DEPLOYMENT_PLAN.md`). EA_RUNNER_v1 ไม่อยู่ใน demo 9 ตัว — ตรวจสถานะจริงก่อนใช้.

## Unit A: EA_RUNNER_v1 (STANDALONE)

**EA:** EA_RUNNER_v1.ex5 (EA_CORE_V1 Phase 5)  
**Signal:** StrategySignal_v5 — Donchian breakout + ATR expand filter  
**Symbol / TF:** XAUUSD H1  
**Set file:** `D:\EA_LAB\_mt5_auto\EA_RUNNER_v1_locked.set`

### Validated IS metrics (2023.01–2026.06, Model=2)
| Bars | PF | Net | Trades | Sharpe | RecFactor |
|------|-----|-----|--------|--------|-----------|
| 55 (default) | **1.68** | $1,945 | 296 | **3.02** | 7.12 |

### Key params (locked)
```
InpBreakoutBars   = 55
InpSlMult         = 1.5
InpTpMult         = 5.0
InpAtrPeriod      = 14
InpAtrMaPeriod    = 20
InpAtrRatio       = 1.0
InpBuyOnly        = true
InpLotSize        = 0.01
InpMagic          = 5001
InpMaxDDPercent   = 20.0   ← PortfolioGuardian: block new entries if DD from peak > 20%
InpEquityFloor    = 0.0    ← disabled
```

### Basket correlation check (EA_RUNNER_v1 vs GSMC, IS 2023-2026)
- Pearson r = **0.518** → WATCH ⚠️ (both XAUUSD H1 — same instrument, same macro regime)
- **Verdict: NOT a basket pair with GSMC.** Structurally correlated because both exposed to XAUUSD H1 momentum/reversion cycle.
- EA_RUNNER_v1 runs STANDALONE. Has built-in PortfolioGuardian (20% DD) as account-level protection.

### Deployment
- Account: separate from GSMC (avoid double XAUUSD H1 exposure from same account)
- Magic: 5001
- Monitor: PortfolioGuardian fires at 20% DD from equity peak — check journal if blocked

### ⚠️ ถ้า EA หยุดเทรดโดยไม่มีสาเหตุชัดเจน
1. ดู Journal tab ใน MT5 → หา log line: `PortfolioGuardian BREACHED | equity=... dd=...%`
2. ถ้า DD เกิน 20% → EA บล็อกออเดอร์ใหม่ทั้งหมด (ไม่มี auto-recovery)
3. **วิธี reset:** Reload EA (F7 → OK) หรือ remove แล้ว attach ใหม่ → `Portfolio_Init()` จะ set peak = equity ปัจจุบัน → unlock
4. หลัง reset ให้พิจารณาว่า DD 20% นั้นเกิดจากอะไร ก่อนปล่อยให้ EA เทรดต่อ

---

## Unit B: GSMC + MatchaGrid Basket

**EA 1:** Gold_SMC_Continuous_MT5_RiskCapV1 (GSMC)  
**EA 2:** MatchaGrid  
**Set files:** `GSMC_run004_locked.set` / `MG_CHFJPY_v1_locked.set`

### Portfolio correlation (validated)
| Period | Pearson r | Verdict |
|--------|-----------|---------|
| IS (2023.01–2026.05, 41 mo) | +0.072 | **ADDITIVE ✅** |
| OOS (2020.01–2022.12, 36 mo) | -0.052 | **ADDITIVE ✅** |

Near-zero correlation is structurally robust across two market regimes. Basis: GSMC = XAUUSD H1 mean-reversion, MG = CHFJPY M15 momentum grid — different instruments + different strategy types.

### Combined IS stats (GSMC=0.01 / MG=0.01 locked params)
| Metric | GSMC | MG | Combined |
|--------|------|----|---------|
| Total | $1,590 | $8,119 | **$9,709** |
| Mean/mo | $38.77 | $198.03 | **$237** |
| Win rate | 48.8% | 100% | **65.9%** |
| Sharpe (ann.) | — | — | **1.37** |
| IS r (locked params) | — | — | **0.055 ADDITIVE ✅** |

### Combined OOS stats (backward 2020–2023)
| Metric | Value |
|--------|-------|
| Mean/mo | $172 |
| Win rate | 52.8% |
| Sharpe | 1.21 |
| MG equity DD (OOS, Model=4) | **64.59%** ← KEY RISK |

### Lot sizing decision: CONSERVATIVE (start)
- GSMC: **0.01 lot** (minimum XAUUSD lot, locked)
- MG: **0.02 lot** (natural start for MatchaGrid)
- Rationale: MG OOS showed 64.59% equity DD in worst-case trending period. Start conservative, scale after 3 months live data.

### Deployment config
```
Account 1: GSMC on XAUUSD H1
  EA:      Gold_SMC_Continuous_MT5_RiskCapV1
  Set:     GSMC_run004_locked.set   (InpLot=0.01)
  Capital: $10,000

Account 2: MatchaGrid on CHFJPY M15
  EA:      MatchaGrid
  Set:     MG_CHFJPY_v1_locked.set  (InpLotStart=0.01, GridPoints=350, StepAddLot=0.01)
  Capital: $10,000
```

### Monitoring rules
1. **GSMC**: alert if floating DD > 20% on XAUUSD account (RiskCapV1 auto-closes at 25%)
2. **MG**: alert if open floating loss > 15% on CHFJPY account (grid builds fast in strong trends)
3. **Combined**: if both accounts lose >10% same month → check for correlation spike (macro event)
4. **Judge date**: 2026-09-22 (same as EA_LAB demo portfolio)

---

## Summary

| Unit | Type | Symbol | Status | Action |
|------|------|--------|--------|--------|
| EA_RUNNER_v1 | Standalone | XAUUSD H1 | ✅ Ready | Deploy separately |
| GSMC | Basket EA 1 | XAUUSD H1 | ✅ Deployed (demo) | Keep running |
| MatchaGrid | Basket EA 2 | CHFJPY M15 | ✅ Ready | Deploy on separate account |

Correlation between EA_RUNNER_v1 and GSMC: r=0.518 (same instrument — expected). They must run on separate accounts and are treated as independent units, NOT a combined basket.

---

## Files Reference

| File | Path |
|------|------|
| EA_RUNNER_v1 set | `D:\EA_LAB\_mt5_auto\EA_RUNNER_v1_locked.set` |
| GSMC set | `D:\EA_LAB\_mt5_auto\GSMC_run004_locked.set` |
| MG set | `D:\EA_LAB\_mt5_auto\MG_CHFJPY_v1_locked.set` |
| GSMC+MG basket plan | `D:\EA_LAB\BASKET_PLAN_GSMC_MG.md` |
| Basket corr script | `D:\EA_LAB\scripts\basket_oos_corr.ps1` |
| Runner+GSMC corr script | `D:\EA_LAB\scripts\basket_earun_gsmc_corr.ps1` |
| EA_CORE_V1 source of truth | `D:\EA_Project\CURRENT_BUILD\DOCS\EA_CORE_V1_SOURCE_OF_TRUTH.md` |
