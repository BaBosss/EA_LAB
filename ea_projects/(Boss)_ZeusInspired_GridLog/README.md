# (Boss) ZeusInspired GridLog — standalone project home  ⏳ MOVE PENDING

> **สถานะ: home จองไว้แล้ว แต่ยังไม่ย้ายไฟล์** (2026-07-08).
> source ตัวจริงยังอยู่ `D:\EA_Project\CURRENT_BUILD\TEMPLATE\` และ **ยังเทสอยู่** (ข้อมูลยังเปลี่ยน) →
> อย่าก็อปมาตอนนี้ (จะได้ snapshot เก่า). ย้ายจริงเมื่อ session ที่ทำ ZeusInspired ถึง checkpoint.
> canonical entry = `PROJECT_STATE.md`.

- **Chain:** `EA_ZEUSINSPIRED_GRIDLOG_20260703_01` · **Magic** 990101 (GridLean) / 990102 (TightLean) · standalone Boss EA
- **Origin:** inspired by observed BEHAVIOR of Zeus Gold Hedge V1.2 (closed third-party) — grid + LOG lot, run 2 instances @ different Magic/.set เพื่อ diversify ระดับ portfolio. NOT a clone.

## ✅ MOVE CHECKLIST (ทำโดย session เจ้าของงาน เมื่อเทสจบ checkpoint)
ทำแบบเดียวกับ RSI_MR_GridLog (commit `3436b2ad` เป็นแม่แบบ):

1. **copy source สุดท้าย** จาก `D:\EA_Project\CURRENT_BUILD\TEMPLATE\` เข้าที่นี่:
   - `(Boss)_ZeusInspired_GridLog_rev01.mq5` → โฟลเดอร์นี้ (working source)
   - `.ex5` ที่ compile ล่าสุด → โฟลเดอร์นี้ (gitignored, ไม่เข้า git แต่เก็บ binary ไว้)
   - `ZeusInspired_*.set` (12 ไฟล์: AUDJPY/AUDUSD/EURCAD lot-variants + V1/V2/V3 + Lean) → `set_files\`
   - report .htm ที่ validate แล้ว → `reports\`
2. **ลบออกจากคลัง** (ไฟล์นี้ tracked ใน git ของ `D:\EA_Project` — ไม่ใช่ orphan เหมือน RSI_MR):
   ```
   cd /d/EA_Project && git rm "CURRENT_BUILD/TEMPLATE/(Boss)_ZeusInspired_GridLog_rev01.mq5" \
     "CURRENT_BUILD/TEMPLATE/ZeusInspired_"*.set
   git commit -m "[claude] ZeusInspired moved out of archive -> EA_LAB\ea_projects (see EA_LAB commit)"
   ```
3. **compile ต่อจากนี้ที่นี่** (EA_LAB) — ห้ามพ่น .ex5 กลับเข้า `D:\EA_Project` archive อีก (guide §1).
4. **อัปเดต path** ที่อ้าง `EA_Project\...\TEMPLATE\(Boss)_ZeusInspired` ใน scorecard/PROJECT_STATE → ชี้มาที่นี่.
5. commit ฝั่ง EA_LAB (source .mq5 + set_files + reports + README นี้), แล้วลบบรรทัด "MOVE PENDING" ออกจากหัว README.

## Build / recompile (หลังย้ายแล้ว)
```powershell
& "D:\Meta 5\metaeditor64.exe" /compile:"D:\EA_LAB\ea_projects\(Boss)_ZeusInspired_GridLog\(Boss)_ZeusInspired_GridLog_rev01.mq5"
```
Backtest via `D:\EA_LAB\scripts\mt5_run.ps1` (ปิด MT5 GUI ก่อน).
