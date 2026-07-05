# PROJECT_STATE — EA_LAB single living state (👉 AI START HERE)

> **last updated:** 2026-07-04 (รอบ 6 — ORDER-021/022/023 ครบทั้ง 3, ทำเองแทน Codex/ZCode ที่ token หมด) · **updated by:** Claude Fable 5 · **owner:** patip (p.atipayoon@gmail.com)
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
| กติกา multi-agent (Claude/Codex/ZCode) | **AGENTS.md** | link |
| คิวงานกลาง + ผลดิบรอ review | **AGENT_TASKBOARD.md** | link |
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
| 2026-07-03 | **user rule: ห้ามตัดสิน DEAD/REJECT จนกว่าจะลอง optimize จริง** — verdict จาก param ชุดเดียว = PARKED-pending-optimize เสมอ | user-corrected ระหว่าง Boss_14 sweep — **พิสูจน์คุณค่าภายในชั่วโมงเดียว: 3/4 symbol ที่ถูกเรียก DEAD/REJECT ฟื้นหลัง probe 54-pass** (EURJPY 0.83→2.49 · EURCAD 0.65→1.82 · USDJPY 1.00→1.51) เหลือ EURCHF ตายจริง (0/54). ดู EA_SCORECARD §FRESH TEMPLATE |
| 2026-07-03 | **ROADMAP.md เกิดขึ้น (user parameters: จบ=ระบบหมุนเอง · 10 account แยกจริง · live micro ทันทีหลัง judge · เวลา user 2–4 วัน/สัปดาห์)** — gate เลื่อนเฟสผูกกับ bench/หลักฐาน ไม่ใช่วันที่ · **Model transition: Fable → Opus หลัง 2026-07-07** (role อยู่ที่ seat ไม่ใช่ model — protocol ใน CLAUDE.md) | user ต้องการแผนจนจบเพื่อ delegate ให้ Codex/ZCode ต่อได้ + Fable access หมด 7 ก.ค. |
| 2026-07-03 | **Multi-agent protocol: Claude = lead/judge เท่านั้น · Codex = peer engineer · ZCode = batch runner · ส่งไม้ผ่าน `AGENT_TASKBOARD.md` (order + acceptance criteria) · single-writer: VISION/Decision log/verdict = Claude/user เท่านั้น** | user ใช้ 3 agent ร่วมกัน (Claude quota จำกัด) — กัน "คนอื่นทำต่อแล้วพัง" ด้วย: order เล็ก+ตรวจได้ด้วยตัวเลข · agent อื่นผลิตหลักฐานไม่ตัดสิน · cage (check_state/tpl_regression) เป็น agent-agnostic · Claude กลับมาต้อง review ก่อน build ต่อ. กติกาเต็ม → `AGENTS.md` |
| 2026-07-03 | **user rule: cap breach (DD/margin/deposit-load/MC-ruin) = resize-first ห้าม reject ตรงๆ** — reject จาก cap ได้เฉพาะเมื่อ (1) resize เข้า band แล้ว edge หลุด gate (2) ถึง min-lot แล้วยังเกิน (3) optimize probe ไม่เจอ config ที่เข้า band (4) ไม่เปิดไม้เลย · ส่วน fail เชิง edge (PF หลุด gate) reject ตรงได้เพราะ PF ไม่ขึ้นกับ scale | ขยาย decision 2026-06-23 ("DD ไม่ใช่ hard gate") ให้ครอบ cap ทุกชนิด + ระบุลำดับก่อน reject ชัด — บังคับใช้แล้วใน 4 skills: backtest-report-analyzer (RULE 1b resize-first, ถอน Dim-3 RED จาก hard-fail), robustness-validator (ruin resize-first), backtest-optimize-rigor (Verdict discipline), signal-scanner (smoke ห้ามฆ่าด้วย DD) |
| 2026-07-03 | **Direction alignment (grill session): Boss V2 = แม่พิมพ์หลักตัวเดียว (UNFREEZE — supersede freeze 2026-07-02)** · EA_CORE = คลังอะไหล่ R&D (ไม่ทิ้ง ทำต่อเมื่อพร้อม) · standalone = ทางด่วนชั่วคราว ต้อง port เข้าแม่พิมพ์เมื่อพิสูจน์ edge | เหตุใหม่ที่ทำให้รื้อ decision เดิมได้: ภาพจริงของเจ้าของเพิ่งถูก capture ครั้งแรก (`VISION.md`) — แม่พิมพ์เดียว function กลางร่วม ต่างแค่ entry+TF · เจ้าของต้องเข้าใจระบบได้ทั้งตัว (EA_CORE อ่านไม่ออก = drift ซ้ำ) |
| 2026-07-03 | **โหมดงาน = dual-track ถาวร** (โรงงานเดินตลอด + operate คู่กัน) — ยกเลิกคำว่า "operate ล้วน" | แกนล่าที่ยังไม่อิ่มตัว = **กลไก×symbol** (Zeus พิสูจน์: edge มาจาก grid+LOG บน AUD ไม่ใช่ entry เทพ) — ที่อิ่มตัวคือ entry เดี่ยวเท่านั้น |
| 2026-07-03 | **Zeus: validate จบใน standalone ก่อน (MC + พอร์ตรวม) → PASS แล้วค่อย port เข้า Boss V2 เป็น pilot ของ workflow ใหม่ → deploy จากแม่พิมพ์** · 9 EA live ไม่แตะจนถึง judge | ไม่ทิ้งผล IS/OOS ที่ทำแล้ว · port ก่อน validate = ต้อง rerun ทั้งหมด · แตะ EA live = ทำลาย data การทดลอง |
| 2026-07-03 | **เพิ่ม `VISION.md`** = owner ของ "ภาพใหญ่/ปรัชญาโรงงาน" — AI ทุก session อ่านคู่ PROJECT_STATE, งานขัด VISION ให้หยุดถาม | root cause ของ drift = ภาพในหัวเจ้าของไม่เคยถูกเขียนเป็นไฟล์ → ทุก session ตีความจาก status ที่ drift ไปแล้ว |
| 2026-07-04 | **Model transition Fable→Opus = ACTIVE แล้ว (เร็วกว่าแผน 07-07 เพราะ Fable โควต้าหมดจริง) + รื้อ workflow ทีม:** seat=Opus · ยอดบันได escalation พังลง 1 ชั้น (deep-reasoner=seat แล้ว) → Codex (GPT รุ่นเก่งสุดที่มี = สมองอิสระตัวเดียวที่เหลือ, คนละค่ายจับจุดบอดคนละที่), ขอ review เฉพาะงานแพง/ย้อนไม่ได้ · batch run เลี่ยง ChatGPT quota (qwen→ZCode/GLM→oc-btest ถูกสุด) · oc-btest ลด model ถูกสุด/โยนงานไป ZCode · ห้ามรัน Codex+OpenClaw หนักพร้อมกัน | user: Fable หมด ต้องใช้ Opus แทน + ChatGPT quota (Codex+oc-dev+oc-btest แชร์) หมดเร็ว. กติกาเต็ม → `AGENTS.md` §1.5+§5 · `CLAUDE.md` Model transition |
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

