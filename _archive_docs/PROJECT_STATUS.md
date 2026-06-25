# PROJECT STATUS — EA Platform (อัพเดท 2026-06-22)

> ภาพรวม "ถึงไหนแล้ว / เหลืออะไร / ใช้งานยังไง" · คู่กับ `PLATFORM_INDEX.md` (แผนที่ไฟล์)
> **เป้าหมาย:** 10 พอร์ต × 2-3 EA ที่ไม่ correlate กัน × 10,000 cent → passive income

---

## 1. สรุป 1 บรรทัด
**Deploy ครบ 8 EA บน 10,000 cent account แล้ว (2026-06-22)** — screening + validation จบ, automation pipeline
codified เป็น 9 skills. ตอนนี้อยู่ช่วง **demo-monitor (ติดนาฬิกา) → judge 2026-09-22**. งาน engineering ที่เหลือ
ทำได้เลย 2 thread: (A) เครื่องมือ judge per-EA, (B) EA_CORE ScaleExecutor Part B. การหา signal ใหม่ปิดแล้ว.

---

## 2. Milestone (7 เฟส)

| เฟส                         | คือ                                                                          | สถานะ                            | %   |
| --------------------------- | ---------------------------------------------------------------------------- | -------------------------------- | --- |
| **0. Foundation**           | จัดบ้าน, กู้ความรู้ (chat 788), รวม EA_LAB, git                              | ✅ DONE                           | 100 |
| **1. Automation pipeline**  | parse→deals→score→MonteCarlo→robust-select→gen.set→registry→**MT5 headless** | ✅ DONE (single-test พิสูจน์แล้ว) | 90  |
| **2. Candidate production** | รัน shortlist + validate ให้ผ่าน IS→OOS→robustness                           | ✅ DONE (8 EA ผ่าน + standalone signals) | 100 |
| **3. EA Template**          | standalone-first template (`EA_STANDALONE_TEMPLATE.mq5`) — CB/BRK สร้างจากนี้  | ✅ DONE (เปลี่ยนทิศเป็น standalone) | 100 |
| **4. Portfolio**            | correlation + DD overlap → จัดพอร์ต 8 EA                                       | ✅ DONE                          | 100 |
| **5. Demo**                 | รัน demo จริง ≥3 เดือน (บังคับ ห้ามลัด) — **เริ่ม 2026-06-22, judge 09-22**   | 🔄 กำลังเดิน (ติดนาฬิกา)          | 5   |
| **6. Live**                 | 10 พอร์ต ทุนเล็ก + monitoring + kill-switch                                  | ⬜ หลัง judge 09-22               | 0   |

**Track แยก — EA_CORE_V1 framework** (MQL5 ที่ Codex สร้าง): foundation + Phase 0 spine deployed, Phase A MACD
spec เขียนแล้ว → ตัวถัดไป **ScaleExecutor Part B (pending-order pyramid)**. ยังเป็น proof-of-concept track คู่ขนาน.

**Post-deploy tooling pending:** `report_deals.mq5` + `parse_live_deals.ps1` (per-EA P&L by magic) — ต้องสร้างก่อน
judge 09-22 (ดู skill `ea-live-monitor`). กำลังทำใน Thread A.

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

## 7. ถัดไปทันที (2026-06-22)
1. 🔧 **Thread A (กำลังทำ):** สร้าง `report_deals.mq5` + `parse_live_deals.ps1` → per-EA P&L by magic (ก่อน judge 09-22)
2. 🔧 **Thread B:** EA_CORE ScaleExecutor Part B (pending-order pyramid)
3. ⏰ demo-monitor 8 EA จนถึง 2026-09-22 → ใช้สกิล `ea-live-monitor` ออก keep/kill verdict
4. ❌ หา signal ใหม่ = ปิดแล้ว (signal hunt exhausted)

> หมายเหตุ: section 4 ด้านบน (GSMC = 1 ตัว) เป็น log เก่า session ต้นๆ — portfolio จริง = 8 EA, ดู `DEMO_DEPLOYMENT_PLAN.md`
