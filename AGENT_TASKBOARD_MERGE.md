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
4b. ⚠️ **Codex quota เหลือ ~5% weekly (user แจ้ง 2026-07-06)** — งานที่ Codex claim อาจตายกลางทาง:
   Claude review ต้อง**เอะใจเป็นพิเศษ**กับแถว DONE จาก Codex ช่วงนี้ (ตรวจว่าไฟล์/ผลมีจริงครบ
   ไม่ใช่แค่ประกาศ) และแถว CLAIMED ที่เงียบนาน = สันนิษฐานว่า quota หมด → ปลด claim กลับ OPEN ได้
5. ลำดับบังคับ (ปรับตาม synthesis MERGE-02 — เสี่ยงต่ำก่อน): MERGE-01 ✅ → MERGE-02 ✅ → MERGE-05A ✅ →
   MERGE-04 ✅ → MERGE-05B ✅ → **MERGE-03 (pyramid — ตัวถัดไป, ชิ้นใหญ่สุด)** → MERGE-06 → MERGE-08 (07 = hold)

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

## MERGE-02 — Codex independent scope-check (second opinion ตามกฎ architecture) — `REVIEWED(Claude, 2026-07-06 — ✅ converge 4/4 + รับ 2 ข้อเสนอของ Codex มาแก้แผน)` (role: peer review)

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

**ผล + Synthesis (Claude, 2026-07-06):** proposal เต็ม → `handoff\MERGE-02_codex_proposal.md`
(Codex อ่าน source จริงทั้งสองฝั่ง ไม่เห็นทะเบียน Claude — anti-anchoring ทำงาน)
- **Converge 4/4 กับทะเบียน Claude:** port = Guardian · StatePersistence · pending-ladder executor ·
  test pattern / ไม่ port = contract stack, TradeIntent pipeline, RiskEngine ซ้ำ, signal modules —
  สองสมองอิสระคนละค่ายได้คำตอบเดียวกัน = scope นี้เชื่อถือได้
- **รับจาก Codex 2 ข้อ (แก้แผนแล้ว):**
  1. **สลับลำดับ:** ชิ้นเล็กเสี่ยงต่ำก่อน — MERGE-04 (guardian) → MERGE-05B (persist) → แล้วค่อย
     MERGE-03 (pyramid = ชิ้นเสี่ยงสุด) — ladder ใหม่อยู่ในกฎเหล็กข้อ 5 แล้ว
  2. **MERGE-03 risk #1 = split exit ownership** (per-leg TP ของ executor ชนกับ basket-TP ของ
     ExitManager — มี precedent จริงในโค้ด: `_2_SuppressLegTP` เกิดจาก conflict class เดียวกันนี้ตอน
     port GridLog) → mitigation เข้า spec MERGE-03 แล้ว: slice 1 = pending placement/cancel/refresh
     เท่านั้น, basket exit เป็น exit owner เดียว, **ไม่มี per-leg TP/OCO เลยในรอบแรก** + โหมด 93
     ต้อง disable partial-close/Recovery/Hedge/Stack-add เดิมของ basket นั้น (one mode, one owner)
- Codex MAYBE (PositionTracker/adapters/ConfigValidator/Logging แบบ selective) → Claude ยืน **ไม่ port**
  ตามทะเบียนเดิม — audit MERGE-05A พิสูจน์แล้วว่า position state self-healing อยู่แล้ว ช่องจริงมีแค่
  hard-kill state ซึ่ง MERGE-05B ปิด

---

## MERGE-03 — port ScaleExecutor_v2 → Boss V2: โหมด `STACK_PYRAMID(93)` + pending ladder — `OPEN` (ปลดล็อคเมื่อ MERGE-04 + MERGE-05B REVIEWED — ชิ้นเสี่ยงสุดทำท้ายสุด ตาม synthesis MERGE-02) · **ทำได้: Codex-direct** (role: code)

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
- **mitigation "one mode, one exit owner" (จาก MERGE-02 synthesis — บังคับ):** slice แรกนี้
  pending ladder ทำแค่ place/refresh/cancel — **ExitManager (basket) เป็น exit owner เดียว ไม่มี
  per-leg TP/OCO** · เมื่อโหมด 93 active: disable partial-close (`_2_PartialPct*`), Recovery, Hedge,
  และ Stack-add ปกติของ basket นั้น (กัน orphaned pendings / re-entry หลัง basket close —
  precedent: `_2_SuppressLegTP` เกิดจาก conflict class นี้) · per-leg TP/OCO เต็มรูป = ค่อยเป็น
  order ใหม่หลัง slice นี้ผ่าน regression+harness (ถ้าจำเป็นจริง)
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

