# MACROGATE — ชุดพร้อมใช้ (copy โฟลเดอร์นี้ขึ้น VPS อย่างเดียวจบ)

**ทั้งหมดนี้ = DEMO เท่านั้น** · บัญชี **463666728 (Demo bundle 10)** ตัวเดียวกับ Wave5/MacdDiv
ไฟล์ในโฟลเดอร์นี้ครบแล้ว 3 ไฟล์: EA 2 ตัว + regime CSV (ตัวที่ runbook เดิมพูดถึง)

## ขั้นที่ 1 — วางไฟล์ (2 นาที)
1. copy `Boss_12_Breakout.ex5` + `(Boss)_MacroGate.ex5` → `MQL5\Experts\` ของ terminal
   Demo bundle 10 → คลิกขวา Navigator → Refresh
2. copy `EA_LAB_mris_regime.csv` → **Common\Files**:
   ใน MT5: File → Open Data Folder → ถอยขึ้น 1 ชั้น → เข้าโฟลเดอร์ `Common` → `Files` → วางไฟล์

## ขั้นที่ 2 — attach ขาเทรด (demo leg)
- เปิดชาร์ต **USDJPYm H1** → ลาก `Boss_12_Breakout` ลง
- Inputs: แก้ตัวเดียว **`_0_Magic` = 990120** (ที่เหลือ default ทั้งหมด — ห้ามแก้)
- กด Save ใน tab Inputs เก็บเป็น `Boss12_Breakout_USDJPY_H1_demoleg.set` แล้ว OK
- Algo Trading ต้องเขียว

## ขั้นที่ 3 — attach ตัวเฝ้า (watchdog)
- เปิดชาร์ตอะไรก็ได้อีก 1 ชาร์ต (เช่น EURUSDm H1 — มันไม่เทรด แค่เฝ้า) → ลาก `(Boss)_MacroGate` ลง
- Inputs แก้ 3 ตัว:
  - **`InpMagicsCsv` = `990120`**
  - **`InpStaleMaxHours` = `200`**
  - **`InpRowStaleMaxHours` = `200`**
  (ที่เหลือ default) → OK
- เช็ค tab Experts ต้องเห็นบรรทัด `regime loaded: N row(s)` และ `guard carry magic=990120`

## ขั้นที่ 4 — งานประจำ (สำคัญ)
ยังไม่มีท่อส่งไฟล์อัตโนมัติ → **ทุกครั้งที่ RDP เข้า VPS (อย่างน้อยสัปดาห์ละครั้ง) copy
`D:\EA_LAB\portfolio\EA_LAB_mris_regime.csv` เวอร์ชันล่าสุดจากเครื่องแลป ไปทับที่ Common\Files เดิม**
ถ้าลืม: ไฟล์เก่าเกิน 200 ชม. → guard ขึ้น INACTIVE เฉยๆ (ปลอดภัย ไม่บล็อกมั่ว) ไม่พังอะไร
(ท่อ rclone อัตโนมัติ = งานอนาคต รวมกับชุด NewsGuard)

## เสร็จแล้ว
บอก Claude ว่า attach วันไหน → ลงทะเบียน magic 990120 ใน DEPLOYMENTS.csv ให้