**สถานะ (FINAL 2026-07-03): ตระกูล ZeusInspired = ไม่ deploy.** validation ครบทุกด่านแล้ว
(MC ✅ → พอร์ตรวม ✅ → **backward-OOS 2023-24 = ด่านที่ฆ่า**): AUDUSD REJECT (ไม่เทรดก่อน 2025 +
2024 ขาดทุน) · AUDJPY PARKED (กำไร 3 ปีแต่ต้อง size ลงจน PF เหลือ 1.12 < gate 1.20 —
full-window 8x: eqDD 12.17% ✅ / PF 1.12 ❌). บทเรียนที่จ่ายแล้วคุ้ม:
(1) IS/OOS ใน regime เดียวกัน (2025-26) ไม่พอ — backward-OOS บังคับทุก candidate ต่อไป
(2) MC จาก closed trades optimistic จริง (MC worst 18% vs ปี hostile จริง 36%)

✅ **PORT เสร็จ 2026-07-03 (รอบ 5 attempts): กลไก Zeus อยู่ในแม่พิมพ์แล้ว = `Boss_14_GridLog`**
parity ผ่าน (PF 2.04 vs 1.91 · 58 vs 54 trades · net +$2,913 vs +$2,780 · eqDD ต่ำกว่าฝั่งดี) ·
regression CLEAN ตลอด (Boss_11/12/13 ไม่กระทบ) · spec + input ใหม่ 9 กลุ่ม + บทเรียน parity →
`ea_template\DESIGN_V2.md` §5.5 · **workflow "standalone → แม่พิมพ์" ตาม VISION ปิด loop ครั้งแรกสำเร็จ**
→ ~~sweep Boss_14~~ ✅ **sweep 15 symbol + optimizer probe ครบ (2026-07-03 ดึก):**
**4 CANDIDATE (in-sample): GBPAUD (plateau PF 1.71 ทุกปีบวก — ผู้นำ) · EURJPY (2.49) ·
EURCAD (1.82) · USDJPY (1.51)** + AUDNZD WATCH · EURCHF DEAD-optimized · 9 ตัว
PARKED-pending-probe — รายละเอียด+caveat in-sample → EA_SCORECARD §FRESH TEMPLATE.
เครื่องมือใหม่: `report_year_split.py` + probe set กลาง `Boss14_GridLog_GBPAUD_opt1.set`
**🤝 HANDOFF (2026-07-04 ค่ำ — session Fable สุดท้ายก่อน compact; อ่านตรงนี้ = รู้ทุกอย่าง):**