## MERGE-04 — port PortfolioGuardian_v1 → RiskControl: account-level DD gate — `REVIEWED(Claude, 2026-07-06 — ✅ ทำเอง+พิสูจน์ครบทุกข้อ)` (role: code)

**ทำไม:** demo ปัจจุบัน = 7 EA บน account เดียว — RiskControl คุมแค่ระดับ EA ตัวเอง ไม่มีชั้น
"ทั้ง account DD เกิน X% → หยุดเปิดไม้ใหม่ทุกตัว" ซึ่ง `PortfolioGuardian_v1.mqh` (76 บรรทัด) ทำอยู่แล้ว

**Spec:** input ใหม่ `RC_AcctDDLimitPct` (double, **default 0 = off** — เปลี่ยนชื่อจากร่างเดิม
`_3_AcctDDLimitPct` เพราะ `_3x_` เป็นเลขแกน SL อยู่แล้ว, cage ใช้ prefix `RC_`) ใน group RiskControl —
เมื่อ account equity ต่ำกว่า high-water-mark เกิน limit → block **first-entry ใหม่เท่านั้น**
(ไม้ที่เปิดอยู่ + stack-add ของ basket เดิม ปล่อยให้จบตามระบบ — ตามปรัชญา resize-not-kill ของ user) ·
log 1 บรรทัดชัดเจนตอน gate trip/release · **HWM ต้อง persist ผ่าน GV helper ของ MERGE-05B**
(audit 05A ยกเลิก known-gap เดิม — ถ้า 05B ยังไม่ merge ให้เขียน HWM ผ่าน GlobalVariables ตรงๆ
ด้วย key pattern `Boss_<magic>_hwm` แล้ว 05B ค่อย refactor เข้า helper)
**Acceptance:** compile 0/0 · `tpl_regression.ps1` CLEAN · พิสูจน์ gate trip: backtest 1 รันด้วย
limit จงใจต่ำ (เช่น 1%) บน config ที่มี DD → journal มีบรรทัด gate trip + จำนวน trades ลดลง vs รัน limit=0 ·
append เลขทั้งคู่
**ห้าม:** ปิดไม้ที่เปิดอยู่ · เปลี่ยน default · ผูกกับ magic อื่น (อ่าน account equity รวมพอ)

**ผล (Claude ทำเอง, 2026-07-06):** ✅ acceptance ครบ 4 ข้อ —
- **โค้ด:** `Inputs.mqh` เพิ่ม `RC_AcctDDLimitPct=0.0` · `RiskControl.mqh` เพิ่ม HWM tracking
  (update ใน `RiskControl_CheckDD` ต่อ tick, no-op เมื่อปิด) + `RiskControl_AcctGateOK()` +
  GV persist key `Boss_<magic>_acct_hwm` (restore ตอน init มี log) · `LabCore.mqh` เช็ค gate
  เฉพาะจุด first-entry 2 จุด (bar-gate branch + have==0) — stack-add ไม่โดนแตะตาม resize-not-kill
- **compile 0/0 ทั้ง 5 ไฟล์** · **tpl_regression = CLEAN** (gate ปิด default → เลขเดิมเป๊ะทั้ง 4 EA)
- **gate-trip พิสูจน์แล้ว (Boss_13 defaults + limit 5%, XAU H1 2024H1 M1):** baseline 107 trades /
  net -950.60 / eqDD 25.16% (ชน HARD KILL) → gate on = **48 trades / net +1,066 / eqDD 11.67%** ·
  journal: `[RISK] acct-DD gate TRIP: DD 5.25% vs limit 5.00% (HWM 11679.71) - blocking new first-entries`
  (2024.02.02) — report `MERGE04_ACCTGATE_TEST4.htm`
- **บทเรียนที่จ่ายไประหว่างพิสูจน์ (สำคัญต่อคนใช้ input นี้):** ลอง trip กับ Boss_14 GridLog ก่อน
  (limit 1%→0.1%→0.01%) แล้ว**ไม่ trip เลย = ถูกต้อง ไม่ใช่ bug** — config DCA ที่ปิดตะกร้าบวกทุกครั้ง
  balance ตอน flat ไม่เคยต่ำกว่า HWM (gross loss ทั้งหมดเป็น "ขาข้างใน" ของตะกร้าที่ net บวก) →
  gate ชนิดนี้จับเฉพาะ **realized loss ระดับ account** ไม่ใช่ floating DD (ตรงตามปรัชญา
  PortfolioGuardian — floating คุมโดย KillDD/hedge อยู่แล้ว)
