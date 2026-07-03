# PROJECT_STATE — EA_LAB single living state (👉 AI START HERE)

> **last updated:** 2026-07-03 (รอบ 2 — direction alignment) · **updated by:** Claude Fable 5 · **owner:** patip (p.atipayoon@gmail.com)
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
| ภาพใหญ่/ปรัชญาโรงงานของเจ้าของ | **VISION.md** | link |
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

## 1. เป้าหมาย + ภาพรวม 4 ชั้น (โรงงาน 1 + แม่พิมพ์ 1 + คลังอะไหล่ 1 → พอร์ตจริง)

> **เป้าหมายสูงสุด:** 10 พอร์ต × 2–3 EA ที่ **ไม่ correlate กัน** × 10,000 cent → passive income.
> **ภาพใหญ่/ปรัชญาโรงงานของเจ้าของ → `VISION.md`** (อ่านคู่ไฟล์นี้ทุก session — ถ้างานขัดกับ VISION ให้หยุดถามเจ้าของ)

| ชื่อ | ที่อยู่จริง | บทบาท (aligned 2026-07-03) | สถานะ % |
|---|---|---|---|
| **EA_LAB** | `D:\EA_LAB` (repo นี้) | โรงงาน — หา/validate/deploy EA + automation pipeline | 85% โตเต็มวัย |
| **EA_Template (Boss V2)** | `D:\EA_LAB\ea_template` | **แม่พิมพ์หลักตัวเดียวของโรงงาน** (UNFREEZE 2026-07-03) — function กลางร่วมกัน (MM/lot/SL/grid/hedge/recovery) ต่างแค่ entry+TF · งานผลิต EA ใหม่ทุกตัวออกจากที่นี่ | chassis เสร็จ · เหลือเติม Hedge/Recovery + smoke-regression |
| **EA_Project / EA_CORE** | `D:\EA_Project\CURRENT_BUILD` (CORE = engine) | **คลังอะไหล่ R&D** — ไม่ทิ้ง หยิบ module (เช่น ScaleExecutor pyramid) มาใส่แม่พิมพ์เมื่อต้องการ · TEMPLATE\ = ที่อยู่ standalone (ทางด่วนชั่วคราว — พิสูจน์ edge แล้วต้อง port เข้าแม่พิมพ์) | framework สมบูรณ์ · พักการพัฒนา จนกว่าจะพร้อม |
| **Live Portfolio** | account 10,000 cent (demo) | **เป้าหมายจริง** — เงินจริง | 20% (9 EA live ครบ, รอ judge) |

หมายเหตุ: "EA_Project" กับ "EA_CORE" = track เดียวกัน (Project = repo, Core = engine ข้างใน).

---

## 2. สถานะตอนนี้ (one-liner ต่อชั้น)

- **EA_LAB 90%** — pipeline ครบ (intake→smoke→IS/OOS→MC→corr→deploy). housekeeping ปิดครบทุกข้อ 2026-07-02:
  ~~fix path OneDrive→D:~~ ✅ + ~~รวม template ซ้ำ~~ ✅ + ~~ลบ ea_projects/Gold~~ ✅. เหลือ 10% =
  งานที่ผูกกับเวลาจริง (operate จนถึง judge, ขยายจาก 1→หลายพอร์ต) ไม่ใช่งานสร้างเพิ่ม.
  ✅ ทำแล้ว 2026-06-29: รวม central_results→portfolio · deprecate
  RUN_REGISTRY/_RESUME_HERE · anti-drift system (§0.5). ✅ 2026-06-29–30: qwen batch queue รันจบ
  (39 reports — baseline 9 EA, GR opt PF 2.35, MT4 goldgrid, split-period) → ✅ **review/ตัดสินครบแล้ว
  2026-07-02** (GR opt = null result, goldgrid = all fail, ดู §2 EA_CORE/signal hunt) (log: `QWEN_RUN_LOG.md`).
