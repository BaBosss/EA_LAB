# RESUME HERE — อัพเดท 2026-06-15 (session 5)

อ่านไฟล์นี้ก่อนเสมอเมื่อเปิด session ใหม่

---

## ถัดไปทันที (session ถัดไป)

### ลำดับงาน:

1. **ก — ทดสอบ .ex5 candidates ต่อ** (LondonBO ยังไม่ optimize)
   - `LondonBO.ex5` — ต้องเปิด MT5 GUI → ดู Inputs tab → จดชื่อ params → ทำ .set → optimize_loop
   - หรือลอง GBPJPY / EURUSD / USDJPY time-based smoke ก่อน (London open = 07:00-10:00 GMT)
   - `HalfTrend_MTF_EA.ex5` — อาจมี edge ถ้า reduce lot + ปรับ timeframe (M15 หรือ H4)
   - ยัง: `Sentinel KMZ_2.5_fix MT5.ex5`, `PivotProbabilityPro.ex5`

2. **ข — GSMC robustness (Monte Carlo)** — GSMC ยังรอ Monte Carlo / WF pass
   - ใช้ robustness-validator skill กับ GSMC (portfolio candidate #1)
   - ต้องมี IS+OOS report + set file ก่อน (มีแล้วจาก session ก่อน)

3. **ค — template EntryStyle ถัดไป** — BREAKOUT ทดสอบแล้ว ไม่มี edge บน forex H1
   - พิจารณา MEAN_REVERSION entry (Bollinger band bounce หรือ RSI extreme)
   - หรือ SESSION filter บน BREAKOUT (เพิ่ม InpBreakoutHourFrom/To)

---

## EA_LabTemplate (Phase 3a) — ✅ BREAKOUT entry เพิ่มแล้ว

EA chassis dropdown-mode ที่ `D:\EA_LAB\ea_template\` (git). compile 0/0.
- deploy: `& D:\EA_LAB\ea_template\deploy.ps1 -Compile` → `Experts\EALabTpl\` (data folder 9CA1)
- expert name: `EALabTpl\EA_LabTemplate`

### Dropdown axes ปัจจุบัน:
- `InpEntryStyle`: GRID_TREND_MA (0) / **BREAKOUT (1)** ← เพิ่ม session นี้
- `InpBreakoutBars`: lookback channel (default 20)
- `InpBreakoutConfirmBars`: 0=tick-level, 1+=close-confirmed (channel shifts past confirm window)
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
| GSMC (Gold SMC RiskCap) | XAUUSD | ✅ PORTFOLIO_CANDIDATE #1 (รอ Monte Carlo) |
| EX197 Multi Group Scalping | GBPJPY | ❌ CONDITIONAL REJECT — OOS RF 1.30 < 1.50 |
| MooDeng Bot | USDCHF/EURUSD/EURGBP | ❌ REJECT |
| EA TREND V2 | EURUSD/GBPUSD | ❌ REJECT |
| EA_LabTemplate BREAKOUT | XAUUSD | ⏸ IS only (regime-dependent) |
| EA_LabTemplate GridTrendMA | XAUUSD | ⏸ ผู้ใช้ optimize เองต่อ |

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
