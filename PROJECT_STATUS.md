# PROJECT STATUS — EA Platform (อัพเดท 2026-06-14)

> ภาพรวม "ถึงไหนแล้ว / เหลืออะไร / ใช้งานยังไง" · คู่กับ `PLATFORM_INDEX.md` (แผนที่ไฟล์)
> **เป้าหมาย:** 10 พอร์ต × 2-3 EA ที่ไม่ correlate กัน × 10,000 cent → passive income

---

## 1. สรุป 1 บรรทัด
**เครื่องมือ (automation) สร้างเสร็จ ~90% และพิสูจน์แล้วว่าทำงานจริง** — ตอนนี้กำลังเข้าสู่ช่วง "ป้อน EA เข้าระบบเพื่อหา candidate ที่ผ่านจริง" ส่วนที่เหลือถึง live ส่วนใหญ่เป็น **เวลา** (demo 3 เดือนบังคับ) ไม่ใช่ engineering

---

## 2. Milestone (7 เฟส)

| เฟส | คือ | สถานะ | % |
|---|---|---|---|
| **0. Foundation** | จัดบ้าน, กู้ความรู้ (chat 788), รวม EA_LAB, git | ✅ DONE | 100 |
| **1. Automation pipeline** | parse→deals→score→MonteCarlo→robust-select→gen.set→registry→**MT5 headless** | ✅ DONE (single-test พิสูจน์แล้ว) | 90 |
| **2. Candidate production** | รัน shortlist + validate ให้ผ่าน IS→OOS→robustness | 🔄 กำลังทำ (batch รันอยู่ตอนนี้) | 25 |
| **3. EA Template** | เปลือก EA dropdown modes (MM/TP/SL/Recovery/Hedge ร่วม, เปลี่ยนแค่ entry) | ⬜ ยังไม่เริ่ม (พัก) | 0 |
| **4. Portfolio** | correlation + DD overlap → จัดพอร์ต (ต้องมี ≥2-3 EA ผ่านก่อน) | ⬜ ยังไม่เริ่ม | 0 |
| **5. Demo** | รัน demo จริง ≥3 เดือน (บังคับ ห้ามลัด) | ⬜ ยังไม่เริ่ม | 0 |
| **6. Live** | 10 พอร์ต ทุนเล็ก + monitoring + kill-switch | ⬜ ยังไม่เริ่ม (เป้า) | 0 |

**Track แยก — EA_CORE_V1 framework** (MQL5 ที่ Codex สร้าง): foundation เสร็จ (1317 PASS, metadata-only), ExecutionEngine ยังไม่เริ่ม → **พักไว้** ตามทิศทาง balanced (ใช้ EA สำเร็จรูปก่อน)

---

