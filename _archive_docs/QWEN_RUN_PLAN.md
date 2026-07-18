# QWEN RUN PLAN — batch optimize/rerun ยาวถึง พฤ. 2026-07-02

> ⚠️ canonical entry = `PROJECT_STATE.md`. ไฟล์นี้ = task queue สำหรับ **Qwen รันแทน** (ephemeral).
> Qwen = **RUN + LOG เท่านั้น ห้ามตัดสิน** (ห้ามสรุป keep/kill/overfit, ห้ามแก้ canonical docs, ห้าม git commit).
> Claude มาตัดสินผลวันพฤหัส. งานคือ "ป้อนคำสั่ง เก็บผล log" ให้เครื่องทำงานไม่ว่าง.

## กฎเหล็ก (อ่านก่อนทุกครั้ง)
1. **ปิด MT5/MT4 GUI ก่อนรันทุกครั้ง** (script จะ abort ถ้าเปิด). ใช้ `-Force` ได้ถ้าแน่ใจว่าไม่มี GUI.
2. ใช้ **เฉพาะ scripts ใน `D:\EA_LAB\scripts\`** (มี freeze-guard: ReserveCores/TimeoutSec/Portable ในตัว). ห้ามรัน tester มือ.
3. **error → log แล้วข้ามไป task ถัดไป.** retry ไม่เกิน 2 ครั้ง. ห้ามลบ/ย้ายไฟล์อะไรทั้งสิ้น.
4. ทุกผลลัพธ์ **append 1 บรรทัด** ลง `D:\EA_LAB\QWEN_RUN_LOG.md` (สร้างถ้ายังไม่มี) รูปแบบ:
   `| <date time> | TASK<n> | <expert>/<symbol>/<window> | <report path> | PF=? Net=? Trades=? | OK/ERR |`
5. report ทุกอันให้ `-ReportName` ขึ้นต้น `QWEN_` + เก็บ default ที่ script วางไว้. **อย่า judge ตัวเลข** แค่ copy ลง log.
6. window มาตรฐาน: **IS = 2023.01.01–2025.01.01 · OOS = 2025.01.01–2026.06.01 · FULL = 2023.01.01–2026.06.01**.
7. terminal: MT5 = `D:\Meta 5\terminal64.exe` (default) · ตัวที่ 2 ขนาน = เพิ่ม `-Portable` · MT4 = `D:\Meta4\terminal.exe`.
8. **Expert names** ดูตาราง "Expert Names" ใน `DEMO_DEPLOYMENT_PLAN.md`. ถ้า run error "expert not found" → `ls "<DataDir>\MQL5\Experts"` หาชื่อ .ex5 ที่ตรง แล้วใช้ชื่อนั้น.

---

## TASK 1 — RE-CONFIRM OOS ของ EA ที่ deploy แล้ว (ทำก่อน, คุ้มสุด, ปลอดภัยสุด)
> เหตุผล: กฎ "อย่าเชื่อ report เก่า — rerun ด้วย locked .set". ยืนยันเลข baseline ก่อน judge.
> แต่ละตัว: รัน **IS แล้ว OOS** (2 รัน) ด้วย `mt5_run.ps1`. Model 4 default; ถ้า **hang/timeout → รันซ้ำเป็น `-Model 2`** แล้ว log ว่า "M2 fallback".

คำสั่งแม่แบบ (เปลี่ยน 4 ค่า: Expert, Symbol, SetFile, ช่วงวัน):
```powershell
& D:\EA_LAB\scripts\mt5_run.ps1 -Expert "<EXPERT>" -Symbol <SYM> -Period <TF> `
  -FromDate <FROM> -ToDate <TO> -SetFile "<LOCKED_SET>" -Model 4 -TimeoutSec 2400 -Force `
  -ReportName QWEN_<TAG>_<IS|OOS>
