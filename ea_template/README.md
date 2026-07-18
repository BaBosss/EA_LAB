# EA_LabTemplate — dropdown-mode EA chassis

> ⚠️ **DOC STALE-STAMP 2026-07-18:** ข้อความ "tester-only / Recovery-Hedge stub / ยังไม่ demo-live" ด้านล่าง = สถานะเก่า. ปัจจุบัน V2 มี Recovery/Hedge/Stack ใช้จริง + demo bundles staged (`_vps_deploy/`). อ่านสถานะจริงจาก PROJECT_STATE.md · การแก้เนื้อหาเต็มรอ ORDER-130 follow-up.

Standalone MQL5 EA สำหรับ EA_LAB funnel. เสียบ entry หลายแบบเข้า chassis เดียว
ที่ใช้ MM / Exit / Risk ร่วมกัน → ห่อ strategy ใหม่ให้ backtest+optimize ได้เร็วและสม่ำเสมอ.
**Phase 3a: รันใน Strategy Tester เท่านั้น** (ยังไม่ต่อ demo/live). built-in indicator เท่านั้น (iMA/iATR) เพื่อ backtest ง่าย.

## โครงสร้าง
```
EA_LabTemplate.mq5        เจ้าของ include order + เลือก mode + OnInit/OnTick
modules/
  Inputs.mqh              enum dropdown ทุกแกน + param แต่ละ mode + risk inputs
  Indicators.mqh          iMA / iATR / iHighest / iLowest (built-in)
  Execution.mqh           CTrade — จุดเดียวที่ส่งออเดอร์ (InpDryRun guard)
  RiskControl.mqh         hard-kill DD + caps ปรับได้ + สถิติ adherence
  MoneyManagement.mqh     ไม้แรก FIXED/RISK · ไม้ถัดไป NONE/LINEAR/MULTIPLIER/PLUS/LOG
  ExitManager.mqh         TP/SL/trail: FIXED/MONEY/ATR/RUN_TREND + SL โครงสร้าง Donchian/SR
  Recovery.mqh            enum NONE/LIGHT/.. (gated; NONE active เฟสนี้)
  Hedge.mqh Basket.mqh    gated OFF stub
  entries/
    IEntry.mqh            *** hybrid seam *** EntrySignal (field ตรง core StrategySignalResult)
    Entry_GridTrendMA.mqh entry แรก: เทรนด์ MA cross (signal-only; chassis ทำ grid)
```

## Dropdown (เลือกโครงสร้าง → optimize ข้าม mode เร็ว, param ปรับต่อได้)
- `InpEntryStyle` GRID_TREND_MA
- `InpExitMode` FIXED_TP / TRAIL / RUN_TREND / ATR_TP
- `InpSLMode` NONE / FIXED_POINTS / MONEY / ATR / STRUCT_DONCHIAN / STRUCT_SR
- `InpFirstLotMode` FIXED / RISK · `InpLotProgression` NONE / LINEAR / MULTIPLIER / PLUS / LOG
- `InpRecoveryMode` NONE / LIGHT / ADAPTIVE / AGGRESSIVE · `InpHedgeMode` OFF

## Risk control (3 ชั้น)
1. **Hard kill**: `InpCloseAllWhenDDPct` (def 25) — DD ถึงเพดาน → ปิดหมด + halt
2. **Caps ปรับ/opt ได้**: `InpMaxLot` 0.20 · `InpMaxDepositLoadPct` 30 · `InpMaxRecoverySteps` 3 · `InpRecoveryMultMax` 1.3
3. **Adherence** → ป้อนคะแนน live-suitability (RiskControl ใน DeployScore) ทีหลัง

## ใช้งาน
```powershell
& D:\EA_LAB\ea_template\deploy.ps1 -Compile      # junction เข้า MQL5\Experts + compile
# smoke backtest (ปิด MT5 GUI ก่อน):
& D:\EA_LAB\scripts\mt5_run.ps1 -Expert "EALabTpl\EA_LabTemplate" -Symbol EURUSD `
    -Model 1 -FromDate 2024.01.01 -ToDate 2026.06.01 -ReportName LabTpl_smoke
# เก็บผลเข้า RUN_LOG:
& D:\EA_LAB\scripts\fetch_report.ps1 -Mode single
# optimize:
& D:\EA_LAB\scripts\optimize_loop.ps1 -Expert "EALabTpl\EA_LabTemplate" -Symbol EURUSD -Code LABTPL ...
```
Expert name สำหรับ tester = `EALabTpl\EA_LabTemplate`

## นอกขอบเขตเฟสนี้
Recovery/Hedge/Basket เต็ม · entry เพิ่ม (Breakout/Swing/MeanRev/GSMC) · demo/live + safety review · ยก Entry_* เข้า EA_CORE_V1 เป็น StrategySignal_v2
