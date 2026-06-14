# RESUME HERE — เปิด session ใหม่อ่านไฟล์นี้ก่อน (2026-06-14)

## อ่านตามลำดับ
1. `D:\EA_LAB\PLATFORM_INDEX.md` — แผนที่ทุกราก/โฟลเดอร์
2. `D:\EA_LAB\PROJECT_STATUS.md` — สถานะ/milestone/ขั้นตอนใช้งาน
3. `D:\EA_LAB\RUN_REGISTRY.md` — ผล backtest ทั้งหมด (auto)

## ล่าสุด (resolved 2026-06-14)
- **optimize loop เต็มสาย CONFIRMED ทำงาน** — headless optimize -> XML ได้จริง (Optimization=2, เขียนไป data folder เหมือน single-test) · `optimize_loop.ps1` = 1 คำสั่งจบ (optimize->robust->set->single-test->score)
- robust selector แก้แล้ว: **trade floor >=100** ตัด fluke PF สูงเทรดน้อย
- **EURCAD grid: IS PASS (PF 3.9/113tr) แต่ OOS REJECT (PF 0.83 ขาดทุน, DD 45%)** = grid overfit ยืนยัน แม้ provenance สะอาด -> **เลิกตาม grid family**
- **EA validated จริง = GSMC (Gold SMC) ตัวเดียว** -> ต้องการ non-grid EA เพิ่ม (mean-reversion/trend)
- next: เอา optimize_loop ไปใช้กับ EA แบบ non-grid (เทรดเยอะ) เช่น GSMC, trend EAs -> หา candidate ที่ผ่าน OOS จริง

## สถานะสั้นๆ
- automation pipeline ครบ + MT5 headless single-test **พิสูจน์แล้วทำงาน**
- **EA validated จริง = 1 ตัว: GSMC (Gold SMC)** — archive shortlist (EURCAD/AUDCAD/GEP) REJECT หมดเพราะ provenance ไม่ตรง
- next: ยืนยัน optimize loop -> ถ้าได้ ทำ candidate pool -> portfolio (ต้องมี >=2-3 EA uncorrelated)

## กฎ
ปิด MT5 ก่อนรัน automation · grid ใช้ report DD · commit git ทุกงานใหญ่ · demo 3 เดือนห้ามลัด