**✅ DEMO bench = 6 EA ครบทุกด่าน (IS-opt→fresh-OOS→full-confirm→MC→Model-4 real ticks):**
cohort-1: USDJPY 990201 · AUDNZD 990202 (แชมป์) · EURJPY 990203 (fill-sensitive) ·
cohort-2: AUDCAD 990204 (OOS 4.30) · CADJPY 990205 (thin 11t) · EURUSD-SELL 990206 ·
sets = `Boss14_GridLog_<SYM>_DEMO.set` (0.25x, DdAdaptive OFF ตาม scrutiny)

**⏳ USER DECISION บันทึกแล้ว (2026-07-04): เปิดบัญชี demo ใหม่ทุน 60,000 cent (6×10k ตาม
scrutiny round-2 — ให้ risk-threshold ต่อ EA ตรงกับที่ validate) แล้ว attach ทั้ง 6 ชาร์ต H1 —
user จะทำ "พรุ่งนี้" (2026-07-05)** · attach แล้ว demo-clock 3 เดือนเริ่มนับ → โหมดเงียบ: operate
+ hunt ช้าๆ ตาม ROADMAP §2.5

**✅ ORDER-019/020 reviewed (Claude/Fable, 2026-07-04):** corr matrix 6-EA demo = พอร์ตกระจายตัวดี
(ไม่มีคู่ >0.60, watch แค่ USDJPY-CADJPY 0.57 — ลด lot ไม่ตัด, ยังไม่ต้องทำอะไรตอนนี้) · SELL-side
hunt เจอ 1 candidate ใหม่จริง **NZDUSD pass 29** (สม่ำเสมอ 2 window) → เข้าคิว **ORDER-023**
(fresh-start OOS, mechanical, พร้อมรัน) · GBPAUD-SELL ตัดทิ้ง (dormancy เดียวกับ BUY) รายละเอียดเต็ม
→ `AGENT_TASKBOARD.md` ORDER-019/020 + `EA_SCORECARD_AND_REGISTRY.md` Boss_14_GridLog row

**✅ ORDER-021 done (Claude/Fable, 2026-07-04 — ทำเองแทน Codex ที่ token หมด):** สรุป 20 treasure
sources ครบ → `_triage/shortlist_briefs.md`. ของใหม่จริงที่น่าพิจารณา build ต่อ (ยังไม่ตัดสิน แค่ triage):
multi-symbol CCI strength ranking · ADX+DI filter (Boss V2 ยังไม่มี ADX module) · PA candle-pattern
gate (Doji/Engulfing/Star/Tower) · retest-zone+reversal-exit บน breakout (ต่อยอด Entry_Breakout ตรงๆ) ·
auto-S/R multi-level pyramid. ตัดทิ้ง: EX170 (manual chart-line ไม่อัตโนมัติ), XPERT2 (kernel32.dll
file I/O + obfuscated), MoonKinght MASA (decompiled). รายละเอียดเต็ม → `AGENT_TASKBOARD.md` ORDER-021

**✅ ORDER-023 done (Claude/Fable, 2026-07-04 — รันเองแทน Codex/ZCode ที่ token หมด):** NZDUSD-SELL
pass 29 = **❌ PARKED (regime-dependent)** — OOS ดูดีเพราะคาบเกี่ยวปี 2026 ที่แข็ง แต่ year-split เผย
2024 แทบไม่เทรด + 2025 แพ้จริง (เหมือน pattern ที่ฆ่า GBPAUD/EURCAD ไปแล้ว) → ปิดการล่า SELL-side รอบนี้

