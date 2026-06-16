# RESUME HERE — อัพเดท 2026-06-15 (session 8)

อ่านไฟล์นี้ก่อนเสมอเมื่อเปิด session ใหม่

---

## ถัดไปทันที (session ถัดไป)

### ลำดับงาน:

1. **ก — Matchagrid CHFJPY** ✅ COMPLETE → **CONDITIONALLY ROBUST / DEMO_READY**
   - Manual grid search: GridPoints 300→350 + LotStart 0.02→0.01 + StepAddLot 0.06→0.01
   - IS 2023-2026: PF=1.97 DD=18.01% Score=66 PASS; OOS 2020-2023: PF=2.08 DD=23.75% WATCH
   - MC bootstrap: PF5th=1.755, ruin=0.0% — edge ยืนยัน
   - Locked params: `MG_CHFJPY_v1_locked.set` · Verdict: `ea_projects/Matchagrid/CHFJPY/validated_v1/ROBUSTNESS_VERDICT.md`
   - Sizing caution: live DD อาจถึง 36-72% (grid multiplier 2-3×) → demo ≥3 เดือนก่อน live

2. **ข — GSMC revive** (optional, ถ้า Matchagrid ยังไม่พอ)
   - Set file ready: `GSMC_revive_opt.set` (wider range, LotMultiplier 1.0-1.3, full window 2020-2026)
   - รัน optimize_loop IS 2020-2023 OOS 2023-2026

3. **ค — template MEAN_REVERSION smoke** ✅ CODE DONE (session นี้)
   - MEAN_REVERSION (BB+RSI bounce) เพิ่มแล้ว, compile 0/0
   - SESSION filter บน BREAKOUT (InpBreakoutHourFrom/To UTC) เพิ่มแล้ว
   - ต้องสร้าง .set + optimize: EA_LabTemplate MR บน EURUSD หรือ XAUUSD H1

4. **ง — EAs smoke batch 1 COMPLETE (session 8)**
   - smoke_all.ps1 ทดสอบ 27 EAs → PASS: BaronGrid (PF=1.83 DD=4.06%), Immortal Gold (PF=2.64 DD=9.24%)
   - **BaronGrid** → OOS 2020-2023 PF=0.78 + full-window opt ไม่ robust → **REJECT**
   - **Immortal Gold** → OOS 2020-2023 PF=0.21 DD=230% BLOWUP (LONG-only martingale) → **REJECT**
   - **smoke_batch2.ps1** COMPLETE: 37 EAs จาก MQL5 EA\ + Quantum\ → PASS 2 ตัว:
     - **`Quantum\Quantum Speed`** EURUSD → IS PF=1.93 DD=7.66% (256t) PASS + OOS PF=1.55 DD=12.03% (206t) WATCH — **first non-martingale commercial EA with OOS edge!**
     - `rev_001_Smart_Money_EA` EURUSD → IS PF=2.07 DD=5.74% (38t) — too few trades, needs OOS
     - PORT 1 (CelestialWoodfire) REJECT PF=0.70. PORT 6 (GoldenEmber rev012) REJECT PF=0.68. All Boss EAs REJECT. All rev_00x mostly REJECT.
   - **Quantum Speed optimize_loop** running (IS: 2023-2026, OOS: 2020-2023)

5. **GSMC robustness** ✅ COMPLETE → **DISQUALIFIED**
   - Extended IS 2023-2026: PF=1.04 DD=33.5% / OOS 2020-2023: PF=0.90 DD=33.6% → ทั้งคู่ REJECT
   - MC bootstrap ruin=16.7% — ไม่มี edge จริง
   - Verdict: `ea_projects/Gold SMC continuous/portfolio/candidates/.../ROBUSTNESS_VERDICT.md` (Section 7)

---

## EA_LabTemplate (Phase 3a) — ✅ BREAKOUT entry เพิ่มแล้ว