- **EA_CORE — บทบาทใหม่ 2026-07-03 = คลังอะไหล่ R&D (ดู VISION.md + Decision log):** loop ปิดแล้ว
  (2026-07-02, fallback invoked): STEP 1→5 เดินครบ.
  หลักฐานปิดเคส: STEP 2 A/B — signal v4 เพียวๆ PF 0.67 (overfit อยู่ที่ exit structure ไม่ใช่ signal) ·
  STEP 3 coarse grid **complete 48 combos → OOS PF<1.0 ทั้งหมด** (ดีสุด 0.87 บน M2 ฝั่ง optimistic).
  **ข้อสรุป: EA_CORE = R&D track** — framework สมบูรณ์เชิงวิศวกรรม (signals v2–v5, ScaleExecutor_v2,
  risk stack, regression 1417 PASS) พร้อม reuse เมื่อมี signal ที่มี edge จริง; **production = ST_EA03
  standalone** (live 9397/9398). replica 990010 บน demo = WATCH เก็บ data. ห้าม re-tune ตระกูล param นี้.
  gotchas ที่บันทึกไว้: LR1 ต้อง `InpAllowLiveOrders=true` ใน tester · optimizer genetic mode พัง ใช้
  Optimization=1 · portable python `tools/python312`. รายละเอียด → `EA_CORE_ST03_LOOP_PLAN.md` ·
  architecture guide → `docs/EA_CORE_AND_TEMPLATE_GUIDE.md`.
