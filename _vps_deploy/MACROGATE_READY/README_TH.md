# MACROGATE — ชุดพร้อมใช้บน VPS

**ทั้งหมดนี้ = DEMO เท่านั้น** · บัญชี **463666728 (Demo bundle 10)** ตัวเดียวกับ Wave5/MacdDiv

## ขั้นที่ 1 — วาง EA / ไฟล์
1. copy `Boss_12_Breakout.ex5` + `(Boss)_MacroGate.ex5` → `MQL5\Experts\` ของ terminal Demo bundle 10
2. คลิกขวา Navigator → Refresh
3. `EA_LAB_mris_regime.csv` ต้องอยู่ใน **Common\Files** และสด

## ขั้นที่ 2 — attach ขาเทรด (demo leg)
- เปิดชาร์ต **USDJPYm H1** → ลาก `Boss_12_Breakout` ลง
- Inputs: แก้ตัวเดียว **`_0_Magic` = `990120`** (ที่เหลือ default ทั้งหมด — ห้ามแก้)
- กด Save ใน tab Inputs เก็บเป็น `Boss12_Breakout_USDJPY_H1_demoleg.set` แล้ว OK
- Algo Trading ต้องเขียว

## ขั้นที่ 3 — attach ตัวเฝ้า (watchdog)
- เปิดชาร์ตอะไรก็ได้อีก 1 ชาร์ต → ลาก `(Boss)_MacroGate` ลง
- Inputs ที่ติดตั้ง/อนุมัติอยู่:
  - **`InpMagicsCsv` = `990120`**
  - **`InpStaleMaxHours` = `200`**
  - **`InpRowStaleMaxHours` = `200`**
- ที่เหลือใช้ค่าที่อนุมัติอยู่เดิม; งาน transport นี้ไม่เปลี่ยน risk semantics
- เช็ค Experts ต้องเห็น `regime loaded: N row(s)` และ `guard carry magic=990120`

## ขั้นที่ 4 — งานประจำ / Guard Feed อัตโนมัติ
ก่อน rollout VPS worker รุ่นนี้ วิธี **AS-DEPLOYED** ยังเป็น manual-weekly ตามเดิม
โดยใช้ `InpStaleMaxHours=200` + `InpRowStaleMaxHours=200`

เมื่อ rollout ให้เอา **ทั้ง** `pull_news.cmd` และ `pull_guard_feeds.ps1` จาก accepted commit
ไปไว้ใน VPS worker directory เดียวกัน แล้วคง scheduled task เดิมให้เรียก `pull_news.cmd`
ตัว worker จะดึง/validate ทั้ง `EA_LAB_news_week.csv` และ `EA_LAB_mris_regime.csv`
ก่อน replace เข้า `Common\Files`; ไฟล์เสีย/หาย/เก่าจะไม่ทับ last-good copy

หลังยืนยัน `C:\rclone\logs\pull_guard_feeds.log` มี `guard feed pull COMPLETE`
และสองไฟล์ใน `Common\Files` สดแล้ว **ไม่ต้อง RDP มา copy regime CSV รายสัปดาห์อีก**
manual copy ใช้เฉพาะ emergency fallback เท่านั้น

## เสร็จแล้ว
บันทึก attach/deployment ตาม `portfolio/DEPLOYMENTS.csv`; automation นี้ไม่ใช่การอนุมัติ LIVE
และไม่เปลี่ยน risk/default ของ MacroGate