```
รายการ (ทำทั้ง IS+OOS ทุกตัว):
| TAG | Expert | Sym/TF | locked .set |
|---|---|---|---|
| ST03rep | `EA_RUNNER_ST03` | GBPUSD H1 | `_vps_deploy\ST03_GBPUSD\ST03_GBPUSD_live_v1.set` |
| BRK55 | `EA_BREAKOUT_XAU` | XAUUSD H1 | `_vps_deploy\BRK_XAU_live_v3.set` |
| BRK8 | `EA_BREAKOUT_XAU` | XAUUSD H1 | `_vps_deploy\BRK_XAU_Bars8\BRKXAUH4_Bars8_demo_v1.set` |
| CBGBP | `(Boss)_LondonConsoBreakout_rev01` | GBPUSD H1 | `_vps_deploy\CB_GBP\CB_GBP_H1_live_v1.set` |
| NUII | `(NuiIndy) Dynamic RSI+ADX Style (4)` | EURUSD H1 | `_mt5_auto\NuiIndy_EURUSD_robust.set` |
| MACDg | `(ST) EA03 Count MACD v1` | GBPUSD H1 | `_mt5_auto\MACD_GBPUSD_locked.set` |
| MACDc | `(ST) EA03 Count MACD v1` | USDCAD H1 | `_mt5_auto\MACD_USDCAD_locked.set` |
| GR | `The Gold Reaper MT5_4.3_fix_@FundedMillionAiress` | XAUUSD H1 | `_mt5_auto\GoldReaper_cent_v1.set` |
| MG | `Matchagrid` | CHFJPY M15 | `_mt5_auto\MG_CHFJPY_v1_locked.set` |

→ 9 EA × 2 window = ~18 รัน. นี่คือชุดหลัก. เสร็จแล้วไป TASK 2.

---

## TASK 2 — GOLD REAPER optimize (backlog TASK 4)
> ต้องมี .set ที่มี **optimize range** (รูปแบบ MT5: `Name=val||min||step||max||Y`). ทำดังนี้:
1. copy `_mt5_auto\GoldReaper_cent_v1.set` → `_mt5_auto\GR_opt.set`
2. ใน `GR_opt.set` หา input ที่เป็น lot เริ่ม (เช่น `StartLots=` หรือ `Lots=`) แล้วแก้บรรทัดนั้นเป็นช่วง เช่น
   `StartLots=0.01||0.01||0.01||0.05||Y` (ถ้าหาชื่อไม่เจอ → log "GR param name unknown, skip TASK2" ข้ามไป)
3. รัน:
```powershell
& D:\EA_LAB\scripts\mt5_optimize.ps1 -Expert "The Gold Reaper MT5_4.3_fix_@FundedMillionAiress" `
  -Symbol XAUUSD -Period H1 -FromDate 2023.01.01 -ToDate 2026.06.01 `
  -SetFile "D:\EA_LAB\_mt5_auto\GR_opt.set" -Model 1 -Optimization 2 -TimeoutSec 7200 `
  -ReportName QWEN_GR_opt
```
4. parse: `& D:\EA_LAB\scripts\parse_opt_xml.ps1` (ดู param ของมันก่อนถ้าต้องชี้ไฟล์). log แค่ "เสร็จ + path". **อย่าเลือก param ที่ดีสุด** — Claude เลือกเอง.

---

## TASK 3 — ST03 framework coarse grid (EA_CORE STEP 3) — *เงื่อนไข*
> ทำ **เฉพาะถ้า** `EA_RUNNER_ST03` รันใน tester ได้ (TASK 1 ST03rep ผ่าน). ใช้ `optimize_loop.ps1` (ทำ IS+OOS ให้เอง).
> ต้องมี base .set ที่ใส่ range บน `InpTp3Pts / InpNearbyPip / InpLotRepeat / InpPendingMode`.
1. copy `_vps_deploy\ST03_GBPUSD\ST03_GBPUSD_live_v1.set` → `_mt5_auto\ST03_grid.set`
2. แก้ 4 บรรทัดเป็น range: `InpTp3Pts=50||30||10||120||Y` · `InpNearbyPip=100||50||50||150||Y` ·
   `InpLotRepeat=3||2||1||3||Y` · `InpPendingMode=2||2||1||3||Y` (ถ้าหาชื่อ input ไม่ตรง → log + skip)
3. รัน:
```powershell
& D:\EA_LAB\scripts\optimize_loop.ps1 -Expert "EA_RUNNER_ST03" -Symbol GBPUSD -Period H1 -Model 1 `
  -BaseSet "D:\EA_LAB\_mt5_auto\ST03_grid.set" -Code ST03GRID `
  -OptFrom 2023.01.01 -OptTo 2025.01.01 -OosFrom 2025.01.01 -OosTo 2026.06.01
```
4. log path ผลลัพธ์. **อย่า rank** — Claude rank ด้วย min(IS,OOS) วันพฤหัส.

---

## TASK 4 — MT4 gold-grid Phase 1 (backlog TASK 5, ถูก)
> อ่าน `MT4_GOLDGRID_RETEST_PLAN.md` เอาชื่อ Expert + .set ของ Elephant / Mammoth / Gold Stuff V7.
> รันแต่ละตัวบน XAUUSD, FULL window, เก็บ report (มี equity curve):
```powershell
& D:\EA_LAB\scripts\mt4_run.ps1 -Expert "<MT4_EXPERT>" -Symbol XAUUSD -Period H1 `
  -FromDate 2023.01.01 -ToDate 2026.06.01 -SetFile "<set ถ้ามี>" -Model 2 `
  -ReportName QWEN_GG_<name> -Force
```
log path ของแต่ละ report. **อย่าตัดสินว่า martingale/artifact** — Claude ดู equity curve เอง.

---

## LOOP จนถึงพฤหัส
ทำ TASK 1→4 ตามลำดับ. **เสร็จครบแล้ว** ถ้ายังไม่ถึงพฤหัส ให้วนทำ:
- **รอบ 2:** TASK 1 ซ้ำแต่เปลี่ยนเป็น **Model 2** ทุกตัว (เทียบ M4 vs M2 = วัด tight-TP artifact). TAG เติม `_M2`.
- **รอบ 3:** สำหรับ EA ที่ TASK 1 PF ดี (PF>1.5 ตาม log) → รัน OOS แยกเป็น 2 ครึ่ง (2025H1: 2025.01–2025.07 / 2025H2-26: 2025.07–2026.06) ดู stability. TAG เติม `_half1/_half2`.
- ถ้าไม่มีอะไรทำ → หยุด, เขียน `QWEN_RUN_LOG.md` บรรทัดสุดท้าย "QUEUE DRAINED, idle until Claude review".

## ส่งมอบให้ Claude (วันพฤหัส)
- `QWEN_RUN_LOG.md` = สรุปทุกรัน (Claude อ่านอันนี้ก่อน)
- report files ที่ script เก็บไว้ (path อยู่ใน log)
- **อย่า commit git** — Claude review + commit เอง (pre-commit hook จะรัน check_state)
