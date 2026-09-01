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
**FACTORY-B11-16-PROSPECTIVE-H01-PREREGISTRATION: OWNER-APPROVED / PROSPECTIVE / FIXED-CONFIG ONLY - 2026-08-29.** This is the pre-result causal owner for new `B11-H01-r1`, `B12-H01-r1`, `B13-H01-r1`, `B15-H01-r1`, and `B16-H01-r1`. Each H01 freezes the exact tracked regression-default baseline that exists at this preregistration: B11 `ea_template/sets/regression/Boss_11_GridTrend_defaults.set` = 151 physical keys / SHA256 `5a0cdd3186e924234d4491bdf854966553214ebaaf03ca6793beaedd42ea8efa`; B12 `Boss_12_Breakout_defaults.set` = 155 / `62ffa4e95a08a483617046694309a8082c1d07bece39a778704f67cb389626c1`; B13 `Boss_13_MeanRev_defaults.set` = 157 / `65f3d4287effd5cf821bac6fff5f123eb17430608f32e9bfa5853216d053d9a6`; B15 `Boss_15_ST03_defaults.set` = 157 / `ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c`; B16 `Boss_16_KangarooGrid_defaults.set` = 134 / `4c18e345bd773d47cfde945bfa5ed47e7bbff3cd3d245dd0079829084ef15563`. The hypothesis is intentionally minimal: the current canonical family at its frozen baseline is enrolled as a fixed-config first evidence point; H01 grants **zero optimizer authority**, creates no TUNABLE ranges, does not promote any historical winner, and cannot use pre-registration results as H01 validation. All H01 decision evidence must be generated after this preregistration. Factory output remains `NON_AUTHORITATIVE_SIDECAR`; candidate selection/promotion, deployment, DEMO/LIVE attachment, risk/default changes, and HOLDOUT use are outside this contract. B14 and B17 remain accepted reference molds only. B18 remains PARKED/fail-closed: `_18_DirMode=1` versus `2` is an unresolved semantic choice and this order grants no authority to choose it.

**FACTORY-B11-16-H01-FIXED-BASELINE CLOSE — 2026-08-29:** COMPLETE / MECHANICAL PASS. Ten Model-1 XAUUSD/H1 MAIN+BWD cells are full-window eligible with exact build/config identity. MAIN/BWD PF: B11 1.02/0.88, B12 0.95/0.92, B13 0.91/0.90, B15 0.99/0.89, B16 1.49/0.96. Every BWD PF is below 1.0; no optimizer, HOLDOUT, candidate promotion, DEMO/LIVE, risk/default, or deployment continuation is unlocked. B14/B17 remain reference molds. B18 remains PARKED pending owner choice _18_DirMode=1 vs 2. Evidence: docs/factory/BOSS11_16_H01_FIXED_BASELINE_RESULTS.md.

**FACTORY-B11-16-H02-LITERAL-PORTABILITY CLOSE — 2026-08-30:** COMPLETE / SCREEN CLOSED. Preregistered at `40b38ffafc5be5e34abc5070a57fa6049ed5b3b4`; 110 new fixed-config Model-1 cells plus 10 reused H01 XAUUSD/H1 cells = 120 cells / 60 MAIN-BWD pairs. Integrity = 110/110 expected H02 keys, 0 missing/extra/duplicate; 106 H02 rows PASS and 4 B11 M15 rows are `SUSPECT_TRUNCATED`, yielding 58 full-window eligible pairs. Six eligible pairs have PF > 1 in both windows: B16 XAUUSD/H4 4.08/1.44, B16 USDJPY/H1 1.53/1.11, B16 XAUUSD/M15 1.25/1.10, B15 GBPUSD/H4 1.10/1.07, B13 XAUUSD/M15 1.06/1.02, B13 GBPUSD/H4 1.05/1.02 (MAIN/BWD). These are screening pulses only; H02 grants no optimizer/rescaling/HOLDOUT/selection/promotion/DEMO/LIVE/risk authority. Next continuation requires a new preregistered confirmation/mechanism hypothesis. Evidence: docs/factory/BOSS11_16_H02_LITERAL_PORTABILITY_RESULTS.md and docs/factory/BOSS11_16_H02_PAIR_MATRIX.csv.

**FACTORY-B16-H03-CONFIRMATION — 2026-08-30:** DONE / ACCEPTED / `POSITION_ENGINE_DEPENDENT_OR_UNKNOWN`. Accepted H02 bytes reconciled without MT5 rerun; multi-entry cycles contribute 79.80% MAIN and 87.89% BWD gross profit, so H04 is not unlocked. Strategy quality not reassessed; no optimize/HOLDOUT/candidate/DEMO/LIVE/risk authority. Result: docs/factory/B16_H03_CONFIRMATION_RESULTS.md.
**BOSS19-P4-REGIME-ATTRIBUTION — 2026-09-01 CLOSEOUT:** P4A FROZEN / P4B `BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)` / RESEARCH_ONLY. Immutable macro + exact 18-cell tester OHLC prerequisites are complete and the reviewed classifier timeline is frozen at SHA-256 `5f3a0f8d1accd25cb6cc08ad1c6e291aed6d238d620269102151016dbfaf569d`. Only after that freeze were H3 outcome/deal bytes opened. Canonical unit audit `e9a3816775e1e2810ca99c55f349cdabc70d5348` pins `H3_MATRIX.csv` (`e3f3305c29a837c936a4476d100bf3e1b8b68357ab3a8faac041f9e11402faaa`), binds all 36 rows to the accepted package, rehashes 36/36 reports, and reconciles 1,549 `in` with 1,549 realized `out` deals. Current report schema has no source-emitted Position/opening-link field, opening/closing Order IDs are disjoint, and no source basket ID exists; FIFO/time/volume/order/P&L reconstruction is forbidden. This is an evidence-shape blocker, not strategy failure or regime conclusion. Resume only with a hash-pinned source-bound timestamped unit export carrying durable realized-deal/position→opening identity. HOLDOUT remains UNSPENT; no runtime gate/optimization/candidate/risk/deploy authority. Result: docs/research/BOSS19_P4_REGIME_ATTRIBUTION_RESULTS.md.

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