- **EA_Template (Boss V2) — UNFREEZE 2026-07-03 → แม่พิมพ์หลักตัวเดียว** (supersede freeze 2026-07-02
  ด้วยเหตุใหม่: ภาพจริงของเจ้าของเพิ่งถูก capture ใน `VISION.md` — แม่พิมพ์เดียว function กลางร่วมกัน
  ต่างแค่ entry+TF). chassis compile 0/0 วัดเชื่อถือได้อยู่แล้ว · **งานค้างเพื่อเป็นแม่พิมพ์เต็มตัว:**
  (1) เติม Hedge/Recovery module จริง (ตอนนี้เป็น stub ปิดไว้) (2) เพิ่ม smoke-regression ชุดเล็ก
  (backtest ค่าคงที่ 1 ชุด เทียบเลขเดิมทุกครั้งที่แก้ core) (3) port Zeus grid/LOG เข้าเป็น entry
  หลัง Zeus validate ผ่าน. architecture + วิธีใช้ → `docs/EA_CORE_AND_TEMPLATE_GUIDE.md`.
  หมายเหตุ: `modules\`(V1) vs `core\`(V2) ซ้ำโดยตั้งใจ ไม่ใช่ขยะ.
- **Live Portfolio 20%** — ✅ **9 EA live ครบแล้ว (user ยืนยัน deploy เสร็จ 2026-07-02)**. live clock เริ่ม 2026-06-22 →
  judge เร็วสุด **2026-09-22**. ⚠️ **ST03 replica (990010) = WATCH**: qwen rerun OOS ได้ **PF 0.86 (585 trades)**
  ขัดกับ 3.93 provisional เดิม — ต้อง re-confirm ด้วย locked .set ก่อนใช้เป็น baseline ตอน judge (คงไว้บน demo ได้
  เพราะ demo มีไว้จับ overfit). ตัวบล็อก = เวลา (รอ demo 3 เดือน) + ยังไม่ขยายจาก 1 → หลายพอร์ต.
- **Signal hunt — ⚠️ ไม่อิ่มตัวแล้ว หลัง 2026-07-03** เดิมเขียนว่า "98% อิ่มตัว รอไอเดียใหม่" (บรรทัดนี้
  **ล้าสมัย**) — concept เก่าที่ตายแล้วยังตายอยู่ (NR7/AsianRange/LNBREAK/EURCHF/Donchian/Keltner/
  Ichimoku/PrevDay/EMA-cross/SuperTrend/GR optimize/#20 Trend+Pyramid/MT4 goldgrid ทั้งหมด — ดูรายละเอียด
  ที่ `MASTER_BACKLOG.md`) **แต่มี candidate ใหม่จริงจากงาน 2026-07-03: `(Boss)_ZeusInspired_GridLog_rev01`
  บน AUDUSD/AUDJPY (ผ่าน IS/OOS จริง)** — ดู bullet ถัดไปนี้ + `ZEUS_GOLD_HEDGE_ANALYSIS.md` +
  `EA_SCORECARD_AND_REGISTRY.md` §FRESH TEMPLATE EAs
- **🆕 (2026-07-03) Zeus Gold Hedge V1.2 วิเคราะห์ + ต่อยอด — สรุปรวด:**
  วิเคราะห์ EA ปิด/ล็อคของ user (behavioral analysis เท่านั้น ไม่แตะไฟล์) → พบเป็น grid+martingale+hedge
  ที่ **ไม่มี stop loss เลย** → REJECT ทั้ง XAU/EU (score ต่ำ ไม่ใช่ hard gate — ดู rubric fix ด้านล่าง)
  → ออกแบบ EA ใหม่ `(Boss)_ZeusInspired_GridLog_rev01.mq5` (L3 redesign: ATR spacing, LOG lot, real SL,
  partial-close, DD-adaptive first lot) → screen 27 FX symbol (ไม่รวมทอง) → **AUDUSD (IS 1.63→OOS 1.78,
  retention 1.09) + AUDJPY (retention 0.87) = candidate ที่รอด IS/OOS จริง** · EURCAD/AUDCAD/AUDNZD
  ตกหลัง confirm เข้ม (ดูดีตอน screen ผิว แต่ล้มตอนวัดจริง) · corr AUDUSD/AUDJPY = 0.554 (WATCH, ใช้คู่กัน
  ได้แต่ลด lot) · EURJPY = diversifier เท่านั้น (corr ต่ำมากแต่ edge อ่อน) **ยังไม่ deploy — เหลือ Monte
  Carlo บน config ที่ scale แล้ว + ทดสอบเป็นพอร์ตรวมกันจริง** รายละเอียดเต็ม + ทุกตัวเลข →
  `ZEUS_GOLD_HEDGE_ANALYSIS.md` (มี timeline วันนี้ครบ §5.1-5.11)
- **🔧 (2026-07-03) แก้ methodology 2 จุด ตาม user feedback — มีผลกับ EA ทุกตัวไปข้างหน้า ไม่ใช่แค่ Zeus:**
  (1) `EA_SCORECARD_AND_REGISTRY.md` Step 0 hard-gate (uncapped grid/martingale) → เปลี่ยนเป็น score
  penalty −25pt (Step 0b) เหลือ hard gate จริงแค่ expired/locked-ex + structural non-function
  (2) **Model 2 (open price) ห้ามใช้รายงาน/จัดอันดับ PF เด็ดขาด — ใช้กรอง zero-trade เท่านั้น ตัวเลขที่
  โชว์ user ต้อง Model 1 (control points) ขึ้นไปเสมอ** — พิสูจน์คุณค่าจริงวันเดียวกัน จับ false-positive
  ได้ 3 ครั้ง (Zeus XAU M1 artifact PF1.89→M0 จริง1.01, AUDCAD M2 PF1.80→M1 จริง0.89, AUDNZD M2
  PF1.96→M1 จริง1.06) — บันทึกไว้ทั้ง `EA_SCORECARD_AND_REGISTRY.md` และ skill `backtest-optimize-rigor`
- **🆕 (2026-07-03) skill ใหม่ `locked-ea-analyzer`** — เก็บ methodology วิเคราะห์ EA ปิด/ล็อคทั้งหมดไว้ใช้ซ้ำ
  (string-entropy check, ดึง param จาก .set/.ini/Journal, infer behavior, web search, screen, optimize,
  validate) เรียกด้วย "วิเคราะห์ EA ตัวนี้อย่างละเอียด"

---

## 3. DECISION LOG — สิ่งที่ตัดสินใจไป (lock แล้ว อย่ารื้อโดยไม่มีเหตุใหม่)

| วันที่ | การตัดสินใจ | เหตุผล |
|---|---|---|
| 2026-06-29 | **EA_CORE track = ทางเลือก 2: ปิด loop ด้วย ST03 edge** | standalone หา edge เร็วกว่า แต่ ST03 มี edge จริงอยู่แล้ว → ใช้ปิด framework loop ให้ได้ EA deploy-able. แผน: `EA_CORE_ST03_LOOP_PLAN.md` |
| 2026-07-02 | **EA_CORE loop ปิดแล้ว — FALLBACK: EA_CORE = R&D, ST_EA03 standalone = production** | STEP 3 grid 48/48 combos OOS PF<1.0 (complete enum, M2 ฝั่ง optimistic) + STEP 2 signal เพียว PF 0.67 → ไม่มี durable set. ห้าม re-tune ตระกูลนี้โดยไม่มี signal ใหม่. หลักฐาน: `EA_CORE_ST03_LOOP_PLAN.md` STEP 5 |
| 2026-07-02 | **KAUFMAN_ER = CANDIDATE reserve · SUPERTREND XAU = PARKED** (ยังไม่ deploy) | re-confirm ผ่านทั้งคู่ แต่ corr ระหว่างกัน 0.946 = ตัวเดียวกัน → ถ้าจะ deploy เอา KER ตัวเดียว 0.01 lot (corr 0.75 vs BRK8). ดู EA_SCORECARD §VALIDATED RESERVE |
| 2026-07-02 | **EA_Template = FREEZE 100% เป็น smoke tool** | เครื่องมือเสร็จ วัดเชื่อถือได้ = จบงาน track; ไม่พัฒนา chassis ต่อ, ไอเดียใหม่ยังเสียบผ่าน Boss V2 ได้ (guide: `docs/EA_CORE_AND_TEMPLATE_GUIDE.md`) |
| 2026-07-02 | **ST03 replica (990010) = WATCH** | qwen rerun OOS PF 0.86 ขัด 3.93 provisional → ห้ามใช้เป็น baseline จนกว่า re-confirm ด้วย locked .set |
| 2026-07-03 | **Zeus Gold Hedge V1.2 (MT4) = REJECT ทั้ง XAU/EU** (score ต่ำ ไม่ใช่ hard gate — ดู rubric fix ด้านล่าง) → ต่อยอดเป็น `(Boss)_ZeusInspired_GridLog_rev01.mq5` (L3 redesign) | วิเคราะห์เต็ม: `ZEUS_GOLD_HEDGE_ANALYSIS.md` · registry: `EA_SCORECARD_AND_REGISTRY.md` · methodology → skill `locked-ea-analyzer` |
| 2026-07-03 | **แก้ scoring rubric: mechanism-risk hard-gate → score-penalty** + **Model 1 (control points) = ขั้นต่ำก่อน REJECT/DISQUALIFIED ใดๆ** (Model 2 = proof-of-concept เท่านั้น) | user-corrected — ป้องกัน reject EA ทิ้งก่อนวัดผลจริง. บันทึกใน `EA_SCORECARD_AND_REGISTRY.md` Step 0/0b + `backtest-optimize-rigor` skill. พิสูจน์คุณค่าทันที: จับ false-positive ได้ 2 ครั้งในวันเดียว (Zeus XAU Model 1 fill-artifact PF 1.89→Model 0 จริง 1.01; AUDCAD Model 2 PF 1.80→Model 1 จริง 0.89) |
| 2026-07-03 | **`(Boss)_ZeusInspired_GridLog_rev01` — AUDJPY = CANDIDATE แรกที่รอด** (PF 1.21 เท่ากันทั้ง Model 2/1 = ไม่ใช่ fill artifact; DD-scale เข้า 15% ได้ PF 1.91 net +$2,780/18mo) ยังไม่ IS/OOS/MC | AUDCAD ตกทั้ง baseline/tightened ที่ Model 1 — ทองถูกตัดออกทั้งหมดตามคำสั่ง user (Zeus family ไม่เหมาะกับ volatility ทอง) |
| 2026-07-03 | **Direction alignment (grill session): Boss V2 = แม่พิมพ์หลักตัวเดียว (UNFREEZE — supersede freeze 2026-07-02)** · EA_CORE = คลังอะไหล่ R&D (ไม่ทิ้ง ทำต่อเมื่อพร้อม) · standalone = ทางด่วนชั่วคราว ต้อง port เข้าแม่พิมพ์เมื่อพิสูจน์ edge | เหตุใหม่ที่ทำให้รื้อ decision เดิมได้: ภาพจริงของเจ้าของเพิ่งถูก capture ครั้งแรก (`VISION.md`) — แม่พิมพ์เดียว function กลางร่วม ต่างแค่ entry+TF · เจ้าของต้องเข้าใจระบบได้ทั้งตัว (EA_CORE อ่านไม่ออก = drift ซ้ำ) |
| 2026-07-03 | **โหมดงาน = dual-track ถาวร** (โรงงานเดินตลอด + operate คู่กัน) — ยกเลิกคำว่า "operate ล้วน" | แกนล่าที่ยังไม่อิ่มตัว = **กลไก×symbol** (Zeus พิสูจน์: edge มาจาก grid+LOG บน AUD ไม่ใช่ entry เทพ) — ที่อิ่มตัวคือ entry เดี่ยวเท่านั้น |
| 2026-07-03 | **Zeus: validate จบใน standalone ก่อน (MC + พอร์ตรวม) → PASS แล้วค่อย port เข้า Boss V2 เป็น pilot ของ workflow ใหม่ → deploy จากแม่พิมพ์** · 9 EA live ไม่แตะจนถึง judge | ไม่ทิ้งผล IS/OOS ที่ทำแล้ว · port ก่อน validate = ต้อง rerun ทั้งหมด · แตะ EA live = ทำลาย data การทดลอง |
| 2026-07-03 | **เพิ่ม `VISION.md`** = owner ของ "ภาพใหญ่/ปรัชญาโรงงาน" — AI ทุก session อ่านคู่ PROJECT_STATE, งานขัด VISION ให้หยุดถาม | root cause ของ drift = ภาพในหัวเจ้าของไม่เคยถูกเขียนเป็นไฟล์ → ทุก session ตีความจาก status ที่ drift ไปแล้ว |
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

### ✅ เสร็จแล้วครบ (2026-06-29 → 07-02) — งานสร้าง/หา edge จบรอบนี้แล้ว
- Deploy ครบ 3 รายการ → พอร์ต 9 EA live ✅
- EA_Template freeze 100% + เขียน `docs/EA_CORE_AND_TEMPLATE_GUIDE.md`
- **EA_CORE loop ปิดแล้ว (fallback):** STEP 1→5 ครบ, grid 48 combos ไม่เจอ durable set →
  EA_CORE = R&D, ST_EA03 standalone = production. ST03 replica re-confirm: OOS PF 0.86 = baseline จริง (WATCH)
- **KAUFMAN_ER/SUPERTREND ตรวจแล้ว** → CANDIDATE reserve / PARKED · **user decision 2026-07-02: เก็บไว้ก่อน
  ไม่ deploy** (ไอเดียอนาคต: ใช้ Kaufman ER เป็น regime/direction filter ให้ EA อื่น — ดู EA_SCORECARD)
- **Gold Reaper opt** = null result (StartLots ไม่มีผลจริงภายใต้ Risk=1234 mode) → live set คงเดิม
- **#20 Trend+Pyramid** = DEAD (XAU/GBP H4 ทั้ง single-entry และ pyramid) → ปิด TOP-8/10 shortlist ครบ
- **MT4 goldgrid** = ปิดเคส (Elephant/Mammoth artifact confirmed PF 85→1.41 DD 53.65%/yr ·
  GoldStuffV7 DQ ยืนยัน uncapped martingale DD 77%/yr) → gold-grid concept dead ทั้ง pool
- housekeeping ทั้งหมด: ลบ ea_projects/Gold ✅ · template ซ้ำเหลือตัวเดียว ✅ · portable python ✅ ·
  fix OneDrive→D: path ✅ · แก้ log data ที่เกือบหาย (qwen merge) ✅

**สรุปเดิม (2026-07-02, ล้าสมัยแล้ว):** ~~ไม่มีงาน "หา edge ใหม่" ค้างอยู่แล้ว~~ — **แก้ไข 2026-07-03
(direction alignment): โหมดถาวรจากนี้ = dual-track** — (1) โรงงานเดินตลอด: ล่า edge ผ่านแม่พิมพ์ Boss V2
(แกนใหม่ = กลไก×symbol) + งานค้าง Zeus (HANDOFF ด้านล่าง) + งานอัปเกรดแม่พิมพ์ (ด้านล่าง) ·
(2) operate 9 EA live คู่กันจนถึง judge. ดูปรัชญา → `VISION.md`

### 🔴 HANDOFF — ZeusInspired_GridLog (เริ่มต่อจากตรงนี้ session หน้า)

**สถานะ:** AUDUSD + AUDJPY ผ่าน IS/OOS จริงแล้ว (retention 1.09 / 0.87) — **ยังไม่ผ่าน Monte Carlo บน
sizing ที่ scale แล้ว และยังไม่เคยรันเป็นพอร์ตรวมกัน 2 symbol พร้อมกัน** ยังห้าม deploy

**งานที่เหลือ ตามลำดับที่ควรทำ:**
1. **Monte Carlo บน config ที่ DD-scale แล้วจริง** (AUDUSD 20x, AUDJPY 20x) — เครื่องมือพร้อมแล้ว
   `scripts/mt5_montecarlo.py` (แก้ UTF-16 bug แล้ว) รันกับ `_mt5_auto/reports/ZIGL_AUDJPY_lot20x_M1.htm`
   และ `ZIGL_AUDUSD_lot20x_M1.htm` ที่มีอยู่แล้ว (ไม่ต้องรัน backtest ใหม่)
2. **รัน AUDUSD+AUDJPY เป็นพอร์ตรวมกันจริง** (2 instance คนละ magic บนบัญชีเดียวกัน) เทียบ equity curve
   รวมกับแยกกัน — corr 0.554 (WATCH tier) แปลว่าควรลด lot ทั้งคู่ ไม่ใช่รันเต็ม lot แยกกัน
3. **GBPAUD/USDJPY/EURCHF** ยังบางเกิน (12-18 เทรด) — ถ้าจะเก็บต่อ ต้องรอ history ยาวขึ้นหรือหา window อื่น
   เพิ่ม ไม่ใช่เชื่อจากเทรดน้อยแบบนี้
4. **ก่อน deploy จริง:** ผ่าน `robustness-validator` skill ให้ครบ (ยังไม่เคยเรียก skill นี้กับ EA ตัวนี้เลย)
   + สร้าง magic number ใหม่ (990101/990102 มีอยู่แล้วใน .set แต่ยังไม่จองในระบบ live)
   + ตาม `vps-deploy-ops` checklist ปกติ (ยังไม่ได้ build deploy bundle)
5. **(ใหม่ 2026-07-03) ถ้า validate ผ่านทั้งหมด → port เข้า Boss V2 เป็น `Entry_GridLog` ก่อน deploy**
   (Zeus = pilot ของ workflow "standalone → แม่พิมพ์" ตาม VISION) — port แล้วต้อง re-confirm เลข
   ตรงกับ standalone เดิมก่อนถือว่า port สำเร็จ · deploy จากแม่พิมพ์ ไม่ใช่จากร่าง standalone

### 🔧 งานอัปเกรดแม่พิมพ์ Boss V2 (track ใหม่ 2026-07-03 — ทำขนานกับ Zeus ได้)

1. เติม **Hedge/Recovery module จริง** (ตอนนี้เป็น stub ปิดไว้ใน `ea_template\core\`)
2. เพิ่ม **smoke-regression ชุดเล็ก** — backtest ค่าคงที่ 1 ชุดทุกครั้งที่แก้ core แล้วเทียบเลขเดิม
   (ทดแทน test suite ที่ Boss V2 ไม่มี)
3. หลังจากนั้น: sweep แกน **กลไก×symbol** (grid/DCA/hedge/progression บนคู่เงินที่ยังไม่เคยลอง)
   ผ่าน `/signal-scan` ตามปกติ

**ไฟล์ที่เกี่ยวข้องทั้งหมด:**
- EA source: `D:\EA_Project\CURRENT_BUILD\TEMPLATE\(Boss)_ZeusInspired_GridLog_rev01.mq5`
- .set variants ทั้งหมด (baseline/tightened/scaled): `D:\EA_Project\CURRENT_BUILD\TEMPLATE\ZeusInspired_*.set`
- ผลทดสอบทั้งหมด: `D:\EA_LAB\_mt5_auto\reports\ZIGL_*.htm` + `D:\EA_LAB\_mt5_auto\ZIGL_*.csv`
- Correlation script: `D:\EA_LAB\_mt5_auto\zigl_correlation.py`
- Monte Carlo script: `D:\EA_LAB\scripts\mt5_montecarlo.py`
- วิเคราะห์เต็ม + timeline: `ZEUS_GOLD_HEDGE_ANALYSIS.md` · registry: `EA_SCORECARD_AND_REGISTRY.md`
  §FRESH TEMPLATE EAs

**Gotcha ที่ต้องรู้ก่อนรันต่อ (เจอมาแล้ววันนี้ อย่าเจอซ้ำ):**
- `_04_TpUsd` เป็นดอลลาร์คงที่ ไม่ scale ตาม lot อัตโนมัติ — ขยาย `_05_BaseLot` ต้องขยาย `_04_TpUsd` +
  `_06_MaxTotalLot` ตามสัดส่วนเดียวกันเสมอ ไม่งั้น strategy เปลี่ยนพฤติกรรม ไม่ใช่แค่ขนาดเปลี่ยน
- **ห้ามรายงาน/ตัดสินใจจาก Model 2 (open price) เด็ดขาด** ใช้กรอง zero-trade เท่านั้น ทุกเลขที่จะเชื่อ
  ต้อง Model 1 (control points) ขึ้นไป
- MT5 headless run ไม่ผ่าน `-SetFile` = อาจ carry-over ค่าจาก run ก่อนหน้า ไม่ใช่ compiled default เสมอไป
  ต้องส่ง .set ระบุค่าครบทุกครั้ง

### 🟣 ถึง 2026-09-22 (judge) — track operate (9 EA เดิม — เดินคู่กับโรงงาน ไม่ใช่โหมดเดียว)
- /ea-monitor ทุก 1–2 สัปดาห์ (ส่ง live_deals.csv) — จับตา Gold Reaper, MG grid DD, ST03 replica (คาดว่าจะ kill),
  KAUFMAN_ER ถ้า user ตัดสินใจ deploy ระหว่างทาง
- สะสม ≥30 real trades/EA

### 🟢 หลัง 2026-09-22
- per-EA attribution → promote ตัวผ่าน (PF≥1.40, ≥30 trades) → เพิ่ม lot / เปิดพอร์ตที่ 2 → มุ่ง 10 พอร์ต
- ถ้ามีไอเดีย signal ใหม่เข้ามา (นอก TOP-8/10 shortlist เดิม) → /signal-scan ตามปกติ

---

## 8. CANONICAL DOCS INDEX (ของละเอียดอยู่ที่ไหน)

| ต้องรู้เรื่อง | เปิดไฟล์ |
|---|---|
| สถานะ + แผนนี้ (hub) | **`PROJECT_STATE.md`** (ไฟล์นี้) |
| ภาพใหญ่/ปรัชญาโรงงานของเจ้าของ | **`VISION.md`** (อ่านคู่กันทุก session) |
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
