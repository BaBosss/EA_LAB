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
>
> ⚠️ **DIGITS (ยืนยัน 2026-06-21):** XAUUSDc = **3 หลัก** (ราคา 3353.870, point=0.001),
> EURUSDc = 5 หลัก (มาตรฐาน). gold EA ที่ hardcode SL/TP เป็น point โดยไม่เช็ค Digits จะเพี้ยน 10 เท่า.
> **แต่นี่คือสภาพ live จริงของนาย** (Exness cent = gold 3 หลัก) → เทส 3 หลัก = ถูกต้อง ตรง live.
> EA ที่พังบน 3 หลัก = พังในพอร์ตจริงด้วย → คัดออกถูกแล้ว. ทุก XAU row ใน CSV เป็น 3 หลักทั้งหมด.

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

## ผล Batch 2 (15 EAs — Qwen, 2026-06-21) ✅ COMPLETE
| EA | XAU PF | XAU t | XAU DD% | EUR PF | verdict | หมายเหตุ |
|---|---|---|---|---|---|---|
| EA_Golden_Elephant | **4.08** | 207 | 2.60 | **6.69** | PASS ✅ | clean ทั้งคู่ |
| EA_Golden_Mammoth | **4.08** | 207 | 2.60 | **6.69** | PASS ✅ | ผลเหมือน Elephant ทุกบิต = same EA? |
| EURUSD Trading Forex Robot | **5.56** | 73 | 30.31 | **3.89** | PASS | XAU DD สูงเล็กน้อย |
| EA Game Changer_fix | **7.32** | 6911 | 14.33 | **2.22** | PASS⚠️ | 6911t = churn suspect Phase 2 |
| EA-HOKKYDJONG | 1.03 | 5825 | 0.77 | **1.80** | XAU REJECT/EUR PASS | XAU churn |
| Fibot EA | NO_DATA | 0 | — | **2.48** | EUR PASS only | XAU ไม่เทรด |
| EA IRON MAN V.10 | NO_DATA | — | — | THIN | NO_DATA | |
| EA Re Mink-Kwan 1.6 | NO_DATA | — | — | NO_DATA | structural | |
| EA Rebalance V.5+ | NO_DATA | — | — | NO_DATA | structural | |
| Espresso_Gold_Pro | 0.34 | 301 | **125%** | 0.07 | REJECT | DD หายนะ |
| Fx Setka Trader v2 | 0.19 | 1133 | **103%** | 0.93 | REJECT | DD หายนะ |
| Fancy Meal | THIN | 6 | — | 1.01 | THIN | |
| EA Lambo | SKIP | — | — | SKIP | NO_REPORT | |
| EX18 GTS | SKIP | — | — | SKIP | NO_REPORT | |
| GARRY'S AI | SKIP | — | — | SKIP | NO_REPORT | |

## ⚠️ Phase 2 — Pip-adjusted re-test (สำคัญ! กัน "พลาด EA ดีเพราะตั้ง pip ผิด")
**ปัญหา:** บน gold 3-หลัก (point=0.001) EA ที่ input SL/TP/distance ถูกตั้งมาเพื่อ 2-หลัก
จะ**เล็กไป 10 เท่า** → EA churn (เทรดถล่ม TP จิ๋ว) หรือ **ไม่เทรดเลย (NO_DATA/THIN)** →
ดูเหมือนไม่มี edge ทั้งที่ถ้าตั้ง pip ถูกอาจดีมาก. **ห้าม REJECT ทันที** — ต้องเทสซ้ำ pip ที่ถูก

**สัญญาณว่าน่าจะ config ผิด (ไม่ใช่ไม่มี edge):**
- trades สูงผิดปกติ (>2000/ปี) + avg trade จิ๋ว → TP/distance แน่นไป (เช่น Gold Stuff TP=150→$0.15, ClevrFX 3993 เทรด)
- NO_DATA / THIN (เทรด 0 หรือ <10) ทั้งที่ EA เป็น gold EA → ดู 2 สาเหตุหลัก:
  - **(พบบ่อยสุด) MaxSpread / Spread_contr ตั้งต่ำเกิน** — spread ทองบน 3-หลักคิดเป็น points ใหญ่ ~10 เท่า → filter บล็อกทุกออเดอร์. ✅ พิสูจน์แล้ว: ARTGOLDPro default 0 เทรด → MaxSpread 80→800 = 30 เทรด PF 1.10 WATCH
  - SL/TP เล็กจนไม่เข้าเงื่อนไข / init fail