EA chassis dropdown-mode ที่ `D:\EA_LAB\ea_template\` (git). compile 0/0.
- deploy: `& D:\EA_LAB\ea_template\deploy.ps1 -Compile` → `Experts\EALabTpl\` (data folder 9CA1)
- expert name: `EALabTpl\EA_LabTemplate`

### Dropdown axes ปัจจุบัน:
- `InpEntryStyle`: GRID_TREND_MA (0) / BREAKOUT (1) / **MEAN_REVERSION (2)** ← เพิ่ม session นี้
- `InpBreakoutBars`: lookback channel (default 20)
- `InpBreakoutConfirmBars`: 0=tick-level, 1+=close-confirmed (channel shifts past confirm window)
- `InpBreakoutHourFrom/To`: UTC session filter (0,0 = no filter) ← เพิ่ม session นี้
- `InpMR_BB_Period/Dev`: Bollinger Band params (MEAN_REVERSION) ← เพิ่ม session นี้
- `InpMR_RSI_Period/OB/OS`: RSI extreme levels ← เพิ่ม session นี้
- `InpMR_RequireBB`: require price at outer BB band (AND with RSI)
- `InpExitMode`: FIXED_TP / TRAIL / RUN_TREND / ATR_TP
- `InpSLMode`: NONE / FIXED_POINTS / MONEY / ATR / STRUCT_DONCHIAN / STRUCT_SR
- `InpTrendFilter`: NONE / ATR_EXPAND / MA_SLOPE
- `InpTradeDirection`: BOTH / LONG_ONLY / SHORT_ONLY
- `InpFirstLotMode`: FIXED / RISK
- `InpLotProgression`: NONE / LINEAR / MULTIPLIER / PLUS / LOG

### BREAKOUT findings (session 5):
- Bug found+fixed: channel anchor must use startShift=confirmN+1 (else close-confirm always fails)
- XAUUSD H1: IS PF 1.578 DD 2.68% RF 5.61 survivors 29/170 GOOD → OOS PF 0.80 DD 4.87% FAIL
  - Best params: BreakoutBars=40, Confirm=0 (tick-level), LONG_ONLY, ATR_EXPAND, SL=1.5×ATR, TP=5×ATR
  - Same regime-dependent pattern as GridTrendMA — bull regime only
- GBPJPY H1: 0 survivors plateau=NONE (no IS edge)
- EURUSD H1: 0 survivors plateau=NONE (PF 1.004 best)
- **Conclusion:** H1 Donchian whipsaws on forex. Session-specific breakout (LondonBO) is the right form.

---

## สถานะ .ex5 candidates (ทดสอบ session 5)

| EA | Pair | IS | OOS | Verdict |
|---|---|---|---|---|
| EA TREND V2 | EURUSD H1 | PF 1.20 DD 4.62% score 67 | PF 1.15 eq-DD 19.3% one-big-trade | ❌ REJECT (OOS one-big-trade) |
| EA TREND V2 | GBPUSD H1 | PF 1.26 DD 3.36% | PF 1.15 DD 31.28% | ❌ REJECT (OOS DD too high) |
| EA TREND V2 | USDJPY H1 | PF 1.18 DD 12.99% | PF 0.48 DD 86.95% | ❌ REJECT (OOS blow-up) |
| EA TREND V2 | XAUUSD/GBPJPY | PF 0.31/0.71 | — | ❌ REJECT (fixed pip sizing blow-up) |
| Multi-TF Trend | EURUSD H1 | PF 0.83 DD 64% | — | ❌ REJECT (blow-up) |
| HalfTrend_MTF | XAUUSD H1 | PF 1.05 DD 38% 8470t | — | ⏸ NEEDS LOT TUNING |
| LondonBO | GBPUSD H1 | PF 0.93 default | — | ⏸ NEEDS OPTIMIZE (inputs unknown) |

---

## สถานะ EA candidates (รวม)

| EA | Pair | ผล |
|---|---|---|
| GSMC (Gold SMC RiskCap) | XAUUSD | ❌ DISQUALIFIED — regime-dependent |
| **Matchagrid** | CHFJPY M15 | ✅ **CONDITIONALLY ROBUST** — PF 1.97 IS / 2.08 OOS, DD 18/24%, MC ruin=0% → DEMO_READY |
| EX197 Multi Group Scalping | GBPJPY | ❌ CONDITIONAL REJECT — OOS RF 1.30 < 1.50 |
| MooDeng Bot | USDCHF/EURUSD/EURGBP | ❌ REJECT |
| EA TREND V2 | EURUSD/GBPUSD | ❌ REJECT |
| HalfTrend_MTF_EA | XAUUSD H1/H4 | ❌ REJECT — overtrading (8470-10103 trades), DD 36-38% |
| Sentinel KMZ 2.5 | XAUUSD H1 | ❌ REJECT — PF 0.95, DD 93% |
| PivotProbabilityPro | XAU/EUR H1 | ❌ REJECT — PF 0.84 losing |
| BB Return MT5 EA V_7.40 | XAUUSD H1 | ❌ REJECT — 44 trades only (insufficient) |
| EA_LabTemplate BREAKOUT | XAUUSD | ⏸ IS only (regime-dependent) |
| EA_LabTemplate GridTrendMA | XAUUSD | ⏸ ผู้ใช้ optimize เองต่อ |
| **Immortal Gold** | XAUUSD H1 | ❌ REJECT — LONG-only martingale, OOS 2020-2023 PF=0.21 DD=230% BLOWUP |
| **BaronGrid** | EURUSD H1 | ❌ REJECT — OOS 2020-2023 PF=0.78, full-window opt gives 120 trades/6yr (too thin) |
| EA Among Us | EURUSD H1 | ❌ REJECT — no-SL martingale (Kmartin=1.5), risky structure |
| KNTPTT Grid Scalp Pro | EURUSD H1 | ⏸ WATCH IS — GridMultiplierStart=3, needs OOS test |
| **Quantum Speed** | EURUSD H1 | ❌ DISQUALIFIED — IS+OOS PASS on OHLC but Model=4 real-ticks: PF=1.13 trades=68 FAIL (tight 5-pip trail = OHLC artifact) |
| Smart_Money_EA | EURUSD H1 | ⏸ IS PF=2.07 DD=5.74% only 38 trades — OOS test pending |
| KNTPTT Grid Scalp Pro | EURUSD H1 | ⏸ IS PF=1.60 DD=12.5% — OOS test pending |

---

## Gate / Pipeline

- **Robust gate:** PF≥1.20, DD≤20%, RF≥1.50, Trades≥100
- **Loop:** `optimize_loop.ps1` → `select_robust_pass.py` → IS+OOS mt5_run → score
- **Plateau:** GOOD≥20 / WEAK 5-19 / THIN 1-4 / NONE=stop
- Grid/hedge EA: ใช้ report DD × 2-3 สำหรับ sizing

## คำสั่งหลัก

```powershell
# optimize loop
& D:\EA_LAB\scripts\optimize_loop.ps1 -Expert "EA_NAME" -Symbol XXXX -BaseSet "path\to.set" -Code CODE -OptFrom 2023.01.01 -OptTo 2026.06.01 -OosFrom 2020.01.01 -OosTo 2023.01.01

