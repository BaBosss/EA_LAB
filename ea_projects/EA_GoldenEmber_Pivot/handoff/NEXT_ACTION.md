# NEXT ACTION — EA_GoldenEmber_Pivot

## ทำอันนี้ต่อ
รัน single-test ด้วย `pass845_safe_FULL.set` + `pass845_safe_RECENT.set`
บน `PORT 6 — EA_GoldenEmber` (NZDUSD H1, real ticks) ตามขั้นตอนใน
[../00_README.md](../00_README.md) ข้อ "วิธี backtest"

## เป้าหมายของ run นี้
ได้ **report HTML + deals CSV** ที่ pass845 ขาดไป (ก่อนหน้านี้มีแต่ pass71)
เพื่อพิสูจน์ว่า pass845 ดีกว่า pass71 จริงไหม

## พอได้ report แล้ว
1. วางไฟล์ใน `reports/inbox/`
2. บอก Claude: "parse GEP report แล้ววิเคราะห์"
   → parse_mt5_report.py → backtest-report-analyzer skill → verdict
3. ถ้า PASS → robustness-validator (ใช้ deals CSV → monte_carlo.py)
4. อัปเดต [../RESULTS.md](../RESULTS.md) RUN_GEP_0004/0005

## ถ้าติดปัญหา
- EA โหลดไม่ขึ้น / no trade → เช็คว่าเลือก `PORT 6 — EA_GoldenEmber` ไม่ใช่
  `Boss - 6 Pivot Range Trading` (คนละ batch)
- ชื่อ EA มี em-dash "—" ถ้า MT5 CLI โหลดไม่ได้ ให้รันผ่าน GUI แทน
