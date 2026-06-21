# MT4 EA Screening — Workflow Design & Qwen Handoff

อัพเดท: 2026-06-21 | สถานะ: 🟢 INFRA PROVEN (4 runs done) — พร้อมส่ง Qwen ทำ batch ต่อ

## เป้าหมาย
Smoke-screen MT4 EAs ~63 ตัว (โฟลเดอร์ `MQL4\Experts`) ที่ยังไม่เคยเทส
หา EA ที่มี "edge" บน gold/forex เพื่อเอาเข้า deep validation (IS/OOS/MC) ต่อ

---

## สภาพแวดล้อม (สำรวจแล้ว 2026-06-21)

| รายการ | ค่า |
|---|---|
| MT4 terminal | `D:\Meta4\terminal.exe` |
| Data dir | `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0` |
| Broker ที่ล็อกอินค้าง | **Exness-Real35** (cent account, Build 1471) |
| Symbol ที่ใช้ | **XAUUSDc** + **EURUSDc** (cent) — ทุก EA เทส 2 symbol นี้ |
| History ลึกสุด | XAUUSDc H1 ~30mo (2023-12→2026-06), EURUSDc H1 ~30mo |
| TF เดียวที่ data พอ | **H1** (M1/M15 ตื้นมาก → every-tick ยังไม่ได้) |
| Model | **2 = Open prices** (rough screen; ตัวน่าสนใจค่อย Model 0) |
| Window | **1 ปี: 2025.06.01 → 2026.06.01** |

> หมายเหตุ broker: นายอยากได้ ThinkMarkets แต่ terminal ล็อกอินค้างที่ Exness
> และสลับต้อง login (Claude กรอกรหัสไม่ได้). Exness cent data ลึก+ใหม่กว่า ThinkMarkets
> และตรงแผน cent live → ใช้ Exness ไปก่อน. ถ้าจะเอา ThinkMarkets: นาย login เองแล้วรันซ้ำ symbol = EURUSD/XAUUSD (ไม่มี c)

---

## เครื่องมือ (สร้างใหม่ session นี้)

| ไฟล์ | หน้าที่ |
|---|---|
| `scripts\mt4_run.ps1` | headless single backtest (config ini → terminal.exe → ย้าย .htm report) |
| `scripts\parse_mt4_report.py` | แปลง MT4 .htm report → JSON/CSV + ติด screen verdict |
| `_mt4_auto\reports\` | report .htm + .gif |
| `_mt4_auto\MT4_SCREEN_RESULTS.csv` | ตารางผลรวม (accumulator) |

### คำสั่งมาตรฐาน (1 EA, 1 symbol)
```powershell
& "D:\EA_LAB\scripts\mt4_run.ps1" -Expert "<ชื่อ EA ไม่มี .ex4>" -Symbol XAUUSDc `
   -Period H1 -FromDate 2025.06.01 -ToDate 2026.06.01 -ReportName "<TAG>" -Model 2 -TimeoutSec 300
python "D:\EA_LAB\scripts\parse_mt4_report.py" "D:\EA_LAB\_mt4_auto\reports\<TAG>.htm" --csv
```

### ⚠️ กฎเหล็ก
1. **ปิด MT4 GUI ก่อนรัน** — single-instance ต่อ data dir. `mt4_run.ps1` จะ ABORT ถ้า terminal เปิดอยู่ (มี -Force แต่อย่าใช้ถ้าไม่จำเป็น)
2. รัน **ทีละตัว** (sequential) — MT4 รันพร้อมกันไม่ได้
3. ชื่อ EA ต้องตรงเป๊ะ (มีช่องว่าง/อักขระพิเศษ/ภาษาไทย) — copy จาก registry
4. ถ้า "NO REPORT" → เช็คชื่อ EA / EA ต้อง unlock / EA crash on init → ข้าม ลงบันทึก SKIP

---

## เกณฑ์ screen (อยู่ใน parser แล้ว)
| verdict | เงื่อนไข |
|---|---|
| PASS | PF ≥ 1.40 (และ trades ≥ 10) |
| WATCH | 1.10 ≤ PF < 1.40 |
| REJECT | PF < 1.10 |
| THIN | trades < 10 (น้อยเกินตัดสิน) |
| NO_DATA | parse ไม่ได้ |

> ⚠️ PF อย่างเดียวไม่พอ — ดู **maxDD%** + **trades** ด้วย:
> - DD สูง (>30%) + trades เยอะ (>2000/ปี) = martingale/grid → flag "GRID risk" แม้ PF สูง
> - net น้อยมาก (default lot ไมโคร) = ดู PF/win% เป็นหลัก ไว้ size ตอน deep validation

---

## ผลที่ทำแล้ว (4 runs, infra proof)
| EA | Sym | trades | PF | maxDD% | win% | verdict | note |
|---|---|---|---|---|---|---|---|
| MACD Sample (control) | EURUSDc | 37 | 0.36 | 0.03 | 81 | REJECT | control — pipeline OK |
| AI Gold Sniper EA | XAUUSDc | 115 | 2.26 | 0.01 | 98 | PASS | net น้อย (micro lot); edge น่าสนใจ |
| AI Gold Sniper EA | EURUSDc | 10 | 0.17 | 0.01 | 70 | REJECT | gold EA → EUR ไม่เวิร์ก |
| Gold Stuff EA V7.0 | XAUUSDc | 4655 | 5.09 | **39.26** | 71 | PASS⚠️ | GRID risk: 4655 เทรด/ปี + DD 39% |
| Gold Stuff EA V7.0 | EURUSDc | 789 | 2.43 | 0.6 | 70 | PASS | ผ่านสะอาด |

---

## งานของ Qwen (batch ที่เหลือ ~61 EA)
ดู `QWEN_MT4_SCREEN_PLAN.md` — รัน EA ที่เหลือทั้งหมด × {XAUUSDc, EURUSDc} ด้วย pattern ข้างบน
แล้ว append ลง `MT4_SCREEN_RESULTS.csv` + รายงานตาราง ranked ตาม PF (XAU)

## หลัง screen เสร็จ (Claude ทำต่อ)
1. คัด PASS/WATCH ที่ DD สมเหตุสมผล → deep validation (IS/OOS split + Model 0 every-tick ตัวที่ผ่าน)
2. แยก GRID/martingale ออกพิจารณาต่างหาก (ต้อง MC + DD cap)
3. ตัวที่รอด → cent .set + เข้า portfolio expansion