## 3. เครื่องมือที่สร้างแล้ว (เฟส 1 — ใช้งานได้จริง)
`D:\EA_LAB\scripts\` ทั้งหมด stdlib python + powershell, git คุม 12+ commits:

| script | ทำอะไร |
|---|---|
| `parse_mt5_report.py` | report HTML/optimizer XML → metrics JSON (แก้ bug comma/symbol แล้ว) |
| `extract_deals.py` | ดึง per-trade P/L จาก HTML → CSV (สำหรับ Monte Carlo) |
| `score_backtest.py` | BacktestScore v1 → PASS/WATCH/REJECT (เตือน grid) |
| `monte_carlo.py` | DD distribution + prob-of-ruin |
| `select_robust_pass.py` | เลือก robust pass (ไม่ใช่ overfit peak) + plateau |
| `set_from_robust.py` | robust pass → ไฟล์ .set พร้อมรัน |
| `run_pipeline.py` | batch กวาด report ทั้งหมด → `RUN_REGISTRY.md` + SHORTLIST |
| `mt5_run.ps1` / `mt5_batch_shortlist.ps1` | **MT5 รัน backtest อัตโนมัติ (headless)** ✅ พิสูจน์แล้ว |
| `mt5_optimize.ps1` | MT5 optimize อัตโนมัติ (สร้างแล้ว รอ confirm รันจริง) |

---

## 4. สถานะ EA (candidate)

| EA | สถานะใน lifecycle | หมายเหตุ |
|---|---|---|
| **GSMC (Gold SMC riskcap)** XAU | ✅ IS→OOS→MC ครบ = **PORTFOLIO_TEST** | edge บาง (PF5th 1.07), live DD ~40% |
| Shortlist 14 robust zones | 🔄 batch กำลัง validate | EURCAD/AUDCAD/AUDNZD (grid, ระวัง), Pivot, EX197... |
| EX197 GBPJPY | robust pass GOOD (PF 4.16/DD 5.9%) | รอ single-test |
| Matchagrid CHFJPY | grid, MC เชื่อไม่ได้ | conditional |

**EA ที่ผ่านครบจริง = 1 ตัว** (GSMC) → ต้องการ ≥2-3 ตัวที่ไม่ correlate ก่อนทำพอร์ตแรก

---

## 5. เหลืออีกเยอะไหม? (ตอบตรง)
- **Engineering: เหลือน้อย** — pipeline ครบ, MT5 auto ใช้ได้ ที่เหลือ: ยืนยัน headless-optimize, OOS-aware scoring, (option) EA template
- **การหา candidate: เป็น loop กึ่งอัตโนมัติแล้ว** — ป้อน .set → auto backtest → score → review วนได้เร็ว
- **ตัวขวางจริงคือเวลา:** demo ≥3 เดือน = นาฬิกาเดินจริง ลัดไม่ได้
- **เส้นทางถึง live (สมจริง):** หา 4-6 EA ผ่าน robustness (2-4 สัปดาห์ถ้าขยัน) → พอร์ต → demo 3 เดือน → live → รวม ~4-5 เดือน โดยส่วนใหญ่คือ demo

---

## 6. ขั้นตอนการใช้งาน (operate ประจำวัน)

### A. อยากได้ backtest ใหม่ (อัตโนมัติ)
1. **ปิด MT5 GUI** (สำคัญ — script จะ abort ถ้าเปิดอยู่)
2. `& D:\EA_LAB\scripts\mt5_batch_shortlist.ps1`  (รัน shortlist IS+OOS) — หรือ `mt5_run.ps1` ทีละตัว
3. `python D:\EA_LAB\scripts\run_pipeline.py D:\EA_LAB\ea_projects D:\EA_LAB\_mt5_auto\reports`
4. ดูผล: `D:\EA_LAB\RUN_REGISTRY.md`

### B. robustness + review (ลึก)
- บอก Claude: **"วิ่ง analyst+reviewer กับ <EA>"** → extract_deals + monte_carlo + รีวิว skeptical → นายตรวจสุดท้าย

### C. หา candidate จากคลัง optimize เก่า
- มี optimizer XML อยู่แล้ว → `select_robust_pass.py` → `set_from_robust.py` → `mt5_run.ps1` (single-test) → score
- (อนาคต) optimize ใหม่อัตโนมัติ: `mt5_optimize.ps1`

### D. พอมี EA ผ่าน ≥2-3 ตัว
- skill `portfolio-selector` → correlation + DD overlap → จัดพอร์ต → `live-deployment-controller` → demo

### กฎที่ห้ามลืม
- ปิด MT5 ก่อนรัน automation · ของก้อนใหญ่กลั่นด้วย script ไม่โหลดดิบ · grid ใช้ report DD ไม่ใช่ MC · ทุกงานใหญ่ commit git · demo 3 เดือนห้ามลัด

---

## 7. ถัดไปทันที
1. ⏳ batch screening (รันอยู่) เสร็จ → score → review → เห็นว่ามี candidate ใหม่ผ่านกี่ตัว
2. ตัวที่ผ่าน screening (Model 1) → re-run real-tick (Model 4) ยืนยัน
3. พอได้ ≥2-3 ตัว uncorrelated → เริ่มเฟส 4 (portfolio)
