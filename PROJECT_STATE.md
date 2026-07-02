# PROJECT_STATE — EA_LAB single living state (👉 AI START HERE)

> **last updated:** 2026-07-02 · **updated by:** Claude (Fable) · **owner:** patip (p.atipayoon@gmail.com)
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

## 0.5 ANTI-DRIFT — กันเอกสารเพี้ยน (ทำให้ "อ่านครั้งหน้า = ครั้งก่อน")

ปัญหาเดิม: หลายไฟล์อ้าง authority ทับกัน + เขียน fact เดียวซ้ำหลายที่ → อัปเดตมือแล้วเพี้ยน. กฎ 3 ข้อ:

**1) 1 fact มี owner เดียว** — fact อยู่ไฟล์เดียว ที่อื่น **link ห้าม copy**:

| fact | owner เดียว | ที่อื่นทำได้ |
|---|---|---|
| สถานะ% · decision · แผน · invariants | **PROJECT_STATE.md** (นี่) | link |
| live portfolio (EA/magic/lot/judge/monitor) | **DEMO_DEPLOYMENT_PLAN.md** | link |
| backlog · coverage · hunt | **MASTER_BACKLOG.md** | link |
| ทะเบียน EA · scoring · kill-reason | **EA_SCORECARD_AND_REGISTRY.md** | link |
| แผนที่ไฟล์ · 5 ที่อยู่ | **PLATFORM_INDEX.md** | link |
| EA_CORE framework | `D:\EA_Project` docs + `EA_CORE_ST03_LOOP_PLAN.md` | link |

ถ้า 2 ไฟล์พูดเรื่องเดียวต่างกัน → **INVARIANTS (ข้อ 3) ชนะ** แล้วแก้ไฟล์ที่ผิดทันที.

**2) PROJECT_STATE = entry เดียว** — ไฟล์อื่นห้ามเขียน "เปิดไฟล์นี้ไฟล์เดียวพอ". secondary doc ขึ้นต้นด้วย
banner: `> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: <X เท่านั้น>`.

