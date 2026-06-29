# PROJECT_STATE — EA_LAB single living state (👉 AI START HERE)

> **last updated:** 2026-06-29 · **updated by:** Claude (Opus) · **owner:** patip (p.atipayoon@gmail.com)
>
> ไฟล์นี้ = **จุดเริ่มต้นเดียว** ที่ AI/session ใดก็ตามต้องอ่านก่อน เพื่อให้เข้าใจโปรเจกต์
> "เท่ากับคนที่ทำมาก่อน" โดยไม่ต้องไล่อ่าน 20 ไฟล์. ของละเอียดอยู่ใน canonical docs (section 8) —
> ไฟล์นี้ไม่ duplicate แต่ **ชี้ทาง + เก็บ decision + เก็บ protocol + เก็บแผนต่อ.**

---

## 0. UPDATE PROTOCOL — กฎการดูแลไฟล์นี้ (อ่าน + ทำทุก session)

1. **เปิดไฟล์นี้ก่อนเสมอ** เมื่อเริ่ม session ใหม่ (ก่อน README, ก่อน MASTER_BACKLOG).
2. **จบงานใหญ่ทุกครั้ง → อัปเดตไฟล์นี้:** แก้ section ที่เกี่ยว, bump `last updated`, เพิ่มบรรทัดใน
   Decision log (section 3) ถ้ามีการตัดสินใจใหม่, อัปเดต Forward plan (section 7).
3. **ความจริงอยู่ในไฟล์ ไม่ใช่ใน chat** — สิ่งที่ไม่ถูกเขียนลงที่นี่/canonical docs = หายเมื่อ session จบ.
4. **อย่า duplicate เนื้อหา** — ถ้ามีอยู่ใน DEMO_DEPLOYMENT_PLAN / MASTER_BACKLOG / EA_SCORECARD แล้ว
   ให้ลิงก์ไป ไม่ก็อปมาทั้งก้อน (กันข้อมูลขัดกันเอง). ที่นี่เก็บแค่ "สรุป + ตัวชี้".
5. **commit git ทุกครั้งที่แก้ไฟล์นี้** (ไฟล์นี้คือ memory ข้ามคน/ข้าม AI).

---

## 1. เป้าหมาย + ภาพรวม 4 ชั้น (โรงงาน 1 + เครื่องยนต์ 1 + แม่พิมพ์ 1 → พอร์ตจริง)

> **เป้าหมายสูงสุด:** 10 พอร์ต × 2–3 EA ที่ **ไม่ correlate กัน** × 10,000 cent → passive income.

| ชื่อ | ที่อยู่จริง | บทบาท | สถานะ % |
|---|---|---|---|
| **EA_LAB** | `D:\EA_LAB` (repo นี้) | โรงงาน — หา/validate/deploy EA + automation pipeline | 85% โตเต็มวัย |
| **EA_Project / EA_CORE** | `D:\EA_Project\CURRENT_BUILD` (CORE = engine) | เครื่องยนต์ framework MQL5 (ปั๊ม EA หลายตัวจาก chassis เดียว) | 70% ยังไม่เทรดจริง |
| **EA_Template** | `D:\EA_LAB\ea_template` (Boss V2 chassis) | แม่พิมพ์ — เสียบ signal เข้า chassis เดียว backtest เร็ว | 90% เครื่องมือพร้อม / 0 edge |
| **Live Portfolio** | account 10,000 cent (demo) | **เป้าหมายจริง** — เงินจริง | 18% (1 พอร์ต, demo เดิน) |

หมายเหตุ: "EA_Project" กับ "EA_CORE" = track เดียวกัน (Project = repo, Core = engine ข้างใน).

---

## 2. สถานะตอนนี้ (one-liner ต่อชั้น)

- **EA_LAB 85%** — pipeline ครบ (intake→smoke→IS/OOS→MC→corr→deploy). เหลือ housekeeping (fix path
  OneDrive→D:, รวม template ซ้ำ, รวม central_results+portfolio, ลบ RUN_REGISTRY deprecated).
