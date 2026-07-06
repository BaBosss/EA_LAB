# AGENT_TASKBOARD_MERGE — บอร์ดเฉพาะกิจ: ดูดอะไหล่ EA_CORE เข้าแม่พิมพ์ Boss V2 แล้วปิดคลัง

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **คิวงาน + ผลดิบของ track "merge EA_CORE →
> Boss V2" เท่านั้น** (แยกจาก `AGENT_TASKBOARD.md` เพื่อไม่ปนงาน hunt/operate — จบ track นี้ = ปิดไฟล์นี้)
> กติกา claim/สถานะ = เหมือนบอร์ดหลักทุกข้อ (`AGENTS.md`): `OPEN` → `CLAIMED(agent, เวลา)` → `DONE` /
> `BLOCKED(คำถาม)` → `REVIEWED(Claude)` · เพิ่ม order ใหม่ = Claude/user เท่านั้น
>
> **สถานะบอร์ด: 🟢 ACTIVE (เปิด 2026-07-06)** — เมื่อทุก order = REVIEWED/CLOSED ให้เปลี่ยนเป็น
> `🏁 CLOSED` + ลบ pointer ในบอร์ดหลัก + อัปเดต PROJECT_STATE (ขั้นตอนอยู่ใน MERGE-08)

---

## 🎯 GOAL + DEFINITION OF DONE (user approve 2026-07-06)

**เป้าหมาย:** เอาข้อดีของ EA_CORE (วิศวกรรมลึก: pyramid executor, portfolio guard, วินัย test,
state persistence) มารวมกับข้อดีของ Boss V2 (ง่าย เร็ว เจ้าของเข้าใจได้ทั้งตัว, มี cage) →
**แม่พิมพ์เดียวที่สมบูรณ์** แล้วปิด `D:\EA_Project` เป็น read-only archive (ไม่มีงานใหม่เข้าอีก)

**วิธี merge ที่เลือก (decision 2026-07-06):** ไม่ merge repo ตรงๆ (ได้ลูกครึ่งที่เสียข้อดีทั้งคู่ +
เสี่ยงกระทบ demo ก่อน judge) → **"ดูดอะไหล่ทีละชิ้นภายใต้ regression cage"** — Boss V2 = ตัวรับ,
EA_CORE = ตัวให้, ทุกชิ้น additive (default OFF), cage จับ drift ทุกขั้น

**DONE เมื่อครบ 6 ข้อ (ตรวจได้ด้วยตัวเลข):**
1. regression cage ครอบ Boss_11–14 ครบ (baseline 4 แถว, `tpl_regression.ps1` CLEAN) — MERGE-01
2. Boss V2 มีโหมด pyramid/pending-ladder (จาก ScaleExecutor_v2) ผ่าน behavior checklist + regression CLEAN — MERGE-03
3. RiskControl มี account-level DD gate (จาก PortfolioGuardian_v1) default OFF + พิสูจน์ gate trip ได้จริง — MERGE-04
4. restart-safety audit สรุปแล้ว (port StatePersistence หรือพิสูจน์ว่าไม่จำเป็น) — MERGE-05
5. module ที่เพิ่มใน track นี้มี smoke-assert รันได้ 1 คำสั่ง — MERGE-06
6. `D:\EA_Project` ติดป้าย ARCHIVE + docs ทุกไฟล์ตรงกัน (GUIDE/PROJECT_STATE/VISION) — MERGE-08

(MERGE-07 Entry_ST03 = **conditional ไม่บล็อกการปิดบอร์ด** — เงื่อนไขปลดล็อคอยู่ในตัว order)

## 📦 ทะเบียนอะไหล่ — ตัดสินใจแล้วว่า port อะไร / ไม่ port อะไร (Claude, 2026-07-06)

