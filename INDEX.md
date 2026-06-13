# EA_LAB INDEX — ทะเบียน EA ทุกตัว

> เปิดไฟล์นี้ก่อนเสมอ · อัปเดต 2026-06-12
> สถานะ: BACKTEST → ANALYZED → OPTIMIZED → ROBUST → PORTFOLIO → DEMO → LIVE / REJECTED

## EA ที่กำลังทำ

| EA | Code | Symbol/TF | สถานะ | ขั้นต่อไป |
|---|---|---|---|---|
| [EA_GoldenEmber_Pivot](ea_projects/EA_GoldenEmber_Pivot/00_README.md) | GEP | NZDUSD H1 | ANALYZED (เก่า) | รัน backtest .set แล้วเก็บ report เข้า pipeline |

## EA ที่จ่ออยู่ (ยังไม่ย้ายเข้า)

ดูรายชื่อเต็มใน idea bank: `D:\Forex\50_KNOWLEDGE\IDEA_BANK\INDEX.md`

| EA | จาก idea bank | จะย้ายเข้าเมื่อ |
|---|---|---|
| HalfTrend XAU Pilot | halftrend-xauusd-pilot | เริ่ม tracer bullet |
| EX197 GBPJPY | ex197-gbpjpy | จับคู่พอร์ตกับ GEP |
| Grid Trend Follower | grid-trend-follower | เลือกทำ grid ตัวแรก |

## วิธีเพิ่ม EA ใหม่
1. copy `ea_projects/_TEMPLATE_EA_PROJECT/` → `ea_projects/EA_<ชื่อ>/`
2. กรอก `00_README.md` (ใช้ [templates/EA_README_TEMPLATE.md](templates/EA_README_TEMPLATE.md))
3. เพิ่มแถวในตารางข้างบนนี้
4. โยน .set เข้า `set_files/`, report เข้า `reports/inbox/`

## หมายเหตุสำคัญ (บทเรียน pass id ข้าม batch)
pass number มีความหมายเฉพาะใน optimization batch ของตัวเอง — **เวลาอ้างผลให้ใช้
OptBatchID + PassID เสมอ** และเวลา backtest จริงให้โหลด .set (ค่าฝังอยู่แล้ว)
ไม่ใช่จำแค่เลข pass ดูตัวอย่างที่เคยพลาดใน
`D:\Forex\30_OPTIMIZATION\04_Reports\Pipeline_Demo_20260612\PIPELINE_DEMO_SUMMARY.md`