**✅ ORDER-022 done (Claude/Fable, 2026-07-04 — 48/48 runs, รันเองแทน oc-btest ที่ token หมด):**
plateau-sensitivity 6 demo configs × 8 variants — raw CSV `_mt5_auto/ORDER022_SENSITIVITY.csv`,
verdict เต็ม → `AGENT_TASKBOARD.md` ORDER-022. **สรุปจัดอันดับความแข็ง:** 🏆 **AUDNZD = ที่ราบสมบูรณ์**
(8/8 ผ่าน, ยืนยันแชมป์) · ✅ AUDCAD = ที่ราบ (5/8, ไม่มีพลิกลบ) · ⚠️ USDJPY = มีรอยร้าว (step/TP แคบลง
พลิกขาดทุน — ห้ามลดสองค่านี้ต่ำกว่าเดิม) · ⚠️ EURUSD = ปานกลาง (ไม่มีพลิกลบ) · 🔴 **CADJPY = สันเขา**
(ยืนยันธง "thin" เดิมด้วยหลักฐานใหม่ว่าไวต่อ param ด้วย ไม่ใช่แค่เทรดน้อย) · 🔴 **EURJPY = สันเขาชัดสุด**
(baseline PF 2.49 คือจุดพีคไม่ใช่ที่ราบ, 6/8 ทิศตกฮวบ) — **หลักฐานอิสระคนละมิติมายืนยันธง "fill-sensitive"
เดิมจาก Model-4 confirm ทางเดียวกัน → มั่นใจแล้วว่า EURJPY ต้อง size เบากว่าเพื่อนตอน promote จริง**

**✅ 2026-07-05 (Opus session แรก): จัดระเบียบหลัง Fable ออก — เสร็จ 3 อย่าง:**
1. **workflow ทีมรื้อใหม่** (seat=Opus, Codex=สมองอิสระ review เฉพาะงานแพง, batch เลี่ยง ChatGPT quota) →
   `AGENTS.md` §1.5+§5 · `CLAUDE.md` · Decision log · memory `[[agent-workflow-post-fable]]`
2. **demo go-live prep:** เติม cohort 6 EA (990201-206) บนบัญชี 60k ลง `DEMO_DEPLOYMENT_PLAN.md`
   (เดิมไม่มีเลย) + attach checklist + baked plateau-sensitivity/corr flags