| อะไหล่ (CORE\) | verdict | เหตุผล |
|---|---|---|
| `ScaleExecutor_v2.mqh` (360 บรรทัด) | ✅ **PORT** (MERGE-03) | ของที่ Boss ไม่มีจริง: pending ladder LIMIT/STOP + OCO — Boss ยิงได้แค่ market ทีละไม้ |
| `PortfolioGuardian_v1.mqh` (76 บรรทัด) | ✅ **PORT** (MERGE-04) | demo 7-EA บน account เดียว — gate ระดับ account ยังไม่มีใน RiskControl |
| `StatePersistence_v1.mqh` (296 บรรทัด) | 🔍 **AUDIT ก่อน** (MERGE-05) | grid EA live ตัวจริงเสี่ยง recompile-reset — แต่ Boss อาจ rebuild จาก open positions ได้อยู่แล้ว |
| วินัย test (contract→impl→test) | ✅ **PORT เป็น pattern** (MERGE-06) | เอาแค่แนวคิด smoke-assert — ไม่ยก harness 1417 ตัวมา |
| `StrategySignal_v4.mqh` (ST03 edge-trigger) | ⏸️ **HOLD** (MERGE-07) | replica 990010 = WATCH (OOS PF 0.86 ขัด 3.93 เดิม) — ยังไม่รู้ว่า edge จริงไหม อย่าเพิ่งเสียแรง |
| `Recovery` (step-on-loss ฯลฯ) | ❌ ไม่ port | ORDER-025 ทดสอบแล้ว REJECT ปิดถาวรทั้ง 81+82 (Model-4 เผย lift = artifact) |
| Hedge เพิ่มเติม | ❌ ไม่ port | ORDER-026: HEDGE_LOCK บน AUDNZD = dormant no-op — Boss มี Hedge.mqh อยู่แล้ว |
| `StrategySignal_v1/v2/v3` | ❌ ไม่ port | signal ตายแล้ว (v4 เพียวๆ PF 0.67, grid 48/48 OOS<1.0) |
| `StrategySignal_v5` (Donchian+ATR) | ❌ ไม่ port | Boss มี `Entry_Breakout` ครอบ concept เดียวกันแล้ว |
| `LotSizer_v1` / `RiskEngine_v1` / `EntryGate/ExitGate` | ❌ ไม่ port | MoneyManagement/RiskControl/LabCore dispatcher ทำหน้าที่นี้อยู่แล้ว — ซ้ำซ้อน |
| `Logging/Diagnostics/ConfigValidator/adapters/ScenarioHarness` | ❌ ไม่ port | ผูกกับ contract ฝั่ง CORE, คุณค่าต่อ Boss ต่ำกว่าต้นทุนพา complexity เข้า |

## ⛓️ กฎเหล็กของบอร์ดนี้ (เพิ่มจาก AGENTS.md)