- **EA_CORE 70%** — Phases A–J เสร็จ, signals v2–v4, LotSizer. **อัปเดต 2026-06-29:** entry v4 ✅ +
  **ScaleExecutor_v2 (limit-order pyramid) เขียนเสร็จ+wired+compile แล้ว** (ไม่ใช่ v1 market อีก).
  แต่ **ผล validate ปัจจุบัน = overfit รุนแรง** (ST03B "TG": IS PF 7.08 → WF/stress 0.19–0.32 พังหมด).
  งานจริงเหลือ = **diagnose overfit + หา durable set** (ไม่ใช่เขียน executor). แผนรัน Sonnet →
  `EA_CORE_ST03_LOOP_PLAN.md`. fallback ถ้าไม่ผ่าน = ship ST_EA03 .ex5 (trade อยู่แล้ว), EA_CORE = R&D.
- **EA_Template 90%** — chassis compile 0/0 รันถูก วัดเชื่อถือได้ = **งานเสร็จ**. optimize 0/7 มี edge
  (MA-cross ไม่มี edge). **ใช้เป็นเครื่องมือ smoke ไอเดีย ไม่เพิ่ม signal ใหม่.**
- **Live Portfolio 18%** — 7 EA active + 2 รอ deploy (วันนี้). live clock เริ่ม 2026-06-22 →
  judge เร็วสุด **2026-09-22**. ตัวบล็อก = เวลา (รอ demo 3 เดือน) + ยังไม่ขยายจาก 1 → หลายพอร์ต.
- **Signal hunt ~90% อิ่มตัว** — concept ใหม่ตายเกือบหมด (NR7/AsianRange/LNBREAK/EURCHF/Donchian/
  Keltner/Ichimoku/PrevDay/EMA-cross/SuperTrend = DEAD). เหลือช่องแคบ: GR optimize, MT4 goldgrid,
  #20 Trend+Pyramid. รายละเอียดเต็ม → `MASTER_BACKLOG.md`.

---

## 3. DECISION LOG — สิ่งที่ตัดสินใจไป (lock แล้ว อย่ารื้อโดยไม่มีเหตุใหม่)

| วันที่ | การตัดสินใจ | เหตุผล |
|---|---|---|
| 2026-06-29 | **EA_CORE track = ทางเลือก 2: ปิด loop ด้วย ST03 edge** | standalone หา edge เร็วกว่า แต่ ST03 มี edge จริงอยู่แล้ว → ใช้ปิด framework loop ให้ได้ EA deploy-able. แผน: `EA_CORE_ST03_LOOP_PLAN.md` |
| 2026-06-29 | **PROJECT_STATE.md = living doc กลาง** | ให้ AI ทุกตัวเข้าใจตรงกัน (user request) |
| 2026-06-23 | **DD% ไม่ใช่ hard gate** | DD แก้ได้ด้วย sizing/spacing; structural gate คือ "กลไก" (uncapped martingale/grid). ดู EA_SCORECARD Step 0 |
| ongoing | **correlation rule:** ≤0.40 additive · 0.40–0.60 watch · >0.60 redundant → **ลด lot ไม่ใช่ตัดทิ้ง** | user rule (memory: correlation-vs-lotsize) |
| ongoing | **backtest window = 3 ปี (2023–2026)** · re-opt ทุก 6 เดือน · ห้ามยืดเป็น 10 ปีเพื่อ "แก้ MC" | memory: backtest-window |
| ongoing | **demo ≥3 เดือน ห้ามลัด** ก่อน live micro | README กฎเหล็ก |

---

## 4. LIVE PORTFOLIO (สรุป — detail เต็มที่ `DEMO_DEPLOYMENT_PLAN.md`)

account เดียว 10,000 cent · judge **2026-09-22** · attribution key = **(magic, symbol)**.