- **เช็คก่อนเสมอ:** EA hardcode symbol อื่นไหม (เช่น Boring Pips `trade_symbol="AUDNZD NZDCAD AUDCAD"` → NO_DATA บน gold เพราะมันไม่เทรด gold เลย ไม่ใช่บั๊ก — อย่าเสียเวลา refix)
- `parse_mt4_report.py` ใส่ field `pip_suspect` (input pip/spread ที่เป็นเลข ≠ 0) + `params` (ทุก input) ให้ดูแล้ว

**วิธีทำ (Claude — ต้องใช้วิจารณญาณ ไม่ใช่งาน Qwen):**
```powershell
# 1. ดู params + pip_suspect ของ EA นั้น
python "D:\EA_LAB\scripts\parse_mt4_report.py" "<report>.htm"        # ดู params/pip_suspect
python "D:\EA_LAB\scripts\mt4_pipfix_set.py" "<report>.htm" --list   # ดูทุก param + flag PIP?
# 2. สร้าง .set ที่ ×10 เฉพาะ field pip จริง (เลือกเองอย่าใช้ auto ตรง ๆ — ดู --fields)
python "D:\EA_LAB\scripts\mt4_pipfix_set.py" "<report>.htm" "<EA>_pipx10.set" --mult 10 --fields TP,SL,Distance,...
# 3. เทสซ้ำด้วย .set นั้น แล้วเทียบ default vs ×10
& "D:\EA_LAB\scripts\mt4_run.ps1" -Expert "<EA>" -Symbol XAUUSDc -Period H1 -FromDate 2025.06.01 -ToDate 2026.06.01 -SetFile "D:\EA_LAB\_mt4_auto\<EA>_pipx10.set" -ReportName "<TAG>_XAU_pipx10" -Model 2
```
**ตัดสิน:** ถ้า ×10 → trades สมเหตุสมผล (ไม่ churn) + edge โผล่ = EA ดีแต่ default ผิด → เก็บเข้า deep validation.
ถ้า ×10 ก็ยังแย่ = ไม่มี edge จริง → REJECT. (บาง EA auto-detect Digits อยู่แล้ว → default ถูก, ×10 จะใหญ่เกิน → เลือก version ที่ trade สมเหตุสมผล)

## ผล Batch 3 (15 EAs — Qwen, 2026-06-21) ✅ COMPLETE
| EA | XAU PF | XAU t | XAU DD% | EUR PF | verdict | หมายเหตุ |
|---|---|---|---|---|---|---|
| KRAPOOK AI 2026 SNIPER | **8.50** | 21 | 1.33 | NO_DATA | THIN⚠️ | 21t เท่านั้น — artifact? |
| KRAPOOK BLUE ANT | **2.65** | 477 | **0.40** | 1.28 | PASS ✅ | clean XAU, low DD |
| Gold Buster MT4 | 0.22 | 273 | 32.30 | **4.09** | EUR PASS | XAU REJECT |
| GMGS PRO V2 | 1.29 | 2787 | 0.10 | **1.66** | WATCH/PASS | XAU 2787t churn suspect |
| Infinix ea | 0.85 | 38 | 103.19 | **8.48** | EUR PASS | XAU DD หายนะ |
| God_s Blessing Expert | NO_DATA | — | — | **4.31** | EUR PASS | same as God's Blessing |
| God's Blessing Expert | NO_DATA | — | — | **4.31** | EUR PASS | ผลเหมือนกันทุกบิต |
| KRAPOOK YELLOW ANT | 1.18 | 3511 | **60.83** | 1.09 | WATCH⚠️ | DD=61% grid/martingale |
| Ghost Bot 01 G07 (1) | SKIP | — | — | 1.34 | EUR WATCH | NO_REPORT XAU |
| Gold_Kangaroo | NO_DATA | — | — | NO_DATA | REJECT | structural |
| Goldex AI 1.4 | NO_DATA | — | — | NO_DATA | REJECT | structural |
| HFT2 | NO_DATA | — | — | NO_DATA | REJECT | structural |
| Jesko_fix | NO_DATA | — | — | NO_DATA | REJECT | structural |
| Greezly Bot Pro | SKIP | — | — | SKIP | NO_REPORT | |
| Infinix Currency Ea | SKIP | — | — | SKIP | NO_REPORT | |

Phase 2 suspects Batch 3:
- KRAPOOK SNIPER: 21 trades = THIN/artifact — ถ้า trades น้อยเกินบน Model 2 = เก็บ Deep Val ไว้
- GMGS PRO V2: 2787 trades = churn suspect, check TP field
- KRAPOOK YELLOW ANT: DD=60.83% = grid จริง ไม่ใช่ pip error → REJECT
- Gold_Kangaroo/Goldex AI/HFT2/Jesko_fix: NO_DATA both = structural fail → skip