1. **ห้ามแตะ EA ที่ live/demo อยู่ + magic map** — track นี้แก้แม่พิมพ์เท่านั้น
2. **ทุกครั้งที่แก้ `ea_template\core\` → รัน `scripts\tpl_regression.ps1` ทันที** — DRIFT = revert ก่อน
   ห้าม debug ต่อบน state ที่เพี้ยน (default ทุก input ใหม่ = OFF → regression ต้อง CLEAN เสมอ)
3. **additive เท่านั้น** — ห้ามเปลี่ยน default/behavior ของโหมดเดิม (บทเรียน ORDER-027/029B ใช้ต่อ)
4. MT5 tester (`D:\Meta 5`) เป็นทรัพยากรร่วมกับบอร์ดหลัก (ORDER-038 ฯลฯ) — อย่ารันชนกัน,
   เช็ค process ก่อน claim งานที่ต้องรัน backtest
5. ลำดับบังคับ: MERGE-01 → MERGE-02 → MERGE-03 → MERGE-04 → MERGE-05/06 → MERGE-08 (07 = hold)

---

## MERGE-01 — ขยาย regression cage ให้ครอบ Boss_14 — `REVIEWED(Claude, 2026-07-06 — ✅ CLEAN 4 แถว)` (role: Claude)

**ทำไม:** cage เดิม (`tpl_regression.ps1` + `regression_baseline.csv`) มีแค่ Boss_11/12/13 —
Boss_14 GridLog คือตัวที่มี demo live 7 ตัว + จะเป็นฐานของ MERGE-03/04 → ต้องมี baseline ก่อนแตะอะไร

**งาน:** (1) เพิ่ม `EALabTpl\Boss_14_GridLog` เข้า `$experts` ใน `scripts\tpl_regression.ps1` ✅ ทำแล้ว
(2) รัน compare mode ยืนยัน Boss_11/12/13 ยัง match baseline เดิม (3) ถ้า Boss_14 (compiled defaults)
เทรด >0 → append แถว baseline; ถ้า 0 เทรด → แก้ script รองรับ per-EA pinned set แล้วใช้ set pinned
ใหม่ `sets\Boss14_regression_smoke.set` (copy จาก XAU_DEMO — ห้ามชี้ set ที่งาน optimize ยังแก้อยู่)
**Acceptance:** `tpl_regression.ps1` จบด้วย `REGRESSION CLEAN` โดย baseline มี 4 แถว · commit
**ผล (Claude, 2026-07-06):** ✅ ครบทุกข้อ —
- compare เดิม: Boss_11/12/13 match baseline เป๊ะ (cage เดิม healthy)
- Boss_14 compiled defaults เทรดแค่ **4 ไม้** (PF 0.00) = บางเกิน → ใช้ **pinned set**
  `sets\Boss14_regression_smoke.set` (frozen copy ของ XAU_DEMO — **ห้ามแก้ไฟล์นี้ตอน optimize**)
  ผ่าน `$setOverride` ใหม่ใน `tpl_regression.ps1`
- baseline ใหม่ 4 แถว: Boss_14 = net 587.78 · PF 16.39 · 56 trades · eqDD 1.50%
- รัน compare ซ้ำ = **REGRESSION CLEAN** ทั้ง 4 EA, เลขตรงเป๊ะ 2 รอบ (deterministic)

---

## MERGE-02 — Codex independent scope-check (second opinion ตามกฎ architecture) — `CLAIMED(Codex via Claude spawn, 2026-07-06 — ผลจะเขียนที่ handoff\MERGE-02_codex_proposal.md เพื่อกัน anchoring, Claude synthesize เข้าบอร์ดเอง)` (role: peer review, ห้ามใช้ agent อื่นแทน)

**ทำไม:** track นี้ = การแก้ risk/execution logic เข้าแม่พิมพ์ที่ EA ทุกตัวต่อไปจะใช้ = การตัดสินที่แพง
→ กติกา CLAUDE.md บังคับสมองอิสระคนละค่าย ดูโจทย์เดียวกันโดยไม่เห็นคำตอบ Claude ก่อน

**งาน (สำคัญ: ทำข้อ 1–3 ให้จบก่อน แล้วค่อยเปิดอ่านส่วน "ทะเบียนอะไหล่" ข้างบนเพื่อเทียบ):**
1. อ่าน `D:\EA_Project\CURRENT_BUILD\CORE\` (รายชื่อ module + header comment พอ ไม่ต้องไล่ทุกบรรทัด)
   และ `D:\EA_LAB\ea_template\core\` + `docs/EA_CORE_AND_TEMPLATE_GUIDE.md` §1–3
2. ตอบเป็นตารางของตัวเอง: module ไหนของ EA_CORE ควร port เข้า Boss V2 / ไม่ควร / เพราะอะไร
   + ความเสี่ยงอันดับ 1 ของการ port executor แบบ pending-ladder เข้า chassis ที่เป็น basket-TP
3. เขียนข้อเสนอลงใต้ order นี้ **ก่อน** เปิดอ่านทะเบียนอะไหล่ของ Claude
4. จากนั้นค่อยเทียบ: จุดที่เห็นต่างจากทะเบียน Claude ให้ระบุชัด + เหตุผล
**Acceptance:** ตารางข้อเสนอ (ก่อนเห็นของ Claude) + รายการจุดต่าง · commit `[codex] MERGE-02 done`
**ห้าม:** แก้โค้ดใดๆ ใน order นี้ — เป็น review ล้วน

**ผล:** _(รอ)_

---

## MERGE-03 — port ScaleExecutor_v2 → Boss V2: โหมด `STACK_PYRAMID(93)` + pending ladder — `OPEN` (ปลดล็อคเมื่อ MERGE-01+02 REVIEWED) · **ทำได้: Codex-direct** (role: code)

**ทำไม:** อะไหล่ชิ้นที่มีค่าสุดของ EA_CORE — Boss V2 ยิงได้แค่ market ทีละไม้ (`Stack.mqh` 90/91/92
ล้วน market-add) ขาด pending LIMIT/STOP ladder + OCO ที่ `ScaleExecutor_v2.mqh` มี (360 บรรทัด,
ผ่าน regression ฝั่ง CORE แล้ว) — ได้โหมดนี้ = แม่พิมพ์แสดงกลไก pyramid ได้โดยไม่ต้องเขียน standalone

**Spec (สรุป — รายละเอียด API ดู `CORE\ScaleExecutor_v2.mqh` เป็นต้นแบบ):**
- เพิ่ม `STACK_PYRAMID = 93` ใน enum StackMode (`core\Inputs.mqh`) — **default ยังเป็น 90 เดิม**
- input ใหม่ group `_9_` (default OFF/0 ทั้งหมด): `_9_PendingMode` (0=off·2=LIMIT scale-in·3=STOP pyramid),
  `_9_PendingLegs` (จำนวน legs), ระยะใช้ `Stack_StepPrice()` เดิม (ATR-based + MinPips floor — ห้ามทำสูตรใหม่)
- พฤติกรรม: leg0 = market ตาม LabCore ปกติ · legs ถัดไป = pending วางล่วงหน้าที่ระยะ step ·
  basket ปิด (TP/SL/kill) → **cancel pending ค้างทั้งหมด** (pattern `ScaleExec2_CloseAll`)
- **intentional difference จาก CORE (จดใน DESIGN_V2.md §5.x):** Boss ใช้ basket-TP ไม่ใช่ TP ต่อ leg —
  ห้าม port TP-per-leg เข้ามา (ชน ExitManager) · OnTradeTransaction refresh ใช้ pattern `ScaleExec2_Refresh`
- แตะไฟล์: `Inputs.mqh` · `Stack.mqh` · `Execution.mqh` (เพิ่ม pending place/cancel) · `LabCore.mqh` (wire)
  · `DESIGN_V2.md` (spec + เลขรหัส 93)
**Acceptance (ครบทุกข้อ):**
1. compile 0 errors / 0 warnings ทั้ง Boss_11–14
2. `tpl_regression.ps1` = **CLEAN** (โหมดใหม่ OFF by default — เลขเดิมห้ามขยับแม้ทศนิยมเดียว)
3. smoke เปิดโหมด 93: รัน 1 backtest (GBPUSD H1 2024.01–2024.07 M1, set ที่เปิด `_9_PendingMode=3`,
   legs=3) แล้ว grep tester journal ยืนยันเห็น (a) pending ถูกวาง (b) pending ถูก cancel เมื่อ basket ปิด
4. A/B แนบเลข: โหมด 91 vs 93 บน symbol เดียวกัน window เดียวกัน — append PF/trades/DD ทั้งคู่
   (ไม่ต้องชนะ — แค่พิสูจน์ว่า mechanism ทำงานต่างกันจริง)
**ห้าม:** เปลี่ยน default ใดๆ · แตะ logic โหมด 90/91/92 · แตะ Boss_11–13 entry files · ตัดสินว่าโหมดไหน
"ดีกว่า" (นั่นคืองาน optimize รอบหน้า ไม่ใช่งาน port)

**ผล:** _(รอ)_

---

## MERGE-04 — port PortfolioGuardian_v1 → RiskControl: account-level DD gate — `OPEN` (หลัง MERGE-03) · **ทำได้: Codex-direct / Claude** (role: code)

**ทำไม:** demo ปัจจุบัน = 7 EA บน account เดียว — RiskControl คุมแค่ระดับ EA ตัวเอง ไม่มีชั้น
"ทั้ง account DD เกิน X% → หยุดเปิดไม้ใหม่ทุกตัว" ซึ่ง `PortfolioGuardian_v1.mqh` (76 บรรทัด) ทำอยู่แล้ว

**Spec:** input ใหม่ `_3_AcctDDLimitPct` (double, **default 0 = off**) ใน group RiskControl —
เมื่อ account equity ต่ำกว่า high-water-mark เกิน limit → block **first-entry ใหม่เท่านั้น**
(ไม้ที่เปิดอยู่ + stack-add ของ basket เดิม ปล่อยให้จบตามระบบ — ตามปรัชญา resize-not-kill ของ user) ·
log 1 บรรทัดชัดเจนตอน gate trip/release · HWM persist ผ่าน restart ไม่จำเป็นรอบแรก (จดเป็น known-gap)
**Acceptance:** compile 0/0 · `tpl_regression.ps1` CLEAN · พิสูจน์ gate trip: backtest 1 รันด้วย
limit จงใจต่ำ (เช่น 1%) บน config ที่มี DD → journal มีบรรทัด gate trip + จำนวน trades ลดลง vs รัน limit=0 ·
append เลขทั้งคู่
**ห้าม:** ปิดไม้ที่เปิดอยู่ · เปลี่ยน default · ผูกกับ magic อื่น (อ่าน account equity รวมพอ)

**ผล:** _(รอ)_

---

## MERGE-05 — restart-safety audit (StatePersistence จำเป็นไหม) — `OPEN` (ขนาน MERGE-04 ได้ — read-only) · **ทำได้: Codex / oc-dev** (role: investigate, stage A ห้ามแก้โค้ด)

**ทำไม:** EA_CORE มี `StatePersistence_v1.mqh` เพราะเจอปัญหา recompile/restart ทำ state หาย —
Boss V2 grid EA กำลังจะ live จริง ต้องรู้ว่ามีช่องนี้ไหม **ก่อน** เจอบน live

**งาน (stage A — read-only):** ไล่ code path `LabCore.mqh`/`Stack.mqh`/`MoneyManagement.mqh`/
`ExitManager.mqh` แล้วตอบเป็นตาราง: state แต่ละตัว (basket direction/levels/avg price/basket-TP
baseline/DD-adaptive first-lot anchor/HWM ของ MERGE-04) — หลัง terminal restart หรือ recompile,
rebuild จาก open positions (by magic) ได้เองไหม? ตัวไหนหาย → ผลคืออะไร (เปิดไม้ซ้ำ? TP เพี้ยน?)
+ เสนอ minimal fix ต่อช่อง (GlobalVariables pattern จาก `StatePersistence_v1` — เอาแค่ pattern)
**Acceptance:** ตาราง state×recoverable×ผลถ้าหาย×fix ที่เสนอ · commit `[tag] MERGE-05A done` ·
Claude review แล้วจะออก stage B (implement) เฉพาะช่องที่อันตรายจริง
**ห้าม:** แก้โค้ด · ตัดสินว่า "ไม่เป็นไร" เอง — รายงานดิบ

**ผล:** _(รอ)__

---

## MERGE-06 — smoke-assert harness เล็กสำหรับ core\ (ดูดวินัย test จาก CORE เป็น pattern) — `OPEN` (หลัง MERGE-03/04 merge แล้ว) · **ทำได้: Codex / oc-dev** (role: code+test)

**ทำไม:** ข้อดีอันดับ 1 ของ EA_CORE คือทุก module มี test — Boss V2 มีแต่ regression ระดับ EA
(เลข backtest) ยังไม่มี assert ระดับ module. เอา pattern มา ไม่เอา harness ทั้งชุด

**งาน:** สร้าง `ea_template\tests\` + script EA/Script MQL5 จิ๋ว 1 ตัวต่อ module ที่แตะใน track นี้
(Stack pyramid trigger levels · RiskControl acct-gate boundary) ยิง assert แบบ
`<Module>_v1_Test.mq5` ของ CORE (ดูต้นแบบ) + PowerShell wrapper 1 คำสั่งรันครบทุก test รายงาน PASS/FAIL
**Acceptance:** `powershell -File ea_template\tests\run_tests.ps1` (หรือเทียบเท่า) จบ PASS ครบ ·
README 5 บรรทัดวิธีเพิ่ม test · commit
**ห้าม:** import ScenarioHarness/adapters จาก CORE ตรงๆ (พา dependency เข้า) — เขียนใหม่ให้จิ๋ว

**ผล:** _(รอ)_

---

## MERGE-07 — Entry_15_ST03 (StrategySignal_v4 edge-trigger เข้าแม่พิมพ์) — `⏸️ HOLD` · **เงื่อนไขปลดล็อค (ข้อใดข้อหนึ่ง):** (a) replica 990010 ถึง judge 2026-09-22 แล้วผลไม่แพ้ baseline 0.86 อย่างมีนัย หรือ (b) re-confirm OOS ด้วย locked .set ได้ PF ≥1.2

**ทำไม hold:** signal v4 คือหัวใจ ST03 แต่หลักฐานตอนนี้ขัดกันเอง (provisional 3.93 vs qwen rerun 0.86)
— port ตอนนี้ = เสี่ยงเสียแรงกับของที่ไม่มี edge. spec เขียนไว้ให้หยิบทำได้ทันทีเมื่อปลดล็อค:
`core\entries\Entry_ST03.mqh` คืน `EntrySignal` จาก logic MACD consecutive-bar + edge-trigger
(ต้นแบบ `CORE\StrategySignal_v4.mqh`) · `LAB_ENTRY 15` · input group `Inp15_` · Boss_15_ST03.mq5
2 บรรทัด · parity เทียบ `EA_RUNNER_ST03` ด้วย .set เทียบเท่า (บทเรียน parity อยู่ DESIGN_V2.md §5.5)
**ห้าม:** เริ่มก่อนเงื่อนไขปลดล็อค — ใครเห็นบอร์ดนี้อย่า claim

---

## MERGE-08 — closeout: EA_Project → read-only ARCHIVE + sync เอกสารทุกจุด — `OPEN` (order สุดท้าย — เริ่มได้เมื่อ 01–06 REVIEWED ครบ) · **ทำได้: Claude เท่านั้น** (role: judge/docs)

**งาน:**
1. `D:\EA_Project`: เพิ่ม banner ARCHIVE ใน `PROJECT_MASTER_SPEC.md` + README (ถ้ามี):
   "🏛️ ARCHIVED 2026-XX-XX — อะไหล่ถูก port เข้า Boss V2 แล้ว (ดู D:\EA_LAB\AGENT_TASKBOARD_MERGE.md)
   ไม่มีงานใหม่เข้า repo นี้ · ห้ามลบ (reference + หลักฐาน validation)"
2. `docs/EA_CORE_AND_TEMPLATE_GUIDE.md`: อัปเดต §1 (บทบาท EA_CORE: คลังอะไหล่ → archive) +
   §4 flow (ตัด "ยก module จาก EA_CORE" — ดูดครบแล้ว)
3. `PROJECT_STATE.md`: §1 ตาราง (EA_Project สถานะ → archived) · §2 bullet EA_CORE · §7 forward plan ·
   Decision log แถวปิด track
4. บอร์ดนี้: หัวไฟล์ → `🏁 CLOSED` · ลบ pointer ในบอร์ดหลัก `AGENT_TASKBOARD.md`
5. memory: อัปเดต `agent-workflow-post-fable` / สร้าง memory ปิด track
**Acceptance:** `scripts/check_state.ps1` ผ่าน · ทุกไฟล์ข้างบน commit เดียว `[claude] MERGE-08: track closed`

**ผล:** _(รอ)_