**B16-H05-GBP-SELL-H4-OPT01-PREREGISTRATION - 2026-08-31: PROSPECTIVE / RESEARCH_ONLY / WITHIN OWNER-APPROVED B16 COMPLETION SCOPE.** Causal claim: the accepted B16 GBPUSD/H4 SELL-local profile has a stable RSI-entry region around the accepted 14/70 trigger, so a center can improve or preserve entry participation without relying on a single parameter spike while position-engine, exit, sizing, and safety semantics remain frozen. Exact architecture/config parent = accepted SELL_DIRECTION child SHA256 c0e7cfad84236b798dece5b5106d271c708553fb220af370dba913d8610105de; direction stays SELL. This Factory hypothesis is B16-H05-r1 solely to avoid collision with existing B16 H02/H03 research labels and the locked H04 boundary; it does not unlock or rename H04. WIDE/COARSE search is MAIN-only GBPUSD/H4 Model-1, Fast Genetic, with exactly two TUNABLE dimensions: _16_RsiPeriod = 7..28 step 7 and _16_RsiHigh = 60..80 step 5; 14/70 is the accepted center. The period lattice is a bounded half-to-double memory-horizon study around 14; the threshold lattice stays strictly above neutral 50 and centered on 70, preserving the RSI-high SELL-fade mechanism rather than switching architecture. Every other strategy/mechanism input is LOCKED; sizing/runtime/safety stay SIZING/RUNTIME/SAFETY and are never swept. Falsifier/loop breaker: after the frozen MAIN search surface is available, an admissible plateau center must be interior to both lattices and its center plus all four orthogonal one-step neighbours must each have mechanically accepted MAIN net profit > 0. If no such center exists, the stable-entry-region claim is falsified and this optimization hypothesis stops; do not add spacing/exit dimensions, expand ranges, run BWD, or spend HOLDOUT under this contract. If one or more such centers exist, select by maximum minimum net across the five-cell cross; tie-break by higher minimum trade count, then lower maximum native EqDD%, then smaller Manhattan distance to accepted 14/70. Only the locked selected center may proceed to a separate fixed-config MAIN confirmation and then BWD validation; BWD may invalidate/park the center but may never be used to retune. HOLDOUT remains UNSPENT. No Candidate/DEMO/LIVE/deployment/trading/risk/default/KINT/Grade authority.
<!-- B16-H05-GBP-SELL-H4-OPT01-PREREGISTRATION -->
**B16-H08-USDJPY-BUY-H1-OPT01-PREREGISTRATION - 2026-08-31: PROSPECTIVE / RESEARCH_ONLY / WITHIN OWNER-APPROVED B16 COMPLETION SCOPE.** Causal claim: the accepted B16 USDJPY/H1 BUY parent has a stable, participation-qualified RSI-entry region around 14/30 while position-engine, spacing, current exits, sizing, protection and safety remain frozen. Exact parent full-surface bytes reconstruct identically from all nine canonical one-change characterization sets at SHA256 `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`; accepted parent MAIN = PF 1.53 / net +252.53 / 275 trades / EqDD 3.85%, BWD = PF 1.11 / net +44.10 / 267 trades / EqDD 2.40%. Factory hypothesis is `B16-H08-r1`. WIDE/COARSE search is MAIN-only USDJPY/H1 Model-1 with exactly two TUNABLE dimensions: `_16_RsiPeriod={7,14,21,28}` and `_16_RsiLow={20,25,30,35,40}`. The threshold lattice is newly preregistered for USDJPY BUY from RSI semantics (all thresholds remain below neutral 50, baseline 30 interior); historical XAU BUY and GBP SELL ranges grant no authority. Plateau eligibility requires each center plus four orthogonal neighbours to be mechanically accepted, MAIN net > 0 and >=100 closed trades. If no eligible interior center exists after the exact 20-cell lattice is known, stop H08; do not widen ranges/add dimensions/use BWD as search/spend HOLDOUT. If multiple centers exist, select by max-min MAIN net, then min trades, max EqDD, distance to 14/30, then deterministic low-value tie-break. Only one frozen center may proceed to fixed MAIN reproduction then BWD validation. Current SingleTP/BasketTP behavior remains frozen per the accepted USDJPY exit concentration diagnostic. No Candidate/DEMO/LIVE/deployment/trading/risk/default/KINT/Grade authority.
- `bars:` H08 does not create a new verdict threshold. Report current canonical selection bars separately: MAIN PF >=1.20 and >=100 closed trades; BWD validation PF >=1.00 and >=100 closed trades. Failure does not authorize retuning on BWD or a DEAD verdict under this contract.
- `flat-lot probe:` N-A for sizing escalation: B16 H08 freezes `_16_LadderMult=1.0` and does not optimize lot progression/sizing.
<!-- B16-H08-USDJPY-BUY-H1-OPT01-PREREGISTRATION -->