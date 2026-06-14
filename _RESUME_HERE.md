# RESUME HERE — เปิด session ใหม่อ่านไฟล์นี้ก่อน (2026-06-14)

## อ่านตามลำดับ
1. `D:\EA_LAB\PLATFORM_INDEX.md` — แผนที่ทุกราก/โฟลเดอร์
2. `D:\EA_LAB\PROJECT_STATUS.md` — สถานะ/milestone/ขั้นตอนใช้งาน
3. `D:\EA_LAB\RUN_REGISTRY.md` — ผล backtest ทั้งหมด (auto)

## ค้างอยู่ (in-flight ตอน clear)
- **optimize_loop ของ EURCADv2** (Boss-2 Adaptive Smart Grid) รัน background ไว้
- เช็คผล: ดู `RUN_REGISTRY.md` แถว `EURCADv2_loopIS/OOS` + ไฟล์ `_mt5_auto\optimizations\OPT_EURCADv2.xml`
- **ถ้าไม่มี OPT_EURCADv2.xml** = headless optimize -> XML ไม่ทำงานบน build นี้ (ต้อง export มือใน GUI หรือหาทาง v2)
- รัน `python D:\EA_LAB\scripts\run_pipeline.py D:\EA_LAB\ea_projects D:\EA_LAB\_mt5_auto\reports` เพื่อ refresh registry

## สถานะสั้นๆ
- automation pipeline ครบ + MT5 headless single-test **พิสูจน์แล้วทำงาน**
- **EA validated จริง = 1 ตัว: GSMC (Gold SMC)** — archive shortlist (EURCAD/AUDCAD/GEP) REJECT หมดเพราะ provenance ไม่ตรง
- next: ยืนยัน optimize loop -> ถ้าได้ ทำ candidate pool -> portfolio (ต้องมี >=2-3 EA uncorrelated)

## กฎ
ปิด MT5 ก่อนรัน automation · grid ใช้ report DD · commit git ทุกงานใหญ่ · demo 3 เดือนห้ามลัด