# single test
& D:\EA_LAB\scripts\mt5_run.ps1 -Expert "EA_NAME" -Symbol XXXX -Model 1 -FromDate 2024.01.01 -ToDate 2026.06.01 -SetFile "path\to.set" -ReportName "label"

# optimize (แยก)
& D:\EA_LAB\scripts\mt5_optimize.ps1 -Expert "EA_NAME" -Symbol XXXX -Model 1 -FromDate 2023.01.01 -ToDate 2026.06.01 -SetFile "path.set" -ReportName "OPT_label"

# ดูผล
python D:\EA_LAB\scripts\_show_rows.py "keyword"

# parse + score
python C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts\parse_mt5_report.py "report.htm" > parsed.json
python D:\EA_LAB\scripts\score_backtest.py "parsed.json" --strategy trend
```

## .set files ที่มี

```
_mt5_auto/BREAKOUT_opt_XAU.set           XAUUSD optimize ranges
_mt5_auto/BREAKOUT_XAU_robust.set        XAUUSD robust pick (BreakoutBars=40 LONG_ONLY ATR_EXPAND)
_mt5_auto/BREAKOUT_opt_GBPJPY.set        GBPJPY (ทดสอบแล้ว — ไม่มี edge)
_mt5_auto/BREAKOUT_opt_EURUSD.set        EURUSD (ทดสอบแล้ว — ไม่มี edge)
_mt5_auto/BREAKOUT_smoke_XAU.set         XAUUSD default smoke (Confirm=1)
_mt5_auto/MooDengv1_robust.set           USDCHF
_mt5_auto/LABTPL_XAU3_robust.set         XAUUSD single-trade no-filter
_mt5_auto/LABTPL_XAU4_robust.set         XAUUSD single-trade ATR filter
_mt5_auto/LABTPL_XAU5_robust.set         XAUUSD single-trade LONG-only + ATR filter
ea_template/sets/LabTpl_XAU_v5_long.set  template set สำหรับ XAUUSD LONG-only
```

## Important notes

- **MT5 .set optimize format:** `param=current||start||step||stop||Y` (NOT start||stop||step!)
- **InpBreakoutConfirmBars=1:** channel anchors at shift=2 (else close[1]>channel impossible)
- **InpCloseAllWhenDDPct:** ตั้ง 50 ใน backtest (25 halt EA กลางทาง)
- **EA TREND V2:** ใช้ pip sizing คงที่ — blows up บน XAUUSD/GBPJPY (volatile pairs)
- **Expert names:** root data folder EAs = bare name (e.g. "LondonBO"), subfolders = "folder\name" (e.g. "EALabTpl\EA_LabTemplate")