3. **stock taskboard:** ORDER-024 (Recovery-mode A/B บน AUDNZD champion = hunt mine #1, ready)

**✅ Loss-management layer = ปิด branch (ORDER-024/025/026, 2026-07-05):**
- **Recovery 81 Light = REJECT** · **Recovery 82 Adaptive = REJECT** (Model-1 โชว์ดีขึ้นแต่ Model-4 real
  ticks เผย PF AUDNZD ร่วง 3.37→1.50 = artifact; generalize ไม่ผ่าน) · **HEDGE_LOCK = dormant no-op**
  (trigger 8% แต่ DD แตะ ~4% ไม่เคยยิง) → **Recovery+Hedge ไม่เพิ่มค่าบน Boss_14, demo config (2 layer OFF) ถูกแล้ว**
- **บทเรียนใหญ่: Model-4 บังคับก่อนเชื่อ mechanism grid/recovery — Model-1 เป็น fill-artifact ได้ (ลึกกว่า Model-2 ban)**
- **routing rule (user 2026-07-05):** ZCode ฟรีแต่โควต้า ≈ **1 order หนัก/วัน** (ORDER-025 กินหมดวันในคำสั่งเดียว!)
  → เก็บ ZCode slot ให้ order สำคัญสุด/วัน, batch เล็กให้ qwen/Claude รันเอง · ทุก order ระบุ "👉 แนะรัน" (AGENTS §5)

**🔍 REASSESS mine #1 (Claude/Opus 2026-07-05 — อ่าน Entry_Breakout + scorecard prior):** Boss_12/13
entries บน FX = **EV ต่ำ deprioritize** — Boss_12 Breakout = Donchian ตัวเดียวกับ LabTpl ที่ **optimize-killed
บน FX แล้ว (0/180, 0/175 survivors, "edge is XAU-specific")**, XAU ก็ซ้ำ live EA_BREAKOUT_XAU · Boss_13
MeanReversion = BB+RSI ~1.1 ceiling dead-prior. → **mine #1 ที่เหลือ EV สูงสุด = ขยาย GridLog (ตัวชนะ)
ไป non-FX (metals/index)** ไม่ใช่ probe entry ที่ตายแล้ว. ติดบล็อก = `_2_BasketTP_Money` ($ คงที่ ไม่ scale
ข้าม instrument) → **ORDER-027 (ATR-TP mold upgrade) = prerequisite**

**✅ ORDER-027 reviewed + accepted (Claude/Opus verify tpl_regression CLEAN เอง):** `_2_BasketTP_ATRmult`
(ATR-scaled basket TP, additive) ทำงานถูก inert-on-default. **แล้ว Claude รัน XAU scan ต่อ → 2 การค้นพบ:**
- **🥇 XAU GridLog มีชีวิต! PF 1.76 in-sample (@mult=1, 0.25x, +$5,569)** = **non-FX diversifier ตัวแรก**
  (ทอง vs พอร์ต FX grid) — ⚠️ IN-SAMPLE + DD 18.73% สูง (de-scale ตอน promote) + ทอง+grid ต้อง Model-4 + สงสัยสูงสุด
- **🐛 bug ตัวที่ 2 = `_33_SL_MaxPips` ไม่ portable** (XAU 2-digit → SL cap เพี้ยนเป็น $1.50 → รอบแรก PF 0.29
  = artifact). workaround = ตั้ง `=0` (ATR-SL คุมเอง). fix ถาวร = ORDER-029

**✅ ORDER-028/029A reviewed (Claude/Opus 2026-07-05):** XAU IS-opt → plateau-center **Pass 20**
(Step3.0/BUY/Dist1.4/BasketTP_ATRmult=1.0, PF 1.48/277t/DD 9.34% in-sample) · set `Boss14_GridLog_XAU_ISpick.set`
สร้างแล้ว · 029A → เลือก **Option B** (ATR-relative SL cap) implement = ORDER-029B

**🏭 คิว PIPELINE ยาว พร้อมให้คอมรันเอง (token Claude ใกล้หมด — user สั่งรันทดสอบยาวๆ):**
| Order | งาน | ทำได้ · 👉 แนะ | ลำดับ |
|---|---|---|---|
| **ORDER-030** | XAU fresh-OOS + full + year-split | ZCode/Codex/oc-btest · 👉 ZCode | รันก่อน |
| **ORDER-031** | XAU MC + Model-4 (ทองบังคับ M4, รันเดี่ยว) | ZCode · 👉 ZCode | **หลัง 030 ผ่าน** |
| **ORDER-032** | XAG (เงิน) IS-optimize (non-FX ตัว 2, ขนาน) | ZCode/oc-btest · 👉 ZCode | วันแยก |
| **ORDER-029B** | implement ATR-relative SL cap (code) | Codex/Claude/oc-dev · 👉 Codex-direct | ขนาน, ไม่เร่ง |
| **ORDER-033** | smoke 4 MT5 signal EAs จาก `wait for test` (idle filter) | Codex/oc-dev · 👉 Codex-direct | idle-compute, EV ต่ำ |

**🗺️ MASS-SMOKE `wait for test` (user 2026-07-05 ยืนยัน: เคยเห็นตัวรันดี, เทสทั้ง ex4+ex5 autonomous):**
ขนาดจริง = **337 unique .ex5 + 2,286 unique .ex4 = 2,623 ตัว** (dump ใหญ่). tooling ครบทั้ง 2 track (MT5
`smoke_all.ps1` · MT4 `mt4_run.ps1`+`D:\Meta4`). funnel: **ORDER-034 catalog/dedup/กรอง → 035 MT5 smoke →
036 MT4 smoke (stage ~200)** ทุกตัว autonomous มี timeout/skip-hang guard. survivor (Tier A: PF>1&trades≥20&DD<40%; Tier B grid-trap แยก) → Claude คัด
เข้า intake funnel เต็ม. (ORDER-033 4-EA = warm-up subset). VISION: survivor = สกัดกลไกเข้าแม่พิมพ์

**✅ reviewed 029B/030/032/033 (Claude/Opus 2026-07-05):**
- **🥇 ORDER-030 XAU = ผ่านด่าน OOS! CONDITIONAL PASS** — OOS PF 1.15/196t + **ทุกปีบวก** (1.20/2.31/1.31/1.37) ·
  **= candidate non-FX ตัวแรกที่รอด OOS** · ⚠️ DD 27%@0.25x (de-scale ~ครึ่ง) + **ต้อง Model-4 (ORDER-031) ก่อนเชื่อ**
- **029B = ACCEPT** (verify tpl_regression CLEAN เอง — mold portable non-FX แล้ว) · **032 XAG = PARK-thin** (4 pass, ทองแข็งกว่า) ·
  **033 4-EA = ไม่มี survivor** (Retest/GapFill ไม่ติด, Bot V00 DD 42.9% churn) → ตอกย้ำต้อง mass-smoke เต็ม

**🎉 ORDER-031 reviewed (Claude/Opus 2026-07-05): XAU ผ่านครบ = CANDIDATE #7 (non-FX diversifier ตัวแรก!)**
Model-4 real ticks = net +$5,078/DD 19.95% (**edge รอด real ticks ไม่ร่วงแบบ Recovery**) · MC ruin 0%/P(loss) 0% ·
DEMO set สร้างแล้ว `Boss14_GridLog_XAU_DEMO.set` (**lot 0.05 de-scaled, magic 990207**, DD ~2x FX จึงลดครึ่ง) →
เพิ่มใน DEMO_DEPLOYMENT_PLAN เป็น EA ที่ 7 · **candidate พร้อมเข้า demo cohort เมื่อ user attach** (⚠️ leg เสี่ยงสุด จับตา DD)
**บทเรียน:** grid บน non-FX ทำได้ **หลังแก้ 2 portability bug** (basket-TP ATR-scale ORDER-027 + SL cap ATR-relative 029B) —
Model-4 คือด่านที่แยก "grid มี edge จริง" (ทอง) ออกจาก "Model-1 artifact" (Recovery)

**✅ ORDER-034 reviewed:** worklist mass-smoke พร้อม = **1,521 tradeable (ex5 203 + ex4 1,318)** → 035/036 unblocked

**✅ ORDER-035 reviewed (Claude/Opus 2026-07-05): mass-smoke MT5 → 39 survivor แต่ส่วนใหญ่กับดัก Model-1**
(tight-TP artifact suspect: IR Whale 3.94/DD0.75%, The One 2.32/2941t · grid DD30-60%: North East Way,
continue v06 · หมดอายุ: EA GOLD CENTER Expried). **คัด 3 → ORDER-037 Model-4 artifact-check:** ⭐pun fix lot v05
(4-sym fixed-lot 1.5-1.6) · EA_GapinFX (gap 2-sym PF2+) · North East Way (4-sym PF2+/DD30%). **036 MT4 = พรุ่งนี้.**
treasure ที่ user จำได้อาจอยู่ในนี้ — ต้องผ่าน Model-4 ก่อน (Elephant lesson PF85→1.41)

**✅ corr check XAU vs 6 FX done (Claude/Opus 2026-07-05): ทอง = diversifier ยืนยัน** — AUDNZD -0.59 (สวนทาง!) /
CADJPY -0.19 / AUDCAD +0.19 / EURJPY +0.32 = additive · USDJPY +0.53 watch (6mo บาง) · **ไม่มีคู่ >0.60** →
ทองลด risk พอร์ตจริง (ตอน FX ย่อ ทองอาจขึ้น) · caveat: shared months บาง (6-15) ต้องวัดซ้ำหลัง demo สะสมข้อมูล

**🗺️ แผนที่ต้องทำ — เรียง priority (2026-07-05):**
- **P0 = critical path (รอ user): DEMO ATTACH 7 EA** → บัญชี 60k · ทุกอย่าง validate + set + corr ครบแล้ว
  รอแค่ user attach → **3-month demo clock เริ่มนับ** (นี่คือ gate เดียวสู่ validation จริง — งานอื่นรองทั้งหมด).
  เมื่อ attach: จด start date + set demo-clock + นัด /ea-monitor ครั้งแรก ~2 สัปดาห์. XAU #7 ต้อง de-scale
  บัญชี 60k อาจต้องปรับ (7 EA แทน 6 — XAU lot 0.05 = ครึ่ง unit จึงเกือบพอดี, user เคาะตอน attach)
- **P1 = autonomous idle-compute: ORDER-035 (MT5 203) → 036 (MT4 1,318 stage)** ล่า treasure ที่ user
  เชื่อว่ามี · 👉 oc-dev/Codex · รันข้ามคืนได้ · survivor (Tier A: PF>1&trades≥20&DD<40%; Tier B grid-trap แยก) → Claude คัดเข้า intake funnel
- **P2 = hunt ต่อ (mine #1 ใกล้หมด):** loss-mgmt ตาย · entries FX ตาย · XAU done · XAG parked · เหลือ:
  GridLog บน **indices (US30/NAS)** เป็น non-FX ตัวถัดไป (มี ORDER-029B ATR-SL portable แล้ว) **หรือ**
  ข้ามไป **mine #2 treasure** (candle-gate/retest-zone mold-port) — Claude เคาะเมื่อ mass-smoke ให้ผล/demo เดินแล้ว
- **P3 = housekeeping:** XAU ยังไม่ผ่าน `robustness-validator` skill เป็นทางการ (แต่ OOS+MC+M4 = ครอบคลุมแล้ว) ·
  audit เอกสารซ้ำ (ROADMAP §3)

**คำแนะนำเด็ดขาด:** P0 (demo attach) คือสิ่งเดียวที่ปลดล็อกทุกอย่าง — เมื่อ user ว่างให้ทำก่อน · ระหว่างรอ =
P1 mass-smoke เดินอัตโนมัติ · P2 hunt เก็บไว้ทำเมื่อ demo เดิน + มี Claude quota

**วิธีรัน (user):** dispatch ORDER-030 ให้ ZCode ก่อน (ด่านชี้ขาด OOS) → ผ่านค่อย 031 (M4) · 032/029B ขนานได้ ·
**ทุก order มีคำสั่ง+ไฟล์+acceptance ครบในตัว agent รันได้เลย** · verdict = Claude ทำตอนกลับมา (ห้าม agent ตัดสิน)
**routing:** "ทำได้: X · 👉 แนะ: Y" (AGENTS §5.1) · Codex-direct ประหยัดกว่า OpenClaw · ZCode ฟรี ~1 order หนัก/วัน

**งาน Claude session หน้า:** review 030/031/032/029B ตามที่ DONE → ถ้า XAU ผ่านครบ (OOS+M4+MC) = **candidate #7
non-FX จริง** (de-scale lot ให้ DD เข้า budget ก่อน demo) → ถ้าตก = mine #1 non-FX จบ → **mine #2 treasure**
(candle-pattern gate + retest-zone) · demo cohort (ค้างตาม user) เมื่อ attach → จด start date + นัด /ea-monitor
**เครื่องมือครบแล้ว — ห้ามสร้างเพิ่มโดยไม่มี friction จริง (ตกลงกับ user แล้ว):** 2 เลน MT5
(Meta 5 + Meta 5b bit-identical) · EA_MASTER_INDEX.csv 125 แถว (OneDrive) · STATUS.md (OneDrive) ·
ทีม OpenClaw 3 ตัว ([oc-mgr/dev/btest], heartbeat, เลน 2) · A/B harness · กฎครบใน AGENTS.md
**Verdict อื่นล่าสุด:** GBPJPY/USDCAD/NZDUSD = WATCH · GBPAUD/EURCAD/GBPUSD = PARKED (GBP
hostile pattern) · EURCHF/USDCHF/LNBREAK = DEAD-optimized · NRBreakout = PARKED-final

**งานที่เหลือ ตามลำดับที่ควรทำ:**
1. ~~**Monte Carlo บน config ที่ DD-scale แล้วจริง**~~ ✅ **เสร็จ 2026-07-03 (รอบ 2):** AUDUSD DD
   95th 16.55%/worst 26.04% · AUDJPY 95th 11.22%/worst 18.18% · ruin 0% ทั้งคู่ — PASS
2. ~~**รัน AUDUSD+AUDJPY เป็นพอร์ตรวมกัน**~~ ✅ **เสร็จ 2026-07-03 (closed-trade merge):**
   full-lot MC-DD 95th 16.92% เกิน budget → **แนะนำ 0.7x ทั้งคู่ (MC-95th 12.44%, net +$2,677/17mo,
   PF 1.48)** — scale `_05_BaseLot`+`_04_TpUsd`+`_06_MaxTotalLot` พร้อมกัน · เดือนที่ลบพร้อมกันมีแค่
   1/17 แต่คือ **2026-06 เดือนล่าสุด** → จับตาบน demo · caveat: วัดจาก closed trades — combined
   floating DD ต้องพิสูจน์บน demo (ตัวเลขเต็ม → EA_SCORECARD §FRESH TEMPLATE EAs)
3. ✅ **Backward-OOS 2023–2024 เสร็จ 2026-07-03 (รอบ 3) — VERDICT เปลี่ยน:** **AUDUSD = REJECT**
   (แทบไม่เทรดก่อน 2025 + ปี 2024 ขาดทุน PF 0.41 — edge เป็น regime 2025-26 เท่านั้น) ·
   **AUDJPY = CONDITIONAL** (กำไรทั้ง 3 ปีแต่ 2023 eqDD 36% ที่ 20x → ต้อง de-scale เป็น **lot8x**) ·
   แผนพอร์ตรวม 0.7x = ยกเลิก → AUDJPY solo · ตัวเลข → `_mt5_auto/ZIGL_BWD_OOS.csv` + scorecard
3b. **GBPAUD/USDJPY/EURCHF** ยังบางเกิน (12-18 เทรด) — ถ้าจะเก็บต่อ ต้องรอ history ยาวขึ้นหรือหา window อื่น
   เพิ่ม ไม่ใช่เชื่อจากเทรดน้อยแบบนี้
4. **ก่อน deploy จริง:** ผ่าน `robustness-validator` skill ให้ครบ (ยังไม่เคยเรียก skill นี้กับ EA ตัวนี้เลย)
   + สร้าง magic number ใหม่ (990101/990102 มีอยู่แล้วใน .set แต่ยังไม่จองในระบบ live)
   + ตาม `vps-deploy-ops` checklist ปกติ (ยังไม่ได้ build deploy bundle)
5. **(ใหม่ 2026-07-03) ถ้า validate ผ่านทั้งหมด → port เข้า Boss V2 เป็น `Entry_GridLog` ก่อน deploy**
   (Zeus = pilot ของ workflow "standalone → แม่พิมพ์" ตาม VISION) — port แล้วต้อง re-confirm เลข
   ตรงกับ standalone เดิมก่อนถือว่า port สำเร็จ · deploy จากแม่พิมพ์ ไม่ใช่จากร่าง standalone

### 🔧 งานอัปเกรดแม่พิมพ์ Boss V2 (track ใหม่ 2026-07-03 — ทำขนานกับ Zeus ได้)

1. ~~เติม **Hedge/Recovery module จริง**~~ ✅ **เสร็จ 2026-07-03 (deep-reasoner + regression-verified):**
   Recovery 81 Light / 82 Adaptive / 83 Aggressive + HEDGE_LOCK — ทุกโหมด cage-clamped,
   default OFF ทุกตัว, compile 0/0 ทั้ง 3 Boss EA. spec + ข้อจำกัด (netting account, comment tag,
   ยังไม่เคย backtest) → `ea_template\DESIGN_V2.md` §5
2. ~~เพิ่ม **smoke-regression ชุดเล็ก**~~ ✅ **เสร็จ 2026-07-03:** `scripts\tpl_regression.ps1` +
   `ea_template\regression_baseline.csv` (3 Boss EA, XAU H1 2024H1, Model 1) — รอบแรกจับ parity
   หลังใส่ Hedge/Recovery แล้ว: **REGRESSION CLEAN ทั้ง 3 ตัว**. กฎ: แก้ `core\` ทุกครั้งต้องรัน
   script นี้ก่อน commit
3. ต่อไป: sweep แกน **กลไก×symbol** (grid/DCA/hedge/progression บนคู่เงินที่ยังไม่เคยลอง)
   ผ่าน `/signal-scan` ตามปกติ · หมายเหตุ: โหมดใหม่ (82/83/HEDGE_LOCK) ยังไม่เคยผ่าน backtest ใดๆ —
   เปิดใช้ครั้งแรก = validate เหมือน mechanism ใหม่
4. gotcha ใหม่: `deploy.ps1` แก้แล้วให้ resolve junction `Roaming\MetaQuotes\Terminal →
   D:\MetaTraderData\...` ก่อน robocopy (subdir-create ผ่าน junction เคย fail เงียบ)

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
| กติกา multi-agent + คิวงานกลาง | `AGENTS.md` · `AGENT_TASKBOARD.md` |
| roadmap ระยะยาว + ภาพสุดท้าย + gate เลื่อนเฟส | `ROADMAP.md` |
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