| # | EA | Symbol/TF | Magic | OOS PF | สถานะ |
|---|---|---|---|---|---|
| 1 | Matchagrid MG_v1 | CHFJPY M15 | (read .set) | 2.08 | 🟢 LIVE |
| 2 | NuiIndy RSI+ADX | EURUSD H1 | 1524 | 2.00 | 🟢 LIVE |
| 3 | ST_EA03 MACD | GBPUSD H1 | 9397 | 2.47 | 🟢 LIVE |
| 4 | ST_EA03 MACD | USDCAD H1 | 9398 | 2.62 | 🟢 LIVE |
| 5 | Gold Reaper 4.3 | XAUUSD H1 | (default/GUI) | 2.07 | 🟢 LIVE |
| 6 | EA_BREAKOUT_XAU (Bars55) | XAUUSD H1 | 991001 | 2.94–4.87 | 🟡 RELOAD v3 (วันนี้) |
| 7 | LondonConsoBreakout | GBPUSD H1 | 990005 | 2.08 | 🟢 LIVE |
| 9 | EA_RUNNER_ST03 (replica) | GBPUSD H1 | 990010 | 3.93 | 🟡 DEPLOY วันนี้ |
| 10 | EA_BREAKOUT_XAU (Bars8) | XAUUSD H1 | 991002 | 3.92 | 🟡 DEPLOY วันนี้ |

