# RESUME HERE — อัพเดท 2026-06-15 (session 4)

อ่านไฟล์นี้ก่อนเสมอเมื่อเปิด session ใหม่

---

## ถัดไปทันที (session ถัดไป)

### ลำดับงาน:
1. **ค — เพิ่ม EntryStyle BREAKOUT ใน EA_LabTemplate** (session ถัดไปทำก่อน)
   - เพิ่ม `ENTRY_BREAKOUT` enum ใน `Inputs.mqh`
   - สร้าง `Entry_Breakout.mqh` ใน `ea_template/modules/entries/`
   - Signal: breakout จาก high/low ย้อนหลัง N แท่ง (Donchian-style, built-in iHighest/iLowest)
   - params: InpBreakoutBars, InpBreakoutConfirmBars, ใช้ร่วมกับ ATR filter + direction bias ที่มีแล้ว
   - deploy -Compile → optimize XAUUSD/GBPJPY

2. **ก — ทดสอบ .ex5 EA candidates** สำหรับ EA #2
   - ดู Expert path จาก MT5: `D:\Meta 5\MQL5\Experts\`
   - `LondonBO.ex5` — London Breakout (เริ่มก่อน)
   - `HalfTrend_MTF_EA.ex5` — trend following MTF
   - `Multi-Timeframe Trend Following.ex5`
   - `EA TREND V2.ex5`
   - `Sentinel KMZ_2.5_fix MT5.ex5`
   - `PivotProbabilityPro.ex5`
   - **Eurusd All TF.xml** (WEAK PF 4.16 DD 6% 889 trades) ใน `D:\Forex\30_OPTIMIZATION\OLD_Report\` — ไม่รู้ EA ไหน ต้องหาก่อน

3. **GridTrendMA XAUUSD** — ผู้ใช้จะ optimize เองต่อ (อย่าแตะ)

---

## EA_LabTemplate (Phase 3a) — ✅ ใช้งานได้ + อัพเดท filter แล้ว

EA chassis dropdown-mode ที่ `D:\EA_LAB\ea_template\` (git). compile 0/0.
- deploy: `& D:\EA_LAB\ea_template\deploy.ps1 -Compile` → `Experts\EALabTpl\` (data folder 9CA1)
- expert name: `EALabTpl\EA_LabTemplate`

### Dropdown axes ปัจจุบัน:
- `InpEntryStyle`: GRID_TREND_MA (เดียว) → **ต้องเพิ่ม BREAKOUT**
- `InpExitMode`: FIXED_TP / TRAIL / RUN_TREND / ATR_TP
- `InpSLMode`: NONE / FIXED_POINTS / MONEY / ATR / STRUCT_DONCHIAN / STRUCT_SR
- `InpTrendFilter`: NONE / ATR_EXPAND / MA_SLOPE ← **เพิ่มแล้ว session นี้**
- `InpTradeDirection`: BOTH / LONG_ONLY / SHORT_ONLY ← **เพิ่มแล้ว session นี้**
- `InpFirstLotMode`: FIXED / RISK
- `InpLotProgression`: NONE / LINEAR / MULTIPLIER / PLUS / LOG
- `InpRecoveryMode`: NONE / LIGHT / ADAPTIVE / AGGRESSIVE (stubs)

### Findings GridTrendMA:
- EURUSD H1: ไม่มี edge (PF 0.86 ทุก combo)
- XAUUSD H1: regime-dependent — IS LONG-only+filter: PF 2.26 RF 2.59 GOOD, OOS fail
- Hard kill `InpCloseAllWhenDDPct`: ตั้ง 50 ใน backtest (25 halt EA กลางทาง)
- รายละเอียด: `memory/ea-lab-template.md`

---

## สถานะ EA candidates

| EA | Pair | ผล |
|---|---|---|
| GSMC (Gold SMC RiskCap) | XAUUSD | ✅ PORTFOLIO_CANDIDATE #1 |
| EX197 Multi Group Scalping | GBPJPY | ❌ CONDITIONAL REJECT — OOS RF 1.30 < 1.50 |
| MooDeng Bot | USDCHF | ❌ REJECT — OOS PF 0.94, DD 80% |
| MooDeng Bot | EURUSD | ❌ REJECT — OOS PF 0.16, DD 71.8% |
| MooDeng Bot | EURGBP | ❌ REJECT — OOS PF 0.10, DD 78.1% |
| EA_LabTemplate GridTrendMA | XAUUSD | ⏸ ผู้ใช้ optimize เองต่อ |

---

## Gate / Pipeline

- **Robust gate:** PF≥1.20, DD≤20%, RF≥1.50, Trades≥100
- **Loop:** `optimize_loop.ps1` → `select_robust_pass.py` → IS+OOS mt5_run → score
- **Plateau:** GOOD≥20 / WEAK 5-19 / THIN 1-4 / NONE=stop
- Grid/hedge EA: ใช้ report DD × 2-3 สำหรับ sizing

## คำสั่งหลัก

```powershell
# optimize loop (IS=ใหม่กว่า, OOS=เก่ากว่า)
& D:\EA_LAB\scripts\optimize_loop.ps1 -Expert "EA_NAME" -Symbol XXXX -BaseSet "path\to.set" -Code CODE -OptFrom 2023.01.01 -OptTo 2026.06.01 -OosFrom 2020.01.01 -OosTo 2023.01.01

# single test
& D:\EA_LAB\scripts\mt5_run.ps1 -Expert "EA_NAME" -Symbol XXXX -Model 1 -FromDate 2024.01.01 -ToDate 2026.06.01 -SetFile "path\to.set" -ReportName "label"

# ดูผล
python D:\EA_LAB\scripts\_show_rows.py "keyword"
```

## .set files ที่มี

```
_mt5_auto/MooDengv1_robust.set           USDCHF
_mt5_auto/MooDeng_EURUSD_robust.set      EURUSD
_mt5_auto/MooDeng_EURGBP_robust.set      EURGBP
_mt5_auto/LABTPL_XAU3_robust.set         XAUUSD single-trade no-filter
_mt5_auto/LABTPL_XAU4_robust.set         XAUUSD single-trade ATR filter
_mt5_auto/LABTPL_XAU5_robust.set         XAUUSD single-trade LONG-only + ATR filter
ea_template/sets/LabTpl_XAU_v5_long.set  template set สำหรับ XAUUSD LONG-only
```

## GitHub private repo — ยังไม่เสร็จ รันเอง:

```
gh repo create EA-Lab --private --description "MT5 EA platform"
cd D:\EA_LAB && git remote add origin https://github.com/<username>/EA-Lab.git && git push -u origin master
```
