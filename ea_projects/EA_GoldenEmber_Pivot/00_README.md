# EA_GoldenEmber_Pivot

- **EA Code:** GEP
- **EA name ใน MT5:** `PORT 6 — EA_GoldenEmber` (a.k.a. "(Boss) 6- MTF Range Pivot")
- **Magic:** 117030969
- **Symbol / TF:** NZDUSD / H1
- **ประเภท:** mean-reversion (pivot range + RSI/CCI + ATR zone)
- **idea bank:** `D:\Forex\50_KNOWLEDGE\IDEA_BANK\cards\pivot-range-nzdusd.md`

## ⚠️ ก่อนทำต่อ อ่านก่อน — มี EA สองสายที่ชื่อใกล้กัน

| สาย | ไฟล์ EA ใน MT5 | optimizer batch | .set ที่เกี่ยวข้อง |
|---|---|---|---|
| **rev0 / GoldenEmber** (Magic 117030969) | `PORT 6 — EA_GoldenEmber.ex5` | `Port 6 Pivot range - NZDUSD - rev 0\*.xml` | pass845, pass71, pass202 (ทุกไฟล์ใน set_files/) |
| Boss main | `Boss - 6 Pivot Range Trading.ex5` | `Port 6 Pivot range - NZDUSD.csv` (1,694 passes) | — |

`.set` ทั้งหมดใน `set_files/` มี header ระบุว่าเป็นของ **rev0 (GoldenEmber)** →
ต้องโหลดเข้า `PORT 6 — EA_GoldenEmber.ex5` เท่านั้น

**บทเรียน:** "pass 845" ใน .set ≠ "pass 845" ใน CSV หลัก (คนละ batch) —
เวลา backtest เชื่อค่าใน .set ไม่ใช่เลข pass

## ตำแหน่งไฟล์จริง

- **EA (.ex5):** `D:\Meta 5\...\MQL5\Experts\PORT 6 — EA_GoldenEmber.ex5`
  (ที่จริงคือ terminal folder `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\`)
- **.set:** `set_files/` ในโฟลเดอร์นี้ (copy มาแล้ว)
- **optimizer เดิม:** `reports/raw/Port 6 Pivot range - NZDUSD - rev0.xml`

## พารามิเตอร์ของ pass845_safe (จาก .set)
TF_Entry=16388 (H1), RSI_Period=20, CCI_Period=21, ATR_Period=20,
Zone_ATR_Mult=0.8, ATR_SL_Mult=4.0, RiskPercent=1.0, Max_Pos=10,
MaxDD_Pct=9, MaxDay_Pct=5, Max_Lot=3, ADX_Filter=ON, BB_Filter=ON

## วิธี backtest (ทำตอนนี้ได้เลย)
1. MT5 (`D:\Meta 5`) → Ctrl+R เปิด Strategy Tester
2. Expert: `PORT 6 — EA_GoldenEmber` | Symbol: NZDUSD | TF: H1
3. Modelling: **Every tick based on real ticks**
4. ช่วง FULL: 2020.01.01–2026.05.09 (รันแยกอีกครั้งช่วง OOS: 2025.07.01–2026.05.09)
5. แท็บ Inputs → คลิกขวา → Load → `set_files/NZDUSD_Pivot_pass845_safe_FULL.set`
6. Start → เสร็จแล้ว: Report → Save as Report (HTML) ลงใน `reports/inbox/`
   และ History tab → export deals เป็น CSV ลง `reports/inbox/` ด้วย
7. บอก Claude: "parse report ใน GEP inbox" → เข้า pipeline ต่อ

## ดูผลทั้งหมดที่ [RESULTS.md](RESULTS.md)