## ผล Batch 4 (16 EAs — Qwen, 2026-06-21) ✅ COMPLETE
13/16 NO_REPORT = commercial locked EAs (Quantum/Ro King Man/SkyFX/SMC/Vigorous/Winning/Zeus etc.)
| EA | XAU PF | XAU t | XAU DD% | EUR PF | verdict |
|---|---|---|---|---|---|
| KZM V.1.20 | 0.24 | 5867 | 0.32 | 1.38 | XAU REJECT, EUR WATCH |
| Little Birds EA | 0.81 | 462 | 103.45 | 0.50 | REJECT (XAU DD หายนะ) |
| 14 EAs | SKIP | — | — | SKIP | NO_REPORT (locked/init fail) |

## ✅ SCREENING COMPLETE — 63 EAs, 4 Batches + Phase 2

## Phase 2 refix summary (all complete)
| EA | Phase 2 ผล | verdict |
|---|---|---|
| ARTGOLDPro | MaxSpread 80→800 = 30t PF=1.10 | **WATCH** (rescued) |
| Gold Stuff V7.0 | pip×10 ยัง churn DD=53% | REJECT (grid จริง) |
| DHW GoldEA4 | all fix ยัง 0t | REJECT (structural) |
| AlgoScalpPro | spread+pip fix EUR=0.41 XAU=0t | REJECT |
| BuRengNong2073 | pip×10 ยัง 0t | REJECT (TF15 only) |
| ClevrFX | TP×10 = 0t (tradeLimit stall) | REJECT (scalp artifact) |
| EA Game Changer | TP×10 = 6795t (เกือบเท่าเดิม) | REJECT (hedge grid, Model 2 artifact) |
| GMGS PRO V2 | TakeProfit=30→ diagnosis: martingale hedge | REJECT (same artifact class) |

## 🏆 FINAL SHORTLIST — MT4 EA candidates ที่น่า deep validate

### ✅ XAU Clean PASS (สมเหตุสมผลทุกมิติ)
| EA | XAU PF | XAU t | XAU DD% | EUR PF | หมายเหตุ |
|---|---|---|---|---|---|
| **EA_Golden_Elephant** | **4.08** | 207 | **2.60** | **6.69** | ดีทั้ง 2 sym, low DD ✅ |
| **KRAPOOK BLUE ANT** | **2.65** | 477 | **0.40** | 1.28 | DD ต่ำสุดใน pool ✅ |
| **BuRengNong207_FiniteBreakOut** | **1.76** | 508 | **8.58** | **1.65** | cleanest ทั้ง 2 sym ✅ |

### ⚠️ XAU Borderline (ผ่านแต่มีข้อกังวล)
| EA | XAU PF | XAU t | XAU DD% | หมายเหตุ |
|---|---|---|---|---|
| EURUSD Trading Forex Robot | 5.56 | 73 | **30.31** | DD borderline; EUR 3.89 clean |
| AI Gold Sniper EA | 2.26 | 115 | 0.01 | micro lot ($1.26 net) — lot ไมโคร |
| KRAPOOK AI SNIPER | 8.50 | **21** | 1.33 | THIN — 21 trades only |
| ARTGOLDPro (Phase 2 rescued) | 1.10 | 30 | 0.87 | trades น้อย |

### 📋 EUR-only interesting
| EA | EUR PF | EUR t | หมายเหตุ |
|---|---|---|---|
| God_s/God's Blessing | 4.31 | 45 | ไม่เทรด XAU |
| Gold Buster MT4 | 4.09 | 141 | ไม่เทรด XAU |
| Infinix ea | 8.48 | 33 | THIN; XAU DD=103% |
| Fibot EA | 2.48 | 321 | ไม่เทรด XAU |

## Next: Deep Validation (IS/OOS + Model 0)
Top 3 → IS/OOS extended (2020-2025) + Model 0 every-tick → cent .set

## หลัง screen เสร็จ (Claude ทำต่อ)
1. **Phase 2 pip re-test** กับ gold ทุกตัวที่ churn / NO_DATA / THIN ที่มี pip_suspect (ข้างบน)
2. คัด PASS/WATCH ที่ DD สมเหตุสมผล → deep validation (IS/OOS split + Model 0 every-tick ตัวที่ผ่าน)
3. แยก GRID/martingale ออกพิจารณาต่างหาก (ต้อง MC + DD cap)
4. ตัวที่รอด → cent .set + เข้า portfolio expansion

## เครื่องมือเพิ่ม
- `scripts\mt4_pipfix_set.py` — ดึง params จากรายงาน → ×N เฉพาะ pip fields → เขียน .set สำหรับ re-test
- `parse_mt4_report.py` — เพิ่ม field `params` (บันทึก strategy) + `pip_suspect` (flag input ที่ต้องเช็ค)