**3) INVARIANTS — fact ที่ต้องตรงทุกที่ (ที่ไหนเขียนต่าง = ที่นั่นผิด):**
- live portfolio = **9 EA** บน **1 account 10,000 cent** (#8 CB_EUR dropped)
- live clock start **2026-06-22** · judge **2026-09-22**
- backtest window **2023–2026** · re-opt ทุก 6 เดือน
- **magic map (ห้ามชน):** 1524=NuiIndy · 9397=ST_EA03 GBP · 9398=ST_EA03 CAD · 990005=CB_GBP ·
  990010=ST03 replica · 991001=BRK Bars55 · 991002=BRK Bars8 · MG_v1+GoldReaper=GUI default (ไม่อยู่ .set)
- **bot บังคับเอง:** git **pre-commit hook** (`.githooks/pre-commit`) รัน `scripts/check_state.ps1 -Strict`
  อัตโนมัติทุก commit → **block ถ้า hard-invariant เพี้ยน**. setup ครั้งเดียวต่อเครื่อง: `git config core.hooksPath .githooks`.
  bypass ฉุกเฉิน: `git commit --no-verify`. รันมือ: `powershell -File scripts/check_state.ps1`
  > ⚠️ **ขอบเขต guard:** คุมแค่ invariant เชิงโครงสร้างไม่กี่ตัว (entry เดียว · judge/start date · account ·
  > 9 EA · magic present · banner) — **ไม่ใช่เนื้อหาทั้งหมด** (PF, สถานะ EA, ตัวเลขอื่น ยังต้องอ่าน/อัปเดตมือ).
  > GUI commit client (VS Code ฯลฯ) อาจซ่อน output ของ hook — ถ้า commit ถูก block แบบงงๆ ให้รัน check มือดู.

---

## 1. เป้าหมาย + ภาพรวม 4 ชั้น (โรงงาน 1 + เครื่องยนต์ 1 + แม่พิมพ์ 1 → พอร์ตจริง)

> **เป้าหมายสูงสุด:** 10 พอร์ต × 2–3 EA ที่ **ไม่ correlate กัน** × 10,000 cent → passive income.

| ชื่อ | ที่อยู่จริง | บทบาท | สถานะ % |
|---|---|---|---|
| **EA_LAB** | `D:\EA_LAB` (repo นี้) | โรงงาน — หา/validate/deploy EA + automation pipeline | 85% โตเต็มวัย |
| **EA_Project / EA_CORE** | `D:\EA_Project\CURRENT_BUILD` (CORE = engine) | เครื่องยนต์ framework MQL5 (ปั๊ม EA หลายตัวจาก chassis เดียว) | **100% — loop ปิด (fallback): framework = R&D พร้อม reuse, ST_EA03 standalone = production** |
| **EA_Template** | `D:\EA_LAB\ea_template` (Boss V2 chassis) | แม่พิมพ์ — เสียบ signal เข้า chassis เดียว backtest เร็ว | **100% — FREEZE เป็น smoke tool** (2026-07-02) |
| **Live Portfolio** | account 10,000 cent (demo) | **เป้าหมายจริง** — เงินจริง | 20% (9 EA live ครบ, รอ judge) |

หมายเหตุ: "EA_Project" กับ "EA_CORE" = track เดียวกัน (Project = repo, Core = engine ข้างใน).

---

## 2. สถานะตอนนี้ (one-liner ต่อชั้น)

- **EA_LAB 85%** — pipeline ครบ (intake→smoke→IS/OOS→MC→corr→deploy). เหลือ housekeeping ข้อเดียว:
  fix path OneDrive→D: ใน `scripts/` (~~รวม template ซ้ำ~~ ✅ + ~~ลบ ea_projects/Gold~~ ✅ 2026-07-02).
  ✅ ทำแล้ว 2026-06-29: รวม central_results→portfolio · deprecate
  RUN_REGISTRY/_RESUME_HERE · anti-drift system (§0.5). ✅ 2026-06-29–30: qwen batch queue รันจบ
  (39 reports — baseline 9 EA, GR opt PF 2.35, MT4 goldgrid, split-period) → **ผลรอ Claude review/ตัดสิน**
  (log: `QWEN_RUN_LOG.md`).
- **EA_CORE 100% — LOOP ปิดแล้ว (2026-07-02, fallback invoked):** STEP 1→5 เดินครบ.
  หลักฐานปิดเคส: STEP 2 A/B — signal v4 เพียวๆ PF 0.67 (overfit อยู่ที่ exit structure ไม่ใช่ signal) ·
  STEP 3 coarse grid **complete 48 combos → OOS PF<1.0 ทั้งหมด** (ดีสุด 0.87 บน M2 ฝั่ง optimistic).
  **ข้อสรุป: EA_CORE = R&D track** — framework สมบูรณ์เชิงวิศวกรรม (signals v2–v5, ScaleExecutor_v2,
  risk stack, regression 1417 PASS) พร้อม reuse เมื่อมี signal ที่มี edge จริง; **production = ST_EA03
  standalone** (live 9397/9398). replica 990010 บน demo = WATCH เก็บ data. ห้าม re-tune ตระกูล param นี้.
  gotchas ที่บันทึกไว้: LR1 ต้อง `InpAllowLiveOrders=true` ใน tester · optimizer genetic mode พัง ใช้
  Optimization=1 · portable python `tools/python312`. รายละเอียด → `EA_CORE_ST03_LOOP_PLAN.md` ·
  architecture guide → `docs/EA_CORE_AND_TEMPLATE_GUIDE.md`.
- **EA_Template 100% — FREEZE (2026-07-02)** — chassis compile 0/0 รันถูก วัดเชื่อถือได้ = **track ปิดอย่างเป็นทางการ**:
  ใช้เป็น smoke tool เท่านั้น ไม่พัฒนา chassis ต่อ (ไอเดียใหม่เสียบผ่าน Boss V2 ได้ตามเดิม). architecture +
  วิธีใช้ → `docs/EA_CORE_AND_TEMPLATE_GUIDE.md`. หมายเหตุ: `modules\`(V1) vs `core\`(V2) ซ้ำโดยตั้งใจ ไม่ใช่ขยะ.
- **Live Portfolio 20%** — ✅ **9 EA live ครบแล้ว (user ยืนยัน deploy เสร็จ 2026-07-02)**. live clock เริ่ม 2026-06-22 →
  judge เร็วสุด **2026-09-22**. ⚠️ **ST03 replica (990010) = WATCH**: qwen rerun OOS ได้ **PF 0.86 (585 trades)**
  ขัดกับ 3.93 provisional เดิม — ต้อง re-confirm ด้วย locked .set ก่อนใช้เป็น baseline ตอน judge (คงไว้บน demo ได้
  เพราะ demo มีไว้จับ overfit). ตัวบล็อก = เวลา (รอ demo 3 เดือน) + ยังไม่ขยายจาก 1 → หลายพอร์ต.
- **Signal hunt ~90% อิ่มตัว** — concept ใหม่ตายเกือบหมด (NR7/AsianRange/LNBREAK/EURCHF/Donchian/
  Keltner/Ichimoku/PrevDay/EMA-cross/SuperTrend = DEAD). เหลือช่องแคบ: GR optimize, MT4 goldgrid,
  #20 Trend+Pyramid. รายละเอียดเต็ม → `MASTER_BACKLOG.md`.

---

## 3. DECISION LOG — สิ่งที่ตัดสินใจไป (lock แล้ว อย่ารื้อโดยไม่มีเหตุใหม่)

| วันที่ | การตัดสินใจ | เหตุผล |
|---|---|---|
| 2026-06-29 | **EA_CORE track = ทางเลือก 2: ปิด loop ด้วย ST03 edge** | standalone หา edge เร็วกว่า แต่ ST03 มี edge จริงอยู่แล้ว → ใช้ปิด framework loop ให้ได้ EA deploy-able. แผน: `EA_CORE_ST03_LOOP_PLAN.md` |
| 2026-07-02 | **EA_CORE loop ปิดแล้ว — FALLBACK: EA_CORE = R&D, ST_EA03 standalone = production** | STEP 3 grid 48/48 combos OOS PF<1.0 (complete enum, M2 ฝั่ง optimistic) + STEP 2 signal เพียว PF 0.67 → ไม่มี durable set. ห้าม re-tune ตระกูลนี้โดยไม่มี signal ใหม่. หลักฐาน: `EA_CORE_ST03_LOOP_PLAN.md` STEP 5 |
| 2026-07-02 | **KAUFMAN_ER = CANDIDATE reserve · SUPERTREND XAU = PARKED** (ยังไม่ deploy) | re-confirm ผ่านทั้งคู่ แต่ corr ระหว่างกัน 0.946 = ตัวเดียวกัน → ถ้าจะ deploy เอา KER ตัวเดียว 0.01 lot (corr 0.75 vs BRK8). ดู EA_SCORECARD §VALIDATED RESERVE |
| 2026-07-02 | **EA_Template = FREEZE 100% เป็น smoke tool** | เครื่องมือเสร็จ วัดเชื่อถือได้ = จบงาน track; ไม่พัฒนา chassis ต่อ, ไอเดียใหม่ยังเสียบผ่าน Boss V2 ได้ (guide: `docs/EA_CORE_AND_TEMPLATE_GUIDE.md`) |
| 2026-07-02 | **ST03 replica (990010) = WATCH** | qwen rerun OOS PF 0.86 ขัด 3.93 provisional → ห้ามใช้เป็น baseline จนกว่า re-confirm ด้วย locked .set |
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
| 1 | Matchagrid MG_v1 | CHFJPY M15 | (GUI default) | 2.08 | 🟢 LIVE |
| 2 | NuiIndy RSI+ADX | EURUSD H1 | 1524 | 2.00 | 🟢 LIVE |
| 3 | ST_EA03 MACD | GBPUSD H1 | 9397 | 2.47 | 🟢 LIVE |
| 4 | ST_EA03 MACD | USDCAD H1 | 9398 | 2.62 | 🟢 LIVE |
| 5 | Gold Reaper 4.3 | XAUUSD H1 | (default/GUI) | 2.07 | 🟢 LIVE |
| 6 | EA_BREAKOUT_XAU (Bars55) | XAUUSD H1 | 991001 | 2.94–4.87 | 🟢 LIVE (v3 reloaded) |
| 7 | LondonConsoBreakout | GBPUSD H1 | 990005 | 2.08 | 🟢 LIVE |
| 9 | EA_RUNNER_ST03 (replica) | GBPUSD H1 | 990010 | 3.93* | 🟠 LIVE — **WATCH** |
| 10 | EA_BREAKOUT_XAU (Bars8) | XAUUSD H1 | 991002 | 3.92 | 🟢 LIVE |

(#8 CB_EUR EURUSD = ❌ DROPPED 2026-06-25, no durable edge. พอร์ตจริง = 9 EA — deploy ครบ ✅ 2026-07-02.)

> ***3.93 = คนละ window, ไม่ใช้เป็น baseline (verified 2026-07-02)** — 3.93 มาจาก OOS window รอบ 06-26
> (regime ดี, ดู scorecard WFA "regime-dependent"). qwen rerun ด้วย ini ตรง locked set
> (LR2·Tp3=50·Nearby=50·Mode2·Model 4·**full OOS 2025.01–2026.06**) = **PF 0.86 (585 trades)** ซึ่งตรง
> regime ปัจจุบัน → **baseline เทียบ live ใช้ 0.86**. คงไว้บน demo เก็บ data ถึง judge ได้ แต่คาดหวัง =
> ใกล้ศูนย์/ลบ · สถานะ = WATCH (ตัวเก็ง kill แรก). loop ปิดแล้ว → `EA_CORE_ST03_LOOP_PLAN.md` STEP 5.

deploy ทำตาม `DEPLOY_CHECKLIST_2026-06-29.md` → ✅ เสร็จครบ 3 รายการ (user ยืนยัน 2026-07-02).

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

### ✅ เสร็จแล้ว (2026-06-29 → 07-02)
- Deploy ครบ 3 รายการ → พอร์ต 9 EA live ✅ · qwen batch queue รันจบ (GR opt, MT4 goldgrid, baseline, splits)
- EA_Template freeze 100% + เขียน `docs/EA_CORE_AND_TEMPLATE_GUIDE.md`

### ✅ ปิดแล้ว 2026-07-02 — EA_CORE loop (STEP 1→5 ครบ, fallback invoked)
- STEP 2 A/B + STEP 3 grid 48 combos → ไม่มี durable set → EA_CORE = R&D, ST_EA03 standalone = production
- ST03 replica re-confirm แล้ว: OOS PF 0.86 = baseline จริง (WATCH บน demo)
- KAUFMAN_ER/SUPERTREND ตรวจแล้ว → CANDIDATE reserve / PARKED (ดู decision log — **รอ user ตัดสินใจ deploy KER หรือไม่**)
- housekeeping: ลบ ea_projects/Gold ✅ · template ซ้ำเหลือตัวเดียว ✅ · portable python ✅

### 🟡 คิวรอง (สัปดาห์นี้/ถัดไป)
- Review ผล qwen ที่ค้าง: GR opt plateau-check (PF 2.35 — memory 06-28 ระบุ default FF2 อยู่บน plateau แล้ว → ยืนยัน+บันทึกลง scorecard) · GG Elephant = artifact DQ · GG Mammoth 5.10 ยังไม่ตัดสิน · GoldStuffV7 = DQ
- #20 Trend+Pyramid generate → /signal-scan (`STRATEGY_200_ANALYSIS.md`)
- housekeeping LAB ที่เหลือ: fix path OneDrive→D: ใน `scripts/`

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
| สถาปัตยกรรม+วิธีใช้ EA_CORE / EA_Template | `docs/EA_CORE_AND_TEMPLATE_GUIDE.md` |
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
