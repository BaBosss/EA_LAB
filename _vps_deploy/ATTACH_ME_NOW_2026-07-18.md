# ✅ ATTACH CHECKLIST — เหลือจริงแค่ 3 รายการ (สถานะจริงจาก DEPLOYMENTS.csv 2026-07-18)

> ข่าวดี: bundle ส่วนใหญ่ attach ไปแล้ว (SuperTrend 990020 · MacdDiv 999094 · IchiADX ×4 ·
> Wave5 XAU/XAG · BRK USDJPY/US30 · SMCSTO 991070 = ACTIVE ครบใน CSV). เหลือค้าง 3 ชุดข้างล่าง.
> วิธี attach เหมือนกันทุกตัว: copy .ex5 → `MQL5\Experts` (ผ่าน rclone pipe เดิม หรือ copy-paste
> ทาง RDP ก็ได้) → refresh Navigator → เปิดชาร์ต symbol+TF ตามตาราง → ลาก EA ลง → Load .set
> → เช็ค AutoTrading เขียว + หน้ายิ้ม → เสร็จแล้วบอก Claude วันที่ attach เพื่อลง CSV + ตั้ง judge

## 1) WAVE5 USDJPY — ง่ายสุด ทำก่อน (~2 นาที)
- โฟลเดอร์: `_vps_deploy/WAVE5_USDJPY/`
- บัญชี: **463666728 (Demo bundle 10)** — EA ตัวเดียวกับ Wave5 XAU/XAG ที่รันอยู่แล้ว (แค่เพิ่มชาร์ต)
- ชาร์ต: **USDJPYm H1** · Magic: **990303** · Set: `WAVE5_USDJPY_H1_demo_v1.set`
- เช็คหลังโหลด set: EntryFib=38.2 · Wave3MinMult=1.618 · Magic=990303

## 2) PAIRSPREAD STAT-ARB — diversifier class ใหม่ (~3 นาที)
- โฟลเดอร์: `_vps_deploy/PAIRSPREAD_STATARB/`
- บัญชี: **463666728 (Demo bundle 10)** · DEMO ONLY (CANDIDATE_WEAK เก็บ data)
- ชาร์ต: **EURUSDm H4** (EA ดึง GBPUSD เองภายใน — ต้องมีทั้ง 2 symbol ใน Market Watch)
- Magic: **990984** · Set: `PAIRSPREAD_EURGBP_H4_demo_v1.set`
- ⚠️ S6: broker suffix ต้องตรงทั้ง EURUSD และ GBPUSD (เช็ค input SymbolB ให้ตรง suffix m)

## 3) MACROGATE + demo leg — ชุดเดียวทำตาม runbook (มีขั้น rclone เพิ่ม 1 ไฟล์)
- ทำตาม **`_vps_deploy/MACROGATE/ATTACH_RUNBOOK.md`** ทีละขั้น (ครบจบในไฟล์เดียว):
  STEP 1 เพิ่ม `EA_LAB_mris_regime.csv` เข้า rclone pipe เดิมของ NewsGuard (lab→VPS)
  → STEP 2 attach `Boss_12_Breakout.ex5` (MACROGATE_DEMOLEG) **Magic 990120**
  → STEP 3 attach `(Boss)_MacroGate.ex5` (watchdog) ตั้ง `InpMagicsCsv=990120`
  → เช็ค Experts log เห็น `gate ON magic=990120` ตอน regime = RISK_OFF/STRESS

## ⛔ ห้าม attach (bundle เก่าที่ obsolete แล้ว — อยู่ในโฟลเดอร์เดียวกัน อย่าหยิบผิด)
- `ST03_GBPUSD/` — ตระกูล ST03 ถอดจากเงินจริงแล้ว 2026-07-18 (STRUCTURAL no-edge)
- `CB_EUR/` — DROPPED 2026-06-25 (no durable edge)
- `.set` ลอยที่ root (`BRK_XAU_live_v2/v3`, `ST_XAU_H4_live_v1`, `KAUERMAN_buyonly_live`) — เวอร์ชันเก่า/รอตัดสิน อย่าใช้โดยไม่ถาม

## NewsGuard + SnapshotExporter (ถ้ายังไม่ได้ทำ)
- คู่มือเต็ม: `ea_projects/(Boss)_NewsGuard/VPS_TRANSPORT_AND_ATTACH.md` (MacroGate STEP 1 ใช้ pipe เดียวกันนี้)