(#8 CB_EUR EURUSD = ❌ DROPPED 2026-06-25, no durable edge. พอร์ตจริง = 9 EA หลัง deploy วันนี้.)

วันนี้ทำตาม → **`DEPLOY_CHECKLIST_2026-06-29.md`** (step-by-step + verify).

---

## 5. PORTFOLIO CONSTRUCTION RULES (วิธีวางแผนใช้ EA)

- **กี่ EA ต่อ 1 พอร์ต:** 2–3 EA ที่ corr ต่ำ คือ sweet spot (เป้าหมายตั้งต้น). รันพร้อมกันได้หลายตัว
  บน account เดียว ตราบใดที่ **magic ไม่ชน** + รวม risk ไม่เกิน budget. ตอนนี้ทดลอง 9 EA บน 1 account
  เพื่อเก็บ data — หลัง judge ค่อยแตกเป็นพอร์ตจริง 2–3 ตัว/พอร์ต.
- **correlation gate (monthly Pearson, `_mt5_auto/corr_monthly.py`):** ≤0.40 = additive (รับเข้า) ·
  0.40–0.60 = watch (รับได้แต่ลด lot) · >0.60 = redundant (ลด lot / ไม่เพิ่มเป็น leg ที่ 2 ของ exposure เดิม).
- **ป้องกันพอร์ต (3 ชั้น):** (1) hard SL/DD cap ต่อ EA · (2) corr-diversify ให้ DD ไม่ลงพร้อมกัน ·
  (3) total deposit-load cap ต่อ account (กัน grid/pyramid กินมาร์จิ้นพร้อมกัน). DD budget เป้าหมาย 10–15%.
- **risk per port:** ไม่เกินที่กำหนดต่อ account; EA grid/pyramid (MG, ST_EA03) ใช้ report DD + every-tick
  ไม่ใช่ MC อย่างเดียว (floating DD ซ่อน).
- **strategy mix ที่ดี:** ผสม class ที่ไม่ลงพร้อมกัน — breakout (trending) + reversion (range) + grid +
  scalper (anti-corr). พอร์ตปัจจุบันมีครบ class แล้ว → เน้นกระจาย **instrument/session** เพิ่ม.

---

## 6. MONITORING PROTOCOL (ของพร้อมแล้ว — ไม่ต้องส่งเลข port)

> **MT5 account report (HTML/XLSX) ทิ้ง magic ต่อ deal → ใช้ทำ attribution ไม่ได้.** ต้อง export ผ่าน
> MQL5 script ที่อ่าน `DEAL_MAGIC` แทน. ทุกอย่าง build + tested แล้ว.

**ขั้นตอน (ส่งให้ AI ตรวจ):**
1. ใน MT5 (เครื่อง/VPS ที่รัน demo): ก็อป `D:\EA_LAB\scripts\report_deals.mq5` → `<DataDir>\MQL5\Scripts\`
   → refresh Navigator → ลากลงชาร์ตไหนก็ได้ → ตั้ง `InpFromDate=2026.06.22` → run.
2. มันเขียน **`live_deals.csv`** ลง `Common\Files\` (path โชว์ใน Experts log). คอลัมน์:
   `time,ticket,magic,symbol,type,entry,volume,price,profit,swap,commission,net,comment`.
3. **ส่งไฟล์ `live_deals.csv` นี้ให้ AI** (วางใน `_mt5_report_drop/` หรือแนบมา). AI รัน
   `parse_live_deals.ps1 -Path <csv>` → roll-up per (magic,symbol) → เทียบ backtest → KEEP/WATCH/PAUSE/KILL.
4. trigger ในแชต: **`/ea-monitor`** (skill `ea-live-monitor` จะจัดการ step 3–5).

→ **ตอบ user:** ไม่ต้องส่งเลข port. ส่ง **`live_deals.csv`** อย่างเดียวพอ. ทำทุก 1–2 สัปดาห์.

---

## 7. FORWARD PLAN (today → judge → after)

### 🔴 วันนี้ (จ. 2026-06-29) — `DEPLOY_CHECKLIST_2026-06-29.md`
Deploy 3 จังหวะใน MT5 GUI (~15 นาที): reload #6 v3 · ST03 replica (990010) · Bars8 (991002).

### 🟡 สัปดาห์นี้
- Gold Reaper optimize (plateau-check, MASTER_BACKLOG TASK 4)
- MT4 goldgrid Phase 1 (~5 นาที, `MT4_GOLDGRID_RETEST_PLAN.md`)
- #20 Trend+Pyramid generate → /signal-scan (`STRATEGY_200_ANALYSIS.md`)
- EA_CORE loop: เริ่ม ScaleExecutor Part B (`EA_CORE_ST03_LOOP_PLAN.md`)
- housekeeping LAB (fix path, รวม template, ลบ ea_projects/Gold)

### 🟣 ถึง 2026-09-22 (judge)
- /ea-monitor ทุก 1–2 สัปดาห์ (ส่ง live_deals.csv) — จับตา Gold Reaper, MG grid DD, ST03 replica 30 trades แรก
- สะสม ≥30 real trades/EA
- ปิด EA_CORE ST03 loop ให้ได้ deployable framework EA

### 🟢 หลัง 2026-09-22
- per-EA attribution → promote ตัวผ่าน (PF≥1.40, ≥30 trades) → เพิ่ม lot / เปิดพอร์ตที่ 2 → มุ่ง 10 พอร์ต

---

## 8. CANONICAL DOCS INDEX (ของละเอียดอยู่ที่ไหน)

| ต้องรู้เรื่อง | เปิดไฟล์ |
|---|---|
| สถานะ + แผนนี้ (hub) | **`PROJECT_STATE.md`** (ไฟล์นี้) |
| deploy วันนี้ | `DEPLOY_CHECKLIST_2026-06-29.md` |
| EA_CORE ปิด loop ด้วย ST03 | `EA_CORE_ST03_LOOP_PLAN.md` |
| live portfolio (source of truth) | `DEMO_DEPLOYMENT_PLAN.md` |
| backlog + coverage matrix เต็ม | `MASTER_BACKLOG.md` |
| ทะเบียน EA + scoring rubric + kill-reason | `EA_SCORECARD_AND_REGISTRY.md` |
| แผนที่ไฟล์/5 ที่อยู่ | `PLATFORM_INDEX.md` · `README.md` |
| design "สมอง" (scoring/gate/optimize) | `docs/RECOVERED_PLATFORM_DESIGN_20260614.md` |
| automation/MT5 headless | `AUTOMATION_GUIDE.md` · `docs/MT5_AUTOMATION.md` |
| รับ source ใหม่ | `INTAKE_QUEUE.md` |
| idea จาก 200-prompt PDF | `STRATEGY_200_ANALYSIS.md` |

---

## 9. กฎเหล็ก (ย้ำ)
- อย่าเชื่อ report เก่าบนดิสก์ — rerun ด้วย locked .set ก่อนตัดสินเสมอ.
- ปิด MT5 GUI ก่อนรัน automation (script abort ถ้าเปิด).
- ของก้อนใหญ่กลั่นด้วย script ไม่โหลดดิบเข้า context · ทุกงานใหญ่ commit git.
- grid/martingale ใช้ report DD + every-tick ไม่ใช่ MC อย่างเดียว.
- monitor metric (Myfxbook/Excel/FX Blue) = ดูเพื่อ "วิเคราะห์" เท่านั้น **ไม่ใช่ตัว reject EA** —
  การ reject ใช้ (magic,symbol) attribution + เทียบ backtest ตาม section 6 เท่านั้น.
