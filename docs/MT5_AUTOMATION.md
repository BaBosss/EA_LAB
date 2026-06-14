# MT5 AUTOMATION — headless backtest (2026-06-14)

> ตอบคำถาม "ให้ MT5 รันอัตโนมัติได้ไหม" = **ได้** ผ่าน headless config (.ini)
> แต่มีเงื่อนไขจริง (ด้านล่าง) — อ่านก่อนรัน

## สิ่งที่ทำได้ตอนนี้ (v1) — single-test อัตโนมัติ ✅
`scripts/mt5_run.ps1` สั่ง `terminal64.exe /config:<ini>` ให้:
- โหลด EA + symbol + ช่วงวันที่ + inputs จาก .set
- รัน single backtest (real ticks) แบบไม่มีหน้าจอ → เขียน HTML report → ปิด terminal เอง
- คืน path ของ report → ป้อนเข้า pipeline ที่มี (parse → score → MC) ได้เลย

`scripts/mt5_batch_shortlist.ps1` = วน IS+OOS ให้ shortlist .set ทั้ง 4 ตัวอัตโนมัติ

## ⚠️ เงื่อนไขที่ต้องมี (ไม่งั้นรันแล้วได้ report ว่าง)
| เงื่อนไข | สถานะ |
|---|---|
| **ปิด MT5 GUI ก่อน** (headless ชนกับ GUI ที่เปิดบน data folder เดียวกัน) | ตอนนี้ GUI เปิดอยู่ → script จะ abort ให้อัตโนมัติ |
| EA ต้อง compile อยู่ใน `MQL5\Experts` | ✅ ครบ (Boss-2 Adaptive Smart Grid, Boss-6 Pivot, MatchaGrid, Gold_SMC...) |
| Symbol ต้องมี history โหลดแล้ว | ต้องเช็ค (EURCAD/AUDCAD/AUDNZD/NZDUSD) |
| Terminal login broker ค้างไว้ (ดึง history ได้) | ใช้ login ที่เซฟใน terminal |

## วิธีใช้ (ตอนสะดวก)
1. ปิด MT5 GUI
2. `powershell -File D:\EA_LAB\scripts\mt5_batch_shortlist.ps1`  ← รัน IS+OOS ให้ 4 ตัว
3. `python D:\EA_LAB\scripts\run_pipeline.py D:\EA_LAB\ea_projects D:\EA_LAB\_mt5_auto\reports`  ← score
4. สั่ง Claude "วิ่ง analyst+reviewer" → robustness + รีวิว

→ นายไม่ต้องนั่งคลิกทีละ test เอง แค่ปิด MT5 แล้วสั่ง 1 บรรทัด (หรือให้ผมสั่งให้ตอน GUI ปิด)

## วงจรเต็มที่นายอยากได้ (optimize → select → single-test)
```
[optimize EA]  → [select robust pass] → [gen .set] → [single-test IS+OOS] → [score+MC] → [registry]
   v2 (ดูล่าง)        select_robust ✅      set_from_robust ✅   mt5_run ✅        pipeline ✅
```
ขั้น single-test เป็นต้นไป **อัตโนมัติครบแล้ว**

## ข้อจำกัด — headless OPTIMIZATION (v2, ยังไม่ทำ)
- MT5 **รัน** optimization headless ได้ (`Optimization=2` ใน ini) แต่ผลออกมาเป็น **.opt cache (binary)** ไม่ใช่ XML
- MT5 ไม่มีคำสั่ง export opt → XML แบบ headless สะอาดๆ (ปกติต้อง export มือใน GUI)
- ทางออก v2: เขียน `OnTester()` hook ใน EA ให้เขียนผลทุก pass ลงไฟล์ หรือ parser อ่าน .opt — เป็นงานเพิ่ม
- **ตอนนี้:** ใช้ optimization XML ที่นายมีอยู่แล้ว (22 batch ในคลัง) → select_robust → .set → auto single-test ก็ได้ candidate ครบโดยไม่ต้อง optimize ใหม่

## ไฟล์ที่เกี่ยวข้อง
- `scripts/mt5_run.ps1` — launcher 1 job (มี safety guard GUI)
- `scripts/mt5_batch_shortlist.ps1` — batch IS+OOS ให้ shortlist
- output → `_mt5_auto/reports/` + `_mt5_auto/ini/`