- หมายเหตุ release semantics: trip แล้วปลดได้เมื่อ equity ฟื้นเหนือ threshold (ตะกร้าที่ยังเปิดลาก
  equity ขึ้น หรือ EA อื่นบน account ทำกำไร) — flat ล้วนๆ จะ block ยาว = พฤติกรรมที่ตั้งใจ

---

## MERGE-05 — restart-safety audit (StatePersistence จำเป็นไหม) — `REVIEWED(Claude, 2026-07-06 — stage A ทำเองครบ: 1 CRITICAL + 2 LOW → ออก MERGE-05B)` (role: investigate, stage A ห้ามแก้โค้ด)

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

**ผล (Claude ทำเอง, 2026-07-06 — ไล่ code path ครบ LabCore/Execution/RiskControl/ExitManager/MM/Stack/Entry_GridLog):**

| state | อยู่ที่ | rebuild หลัง restart/recompile ได้ไหม | ผลถ้าหาย | severity |
|---|---|---|---|---|
| โครง basket (dir/จำนวน level/lots/avg/last price/profit) | scan positions สดจาก (symbol,magic) ทุก tick (`Execution.mqh`) | ✅ self-healing สมบูรณ์ | — | OK |
| `g_lab_last_bar` (bar-open gate) | `LabCore.mqh:38` reset ใน OnInit | ✅ by design | ประเมินซ้ำ 1 bar แรก — benign | OK |
| **`g_rc_halted` + `g_rc_peak_equity` (hard-kill state)** | `RiskControl.mqh:12-13` memory-only, `RiskControl_Init()` เคลียร์ทุกครั้ง | ❌ | **hard-kill เด้งแล้ว → restart/recompile/VPS reboot → EA ฟื้นมาเทรดต่อเหมือนไม่เคยตาย + peak equity anchor ใหม่ที่ equity หลังขาดทุน → bleed ข้าม restart ไม่มีวันชน KillDD** — จุดที่ EA_CORE สร้าง StatePersistence มาแก้ตรงๆ | 🔴 **CRITICAL** (live เท่านั้น — tester มองไม่เห็นเพราะรันต่อเนื่อง) |
| `g_gl_armed_level` (GridLog resting-stop emulation) | `Entry_GridLog.mqh:20` reset ใน Init | ⚠️ re-arm bar ถัดไปที่ราคา/ATR ใหม่ | ไม่เปิดไม้ซ้ำ แต่ trigger level ย้าย = live เพี้ยนจาก backtest หลัง restart (standalone Zeus ใช้ pending จริงที่ broker = restart-safe กว่า port!) | 🟡 LOW-MED |
| `g_exit_partial1/2_done` (partial-close flags) | `ExitManager.mqh:168-169` memory-only | ⚠️ reset กลาง basket | partial อาจยิงซ้ำรอบเดียวกัน — โพซิชันเล็กลงกว่าแผน ไม่อันตรายต่อ account (semantics เดิมก็ re-arm เมื่อ profit ≤0 อยู่แล้ว) | 🟢 LOW |
| DD-adaptive first lot / MM ทั้งหมด | stateless (อ่าน equity/balance สด) | ✅ | — | OK |
| Recovery/Hedge/Basket | ปิดถาวร (ORDER-025) / dormant (ORDER-026) | n/a | — | skip |

**ข้อสรุป:** ต้อง port แนวคิด StatePersistence จริง แต่จิ๋ว (GlobalVariables helper ~30 บรรทัด ไม่ใช่ 296)
— เป้าเดียวที่บังคับ = hard-kill state · MERGE-04 (acct-DD HWM) ต้องใช้ helper เดียวกันตั้งแต่วันแรก
(ยกเลิก known-gap ที่เขียนไว้ใน MERGE-04) → ออก **MERGE-05B** ด้านล่าง

---

## MERGE-05B — implement `core\Persist.mqh` (GV helper จิ๋ว) + persist hard-kill state — `REVIEWED(Claude, 2026-07-06 — ✅ ทำเอง acceptance ครบ + default ON signed off)` (role: code)

