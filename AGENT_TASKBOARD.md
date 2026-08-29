# AGENT_TASKBOARD — คิวงานกลางของทุก agent

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **คิวงาน + ผลดิบระหว่างรอ review เท่านั้น** ·
> กติกาเต็ม → `AGENTS.md` (อ่านก่อน claim) · verdict สุดท้ายไม่อยู่ที่นี่ — อยู่ที่ EA_SCORECARD/PROJECT_STATE
>
> สถานะ: `OPEN` → `CLAIMED(agent, เวลา)` → `DONE` / `BLOCKED(คำถาม)` → `REVIEWED(project reviewer)`
> agent อื่นแก้ได้เฉพาะแถว order ที่ตัว claim · เพิ่ม order ใหม่ = ChatGPT/user หรือ agent ที่ task contract อนุญาตชัดเจน
>
> 📋 **ORDER TEMPLATE (บังคับตั้งแต่ ORDER-124+ · framework Part 5 enforcement #1):** order ทดสอบ/optimize ทุกใบ
> ต้องมี 2 บรรทัดนี้ในสเปก — pre-register ก่อนรัน ห้ามเติมย้อนหลัง:
> - `bars:` pass = X · dead = Y · กลาง(WATCH/build-on) = Z   ← เลขตัดสินที่ล็อกก่อนเห็นผล
> - `flat-lot probe:` done / N-A(single-order) / pending   ← ถ้ามี escalation ต้อง done ก่อนตัดสิน STRUCTURAL
>
> 🌳 **CONDITIONAL-ORDER TEMPLATE (บังคับสำหรับทุก order ที่จ่ายให้ lane ตอน Claude ไม่อยู่ — oc-qwen/qwen/ZCode ·
> user directive 2026-07-25 · ฉบับเต็ม + เหตุผล → `docs/QUOTA_FALLBACK_PLAYBOOK.md`):** order ที่ไม่มีบล็อก
> `TREE:` = **worker ห้ามรับ** (มันจะจบที่ STEP 1 แล้วเครื่องว่าง ซึ่งคือปัญหาที่ template นี้แก้)
> ```
> ## ORDER-xxx — <ชื่อ> — `OPEN` · ทำได้: <agents> · 👉 แนะ: <default>
> **bars:** pass = X · dead = Y · กลาง = Z          **flat-lot probe:** done / N-A / pending
> **STEP 1:** <คำสั่งรันที่ copy ไปวางได้ตรงๆ — EA/symbol/TF/window/path ครบ>
> **TREE:** PF ≥ pass → STEP 2A <สเปกครบ> · pass > PF ≥ กลาง → STEP 2B <สเปกครบ> ·
>           PF < dead → STOP lane นี้ + ไป order ถัดไป (ห้ามสรุปว่า "ตาย" — ส่งให้ project reviewer ประสาน working verdict) ·
>           ไม่เข้า branch ไหน / รันพลาด 2 ครั้ง → `BLOCKED(<คำถาม + ตัวเลือก A/B>)` แล้วแจ้ง user
> **ห้าม:** verdict · แตะ scorecard/MASTER_INDEX/EDGE_CATALOG/PROJECT_STATE/VISION/B1_DATASET ·
>          แตะ .mq5 หรือ ea_template\core\ · แตะ _vps_deploy/.set ของ EA ที่ demo อยู่ · Model-2 ·
>          ตีความผลนอก branch · เปลี่ยนค่าที่ STEP ไม่ได้ระบุ
> ```
> ทุก branch ต้องรันได้ทันทีโดยไม่ต้องคิด ("SL {2.5,3.0,3.5} step 0.5" = ใช่ · "ลองปรับดู" = ไม่ใช่) ·
> ปลายทุกกิ่งต้องเป็น **STEP ถัดไป / STOP / BLOCKED** เท่านั้น ห้ามมีปลายเปิด · ลึก 2-3 ชั้นกำลังดี
>
> 🏁 **track merge EA_CORE → Boss V2: ปิดแล้ว (เปิด+จบ 2026-07-06)** — อะไหล่เข้าแม่พิมพ์ครบ
> (pyramid 93 · acct-DD gate · Persist · tests\) + EA_Project = read-only archive · บันทึกเต็ม →
> `AGENT_TASKBOARD_MERGE.md` (เหลือ MERGE-07 Entry_ST03 = HOLD ถึง judge — เงื่อนไขอยู่ในบอร์ดนั้น)

---

## HISTORICAL PHASE SNAPSHOT — 2026-08-17 DURABLE STATE SYNC (NOT CURRENT ROUTING)

> Current blockers, accepted milestones, hard stops, and forward plan are owned by `PROJECT_STATE.md`. The dated material below is retained as queue/history context and must not be used to reopen a closed blocker by itself.

The SYSTEM FOUNDATION acceptance lanes are closed and are not active queue items. The next Control Tower phase is:

- **SYSTEM COMPLETION (2026-08-17 durable governance sync): `SYSTEM ACTIONABLE WORK = COMPLETE`.**
  ORDER-1283, ORDER-1284, ORDER-601 and ORDER-1360 are closed as duplicate-stale on this board (canonical
  already satisfied their acceptance — see each row's 2026-08-17 closure note; no code change). ORDER-1251
  and ORDER-1265 were already correctly archived (`ARCHIVE_TASKBOARD_2026-07A.md`) and are unchanged.
  Monitoring Real Defect A (`make_status.ps1` taskboard-read-failure vs empty-queue conflation) and Real
  Defect B (`SnapshotVerdict` `x-enforced-by` stale "no reader calls `load_verified()`" prose) are
  `FIX_ACCEPTED`, integrated at `64fbf2c2` (branch `system-completion-monitoring-integration`, parent
  canonical `23d916d2`) — `SnapshotVerdict.x-enforcement-status` remains `BUILT`, not promoted to `WIRED`.
  No product/system defect from the Gap-to-Done pass remains open. Remaining work is either
  **OWNER/EXTERNAL BLOCKED** (Telegram CONTROL_ROOM credentials · AGENTS.md §2 Work Receipts writer
  authority · ClevrFX/`69424711` deployment-runtime evidence · deal-sensor freshness · owner
  signatures/attestations · PR #8 / ORDER-1560 owner-pending merge) or **PARKED/FUTURE** (Relay R4 · D3/D6
  owner-gated · Zeus optimization HOLD + the Template Zeus port waiting on it · ExpertMAPSAR · ExpertMAMA
  + its Model-4 fill-sensitivity investigation · QI-2+ · the portable-Python extra end-to-end committed
  test · other previously parked future hardening). Monitoring stays `DEGRADED_MONITORING` (see MONITOR
  below) — System Completion does not make it GREEN. Factory stays paused (see FACTORY below) through the
  owner push boundary. No deployment, trading, LIVE, risk/default, or QI-2+ authority is implied.
- **FACTORY (2026-08-17 update):** Wave5 Candidate 3 ExpertMACD is **closed** — `REJECT_FROM_M3` (bounded
  Invalid Stops repair landed, invalid stops 5→0, valid evidence PF 0.67; evidence integrated at
  `_mt5_auto/M2_WAVE5_C3_REPAIR/`). Wave5 Candidate 4 ExpertMAPSAR = `PARKED-VERIFY(user)` (BWD
  participation 58 < the ≥100/window floor on the plateau host; canonical right-home XAU/GBP naked smoke
  all four cells thin; evidence at `_mt5_auto/M2_WAVE5_C4_MAPSAR/`, `_mt5_auto/M3_WAVE5_C4_MAPSAR/`,
  `_mt5_auto/M3_RIGHTHOME_MAPSAR/`). ExpertMAMA = `PARKED-VERIFY(user)` (right-home naked smoke PROCEED,
  M3 coarse optimize showed no genuine plateau; evidence at `_mt5_auto/M2_MAMA/`, `_mt5_auto/M3_MAMA_OPTIMIZE/`).
  Zeus (`ZeusInspired_GridLog`) optimization = **HOLD FOR LATER** per owner direction (not dead/non-viable;
  BWD participation 70 < the ≥100/window floor; evidence at `_mt5_auto/ZEUS_XAU_VALIDATION/`). **No current Factory candidate is selected for production.** Boss14 H01 is now the accepted first full-green
  `NON_AUTHORITATIVE_SIDECAR` reference; the next Factory queue item is deterministic read-only Boss11-18 preflight.
  Do not rank/select/promote a production candidate or invent missing parameter/range semantics from this routing sync.
- **TEMPLATE:** smoke-regression suite accepted (`scripts/tpl_smoke_regression.ps1`, 8/8 clean across every
  current Boss build); the Zeus grid/LOG port stays waiting on the Zeus optimization outcome above.
- **MONITOR (CURRENT ROUTING OVERRIDE, 2026-08-24):** preserve global `DEGRADED_MONITORING`. ORDER-353 setup/acceptance is complete: config/attestation/target G3 are closed at the accepted binding; forward observation is waiting only on genuine qualifying trade evidence. Do not reopen pre-deployment/runtime-identity work without a concrete regression, and do not invent another monitoring order without new evidence or a direct consumer.

**POST-FACTORY vNEXT / EXECUTION RELIABILITY ACCEPTANCE SYNC - 2026-08-26:** Factory vNext MT5 set compatibility adapter and Execution Reliability Pack V1 are CLOSED/ACCEPTED integration inputs. They create no new active queue item, candidate selection, runtime/deployment authority, risk/default change, or KINT closure. Future Factory production migration and Boss11-18 rollout still require separate bounded consumers.
**FACTORY vNEXT MT5 SET CONSUMER PILOT CLOSE - 2026-08-26:** CLOSED/ACCEPTED as expected-refusal evidence. Real SuperTrend rev05 BTCUSD/H4 baseline reaches the consumer boundary and refuses because canonical VariantBuildPackage is absent while `KINT-001` is OPEN / semantics remain required. No MT5 terminal write, Strategy Tester invocation, candidate selection, runtime authority, risk/default change, or KINT closure occurred. This closeout creates no new active queue item.
**CONTROL-PLANE P0 / BOSS14-PONYTAIL CONVERGENCE - 2026-08-27:** Boss14 H01 first full-green, BaselineCoverage, Ponytail final protected-directory repair, Diagram Design, MacroGate RegimeOnly readiness, Traycer authenticated-A2A OFFLINE cage, and Scheduled Continuation are accepted/canonical inputs. Boss11-18 deterministic read-only preflight is READY/NEXT; `P72000 / UseMiddlePathVeto` remains quarantined from Range Generator/optimizer semantics. Cleanup Batch 1 is PARTIAL_SAFE/CLOSED FOR NOW and Batch 2 is PARKED. ORDER-353 remains passive genuine-evidence monitoring only. No runtime/deployment/trading/risk authority is added.
**BOSS19 ADAPTIVE TREND GRID V0 VALIDATION - 2026-08-28:** CLOSED as `PARKED-VERIFY(user)`. STOP MAIN search selected a non-boundary center (`StepATR 0.30 / Fast 20 / Slow 50 / TP 1.50`) and exact MAIN confirms PF 4.64 / 100 trades; BWD fails decisively at PF 0.34 / 49 trades / ~25% DD. Flat-lot control shows the MAIN pulse is not created only by progression (PF 5.78) but BWD still fails PF/trade-count and hits the hard DD cage. LIMIT hit the StepATR lower boundary twice across the one bounded expansion, so auto-expansion stopped. HOLDOUT 2026H1 is UNSPENT; no sensitivity/MC/Model-4/candidate/deployment continuation is READY. Future redesign is a new hypothesis; DEMO/LIVE attach and risk/default changes remain owner-reserved.

No new detailed order is invented here; the Control Tower should bind these phase items to the next canonical task contracts.
> 🏭 **FACTORY B17 CURRENT QUEUE — 2026-08-29**
> - **FACTORY-B17-PACKAGE — CLOSED / REVIEWED / CANONICAL at `94b4bc6be58eabd391933a9079532a4c12911272`.** Exact-head independent Claude review PASS. `B17-H01-r1` now has the deterministic first-green Factory vNext package: 147 logical bindings, 31 LOCKED/SNAPSHOT_ONLY projection rows, 159 physical baseline rows (31 PROJECT + 128 PRESERVE_SNAPSHOT), zero TUNABLE, proposed `.set` preserving the frozen baseline, and authority `NON_AUTHORITATIVE_SIDECAR`. No optimizer/runtime/risk authority was added.
> - **FACTORY-B18-REGISTRATION — BLOCKED(PROVENANCE).** Do not create a B18 Hypothesis/ParameterBinding until an exact tracked pre-result configuration pin exists or a new prospective owner-approved hypothesis is registered. Activation/physical coverage are already complete and are not the blocker.
> - R0-FINAL, R0-GUARD, and B17/B18 activation are closed prerequisites; **do not reopen them** for this package lane unless a live path proves a regression.
>
> 🔧 **SYSTEMS TRANCHE ORDER-152..158 (เขียน 2026-07-23, Opus-seat)** — งาน infra/tooling ล้วน ไม่ใช่ verdict EA.
> ที่มา = 2 backlog รวมกัน: (A) review แผน `docs/EA_CORE_TEMPLATE_WORKPLAN_FOR_CLAUDE.md` (7 finding ของ Opus
> + 4 ที่ Codex จับเพิ่ม) (B) `ROADMAP.md` §3 development backlog. **ลำดับ = อะไร block งานอื่น/เสียข้อมูลถาวร
> ก่อน ไม่ใช่อะไรง่ายก่อน.** T1 = 152-155 (ทำก่อน) · T2 = 156-158 (ตามหลัง ไม่เร่ง).
> **ไม่เขียนเป็น order (มี trigger ชัดแทน):** PQ-02 deflated gate = LOCKED + ยังไม่ binding (order ที่ค้างอยู่ N≤50
> ทุกใบ → บาร์คง 1.20) unlock เมื่อมี screen order แรกที่ N>50 · PQ-01 vol-target rebalancer เต็มรูป = ต้องใช้ deals
> จริง ≥3 เดือน ซึ่ง cohort ใหม่ยังไม่มี รันไม่ได้ก่อน ~ต.ค. · MT5 เลน 2/3 = `AGENTS.md` §3 มี lane params ครบแล้ว
> เหลือแค่ verify ตอนคิวแน่นจริง

> 📦 **ย้ายเข้าคลัง 2026-07-24 (Opus-seat):** 52 order ที่ปิดด้วยสถานะ `REVIEWED*` แล้ว ถูกยกทั้งดุ้น (verbatim ไม่ตัด) ไปต่อท้าย
> `ARCHIVE_TASKBOARD_2026-07A.md` ตาม contract append-only (ORDER-103) — ค้นด้วยเลข order ในไฟล์นั้นได้ตามปกติ.
> **ที่ย้าย:** 153 · 154 · 155 · 159 · 156 · 157 · 168 · 180 · 173 · 169 · 166 · 171 · 172 · 174 · 184 · 170 · 163 · 164 · 158 · 160 · 150 · 146 · 148 · 142 · 140 · 124 · 125 · 126 · 127 · 135 · 138 · 129 · 132 · 131 · 130 · 137 · 098-E · 098-G · 098-J · 098-L · 098-M · 104 · 109 · 110 · 111 · 057 · 099 · 100 · 101 · 103 · 105 · 115
> **ที่ยังอยู่บอร์ดนี้** = order ที่ยัง OPEN/CLAIMED/WAITING-USER/CAMPAIGN + ใบที่สถานะเป็น `DONE`/`CLOSED` เปล่าซึ่งยัง
> ย้ายไม่ได้ (validator ต้องการ `## REVIEW ORDER-x` คู่กัน ไม่งั้นจุด `terminal-no-linked-review`) — ต้องทำ C1-CLOSURE ก่อน.
> 📦 **ย้ายเข้าคลังรอบ 2026-07-26 (Opus-seat):** 22 order สถานะ `REVIEWED*` ยกทั้งดุ้น (verbatim) ไปต่อท้ายไฟล์คลังเดิม — **ที่ย้าย:** 210 · 211 · 212 · 222 · 218 · 219 · 220 · 217 · 221 · 214 · 216 · 204 · 203 · 200 (x2) · 198 · 199 · 201 · 197 · LANEA-AB · LANEC-FAN · 136 · **ที่ไม่ย้าย:** 193(d) + 095/#4 (เลข order ซ้ำกับใบที่ยังค้างบอร์ดนี้ → ย้ายแล้วจะจุด `cross-active-and-archive`)
>
> 📦 **ย้ายเข้าคลังรอบ 3 · 2026-07-27 (ORDER-390):** **12 ใบ** — `350` `341` `390` `270` `231` `238` `250` `251` `252` `205` `206` `097`.
> **ครึ่งหนึ่งของชุดนี้ปลดล็อกได้เพราะ ORDER-390** ซึ่งแก้อาการที่ `Get-StatusClass` มองไม่เห็น `REVIEWED` เมื่อ status span
> มี inline code ซ้อน (backtick เดี่ยวซ้อนกันไม่ได้ ⇒ `` `DONE(..., `sha`) ... + REVIEWED(...)` `` แตกเป็นหลายสแปน
> สแปนแรกมีแค่ `DONE`) — **6 ใบเคยนั่งบนบอร์ดเหมือนงานที่ยังไม่เสร็จทั้งที่ review แล้ว**
> **ที่ยังไม่ย้าย:** `095/#4` (แม่ CAMPAIGN ยัง OPEN — เหมือนรอบก่อน)
>
> 📦 **ย้ายเข้าคลังรอบ 2 · 2026-07-26 (ORDER-260 + ORDER-261):** อีก **51 ใบ**. ปลดล็อกได้เพราะ **ORDER-260** แก้บั๊ก
> `Get-StatusClass` ที่ตี `REVIEWED` เป็น NonTerminal เมื่อ verdict มีคำว่า "holdout"/"open" (17 ใบติดกับนี้) และ
> **ORDER-261** เขียน review ให้ 28 ใบที่ตรวจหลักฐานครบแล้ว (`_triage/EVIDENCE_SWEEP_TERMINAL_BLOCKS_2026-07-26.md`)
> พร้อมแก้ข้อความ 9 ใบที่ข้ออ้างเก่าถูกหลักฐานใหม่หักล้าง (073 · 143 · 188 · 193 · 187 · 072 · 036 · 112E · 189).
> **ที่ยังไม่ย้าย:** `095/#4` (แม่ CAMPAIGN ยัง OPEN — ย้ายแล้วจะจุด `cross-active-and-archive` · ต้องรอ campaign ปิด)

> 🔁 **RE-OPTIMIZE WAVE 210..213 (เขียน 2026-07-25, Opus-seat — user สั่ง "วางแผน optimize ใหม่")**
> <sub>⚠️ renumbered 205..208 → 210..213 ทันทีหลังเขียน: session คู่ขนานลง 205/206 (MacdDiv/PivotBreakout expand)
> ไว้ก่อนแล้ว — collision เดิมซ้ำรอย ORDER-201/202 เมื่อวาน. ไฟล์ ranges ยังชื่อ `order205_brkxau/` ตามเดิม
> (prefix = ตอนที่สร้าง ไม่ใช่เจ้าของใบ — เปลี่ยนแล้ว pointer ใน brief ที่ agent ถืออยู่จะพัง). **เลข 209 เว้นว่างไว้.**</sub>
> **หลักการเลือกว่าตัวไหนต้อง re-opt:** ไม่ใช่ "รันใหม่ให้หมด" แต่รันเฉพาะตัวที่ **หลักฐานที่ใช้เลือกพารามิเตอร์เสียจริง**.
> ตรวจแล้วมี 3 แหล่งที่ทำให้หลักฐานเสีย และแต่ละแหล่งกินตัวไหนบ้าง:
> - **(A) holdout leak** (ORDER-202): 87 optimize pass เลือกบนหน้าต่างที่กิน 2026H1 — แต่ deployed จริงโดน
>   **ตัวเดียว = `EA_BREAKOUT_XAU` 991001 (เงินจริง)** → **ORDER-210**. Boss_14 cohort ค่าพารามิเตอร์สะอาด
>   (มาจาก `_IS.ini` 2023.01–2025.06) เสียแค่ "ใบตัดสินว่าจะ ship" → ประกาศ 2026H1 ไหม้ พอ ไม่ต้อง re-opt.
>   Boss_16 สะอาด แต่ **บาร์ที่จะใช้ตัดสิน demo เขียนมาจากเลขที่เฟ้อ** → **ORDER-213** (แก้เลข ไม่ใช่ re-opt).
>   NRBreakout/ST03/ZSCORE/LNBREAK = verdict เป็น "ตก" อยู่แล้ว — contamination มีแต่ทำให้ดูดีขึ้น ไม่ต้องทำใหม่.
> - **(B) MRIS core classifier พัง** (ORDER-203, แก้แล้ว `265de0e3`): ทุกอย่างที่**กินสัญญาณ regime ย้อนหลัง**
>   ต้องวัดใหม่ — ตัวที่โดนจริงคือ **MacroGate 990120** ที่ attach อยู่ → **ORDER-211**.
> - **(C) genetic ที่ไม่มี fine-grid** (ORDER-204 กำลังรัน): ยังไม่รู้ว่ากินใครบ้าง — **ORDER-204 คือใบสำรวจ**,
>   ผลออกมาแล้วค่อยแตกใบ re-opt ต่อ (จะเป็น 209+). ห้ามเดารายชื่อล่วงหน้า.
> **ที่ไม่อยู่ในเวฟนี้และเหตุผล:** EA ที่ verdict = DEAD/ตก (contamination ทำให้ดูดีขึ้นเท่านั้น) · EA ที่ยังไม่ deploy
> และไม่มีใครอ้างเลขมันอยู่ (ไม่มีใครเสียหายถ้าเลขผิด — รอ ORDER-204 คัดมาก่อน) · Boss_14 cohort (ค่าสะอาด).

> 🧹 **TRANCHE 230-239 + 250-252 (เขียน 2026-07-26, Opus-seat · session `S-2026-07-26-TRIAGE`)** — **ไม่ใช่งานใหม่**
> ทุกใบในชุดนี้คืองานที่**มีอยู่แล้วแต่ไม่เคยมีที่อยู่บนบอร์ด**. ที่มา = กวาด `_triage/HANDOFF_*` 17 ใบ (100 รายการ)
> แล้วเจอ **27 รายการที่ไม่เคยเข้า `AGENT_TASKBOARD.md` เลย** + evidence sweep บน 36 order ที่ terminal-แต่ยังไม่ review
> เจอเพิ่มอีก 3. **6 ใบแรก (230-235) = แตะเงินจริงหรือบัญชีจริง** · 236-239 = หลักฐานพร้อมแต่ไม่เร่ง ·
> 250-252 = หนี้ระบบที่ evidence sweep จับได้ · **ที่เหลือ 16 รายการ → `MASTER_BACKLOG.md` §9 พร้อมช่อง "ปลุกเมื่อ"**
> (ไม่เปิดเป็น order เพราะยังไม่มีเงื่อนไขปลุก — เปิดไว้เฉยๆ = บอร์ดบวมโดยไม่มีใครทำ)
> วงจรชีวิตเต็ม + เหตุผล → `docs/WORK_LIFECYCLE.md` · เลนที่เปิดอยู่ → `docs/SESSION_LEDGER.md`

> 🔍 **TRANCHE 370-373 (เขียน 2026-07-27, session `S-2026-07-27-CUTLOSS-VERIFY`)** — มาจากการ **ตรวจงานตัวเอง**
> ของ 5 ใบเมื่อวาน (219 · 220 · 221 · 222 · 215) ไม่ใช่งานใหม่จากไอเดีย. **370 คือช่องโหว่ในสคริปต์ที่ผมเขียนเอง**
> (เจอตอน verify ว่า Boss_16 ที่ attach ไปแล้วเป็นของสดหรือไม่) · 371 = ผลข้างเคียงที่เจอตอนถูกบีบให้ย้ายเลน ·
> 372 = ขาที่ ORDER-222 เขียนไว้เองว่ายังขาด · 373 = สองคำถามเงินจริงที่**เหลือให้ user เคาะเท่านั้น**

> 🔍 **TRANCHE 540-544 (เขียน 2026-07-28, session `S-2026-07-28-BATCHQUEUE`)** — user สั่งหางาน batch ขยายผล
> ก่อน quota หมด. ทั้ง 5 ใบมาจากการอ่านบอร์ด**เทียบกับเกณฑ์ที่เพิ่งเปลี่ยน + บั๊กที่เพิ่งแก้** ไม่ใช่ไอเดียใหม่:
> **540 = ประตูบังคับ** (binary stale → ผลทุกใบข้างล่างพูดถึงโค้ดที่ไม่มีอยู่แล้ว) · 541/542 = cell ที่ GEN-STANDING
> เขียนสเปกไว้ครบแต่ไม่เคยมีใครรัน · 543 = fan ของ ORDER-431 ที่**เลือกค่าที่ขอบกริดพอดี** · 544 = กรง ENGINE-EDGE
> ที่ NuiIndy ไม่เคยเดิน. **ลำดับบังคับ: 540 ต้องผ่านก่อน 541/542/543 จึงจะรันได้**

> 🏭 **TRANCHE 600-601 (pasted 2026-07-30 17:40, lane `S-2026-07-30-BOARDPASTE`)** — the two Factory-OS orders that came out of `BACKLOG-D30`. They were drafted at 11:50 and could not be pasted for six hours because a concurrent lane held this file with uncommitted work under a user instruction to hold all commits; they lived in `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md` and were tracked by `BACKLOG-D30` in the meantime. **600 is untouched. 601 is already built and blind-audited — read its header before doing anything to it.** Both specs are deliberately un-gameable: Codex audit 5 constructed, for every rev-1 criterion, the cheapest output that met the letter and defeated the purpose, and every rev-2 amendment traces to one of those.

> 🧭 **TRANCHE 670-674 (written 2026-07-31, lane `S-2026-07-31-TIERSNAP`)** — three of these are the owner's decisions from 14:2x, recorded in `PROJECT_STATE.md` §3 **before** any code moved (`671` · `672` · `673`), and two come out of one measurement: **31 of 32 declared reads of judged evidence in the checker set read the WORKING TREE while the tier is a pre-commit hook** (`670` · `674`). Design = [`_triage/factory_os/TIER_SNAPSHOT_DESIGN.md`](_triage/factory_os/TIER_SNAPSHOT_DESIGN.md) **rev 2**, attacked by an independent review before a line was written: rev 1's central argument was wrong twice and its arrival check was a blacklist. **Do not implement from rev 1's shape — read §7 first, it is short and it is the reason the rest is trustworthy.**

---


---

### 📂 ACTIVE QUEUE — split across parts (mechanical, semantic NO-OP)

> This file is the root manifest (canonical entry stays PROJECT_STATE.md, per the banner
> above). Every ORDER block that used to live directly below now lives in one of the
> ordered part files below — whole blocks only,
> never split, global order preserved. Read them in the declared order to reconstruct
> the full active queue; `scripts/lib/taskboard_source.ps1` does this for every script.
> Do not hand-edit the marker block below — it is the machine-read source of truth for
> which parts exist and in what order.

- `taskboards/active/P01.md` — 52 orders (ORDER-1462 … ORDER-830), 391574 bytes
- `taskboards/active/P02.md` — 33 orders (ORDER-941 … ORDER-GEN-STANDING), 445995 bytes
- `taskboards/active/P03.md` — 29 orders (ORDER-190 … ORDER-RND-P6), generated metadata refreshed by `scripts/make_taskboard_digest.ps1`

<!-- TASKBOARD-ACTIVE-PARTS
taskboards/active/P01.md
taskboards/active/P02.md
taskboards/active/P03.md
-->