**ทำไม:** ผล audit MERGE-05A — hard-kill state เป็น memory-only = 🔴 CRITICAL บน live/VPS
(restart แล้ว EA ที่ถูกฆ่าฟื้นมาเทรดต่อ + peak-equity anchor รีเซ็ต). tester มองไม่เห็นช่องนี้
เพราะรันต่อเนื่อง — นี่คือ bug class "backtest เขียว live พัง" ตรงตำรา

**Spec:**
- สร้าง `core\Persist.mqh`: helper GlobalVariables คีย์ `Boss_<magic>_<name>` — `Persist_Set/Get/Del`
  (~30 บรรทัด — เอา pattern จาก `CORE\StatePersistence_v1.mqh` ไม่เอา dependency)
- `RiskControl.mqh`: input ใหม่ `_3_PersistHalt` — persist `g_rc_halted` + `g_rc_peak_equity`
  (เขียนตอนเปลี่ยนค่า, อ่านตอน `RiskControl_Init`) · halt ที่ถูก restore ต้อง log ชัด 1 บรรทัด
  ("HALT restored from GV — manual reset = ลบ GV หรือ input toggle")
- **default ของ `_3_PersistHalt` = เสนอ ON (ข้อยกเว้น additive rule ข้อเดียวของ track — เหตุผล:
  ใน tester GV เป็น sandbox ต่อ pass → เลข backtest ไม่ขยับ (พิสูจน์ด้วย regression CLEAN) แต่ live
  ปิดช่อง critical ทันทีทุก EA ที่ compile จากแม่พิมพ์) — จุดนี้ต้องให้ user/Claude sign-off ตอน review**
- (optional, ถ้าเวลาเหลือ) persist `g_gl_armed_level` ของ Entry_GridLog (🟡 จาก audit) ด้วย helper เดียวกัน
**Acceptance:** compile 0/0 · `tpl_regression.ps1` CLEAN · พิสูจน์ restore: script/EA test ใน `tests\`
จำลอง set GV → init → อ่าน halted ถูกต้อง · append log บรรทัด restore
**ห้าม:** persist อะไรที่ rebuild จาก positions ได้อยู่แล้ว (ห้ามซ้ำซ้อนกับ self-healing เดิม)

**ผล (Claude ทำเอง, 2026-07-06):** ✅ acceptance ครบ —
- **โค้ด:** `core\Persist.mqh` ใหม่ (~30 บรรทัด, key `Boss_<magic>_<name>`, pattern จาก
  StatePersistence_v1 ไม่มี dependency) · `RiskControl.mqh` persist `rc_halted`+`rc_peak_eq`
  (เขียนตอน kill + ตอน peak ขยับ, restore ใน Init พร้อม log บอกวิธี un-halt) + refactor acct_hwm
  ของ MERGE-04 เข้า helper (key เดิมเป๊ะ ไม่ break ของที่ persist ไว้แล้ว) · input `RC_PersistHalt`
- **`RC_PersistHalt` default = ON — ข้อยกเว้น additive ข้อเดียวของ track, signed off (Claude ตาม
  มอบหมาย user 2026-07-06):** เหตุผล: tester GV = sandbox ต่อ pass → เลขไม่ขยับ (พิสูจน์ด้าน
  ล่าง) · default OFF จะไม่มีวันถูกเปิดจริงเพราะ .set เก่าไม่มี input นี้ — safety ที่ปิดไว้ = ไม่มี safety
- **compile 0/0 ทั้ง 5 + Persist_Test** · **`tests\Persist_Test.mq5` = [PASS] 8/8 asserts** (Del/Has/
  fallback/roundtrip/overwrite/key-isolation/restore-sim/cleanup) — test แรกของ `ea_template\tests\`
  (หัวเชื้อ MERGE-06)
- **tpl_regression = CLEAN ทั้ง 4 EA โดย persist ON** — จุดสำคัญ: Boss_13 ชน HARD KILL ใน
  regression run (persist path ทำงานจริง) แล้วเลขยังตรง baseline เป๊ะ = ยืนยัน sandbox claim
- **ขอบเขตที่จงใจไม่ทำ:** `g_gl_armed_level` (Entry_GridLog, 🟡 LOW-MED จาก audit) ยังไม่ persist —
  ไม่อันตราย (แค่ trigger level ย้ายหลัง restart ไม่เปิดไม้ซ้ำ) เก็บเป็น optional ของ MERGE-06 ·
  cross-restart survival บน live terminal = platform behavior (gvariables.dat) — ตรวจของจริงครั้งเดียว
  ตอน attach demo chart ครั้งหน้า (จดใน checklist deploy)

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
