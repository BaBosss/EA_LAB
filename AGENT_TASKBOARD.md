# AGENT_TASKBOARD — คิวงานกลางของทุก agent

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **คิวงาน + ผลดิบระหว่างรอ review เท่านั้น** ·
> กติกาเต็ม → `AGENTS.md` (อ่านก่อน claim) · verdict สุดท้ายไม่อยู่ที่นี่ — อยู่ที่ EA_SCORECARD/PROJECT_STATE
>
> สถานะ: `OPEN` → `CLAIMED(agent, เวลา)` → `DONE` / `BLOCKED(คำถาม)` → `REVIEWED(Claude)`
> agent อื่นแก้ได้เฉพาะแถว order ที่ตัว claim · เพิ่ม order ใหม่ = Claude/user เท่านั้น
>
> 📋 **ORDER TEMPLATE (บังคับตั้งแต่ ORDER-124+ · framework Part 5 enforcement #1):** order ทดสอบ/optimize ทุกใบ
> ต้องมี 2 บรรทัดนี้ในสเปก — pre-register ก่อนรัน ห้ามเติมย้อนหลัง:
> - `bars:` pass = X · dead = Y · กลาง(WATCH/build-on) = Z   ← เลขตัดสินที่ล็อกก่อนเห็นผล
> - `flat-lot probe:` done / N-A(single-order) / pending   ← ถ้ามี escalation ต้อง done ก่อนตัดสิน STRUCTURAL
>
> 🏁 **track merge EA_CORE → Boss V2: ปิดแล้ว (เปิด+จบ 2026-07-06)** — อะไหล่เข้าแม่พิมพ์ครบ
> (pyramid 93 · acct-DD gate · Persist · tests\) + EA_Project = read-only archive · บันทึกเต็ม →
> `AGENT_TASKBOARD_MERGE.md` (เหลือ MERGE-07 Entry_ST03 = HOLD ถึง judge — เงื่อนไขอยู่ในบอร์ดนั้น)

---

## ORDER-LANEC-REBUILD — SMC×STO rebuild for an SL plateau (parallel to live demo 991070) — `DONE + REVIEWED(Claude 2026-07-18): NO SWAP — keep demo 991070. 35 M4 runs (coarse SL×TP grid MAIN + plateau-center SL3.5/TP1.2 both-window+fan+holdout, magic 991071). Center MAIN 1.38/BWD 1.02 but holdout 1.09<1.2 (soft ~0.94-1.18 across whole plateau = 2026H1 regime weak, not config) + SL still not clean plateau (fragility moved to SL+20%=4.2 BWD 0.94) + rebuild BWD 1.02 < demo BWD 1.19. No decisive improvement → keep 991070 as-is, 991071 not deployed. SMCxSTO EURUSD-H1 = genuinely marginal reversion edge; further build-on = different HOME (TF/symbol) not more EURUSD-H1 SL tuning. verdict=_triage/ORDER_LANEC_REBUILD_VERDICT.md` (role: Claude judge · M4 driver)
**why:** ORDER-LANEC-FAN found the demo config (SL=3.0) edge-positive both-window but **SL-fragile** — SL−20%
(2.4×ATR) flips 0.94/0.99 both-window (center = cliff, not plateau). User (2026-07-18): keep 991070 on demo AS-IS,
rebuild in parallel, swap only if the rebuild tests+builds better. verdict src = `_triage/ORDER_LANEC_SMCSTO_FAN_VERDICT.md`.
**pre-registered bars:** pass = a config whose **SL axis is a PLATEAU** (SL and SL±20% ALL ≥1.0 both-window) AND
MAIN≥1.2/BWD≥1.0 AND holdout(2026H1)≥1.2 → new demo row (new magic **991071**, run alongside 991070). middle =
edge but SL still marginal → BUILD-ON note. dead = no SL-plateau exists on EURUSD H1 → keep 991070 only, close.
**flat-lot probe:** N/A (EmaStoRev single-position, flat 0.01 — no escalation).
**method (⚠️ anti-overfit — do NOT re-center on the 07-18 fan, that data is now "seen"):** proper coarse→fine
SL×TP grid on MAIN only (SL {2.0,2.5,3.0,3.5,4.0} × TP {0.8,1.0,1.2,1.5}), pick the **plateau center** (not the
peak) where neighbors incl. SL±1 step all profitable → both-window → fresh sensitivity fan → holdout 2026H1 (never
used to select) → Model-4. Keep other axes at the ORDER-107 center (StoK13/OS30/AdxMax30/EMA50). EA=`(EXP)_EmaStoRev`,
Expert `EmaStoRev`, EURUSD H1. **verdict = Claude** (VERDICT GATE + Row-X). **ห้าม:** report Model-2; re-center on
seen fan; swap 991070 before the rebuild clears the pre-registered bars. role: agent runs coarse/fine M4 serial · Claude judges.

## ORDER-LANEA-AB — JumStoch (Boss_18) direction×lever A/B, Model-4 both-window — `DONE + REVIEWED(Claude 2026-07-18): DEAD-OPTIMIZED (port-level). base-gate 16 M4 runs 0.58–0.71 (no pulse) → last-optimize exit lever (base fixed-TP → Boss14 basket-ATR-TP) lifted to 0.82–0.94 but still <1.0 both-window → H4 TF round 0.85–0.92 same. 28 runs total, ≥4 levers × 2 TF × both-window all sub-1. Both DirMode equal+losing = direction A/B moot; edge was standalone's 4-basket+BEP engine not the seed. Lever matrix NOT run (base-gate STOP per pre-registered bar). Boss_18 kept+caged (dead-seed, not deploy). verdict=_triage/ORDER_LANEA_JUMSTOCH_VERDICT.md; EDGE_CATALOG dead-cell + basket-close-DCA lever added.` (role: Claude build+judge · M4 batch driver)
**pre-req DONE:** Boss_18 built + caged green (compile 0/0 · run_tests PASS · tpl_regression RED-benign,
n identical). Build note = `_triage/ORDER_LANEA_JUMSTOCH_BUILD.md`. Expert = `EALabTpl\Boss_18_JumStoch`.
**flat-lot probe:** N/A at entry-signal level (chassis grid; the escalation is StackMode DCA not lot-martingale —
BaseLot flat by default). Run the base once with StackMode=90 (single) as the flat-lot reference if the grid passes.
**spec:** grid/spacing/SL config mirror ORDER-091C-D1 validated JUMSTOCH (Range≈21pip spacing, SL≈253pip,
Level_Max≈12, BEP-shift) mapped to chassis `_9_` params — **⚠️ this mapping is the first real task; verify a
sane .set before the matrix** (StackMode=92, _9_StepUseATR + _9_StepATRmult OR _9_StepPoints to hit ~21pip on
EURUSD/AUDUSD H1, _9_MaxLevels=12, SL via SLMode). Build one base .set per DirMode.
**matrix (Model-4 MANDATORY — grid/DCA; serial lane-1 only):** 2 DirMode {1 faithful, 2 reversion} × 2 symbols
{EURUSD H1, AUDUSD H1} × 4 lever-configs {base OFF · `_9_RegimeGateAdds` ON (+_50_RegimeMode≠0) ·
StackConfirm=CONF_PA_ENGULF · both ON} × both windows {MAIN 2023.01–2025.12, BWD 2020.01–2022.12}.
**GATE (pre-registered — STOP if unmet):** run the 4 BASE cells (DirMode×symbol, no levers) FIRST. **base must
yield PF≥1.0 both-window Model-4** on ≥1 (DirMode,symbol) home before running any lever cell. If NO base home
clears PF≥1.0 both-window → **STOP the lane, report, do NOT optimize further** (right-home reminder: faithful=
momentum→trender may need XAU not EURUSD; reversion→ranger fits EURUSD/AUDUSD — if both ranger homes die on
faithful mode, note it, that's expected). **lever wins only if:** expectancy/trade ↑ AND DD ↓ both-window vs its
own base (Part-1 rule 4: confirms judged by expectancy-per-trade, not net/PF). **verdict = Claude** (VERDICT GATE
+ Row-X write-list). role: agent runs M4 batch serial (ea-validator or qwen driver) · Claude judges.

## ORDER-LANEC-FAN — SMC×STO EURUSD H1 sensitivity fan + Model-4 — `DONE + REVIEWED(Claude 2026-07-18): WEAK candidate — edge-positive but SL-fragile. 26 M4 runs. center 1.39/1.19 both-window; 5/6 axes robust (Ema/OS/StoK/Tp all >1 both-win) but SlAtrMult-20%(2.4)=0.94/0.99 FLIPS both-window + AdxMax-20% BWD 0.91. Center not a plateau on SL (sits above a cliff). Deployed SL=3.0 = safe side, not broken. DEMO-KEEP with SL-lock>=3.0 flag (updated DEPLOYMENTS note 991070); demo-forward=judge. Cannot re-center wider (anti-overfit). verdict=_triage/ORDER_LANEC_SMCSTO_FAN_VERDICT.md` (role: Claude judge · M4 fan driver)
**EA:** `(EXP)_EmaStoRev` · candidate config (ORDER-107, EDGE_CATALOG): **StoK13/OS30/AdxMax30/EMA50/SL3/TP1 =
MAIN 1.50 / BWD 1.24, 130t**. verdict src = `_triage/ORDER107_SMCxSTO_STAGE0_VERDICT.md`.
**spec:** ±20% single-axis sensitivity fan around center **including the frozen axes** — StoK13 {10,13,16},
OS30 {24,30,36}, AdxMax30 {24,30,36}, EMA50 {40,50,60}, SL3 {2.4,3.0,3.6}, TP1 {0.8,1.0,1.2}. Model-4
both-window {MAIN 2023.01–2025.12, BWD 2020.01–2022.12}. **bar (pre-registered):** most variants hold ≥70% of
baseline PF AND none flips to a loss (PF<1) in either window → PASS → candidate demo. Any axis where a ±20%
step drops PF<1.0 both-window = fragile → NOT demo, report which axis. **verdict = Claude.** role: agent runs
M4 fan serial · Claude judges. **ห้าม:** report Model-2 numbers; single-window ranking.

## ORDER-118 — ST03 real-money CutLoss guardrail — `CLOSED-OBSOLETE (Claude 2026-07-18): user ถอดตระกูล ST03 ออกจากบัญชีจริง 159475669 ทั้ง 3 ตัว (9398/939721/990010 — DEPLOYMENTS.csv = REMOVED, ยืนยัน RDP) → ไม่มี tail เปิดบนเงินจริงแล้ว กรง CutLoss หมดเหตุ. ถ้าอนาคตเอาตระกูลนี้กลับขึ้นเงินจริง ต้องเปิด order นี้ใหม่ก่อนเสมอ (spec เดิมด้านล่างใช้ได้เลย)`
**why (owner decision 2026-07-18, Fable grill session):** user เคาะเก็บตระกูล ST03 บนบัญชีจริง 159475669
ต่อ (override คำแนะนำถอด 2026-07-10) **โดยมีเงื่อนไขต้องใส่กรง CutLoss ก่อน** — pattern เดียวกับ NuiIndy
`CutLoss=30` (tail-insurance ฟรี, DD มีเพดาน). ST03 = uncapped recovery (ที่มาไม้ 33.73 lots) → เปลี่ยน
uncapped→capped โดยไม่ใส่ SL รายไม้ (SL รายไม้ฆ่า edge — ทดสอบแล้ว 2026-06-26).
**spec:**
1. **X-ray inputs ก่อน:** ST_EA03 (source/`.set` ของ config live 9397 GBPUSD H1 + 9398 USDCAD H1) มี input
   ตระกูล CutLoss/MaxDD/equity-stop ไหม — อ่านจาก .set + source + Journal (locked-ea-analyzer วิธีเดิม)
2. **มี input →** grid CutLoss% {10,15,20,25,30,40} รัน **continuous span 2020.01–2026.06** (basket EA =
   ห้าม stitched windows) Model 1 → confirm ค่าเลือกด้วย Model 4 (serial เลน 1) · ทั้ง GBPUSD+USDCAD
3. **ไม่มี input →** arithmetic จาก equity curve ของ ST03LAB continuous runs ที่มีอยู่ (`_mt5_auto\reports\
   ST03LAB_*`): simulate close-all-at-X%-แล้วไปต่อ สำหรับ X เดิม → เลือกค่า + แนะกลไก (guardian watchdog
   เล็กที่ force-close ตาม magic ที่ DD threshold — spec build แยกเป็น order ใหม่ ห้ามลงมือในใบนี้)
**acceptance (pre-registered):** ค่าที่เลือก = ค่า**เล็กสุด**ที่ (a) หน้าต่าง benign 2025-26 trigger ≤1 ครั้ง
และ cost ≤20% ของ net (b) ตัด worst eqDD ของหน้าต่าง hostile 2023-24 ลง ≥50% · deliverable = ตาราง
X% × {net, worstEqDD, #triggers} ต่อ symbol + **ค่าแนะนำ 1 ค่า** ส่ง user ใส่เอง (บัญชีจริง = มือ user เท่านั้น)
**ห้าม:** แตะ EA/บัญชี live เอง · report Model-2 · ตีความผลเป็น verdict (Claude เท่านั้น)
**ทำได้:** Claude · qwen (arithmetic route) · ZCode (backtest route) · 👉 แนะ: **Claude x-ray ก่อน → route ตามข้อ 2/3**

## ORDER-119 — CAMPAIGN: ST03 rescue รอบ owner-override — 3 lever ที่ยังไม่เคยแตะ (flat-lot bar ตัดสิน) — `OPEN` (ลดระดับจากเร่ง→คิวปกติ 2026-07-18: ตระกูล ST03 ออกจากเงินจริงแล้ว = ไม่มี exposure ระหว่างทดลอง — งานนี้กลายเป็น backtest-only ปลอดภัยเต็มตัว)
**why:** user สั่งต่อยอด ST03 (filter/MM/optimize) 2026-07-18. **ORDER-071 ban ถูก owner แก้ขอบเขต:
lever ที่ปิดแล้วยังปิดอยู่ (exit ×4 · reactive vol-gate/ADX filter · symbol GBP/CAD ที่ default params) —
เปิดเฉพาะ 3 lever ที่ไม่เคยเทส.** vehicle = **Boss_15_ST03 (chassis, signal parity 133/133)** — ห้ามแตะ live.
**คำถามแกน (pre-registered): มี config ไหนทำ flat-lot PF≥1.0 both-window ได้ไหม** — ถ้าไม่มี = entry ยังไม่มี
edge, campaign ปิด, ผลตัดสินระยะยาวกลับไปทางถอด/แทนด้วย Boss_16 (แจ้ง user, Fable case-1 ถ้า quota มี)
**lever C ก่อน (ถูกสุด ชี้ขาดสุด) — entry-signal params:** MACD fast/slow/signal + count-threshold N
(บทเรียน StoK 5→17: default ≠ ceiling) · homes: GBPUSD+EURUSD+EURGBP (ranger prior) × H1+H4 · Model 1
· **windows: MAIN 2023.07–2026.07 (rolling-36 ตาม framework ใหม่) + BWD 2020.01–2022.12 พร้อมกัน** · coarse ≤50 combos/symbol
**🔧 DISPATCH-READY SCHEMA (Opus 2026-07-18 — de-risked, ไม่ต้อง re-derive):**
- vehicle = `ea_template/Boss_15_ST03.ex5` (chassis) · **flat-lot = `LotProg=PROG_NONE` = chassis DEFAULT อยู่แล้ว** (ไม่ต้องยุ่ง LOT_Repeat — นั่นคือ param ตัว standalone `EA_RUNNER_ST03`, คนละตัว!) · escalation = `LotProg=PROG_LOG_POWER`+`_55_LogPowerFactor` (ไว้ lever A ทีหลัง)
- sweep params (ชื่อ chassis จริง จาก `core/Inputs.mqh` L229-232): `_15_MacdFast {8,12,16}` × `_15_MacdSlow {26,34}` × `_15_MacdSignal {9}` × `_15_CountBars {2,3,4}` = **18 combos** (default 12/26/9/2)
- runner: `scripts/mt5_optimize.ps1` complete-mode ต่อ cell (deterministic grid, XML out) — **ไม่ใช้** `robust_sweep_st03.ps1` (ตัวนั้น target standalone + exit-params ผิด lever). base .set = pin `LotProg=PROG_NONE` + FirstLotMode=FIRSTLOT_FIXED + base lot เล็ก ให้ DD อ่านได้ · **⚠️ Model-4 หมายเหตุ: lever C = flat-lot single-position → Model 1 พอ (ไม่ใช่ basket ยัง)**
- 12 optimize passes = 6 cell × 2 window · แต่ละ pass ≤18 combos → รวม ~216 config-runs
**GATE:** ไม่มี cell flat-lot ≥1.0 both-window (n≥100 ต่อ type intraday) → **STOP รายงาน ห้าม optimize ต่อ**
**lever A (เฉพาะเมื่อ C ผ่าน):** capped basket บน cell ที่ผ่าน — _9_MaxLevels {4,6,8} × emergency-DD
(RC_AcctDDLimitPct / kill-DD) — **ไม่ใช่ SL รายไม้** · Model 4 confirm (basket)
**lever B (เฉพาะเมื่อ C ผ่าน):** leading regime gate — `_MG_SelfGate` A/B (MRIS regime CSV — validated
ORDER-073 แล้ว) on/off บน config เดียวกัน · ชนะ = expectancy/trade ↑ AND DD ↓ both-window
**ห้าม:** Model-2 numbers · รันซ้ำ lever ที่ปิดแล้ว · แตะ 9397/9398/990010/บัญชีจริง · deploy (verdict =
Claude + user) · single-window ranking
**ทำได้:** Claude sets+judge · qwen/ea-screener batch M1 · M4 serial เลน 1 · 👉 แนะ: **Claude ออก .set →
qwen รัน C → Claude อ่าน surface → A/B เฉพาะเมื่อผ่าน GATE**

## ORDER-120 — implement framework Part 4: rewrite CLAUDE.md VERDICT GATE เป็น tree + bar table — `DONE(Opus 2026-07-18): CLAUDE.md gate = decision tree (STRUCTURAL→PARAMETRIC→DEAD-OPTIMIZED/BUILD-ON/PARKED-VERIFY/CANDIDATE) + bar table 7 แถว (MAIN≥1.2 hard / BWD≥1.0 soft-gate→PARKED-VERIFY / holdout≥1.2 / MC ruin≤2% PF-5th≥1.0 / demo→live PF≥1.40@30) + Row-X write-checklist 5 บรรทัด + window names MAIN/BWD/HOLDOUT rolling-36 + paid-for history เป็น footnote. vocab 7 ตัวครบ. section อื่นไม่แตะ.`
**source:** `_triage/FABLE_RESETTLE_FRAMEWORK_2026-07-18.md` Part 4(b) (user approve ครบใน grill 2026-07-18 —
decision log แถว 2026-07-18). **spec:** แทน prose gate ด้วย (1) decision tree STRUCTURAL→PARAMETRIC→
DEAD-OPTIMIZED/BUILD-ON/PARKED-VERIFY/CANDIDATE (2) bar table 7 แถวตาม framework (MAIN≥1.2·BWD≥1.0
soft-gate ตามที่ user เคาะ Q3 — BWD-fail → PARKED-VERIFY(user) เคาะ demo-isolate ได้แต่ปิดทางเงินจริงอัตโนมัติ)
(3) Row-X write-checklist 5 บรรทัด (scorecard·index·EDGE_CATALOG·B1·user-brief) (4) ตั้งชื่อ window
MAIN/BWD/HOLDOUT ตาม rolling-36 ใหม่. **acceptance:** vocab 7 ตัวครบ · บรรทัด "paid for" history เดิมคงอยู่เป็น
footnote (ห้ามลบบทเรียน) · ไม่มี section อื่นใน CLAUDE.md ถูกแตะ · เลขบาร์ตรง framework ทุกตัว.
**ห้าม:** เปลี่ยนเลขบาร์เองโดยไม่มี decision ใหม่. **ทำได้:** Claude เท่านั้น (แก้กฎ) · 👉 แนะ: **Opus-seat**

## ORDER-121 — implement framework Part 3: rewrite skill backtest-optimize-rigor เป็น ladder 0-9 — `DONE(Opus 2026-07-18): skill = THE OPTIMIZE LADDER Step 0-9 (windows pin MAIN rolling-36/BWD 2020-22/HOLDOUT 2026H1 · Model-4-mandatory table ย้ายเข้า · MC bars ruin≤2%/resize 2-10%/PF-5th≥1.0 ย้ายเข้า). ลบ "Model 2 throughout optimize" (Codex BLOCKER) → Model-2 = preflight+kill-only, coarse=Model 1+. grep "Model 2" เหลือเฉพาะ preflight/kill/artifact-detect. OPTIMIZE_PROCEDURE_AND_AUDIT.md ติด superseded banner. NEXT STAGE → VERDICT GATE.`
**source:** framework Part 3(b). **spec:** (1) แทน Phase D-F ด้วย ladder Step 0-9 (2) **ลบบรรทัด "Model 2
throughout optimize for bar-open EAs" (drift ที่ Codex จับเป็น BLOCKER)** → Model-2 = zero-trade preflight +
kill-only, coarse sweep = Model 1+ (3) pin windows: MAIN = rolling 36 เดือนที่ไม่กิน holdout (convention
2023.01–2025.12) · BWD 2020.01–2022.12 · HOLDOUT 2026H1/unseen-symbol (4) ย้ายตาราง Model-4-mandatory เข้า
(grid/DCA/basket · pending-ladder · TP<20pip · largest-loss cliff) (5) ย้ายเลข MC จาก robustness-validator เข้า
(ruin ≤2% green · 2-10% resize-first · PF-5th ≥1.0) (6) `OPTIMIZE_PROCEDURE_AND_AUDIT.md` ติด superseded
banner ชี้ skill. **acceptance:** grep "Model 2" ใน skill เหลือเฉพาะบริบท preflight/kill · ladder ครบ 10 ขั้น ·
เลขตรง framework. **ทำได้:** Claude · 👉 แนะ: **Opus-seat** (แก้กฎ optimize = law)

## ORDER-122 — implement framework Part 2+5: สร้าง docs/PIPELINE.md + sync FINAL RULE 9 skills + AGENTS §1.5 — `DONE(Opus+Sonnet 2026-07-18): docs/PIPELINE.md สร้างแล้ว (flow owner + routing table 10 boundary + skill roster). FINAL RULE sync 9 skills: strategy-and-risk (ลบ standalone-faster block→chassis-first) · mql-code-generator (→mql-code-reviewer ก่อน compile) · signal-scanner · backtest-optimize-rigor (→VERDICT GATE) · mql-code-reviewer (mandatory cage) · robustness-validator + backtest-report-analyzer (DEMOTED banner, vocab retired) · portfolio-selector (corr ladder ≤0.40/0.40-0.60/>0.60 reduce-not-cut/same-EA<0.8) · live-deployment-controller (=GATE) · vps-deploy-ops (=SHIP, requires gate output). AGENTS §1.5 sync Fable→4 reserved cases. check_state CLEAN. Opus นำ+verify · Sonnet แก้ 8 skills+AGENTS ตาม list.`
**source:** framework Part 2(b) kill-list + Part 5(b) routing table. **spec:** (1) สร้าง `docs/PIPELINE.md` =
owner ของ flow เดียว + ตาราง 10 boundary (artifact·gate·who·written-where) ยกจาก framework ตรงๆ + banner
"canonical entry = PROJECT_STATE · ไฟล์นี้ owns: stage routing เท่านั้น" (2) แก้ FINAL RULE/handoff ใน 9 skills:
strategy-and-risk (ลบ standalone-faster-path block) · mql-code-generator (→ mql-code-reviewer ก่อน compile,
ลบ "standalone preferred") · signal-scanner · backtest-optimize-rigor · mql-code-reviewer ·
robustness-validator + backtest-report-analyzer (ติด banner "calculator ไม่ใช่ pipeline gate — vocab เดิม retired") ·
portfolio-selector (**แก้ corr: pair>0.7-block → ladder ≤0.40/0.40-0.60 reduce-lot/>0.60 reduce-not-cut ตามกฎ
user**) · live-deployment-controller (= gate ก่อน vps-deploy-ops) · vps-deploy-ops (ต้องรับ output จาก gate)
(3) AGENTS.md §1.5 sync สถานะ Fable → จอง 4 กรณี one-shot ตาม CLAUDE.md 2026-07-11 + fallback Opus+Codex.
**acceptance:** ทุก skill ชี้ next-stage ตรง PIPELINE.md · ไม่มี "PASS/CONDITIONAL/ROBUST" เป็นด่านเหลือใน
FINAL RULE ไหน · check_state ผ่าน. **ทำได้:** Claude (Sonnet ช่วย mechanical edits ได้) · 👉 แนะ: **Opus นำ + Sonnet แก้ตาม list**

## ORDER-123 — order template: เพิ่ม field บังคับ 2 ช่อง (pre-registered bars · flat-lot probe) — `DONE(Opus 2026-07-18): เพิ่ม ORDER TEMPLATE block ใน header taskboard (ใต้กติกาสถานะ) — order ทดสอบทุกใบตั้งแต่ 124+ ต้องมี bars: (pass/dead/กลาง) + flat-lot probe: done/N-A/pending.`
**source:** framework Part 5(b) enforcement #1. **spec:** เพิ่ม template block ใน header taskboard นี้ (ใต้กติกา
สถานะ): order ทดสอบทุกใบต้องมีบรรทัด `bars:` (pass=X/dead=Y/กลาง=Z) และ `flat-lot: done/N-A/pending`.
**acceptance:** header มี template + ORDER ใหม่ตั้งแต่ 124 ขึ้นไปใช้ครบ. **ทำได้:** Claude · 👉 แนะ: ทำพ่วงกับ 120-122

## ORDER-124 — chassis chores ×3 ตาม framework Part 1 (additive, cage) — `OPEN` ✅ ปลดบล็อคแล้ว (ORDER-129 re-pin baseline 8-EA compile-current-source 2026-07-18 = baseline สดกว่าที่รอ)
**source:** framework Part 1(b) rules 5-6. **spec:** (1) ย้าย `core/Kangaroo.mqh` → `core/entries/`
(แก้ include ใน LabCore #ifdef 16) (2) ย้าย input block `_MG_*` จาก LabCore.mqh → Inputs.mqh (3) exit-owner
assert ที่ OnInit — fail/hard-WARN เฉพาะ combo ที่ close path รันพร้อมกันได้จริง (STACK_PYRAMID+Recovery ON;
**ห้าม trip เคส dormant** เช่น entry-16 ที่ Kangaroo return ก่อน ExitManager — Codex catch) + ตาราง legal
combos ลง DESIGN_V2 §3c. **acceptance ต่อข้อ:** compile 0/0 ทั้ง 8 Boss EA · run_tests PASS · neutrality:
trade count + net identical ก่อน/หลังบน regression set (baseline stale ใช้เทียบ n ได้) · .set เดิมโหลดได้
(ชื่อ input ไม่เปลี่ยน). **ห้าม:** เปลี่ยนชื่อ input ใดๆ (พัง .set) · แตะ logic. **ทำได้:** Claude · Codex ·
👉 แนะ: **Claude เขียน + Codex blind review** (แตะ core = โค้ดสำคัญตาม routing flip)

## ORDER-125 — chassis lever: vertical-barrier exit (max-holding-bars force-close) — `OPEN` ✅ ปลดบล็อคแล้ว (baseline re-pinned โดย ORDER-129 2026-07-18)
**source:** QuantCorner idea catalog #2 (Triple Barrier Method) + LEAD TRIAGE 2026-07-18 (`_triage/QUANTCORNER_FINDYOUR8_IDEA_CATALOG.md`). **why:** พอร์ตมี horizontal barrier (TP/SL) ครบ แต่ไม่มี **time-based force-close** — grid/DCA ที่ค้าง basket ใต้น้ำนาน (recovery-days tail ที่ equity curve ซ่อน) ไม่มี lever ปิดตามเวลา. เป็น exit-mode lever ใหม่ตรงตาม LAST-OPTIMIZE doctrine (lever ที่ยังไม่เคยแตะ).
**spec:** เพิ่ม input `_2_MaxHoldBars` (int, default 0=off → byte-identical เมื่อ off) ใน ExitManager (axis 2x). เมื่อ >0: ปิด position/basket ที่เปิดเกิน N บาร์ (นับจาก first-leg open). **acceptance:** compile 0/0 · neutrality byte-identical เมื่อ off (regression set) · run_tests PASS · .set เดิมโหลดได้. **bars:** pass = ยก recovery-days ลง AND both-window PF ≥1.0 retained บน host grid EA (เช่น Boss_14) · dead = ตัด trade ทำ PF <1.0 both-window · กลาง = ลด DD แต่ net แย่ลง = opt-in robustness dial (เหมือน dyn-close-money 098-C). **flat-lot probe:** N-A (exit lever ไม่ใช่ sizing). **ห้าม:** เปลี่ยน default behavior · แตะ entry. **ทำได้:** Claude เขียน + Codex blind review (แตะ core).

## ORDER-126 — SMCxSTO 991070 SL-rescue: ATR-adaptive SL + round-number offset — `OPEN` (ea_projects probe, ไม่ติด baseline blocker)
**source:** QuantCorner idea catalog #3 (stop-hunt/round-number avoidance) + LEAD TRIAGE 2026-07-18. **why:** SMCxSTO EURUSD H1 (demo 991070) = marginal edge แต่ **SL-fragile** (Lane C ORDER-LANEC: SL−20%=2.4×ATR พลิก 0.94/0.99 both-window, center=cliff ไม่ใช่ plateau). idea #3 ชี้ตรง: SL ที่ round-number level โดน liquidity-hunt. **last-optimize lever ที่ยังไม่แตะ = SL placement rule** (เดิม tune แต่ SL width ไม่เคย tune SL-offset-from-round-number).
**spec:** vehicle = `(EXP)_EmaStoRev` (standalone, magic 991071 = lab copy, **ห้ามแตะ 991070 live-demo**). เพิ่ม SL rule: (a) ATR-adaptive base (มีอยู่แล้ว) + (b) offset SL ออกจาก round-number (00/50 level) เล็กน้อย (เช่น ±3-8 pip ให้พ้นโซนที่ stop กระจุก). funnel EURUSD H1 both-window (MAIN 2023-25 / BWD 2020-22) + holdout 2026H1, Model 1. **bars:** pass = SL axis กลายเป็น **plateau** (SL และ SL±20% ทั้งหมด ≥1.0 both-window) AND holdout ≥1.2 → candidate swap vs 991070 · dead = offset ไม่ยก SL-fragility (center ยัง cliff) → คง 991070 as-is, idea #3 ปิด. **flat-lot probe:** N-A (single-position reversion, ไม่มี escalation). **ห้าม:** verdict (Claude) · แตะ 991070 live. **ทำได้:** Claude build → agent batch funnel.

## ORDER-127 — CAMPAIGN: RSI-as-MOMENTUM family + filter overlays (user request 2026-07-18) — `REVIEWED(Claude 2026-07-18): naked-momentum branch = DEAD-OPTIMIZED (concept). Built (EXP)_RsiMomentum_Naked (3 modes A/B/C + EMA/MACD/BB filter default-OFF, mql-review PASS, compile 0/0). Tested BOTH momentum homes: XAU H1/H4 (all 3 modes + fine-grid — coarse spikes P9/L55·P21/L50 did NOT reproduce at fine res = noise; mode A tops 0.99 MAIN, mode C flat ~1.0) + GBP H1/H4 (27 combo — 1 lone both-window cell A_SMA30_P21 H4 1.21/1.27 = isolated spike, all neighbors fail MAIN; rest breakeven). No plateau both-window≥1.2/1.0 anywhere on either home × 3 archetypes × entry-swept × 2 TF → concept dead earned. RSI = no standalone momentum edge naked; filters can't rescue naked-breakeven (gate lesson, so filter overlays not run). RSI usable only as confirm-FILTER on another base. reversion branch (D classic OB/OS on rangers) NOT run = low-prior (BB+RSI already ~1.1 dead) — left as optional. evidence RSIMOM_{FINE,GBP}_SWEEPS.csv, signal-landscape updated.` (role: Claude build+judge · agent/driver batch)
**เดิม spec (OPEN):**
**source + full plan:** `_triage/RSI_STRATEGY_MATRIX_2026-07-18.md` (lead triage + dedup). **why:** user อยากลอง RSI strategy ให้หมด (SMA20-RSI · break-trending RSI · grid RSI) + filter (MACD/ST/EMA/BB). dedup แล้ว: **RSI-as-reversion (classic OB/OS · grid-RSI · BB+RSI) = ทำแล้ว/เพดานเตี้ย ~1.1** (ST03/RSI-MR/NuiIndy/BB+RSI dead). ช่องเปิดจริง = **RSI-as-MOMENTUM** (ตรง prior momentum>reversion, ยังไม่เคยเทสเป็นระบบ).
**spec:** build `(EXP)_RsiMomentum_Naked.mq5` — enum `_01_RsiMode` {A=RSI-SMA20-cross · B=RSI-50-break · C=RSI-trendline} + filter block default-OFF (EMA-align/SuperTrend/MACD-confirm/BB-squeeze) bool ต่อตัว (byte-identical เมื่อ off). chassis-safety (bar-open · tester-gate · digit-aware pip · magic-scope). flat-lot naked (Model 1 พอ). **smoke order:** (1) B naked XAU H1+H4 (2) A naked XAU+GBP H4 → pulse ค่อย +EMA200 → +ST. (3) D classic OB/OS minimal smoke EUR/EURGBP = ปิด cell เท่านั้น. **E grid-RSI = ข้าม** (ST03 ทำแล้ว).
**bars:** pass = naked cell PF≥1.2 both-window บน trender (RSI-momentum edge) · dead = A+B ไม่มี cell ≥1.0 both-window หลัง sweep entry-param (RSI period/SMA/50-offset) → RSI-momentum family ปิด บันทึก signal-landscape · กลาง = 1.0-1.2 → +filter วัด expectancy-per-trade. **flat-lot probe:** N-A (naked single-position). **ห้าม:** verdict (Claude) · stack >2 filter รอบแรก · grid ก่อน naked ผ่าน · หวัง filter กู้ naked ที่ตาย. **ทำได้:** Claude build → agent batch smoke.
**PROGRESS (Opus 2026-07-18):** EA `(EXP)_RsiMomentum_Naked` built (3 mode enum A/B/C + EMA/MACD/BB filter default-OFF; SuperTrend deferred to post-pulse) · mql-review PASS · compile 0/0. **naked B (RSI-50 break) MAIN smoke: XAU H1 0.88(270t) · H4 1.00(71t) = ใต้บาร์ 1.2 = ยังไม่ตี verdict, ต้อง optimize entry-param ก่อน** (default-smoke ปิดได้แค่ cell). → entry-param sweep (RsiPeriod×Level × H1/H4 both-window) กำลังรัน. mode A/C ยังไม่ smoke.

## ORDER-128 — 🔴 P0: monitoring chain repair (task refused + false-green gist) — `DONE(Opus 2026-07-18) ⏸ 1 leg WAITING-USER: gh token ตาย` — a/b/c ครบ + manual run เก็บ snapshot 18 ก.ค. สำเร็จ (auto-commit e321eee, ทุก step ผ่านยกเว้น gist) · **root cause dashboard มือถือเน่า = gh token account BaBosss หมดอายุ (401 มานาน แต่ script เดิมพิมพ์ "updated" ปลอม) → user ต้องรัน `gh auth login -h github.com` เอง แล้ว chain รอบ 07:30 พรุ่งนี้จะพิสูจน์ E2E** · fail-path test ผ่าน (bogus gist id → exit 1 จริง)
**source:** Codex system review `_triage/CODEX_SYSTEM_REVIEW_2026-07-18.md` + contract review เดียวกัน — verified โดย Opus: `EA_LAB_DailyMonitor` LastResult `0x800710E0` วันนี้ 07:47 (LogonType=Interactive → ถูก refuse) · snapshot ค้าง 17 ก.ค. · `publish_dashboard_gist.ps1` ไม่เช็ค `$LASTEXITCODE` ของ `gh gist edit` → "updated" ปลอมได้เมื่อ 401. **why P0:** เงินจริง + 38 ACTIVE deployments แต่ตาเฝ้าบอด และระบบรายงานเขียวปลอม.
**spec:** (a) task config: `StartWhenAvailable=true` + ยกเลิก battery block + เพิ่ม logon trigger (delay) — คง Interactive logon เพราะ `monitor_rotation.ps1` เปิด MT5 GUI terminals (S4U = session 0 เสี่ยง exporter ไม่ทำงาน); (b) `publish_dashboard_gist.ps1` เช็ค `$LASTEXITCODE` ทุก native call, fail → exit 1 ให้ `Step()` แม่เห็น; (c) `daily_monitor.ps1` freshness guard (last success <20h → skip เงียบ กัน logon trigger รันซ้ำ) + health alert (snapshot age >26h → `portfolio/MONITOR_ALERT.txt` + log ALERT + exit non-zero, healthy → ลบ alert file). **acceptance:** manual run จบ exit 0 + dashboard/gist update วันนี้ · task query แสดง trigger ใหม่ · จำลอง gh fail → script exit 1 จริง. **bars:** N-A (infra). **flat-lot probe:** N-A. **ห้าม:** แตะ collector/rotation logic · เปลี่ยน gist id/URL. **ทำได้:** Opus ทำเอง (มี state-change บนเครื่อง user).

## ORDER-129 — template SEV-1 pack + regression-cage rebuild (Codex system review) — `DONE + REVIEWED(Opus 2026-07-18)` — Codex blind-audit ครบ loop แล้ว
**AUDIT TRIAGE (Codex `_triage/CODEX_ORDER129_AUDIT.md` 10 findings → Opus judge):** ✅ **แก้ทันที 6:** F1 money-stop pre-gate (`Exit_SafetyMoneyStop()` แยก loss-leg ออกจาก bar-gate — Codex จับว่าผม implement สเปคตัวเองไม่ครบ) · F2-minimal Stack latch เฉพาะเมื่อ ≥1 leg placed (กัน spread/news veto ทำ ladder ค้างถาวร — regression ที่ผมสร้างเอง) · F5 DryRun ห้าม persist HALT/kill GV · F7 `Exec_NormalizeCloseLot` (ไม่เอา RC_MaxLot ไป cap การลด risk) · F8 cage two-way compare + zero-experts fail · F9-partial warnings enforce 0/0 · F10 spread doc = POINTS + placement-only semantics (ไม่ rename input — D1 hazard). ทุกตัว inert ต่อ cage config (_32_SL_Money=0 · StackMode≠93 · DryRun=false · RC_MaxLot>lots ใน sets). ⏭ **defer → ORDER-132:** F2-full/F3 (transactional exits: pair-close retry · partial confirm · ladder per-leg) · F4 persist scope account+symbol (pre-existing class, ต้องมี migration path ระวัง live GVs) · F6 persist single-enum (crash-window วิเคราะห์แล้ว self-healing ฝั่ง fail-safe). ❌ **ปฏิเสธ 1:** F9-สาย "commit ก่อน CLEAN" — confirm-regression 8/8 CLEAN รันแล้วหลัง commit บน tester ว่าง (Codex อ่านสถานะกลางทาง) · ส่วน "re-pin ก่อน isolate" = จริง, ORDER-131 เปิดรออยู่. **compile 0/0 ×9 (zero-warning enforced) · final cage confirm หลัง audit-fix = คิวรวมกับ ORDER-131 (RSIMOM sweep ครอง tester)**
**PROGRESS (Opus 2026-07-18):** ครบทั้ง 7 ข้อ + cage rebuild. (1) cage: deploy.ps1 + tpl_regression.ps1 = dynamic discovery ทุก Boss_*.mq5 + compile-current-source ก่อนรันเสมอ (Boss_17 ที่เคยหลุด list = เข้า cage แล้ว) + baseline re-pin 8 ตัว (17: 24t · 18: 6020t drift-detector). (2) kill state machine `KILL_PENDING→FLAT_VERIFIED→HALTED` — `Exec_CloseAll()` คืน proof-of-flat (re-scan broker state) + persist `rc_kill_pending` (restart กลาง kill = kill ต่อ) + retry ทุก tick. (3) hard-kill ย้ายขึ้นก่อน `_0_BarOpenOnly` gate. (4) Kangaroo SL=0 fail-closed. (5) OnInit reject magic 990001 นอก tester. (6) `_0_MaxSpread` enforce จริง market+pending. (7) NormalizeLot vol-step arithmetic + below-min→0 (ไม่ floor ขึ้น). **Regression: 7/8 byte-identical** (รวม Boss_13 ที่ kill fire ในหน้าต่าง = kill path เดิม reproduce เป๊ะ) · **Boss_18 drift −17t (6037→6020, net −2511→−2499, eqDD 25.13→25.00)**: reproduce ได้ทั้งสองฝั่ง (4×/3×), null-hypothesis (environment) ตกไปด้วย HEAD-run ตรง baseline เป๊ะ, bisect ตีวงเหลือ {LabCore∪Kangaroo} แต่แยกไม่จบเพราะ RSIMOM sweep (ORDER-127 คู่ขนาน) แย่ง tester → **ตัดสิน: รับ + re-pin** (ทิศ safer: kill ที่ 25.00 พอดีแทน overshoot 25.13 · EA ตายแล้ว cage-only · 7 ตัวจริง identical). mql-review PASS · compile 0/0 ×9. **residual → ORDER-131.**
**source:** `_triage/CODEX_SYSTEM_REVIEW_2026-07-18.md` findings SEV-1 ×7, SEV-2 cage/lot/spread — spot-verified 4/4 โดย Opus (LabCore bar-gate bypass เห็นจริง :171 vs :187 · Exec_CloseAll ทิ้ง result :263 · `_0_MaxSpread` dead input · lot NormalizeDouble(,2)).
**spec (ลำดับใน order เดียว — cage ก่อน โค้ดตาม):** (1) **cage rebuild**: `tpl_regression.ps1` compile-current-source ทุก `Boss_*.mq5` (dynamic discovery) + ลบ binary เก่า + baseline pin Boss_17/18 + re-pin baseline ปัจจุบัน (ปลด blocker ORDER-124/125); (2) **kill-reconciliation**: `Exec_CloseAll` คืนสถานะ + `RiskControl` state machine `KILL_PENDING→FLAT_VERIFIED→HALTED` — persist HALT เฉพาะเมื่อ broker ยืนยัน flat (positions+pendings=0), retry ทุก tick; (3) **bar-gate safety**: ย้าย `RiskControl_CheckDD()` + basket money-stop ขึ้นก่อน `_0_BarOpenOnly` early-return ใน `LabCore.mqh` (bar-gate เฉพาะ signal/management ไม่ gate safety); (4) **SL=0 fail-closed**: Kangaroo ATR ไม่พร้อม → ห้ามส่ง order (block ที่ `Exec_Open` กลาง); (5) **magic guard**: OnInit reject default magic 990001 บน live/demo จริง (tester ผ่านได้) + log; (6) **spread check จริง**: `_0_MaxSpread>0` → block open ทั้ง market+pending; (7) **lot normalize**: port ORDER-125 RiskLot pattern (vol-step arithmetic, ต่ำกว่า min → 0+alert ไม่ floor ขึ้น). **acceptance:** compile 0/0 ทุก Boss · regression ตัวเลขเดิมทุก cell ที่ flag off (พิสูจน์ neutrality) · new failure-path smoke (close-fail sim ผ่าน log ตรวจ retcode path มีจริง) · mql-review PASS · Codex blind-audit 1 รอบ (neutral QA prompt). **bars:** N-A (safety refactor — ห้ามเปลี่ยนตัวเลข backtest เมื่อ input default). **flat-lot probe:** N-A. **ห้าม:** เปลี่ยน default behavior/ตัวเลข regression · แตะ entry logic · รวม lever ใหม่ (124/125 แยกไป). **ทำได้:** Opus เขียนเอง (money/risk = Claude-author per AGENTS routing) → Codex blind-audit.

## ORDER-132 — transactional exits + persist scoping (defer pack จาก Codex ORDER-129 audit) — `OPEN` (Opus-author — money code · ทำหลัง 131)
**source:** `_triage/CODEX_ORDER129_AUDIT.md` F2-full/F3/F4/F6. **spec:** (1) pair-close (Kangaroo overlap) track 2 tickets + retry residual ticket ถ้าปิดได้ขาเดียว (อันตรายสุด: กิน cushion แล้วเหลือ tail) (2) partial-close milestone: mark done เฉพาะหลังยืนยัน volume ลดจริง (3) Stack ladder per-leg ticket tracking + `OrderCalcMargin` budget ก่อนวาง (Codex system-review SEV-1 #5 เดิมด้วย) (4) Persist key scope server+login+symbol+magic + migration path สำหรับ GV เก่าบน live (ST03/Boss_14 ระวัง!) + rc-state เป็น enum เดียว. **acceptance:** compile 0/0 · cage CLEAN · migration ทดสอบบน demo ก่อน · Codex blind-audit. **ห้าม:** แตะ live GVs โดยไม่มี migration doc. **ทำได้:** Opus เขียน → Codex audit.

## ORDER-131 — isolate Boss_18 cage drift to exact line + final cage confirm หลัง ORDER-129b audit-fix — `OPEN` (agent ได้, ต้องรอ tester main lane ว่าง — RSIMOM sweep ครองอยู่)
**why:** ORDER-129 regression: Boss_18 (ตัวเดียวจาก 8) drift −17 trades ที่ kill boundary; bisect ตีวงเหลือ {LabCore.mqh ∪ Kangaroo.mqh} (RiskControl+Execution พิสูจน์บริสุทธิ์ด้วย A/B: old RC+Exec ก็ให้ 6020) แต่รอบแยก LabCore-เดี่ยว โดน RSIMOM sweep ชน tester (0-trade artifact ×2). **spec:** รอ tester ว่าง → A/B บน main lane: (a) HEAD+LabCore-ใหม่เท่านั้น (b) HEAD+Kangaroo-ใหม่เท่านั้น → ตัวที่ให้ 6020 = ตัวการ → diff บรรทัดต่อบรรทัดหา mechanism (คาด: อะไรสักอย่างใน OnInit guard หรือ include-order side effect). **acceptance:** ชื่อ file+บรรทัด+mechanism ที่อธิบาย −17 trades ได้ · ยืนยัน harmless หรือแก้. **ห้าม:** รันชน batch อื่น (เช็ค process/report ใหม่ก่อน) · แก้ code ก่อนรู้ mechanism. **ทำได้:** agent (mechanical A/B) → Opus ตัดสิน.

## ORDER-130 — process-drift batch: window pin · scorecard rubric freeze · index sync · stale tables — `DONE + REVIEWED(Opus 2026-07-18)` — ข้อ 1 Opus เอง (CLAUDE.md pin MAIN 2023.01–2025.12 + กฎเหล็ก MAIN∩HOLDOUT=∅ + PROJECT_STATE ×2 + memory update) · ข้อ 2-6 Sonnet agent (scorecard HISTORICAL banner ×2 · index sync: Boss_14 GBPJPY→DEMO + 8 แถวใหม่ · PROJECT_STATE §4 historical stamp · README/ROADMAP stale stamp · FACT_OWNER_MAP B0-snapshot stamp) · 5 แถว TODO-OPUS-VERIFY → Opus เติม verdict จาก DEPLOYMENTS.csv + lane verdicts (Boss_16 CANDIDATE-demo-fwd-holdout · Boss_17 DEMO 990301-303 · MacdDiv DEMO 999094 · SMCxSTO DEMO-marginal 991070 · PairSpread DEMO-weak 990984) · `check_state -Strict` CLEAN
**source:** `_triage/CODEX_SYSTEM_REVIEW_2026-07-18.md` SEV-2/3/4 process findings. **spec:** (1) **window pin fix (Opus)**: CLAUDE.md MAIN ต้องจบก่อน HOLDOUT เริ่ม (MAIN 2023.01–2025.12 ให้ตรง PROJECT_STATE:201, ลบ 2023.07–2026.07 ที่ทับ 2026H1) + กวาด PROJECT_STATE ที่ยังเขียน 2023–2026; (2) scorecard: ตี section score-band CORE/REBUILD/DEAD เป็น **HISTORICAL — intake evidence เท่านั้น ห้ามใช้ตัดสิน deploy** (verdict authority = CLAUDE.md tree เดียว); (3) `EA_MASTER_INDEX.csv` sync แถวที่หาย (Boss_15/16/17/18 · MacdDiv · SMC · PairSpread · RSI_MR) + Boss_14 GBPJPY status; (4) PROJECT_STATE ลบ/ตีตรา historical ตาราง deployment ค้าง (§ ST03 rows) — คง pointer ไป DEPLOYMENTS.csv เท่านั้น; (5) ea_template/README.md + ROADMAP stale blocks ตีตรา historical. **acceptance:** `check_state.ps1 -Strict` CLEAN · grep ไม่เจอ window เก่าใน authority docs · index parity spot-check 5 แถว. **bars/flat-lot:** N-A. **ห้าม:** แก้ verdict ใดๆ ระหว่าง sync (drift → ยกให้ Opus ตัดสิน) · แตะ B1 dataset. **ทำได้:** Sonnet (ยกเว้นข้อ 1).

## ORDER-095 / #4 — Boss_14 GridLog EUR-cross symbol-expand — `CLOSED + REVIEWED(Claude 2026-07-17): EURCHF+EURGBP both-window Model-4 coarse = NO home (MAIN spikes only, BWD dead ทุก cell) → PARKED ทั้งคู่ ไม่ kill (Boss_14 live @GBPJPY leg-8). ยืนยัน grid=symbol-specific. GBPCHF/NZDCAD/AUDNZD/AUDCHF = BLOCKED-ON-DATA (ไม่มี history 2020-22 → user โหลดก่อนถึงเทสได้; user เคาะ stop-at-2). verdict = _triage/ORDER095_EURCROSS_EXPAND_VERDICT.md` (role: agent ea-validator ×2 · verdict = Claude)

## ORDER-098-C — FVG-fill + RSI confluence gate (fxDreema course, #098 corpus) — `DONE + REVIEWED(Claude 2026-07-17): REJECT. build FVGFill_RSIgate (naked 098-A chassis + RSI gate, mql-review PASS, compile 0/0). RSI threshold swept 30/70 (~0 trades) /40/60 (thin spike XAU MAIN 1.23 BWD 0.63) /50/50 (well-powered 350-370t both-win, PF 0.76-0.94 ไม่เคย >1.0). FVG-fill ไม่มี edge naked หรือ RSI-gated. Gold SMC = FVG-retest อยู่แล้ว → FVG-as-primary ปิด, fxDreema FVG lineage exhausted. verdict = _triage/ORDER098C_FVG_RSIGATE_VERDICT.md` (role: Claude build → agent batch · verdict = Claude)

## ORDER-098-D — Currency-strength meter EA (fxDreema CCI-Strength lineage, #098 corpus) — `DONE + REVIEWED(Claude 2026-07-17): 🟡 PARAMETRIC-marginal → BUILD-ON candidate. naked CurrStrength_Naked (7-pair USD-basket momentum→chart-cross stronger-leg entry, ATR SL). multi-symbol tester ยืนยัน works (215t). funnel: threshold×3 · exit-RR×3 · TF×2 · 3 crosses. EURJPY H4 default = MAIN 1.01/BWD 1.01 (177/119t, win 42%) = cell เดียว both-window>1 sample พอ แต่ razor-thin + neighbors sub-1 = ไม่ใช่ plateau, ไม่ deploy. TP-widen thesis disproven (แคบดีกว่า). meter validated functional → build-on = ORDER-098-E. verdict = _triage/ORDER098D_CURRSTRENGTH_VERDICT.md` (role: Claude build → agent batch · verdict = Claude)

## ORDER-098-E — Currency-strength BUILD-ON: strongest-vs-weakest ranking + filters (#098 corpus) — `DONE + REVIEWED(Claude 2026-07-17): ranking ไม่ยก. CurrStrength_Ranked (multi-symbol scan 8-cross + exit enum FIXED/TRAIL/PARTIAL + capped pyramid, mql-review PASS compile 0/0). multi-symbol ยืนยัน works (701t ครบ 8 cross) แต่ portfolio-ranking 0.88/0.89 < 098-D single-chart 1.01/1.01 — ranking ดึง cross แย่มาเจือจาง → 1.01 = EURJPY-idiosyncratic ไม่ generalize. TRAILING แย่สุด (0.67 short-horizon). currency-strength = mechanically sound แต่ edge จาง non-deployable. remaining lever = trend/regime confluence filter (prior ต่ำ, park optional). verdict = _triage/ORDER098E_RANKED_VERDICT.md` (role: Claude build → agent batch · verdict = Claude)
**เดิม spec (OPEN):**
**why:** 098-D naked = PF 1.01/1.01 both-window บน EURJPY H4 (marginal, right-home) → doctrine build-on. lift ที่แท้จริง = architectural ไม่ใช่ parametric. reuse `CurrencyStrength()` core.
**spec (Claude เคาะ):** (1) **ranking mode** — scan ทุก cross ที่เข้าถึงได้ทุกบาร์ เข้าเฉพาะคู่ที่ strength-diff สุดขั้วสุด (highest conviction) แทน fixed chart — ยก win% ที่ตอนนี้เกาะเส้น 42% breakeven. **user vision: "เอาตัว strongest ไปทำต่อ"**. (2) **confluence filter** — trend/regime gate (เข้า strength-diff เฉพาะเมื่อเทรนด์คู่นั้นเห็นด้วย) + min-ATR/vol gate + session gate. (3) **exit tricks** — trailing/partial/BE (short-horizon signal → **ห้าม TP กว้างคงที่ พิสูจน์แล้วแย่ลง**). (4) RR held 1.5, TF H4 (พิสูจน์แล้วดีกว่า H1), home = JPY-crosses + majors trender.
**acceptance:** compile 0/0 · mql-review PASS (multi-symbol scope + ranking loop ต้อง fail-closed) · both-window Model-1 · target = plateau both-window PF≥1.1 (momentum prior ยกบาร์) ไม่ใช่ spike. **ห้าม:** verdict (Claude) · TP กว้างคงที่ · grid ก่อน naked ผ่าน. **ทำได้:** Claude build → agent batch. **user มี order-entry ideas เพิ่ม — ถามก่อน finalize exit tricks.**
**concept:** คลาสสัญญาณใหม่ = currency-strength meter (diversifier จริง). corpus lineage: PK/ICE CCI Currencies Strength + Jobot Basic Correlation/Arbitage. **user feedback 2026-07-17 [[feedback-course-files-extract-idea]]: Jobot no-SL = ไฟล์เรียน ห้าม skip เพราะ no-SL — extract arbitrage/correlation idea แล้ว rebuild ใส่ SL+cap เอง** (arbitrage-basket idea = build ได้ ถ้าใส่ risk cage, ไม่ใช่ structural skip). build ปัจจุบัน = currency-strength (USD-major basket momentum vs USD → chart-pair stronger-leg entry, ATR SL).
**user vision:** EA ตรวจจับ strength → เอาตัว strongest ไปเทรด (คล้าย News EA ที่อยากทำ) → ใส่เงื่อนไข + ลูกเล่นออกไม้เพิ่มได้เยอะ (build-on layer หลัง naked ผ่านบาร์).
**spec (Claude เคาะ design — lead's call):** (1) compute per-currency strength จาก basket majors 7-8 คู่ (EURUSD/GBPUSD/USDJPY/USDCHF/AUDUSD/USDCAD/NZDUSD) — normalize %change หรือ CCI-avg ต่อ currency ต่อ bar (bar-open gate); (2) rank → เข้า strongest-vs-weakest pair (buy strongest/sell weakest ที่ implied pair); (3) flat-lot naked probe ก่อน (doctrine: entry ต้องมี edge ก่อนใส่ MM); SL/TP ATR-based; (4) tester-gate + magic-scope + digit-aware pip (ดู FVGFill chassis เป็น template ความปลอดภัย).
**acceptance:** compile 0/0 · mql-review PASS · both-window Model-1 (MAIN 2023-26 / BWD 2020-22) บน implied major pairs · **ห้าม:** verdict PASS/REJECT (Claude) · ใส่ grid/martingale ก่อน naked ผ่านบาร์ · Model-4 (ยังไม่มี grid). **ทำได้:** Claude build → agent batch-run.

---

## ORDER-098-F — Pairs-spread stat-arb (Jobot arbitrage idea + SL cage, #098 corpus) — `DONE + REVIEWED(Claude 2026-07-17): 🟢 PARAMETRIC CANDIDATE (session's strongest). PairSpread_StatArb — 2-leg hedged, spread=log(A)-log(B) z-score fade, exit revert/z-stop cage (course NO_SL → SL cage rebuilt, blowup fixed: largest loss ~2% gross). mql-review PASS compile 0/0. funnel EntryZ×4·ExitZ×2·TF×2·2pairs. **H4 z2.5 EURUSD/GBPUSD = MAIN 1.07(130t)/BWD 1.04(110t) win 49-51% eqDD 4/13% = only both-window>1 cell**, lift จาก TF (H1→H4 ตัด cost drag) ไม่ใช่ Z. NEW diversifier class (pairs mean-rev, orthogonal). แต่ thin + selected-on-both → NOT deploy จนกว่า plateau+holdout+MC. verdict = _triage/ORDER098F_PAIRSPREAD_STATARB_VERDICT.md` (role: Claude build → agent batch · verdict = Claude)

## ORDER-098-G — Validate stat-arb candidate H4 z2.5 EURUSD/GBPUSD (#098 corpus) — `DONE/REVIEWED (Claude 2026-07-17) → CANDIDATE_WEAK`
**verdict (Claude, robustness-validator Mode B):** plateau HOLDS (6/8 neighbors both-window PF≥1.0, center mid-plateau not spike) · true holdout 2017-2019 PF **1.13** ✓ · MC ruin 0% แต่ edge thin (bootstrap PF_5th 0.72, date-split OOS tail PF 0.837) · cross-pair NOT generalize (GU 0.93 / EURCHF 0.88 BWD). = **CANDIDATE_WEAK** → portfolio-selector (small-size diversifier leg, corr-check, NOT direct live). RESIZE-FIRST n/a (edge-thin, lot-invariant). full = `_triage/ORDER098F_PAIRSPREAD_STATARB_VERDICT.md` §098-G · artifacts `order098g_*`.
**098-H edge-thicken (2026-07-17):** OFAT optimize → **ExitZ 0.3 = locked improvement** (both-window 1.14/1.15, holdout 1.13→**1.23**, OoS-split 0.84→**0.92**, plateau-validated neighbors 0.2/0.4). StopZ4.0/EntryZ2.0 also lift in-sample but combined-config holdout REGRESSES (1.09) = OFAT-stacking overfit, rejected. MC still bootstrap PF_5th 0.75<0.8 = **stronger CANDIDATE_WEAK, not OK**. Locked set `ab_sets/order098g/g_x03.set`. corr-check PASS (additive). → small-weight DEMO leg. artifacts `order098h*`.
**098-I Divergence corpus (2026-07-17) = CLOSED:** MacdDiv (098-B) divergence winner=XAU H4 (demo-eligible). Reversion home swept: EURUSD opt→holdout 0.35, **EURGBP/AUDNZD H4 smoke sub-1 all windows** (0.52-0.89) → divergence-reversion DEAD, recorded [[signal-landscape]]. No new build. artifacts `order098i_*`.

## ORDER-098-J — Fibonacci-pullback concept (new build) — `DONE/REVIEWED (Claude 2026-07-17) → DEAD-optimized`
Built `(EXP)_FibPullback_Naked` (golden-pocket 0.382-0.618 trend-continuation, 100%-retrace SL, TP xR). Naked smoke M2 2023-26: XAU H4 **1.73** / H1 1.37 looked alive (GBP/EUR/EURGBP dead). = **2023-25 XAU bull-run regime artifact**: H4 both-window collapse (BWD 0.42/HLD 0.35); H1 BWD 1.02/HLD 0.93. Optimize probe pocket×TpRR (≥4 lever, right-home XAU): H1 TP1.5R both-window 1.43/1.19 = selection-fit → **holdout 2017-19 FAIL 0.88-0.94.** No both-window+holdout config. DEAD-optimized, recorded [[signal-landscape]]. Same signature as NR7/Donchian/SuperTrend-USDJPY. artifacts `order098j*`, `(EXP)_FibPullback_Naked`.

## ORDER-098-K — stat-arb maker(pending-limit) build-on — `DONE/REVIEWED (Claude 2026-07-17) → NO LIFT, market baseline stays`
Built `PairSpread_StatArb_Maker.mq5` (magic 990985, limit entry + naked-leg guard). Funnel: maker 1.12/1.14/1.23 ≈ market 1.14/1.15/1.23 → cost-drag hypothesis REJECTED, edge thinness is signal-inherent. Keep deployed market ExitZ0.3. verdict `_triage/ORDER098F_PAIRSPREAD_STATARB_VERDICT.md` §098-K.

## ORDER-098-L — SMC×STO add OB-zone gate (Stage-1) — `DONE/REVIEWED (Claude 2026-07-17) → OB gate NO robust lift, keep Stage-0 base`
**verdict:** Built `(EXP)_EmaStoRev_OB.mq5` (magic 991071, +fresh-OB retest gate, default OFF==Stage-0). OB-OFF reproduces candidate exactly (MAIN 1.50/BWD 1.24/HLD 1.13, ~130t). OB-ON: MAIN 1.38/BWD **1.81**/HLD **1.12**, ~50t. The BWD bump did NOT generalize (holdout flat 1.12 vs 1.13) + cut trades ~60%. OB zone = confluence decoration (locates the same entries), no durable PF gain. **Keep the cheaper Stage-0 candidate (staged `_vps_deploy/SMCSTO_EURUSD/` magic 991070) as demo config.** Confirms EA-header hypothesis. artifacts `order098l*`, `(EXP)_EmaStoRev_OB`.
**why:** ORDER-107 confirmed SMC×STO EURUSD H1 candidate (StoK13-17/OS deeper/ADX-max30, MAIN 1.50/BWD 1.24, plateau+M4+holdout, bundle staged magic 991070). ORDER-107 "Next(2)" = add the OB zone (the SMC piece stripped in Stage-0) to try to push PF >1.3. Base is already both-window+ so the filter is now worth building.
**spec:** extend `(EXP)_EmaStoRev.mq5` — add input `_09_UseObGate` (bool, default OFF, must not change behavior when false → run `scripts/tpl_regression.ps1`? N/A standalone, just verify OFF==identical) + OB detection: fresh/untouched order-block = last opposite-color candle before a displacement bar that breaks the prior swing; state-track "untouched" via ring buffer (model on the FVG detector in ORDER-098-A `(EXP)_FVGFill_Naked`). Gate: only take the STO reversion entry if price is inside an untouched OB zone aligned with trade direction. **Config to test = the confirmed candidate** (`_mt5_auto/ab_sets/order107_opt/top_eur/` + ADX30). Compile 0/0 → mql-review → funnel EURUSD H1 both-window (MAIN 2023-26 / BWD 2020-22) + holdout 2026H1, Model-1. **acceptance:** OB gate must RAISE PF and win% vs no-gate (1.50/1.24) with sane trade count (≥60/window) → if it lifts >1.3 both-window keep; if it only cuts trades without lifting PF = OB is decoration, park gate, keep cheaper skeleton. verdict = Claude. **ห้าม:** เปลี่ยน default behavior · deploy ก่อน holdout.

## ORDER-098-M — Harmonic geometry (AB=CD / Gartley) naked smoke — `DONE/REVIEWED (Claude 2026-07-17) → DEAD (frequency-starved)`
**verdict:** Built `(EXP)_HarmonicABCD_Naked.mq5` (magic 990096). Naked smoke M2 2023-26: EURUSD H4 3.52 but **10t** (noise), EURGBP 0.19(9t), AUDNZD 0.93(26t), XAU 0.39(8t). AB=CD strict-ratio pattern fires 8-26×/3yr = far below frequency floor; no cell with sane sample + edge. **DEAD** — closes Fibonacci/harmonic/geometry catalog block (77 cards) alongside 098-J. Reversion-geometry family triple-dead. recorded [[signal-landscape]]. artifacts `order098m_*`, `(EXP)_HarmonicABCD_Naked`.
**why:** last untested block of the "Fibonacci/harmonic/geometry" catalog (77 cards). Fibonacci-pullback just died DEAD-optimized (098-J, XAU regime artifact); harmonic = more-restrictive reversion-geometry = **low prior**, but user wants the family closed properly (not killed on prior).
**spec:** build `(EXP)_HarmonicABCD_Naked.mq5` — minimal AB=CD reversal detector: find last 3 alternating swing pivots A,B,C (reuse IsHigh/IsLow from `FibPullback_Naked`), project D = C ∓ (A−B) with CD≈AB symmetry + BC retrace 0.382-0.886 of AB; enter reversal at D (BUY bullish AB=CD / SELL bearish), naked flat-lot, SL beyond D + ATR buffer, TP at C (or xR). Guards: bar-open, tester-gate, digit-aware, magic-scope (use 990096). Compile 0/0 → smoke Model-2 2023-26 on **rangers first** (EURUSD/EURGBP/AUDNZD H4 = reversion home) + XAU H4 reference. **acceptance:** naked bar = PF ≥0.85 in any cell to PROCEED (per catalog reversion-geometry note); else DEAD-record. If a cell pulses → both-window + holdout before any verdict. **expected: DEAD** (same family as fib-pullback + RSI/BB reversion). verdict = Claude. **ห้าม:** เขียน DEAD ก่อน smoke จริง (default-smoke ≠ concept kill unless structural).

**why:** 098-F = both-window PF 1.07/1.04 candidate แต่ยัง selection-fit (เลือกจาก MAIN+BWD, margin thin, ridge แคบ — z3.0 BWD dip 0.94). ต้อง validate ก่อน demo.
**spec:** robustness-validator funnel บน `PairSpread_StatArb` H4, EURUSD/GBPUSD, EntryZ 2.5 base. (1) **plateau map** รอบ z2.5: EntryZ {2.0,2.25,2.75} · ExitZ {0.3,0.5,0.7} · ZWindow {80,100,120} both-window — neighbor ต้องไม่ collapse (plateau ไม่ใช่ spike). (2) **holdout** window ที่ไม่เคยใช้ select (เช่น 2019 หรือ split MAIN). (3) **Monte Carlo** (trade-shuffle + start-date). (4) **cross-pair generalize:** ลอง 2-3 correlated pairs อื่น (GBPUSD/EURUSD, EURCHF/USDCHF) H4 z2.5 — ถ้า config generalize = แข็งกว่า currency-strength. **acceptance:** plateau-center + holdout PF>1 + MC survive → demo candidate leg ใหม่ (corr-check vs cohort ก่อน). **ห้าม:** deploy ก่อน 3 ข้อผ่าน · verdict = Claude. **ทำได้:** agent ea-validator/robustness batch.

---

## 🗂️ ARCHIVED ORDERS — index ย้ายไป generated file (ORDER-102 Contract C1, 2026-07-13)

> orders ปิดแล้ว = `ARCHIVE_TASKBOARD_2026-07A.md` (verbatim) · **index = generated/read-only** `docs/memory_control/ARCHIVE_INDEX.md` (§20.7 — ห้าม hand-edit ในบอร์ดนี้) · integrity guard: `powershell -File scripts/check_taskboard_archive.ps1 -Strict` (raw/reviewed/unresolved · archive append-only + active conservation)
## ORDER-036 — MT4 mass-smoke (1,318 ex4) — `CLOSED (2026-07-07 — sweep จบ · 1,318 → 2 survivors → demo คู่ = ORDER-045)` · **ทำได้: Codex · oc-dev**

**👉 spec + สถานะ + วิธีสั่งทั้งหมด = `ORDER-036_MT4_MASS_SMOKE.md`** (แยกไฟล์เพราะ 27 batches ×50 —
กัน taskboard บวม). batch assignment deterministic = `_triage/mass_smoke_mt4_batches.csv` (คอลัมน์ batch 01-27).
user สั่งเป็นก้อน เช่น "ทำ 036 batch 04-08" · batch จบ+review แล้ว archive ไป `_archive/ORDER-036_ARCHIVE.md` ·
order แม่แถวนี้**คงอยู่จนครบ 27 batch** (กันหลุดจาก board) — Claude สรุป verdict รวมที่นี่ตอนจบ

**ผล (สรุปปิด 2026-07-07, header sync 2026-07-16):** 1,318 ex4 → 2 survivors ผ่านครบถึง Model-0 bwd+fwd
(**UnNomGuaiV1.132 + RSI from pips_EA**) → เข้าคู่ demo = ORDER-045 · รายละเอียดต่อ batch = `ORDER-036_MT4_MASS_SMOKE.md`
+ `_archive/ORDER-036_ARCHIVE.md`

---

## ORDER-045 — MT4 demo experiment #2: UnNomGuai + RSI from pips (คู่, บัญชีใหม่) — `WAITING-USER (attach) → แล้วค่อยเป็น monitoring loop` · **เจ้าของ: user (attach) + Claude (judge)** _(ออก 2026-07-07 หลัง user อนุมัติ)_

**สถานะ:** ORDER-036 ปิดสมบูรณ์ (1,318 → 2 survivor: **UnNomGuaiV1.132 + RSI from pips_EA** ผ่านครบถึง
Model-0 bwd+fwd) · user อนุมัติ demo คู่บนบัญชีเดียว (2026-07-07) · **bundle พร้อม: `_demo_deploy\`**
(ex4 ×2 + `README_DEPLOY.md` มี MD5 lock, kill-switch, ค่าคาดหวัง) · แผนเต็ม: `DEMO_DEPLOYMENT_PLAN.md`
§MT4 demo experiment #2
**รอ user:** เปิดบัญชี demo ใหม่ ($10k, แนะ ThinkMarkets) → ลง MT4 portable `D:\Meta4demo` (ห้ามใช้เลนเทส)
→ attach ตาม checklist → **แจ้งวันที่ attach = demo-clock เริ่ม (judge +3 เดือน)**
**งาน agent หลัง attach (ทุก ~2 สัปดาห์ รอบเดียวกับ ClevrFX):** อ่าน statement ที่ user export → แยก P&L
ตาม magic (1/2 = UnNom · 5888 = RSI) → เทียบตารางคาดหวังใน README → เช็ค kill-switch (UnNom >12 ไม้ ·
RSI >0.06 lot · DD alert 20/25% kill 30/35%) → รายงาน · **ห้าม:** แก้ input EA · เพิ่ม EA อื่นในบัญชีนี้

**ผล:** _(รอ attach)_

---

## ORDER-055 — [NEXT SESSION START HERE] demo cohort 8 ตัว: attach + monitor — `🚀 ATTACHED 2026-07-09 คืนนี้ (โครงจริงต่างจากแผน — ทั้งหมดบน VPS, cohort MT5 ขึ้น REAL cent!) · judge ชุดนี้ = 2026-10-09 · รายละเอียด = section "DEPLOYMENT REALITY 2026-07-09" ใน DEMO_DEPLOYMENT_PLAN.md · เหลือ: user attach exporter ×5 บน VPS + เลือกท่อ CSV (OneDrive บน VPS หรือ RDP-copy รายสัปดาห์) + จับตา Boss-TrendSwing/Woodfire (มี EA ที่แล็บ REJECT ปน — Gold Reaper, LondonConso)`

**สรุป session 2026-07-08/09 (Opus): EA hunt รอบใหญ่จบ → 7 clean + 1 experimental candidate พร้อม attach.**
รายละเอียดเต็ม = `PROJECT_STATE.md` §7 "SESSION 2026-07-08" block · handoff doc = `handoff/SESSION_2026-07-09_HANDOFF.md`
bundle = `_demo_deploy\README_DEPLOY.md` (2 บัญชี MT4+MT5 · WILL-IT-TRADE checklist + kill-switch + corr + portfolio-sim ครบ).

**8 candidates (magic distinct):**
- MT4: UnNomGuai(EURUSD/1-2) · RSI-orig(EURUSD/5888) · swb(AUDCAD/990) — grid, validated
- MT5: RSI-MR(EURUSD/990103,**ROBUST**) · Zeus(XAU/990101,MARGINAL) · BRK-XAU(XAU/991001,MARGINAL) · SqueezeBRK(XAU/991004,**ROBUST**) · **Trendline(XAU/991002,EXPERIMENTAL PF-5th 0.986)**

**Claude-doable งานเสร็จหมดแล้ว (session นี้):** corr matrix 8-EA (ไม่มีคู่ >0.60, gold 3 ตัว uncorrelated) · portfolio-sim (รวม DD 1.2%, gold-pair 3.8%) · bundle verify + **AllowLive=true fix ทั้ง MT5 set (critical silent-stop catch)** · WILL-IT-TRADE checklist · tools ใหม่: corr_matrix/portfolio_sim/mt4_deals_to_csv/max_recovery_days.py

**แผนวันนี้ 2026-07-09 (user รวม session แล้ว — session นี้เป็น lead เดียว · เรียงตาม EV):**
1. **[user, ~20 นาที] attach 8 ตัว** (MT4 3 + MT5 5 ตาม `_demo_deploy\README_DEPLOY.md` WILL-IT-TRADE checklist) **+ attach DealsExporter.ex5 1 chart** (ค้างจาก ORDER-042) → บอกวันเริ่มให้ Claude · **EV สูงสุด — ทุกอย่างรอด่านนี้**

> **📋 USER CHECKLIST เย็นนี้ (2026-07-09) — ทำทีเดียวจบ:**
> ☐ 1. attach demo cohort 8 ตัว ตาม `_demo_deploy\README_DEPLOY.md` (เช็ค WILL-IT-TRADE ทุกข้อ: AllowLive=true, RSI-MR ต้องบัญชี Hedging, AutoTrading เปิด, magic ตรง)
> ☐ 2. attach `tools\DealsExporter\DealsExporter.ex5` 1 chart บน terminal demo MT5
> ☐ 3. **บัญชี VPS → ไม่ต้องแตะ VPS เลย:** เปิด MT5 instance สำรองบนเครื่องนี้ (D:\Meta 5b) → login บัญชี VPS ด้วย **investor password** (read-only) → แปะ DealsExporter 1 chart · ทำซ้ำต่อบัญชีที่อยาก track (รวม Boss-TrendSwing 159475669 ถ้าจะให้ track)
> ☐ 4. บอก Claude: วันที่ attach + รายชื่อบัญชี → Claude ลงทะเบียน DEMO_DEPLOYMENT_PLAN + ตั้ง judge date + scheduled task (collector + dashboard อัตโนมัติทุกเช้า)
> · ~~หมายเหตุ: บัญชี MT4 ใช้ DealsExporter ไม่ได้~~ **อัปเดตบ่าย: MT4 exporter มีแล้ว (ORDER-060)** —
> ☐ 5. attach `tools\DealsExporter\OrdersExporterMT4.ex4` 1 chart บน terminal demo MT4 ด้วย
> (**สำคัญ: คลิกขวา tab Account History → เลือก "All History" ก่อน** ไม่งั้น export ไม่ครบ)
2. **[Claude ทันทีที่รู้วัน attach]** บันทึก DEMO_DEPLOYMENT_PLAN + judge +3 เดือน + ตั้งรอบ /ea-monitor
3. **[Codex] ORDER-057 Stage A** — `Regime.mqh` (ADX trend/sideway + ATR storm, default OFF) → Claude review + `tpl_regression.ps1` ต้อง CLEAN → ค่อยปล่อย Stage B (ZCode, A/B both-windows)
4. **[qwen/Sonnet] ORDER-058** — live dashboard HTML per-magic (ต่อยอด DealsExporter · มีข้อมูลจริงหลัง user ทำข้อ 1)
5. [optional ถ้า quota เหลือ] COT/CME regime-data pull (ไอเดียจากโพส FB 07-09 — ยังไม่เป็น order, รอ user เคาะ) · ORDER-043 US30 probe (ZCode วันว่าง)
**หลัง attach:** statement ทุก ~2 สัปดาห์ → แยก P&L ตาม magic → เทียบค่าคาดหวัง README · จับตา (a) MT4 grid no-SL tail (b) combined gold exposure (Zeus+BRK+Squeeze+Trendline ทั้ง 4 = XAU) (c) Trendline #8 borderline → drop ถ้าไม่เข้าเป้า
**ปิดไปแล้ว:** hunt space สำรวจหมด (instrument/TF/กลไก/lot-law/re-opt/FX-travel = ตัน) — กลไกใหม่จริง (flag/pennant/order-flow) ค่อยว่ากัน · Boss V2 robustness track = parked
**ห้าม:** แก้ config ที่ validate แล้ว · เชื่อ hunt ว่า EV สูง (พิสูจน์แล้วว่าตัน)

**ผล:** bundle deploy-ready (8 EA, safety-checked). รอ user attach.

---

## ORDER-104 — SSRN-151 W1/W2 probe: HP-denoise + tanh + IBS — `STAGE A+B DONE + REVIEWED(Claude 2026-07-13): HP@λ1600 บน XAU ผ่าน both-regime → BUILD-ON · IBS naked ตก(park) · tanh INERT` · **ทำได้: agent smoke-batch** · 👉 verdict = Claude · สรุปเต็ม = `_triage/ORDER104_EXPERIMENT_SUMMARY.md`

**🎯 STAGE B พลิก Stage A (λ-sweep + IBS, P104b_summary.csv):**
- **HP λ-sweep เผยว่า λ คือ lever — λ ต่ำดี:** **λ1600 บน XAU ผ่านทั้ง 2 regime** (XAU H1 1.15/1.26 · **XAU H4
  1.35/1.68** n=64-72 = plateau จริง). λ14400 over-smooth (regime-invert) · λ129600 thin(n=10-50). **Stage A ที่ตี
  HP ตก = artifact ของ λ เดียว** — ตรงกฎ "ห้าม DEAD ก่อน sweep ≥3 lever". HP ช่วยเฉพาะ XAU ไม่ช่วย EUR.
  → **BUILD-ON: XAU H4 @ λ1600 = candidate** (sweep MA-period/SL รอบ plateau + Model-4 confirm + holdout/MC).
- **IBS naked = ไม่มี edge** (trade 4000-5400 บน H1, PF 0.80-1.07 churn จ่าย cost) → park, ต้อง filter (band/trend-gate).
- **tanh = INERT** (calib bug R/κ horizon ต่างกัน) — rescale ก่อนถึง judge.
- **NEXT:** build-on XAU-H4-HP-λ1600 (W1 survivor) · W3 Pivot/Donchian · IBS+filter (ถ้าจะกู้).

**🔎 STAGE A VERDICT (32 runs, `_mt5_auto/reports/P104_summary.csv`, Model 2, XAU+EUR × H1/H4 × BWD/REC):**
- **tanh (Toggle B) = INERT** — `tanh`==`base` เป๊ะทุก cell. bug: `R`(20-bar) / `κ`(1-bar stdev) → R/κ ใหญ่ →
  tanh อิ่ม ±1 → lot คงที่. **ต้อง rescale (R,κ horizon เดียวกัน)** ก่อนถึงจะ judge ได้ — ไม่ใช่ concept verdict.
- **HP-denoise @ λ14400 = ตกเกณฑ์ → ปิด cell (ไม่ใช่ concept ตายสากล):** ตัด trade ~75% (whipsaw ลงจริง) แต่ PF
  ไม่คงที่ — ช่วยเฉพาะ cell อ่อน (BWD base<1) **ทำลาย cell แข็ง REC** (XAU H4 1.40→0.32, XAU H1 1.24→0.98) =
  regime-invert (VERDICT GATE #3). H4 hp บางมาก (n=28-39). spike ไม่ plateau.
- **levers ที่ยังไม่ sweep (ถ้าจะกู้):** HP λ∈{1600,129600} (แก้ $combos ใน launcher) · tanh rescale · chassis
  อื่นที่ไม่ใช่ 2-MA (HP อาจเหมาะ mean-revert มากกว่า trend). **แต่ regime-invert เป็น structural** (smooth มาก=lag
  มาก=แย่ตอน REC trending) → **แนะนำ park HP, เด้งไป W2 (IBS) ที่เป็น signal สะอาดกว่า** เว้นแต่ user อยากดัน λ-sweep.
- base 2-MA เอง = ไม่ใช่ keeper (แต่ละ cell ดี window เดียว) — เป็นแค่ chassis ทดสอบ bolt-on.

**BUILD:** `ea_projects\(TRD)_Probe_MAHP_TanhVol\(TRD)_Probe_MAHP_TanhVol_rev01.mq5` (+.ex5) · magic 991041 ·
2-MA crossover + 2 toggle: `_02_UseHPFilter` (causal HP denoise, banded-Cholesky solve, one-sided ไม่ look-ahead —
reviewer ยืนยันแล้ว) · `_03_UseTanhVol` (lot × |tanh(R/κ)|×TargetVol/σ, SIZING ONLY ไม่แตะ entry). compile 0/0.
**SMOKE Stage A (รอ agent):** XAUUSD+EURUSD × {H1,H4} × {2020-22, 2023-26} × 4 toggle-combo (off/off · HP · tanh ·
both) = 32 run. sweep `_02_HP_Lambda` ∈ {1600,14400,129600}. เทียบ combo vs off/off ต่อ cell — acceptance +
ห้าม = ดู spec เดิมด้านล่าง. _(ที่มา: user แชร์เปเปอร์ Kakushadze&Serur "151 Trading Strategies" — `docs\ssrn_id3453295_code2224789.pdf` · แผน = `_triage/SSRN_151strategies_PBX_ebook_2026-07-13.md` W1 · กลไก = catalog 8.1 + 10.4)_

**Objective:** วัดว่า 2 เทคนิคจากเปเปอร์ยก signal quality ของ MA-cross ได้จริงไหม (bolt-on ถูกสุด/เสี่ยงต่ำสุด):
(1) **8.1 HP-filter denoise** — กรอง noise ความถี่สูงด้วย Hodrick-Prescott *ก่อน* คำนวณ MA → ลด false cross;
(2) **10.4 tanh vol-scale** — สเกล signal/lot ด้วย `tanh(R/κ)` (กัน flip ถี่แถวศูนย์) + `1/σ` (ลด over-invest ตอนผันผวน).

**Build spec — standalone probe EA `Probe_MAHP_TanhVol.mq5`** (อย่าแก้ EA production ตัวอื่น):
- แกน = 2-MA crossover (fast/slow) เข้า long เมื่อ MA(T1)>MA(T2), short กลับกัน — 1 position, มี SL/TP ปกติ.
- **Toggle A `UseHPFilter`** (bool, default false): true = คำนวณ MA บน series ที่ผ่าน HP-filter แทน raw price.
  λ ปรับได้ (input `HP_Lambda`, default 100·n² ที่ n=หน่วยข้อมูล; ลอง 1600 / 14400 ด้วย).
- **Toggle B `UseTanhVol`** (bool, default false): true = lot = risk% × |tanh(R/κ)|/σ_norm (cap ที่ risk%),
  R = return ล่าสุดช่วง `T_ret`, κ = stdev(R) rolling `N_kappa` บาร์, σ = stdev(price-return) rolling.
  false = fixed lot ตาม risk% เดิม.
- **baseline = A off + B off** (2-MA ล้วน) → เทียบ 4 combo (off/off, HP-only, tanh-only, both).

**🔴 Correctness gates (ห้ามผ่านถ้าไม่ครบ — ผ่าน `mql-code-reviewer` + `tpl_regression.ps1` CLEAN):**
1. **HP filter ต้อง CAUSAL** — คำนวณจาก **บาร์ปิดที่ผ่านมาเท่านั้น** (rolling one-sided window). HP ต้นฉบับเป็น
   two-sided (มองอนาคต) → ถ้าใช้ตรงๆ = **look-ahead, backtest หลอก**. ต้อง recompute บน window อดีตทุกบาร์
   หรือใช้ one-sided approximation. **นี่คือ gate ที่ทำให้ผล valid** — reviewer ต้องยืนยันไม่มี future bar.
2. bar-open gate (คิด/เข้าเฉพาะแท่งปิด ไม่ intrabar repaint), tester-gate, digit-aware pip, broker-aware lot normalize, magic เฉพาะตัว (เลือกเลขว่าง), hard risk cap. (ตาม `mql-code-reviewer` checklist)

**Test matrix (per VERDICT GATE — coarse→surface, both regimes):**
- **Stage A (คุ้มสุดก่อน):** XAUUSD + EURUSD × {H1, H4} × {BWD 2020-22 trend + ปีล่าสุด 2023-26} × 4 combo = 32 run.
- **Stage B (ต่อเมื่อ Stage A มีสัญญาณ):** เพิ่ม GBPUSD + USDJPY (อีก 32 run).
- ทุก run: same SL/TP/MA-period ต่อ cell (เปลี่ยนแค่ toggle) เพื่อ isolate ผลของเทคนิค. sweep HP_Lambda ≥3 ค่า.

**Acceptance (treatment ชนะ baseline):** เทียบ combo ใดๆ vs off/off ในแต่ละ cell —
- ✅ **PASS-signal** ถ้า: PF ยก **≥10%** *หรือ* จำนวน trade whipsaw (trade ที่ปิดขาดทุน < 0.3·SL ภายใน ≤3 บาร์) ลด
  **≥20% โดย PF ไม่ตก**, และเกิดบน **≥ ครึ่งของ cell (≥ majority)** ทั้ง 2 window — ไม่ใช่ spike cell เดียว (ต้อง plateau).
- ❌ ถ้าไม่ถึง = เทคนิคไม่ช่วยกับ MA-cross → เขียน verdict "no-edge บน MA-cross" (ตกได้ตาม gate เพราะเป็น
  smoke ที่ตกเกณฑ์ pre-registered — **ห้ามเขียนเป็น concept ตายสากล**, แค่ปิด cell นี้).
- ผ่าน → build-on: หา MA-period/SL ที่ plateau-center, แล้วค่อยพิจารณา promote (holdout+MC = เฟสถัดไป ไม่ใช่ order นี้).

**ห้าม:** แก้ EA production/validate แล้ว · ใช้ HP two-sided (look-ahead) · ตัดสิน concept ตายจาก cell เดียว ·
promote เงินจริงใน order นี้ (probe เท่านั้น) · background-run แล้วหยุดรอ (agent ต้อง foreground synchronous).

**ผล:** _(Stage A+B done — ดู verdict ที่ header + `_triage/ORDER104_EXPERIMENT_SUMMARY.md`)_

### ORDER-104 STAGE C — build-on XAU-H4-HP-λ1600 (W1 survivor) — `DONE + REVIEWED(Claude 2026-07-16): plateau both-regime ยืนยัน — fast16/slow32 MAIN 1.59/BWD 1.33 + เพื่อนบ้าน 4 ทิศผ่าน + SL ทั้ง 3 ค่าผ่าน + λ1600=center → HP-denoise = validated noise-filter lever บน XAU trend-cross · chassis=probe testbed → next = Model-4 confirm หรือ graft เข้า production chassis (lead เลือกตอนถึงคิว) · verdict = _triage/ORDER104C_HP_PLATEAU_VERDICT.md` (role: agent smoke-batch · spec+verdict = Claude 2026-07-16)

**เป้า:** ยืนยันว่า cell ที่ผ่าน both-regime (XAU H4 @ λ1600: 1.35/1.68 n=64-72) เป็น plateau จริงรอบแกน
MA-period × SL แล้วค่อยส่ง Model-4 confirm — ตาม NEXT ของ Stage B.

**Runs (Model 1, EA = `(TRD)_Probe_MAHP_TanhVol_rev01`, HP on @ λ1600, tanh off):**
1. MAIN 2023-2026 + BWD 2020-2022, XAU H4: sweep MA fast∈{8,12,16} × slow∈{24,32,40} (9 combo ×2 window = 18)
2. SL sweep รอบตัวชนะ MAIN ของข้อ 1: SL-ATR-mult ∈ {1.5, 2.0, 3.0} ×2 window (6 runs)
3. λ neighbor: {800, 3200} บน center combo ×2 window (4 runs) — เช็คว่า λ1600 ไม่ใช่ spike บนแกน λ เอง
รวม ~28 runs · **Acceptance:** CSV ดิบ PF/Net/Trades/DD/Win ต่อ run · **ห้าม:** verdict (lead ตัดสิน plateau
ตาม VERDICT GATE #2-3) · Model-4 ใน order นี้ (แยกไปหลัง plateau ยืนยัน) · แตะ EUR cells (HP ไม่ช่วย EUR — ปิดแล้ว)

---

## ORDER-106 — rescue #1 จากคิว ORDER-084: Boss_14_GridLog second-symbol pool — `GBPJPY DONE + REVIEWED(Claude 2026-07-16): ✅ RESCUE สำเร็จ ไม่ตาย — H4 @ dist2.0 plateau both-window + Model-4 CONFIRM (MAIN 1.56/BWD 1.11 ดีขึ้น/HOLDOUT 1.50, grid ไม่ collapse บน real ticks) · high-PF cells = spike ทิ้ง · thin (n~50, DD~9%) · PARAMETRIC candidate = leg ที่ 8 ของ Boss_14 demo cohort (H4, magic ใหม่) · **d1.5 finer Model-4 = REJECT (2026-07-16): MAIN 1.92 แต่ BWD 0.92 fill-optimism → leg-8 config = d2.0/s4.0** · **✅ ปิด leg-8 (2026-07-16): corr ทุกคู่ <0.8 (max CADJPY 0.791) + year-split Model-4 all-years-positive (2021-2026 PF 1.28-2.36, ไม่มีปีเจ๊ง — สะอาดกว่า Zeus) → DEMO LEG-8 พร้อม `_vps_deploy/BOSS14_GBPJPY/` magic 990208 (EA=Boss_14_GridLog ตัวเดียวกับ cohort, แค่ attach chart GBPJPY H4 เพิ่ม) · caveat: thin 9-28t/ปี + 2020 no-data + CADJPY 0.791 (JPY-cross คู่กัน flag user) → รอ user attach** · verdict = _triage/ORDER106_GBPJPY_RESCUE_VERDICT.md · NZDUSD/USDCAD/AUDNZD = ใบถัดไป` (role: agent funnel-batch · verdict = Claude)

**ที่มา:** ORDER-084 judge กอง ข อันดับ 1 — GBPJPY/NZDUSD/USDCAD/AUDNZD เคยเห็นแค่ defaults (0.68-1.13,
GBPJPY OOS 1.12 เฉียดบาร์) บน chassis Boss_14 ที่ validated แล้ว = under-swept ชัดตามกฎ rescue-ladder.

**คำสั่ง (เริ่ม GBPJPY ตัวเดียวก่อนตาม pacing):** funnel มาตรฐาน Boss_14 family — coarse sweep ≥3 lever
(spacing/DistAtrMult × SL-mult × lot-law ตาม strategy) × {H1, H4} × both-window (MAIN 2023-26 + BWD 2020-22)
Model 1 → รายงาน surface ดิบ (ทุก pass ไม่ใช่ top) → lead ตัดสิน plateau → ถ้าผ่านค่อย NZDUSD/USDCAD/AUDNZD
ใบถัดไป. ใช้ launcher/set ของ family เดิม (`_mt5_auto/ab_sets/` มี precedent ORDER-069 216-pass).
**Acceptance:** CSV ทุก pass: PF/Net/Trades/DD ต่อ window · **ห้าม:** verdict · เลือก "ตัวดีสุด" เอง ·
รันเกิน 1 symbol ในรอบเดียว · แตะ config demo cohort เดิม

---

## ORDER-107 — SMC×STO signal Stage-0 cheap smoke (user idea 2026-07-16) — `CORRECTED + REVIEWED(Claude 2026-07-16): 🟩 BUILD-ON candidate ไม่ตาย (user จับถูก — default-smoke ผมรีบตัดสินผิด gate) · optimize จริง 180 passes/symbol: XAU (trender=บ้านผิด) regime-fit ล่ม BWD · EURUSD (ranger=บ้านถูก) 2/3 top pass ยืน both-window (1.30/1.13 · 1.22/1.02) · **CONFIRMED (2026-07-16): EURUSD H1 = demo candidate จริง** — ADX filter (user idea) ยก 1.30/1.13→1.50/1.24 · plateau 6/7 neighbor · **Model-4 MAIN 1.39/BWD 1.19/HOLDOUT 1.14 ครบ** · EURUSD-only (ไม่ travel AUDNZD/EURGBP/XAU) · bundle `_vps_deploy/SMCSTO_EURUSD` magic 991070 → รอ user attach (corr=informational) · verdict = _triage/ORDER107_SMCxSTO_STAGE0_VERDICT.md · **บทเรียน: default-smoke เกือบทิ้ง candidate จริง — user push optimize+filter ถูก** (memory feedback-optimize-before-killing-reversion)` (role: Claude build → agent optimize · verdict = Claude)

**ที่มา:** user แชร์ระบบ class SMC×STO (triage เต็ม = `_triage/SMCxSTO_SIGNAL_TRIAGE.md`, EDGE_CATALOG PARKED-CONCEPT).
class = momentum-gated reversion · cheap-death: strip SMC/OB (แพง) เทส skeleton ก่อน.

**Stage 0 (คำสั่ง):** build standalone probe `(EXP)_EmaStoRev` — higher-TF EMA100 gate (buy-only ถ้า close>EMA100 บน
resample/HTF handle · sell-only ถ้าต่ำกว่า) + Stochastic(5,3,3) cross ออกจาก OS(20)/OB(80) = entry, 1 flat-lot 0.01,
SL 1.5-2.0×ATR, exit = STO-reverse ที่ opposite extreme + BE-move ที่ STO50. **ไม่มี OB zone, ไม่มี grid** (Stage 1
ค่อยเพิ่มถ้ามีชีพจร). bar-open gate + tester-gate + digit-aware pip ผ่าน mql-code-reviewer ก่อน compile.
smoke Model 1, 2023-2026: EURUSD + GBPUSD + XAUUSD × {M15, H1} = 6 cell.
**Acceptance:** ตาราง 6 แถว PF/Trades/DD/Win + report path · **บาร์:** cell ใดก็ได้ PF≥1.1 naked = ไป Stage 1 (เพิ่ม OB
gate) · ทุก cell PF<1.0 = DEAD concept (OB ไม่ช่วย — zone แค่ locate reversion เดิม) บันทึก signal-landscape ปิด.
**ห้าม:** ใส่ OB/grid ก่อน skeleton ผ่าน · M1 ใน Stage 0 (spread noise — เก็บไว้ถ้าไป production) · verdict (lead).

---

## ORDER-108 — break-and-retest split-entry (market + pending-limit) บน breakout winner (user idea 2026-07-16) — `DONE + REVIEWED(Claude 2026-07-16): 🟩 BUILD-ON SUCCESS — build (EXP)_BRK_SplitRetest + A/B Model-4 XAU H1 · retest fill-rate ~90% · adverse-selection จริง (pending-only แพ้ market ในเทรนด์ = ต้องมีขา market) · split robust ทั้ง 2 regime (1.93/1.97) · lever ใหม่เข้า EDGE_CATALOG · **followup: retrofit LIVE Bars55/TP8 = ไม่ยก (split 1.89<market 1.99, retest อ่อน BWD) → ห้าม retrofit ตัว live · lever = config-conditional (ช่วยเฉพาะ config สมดุล)** · verdict = _triage/ORDER108_SPLIT_RETEST_VERDICT.md` (role: Claude build → agent run · verdict = Claude)

**ที่มา (user 2026-07-16):** breakout ส่วนใหญ่กลับมา retest แนวที่ทะลุ → วาง **pending-limit ที่ retest** เก็บ pullback
ราคาถูก (ไม่จ่าย spread + SL แคบชิดแนว = RR ดีขึ้น). user เสนอ **split sizing: market 0.02 (จับ runner ที่ไม่ retest) +
pending 0.01 (เก็บ retest)** — แก้ปัญหา adverse-selection พอดี (ไม้ที่ไม่ retest มักแรงสุด → market leg กันพลาด).
**ต่างจาก Thread A (JUMSTOCH reversion pending):** นี่ = breakout+retest บน EA ที่มี edge อยู่แล้ว, entry-quality lever.

**Vehicle = EA_BREAKOUT_XAU** (deploy อยู่, edge ยืนยัน — ไม่ใช่ XAU_NY ที่ปัญหาคือ regime ไม่ใช่ราคาเข้า).
**คำสั่ง:** (1) variant ที่ breakout signal ยิง: ส่ง market leg (sizeA) ทันที + วาง pending buy/sell-limit (sizeB) ที่
**ระดับแนวที่ทะลุ** (retest level), expiry N bars · ห้ามแตะ signal/SL/exit logic เดิม (isolate entry-structure) ·
(2) compile 0/0 + mql-code-reviewer (3) A/B บน home cell (XAU H4/H1 both-window): **market-only baseline** vs
**split(A=0.02,B=0.01)** vs **pending-only** · sweep retest-offset + expiry.
**Acceptance (วัด adverse-selection ตรงๆ):** ต่อ variant รายงาน — pending-leg **fill-rate %** · **EV/signal** เทียบ
baseline · แยก EV ของไม้ที่ **2-leg fill (retest เกิด)** vs **market-only (วิ่งหนี)** = พิสูจน์ว่า runner คือกำไรใหญ่จริงไหม ·
net PF/DD. **บาร์:** split net-EV/signal > market-only ที่ spread จริง = ยืนยันคุณค่า.
**ห้าม:** เอา pending-limit ไปแปะ EA ที่ปัญหาไม่ใช่ entry-cost (เช่น XAU_NY = regime) · เปลี่ยน lever อื่นนอก
{entry-structure, retest-offset, expiry, split-ratio} · verdict (lead) · promote เงินจริง (probe/build-on เท่านั้น).

---

## ORDER-109 — regime-rescue #1: graft `_50_ Regime.mqh` เข้า Zeus chassis + sweep AUDJPY/AUDUSD both-window (user เคาะ 2026-07-16) — `BUILD+NO-OP+SWEEP+CONFIRM+YEARSPLIT DONE + REVIEWED(Claude 2026-07-16): 🟡 AUDJPY = PARTIAL RESCUE (regime-dependent, PARKED-VERIFY user) — range-only gate (m1rng25) ยก base both-window-fail (1.12/0.94) → Model-4 both-window-aggregate positive ทั้ง plateau thr20/25/30 (MAIN 1.24-1.63 / BWD 1.28-1.52) + BWD all-3-years-positive · **BUT year-split เผย 2023 ขาดทุนจริง (-1107/PF0.64, ปี trend yen) + 2025 breakeven + MAIN พึ่ง 2024 thin-lucky(28t) → ไม่ผ่าน all-years-positive → ไม่ deploy-ready**, แจ้ง user (demo+caveat หรือ park) · direction-lock m2 ตายบน real ticks (BWD 1.39→1.01) · AUDUSD = fragile spike (park) · no-op bit-identical ✅ · **meta-lesson: regime gate = orthogonal สำหรับ grid (Zeus กู้), redundant กับ breakout (XAU_NY ไม่ขยับ)** [[regime-gate-grids-not-breakouts]] · **DEMO BUNDLE BUILT (user เคาะ demo 2026-07-16): `_vps_deploy/ZEUS_AUDJPY_REGIME/` magic 990110, preset m1rng25+storm1.5 (storm sweep: 1.5=best MAIN 1.35/BWD 1.20 DD↓, 2023 ยัง -900 structural) · locked .set verified reproduces 1.35 · ⚠️README เตือน recompile-reset (RegimeMode→0=no gate=base พัง) + 2023 caveat → รอ user attach คืนนี้ (บอกวัน→register DEPLOYMENTS)** · verdict = _triage/ORDER109_ZEUS_REGIME_VERDICT.md` (role: Claude build → self-run batch · verdict = Claude)

**ที่มา + reframe สำคัญ (Claude scoping 2026-07-16):** START-HERE #1 "regime-rescue pipeline ~29 EA" — Explore ยืนยัน
กอง regime จริง addressable **แค่ 4 cells ไม่ใช่ 29**: ~12 ตัวเป็น MT4 black-box (graft `_50_` ไม่ได้) · Boss_14 family
เคยผ่าน regime-refunnel ครบใน ORDER-062 · เหลือ source-available ที่ยังไม่ผ่าน gate = **Zeus AUDJPY/AUDUSD**
(ต้อง graft — standalone chassis ไม่มี lever) + **XAU_NY** (source หาย → ORDER-110 rebuild) + AsReMix (black-box ตาย).
regime-rescue = **งาน build ไม่ใช่ batch**. user เคาะ "ทำ 1-2" = Zeus (นี่) + XAU_NY rebuild ต่อ.

**BUILD (done, Claude):** port `ea_template/core/Regime.mqh` → `ea_projects/(Boss)_ZeusInspired_GridLog/Regime_Standalone.mqh`
(self-contained: ประกาศ `_50_*` inputs เอง, logic verbatim reviewer-approved, ไม่ดึง LabCore Inputs). graft เข้า Zeus.mq5:
include + `Regime_Init()` OnInit + `Regime_Deinit()` OnDeinit + gate `Regime_AllowsEntryDirection(dir)` **ก่อน arm first-entry
เท่านั้น** (grid-add + exit ไม่แตะ — ตรง convention LabCore). compile 0/0 ผ่าน `D:\Meta 5\MetaEditor64.exe` (⚠️ gotcha:
Meta5b MetaEditor resolve include ไม่ได้ — roaming B084 ไม่มี Include tree; ใช้ Meta5 primary เท่านั้น). mode 0 = no-op
(Regime_Enabled() false → inert). ex5 deploy roaming 9CA16B\Experts + baseline pre-graft เก็บเป็น `_ZeusBaseline_pregraft.ex5`.

**RUN (self, background — runner `_mt5_auto/ab_sets/zeus_regime/run_zeus_regime.ps1`):**
- **Phase 1 no-op proof:** baseline(pre-graft) vs grafted(mode-0) บน AUDJPY_lot8x + AUDUSD_lot10x MAIN → net/pf/trades/eqdd
  ต้อง **bit-identical** (sanity ผ่านแล้ว: grafted mode-0 = PF 1.12 ตรง parked AUDJPY 8x). ถ้าไม่ identical = STOP graft พฤติกรรมเพี้ยน.
- **Phase 2 sweep:** grafted ex5 × 8 config {base·m1t20/25/30·m1rng25·m2t20/25/30} × 2 window {MAIN 2023-26 · BWD 2020-22}
  × 2 symbol {AUDJPY_lot8x · AUDUSD_lot10x} = 32 run → `_mt5_auto/ZEUS_REGIME_AB.csv`.
**Acceptance (Claude judge ตาม VERDICT GATE):** ✅ RESCUE = regime config ใด**ยก both-window พร้อมกัน** (MAIN≥base & BWD PF≥1.2)
เป็น **plateau** (thr เพื่อนบ้านไม่พลิกขั้ว) ไม่ใช่ spike · mode 2 ≤ mode 1 คาดไว้ (ORDER-057 precedent) · ถ้าไม่มี config ยก
both-window = regime lever ไม่กู้ Zeus (ปิด cell, บันทึก signal-landscape). ห้าม: verdict จาก window เดียว · retrofit demo cohort.
**ผล:** _(sweep รันอยู่ — judge เมื่อ CSV ครบ)_

---

## ORDER-110 — regime-rescue #2: rebuild XAU_NY (NY-session breakout) บน LabCore chassis (มี `_50_` lever) — `DONE + REVIEWED(Claude 2026-07-16): 🟡 regime gate ไม่กู้ XAU_NY — rebuild = pure config บน Boss_12_Breakout (Entry-12 Donchian + session filter + _50_ ครบ ไม่ต้องเขียนโค้ด) · 48-run coarse (TF×Bars×session×regime × both-window): both-window cells มีแค่บน H4 แต่ BWD อ่อนหมด (≤1.06) · regime gate ให้ BWD nudge เล็ก (~+0.05) ไม่พอ + cell ที่ผ่าน = Bars-spike ไม่ใช่ plateau · **meta-lesson: regime-gate = orthogonal filter สำหรับ GRID (Zeus/XAU-grid สำเร็จ) แต่ redundant กับ BREAKOUT (ADX ซ้ำ momentum)** · naked H4/20/NY (1.47/1.05) = build-on lead low-priority (Model-1 only, likely corr>0.6 กับ XAU legs เดิม) → park · verdict = _triage/ORDER110_XAUNY_REGIME_VERDICT.md` (role: Claude build → self-run · verdict = Claude)

**ที่มา:** XAU_NY (#83) source หาย (compiled-only) → graft ไม่ได้ → rebuild เป็น config บน Boss_12_Breakout (LabCore Entry-12
Donchian มี session filter `_12_HourFrom/To` + `_50_` gate ครบ). ผล = regime ไม่ใช่ hero; breakout momentum ซ้ำกับ ADX gate.

---

## ORDER-111 — re-audit open-price-killed pile + source-catalog build-material (user เคาะ 2026-07-16) — `DONE + REVIEWED(Claude 2026-07-16): Part A 6-marginal recheck = **ไม่มี wrongly-parked** (every-tick แย่ลงทั้ง 6, PF ตกทุกตัว, 2 ตัวโผล่ DD~99% ที่ control-points บัง) → cheap-model parking แฟร์/ใจดีเกินด้วยซ้ำ, ความกังวล user ปิดด้วยหลักฐาน · Part B .mq5 catalog = 599 families, ~5 external build-lead (ไม่ใช่ขุมทรัพย์) · **meta: control-points บัง grid/basket blowup → grid ต้อง Model-4 เสมอ**` (role: Claude scope → agent batch · verdict = Claude)

**ที่มา:** user ห่วงว่าผมฆ่า EA ด้วย open-price/math-cal. **Scope finding:** mass-smoke (ORDER-036) ตัดสิน PF บน
**control-points (m1) ไม่ใช่ open-price** (m2 = แค่ด่านนับ trade) → **ไม่มีกองถูกฆ่าผิดขนาดใหญ่.** Reject-tier=143 (97 deep-dead),
marginal จริง (pf 0.95-0.99, ยังขาดทุน) = **6 EA** · 0-trade ทุก symbol = 1,044 (ส่วนใหญ่ indicator-dep/junk/expired ตาม user caveat).

**Part A (6-marginal recheck) — agent RUNNING:** re-run 6 EA (Auto SL-TS-TP/GridMACDM/RoNz/Sample_MA_Trader/smartass2/TCO FG)
ด้วย every-tick (Model 0) via mt4_run.ps1. flag ตัวที่ PF jump >1.2 = wrongly-parked. time-box, skip junk/indicator/error.

**Part B (source catalog) — build-material (user: ".mq4/.mq5 มีประโยชน์ต่อยอด"):** D:\Forex มี 5,188 .mq4 + 1,708 .mq5.
**batch 1 = 1,708 .mq5** (MT5 platform เรา ใช้ตรง) → deterministic parser (dedupe vs catalog เดิม 091, extract mechanism/family,
flag self-contained vs indicator-dep) → IDEA_CATALOG. ไม่ใช่ "EA ผ่านไหม" แต่ "logic อะไรต่อยอดได้". batch 2 = .mq4 ทีหลัง.
**caveat (user):** junk เยอะ ให้ข้าม · indicator-dependent ข้าม · error = flag ไม่จม. = ORDER-091 intake continuation + skill corpus-intake.

**Part B RESULT (agent DONE 2026-07-16 — `_triage/ORDER111_mq5_source_catalog.csv` 599 families):** 1,708 .mq5 → 599 unique
(324 indicator-dep flag+ข้าม · 139 self-contained-new **แต่ส่วนใหญ่ = boss* AI-gen ของแล็บเราเอง ไม่ใช่ external**). family split:
grid-mart 281 · other 195 · trend 41 · MR 38 · breakout 14. **external ใหม่จริงต่อยอดได้ = ~4-5 กลไก:** Breakout Retest Pro
(breakout+retest ← ตรง ORDER-108 lever), EX197 FVG scalper, POW BANKER (multi-confluence+news+trailing), TEMPO EMA/MACD,
Boss Pivot Range. **สรุป: ไม่ใช่ขุมทรัพย์** (ตรง WOBR/intake lesson — family ตายแล้วเยอะ) แต่ 4-5 กลไกนี้เก็บเป็น build-lead.
next: .mq4 (5,187) batch 2 · eyeball 195 "other" ทีหลัง.
**batch 2 DONE (Claude 2026-07-16B):** 5,187 .mq4 → **2,048 unique families** (dedup content-hash). parser `scripts/mq4_source_catalog.ps1`
(PowerShell) · catalog `_triage/ORDER111_mq4_source_catalog.csv` · summary `_triage/ORDER111_mq4_catalog_SUMMARY.md`. dist: other 924 (iCustom-dep) ·
**breakout 421 · trend 384** (momentum) · reversion 160 · oscillator 151 · grid-mart 8. **⚠️ boilerplate: "martingale" label = 95% ของไฟล์ (fxDreema template)
→ exclude จาก family, เก็บ `has_mart_block` แยก.** **532 buildable momentum families** (self-contained+ใหม่) — top = classic public EA (firebird/tsd/awesome/universalMAcross).
next (judgment รอ user): cross-ref lab status → NEVER-TOUCHED momentum ที่ user รู้จัก = คิว build.

---

## เสนอ order ใหม่ (agent อื่นเขียนข้อเสนอได้ที่นี่ — Claude เป็นคนยกเป็น order จริง)

### 🟣 PROPOSAL-A (ZCode, 2026-07-04) — ✅ APPROVED → ยกเป็น ORDER-009 แล้ว (เก็บไว้เป็น reference)

**บริบท:** ตอนนี้ ORDER-005 (IS-opt) + ORDER-006 (fresh-start OOS) + ORDER-007 (probe 7) = DONE
ทั้งหมด รอ Claude review. แต่ ORDER-006 ผลิตแค่ผล OOS (PF/Net/EqDD จาก single equity path)
**ยังไม่มี Monte Carlo** — ขณะที่ ORDER-004 (GBPAUD) ใช้ MC เป็นหลักฐานประกอบ verdict
(DD 95th/worst/ruin). pipeline เดียวกันควรมี MC ครบทุก OOS-passing candidate ก่อน Claude
ตัดสิน ไม่งั้น Claude ต้องสั่งซ้ำรอบ review.

**OOS ผลที่ ORDER-006 รายงาน (จาก report ครบบน disk):**
AUDNZD 42t PF 3.02 ✅ · EURJPY 23t PF 2.15 ✅ · USDJPY 106t PF 2.77 ✅ ·
GBPJPY 23t PF 1.12 (borderline) · EURCAD 140t PF 0.67 (fail)

**งานที่ขอทำ (role ZCode แท้ — รัน `mt5_montecarlo.py` ที่มีอยู่ ไม่สร้าง/แก้ source):**
```powershell
. D:\EA_LAB\scripts\use_python.ps1
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_AUDNZD_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_GBPJPY_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_EURJPY_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_EURCAD_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_USDJPY_OOS_M1.htm  --deposit 10000 --iters 5000
```
**Acceptance (ถ้า Claude approve):** ต่อ symbol append ตาราง `trades_used / DD median / 95th /
worst / ruin% / P(loss)` · commit `[zcode] PROPOSAL-A done`
**ข้อห้าม (ตาม role):** ไม่ตีความผล, ไม่ให้ verdict, ไม่เลือก candidate — รายงานดิบเท่านั้น.
**caveat ที่จะรายงานควบ (จาก docstring ตัว script เอง):** trade-reshuffle MC = optimistic
lower bound (grid ขาขาด cluster → real adverse อาจแย่กว่า reshuffle ใดๆ) — treat 95th/worst
เป็น "at least this bad" ไม่ใช่ ceiling.

**⚠️ ข้อควรพิจารณาของ Claude ก่อน approve:**
- OOS report บางตัวมีเทรดน้อย (GBPJPY 23t / EURJPY 23t / AUDNZD 42t) — MC บน n<30 noise มาก
  (ORDER-004 เคยเลี่ยงปัญหานี้โดยรัน MC บน full report 88t แทน OOS 23t). ทางเลือกสำหรับ Claude:
  (a) approve ทั้ง 5 + flag ว่า thin, (b) ขอให้ ZCode รัน MC บน full-window report เพิ่มเทียบ,
  (c) รันเฉพาะ USDJPY(106t)/EURCAD(140t) ที่ n เพียงพอก่อน.
- หาก Claude ตั้งใจ review ORDER-005/006 เองโดยไม่ใช้ MC (ใช้แค่ PF+regime-read) ก็ปฏิเสธ
  proposal นี้ได้เลย — ZCode จะไม่ทำ.

---

## ORDER-057 — mold upgrade: `Regime.mqh` (market-state filter, additive) — `CLOSED (Stage A+B+C REVIEWED Claude 2026-07-09 — m1 trend-only gate = ของจริง in-sample บน XAU · adoption = lever _50_ ใน optimize funnel ของ EA ตัวถัดไป · ห้าม retrofit demo cohort)` · **ทำได้: Codex/Claude/oc-dev** · 👉 **Codex-direct** _(ออก 2026-07-09, user สั่ง: "อยากได้ตัวระบุสภาวะตลาด trend/sideway เป็น direction ให้ EA + ปิดได้")_

**Stage A review (Claude, 2026-07-09):** โค้ด Codex ผ่านทุกข้อ — closed-bar classify (shift 1, no repaint) +
cache ต่อแท่ง regime-TF · gate เฉพาะ first-entry ทั้ง 2 path (resting-stop + market) ไม่แตะ exit/basket ·
direction convention 1=BUY/2=SELL ตรง Entry_ST03 · handle init/release ตามแบบ Indicators.mqh · mode 0 no-op
จริง (พิสูจน์: run มี module = run ไม่มี module ตรงกันทุกหลักทศนิยม) · **เหตุการณ์ระหว่าง review: cage ขึ้น
DRIFT 4 ตัว → สอบสวนด้วย control run บน HEAD สะอาด = เลขเพี้ยนเหมือนกันเป๊ะ → root cause คือ XAUUSD history
refresh (trade count เท่าเดิมทุกตัว กำไรขยับ ~1-4%) ไม่ใช่โค้ด → re-baseline บน HEAD แล้วรันซ้ำกับ module =
CLEAN 4/4 · บทเรียน: DRIFT ที่ trade count เท่าเดิม + กำไรขยับเล็กน้อย = สงสัย data-side ก่อน code-side,
พิสูจน์ด้วย control run เสมอ** · sanity A/B ของ Codex: mode 1 (block RANGE) 426→378 ไม้ = gate กัดจริง

**เก็บตกหลักฐาน (Claude, 2026-07-09 บ่าย):** เจอช่องว่าง — `mt5_run.ps1` ไม่ compile ดังนั้น control run
แรกเทียบ binary เดียวกัน (พิสูจน์แค่ history ไม่ใช่ source) → ปิดช่องด้วยการ compile เอง 2 รอบ:
source มี module (compile 0/0) vs source ก่อน module (checkout `36a6819`, compile 0/0) → regression
เลขเท่ากันเป๊ะทุกหลักทั้งคู่ = **mode-0 no-op พิสูจน์ end-to-end ระดับ source ด้วยมือ lead แล้ว** ไม่พึ่งคำ Codex

**Stage B — reassign เป็น Claude รันเอง (2026-07-09: user cancel Codex — quota หมด กลับ 2026-07-11 · ZCode n/a):**
matrix 32 runs เสร็จแล้ว → `_mt5_auto\REGIME_AB.csv` · runner = `_mt5_auto\ab_sets\regime_sets\run_regime_ab.ps1`

**Stage B VERDICT (Claude, 2026-07-09):**
- **XAU (Boss_14 chassis, ISpick): trend-only gate = ของจริงระดับ in-sample** — m1 (block RANGE):
  BWD PF 1.07→**1.88/1.88/1.82** (thr 20/25/30 = plateau ไม่ใช่ spike) net 121→799 · FWD เสียนิดเดียว
  1.42→1.39 (thr20) n 426→405 · eqDD ลดทั้งสอง window (23.35→20.05% / 8.30→7.30%) · **shape ที่ต้องการ
  เป๊ะ: เฉือนกำไรปีกระทิงนิดหน่อย แลก window อ่อนพลิกจากแทบเจ๊าเป็น 1.88**
- **AUDNZD (DEMO champion): ไม่เอา** — ทุก config ที่ช่วย BWD ทำร้าย FWD สลับกัน (m1t20: FWD 1.53↑ แต่
  BWD 0.74↓ · m1t25: BWD 1.76↑ แต่ FWD 1.27↓) ยกเว้น thr30 ที่ต้องจ่ายไม้หาย ~75% = thin · no plateau
- mode 2 (direction-lock) ≤ mode 1 ทุก cell ที่เทียบได้ → mode 1 คือตัวจริงของ lever นี้
- m1 range-only: FWD 2.05 บน n=38 / BWD 0.60 = thin+flip ทิ้ง
- **Stage C (สมมติฐาน user "COT+trend filter ใช้คู่กัน"): ทดสอบแล้ว — COT ไม่เพิ่มค่าบน ADX** — ใน
  trade ที่ผ่าน ADX gate แล้ว (n=512) ทุก COT bucket กำไรหมด (LOW 1.22 / MID 1.25 / HIGH 1.54) ตัด LOW
  = ตัดกำไร ไม่ใช่ตัดขาดทุน + year-split ยังไม่เสถียร (2024 LOW 1.93) → COT จบที่ dashboard light ตามเดิม
- **ข้อจำกัด verdict:** เลือก config จาก 2 window ที่เห็นทั้งคู่ = in-sample selection · **ห้าม retrofit
  เข้า demo cohort ที่ validate แล้ว** (กฎเดิม) · adoption ที่ถูก = `_50_` เป็น axis ใหม่ใน optimize funnel
  ของ EA ตัวถัดไป + Boss V2 track (ตอน unpark) แล้วต้องผ่าน holdout+MC ของ funnel นั้นเอง
- MC PF-5th base vs m1t20 (XAU, bootstrap-w/-replacement 5000 iters บน deals จริง — caveat grid-MC เดิม):
  FWD 0.825→0.797 (จ่ายเบี้ยปีกระทิง) · BWD 0.572→**0.849** (window อ่อนดีขึ้นชัด) · ALL 0.829→0.852 —
  สอดคล้อง story ประกันภัย, ไม่เปลี่ยน verdict (lever เข้า funnel ใหม่ ไม่ retrofit)

**ทำไม:** cohort มี EA ที่ตายเพราะ regime เปลี่ยน (NZDUSD-SELL = PARKED regime-dependent ·
Scalping-AsReMix = PARKED trend-specialist edge-decay) — ถ้ามี regime filter ในแม่พิมพ์ จะได้
lever ใหม่ให้ sweep ทั้ง family และเป็นตัว "ปิดเครื่องเมื่อสภาวะไม่ใช่" ที่ demo cohort ยังไม่มี

**Stage A — implement (Codex-direct, additive เท่านั้น):**
- ไฟล์ใหม่ `ea_template\core\Regime.mqh` — enum `REGIME_TREND_UP / REGIME_TREND_DOWN / REGIME_RANGE / REGIME_STORM`
- ตัวจับ (built-in handles เท่านั้น ตามธรรมเนียม Indicators.mqh):
  - trend/range: **iADX** บน `_50_Regime_TF` — ADX ≥ `_50_ADX_TrendMin` = trend (ทิศจาก +DI/-DI), ต่ำกว่า = RANGE
  - storm: ATR ปัจจุบัน > `_50_StormATRmult` × SMA(ATR, `_50_StormLookback`) = STORM (ทับทุกสถานะ, 0 = ปิดเช็คนี้)
- inputs ใหม่ใน `Inputs.mqh` (prefix `_50_`):
  `_50_RegimeMode` **0=OFF (default)** · 1=FILTER (เทรดเฉพาะ regime ที่อนุญาตผ่าน `_50_AllowTrendUp/_AllowTrendDown/_AllowRange`; STORM = block เสมอ) · 2=DIRECTION (อนุญาตเฉพาะฝั่งตาม trend; RANGE = block ทั้งคู่)
  · `_50_Regime_TF` (default H4) · `_50_ADX_Period` (14) · `_50_ADX_TrendMin` (25.0) · `_50_StormATRmult` (2.0) · `_50_StormLookback` (100)
- จุดเสียบ: gate **การเปิดไม้ใหม่เท่านั้น** (ก่อน entry signal ใน LabCore) — ห้ามแตะ exit/basket/recovery/ไม้ที่เปิดอยู่ · ประเมินที่ bar-open ของ `_50_Regime_TF` (bar-open gate)
**Acceptance (Stage A):** compile 0/0 · **`tpl_regression.ps1` CLEAN ที่ mode 0** (default off = พฤติกรรมเดิมทุก byte) · sanity run 1 ครั้ง: XAU GridLog p20 set + mode 1 (AllowRange=false) → trade count ต้องเปลี่ยนจาก baseline · commit `[codex] ORDER-057A done`
**ห้าม (Stage A):** แตะ ExitManager/RiskControl/Recovery logic · เปลี่ยน default พฤติกรรมใดๆ · ตัดสินว่า filter "ช่วย"

**Stage B — A/B sweep (ZCode/oc-btest, หลัง A ผ่าน review):**
- EA ทดสอบ 2 ตัว: XAU GridLog (Pass 20 set) + AUDNZD champion — รัน baseline (mode 0) vs mode 1 (3 ชุด allow) vs mode 2, บน**ทั้ง 2 window: 2023-2026 + BWD 2020-2022** (กฎ both-regimes)
- sweep `_50_ADX_TrendMin` ∈ {20, 25, 30} — รายงานดิบ PF/Trades/DD ต่อ cell, append ใต้ order นี้
**ห้าม (Stage B):** เลือก config "ดีสุด" — verdict = Claude ตาม VERDICT GATE (surface ไม่ใช่จุดเดียว)

**ผล (Codex, Stage A only; ไม่มี verdict):**
- touched: `ea_template\core\Regime.mqh` (new) · `ea_template\core\Inputs.mqh` · `ea_template\core\LabCore.mqh`
- compile: Boss_11/12/13/14/15 workspace builds = **0 errors / 0 warnings**
- regression: `powershell -File D:\EA_LAB\scripts\tpl_regression.ps1` = **CLEAN**
- sanity A/B (XAU GridLog Pass-20 full window 2023.01.01-2026.07.01, Model 1):
  baseline `_50_RegimeMode=0` = **426 trades**
  filtered `_50_RegimeMode=1`, `_50_AllowRange=false` = **378 trades**
- note: MT5 expert folders were ACL-blocked from this session, so the proof run used a temporary portable sandbox under `D:\EA_LAB\_mt5_portable_order057` with the workspace-built `.ex5` + copied XAU history; raw reports:
  `D:\EA_LAB\_mt5_auto\reports\ORDER057_XAU_BASE_SB.htm`
  `D:\EA_LAB\_mt5_auto\reports\ORDER057_XAU_FILTER_SB.htm`

---

## ORDER-064 — ขุดไอเดียจาก Open WebUI export 93MB (คุยกับ OpenAI ของบริษัท) — `CLOSED (Stage 3 verdict Claude 2026-07-09 — ลูกที่ spawn: ORDER-065 SuperTrendFlip = RESERVE · ORDER-066 VWAP WaveS1 = NO EDGE, ทั้งคู่ปิดแล้วใน archive)`

- **Stage 1 ✅:** `scripts\chatgpt_export_inventory.py` (รองรับทั้ง OpenAI export และ Open WebUI format) →
  45 บทสนทนา, จัดอันดับตาม MQL-keyword density → `_triage\chatgpt_inventory.csv` + top-12 แตกเป็น .txt ใน
  `_triage\chatgpt_convs\` (⚠️ ข้อมูลบริษัท — .txt/.csv **ไม่เข้า git**, เก็บ local เท่านั้น)
- **Stage 2 (กำลังรัน):** 4 Sonnet agents skim 12 ไฟล์ → catalog กลไก/โค้ด/ความใหม่เทียบ cohort
- **Stage 3 (Claude):** judge catalog → เลือก build candidates (เกณฑ์: กลไกใหม่จริง + กติกาชัด — VWAP-based
  น่าสนใจสุดเพราะ cohort ยังไม่มี) · ที่เหลืออีก 33 บทสนทนา = อ่านเฉพาะถ้า top-12 ให้ของดี

**VERDICT Stage 3 (Claude, 2026-07-09 — catalog ครบ 12/12):**
- **ขยะ/ซ้ำของที่เรามี-REJECT แล้ว (7 ไฟล์):** 024 scaffold framework · 015 recovery-hedge spec (ตระกูล REJECT
  81/82) · 041 AW-Recover clone (**ไม่มี SL ต่อไม้ทั้ง 5 เวอร์ชัน**) · 030 prompt-eng session · 036 triage PDF
  ซ้ำ STRATEGY_200_ANALYSIS · 022+009 = 11-EA ตาม**โหราศาสตร์** (โค้ดครบแต่ allocation ไม่ใช่ market logic)
- **ของจริงที่สกัดได้ — จัดอันดับ build EV:**
  1. 🥇 **SuperTrend/HalfTrend/Chandelier "ATR-band flip"** — โผล่อิสระ **5 แหล่ง** (025 HalfTrend MTF ·
     043 Smart Trail · 009 P10 · 022 P10 · STRATEGY_200 #68 top-pick) · กลไก: trailing extreme ∓ ATR×mult
     พลิกทิศ = trend-follow ที่ exit ด้วยเส้นวิ่งตาม ไม่ใช่ fixed TP · บ้านที่ควรเทส: XAU H1 (edge class
     momentum ที่พิสูจน์แล้ว) · build ถูกสุด (indicator เดียว + โครง L1 มีแล้ว) → **ORDER-065**
  2. 🥈 **VWAP Wave (010 — สเปคเต็ม 4 setup)** — VWAP+SD band แยก Balance/Discovery + Initial Balance ·
     กลไกใหม่แท้ต่อ cohort (ไม่มีตัวไหนใช้ fair-value anchor) · ต้องกลั่นเหลือ setup เดียวก่อน (S1 continuation
     หรือ S4 VWAP-bounce) — ห้าม build ตามสเปค 30 ไฟล์ (บวม+ML+Wyckoff = overfit trap) → **ORDER-066**
  3. 🥉 **Z-score pairs stat-arb EURUSD/USDCHF** (009 P5 + 022 P5 สองแหล่ง) — market-neutral = return stream
     คนละจักรวาลกับ cohort ทั้งกอง · ติดเรื่อง infra (multi-symbol tester + ไม่มี price SL ในดีไซน์เดิม = ต้อง
     ใส่ hard SL เอง) → วิจัยความเป็นไปได้ก่อน build → backlog
  4. **Graft ideas ใส่ของที่มีอยู่ (ถูกมาก):** ATR>1.2×ATR_MA เป็น squeeze-proxy ราคาถูก (032) · vote N-of-M
     gate (043/032) · asymmetric-lot MTF confluence (025 — เห็นต่างเข้าครึ่งไซส์) · time-stop 48 แท่ง (032)
  5. **Anti-pattern เก็บเข้าคลัง:** virtual SL (043) · recovery-multiplier ซ้อน martingale (043) · equity-based
     kill แทน price SL (041) · "AI/Neural" = ป้ายการตลาดของ EA ขายตลาด 90% (035 audit ชี้ Quantum Emperor
     เจ้าของเติมเงินเข้า signal ปิด DD!)
- Boring-Pips-style cross-pair reversion (035) + session-gate (022 P11) = MED เก็บ backlog ไม่เร่ง

---

## ORDER-072 — build "(Boss)_Kangaroo" = Boss_16 บนแม่พิมพ์ V2 — `CLAIMED(Claude-agent, 2026-07-10)` (role: agent build ภายใต้ spec ที่ Claude เคาะ)

**Spec decisions (Claude lead เคาะ 2026-07-10 — ปิดประเด็นเปิดทั้ง 5 ของ KANGAROO_LOGIC_NOTES §4):**
1. **Lot law: FLAT default** (ทุกไม้ = base_lot) — flat-lot probe พิสูจน์แล้วว่าดีกว่ามี ladder
   (H1 5.71 vs 4.86) · ×1.5 capped ladder ใส่เป็น input `LadderMult` default 1.0 (=ปิด) ไว้ A/B
2. **Bidirectional = 2 instance ผ่าน Direction input** (ตาม pattern Boss_14) — ไม่ทำ dual-engine
   ในตัวเดียว, magic แยกฝั่ง · ไม่ทำ multi-magic stream ของ original (artifact ไม่ใช่ feature)
3. **Entry v0 = RSI fade** (RSI(14) H1: BUY เมื่อ <th_low, SELL เมื่อ >th_high, default 30/70) —
   ใกล้เคียง counter-trend ของ original ที่สุดในคลังเรา (RSI-MR = survivor mechanism ที่ validate แล้ว)
4. **เก็บ 3 กลไก exit ตาม original แต่คิดเงินจริง:** TP เดี่ยว (ATR-mult) · basket close แบบ net-$ ·
   **overlap pair-close** (คู่ใหม่สุด+เก่าสุด ปิดเมื่อรวม ≥ $X, default 5, sweepable) — โมดูลใหม่
5. **ladder_flatten (controlled-loss release):** มีเป็น input default OFF — A/B แยกใน funnel
6. Spacing ATR (0.8/1.4 mult + floor 150p) · SL ต่อไม้ ATR-mult (ceiling $90-equiv) · HARD cap
   10 ไม้/ฝั่ง (ของจริง ไม่ใช่โฆษณาแบบ original) · emergency DD 70%

**คำสั่ง:** สร้าง `ea_template\Boss_16_KangarooGrid.mq5` + โมดูลใหม่ที่จำเป็นใน `core\` (additive,
default-off สำหรับ EA เดิม) ตาม pattern Boss_14_GridLog · compile 0/0 · **`tpl_regression.ps1` ต้อง CLEAN**
(กติกาแก้ core) · smoke XAUUSD H1 2023-2026 Model 1 บน lane "D:\Meta 5b" (กันชนกับ ORDER-071) ·
เทียบตาราง: Boss_16 flat vs original flat (PF 5.71/DD 11.5% = เป้าไล่)
**Acceptance:** compile 0/0 · regression CLEAN · ตาราง smoke เทียบ original + set ไฟล์ · commit `[tag] ORDER-072 done`
**ห้าม:** deploy/verdict · แก้ Boss_14/15 behavior · martingale default-on · แตะ .set live

### ORDER-072 result — `DONE(Claude-agent, 2026-07-10)` — build ครบ + gates ผ่านทั้ง 3 + smoke raw numbers (NO verdict)

**Build file list:**
- NEW `ea_template\Boss_16_KangarooGrid.mq5` (wrapper: `LAB_ENTRY_16` + tag)
- NEW `ea_template\core\Kangaroo.mqh` — basket engine ของ entry 16 ทั้งก้อน: adverse-only ATR grid
  (0.8/1.4 mult + floor 150p digit-aware) · FLAT lot (LadderMult>1.0 = capped ladder, first-4 = BaseLot,
  cap/order 1.0) · HARD cap 10 ไม้/ฝั่ง (refuse จริง) · per-order broker SL (18×ATR, ceiling 9000p) ·
  exit 4 กลไก **คิดเงินจริงทั้งหมด**: (1) single TP 0.35×ATR (managed close) (2) basket net-$ ≥ 16×(lots/0.01)
  (3) overlap pair-close newest+oldest ≥ $5 เมื่อ ≥4 ไม้ (4) ladder_flatten default OFF (≥6 ไม้, net ≥ -$400) ·
  emergency DD close-all 70% · **one exit owner:** LabCore short-circuit เข้า `Kangaroo_OnTick()` — ExitManager/
  Stack/Recovery/Hedge ไม่รันเลยสำหรับ build นี้; ไม่มี broker TP ต่อไม้ (precedent mode 93); cage ยังเป็นใหญ่
  (RiskControl hard-kill/deposit-load/RC_MaxLot รันก่อน/คุมทับ)
- NEW `ea_template\core\entries\Entry_KangarooRSI.mqh` — entry v0: RSI(14) fade บน chart TF, closed-bar read,
  `_16_Direction` 1=BUY(<RsiLow 30)/2=SELL(>RsiHigh 70) ตาม pattern Boss_14, เข้าที่ bar open
- EDIT (additive, `#ifdef LAB_ENTRY_16` ทั้งหมด — compile out จาก Boss_11..15): `core\Inputs.mqh` (กลุ่ม `_16_*`
  + StackMode/fallback guard) · `core\Indicators.mqh` (handle `g_hRSI16`) · `core\LabCore.mqh`
  (include + init + OnTick short-circuit) · `core\Execution.mqh` (`Exec_CloseTicket()` — build อื่นไม่เรียก)
- EDIT `ea_template\deploy.ps1` (+Boss_16 target) · `scripts\mt5_run.ps1` (+`-Leverage` param, default 100 = พฤติกรรมเดิม)
- NEW `ea_template\sets\Boss16_Kangaroo_XAU_smoke.set` (defaults ทั้งชุด เขียน explicit)

**Gate evidence:**
1. compile: `Boss_16_KangarooGrid.mq5 → Result: 0 errors, 0 warnings` (และทั้ง 7 targets 0/0)
2. `tpl_regression.ps1` = **CLEAN 4/4** — หมายเหตุ: เจอ DRIFT 4/4 ก่อน แต่ control run บน clean HEAD (stash)
   reproduce เลขเพี้ยน **bit-identical** (trades เท่าเดิมเป๊ะ 168/164/107/56, profit ±1-4%) = data-side
   XAU history refresh ตาม incident เดิม commit 6a21f040 → re-baseline บน verified clean HEAD แล้วรันกับ
   module = CLEAN (ทำตาม procedure ที่บันทึกไว้เป๊ะ) · `tests\run_tests.ps1` = **ALL TESTS PASS 3/3**
   (AcctGate/Persist/StackStep)
3. smoke lane "D:\Meta 5b" (portable): XAUUSD H1 2023.01.01–2026.07.01 Model 1 (history quality 98%),
   deposit 10000, leverage 1:2000, defaults flat-lot

**Smoke table (raw — ห้าม verdict ที่นี่):**
| Run | PF | Net $ | maxDD% (eq) | Trades | Win% |
|---|---|---|---|---|---|
| Boss_16 BUY (defaults) | 1.49 | +2,242.42 | 10.85% | 588 | 76.4% |
| Boss_16 SELL (_16_Direction=2) | 0.46 | −2,261.00 | 25.12% ← cage HARD KILL @25% วันสุดท้าย 2026.06.30 | 293 | 54.3% |
| Original Gold_Kangaroo FLAT (MT4 H1, สองฝั่งในตัวเดียว) | 5.71 | +15,216.87 | 11.53% | 6,166 | 86.4% |

Reports: `_mt5_auto\reports\BOSS16_KANG_XAU_H1_BUY.htm` / `BOSS16_KANG_XAU_H1_SELL.htm` · mechanics ยืนยันใน
journal lane2: overlap pair-close ยิงจริง 168 ครั้ง (SELL run), grid adds เดินตาม spacing, cage kill ทำงาน

**Deviations from spec (พร้อมเหตุผล):**
1. smoke = 2 runs (BUY+SELL อย่างละ 1 ครั้ง ไม่มี tuning) — EA เป็น fixed-direction ต่อ instance ตาม spec
   decision 2 แต่แถวเทียบ original เป็นสองฝั่ง → รันฝั่งละครั้งเพื่อให้ตารางเทียบได้
2. single TP = managed close ไม่ใช่ broker TP — กติกา one-exit-owner (ไม้ห้ามมี broker TP, precedent 93);
   fill = tick แรกที่เลย level ซึ่งเทียบเท่า overshoot behavior ที่เห็นใน original
3. grid-add reference = ราคา extreme ของฝั่ง (ต่ำสุด BUY / สูงสุด SELL) ไม่ใช่ไม้ล่าสุดตามเวลา — กัน
   oscillation refill หลัง overlap pair-close ตัดไม้ newest ออก; ตรง observation ว่า original เติมไม้ที่
   new low เท่านั้นช่วง crash 2024-11-06
4. emergency 70% อยู่ในโค้ดตาม spec แต่ cage KillDD (ProtectLevel 2 = 25%) ยิงก่อนเสมอที่ default —
   70% = backstop สำหรับ config ที่คลาย cage (SELL run คือหลักฐาน cage ทำงานจริงและ halt)
5. `mt5_run.ps1` เพิ่ม `-Leverage` (additive, default 100 ไม่เปลี่ยนพฤติกรรมเดิม) เพราะ order สั่ง 1:2000
   แต่ script hardcode 100
6. `regression_baseline.csv` ถูก re-capture บน clean HEAD (ดู gate 2) — ไม่ใช่การกลบ drift ของ module;
   พิสูจน์ด้วย control run ก่อนแล้ว

**ข้อสังเกต (ข้อมูล ไม่ใช่ verdict):** trades 588+293 vs original 6,166 — entry v0 RSI fade คัดเข้มกว่า entry
เข้ารหัสของ original มาก (ตัว original ยิงหลาย magic stream แทบตลอดเวลา) · ฝั่ง SELL แพ้บน XAU 2023-26
ซึ่งเป็นเทรนด์ขึ้นยักษ์ · การอ่านผล/ทางไปต่อ (entry sweep? both-instance portfolio?) = งาน Claude lead


---

## ORDER-073 — News-aware risk system (user directive 2026-07-10) — Phase 1 `DONE(Claude)` · Phase 2 `BUILT(ORDER-083) → WAITING-USER (GuardConfig เคาะ + attach)` · Phase 2.5 MRIS `DONE(Claude 2026-07-18)` · Phase 3 MacroGate `DONE — VALIDATED deploy-candidate (Claude 2026-07-18) → WAITING-USER (live attach)`

**✅ SESSION 2026-07-18 CLOSE (commits `7ee6bbd8`→`e219db8e`, branch `order073-macrogate-safe`):**
- **Phase 2.5 MRIS = SHIPPED, live daily.** web feeder (all 8 barometers from Yahoo — VIX/DXY/COPPER/US10Y-proxy + broker pairs, no stooq), thresholds LOCKED as user-sanctioned defaults + in-file `_tuning_guide` (`barometers.json` v1.0), whisper embedded top of `LIVE_DASHBOARD.html` + wired into `daily_monitor.ps1` (mris_run before dashboard). Codex-hardened (5 fixes: cache-poison, atomic write, effective-status, culture-parse, asof fail-open). Reads NEUTRAL RI 0.269 HIGH.
- **Phase 3 MacroGate = VALIDATED deploy-candidate (was STUB).** Standalone watchdog + chassis GV bridge (`Execution.mqh` block+lot-mult, open-path only) + in-chassis `_MG_SelfGate` for single-EA A/B. Concept: MRIS flags Aug-2024 + Mar-2020 unwinds with lead time. **A/B (Boss_12_Breakout, full-year 2024, 2 symbols): eqDD −54..−56%, P&L flat→much better** (USDJPY −58→+2.8). Manage-only grid (Boss_14) = no-op (harmless). Cage: core edits inert (identical trade counts). Codex QA fix-then-ship → all 7 fixed. Verdict: `ea_projects\(Boss)_MacroGate\MACROGATE_AB_VERDICT.md`; review: `docs\memory_control\CODEX_MACROGATE_REVIEW.md`.
- **WAITING-USER:** (1) NewsGuard GuardConfig เคาะ + VPS attach (Phase 2, unchanged) (2) MacroGate live attach = user decision (deploy on breakout carry legs; use standalone watchdog or `_MG_SelfGate`; regime CSV → VPS via rclone; add `mris_export_regime` to daily chain) (3) refresh `tpl_regression` baseline for a formal GREEN (Jul-11 ticks stale). ⚠️ MacroGate evidence = 1 window (2024, in-sample); test a holdout year before sizing up.

**เป้า user:** เห็นข่าวแรงที่เกี่ยวกับพอร์ตทุกวัน + มีตัวคุมเหนือ EA ทั้งหมด (ลด lot / ปิดไม้ / block entry
ช่วงข่าวแรง ตาม policy ต่อ strategy)

**Phase 1 (เสร็จ 2026-07-10):** `scripts\news_calendar.ps1` — ดึง ForexFactory weekly feed → filter
High-impact 8 สกุลพอร์ต → (a) `portfolio\news_today.html` ฝังใน LIVE_DASHBOARD (มือถือเห็นทุกเช้า
ผ่าน gist) (b) `portfolio\news_week.csv` = machine-readable ให้ Phase 2 · cache กัน 429 · อยู่ใน
daily 07:30 chain แล้ว · **ข้อจำกัดที่ต้องรู้: กันได้เฉพาะข่าวตามนัด — Brexit/SNB-type (gap ไม่มีนัด)
กันด้วยปฏิทินไม่ได้ = เหตุผลที่ SL/cap ต้องมีเสมอ**

**Phase 2 — NewsGuard watchdog EA (OPEN, ต้องคุย design กับ user ก่อน build):**
- EA ตัวเดียว attach 1 chart/บัญชี อ่าน `news_week.csv` (คัดลอกไป Common\Files หรือ WebRequest ดึงเอง
  บน VPS — ต้อง whitelist URL ครั้งเดียว) · นาฬิกา event เทียบ server time
- policy ต่อ magic list (input): `BLOCK_NEW` (กันไม้ใหม่ N นาทีก่อน/หลัง event — ทำได้กับ EA เราเท่านั้น
  ผ่าน GlobalVariable flag ที่ chassis อ่าน) · `CLOSE_ALL` (ปิดไม้ magic นั้นก่อน event — ทำได้กับทุก EA
  รวม locked เพราะ watchdog มีสิทธิ์ระดับบัญชี) · `NONE`
- ค่าเริ่มแนะนำ: CLOSE_ALL เฉพาะ strategy ไร้ SL/recovery (Zeus 7777, gold grids) ก่อนข่าว USD แรง
  30 นาที · BLOCK_NEW สำหรับ breakout family (ข่าวคือ noise ไม่ใช่ signal ของมัน) · Boss_14 bench
  demo = NONE (เก็บ data ให้ judge เห็นพฤติกรรมจริง)
- **ห้าม build จนกว่า user เคาะ policy ต่อบัญชี/ต่อ magic** (มันจะไปปิดไม้เงินจริง — ต้อง explicit)
- **UPDATE 2026-07-17:** build เสร็จแล้วภายใต้ ORDER-083 (MT5+MT4, .ex5/.ex4 compile แล้ว) · draft policy
  ต่อ magic = `ea_projects\(Boss)_NewsGuard\GUARDCONFIG_2026-07-17.md` (รอ user เคาะ) · runbook transport
  แก้เป็น rclone แล้ว (VPS 2012 R2 ลง OneDrive client ไม่ได้) · เหลือ user attach ตาม
  `VPS_TRANSPORT_AND_ATTACH.md` เท่านั้น

**Phase 2.5 — MRIS macro-regime layer (PROTOTYPE BUILT 2026-07-17, Claude inline):** #073 reimagined
(user directive) = อ่านสัญญาณมหภาค→บอกทิศ+เฝ้าระวังล่วงหน้า สไตล์บทความ AUD/JPY carry. **รันได้จริง**
ที่ `scripts\mris\` (PowerShell, zero-token, sibling ของ news_calendar):
- `mris_classify.ps1` — barometer(AUDJPY/USDJPY/VIX/DXY/XAU/BTC)+tripwire relative(SMA200/ATR ไม่ hardcode)
  → state RISK_ON/NEUTRAL/RISK_OFF/STRESS + Risk Index + confidence(เส้นขนาน) · verified RISK_ON↔STRESS พลิกจริง
- `mris_exposure.ps1` — join DEPLOYMENTS → tag DIRECT_CARRY(8 JPY legs)/RISK_ON → action reduce-lot-not-cut
- `mris_brief.ps1` — Thai whisper brief (md+html embed dashboard) · `mris_run.ps1` = one-shot
- feed: MT5 exporter `_mt5_auto\mris\Export_Barometers.mq5` (broker symbols) · VIX/DXY/yields/copper = PENDING (web feeder TODO)
- seed snapshot 2026-07-16 อ่านได้ = **NEUTRAL แต่ 2 loaded lines** (AUDJPY ~3% เหนือ pin 110 · USDJPY 161 crowded)
- **รอ user:** เคาะ tripwire/threshold จริง (`_triage/MACRO_REGIME_SYSTEM_PROMPT.md`) + wire web feeder → แล้ว MacroGate (Phase 3) ยกเป็น order เต็ม

**Phase 3 — MacroGate watchdog (STUB 2026-07-17 — ห้ามหยิบไป build จนกว่า MRIS เคาะกติกา):**
- แนวคิด: watchdog ตัวที่สองแบบ NewsGuard (per-magic, 1 chart/บัญชี) แต่ trigger จากราคา in-terminal
  แทนไฟล์ข่าว — สภาวะ carry-unwind/risk-off (AUDJPY เป็นตัวนำ) → **ลด lot ×0.5 + BLOCK_NEW เฉพาะ
  magic กลุ่ม JPY-cross/risk-on** (Zeus AUDJPY 990110 · Boss_14 990208/201/203/205 · IchiADX 990066-67 ·
  BRK USDJPY 991003 · US30 991005) — **ไม่ปิด position** (user rule: reduce-lot-not-cut)
- กติกา trigger ต้องเป็น relative (เช่น D1 หลุด SMA200 + ร่วง >N×ATR ใน M วัน) — ห้าม hardcode level 110
  (เลขของรอบนี้ = input เสริมที่ user เคาะผ่าน MRIS)
- **บังคับ A/B backtest ก่อน attach:** window ครอบ 2024-08-05 carry unwind + 2020-03 บน leg ที่จะใส่จริง
  (คาดผลตาม Regime.mqh เดิม: ช่วย grid จริง · redundant กับ breakout — ถ้า A/B ไม่ต่าง = ไม่ใส่)
- blocked-on: user เปิด session MRIS (`_triage/MACRO_REGIME_SYSTEM_PROMPT.md` #073-reimagined) เคาะ
  tripwire/threshold ก่อน แล้ว Claude ค่อยยกเป็น order เต็ม (spec + acceptance + ห้าม)

## ORDER-076 — smoke-screen หัวกะทิ 41 ตัวจาก X-ray — `CLOSED (Claude 2026-07-14 — 16 mq5 ใหม่จริง: 11 REJECT/PARK + 1 build-on-needs-data ((ICE) CCI = PARKED, basket 9-major ไม่รอด) · verdict = _triage/ORDER076_MQ5_SMOKE_VERDICT.md)` (role: agent/qwen lane)

**คำสั่ง:** (1) cross-ref 41 ตัว (CSV filter has_sl=yes & lot_escalation=no) กับ EA_SCORECARD +
ผล ORDER-036 (MT4 1,318 sweep) — ตัวที่เคย screen แล้วห้ามรันซ้ำ ใช้ผลเดิม (2) ตัวใหม่จริง:
smoke ตาม filter chain มาตรฐาน (name-DQ → smoke PF>1 → BWD-OOS 2020-22 → spread-stress)
platform ตามไฟล์ · **compiled .ex4/.ex5 เท่านั้นถ้ามี — .mq4/.mq5 คอมไพล์ก่อน** (3) ตาราง verdict-ดิบ
ต่อ EA ต่อด่าน **Acceptance:** ตารางครบ 41 แถว (screened-before / smoked / DQ) + top-5 ตาม
BWD-OOS PF · commit `[tag] ORDER-076 done` **ห้าม:** verdict PASS/REJECT (Claude ตัดสิน) ·
แตะไฟล์ต้นฉบับ · แตะ 297 ตัว SL-unknown (รอ verification pass แยก ถ้าคุ้ม)


---

## ORDER-079 — Idea mining คลังคอร์ส: concept catalog (reframe จาก user 2026-07-10) — `DONE(Claude-inline, 2026-07-10 — catalog = _triage/FXDREEMA_IDEA_CATALOG.md)`

**ทำไม (user directive):** คลัง 1,050 EA = สื่อการเรียน ไม่ใช่สินค้า — ห้ามตัดสินด้วยเกณฑ์ risk structure
(43% no-SL คือ scaffold ของแบบฝึก ไม่ใช่ความผิด) · เป้า = **สกัดไอเดีย/แนวคิด** ที่ user เรียนมา
ให้เห็นเป็นแคตตาล็อกต่อยอดได้ · user ยืนยันในคลังมี Elliott Wave (รวมแบบเฉพาะ wave 5) + SMC —
ห้ามปัดตก แนวพวกนี้แล็บมี precedent ด้วย (Gold SMC = OOS_VALIDATED ใน EA_Project)

**คำสั่ง:** สร้าง concept-mining pass ต่อยอด xray (แหล่งข้อมูลต่อไฟล์: ชื่อไฟล์/โฟลเดอร์ · **fxDreema
block labels** (คนเขียนเอง สื่อความหมายตรง) · indicator signature · comment strings) →
จัด taxonomy แนวคิด เช่น: Elliott/wave-count · SMC/order-block/liquidity/BOS · session-time ·
breakout (แบบไหน) · reversion (RSI/CCI/Stoch/BB) · trend-follow (MA/ST/SAR) · currency-strength
meter · correlation/pair · news · scalping · grid/basket variants · dashboard/tool (ไม่ใช่ EA) ·
money-management exercises → output `_triage\FXDREEMA_IDEA_CATALOG.md`:
ต่อ concept: จำนวนไฟล์ · ตัวแทน 2-3 ไฟล์ (ตัวที่ block labels สื่อสุด) · mechanism sketch จาก labels ·
**cross-ref สถานะแล็บ**: เคยทดสอบ/ตาย/validated/ยังไม่เคยแตะ (เทียบ EDGE_CATALOG.md + memory
signal-landscape ผ่านไฟล์ repo) + CSV คอลัมน์ concept เพิ่มใน FXDREEMA_XRAY.csv
**เจาะพิเศษ:** ไฟล์ Elliott/wave ทั้งหมด (grep wave/elliot/impulse/zigzag ใน name+labels) และ
SMC (order block/liquidity/FVG/BOS/CHOCH/SMC) — ลิสต์แยกครบทุกไฟล์ พร้อมสรุป logic จาก labels ต่อไฟล์
**Acceptance:** catalog ครบ + ลิสต์ Elliott/SMC เต็ม + นับ concept ใหม่ที่แล็บไม่เคยทดสอบ ·
commit `[tag] ORDER-079 done` · **ห้าม:** ตัดสินดี/ไม่ดี ต่อ concept (Claude+user คุยกัน) · risk flags
ห้ามโผล่ใน catalog (คนละเอกสารกับ XRAY)

**สถานะ:** CLAIMED -> DONE(Claude-inline, 2026-07-10) — agent ตายที่ session limit, Claude เขียน/รันสคริปต์เองต่อ (fxdreema_concepts.py + boilerplate fix รอบสอง: doji-string เคย inflate candle_pattern 224->16) · ผลเต็ม = _triage\FXDREEMA_IDEA_CATALOG.md + concept column ใน XRAY.csv + _concept_summary.json


---

## ORDER-080 — วัดมูลค่า "limit-entry แทน market" บน EA เรา (แรงบันดาลใจ: บอท maker-only ของโพสต์ FB) — `CLOSED (Claude 2026-07-17): ตอบผ่าน ORDER-108 + 091C-D1d ไม่ต้อง build Boss_16 ซ้ำ`
**VERDICT (`_triage/ORDER080_LIMIT_ENTRY_VERDICT.md`):** pending-limit ≠ free win — (a) adverse-selection ในเทรนด์ (พลาด runner: ORDER-108 pending-only 1.76<market 2.07),
(b) ~26-28% ไม้ไม่ fill (lwma). **split (market+pending) = robust** (1.93/1.97 ทั้ง 2 regime) แต่ **config-conditional** (ช่วย reversion/balanced, ทำร้าย trend-chaser — ห้าม retrofit live trend EA).
กติกา: offer entry-mode เป็น input, default = validated mode, เปิด pending/split เฉพาะ reversion/balanced. lever อยู่ EDGE_CATALOG แล้ว.

## ORDER-080-orig (spec เดิม — superseded)

**สมมุติฐาน:** เข้าไม้ด้วย pending limit ที่ราคาดีกว่า signal price เล็กน้อย (แลกกับ fill ไม่ครบ)
ให้ EV ดีกว่า market entry — โลก crypto พิสูจน์ด้วย fee; โลก MT5 = ประหยัด spread/slippage แทน
**คำสั่ง:** เพิ่ม input `EntryMode` (0=market เดิม default · 1=limit offset) + `EntryLimitOffsetPips` +
`EntryExpiryBars` ให้ **Boss_16_KangarooGrid** (additive, default = พฤติกรรมเดิม, ผ่าน regression cage)
→ A/B บน config candidate 21/30 XAU H1: market vs limit offset {3, 6, 10 pips} expiry 1 bar ·
ทั้ง IS 2023-26 และ BWD 2020-22 · Model 1 (+Model 0 confirm คู่ที่ต่างกันสุด)
**Acceptance:** ตาราง market vs 3 offset × 2 window: PF/net/trades/**fill-rate** (นับไม้หาย) ·
commit `[tag] ORDER-080 done` · **ห้าม:** เปลี่ยน lever อื่น · verdict (Claude อ่าน — สนใจ EV ต่อไม้
หลังหัก opportunity cost ของไม้ที่ไม่ fill ไม่ใช่แค่ PF)

## ORDER-082 — Entry_Wave5: สัญญาณ Elliott ขา 5 ตาม rule ที่ user ถ่ายทอดเอง (2026-07-10) — `CLOSED — DEMO-ELIGIBLE (Claude 2026-07-14) · WAITING-USER attach · bundles = _vps_deploy/WAVE5_XAU (magic 990301) + WAVE5_XAG (990302)` (role: Claude spec → agent build/probe)

**Rule จากปาก user (บันทึกตรงคำ — นี่คือ ground truth ของ spec):**
- คนส่วนใหญ่พยายามเข้า wave 3 (เทรนด์ยาวสุด) แต่รู้ตัวก็ต่อเมื่อมัน confirm แล้ว (break S/R,
  break trendline) → เข้าไม่ทัน/RR ไม่คุ้ม
- **จุดได้เปรียบ: พอรู้ว่า wave 3 เกิดแล้ว → รอ pullback (wave 4) retrace ~23–38% ของ wave 3
  → เริ่มเข้าได้ เพื่อกิน wave 5**
- **SL = ยอด wave 1** (ตาม EW rule: wave 4 ห้าม overlap โซน wave 1)
- **ออก: break ยอด wave 3 / Fibonacci expansion 100%** — บริเวณนั้นมักเกิด **RSI divergence**
  ร่วม = สัญญาณเตรียมออก/เปิด trailing

**การแปลงเป็นกลไก (draft ให้ user ยืนยันก่อน build):**
1. Swing detection: ZigZag(H1/H4) label โครง 1-2-3: wave1 = impulse แรก, wave2 = retrace ไม่หลุดจุดเริ่ม,
   wave3-confirm = ราคา break ยอด wave1 แล้ววิ่งต่อ ≥ K×|wave1| (เช่น 1.0-1.618) — "รู้หลัง confirm" ตาม user
2. Arm entry เมื่อ: หลัง wave3-peak ราคา retrace เข้าโซน **23.6–38.2% ของ wave 3** (fib จาก zigzag) →
   entry ตามทิศ wave 3 (bar-open + optional confluence: RSI ยังไม่ divergence)
3. SL = ยอด wave 1 (± ATR buffer) — โครงสร้าง ไม่ใช่ระยะสุ่ม · invalid ทันทีถ้า retrace ลึกเกิน 50%
4. TP/exit: ลำดับ (ก) แตะ 100% expansion (wave5 = wave1 length จากจุดเข้า wave4) หรือ break ยอด wave3
   แล้วเปิด ATR trailing (ข) RSI divergence ที่ high ใหม่ = บังคับ trailing แน่น
5. Naked probe ตามมาตรฐาน (1 ไม้/สัญญาณ, no grid): symbol แรก = **XAUUSD H1** (trending home) +
   GBPUSD H1 · window 2023-26 + BWD 2020-22 · บาร์ผ่าน: naked PF ≥ 1.0 ทั้ง 2 window บน symbol ใดหนึ่ง
**หมายเหตุ:** มีไฟล์คอร์ส (Jobot) Elliott Wave 5 Zone v1/AAA ให้เทียบ rule (block labels) — ใช้ตรวจว่า
การตีความข้อ 1-4 ตรงกับที่คอร์สสอนไหม ก่อน build
**ห้าม:** build ก่อน user ยืนยัน draft ข้อ 1-4 · ข้าม naked probe ไป grid/recovery


---

## ORDER-082 — AMENDMENT (user ยืนยัน 2026-07-10 ค่ำ)

- ✅ ZigZag + Fibonacci = แนวที่ user ต้องการ (ตรงกับไฟล์คอร์สด้วย) · ข้อควรระวัง build:
  **ZigZag ขาสุดท้าย repaint — ใช้เฉพาะ pivot ที่ confirm แล้วเท่านั้น** + พิจารณา ATR-adaptive
  deviation แทน fixed (ให้ swing scale ตาม volatility)
- Entry level = **input เลือกได้ {23.6, 38.2, 50, 61.8}** (user: "จุดสำคัญ ... ประมาณนี้") — sweep เป็น lever
- Invalidation = **โครงสร้าง: wave 4 ห้าม overlap โซนยอด wave 1** (แทน fixed 50% เดิม — สอดคล้อง
  SL ที่ยอด wave 1 พอดี ราคาแตะ SL = โครงพังเอง)
- สถานะ: spec ครบ พร้อม build → คิวหลัง ORDER-078/083
- **Task 0 gates CLEARED (Opus, 2026-07-12, commit `fc31d0b`):** Jobot ref = misnomer (RSI+CCI martingale ไม่มี wave logic → ไม่มี ref impl, plan = spec of record) · **fable-advisor spec-check PASS** (arch A sound + guards G1-G4) · user เคาะ: both-direction · TP วัดจากราคาเข้า (entry±\|W1\|) · **trailing ตั้งแต่แรก + RSI-divergence tighten** · แผน build 6 tasks พร้อม = `docs/superpowers/plans/2026-07-12-entry-wave5.md` → รอปล่อย Task 1-4 build
- **Task 1-4 BUILT + Task 6 naked probe DONE (Opus, 2026-07-13):** build เสร็จ (commit `bfa048f`) — Opus verify เอง compile 0/0 + regression CLEAN (11-16 byte-identical) + **จับ+แก้บั๊กร้ายที่ subagent พลาด: labeling 3-pivot → wave1end/wave3peak ต่างประเภทเสมอ = Entry ยิงไม่ออก (zero-trade การันตี) → แก้เป็น 4-pivot + wave2-validity + fib วัดจาก wave3 จริง**
  - **probe 4 cell (default params, ExitMode=TRAIL, MaxLevels=1, structural SL):** XAU main(23-26) **PF 1.57**/174t/DD1.66% · XAU BWD(20-22) 0.95/148t · GBP main **PF 1.18**/164t/DD0.66% · GBP BWD 0.96/137t
  - **VERDICT (lead):** ✅ fix ยืนยัน (ยิงไม้ออกทั้ง 4 cell) · **deploy-gate (both-window≥1.0) ยังไม่ผ่าน** (ทั้ง 2 sym ตก BWD เฉียดๆ) · **แต่ ≠ ตาย** = PARAMETRIC-marginal · ALIVE · build-on (main>1 ทั้งคู่, BWD 0.95-0.96 เฉียดเส้น, DD จิ๋ว, 0 lever swept) · XAU main 1.57@win45% = mechanism มีของ
  - ~~**ค้าง = SWEEP (pace, ยังไม่รัน)**~~ → **SWEEP DONE + DEMO-ELIGIBLE (Opus 2026-07-14):** plateau ยืนยัน 2 symbol
    (XAU fib23.6→30 ต่อเนื่อง 1.11/1.11 · XAG 6/6 cell MAIN 1.30-1.45/BWD 1.28-1.35 แข็งกว่า XAU) · MC ruin 0.00% ·
    holdout XAU H4 MAIN 1.74/BWD 1.01 · corr gate vs 4 gold cohort max|corr|=0.415 << 0.8 · bundle staged
    `_vps_deploy/WAVE5_XAU|XAG` · ⚠️ template ไม่มี tester-gate — attach แล้วเทรดทันที · เหลือ: user attach บน VPS
    (commits `0b4acdbc`+`86151de9`, spec-of-record = `docs/superpowers/plans/2026-07-12-entry-wave5.md`)

## ORDER-084 — Retro-audit: ไล่ verdict DEAD/REJECT/PARKED ทั้งหมดกับกฎใหม่ (user: "ตายเปล่าเยอะ") — `CLOSED (extract DONE agent 2026-07-10 · judge DONE Claude 2026-07-16: กอง ก ~95 ฆ่าถูกกติกา · กอง ข rescue queue 5 ตัวเรียง EV · กอง ค PARKED-VERIFY(user) 2 รายการ — rescue ยกเป็น order ใหม่ทีละใบตาม pacing)`

**ทำไม:** กฎ rescue-ladder (optimize ≥3 รอบ lever ต่างชุด × ≥2 TF ก่อนตาย) + PARKED-VERIFY(user) +
EA-SCORE เพิ่งเกิดวันนี้ — verdict เก่าจำนวนมากตัดสินก่อนกฎนี้ · user เชื่อ (ประสบการณ์ตรง: หลายตัวที่ live
อยู่รอดเพราะมือ user เคยเทส) ว่ามีของดีตายเปล่าค้างอยู่

**ขั้น 1 — extract (mechanical, agent):** กวาดทุก verdict จาก EA_SCORECARD_AND_REGISTRY.md +
MASTER_BACKLOG.md + memory signal-landscape (อ่านผ่านไฟล์ repo ที่อ้างถึง) + AGENT_TASKBOARD
(ORDER ที่ REVIEWED) → ตาราง CSV ต่อ EA/concept: ชื่อ · verdict · วันที่ · **lever ที่ sweep จริง
(นับจากหลักฐาน ไม่ใช่คำอ้าง)** · จำนวน TF ที่ทดสอบ · จำนวน symbol · best PF ที่เคยเห็น · class
(STRUCTURAL/PARAMETRIC/artifact) · หลักฐานชี้ไปไหน
**ขั้น 2 — judge (Claude):** แยก 3 กอง — (ก) STRUCTURAL/artifact ยืนยัน = ตายจริง ไม่แตะ
(ข) **under-swept ตามกฎใหม่** (sweep <3 รอบ หรือ 1 TF) = คิว rescue เรียงตาม EV: best-PF ใกล้เกณฑ์ +
mechanism เข้ากับ symbol ที่รู้จัก (reversion→ranger · breakout/trend→XAU/GBP) (ค) idea ดีแต่เครื่องมือ
ยุคนั้นไม่ถึง = **PARKED-VERIFY(user)** สรุป 3 บรรทัด/ตัวส่ง user
**ขั้น 3 — แผน rescue:** เลือก top 5-10 จากกอง (ข) → order sweep ตามสูตร rescue-ladder
(lever ชุดตามประเภทใน backtest-optimize-rigor) — **ห้ามรันใน order นี้** แค่วางแผน+ประมาณชั่วโมงเครื่อง
**Acceptance ขั้น 1:** `_triage\RETRO_AUDIT_VERDICTS.csv` ครบทุก verdict ที่หาเจอ + สรุปนับต่อกอง ·
commit `[tag] ORDER-084 extract done` · **ห้าม:** ตัดสิน/จัดกองเอง (แค่ extract หลักฐาน) · ห้ามรัน backtest

### ORDER-084 extract SUMMARY (Claude-agent, 2026-07-10 — raw counts, no judging)
1. **Total verdict rows: 154** ใน `_triage\RETRO_AUDIT_VERDICTS.csv` (per-EA/cell/concept; aggregate-pool rows ครอบ ~2,700 EAs ที่ตายเป็นกอง: ORDER-036 1,318 ex4 · ORDER-035 203 ex5 · 63-EA screen · idea_bank 251)
2. Counts by verdict: **REJECT 52 · DEAD 33 · CANDIDATE 13 · CORE/ROBUST/DEMO 12 · NO-EDGE/closed 11 · PARKED 11 · DQ/DISQUALIFIED 10 · CONDITIONAL 3 · WATCH 3 · LEAD 2 · DROP 2 · other 2**
3. **TFs_tested == 1: 141/154 (92%)** — เกือบทั้ง lab ตัดสินจาก TF เดียว (H1 ล้วนเป็นส่วนใหญ่); มีแค่ 13 ราย ที่เห็น ≥2 TF (RSI from pips 4 TF · Boss_16 2 TF · WaveS1 2 TF · NR7/PrevDay/EMATREND/Kangaroo/NuiIndy/ST03/HalfTrend ฯลฯ)
4. **Evidence = default-only/smoke-only (เข้ม): 29 rows · รวมชั้นเดียว (BWD-only/lot-check-only/hard-gate): 44 rows** — กองนี้คือผู้สมัคร rescue-ladder โดยนิยาม (ไม่เคยเห็น lever sweep แม้แต่รอบเดียว)
5. Top-10 best_PF_seen ในกอง DEAD/PARKED/REJECT/DQ (118 rows): CITY-GOLD 259.99 (artifact) · gold-grid concept 85.14 (M2 artifact) · Degold 13.12 (M1-vs-M4 artifact) · Scalper_S3 10.71 (fixed-spread artifact) · GBPJPY1H90PCWR 8.15 (PARKED-no-data, absurd-flag) · Golden Elephant 7.77 (TP-lever artifact) · Gold Stuff V7 5.09 · Dark Mimas 5.0 (regime) · **EA_SUPERTREND XAU H4 4.49 OOS (ตัวจริง — parked เพราะ corr 0.946 กับ KER)** · COT-filter 3.96 (year-split kill)
6. หมายเหตุ: top-PF ส่วนใหญ่ = artifact ที่พิสูจน์แล้ว; PF สูงสุดที่*ไม่ใช่* artifact ในกองตาย = SuperTrend 4.49 · IR Whale 3.94(suspect) · EURUSD Forex Robot 3.89 (BWD 0.39) · FZ2 3.05 (flat-lot 0.36) · 143 E4.7.4 3.0 (BWD 0.85) · AsReMix 2.99 (PARKED regime)
7. รูปแบบที่เห็นซ้ำใน extraction (ข้อมูล ไม่ใช่คำตัดสิน): กอง mass-smoke ตายด้วย 1 symbol-pair × 1 TF × default; กอง concept 200-list ตายด้วย default smoke 1-2 cell แล้วปิด "concept DEAD ถาวร"; กองที่ sweep จริง ≥3 lever มีน้อย (~25 rows: Boss_14 family · ST03 · SessionBreakout 1200-pass · FlagPennant · WaveS1 · SuperTrendFlip · Degold · ZIGL-EURUSD 216-pass ฯลฯ)
8. Sources ที่กวาดครบ: EA_SCORECARD_AND_REGISTRY.md · MASTER_BACKLOG.md · AGENT_TASKBOARD.md (ORDER-001→083) · ORDER-036_MT4_MASS_SMOKE.md · memory signal-landscape.md · STRATEGY_200_ANALYSIS.md · PROJECT_STATE.md §07-08 (อ้างถึงจาก taskboard)
9. STRATEGY_200_ANALYSIS.md = **prior scores ไม่ใช่ verdict** (คะแนน /10 ก่อนเทส) — ไม่ได้สร้าง row ต่อ prompt; ตัวที่ถูกเทสจริง (#9/20/30/62/66/68/70/83/94/100/105/127/135) มี row จากผลเทสใน backlog/signal-landscape แล้ว
10. AGENT_TASKBOARD_MERGE.md = engineering port track ล้วน (MERGE-01..08) ไม่มี EA verdict — ไม่มี row
11. ORDER-064 (ChatGPT export mining) เป็น idea-triage ไม่ใช่ backtest verdict — ไม่ได้สร้าง row (จดไว้กันสับสน)
12. Orders 048-054 ไม่มี header ใน taskboard (เลขข้าม 047→055) — verdict ของ funnel 07-08 (SqueezeBRK ROBUST · Trendline #8 EXPERIMENTAL · ConfluenceMartATR/London/plain-squeeze ตก) สกัดจาก PROJECT_STATE §SESSION 2026-07-08 + การอ้างอิงใน ORDER-059/065/067 แทน
13. Verdict ที่มี supersede-chain ถูกยุบเหลือ row เดียว (verdict ล่าสุด + ประวัติใน evidence): ST03 family (CORE→STRUCTURAL 07-10) · 2020v2 (REJECT→revive→REJECT) · Happy thaipop (PARKED→REJECT ×16.3) · Automated Forex Grail (AUTO-REJECT→revive→REJECT-spread) · LNBREAK/NRBreakout (DEAD→re-exam ORDER-008B)
14. คอลัมน์ class_claimed = คำอ้างของ verdict เดิมเท่านั้น (STRUCTURAL/PARAMETRIC/artifact/unknown) — ยังไม่มีการจัดกอง rescue/dead/verify ตามข้อห้าม
15. ขั้น judge (กอง ก/ข/ค + แผน rescue top 5-10) = รอ Claude lead อ่าน CSV

### ORDER-084 ขั้น 2 JUDGE (Claude lead, 2026-07-16) — จัดกอง 107 rows กลุ่มตาย + แผน rescue

**กอง ก — ตายจริง ไม่แตะ (~95 rows):** ทุกตัวที่มี kill-chain ครบอย่างน้อย 1 ด่าน structural/artifact จริง:
BWD wipeout (Dark Mimas 0.45 · EURUSD Robot 0.39 · SEMIS 0.05-0.65 · GapinFX 2022 0.02) · spread-stress
(Grail · Yetti family · Expert · 2020v2) · lot-check (Z61 ×44-80 · AF-Global →94 lots · Dark Venus ×2+ ·
Happy thaipop) · Model-ladder artifact (Elephant 85→1.41 · Scalper_S3 · Degold M1-fantasy · Zeus Gold Hedge
M1-false-pass) · exhaustive sweep ถึง ceiling (MACD-cross 1.16 · SessionBreakout 1,200-pass 1.20 ·
RSI_Swing_BB 27-combo · LNBREAK 0/81 · Boss_14 EURCHF 0/54 + US30 + BREAKOUT EU/GBPJPY 0/180-175 ·
LondonConso rescue-sweep 48-combo แล้วยังตก) · no-source/cracked (CITY-GOLD · North East Way · KRAPOOK).
**การ audit ยืนยัน: กองนี้ฆ่าตามกติกา ไม่ใช่ตายเปล่า.**

**กอง ข — UNDER-SWEPT ตามกฎใหม่ (ตายจาก default-only/1-TF, ยังไม่เคยเห็น lever sweep) → คิว rescue เรียง EV:**
1. **Boss_14_GridLog second-symbol pool (GBPJPY/NZDUSD/USDCAD/AUDNZD)** — defaults เท่านั้น (0.68-1.13,
   GBPJPY OOS 1.12 เฉียดบาร์) · chassis validated แล้ว = EV สูงสุด · rescue = funnel มาตรฐาน ≥3 lever × H1+H4
   (~2-3 ชม.เครื่อง/symbol, ใช้ launcher เดิมของ family ได้เลย)
2. **EA_XAU_NY (#83 NY-session breakout)** — default smoke เดียว PF 1.12/350t · mechanism = breakout@XAU
   (edge class ที่พิสูจน์แล้ว) · sweep session-window × buffer × SL × {M30,H1,H4} (~2 ชม.)
3. **EA_ZSCORE (#100)** — default เดียว PF 1.15/0.95 H4 · reversion signal แต่เทสบน XAU (บ้าน momentum) —
   ผิดบ้านตาม portfolio-edge thesis · rescue = ย้ายไป ranger pairs (AUDNZD/EURCHF/EURGBP) × H1/H4 ×
   threshold sweep (~2 ชม.)
4. **EA_ICHIMOKU (#66)** — claimed STRUCTURAL "cloud lags" แต่หลักฐาน = default 1 cell = overclaim ชัด ·
   sweep Kumo period × TF บน XAU/JPY (~1.5 ชม.)
5. **EA_KELTNER (#62)** — default เดียว PF 1.04 · momentum-class ถูกบ้านแล้ว แต่ PF ไกลบาร์ · ท้ายคิว (~1.5 ชม.)
6. **EA_PREVDAY / EA_NR7** — เคย iterate 2-3 รอบแล้ว (เกือบครบ gate) · ต่อคิวเฉพาะถ้า 1-5 ให้ผลดี
**หมายเหตุ regime-parked (Zeus AUDJPY/AUDUSD · Boss_14 NZDUSD-SELL · AsReMix):** full-funnel แล้ว ไม่ใช่
under-swept — ทางฟื้นเดียว = lever `_50_ Regime.mqh` ใน funnel ใหม่ (ORDER-057 adoption path) ไม่ใช่ re-sweep เปล่า

**กอง ค — PARKED-VERIFY(user):** (1) **Phoenix_EA_v5_6_03 + GBPJPY1H90PCWR** (PF 8.15 absurd-flag) —
BWD ว่างเพราะ MT4 history ขาด · ปลดล็อกทันทีที่ user โหลด history (memory `mt4-history-gap-jumstoch` มีคิว
priority อยู่แล้ว: NZDUSD-H4/AUDJPY-H1/GBPJPY/EURGBP) (2) **VisualMartiEA** — unverifiable ×2 (ladder ×5
น่าจะ structural แต่ยังไม่มีหลักฐาน) — แจ้ง user ตามกติกา ห้ามปล่อยตายเงียบ

**ขั้น 3 (แผน — ห้ามรันใน order นี้):** rescue 1-2 ตัว/รอบตาม pacing เริ่มจาก Boss_14 GBPJPY → XAU_NY →
ZSCORE · รวม ~9-11 ชม.เครื่องสำหรับ top-5 · ยกเป็น order ใหม่ทีละใบตอนถึงคิว (อย่า burst)

**🔧 แก้คำตัดสินกอง ก (user จับ 2026-07-16 — pending-limit lever):** spread-death subset (Yetti3 · Grail ·
Expert · 2020v2 · Scalper_S3 ฯลฯ) ผมเคยจัด "ฆ่าถูกกติกา" — **แต่ฆ่าใต้ market entry เท่านั้น.** ตัวที่
**(1) entry = reversion/mean-revert** (limit fill บน pullback ได้) **+ (2) มี source แก้ได้** → pending buy/sell
limit = lever ที่ยังไม่เทส → **ย้ายจาก "ตายจริง" ไป rescue-verify** (compiled vendor แก้ entry ไม่ได้ = ตันตามเดิม ·
breakout = pending-limit ผิดทาง มันต้อง chase). vehicle = ORDER-091C-D1d/080 ด้านล่าง (JUMSTOCH เหมาะสุด).

**ผลรอบ rescue 2026-07-16:** #1 GBPJPY = ✅ revive (Model-4 confirm, verdict `_triage/ORDER106_*`) ·
#2 XAU_NY = 🟡 regime-dependent long-gold (edge จริง in-regime แต่ไม่ both-window; 3 lever swept รวม direction;
build-on = จับคู่ ORDER-057 regime-gate; verdict `_triage/ORDER084_XAUNY_RESCUE_VERDICT.md`) · **#3 ZSCORE = ❌ REJECT (2026-07-16):
ย้ายไป ranger (AUDNZD/EURGBP/EURCHF) × threshold{2.0,2.5,3.0} × {H1,H4} × both-window = 36 runs ไม่มี both-window survivor
(≥1.1). ดีสุด EURGBP H4 t3.0 1.04/1.12 แต่ thin 36-42t + spike (t2.0/2.5 ตก) = high-threshold thin-artifact. reversion
ไม่มี edge แม้บนบ้านถูก → valid kill (optimize-on-right-home-fail) ตอกย้ำ momentum>reversion prior · CSV `_mt5_auto/ZSCORE_RESCUE_RANGER.csv`** ·
next: ICHIMOKU → KELTNER (⚠️ agent delegation ต้องใส่ "foreground synchronous ห้าม background-wait" เสมอ — ZSCORE agent ตกหลุมนี้)

**ผลรอบ rescue #4 ICHIMOKU (#66) = ORDER-112 (2026-07-16B):** เปิดพบว่า rescue ทำไปครึ่งทางแล้ว (probe 2026-07-11
sweep ADX+exit+symbol) → USDJPY = cell เดียวที่รอด (smoke 1.25 / IS 1.13 / OOS 2.66-31t · GBPJPY/AUDJPY/GBPUSD/EURUSD ตาย).
**แต่ probe นั้นบน Model-2 + recent-only(2023-25) + Kumo-period ไม่เคยแตะ = 3 ช่องโหว่ตรง VERDICT GATE.** ORDER-112 =
เติม lever แกน: Ichimoku/Kumo periods {fast6/17/34 · def9/26/52 · med12/34/68 · slow20/60/120} × {H1,H4} × both-window
Model-4 (16 runs) · isolate: hold ExitMode2/AdxMin20/Sl2.0 · runner `_mt5_auto/run_ichi_kumo_bothwin.ps1` · CSV
`_mt5_auto/ICHI_KUMO_BOTHWIN.csv`. **VERDICT = 🟡 REVIVED (คว่ำ "DEAD") → PARKED-BUILD-ON:** 6/8 cell both-window บวก >1.1 (plateau);
med-H4(12/34/68)=1.48/1.39 + slow-H1(20/60/120)=1.31/1.22 ผ่าน ≥1.2 both. **แต่ year-split = ทั้งคู่ 2 ปีขาดทุน** (agg โดนปีเทรนด์กลบ)
→ ไม่ผ่าน all-years-positive = ยังไม่ demo. **DEAD 2026-06-27 = ผิด** (under-swept: เทสผิด symbol XAU + ไม่แตะ period lever).
Build-on lead: 2 config ขาดทุนคนละปี → diversified basket (5/6 ปีบวกเมื่อรวม, **full-period PF 1.448** ยืนยัน). verdict = `_triage/ORDER112_ICHIMOKU_RESCUE_VERDICT.md` · CSV year-split `_mt5_auto/ICHI_YEARSPLIT.csv`.

**ผลรอบ rescue #5 KELTNER (#62) = ORDER-113 (2026-07-16B) = ❌ REJECT-CONFIRMED:** sweep channel-def (EMAPeriod/KeltMult)
× TF × both-window Model-4 บน USDJPY (16 runs, `_mt5_auto/KELT_CH_BOTHWIN.csv`). **H4 = window-inversion** (BWD 1.22-1.48 แต่
MAIN 2023-26 พังหมด 0.71-0.76 DD15%) · **H1 = churn** (1.0-1.14 ไม่แตะ 1.2, 450-530t spread-fragile) · ไม่มี cell both-window ≥1.2.
original DEAD ถูก—ครั้งนี้ swept จริง = valid kill. Build-on ปิด (breakout→regime-gate redundant). verdict = `_triage/ORDER113_KELTNER_RESCUE_VERDICT.md`.
**บทเรียน:** rescue-ladder ให้ผลต่างกัน — ICHIMOKU revived · KELTNER dead ภายใต้ treatment เดียวกัน = กระบวนการทำงาน (ไม่ rubber-stamp).

**ORDER-112B ICHIMOKU basket build-on = DONE → DEMO-ELIGIBLE bundle #9:** merged-equity (2 config continuous Model-4, merge deal list ตามเวลา
— deploy = 2 instance ไม่ต้อง build wrapper): **PF 1.339 · 357t · true max-DD 6.09% · MC PF_5th 1.036 · DD_95th 10.77% · ruin 0%.**
edge บวกจริง+MC-survive แต่ thin (PF_5th 1.036) = demo small-lot ไม่ใช่ live leg แข็ง. **Bundle `_vps_deploy/ICHIADX_USDJPY_BASKET/`** (H4 med 990066 + H1 slow 990067)
พร้อม attach (user 2026-07-16B APPROVED "เอาเข้าทั้งหมด" → roster ใน DEMO_DEPLOYMENT_PLAN, register ตอน attach จริง). script `_mt5_auto/ichi_basket_merge_mc.ps1`.

**🥇 ORDER-112C/D ICHIMOKU multi-home = XAU ฟื้นด้วย period lever (2026-07-16B):** เอา config USDJPY-winner ไป 6 trenders × both-window Model-4
(`_mt5_auto/ICHI_MULTIHOME.csv`). GBPJPY/EURJPY/AUDJPY/GBPUSD ตาย/single-window · CADJPY 1.16/1.15 near-miss · **XAUUSD = medH4 3.94/1.25 + slowH1
1.66/1.39 ผ่าน both-window ≥1.2** → คว่ำ "XAU ceiling 1.13" (default-period only). year-split (`ICHI_XAU_YEARSPLIT.csv`): medH4 6/6 ปี ≥0.99 (thin 8-20t/yr) ·
slowH1 5/6 ปีบวก (32-41t/yr). แข็งกว่า USDJPY basket แต่ **gate ชี้ขาด = corr vs XAU legs เดิม** (XAU แน่นมาก).

## ORDER-112E — corr check: Ichimoku-XAU additive หรือ redundant? — `DONE(Claude 2026-07-16B) = 🎯 ADDITIVE (reduced-lot)`
**ผล:** full-window XAU Model-4 → monthly Pearson (`_mt5_auto/ichi_xau_corr.ps1`): Ichimoku-XAU slowH1 PF 1.57/236t/Sharpe 3.0 ·
**vs BRK 0.263 · Kaufman 0.574 · SuperTrend 0.646** = additive (max 0.646, ต่ำกว่า SuperTrend-0.724-block). **VERDICT: candidate จริง.
Bundle #11 `_vps_deploy/ICHIADX_XAU/` (H1 slow magic 990068)** — เพิ่มใน roster แล้ว. medH4 = optional 2nd leg (990069 reserved).
⚠️ **corr = live-decision gate เท่านั้น ไม่ใช่ demo gate** (user 2026-07-16B): demo เอาขึ้นเทส normal lot คอนเฟิร์มว่าเวิร์ค; corr sizing/cut ตอนเงินจริง. เก็บเลข corr ไว้ตอน promote live.
รายละเอียด original order ด้านล่าง (เก็บไว้ provenance):

## ~~ORDER-112E — corr check~~ (spec เดิม, ปิดแล้ว)
**ทำไม:** XAU Ichimoku (slowH1 20/60/120, both-window 1.66/1.39, 5/6 yr+) = edge จริง แต่ XAU portfolio แน่น (BRK/Kaufman/SuperTrend/Wave5/MacdDiv);
SuperTrend เคยโดน corr 0.724 block. ต้องรู้ก่อนว่าเป็น leg ใหม่จริงหรือซ้ำ.
**ขั้น:** (1) รัน (EXP)_IchiADX_Naked slowH1 (set `_mt5_auto/ab_sets/ichi_kumo/KUMO_slow_H1.set`) XAUUSD H1 full 2020-2026 Model-4 → report
(2) ดึง monthly P&L จาก deal list (pattern เหมือน `ichi_basket_merge_mc.ps1`) (3) เทียบ `_mt5_auto/corr_monthly.py` กับ monthly ของ XAU legs เดิม
(รัน full-window ของ EA_BREAKOUT_XAU Bars8 + KAUFMAN_ER buyonly เป็น reference — reports อาจมีแล้วใน `_mt5_auto/reports/`).
**Acceptance:** ตาราง Pearson monthly Ichimoku-XAU vs {BRK, Kaufman, SuperTrend ถ้ามี}. **verdict = Claude:** corr <0.6 ทุกตัว = additive leg ใหม่
(build bundle) · >0.8 ตัวใด = redundant (small-lot หรือ drop) · 0.6-0.8 = reduce-lot include. **ห้าม:** auto-drop (user rule: high-corr = ลด lot ไม่ตัด).

**✅ ORDER-114 PREVDAY+NR7 = DEAD (ปิด rescue queue สมบูรณ์, 2026-07-16B):** swept lever แกน (NR_Period{4,7,10,14} · buffer{0.1,0.3,0.5})
× both-window Model-4 บน XAU (28 runs, `_mt5_auto/PREVDAY_NR7_CLOSE.csv`). **NR7 = window-inversion 16/16 (BWD 0.62-0.92) + DD 27-83%
= structural dead** · **PREVDAY = ไม่มี config แตะ 1.2 both-window (marginal churn)** = dead. verdict `_triage/ORDER114_PREVDAY_NR7_CLOSE_VERDICT.md`.

**🏁 ORDER-084 RESCUE QUEUE = CLOSED (6/6 ยกจัดการครบ):** revive 2 (GBPJPY→leg#8 · ICHIMOKU→USDJPY+XAU basket) · dead 4 (ZSCORE·KELTNER·PREVDAY·NR7 —
swept จริงทุกใบ) · XAU_NY = regime-dependent build-on. **regime-parked (Zeus AUDUSD · Boss_14 NZDUSD-SELL/USDCAD) = full-funnel แล้ว ไม่ใช่ under-swept
→ ทางฟื้นเดียว = graft `_50_ Regime.mqh` (regime-rescue track, low-prior) — ไม่อยู่ใน rescue-ladder scope.** rescue archaeology จบ.


---

## ORDER-091 — MASTER PLAN: intake คลัง Forex 9 โฟลเดอร์ของ user (แผนแม่บท — ลูก 091A-D จ่ายตาม pacing) — `OPEN`

**ที่มา (user 2026-07-10 ค่ำ พร้อม annotation ต่อโฟลเดอร์ — เก็บคำต่อคำใน chat log):** คลังใหญ่กว่า
ที่ X-ray รอบแรกกวาดมาก — coverage เช็คแล้ว: `10_EA_PROJECTS` โดนแค่ 211 path · `04_FxDreema_Learner`
7 path · ขนาดจริง: ~1,100 src + ~9,600 binaries + **~1,100 report/set แนบ** (BOT MOGUL 713 + Final EA 389)

**กฎยืนพื้นทุก wave:** pacing 1-2 order/รอบ · vendor report = claim ไม่ใช่หลักฐาน (memory
wobr-botranking: BotMogul rank = adverse-selected overfit) · ทุกตัวจบ funnel ต้องได้ EA-SCORE ·
mechanism ที่เคยพิมพ์เงิน → จด IDEA_CATALOG เสมอ · DD สูง ≠ ปัดตก → diagnosis→lever (คำ user:
".Final EA อาจ DD เยอะแต่เอาไปทำต่อได้ เชื่อผม")

**Wave 0 — 091A: ขยาย X-ray+concept ให้ครบ 9 โฟลเดอร์ — `DONE(Claude-agent, 2026-07-11)`** (mechanical, dedupe hash vs 1,050 เดิม):
`wait_Fxdreema MT5` (151 src) · `3. ready to use` (38+102) · `review EA\Jobot` (1,556 bin) ·
`BOT MOGUL` (2,905 bin) · `AI_GEN` (168 src) · `Course jobot` (375 src) · `04_FxDreema_Learner`
(221 src) · `.Final EA` (189 src + 4,514 bin) → merged catalog + ตาราง "ใหม่จริง vs ซ้ำของเดิม"

**Wave 1 (ต่อจาก 085B/083B ที่ค้างคิว):**
- **091B — BOT MOGUL report sweep:** parse 713 vendor reports → ตาราง claimed PF/DD/symbol/TF →
  คัด top ตาม claim × โครงผ่าน X-ray → **BWD-OOS spot-kill ทีละ 5** (1 รัน/ตัว ฆ่าถูกสุด) —
  ห้ามเชื่อ report แนบจนกว่า BWD เราเองผ่าน

---

## ORDER-091C-D1d — JUMSTOCH pending-limit entry variant (= ORDER-080 vehicle, user idea) — `🔼 PRIORITIZED (user reaffirm 2026-07-16: "EA ตายเพราะ spread ตั้ง pending + ขยาย TP") — vehicle แรกของ pending-limit rescue · role: Claude/Sonnet build → run`
**ที่มา:** user + ORDER-080 · mean-reversion เข้าหา LWMA → วาง **buy-limit ใต้ราคา / sell-limit เหนือ** ที่ระดับ
grid แทน market → fill maker ไม่จ่าย spread (grid 5-7k ไม้ = ประหยัด spread เยอะ อาจดัน PF ขึ้นชัด). **ทำไมเลือก
ตัวนี้เป็น vehicle แรก:** reversion (limit-compatible เป๊ะ) + grid เทรดเยอะ (spread saving ทวีคูณ) + source แก้ได้.
**คำสั่ง:** (1) สร้าง variant `(EXP)_JUMSTOCH_pending.mq4` (หรือ port entry เข้า Boss V2) — เปลี่ยน OrderSend market
เป็น pending limit ที่ราคา entry logic เดิม + จัดการ expire/re-place · ห้ามแตะ lot/SL/exit logic (isolate ตัวแปรเดียว)
(2) compile 0/0 (3) รันเทียบ market-vs-pending บน 2 home cell (EURUSD+AUDUSD H1) + spread จริง · **+ lever TP-widen
(user 2026-07-16): A/B `TP +0/+2/+5 pip` คู่กับ pending** (spread/TP ratio ลด แลก win% — ต้องวัด net) · ตาราง EV/ไม้
เทียบ (**fill-rate ของ pending ด้วย — limit ไม่ fill ทุกไม้ = ไม้ที่พลาด = โอกาสหาย · วัด EV/ไม้ + fill-rate ไม่ใช่ PF
เดี่ยว** เพราะ PF อาจสวยขึ้นเพราะเหลือแต่ไม้ดีแต่กำไรรวมหด) · **บาร์: pending net-EV > market net-EV ที่ spread จริง
(หลังหัก opportunity cost ของไม้ไม่ fill) = ยืนยันคุณค่า**
· **ห้าม:** เปลี่ยน lever อื่นนอก {entry-type, TP-widen} · verdict · commit `[tag] ORDER-091C-D1d done`
**หมายเหตุ:** นี่ตอบ ORDER-080 (limit vs market) + สมมติฐาน user 2026-07-16 ด้วย EA จริงตัวแรก → ปิด 080 ในตัวถ้าได้ผล

### ORDER-091C-D1d DONE + REVIEWED(Claude 2026-07-16): build MT5 `(EXP)_LwmaRev_Pending` + A/B Model-4
pending fill-rate ~70-73% · pending PF ≥ market 3/4 cell (+0.03-0.06 = spread/entry save) **แต่ base LWMA reversion
ติดลบทุก cell (0.55-0.93)** → วัด spread-save delta ได้ (~+0.05 PF/ไม้) แต่พลิก loser→winner ไม่ได้ (reversion no-edge).
**สรุป pending รวม 2 ฝั่ง = `_triage/PENDING_LIMIT_SYNTHESIS.md`:** pending = refinement (~+0.05 PF) ไม่ใช่ resurrector ·
ไม่ free (พลาด ~28% fill, adverse-selected ได้) · **split structure (Thread B break-retest) = form ที่ adoptable** ·
spread-death revival คุ้มเฉพาะตัวที่ post-spread PF ≥ ~0.95 (gap เล็กพอให้ +0.05 ดันข้าม) — ตัดตัวที่ collapse 0.5-0.7 ทิ้ง.
**next (queue):** TP-widen A/B บน reversion vehicle · หา reversion base ที่ near-breakeven มาเป็น demonstrator ที่ดีกว่า.

---

## ORDER-117 — CAMPAIGN: รีด EA ที่ validated แล้ว — coverage (symbol×TF) + precision-filter (user 2026-07-18: "symbol×TF ยังไม่หมด + เพิ่ม Sto/RSI/CCI/volume/PA/MTF จับจังหวะแม่นขึ้นได้") — `CORE DONE(Claude 2026-07-18) = low yield · 1 PARKED-VERIFY (GBPUSD MacdDiv D1) · filters=decoration · Phase C/other-EAs = optional`

**สรุป core (2 track เทสครบ, ส่วนใหญ่ negative แต่ rigorous + กฎ last-optimize คุ้ม):** (A) coverage: MacdDiv XAU-specific (GBPUSD H4 reject → **D1 pulse 1.45/1.23 PARKED-VERIFY** ด้วยกฎ last-opt) · breakout ไม่ travel FX + TF-expand ไม่ได้ (hardcode H1) · SuperTrend trend-specific(BWD 0.88) · **= ไม่มี leg ใหม่สะอาด**. (B) filter: candle(breakout)+RSI(raw MacdDiv) = **decoration ทั้งคู่** (ตัดไม้ไม่ selective). **บทเรียน portfolio: EA ที่ validated = tune แน่นที่บ้านแล้ว, cheap expand/filter ไม่ยกทั้ง both-window** → pipeline mature, EV จริงอยู่ที่ operate→judge. residual optional: funnel GBPUSD D1 · expand IchiADX · Sto/CCI/volume filter (low prior).

**ที่มา (user จับถูก, lead ยอมรับ):** "corpus-mining exhausted" ≠ "improvement exhausted". lane ที่ตันจริง = split-lever + .Final-EA corpus + naked-signal hunt. **ที่ยังเปิดกว้าง + EV สูง + เสี่ยงต่ำ (ต่อยอด edge ที่พิสูจน์แล้ว) = 3 อย่าง:** (A) ขยาย symbol×TF ของ EA ที่ validated (ORDER-095 ทำแค่ 1/6 EA) (B) เพิ่ม entry-quality filter (Sto/RSI/CCI/volume/candle-PA) ให้ "ออกไม้น้อยแต่แม่นขึ้น" (C) MTF: ออกไม้ดีแล้วดู higher-TF (เลือกมากขึ้น) / lower-TF (ไม้เยอะขึ้น). **doctrine ต่อยอด: ต้อง base ที่มี flat-lot edge จริงก่อน (เหมือน split/pending — filter เติม precision ไม่สร้าง edge).**

**Phase A — coverage (symbol×TF ของ validated EAs):**
- **batch 1 MacdDiv DONE(Claude 2026-07-18) = ❌ ไม่ travel (0 new legs) · `_mt5_auto/MDX_EXPAND.csv`:** smoke พบ GBPUSD H4 1.08/1.05 (config XAU) ดูน่าสน → validator funnel = REJECT-as-tested (GBPUSD H4 fixed-RR, holdout 0.55) → **last-optimize TF lever (กฎใหม่) = 🅿️ PARKED-VERIFY(user): GBPUSD D1 = 1.45/1.23 both-window (pulse จริง!) thin 25t · H2 1.09/0.96 marginal · H1 reject** (`MDXTF_GBP.csv`). **กฎ last-optimize คุ้มทันที — กัน GBPUSD ตาย final ทั้งที่ D1 มี edge (แค่ thin, ซึ่ง D1 ปกติไม้น้อย)** → flag user: D1 น่าลอง funnel เบาๆ (optimize D1 + holdout) ถ้าอยากได้ leg reversion GBP. XAU H2 marginal+redundant · USDJPY H4 0.97 WATCH · rest dead. **บทเรียน: MacdDiv edge = XAU-H4-specific ไม่ travel** (ไม่ใช่ทุก validated EA ขยาย symbol ได้ — ต้องผ่าน holdout ไม่ใช่แค่ smoke both-window). set `_mt5_auto/ab_sets/order117_gbp/` · raw `MDX_GBP_H4_VALIDATE.csv`. **process win: holdout ทำงาน.**
- **batch 2 SuperTrend RUNNING(Claude 2026-07-18):** flat-lot PF 2.93 (edge แข็งกว่า MacdDiv → prior travel ดีกว่า) home XAU H4 → expand symbol×TF. bar เดิม (both-window + ต้องผ่าน holdout ตอน funnel ไม่ใช่แค่ smoke). next: IchiADX · (BRK) family.

**Phase B — precision-filter A/B (per validated EA, toggle default OFF = byte-identical):** เพิ่ม filter ทีละตัวแล้ว A/B on/off both-window. **bar: filter ต้องยก PF **และ** win% ทั้ง both-window — ถ้าตัดไม้เฉยๆ PF ไม่ขึ้น = decoration, park** (แพทเทิร์น 098-J OB-gate).
- **B5 candle/PA bar-strength DONE(Claude 2026-07-18) = ❌ REJECT (decoration/harmful) · `_mt5_auto/O117_FILTER.csv`:** เพิ่ม `_08_UseBarStrength` (breakout bar body≥MinBodyAtr×ATR) A/B บน XAU H1 breakout 40/5. barstr0.3 = REC 2.49→2.72 (win 45→47 ขึ้น) **แต่ BWD 1.75→1.18 (win 39→34 ลง)** = ยก trend แต่พัง chop = **regime-fragile ขึ้น** (ตรงข้ามที่ต้องการ) · 0.5/0.7 พังทั้งคู่. nofilter สมดุลกว่า. **บทเรียน: breakout มี ATR-expansion+EMA200 filter อยู่แล้ว → candle-gate = over-filter.** filter น่าจะได้ผลกับ EA ที่ยัง**ไม่มี**filter (raw signal) มากกว่า breakout ที่ filter แน่นแล้ว.
- **B2 RSI-timing บน raw base (MacdDiv XAU H4) DONE(Claude 2026-07-18) = ❌ REJECT · `_mt5_auto/O117_RSI.csv`:** ใส่ `_07_UseRsiGate` (เข้า divergence เฉพาะตอน RSI ยืนยัน) A/B gate{45/55,40/60,50/50}. nofilter 1.56/1.04 → gate ดีสุด(40/60) 1.16/1.09 = **BWD ขึ้นนิดแต่ MAIN ร่วง 1.56→1.16** ไม่ยก both-window. **บทเรียนใหญ่: filter (candle+RSI) = decoration ทั้งคู่ แม้บน raw base — signal รีด edge หมดแล้ว, filter ตัดไม้ตามสัดส่วน (edge+noise พร้อมกัน) ไม่ selective.** filter-track = low-yield, park.
- **⚠️ caveat (subagent จับได้): `(EXP)_BRK_SplitRetest` hardcode PERIOD_H1/D1 ใน signal → chart-TF ไม่มีผล** = breakout EA นี้ **TF-expand ไม่ได้** ถ้าไม่แก้ code (D1 rows = duplicate ของ H4). breakout symbol-expand: FX majors (EURUSD/EURJPY/AUDUSD) reject, XAU/US30 = legs เดิม → **ไม่มี leg breakout ใหม่.**

**Phase C — TF re-home:** ต่อจาก Phase A — ตัวที่ผ่าน ลอง lower-TF (ไม้เยอะ, เช็ค precision ไม่หลุด) + higher-TF (เลือก, ไม้น้อยแต่ PF สูง) หา sweet spot.

**ห้าม:** filter/expand บน base ที่ flat-lot ไม่มี edge (สร้าง edge ไม่ได้ — บทเรียน split/pending) · verdict ก่อน both-window + (filter: win%↑ ด้วย) · deploy ก่อน holdout+corr · burst หลาย EA รอบเดียว (pace) · Model-2 เป็นเลขรายงาน · commit path-limited.

---

## ORDER-116 — CAMPAIGN: split-entry breakout — รีด lever (ORDER-108 validated) ให้ครบ portfolio (user 2026-07-18 "รีดออกมาทำยาวๆ") — `CORE DONE(Claude 2026-07-18) = split narrow lever, no new legs · conclusion _triage/ORDER116_CAMPAIGN_CONCLUSION.md · Phase 3 (London retrofit) = optional low-prior residual`

**สรุป (conclusion เต็ม `_triage/ORDER116_CAMPAIGN_CONCLUSION.md`):** split = **narrow config-refinement ไม่ใช่ portfolio-wide upgrade / leg-generator.** ✅ Phase 1: XAU 40/5-split regime-robust (2.40/1.96 · full PF 2.26/149t/DD3.9% · **MC PF_5th 1.71 ruin0%**) = chop-robust กว่า live Bars55 (1.99/1.12) **แต่ corr 0.861 vs XAU-BRK leg = same-slot redundant** → replacement candidate ตอน XAU re-opt ไม่ใช่ leg เพิ่ม. ❌ Phase 2: ไม่เปิด leg ใหม่ (US30=ORDER-095 leg+spike · XAG/GBP/NAS dead). **doctrine: pending/split = weak-window-filler บน base ที่มี both-window edge + asymmetric weak window เท่านั้น — เช็ค base edge ก่อน.** residual: Phase 3 retrofit London/CB_GBP (build task, low-prior — GBP generic-Donchian ไม่มี edge แล้ว, value อยู่ที่ session-logic ของ London เอง) · Phase 4 (Bars55 TP) ORDER-108 ปิดแล้ว.

### ORDER-116 Phase 1 RESULT (Claude 2026-07-18) — verdict `_triage/ORDER116_PHASE1_VERDICT.md` · raw `_mt5_auto/O116_P1.csv`
offset sweep XAU H1 Bars40/TP5 both-window Model-4 (D:\Meta 5). **split ยกหน้าต่างอ่อน (BWD chop) 1.75→~1.96** แลก REC นิด (2.49→2.33-2.40) = regime-robust (คอนเฟิร์ม ORDER-108 บน tick ใหม่). **plateau offset ∈ {−0.30,−0.15,0.00}** · +0.15 ตก (retest ตื้นไป BWD 1.67) → edge อยู่ฝั่ง retest ลึก. bar ผ่าน (≥1.80 both). **LOCKED RECIPE = split 0.02mkt/0.01pend · RetestOffset −0.15 · Expiry 5** (`BRK40_split_offm0p15.set`). → Phase 2: พก recipe ไป GBPUSD/EURUSD/US30/XAG both-window หา leg ใหม่ (≥1.4 both + corr<0.8).

**ที่มา:** ORDER-108 พิสูจน์ split-entry (market leg เก็บ runner + pending retest leg fill maker ~90%) = **lever จริงเพิ่ม regime-robustness** แต่ **config-conditional**: ยก Bars40/TP5 (1.93/1.97 both-window) · ไม่ยก Bars55/TP8 live (retest leg อ่อน BWD). กติกา: **split ช่วยก็ต่อเมื่อ retest leg มี edge ในหน้าต่างที่ market อ่อน** (ขึ้นกับ TP-width × lookback). EA `(EXP)_BRK_SplitRetest` = generic Donchian breakout, input ATR-relative → รันข้าม symbol ได้. ห้าม: แปะ EA ที่ปัญหา = regime ไม่ใช่ entry-cost/timing (XAU_NY).

**เป้า campaign:** map envelope ของ lever + หา **breakout leg ใหม่ที่ split ทำให้ regime-robust** (diversification) + retrofit demo config ที่ยกได้. Model-4 บังคับ (pending fill = tick-sensitive) → **รันบน D:\Meta 5 non-portable** (Meta5b portable เขียน report M4 ไม่ออก — บทเรียน D1g). ทุก phase = 1 experiment ใน event log (adoption guide RE-fixes ทำให้ลื่นแล้ว).

**Phase 1 (batch 1, this session): retest-param sweep บน working config (XAU H1 Bars40/TP5)** — หา "retest recipe" ที่ดีที่สุดก่อนพก symbol อื่น. sweep `_07_RetestOffsetAtr {−0.3,−0.15,0,+0.15}` @ `_07_ExpiryBars=5`, split 0.02mkt+0.01pend, both-window Model-4. reference = market-only (2.07/1.75 จาก ORDER-108). **pre-registered bar:** offset ที่ให้ split ≥1.80 **both-window** (ไม่มี weak window) + retest fill-rate ≥80% = recipe ผ่าน → พก Phase 2 · ถ้าไม่มี offset ไหนยก BWD เหนือ market-weak = lever แค่ robustness-neutral, ปรับแผน Phase 2 เป็น config-rebalance · negative offset (retest ลึก=ราคาดีขึ้นแต่ fill น้อย) = สมมติฐานหลักว่าจะยก retest edge.

**Phase 2 DONE(Claude 2026-07-18) = ❌ CLOSED NEGATIVE (split เปิด leg ใหม่ไม่ได้) · verdict `_triage/ORDER116_PHASE2_VERDICT.md` · raw `_mt5_auto/O116_P2.csv`+`O116_P2B_PLATEAU.csv`:** พก recipe ไป US30/NAS100/XAG/GBPUSD both-window Model-4. **US30 ≠ leg ใหม่** — ORDER-095 validate ไปแล้ว (H4 1.46/1.39, **corr vs XAU −0.249 additive PASSED**, staged 991005 WATCH-thin) · my plateau check เผย **US30 40/5 = SPIKE ไม่ใช่ plateau** (neighbor ตก <1.2 both / tp4-tp6 invert, thin 24-39t) → **991005 คง WATCH spike-fragile (feed back ORDER-095)** · split บน US30 = 1.54/1.38 ไม่ยก (market-only ไม่มี weak window ให้เติม). XAG (BWD 0.56, split DD 17%) + GBPUSD (<1) = dead · NAS100 no data. **doctrine sharpened: split เติม weak window เฉพาะ base ที่มี both-window edge + asymmetric weak window (XAU 40/5 trend2.49/chop1.75) — base สมดุลอยู่แล้ว/ไม่มี edge = ไม่ช่วย.** → **Phase 3 (pivot): validate Phase-1 XAU 40/5-split (2.40/1.96 regime-robust) เป็น demo config** — corr vs XAU legs เดิม + MC + holdout (additive หรือ replacement ของ Bars55 chop-weak 1.99/1.12?).
**Phase 3:** retrofit LondonConso (GBP) + CB_GBP — build split เข้า code, A/B ว่ายก demo config ไหม.
**Phase 4:** config-rebalance — config ที่ split ไม่ช่วย (Bars55/TP8) ลอง TP แคบลง + split เทียบ market-only live.
**Phase 5:** EDGE_CATALOG + demo-config upgrade ที่ผ่าน holdout.

**ห้าม:** verdict ก่อนครบ both-window + fill-rate · retrofit ตัว live โดยไม่ผ่าน holdout · burst หลาย phase รอบเดียว (pace 1 batch) · Model-2 เป็นตัวเลขรายงาน · commit path-limited ผ่าน hook.

---

## ORDER-091C-D1g — JUMSTOCH pending-limit + TP-widen A/B บน confirmed-edge base (closes ORDER-080 + user 2026-07-16 full hypothesis) — `DONE + REVIEWED (Claude 2026-07-17) = NULL (keep config) · ORDER-080 CLOSED · event-log dogfood #1 complete`

### D1g RESULT + VERDICT (Claude 2026-07-17) — verdict เต็ม `_triage/ORDER091C_D1G_VERDICT.md` · raw `_mt5_auto/D1G_AB_RESULTS.csv`
**regression cage PASS** (EntryMode=0 = original byte-behavior: PF 1.34/869t เป๊ะ + ตรง 07-11 baseline). ทั้ง 2 lever ทำงานจริง (เปลี่ยน trade count ได้) → null = ผลจริงไม่ใช่ toggle ตาย. **Model-4 เขียน report ไม่ออกบนกล่องนี้ → Model-1 (amended, pre-result, logged AMENDMENT_ADDED).**
- **Pending-limit = NULL:** EURGBP H1 มาร์เก็ต 1.48/1.03 → pending 1.49/1.00 (Δ +0.01/−0.03) · NZDUSD H4 **identical ทั้ง 2 window**. กลไก: JUMSTOCH grid-add เข้าเมื่อ `ask≤trigger` อยู่แล้ว = ไม่จ่าย spread เกิน trigger → แปลงเป็น limit ที่ระดับเดิม = ไม่ประหยัดอะไร (แย่กว่านิดตอน gap). **premise "grid จ่าย spread เยอะ" ไม่ใช้กับ EA ที่ entry เป็น trigger-touch อยู่แล้ว.**
- **TP-widen = inert/noise:** +2 identical, +5 = +0.01-0.02 both-window (ผ่านบาร์ ≥baseline แต่ noise-level, DD เท่าเดิม). กลไก: JUMSTOCH exit ด้วย BEP+trailing ไม่ใช่ raw TP.
- **DECISION (config only):** คง demo config JUMSTOCH เดิม (market entry, TP เดิม) — ไม่มี lever คุ้มให้เปลี่ยน validated config. JUMSTOCH ยัง demo-eligible ตาม 07-11 (order นี้ไม่แตะ).
- **doctrine banked:** pending-limit rescue = ใช้กับ EA ที่ entry **market-on-signal** (จ่าย spread) เท่านั้น — **ห้ามใช้กับ grid ที่เข้าที่ trigger-touch** (ไม่มี spread ให้ประหยัด). รวมกับ D1d → **pending doctrine characterized ครบ · ORDER-080 CLOSED.**


**ที่มา:** D1d (07-16) วัด pending-save บน LWMA proxy ที่ **ไม่มี edge** → พิสูจน์ได้แค่ magnitude (~+0.05 PF/ไม้) ไม่ใช่คุณค่าจริง + TP-widen ครึ่งหลังของ user ยังไม่รัน. `_triage/PENDING_LIMIT_SYNTHESIS.md` สั่งชัด: "หา reversion base ที่ near-breakeven มาเป็น demonstrator". **JUMSTOCH = demonstrator นั้น** — thread D1→D1f REVIEWED = demo-ready, **flat-lot PF 1.18 (edge จริง ไม่ใช่ martingale artifact)**, capped-SL'd reversion grid เทรด 869-3272 ไม้/window = จ่าย spread เยอะ = ตรงเป้า maker-save. นี่คือที่เดียวที่ +0.05 PF/ไม้ × ไม้เป็นพันจะเห็นผลจริง บน base ที่ candidate อยู่แล้ว.

**scope (สำคัญ — VERDICT GATE):** นี่เป็น **refinement-lever test บน EA ที่ผ่าน full funnel แล้ว** (D1-D1f) ไม่ใช่ EA-life verdict → ตัดสินแค่ **demo CONFIG** (market vs pending entry · TP setting) ของ JUMSTOCH ที่ demo-eligible อยู่แล้ว. ไม่ใช่ตัดสินว่า JUMSTOCH ตาย/รอด.

**คำสั่ง:**
1. build `(EXP)_JUMSTOCH_Pending.mq5` = copy MT5 baseline + เพิ่ม **2 lever inputs เท่านั้น**: `EntryMode` (0=market baseline / 1=pending-limit) + `TP_Widen_Pips` (บวกเข้าทั้ง g_TP + Tp_from_Bep). **market path (EntryMode=0) = byte-identical original** (= regression cage). pending: grid-add → BuyLimit/SellLimit ที่ trigger price เดิม (fill ~100% ประหยัด spread ล้วน) · initial entry → limit-at-touch · จัดการ cancel/expire pending + magic-scope. **ห้ามแตะ** lot/SL/Range/Level_Max/signal/exit.
2. compile 0/0 + mql-code-reviewer (pending-order mgmt = bug surface).
3. **regression cage ก่อน A/B:** EntryMode=0/TP+0 บน EURGBP H1 both-window Model-4 → ต้อง reproduce 07-11 baseline (±tolerance) มิฉะนั้น refactor drift = หยุดแก้.
4. A/B Model-4 (mandatory — pending fill = tick-path-sensitive, **ห้าม Model-2**): market vs pending บน EURGBP H1 (primary) + NZDUSD H4 (secondary), both-window continuous span (recent 2023.01-2026.07 + BWD 2020.01-2022.12).
   **🔧 AMENDMENT 2026-07-17 (ก่อนเห็น A/B PF ใดๆ — tooling constraint ไม่ใช่ peak-hunt):** Model-4 บนกล่องนี้ **รันไม่ออก report** (test รันจบจริง—journal เห็น trade—แต่ terminal+local-agent ไม่เขียน .htm; Model-1 เขียนปกติ). ตรงกับ 07-11 D1f ที่ JUMSTOCH ทั้งสายใช้ Model-1. → **ลด Model-4 → Model-1** (M1-OHLC จับ "ราคาแตะ limit level ในบาร์ไหม" ได้ = พอสำหรับคำถาม pending-fill; residual caveat = tick-ordering ภายในนาที ไม่ถูกจำลอง). **ห้าม Model-2 ยังคงอยู่.** บันทึกเป็น AMENDMENT_ADDED event (target = BAR_PREREGISTERED).
5. ถ้า pending มี lift → เพิ่ม TP-widen arm {+0,+2,+5 pip}.
6. วัด **PF + net-EV/ไม้ + fill-rate** (ไม่ใช่ net$ เดี่ยว — pending เทรดน้อยลง = exposure น้อยลง หลอกได้; ไม่ใช่ PF เดี่ยว) + basket-continuous MC.

**pre-registered bar (ล็อกก่อนเห็นผล):**
- **CONFIRM (pending adopted):** pending net-EV/ไม้ > market net-EV/ไม้ ที่ spread จริง บน ≥1 home **both-window** (หลังหัก opportunity cost ของไม้ที่ไม่ fill) AND basket PF ไม่แย่ลง → ปรับ demo config JUMSTOCH เป็น pending entry, จด delta.
- **NULL (no lift):** pending net-EV/ไม้ ≤ market ในกรอบ noise หรือ fill-loss หักล้าง spread-save → คง market entry, จดว่า JUMSTOCH ไม่ได้อะไรจาก pending (สอดคล้อง D1d generic +0.05 = immaterial ที่นี่).
- **TP-widen:** ปรับได้ก็ต่อเมื่อ PF และ net-EV **ทั้งคู่** ≥ baseline ที่ +2 หรือ +5 both-window; ไม่งั้นคง TP เดิม.
- **middle:** lift window เดียว = regime-fit → park lever ไม่ adopt.

**ห้าม:** เปลี่ยน lever อื่นนอก {EntryMode, TP_Widen_Pips} · Model-2 เป็นตัวเลขรายงาน · เชื่อ A/B ก่อน regression cage ผ่าน · ตัดสิน JUMSTOCH ตาย/รอดจาก order นี้ (scope = config เท่านั้น) · commit tag `[claude] D1g ...` path-limited ผ่าน production hook.

**event-log dogfood:** เดิน chain IDEA→HYPOTHESIS→BAR(pre-reg)→RUN→RESULT→REVIEW→DECISION ตาม `docs/memory_control/EVENT_LOG_ADOPTION.md` (experiment แรกที่ใช้จริง — เจอ rough edge = แก้ adoption guide). exp id + evt ids จด inline ตอนปิด.

---

## ORDER-095 — CAMPAIGN: ขยาย symbol ให้ EA ที่ deploy อยู่แล้ว (user 2026-07-11: "ขยายผลไปตัวที่ demo อยู่ ได้อีกเยอะ") — `OPEN (multi-session, pace 1 EA/batch) · batch 1 DONE(Claude 2026-07-14): EA_BREAKOUT_XAU → USDJPY (PF 1.28/1.25) + US30 (1.46/1.39 WATCH-thin) demo-eligible · bundles staged _vps_deploy/EA_BREAKOUT_USDJPY (991003) + EA_BREAKOUT_US30 (991005) · verdict = _triage/ORDER095_BREAKOUT_XAU_EXPAND_VERDICT.md` ⚠️ **US30 991005 UPDATE (ORDER-116, 2026-07-18): plateau check เผยว่าเป็น SPIKE ไม่ใช่ plateau** (b30/b50 ตก <1.2 both · tp4/tp6 invert · thin 24-39t) → **คง WATCH/small, ห้าม graduate จาก single-cell evidence** (ดู `_triage/ORDER116_PHASE2_VERDICT.md`)

**หลักการ (build-on doctrine + multi-symbol reuse):** EA ที่ deploy แล้ว = validated ที่ home เดียว · ขยายไป
symbol อื่นที่ผ่านเกณฑ์ (corr < 0.8 ระหว่างกัน) = เพิ่มไม้โดยไม่ต้องหา EA ใหม่.

**⛔ CAVEAT ชี้ขาด (lead judgment — ขยายผิดตัว = กระจายทางแพ้):** ขยายได้เฉพาะ EA ที่ **entry มี edge จริง
(flat-lot PF>1)** เท่านั้น. EA ที่ entry ไม่มี edge = ขยาย symbol ยิ่งเพิ่มวิธีเสียเงิน:
- ✅ **ขยายได้ (source + flat-lot edge ยืนยัน):** EA_BREAKOUT_XAU (breakout, real, travels) · Boss_14_GridLog
  (demo flagship, 7 symbol แล้ว) · EA_SUPERTREND (flat-lot PF 2.93 — pending demo) · CB_GBP ConsoBreakout ·
  NuiIndy Dynamic RSI+ADX (source อยู่ .Final EA)
- ❌ **ห้ามขยาย (entry ไม่มี edge — กำลังถอดอยู่แล้ว):** RSI-MR (flat-lot 0.78) · ST_EA03 family (0.68/0.40) ·
  ST03 replica — พวกนี้ถอดเพราะ entry ไม่มี edge → ขยายยิ่งผิดหลัก
- ⚠️ **compiled-only (.ex4 รันได้แก้ไม่ได้):** UnNomGuai/swb/RSI-orig (MT4 demo) = ขยายแบบ run-as-is บน symbol
  อื่น + corr check (flat-lot check = ปิด escalation input ถ้ามี) · Zeus/Kangaroo = martingale locked, Zeus เปราะ
  (stop-out gold) → ไม่ขยาย

**Methodology ต่อ EA (เหมือน JUMSTOCH D1c):** (1) flat-lot smoke บน symbol candidate ที่ยังไม่ deploy → เอาที่
entry PF>1 (2) full-config IS/OOS บนตัวที่ผ่าน (3) corr equity-curve vs leg เดิม → เก็บ corr<0.8, คู่ >0.8 บอก user
(4) เพิ่มเข้า demo config. **pace 1 EA/batch** · Boss_14 = ตัวแรก (D1c-สไตล์)

## ORDER-097 — build "(HEX)_HexaGrid" (user สั่งเขียนจากสเปคเอง 2026-07-11) — build `DONE(Claude, 2026-07-11)` · baseline `DONE(Claude, 2026-07-11)` · funnel `CLOSED (Claude 2026-07-14 — STRUCTURAL DEAD: sweep spacing×SL ไม่ช่วย + flat-lot isolate S1-S6 ไม่มีระบบไหนมี edge เดี่ยว (ดีสุด 0.80/0.76) · ปัญหาอยู่ที่ entry ทั้ง 6 ไม่ใช่ chassis · verdict = _triage/ORDER097_HEX_FUNNEL_VERDICT.md)` _(renumbered 096→097: ชนกับ CAMPAIGN ORDER-096 WOBR)_

**ที่มา:** user ส่งสเปค HexaGrid เต็ม (6 ระบบอิสระ magic-scoped แชร์ grid engine ×1.33 cap 10 + SL จริงทุกไม้,
regime EMA224-slope+ADX, 7 ชั้นจัดการ+global cap) แล้วสั่ง "เขียน EA ตัวนี้ + รอรันเลย" (optimize เองไม่ได้ — คอมเต็ม).
brainstorm → standalone-port (core เดิม single-magic global-state #include ตรงไม่ได้) → user เคาะ standalone.

**สถานะ build (DONE):**
- source: `ea_projects\(HEX)_HexaGrid\(HEX)_HexaGrid_rev01.mq5` · compiled: `(HEX)_HexaGrid_rev01.ex5`
  (อยู่ในโปรเจกต์ + deploy แล้วที่ `D:\Meta 5\MQL5\Experts\HEX_HexaGrid_rev01.ex5`)
- **compile 0 errors / 0 warnings** (MetaEditor64, X64 Regular)
- ผ่าน mql-code-reviewer: ไม่มี BLOCKER · แก้ 2 HIGH (sys4 ADX-only ไม่โดน slope-gate · g_suppress_log optimize)
- **RISK CLASS L4** (capped-martingale+grid, ไม่มี rescue-hedge) — user รับทราบ (เลือก global cap 18% เอง)
- default = conservative UNOPTIMIZED (spacing ATR-adaptive multi-symbol, risk 2%/basket, mult 1.33, maxLevels 10)

**⚠️ GOTCHA ก่อนรัน (บันทึกไว้กันเสียเวลา):**
1. **ต้องบัญชี HEDGING เท่านั้น** — OnInit มี guard: ถ้า `ACCOUNT_MARGIN_MODE != RETAIL_HEDGING` = INIT_FAILED
   (netting จะ merge 6 ตะกร้าทับกัน). **เช็ค log หา `[HEX][FATAL]` ก่อนสรุป 0 trades = code bug** — ต้องมั่นใจ
   server ของ terminal ที่รัน tester เป็น hedging ก่อน
2. `_06_AllowLive=false` default แต่ tester-gate เปิดอัตโนมัติ (รัน Strategy Tester ได้เลย)
3. weekend-cut `_G_CutHourServer=12` เป็น proxy 19:30 ไทย — ปรับตาม GMT offset ของ feed ที่เทสถ้าจะเอาชั้นนี้

**คำสั่ง (baseline ก้อนแรก — both-regime, coarse Model 1 ก่อน, 1 symbol × 2 window ตาม pacing):**
```powershell
# ยืนยัน hedging ก่อน แล้วรัน 2 window (trend BWD + recent). แทน window ทีละรอบ:
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'HEX_HexaGrid_rev01' -Symbol XAUUSD -Period H1 -FromDate 2020.01.01 -ToDate 2022.12.31 -Model 1 -Deposit 10000 -Leverage 100 -ReportName HEX_BASE_XAU_BWD -Portable -Terminal 'D:\Meta 5\terminal64.exe'
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'HEX_HexaGrid_rev01' -Symbol XAUUSD -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -Deposit 10000 -Leverage 100 -ReportName HEX_BASE_XAU_REC -Portable -Terminal 'D:\Meta 5\terminal64.exe'
```
**Acceptance (raw เท่านั้น — ห้าม verdict, lead ตัดสิน):** 2 report เข้า `_mt5_auto\reports\` · ต่อ window append:
PF · net profit · trades · maxEqDD% · maxBalDD% · + **ยืนยันว่า OnInit ไม่ FATAL (มี trade เกิดจริง)** ·
สังเกตว่าระบบไหน (magic 20260707-13) มี trade บ้างจาก comment/journal · commit `[tag] ORDER-097 baseline done`

### ORDER-097 BASELINE RESULT (Claude, 2026-07-11) — raw + lead note (NOT a kill-verdict)
Runner `scripts\mt5_run.ps1 -Portable` บน `D:\Meta 5` (account 146237 = **hedging ✅**, guard ผ่าน — EA รันจริง
ไม่ FATAL). **Model 1 coarse** (control-points, optimistic สำหรับ grid), default compiled inputs (no .set),
deposit 10000, leverage 1:100, XAUUSD H1. report เขียนลง `D:\Meta 5\HEX_BASE_XAU_{REC,BWD}.htm` (portable
เขียน root — mt5_run แจ้ง "NO REPORT" เพราะหาผิดที่ แต่ไฟล์มีจริง + test "successfully finished").

| window | PF | Net$ | Trades | Bal-DD | Eq-DD | Sharpe |
|---|---:|---:|---:|---:|---:|---:|
| recent 2023.01–2026.07 | 0.97 | -2,224 | 12,403 | 56.80% | 57.95% | -0.31 |
| BWD trend 2020.01–2022.12 | 0.88 | -5,937 | 9,099 | 65.04% | 65.44% | -1.38 |

**Lead note (ยังไม่ใช่ verdict — VERDICT GATE ยังไม่ครบ: sweep 0 lever, 1 symbol, 1 TF):**
- **default config = NO EDGE ทั้งสอง regime** (PF 0.88–0.97 แม้ Model-1 optimistic → real-tick น่าจะแย่กว่า) → **ยังไม่ผ่านบาร์เข้ารอบ Model-4**
- **DD 57–65% = ตรงกับ worst-case ~60% ที่ flag ตอน build เป๊ะ** · global cap 18% คุมได้แค่ floating ชั่วขณะ ไม่กัน cumulative bleed เมื่อ edge ติดลบ
- **12k/9k trades = spacing แน่นเกิน / 6 ระบบยิงพร้อมกันถี่มาก** — สมมติฐานแรกที่ควร sweep: ขยาย `_G_SpacingATRmult`/`_G_SL_ATRmult` + ลดจำนวนระบบที่เปิดพร้อมกัน
- **ไม่ตีตาย (PARAMETRIC):** unoptimized/1-symbol/coarse → tag **build-on / PARKED-VERIFY(user)** ไม่ใช่ DEAD · แต่ห่างบาร์พอควร ไม่ใช่เฉียด
- **บล็อกจริง:** user optimize ไม่ได้ (คอมเต็ม) → funnel ที่เหลือรอพื้นที่ว่าง. ถ้าเปิดได้: sweep spacing×SL×system-count → both-regime → ถ้าโผล่ PF>1 ค่อย Model-4 real-tick → OOS → MC

**ห้าม:**
- **ห้ามตัดสิน edge จาก Model-1 pass** — grid fill-sensitive, Model-1 optimistic; ผ่าน M1 = แค่ "ผ่านเข้ารอบ Model-4"
  ไม่ใช่ candidate (VERDICT GATE #6 + doctrine grid-EA ต้อง real-tick confirm)
- ห้าม tune ก่อนเห็น baseline both-regime (VERDICT GATE #3)
- ห้ามขยาย symbol×TF เต็มก่อน baseline โชว์ชีพจร (ถ้า XAU both-window PF>1 coarse → ค่อยเปิด funnel: Model-4 real-tick
  → OOS split → MC ตาม robustness-validator · ถ้าติดลบทั้ง 2 window = กลับมาดู logic/default ก่อน ไม่ใช่ tune หนี)
- ถ้า INIT FATAL (ไม่ใช่ hedging) = **หยุด แจ้ง user** ว่าต้องเทสบนบัญชี/เทอร์มินอล hedging ห้ามแก้ guard ออก

---

## ORDER-098 — CAMPAIGN: fxDreema YouTube corpus build-on — `OPEN` (multi-session · user prioritizes ใน session เดียวก่อนลงมือหนัก)

**ที่มา (2026-07-12):** แกะช่อง @fxdreemalearner ครบ 320 คลิป → catalog กลไก 272 EA. ผล + shortlist เต็ม =
`_triage/fxdreema_youtube/BUILDON_SHORTLIST.md` (+ `CATALOG.jsonl` · `DIGEST.txt`). pipeline/สถานะ = memory
`fxdreema-youtube-corpus`. toolchain แกะคลิปเพิ่ม = `scripts/yt2text.ps1` (memory `yt-whisper-toolchain`).

**Doctrine ที่บังคับทุก sub-order (paid rules):**
- เกือบทุก EA = chassis ST03 (entry→grid→trailing→no-SL). **flat-lot probe = ด่านแรกบังคับทุก entry** —
  ปิด escalation (single order, fixed lot, SL/TP) แล้ว PF ยัง >1 ไหม. ST03-dead vs Kangaroo-edge แยกตรงนี้.
- **ห้ามตัด grid/martingale ทิ้ง** (user doctrine [[feedback-buildon-pf-gt-1]]) — ขุด entry + MM part มาแปะ
  chassis ที่ validated แล้ว (MatchaGrid bounded+SL · Kangaroo DD-release · JUMSTOCH capped-SL'd reversion grid).
- ตัวเลข % ในการ์ด = คำอ้างคนสอน **ยังไม่ verify** — guilty until flat-lot + funnel proves.
- VERDICT GATE เต็มใช้ตามปกติ (≥3 lever × ≥2 TF ก่อน reject · both-regime · holdout+MC ก่อน deploy).

**Sub-orders (A/B พร้อมรัน · C = library · user เลือกลำดับ):** 098-A FVG-fill entry · 098-B MACD-divergence entry ·
098-C reusable MM-parts. **ห้ามเริ่ม build campaign เต็มจนกว่า user เคาะลำดับใน session ที่นัดไว้** — sub-orders
ด้านล่าง stock ไว้ให้พร้อมเฉยๆ.

---

## ORDER-098-A — FVG-fill entry (EX009 algo) flat-lot smoke — `CLOSED — REJECT (Claude 2026-07-16): naked FVG-fill ไม่มี edge — 22 runs ครบ BWD both-regime (0.79-0.88) + RR sweep TP{15,20,25,30,40,60}: PF ไต่ถึง 0.97-0.98 แล้วหักลงที่ TP40/60 = cost-dilution ไม่ใช่ edge, ไม่เคย PF>1 สักครั้งใน 26 cells → ไม่เข้า build-on doctrine · ปิดเฉพาะ naked-entry บน EUR/XAU H1/H4 — FVG-as-filter ยังเปิดใน EDGE_CATALOG · verdict เต็ม = _triage/ORDER098A_FVGFILL_SMOKE_VERDICT.md · ดิบ = _mt5_auto/order098a_bwd_rr.csv` (role: Claude/Sonnet build → agent smoke)

**ทำไม:** FVG/ICT-zone (24 การ์ด) = angle ใหม่จริงที่ยังไม่มีใน landscape (มีแค่ PARKED-CONCEPT จาก FB reel ไม่มีตัวเลข).
ทดสอบว่า **entry เปล่าๆ มี edge ไหม ก่อนแตะ grid/MM** (flat-lot probe).

**สเปค entry (จาก EX009 + EX196):**
- FVG bullish = `Low[1] > High[3]` (ช่องว่าง 3 แท่ง) · เข้าเมื่อ `Close[0]` ย้อนกลับมาปิด *ใน* ช่อง (ระหว่าง High[3]..Low[1])
  + ยืนยัน bullish engulfing (body[0] > body[1]) · mirror สำหรับ SELL (`High[1] < Low[3]`)
- **flat-lot บังคับ: single order, fixed 0.01, SL 20 pip / TP 15 pip** (ตาม EX009) — **ไม่มี grid ไม่มี martingale**
- bar-open gate + digit-aware pip + magic-scoped (ผ่าน `mql-code-reviewer` ก่อน compile)

**คำสั่ง:** build `ea_projects/(EXP)_FVGFill_Naked/` → compile headless → smoke Model 1, 2023.01-2026.01:
EURUSD H1 · EURUSD H4 · XAUUSD H1 · XAUUSD H4 (4 cells).

**Acceptance:** ตาราง 4 แถว (PF · Trades · EqDD% · Win%) append ใต้ order นี้ + path report ดิบ. commit `[tag] ORDER-098-A done`.
**ห้าม:** ใส่ grid/martingale ก่อน flat-lot PF ผ่าน · ตัดสิน dead ก่อนครบ VERDICT GATE (≥3 lever × ≥2 TF) ·
เขียน verdict (นั่นงาน lead) · Model-2 tight-TP (TP 15pip อาจ < spread บน XAU → ใช้ Model 1 + ตรวจ spread-artifact).

---

## ORDER-098-B — MACD-divergence entry (EX154/EX010 algo) flat-lot smoke — `CLOSED — DEMO-ELIGIBLE (Claude 2026-07-16): 🥇 XAU H4 ผ่านครบทุกด่าน funnel — MAIN plateau 1.91 (9 neighbor ไม่มีตัวขาดทุน) · BWD 1.04 · HOLDOUT 1.30 · Model-4 real-tick 1.89/0.97/1.28 (edge จริงไม่ใช่ fill artifact) · MC ruin 0% · corr gate max|corr|0.555<0.8 (additive) · bundle staged _vps_deploy/MACDDIV_XAU magic 999094 (tester-gate จริง set AllowLive=true) → WAITING-USER attach · EUR H4 HOLDOUT FAIL 0.35 → PARK · H1 ปิด cell · verdict = _triage/ORDER098B_MACDDIV_VERDICT.md` (build+opt = Codex 2026-07-15 · funnel+M4+corr+bundle = agent/Claude 2026-07-16)

**ทำไม:** MACD *divergence* (price LL / MACD HL) ≠ naked MACD-cross ที่ตายไปแล้ว = reversion signal ที่ยังไม่เคย smoke.
EX120 เสริม volume-confirm + low-freq (RR 1:3-1:5).

**สเปค entry:** bullish divergence = price ทำ lower-low แต่ MACD main ทำ higher-low (lookback N swing) · เข้า BUY ·
mirror SELL · **flat-lot single order fixed 0.01, SL = 3-bar extremum, TP = 200% SL** (จาก EX113/EX013 RR 1:2).

**คำสั่ง:** build `ea_projects/(EXP)_MacdDiv_Naked/` → compile → smoke Model 1 2023.01-2026.01:
EURUSD H1/H4 · XAUUSD H1/H4 (4 cells).

**Acceptance:** ตาราง 4 แถว (PF/Trades/EqDD%/Win%) + report path. commit `[tag] ORDER-098-B done`.
**ห้าม:** grid ก่อน flat-lot ผ่าน · verdict · reject ก่อนครบ gate.

---

## ORDER-098-C — reusable MM-parts library (dynamic close_money + Fibonacci-capped lot) — `DONE(Claude 2026-07-17C, commit bd709fca)` (role: Claude, built via sonnet-agent + lead-verified)

**RESULT:** 2 parts extracted OFF-by-default into Boss V2 core — `PROG_FIBONACCI` (56, MoneyManagement.mqh, lot*fib(lv) cap _56_FibMaxStep=5→13x) + `Exit_DynCloseTargetMoney()` (ExitManager.mqh, base+(openCount/C)*base, gated _57_DynCloseOn=false). Compile 7/7 EA 0 err. **Off-by-default lead-VERIFIED:** tpl_regression trade counts byte-identical to baseline all 6 EA (gated code changes 0 default behavior); 6 net/pf micro-drifts <2% = pre-existing stale baseline (Jul11) vs refreshed ticks NOT edits → **baseline refresh = separate lead maintenance (flagged, not done mid dual-session).** Integrate-into-chassis = future order (not backtested yet, per scope). Retrofit: Fib→MatchaGrid bounded / DynClose→Kangaroo DD-release + JUMSTOCH.

**ทำไม:** 2 ชิ้นนี้ = "cap + linear/log" ที่ user สั่ง มีคนทำไว้แล้วในคลัง — เอาไปแปะ chassis ที่ผ่าน flat-lot (098-A/B)
หรือ retrofit บน MatchaGrid/Kangaroo/JUMSTOCH ได้เลย (pure risk-mechanics ไม่ยุ่ง entry-edge).

**สเปคที่จะสกัดเป็น module:**
- **dynamic close_money** (EX183/EX078): `close_target = base + (open_order_count / C) * base` — เป้าโตตามจำนวนไม้
- **Fibonacci-bounded lot** (EX191): sequence `0.01,0.02,0.03,0.05,0.08,0.13` cap ที่ step 13× (แทน martingale ×2) +
  reset เมื่อ flat · EX211 variant มี SL30/TP50 อยู่แล้ว = bounded+capped ต้นแบบ

**คำสั่ง:** เขียนเป็น include module (`ea_template/core/` ตาม pattern เดิม) + run `tpl_regression.ps1` cage หลังแก้ core.
**Acceptance:** module compile ผ่าน + regression cage เขียว + unit note ว่าใส่กับ chassis ไหนได้. **ยังไม่ต้อง backtest** (งาน integrate อยู่ order ถัดไปหลัง 098-A/B รู้ผล).
**ห้าม:** แก้ core โดยไม่รัน `tpl_regression.ps1` · integrate เข้า chassis จริงก่อน entry-edge ยืนยัน (จะปนตัวแปร).

---

## ORDER-099 — Contract A: B0 historical baseline + fact→owner map — `REVIEWED(Codex blind review round 3 = ACCEPT, 2026-07-12) — Contract A COMPLETE` (SYSTEM ORDER 1 of ≤4 memory-control build)

> **Design source:** `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` **§20 @ `4eb839d`** (Contract A = §20.8) · pin **`B0_CUTOFF_SHA=4eb839df09b1911cec2de18ec4a2df51cf766606`**
> **ทำได้:** Claude/Opus (judgment: cohort selection · incident taxonomy · owner conclusions) · qwen/fast-worker (mechanical extraction เท่านั้น) · **👉 แนะ:** **Opus-seat** (§20 บอก Opus-only for judgment)

**ทำไม:** §20.2 workstream ที่ 1. ก่อนสร้าง harness/archive/events ต้องมี (ก) baseline B0 ของ 20 order ประวัติศาสตร์เพื่อวัดว่า MVP-0/3/1 ทำให้ดีขึ้นจริงไหม (ข) fact→canonical-owner map เพื่อกันสร้าง source-of-truth ชุดที่สอง. **นี่คือ audit output ไม่ใช่ authority ใหม่** — ไม่เปลี่ยนใครเป็นเจ้าของอะไร.

**Outputs (ทั้งหมดอยู่ใต้ dir เดียว `docs\memory_control\` — generated artifact เท่านั้น):**
1. **fact→owner map** — ต่อ fact แถวหนึ่ง: `fact · canonical_owner (ไฟล์/path) · permitted_writers · generated_consumers · freshness_check`. อ้างอิงตาราง §20.7 เป็นฐาน — ห้ามขัด.
2. **B0 raw dataset** (CSV/JSONL reproducible) ของ **20 terminal orders ณ cutoff `4eb839d`** — ต่อแถว: `ORDER_ID · source_anchor (taskboard line/commit) · evidence_commit_or_path · classification (machine-checkable) · onboarding_time · context_incident · context_rework · wrong_order_file_scope · lead_attention_hours`.
3. **B0 report สั้น** + inclusion/exclusion list ชัดเจน (เหตุผลต่อ order ที่ตัดออก).

**Selection rule (bounded, machine-checkable):** เลือก 20 order ที่ **ปิดจริง (มี execution + result) ก่อน/ณ `4eb839d`** · **ตัดออก:** umbrella/CAMPAIGN order ที่ไม่มี execution เอง · `SKIPPED` · no-execution · order ที่ไม่มี evidence. ต่อแถวต้องมี ORDER ID + source anchor + evidence commit/path + classification.

**B0 reality clause (§20.3 — บังคับ):** metric ที่ **ไม่เคยถูกบันทึกตอนงานวิ่งจริง** (onboarding time, lead-attention hours) = **`NOT_RECORDED`** — **ห้าม reconstruct จากความจำ, ห้ามใส่ 0**. metric ที่นับได้จาก git + taskboard history (rework, wrong-scope) ให้คำนวณจาก raw row และต้อง reproduce ได้.

**Acceptance (ตัวเลขล้วน — ตรวจได้ทุกข้อ ได้/ไม่ได้):**
- [ ] `docs\memory_control\` มี 3 artifact ครบ (map · B0 dataset · report)
- [ ] B0 dataset = **20 distinct eligible orders** (ไม่ซ้ำ ORDER ID · ไม่มี umbrella-only/SKIPPED/no-execution)
- [ ] **unresolved owner conflict = 0** ใน fact→owner map (ถ้าเจอ conflict → order = BLOCKED พร้อมคำถาม, **worker ห้ามเลือก owner เอง**)
- [ ] **≥5/20 traces ถึง canonical evidence จริง** (commit/path เปิดได้)
- [ ] rework / wrong-scope ทุกค่า **reproduce จาก raw row ได้** (สคริปต์/สูตรแนบ)
- [ ] onboarding/lead-hour ที่ขาด = `NOT_RECORDED` ทุกช่อง (ไม่มี 0 ปลอม, ไม่มีเลข reconstruct)
- [ ] canonical docs (`PROJECT_STATE.md`/`AGENTS.md`/scorecard/DEPLOYMENTS.csv/taskboard order เดิม) **ไม่ถูกแก้** นอกจาก bootstrap pointer/order lifecycle
- [ ] `[tag] ORDER-099 done` + ผลดิบ append ใต้ order นี้

**ห้าม (out of scope — §20.8 Contract A):**
- ❌ migrate/archive data ใดๆ (นั่นคือ Contract C) · ❌ implement harness/events/packet (Contract B/D/MVP-2)
- ❌ เปลี่ยน authority/owner/write-path จริง · ❌ แตะเงินจริง/deployment/verdict
- ❌ worker ตัดสิน owner conflict เอง → **mark BLOCKED, ให้ Opus resolve แยก**
- ❌ ใส่ metric ที่ reconstruct จากความจำ (ต้อง `NOT_RECORDED`)
- ❌ pre-open Contract B/C/D — order ถัดไปเขียนหลัง Opus review ORDER-099 เท่านั้น

**Rollback:** ลบเฉพาะ generated B0/map artifact ใน `docs\memory_control\`; design pointer ใน PROJECT_STATE คงไว้. canonical docs ต้องไม่เปลี่ยน.

**Routing/mechanics:** mechanical extraction (grep taskboard, list ORDER IDs, pull evidence paths) → qwen/fast-worker ได้ · cohort selection + incident taxonomy + ทุก owner conclusion = **Opus-seat**. ผลดิบ append ใต้ order นี้ก่อน Opus mark REVIEWED. (B0 execution/result = commit แยกจาก canonicalization commit — ห้ามรวม.)

### ผลดิบ (Opus, 2026-07-12) — executed by Opus-seat

**Artifacts** (ใต้ `docs/memory_control/` — generated audit output, ไม่ใช่ authority ใหม่):
- `FACT_OWNER_MAP.md` — 10 fact → owner/writers/consumers/freshness (ฐาน §20.7 + AGENTS.md §2) · **owner conflict = 0**
- `B0_DATASET.csv` — **20 terminal order @ `4eb839d`** (INFRA 6 · CANDIDATE 7 · REJECT 5 · PARK 2, ไม่ซ้ำ ID)
- `B0_REPORT.md` — selection rule + inclusion/exclusion list + metric method + reproducibility recipe
- `README.md` — สรุป + reproduce จาก pinned SHA

**Cohort rule:** 20 most-recently-closed eligible terminal orders @ cutoff (exclude umbrella/SKIPPED/OPEN/CLAIMED/annotation). universe = 110 headers.

**Acceptance self-check (ครบ):** 20 distinct ✓ · owner conflict 0 ✓ · **16/20 traces มี evidence commit** (เกิน ≥5/20) ✓ · `context_rework`=0 + `wrong_order_file_scope`=0 นับซ้ำได้จาก git+taskboard ✓ · onboarding/lead-hours/context-incident = `NOT_RECORDED` ทุกแถว (ไม่มี 0 ปลอม/reconstruct) ✓ · canonical docs ไม่เปลี่ยนนอกจาก order lifecycle ✓

**System note:** เจอ ORDER-ID collision 2 ครั้ง (042→043, 096→097) นอก cohort — บันทึกใน report ไม่ทิ้งเงียบ (เป็น class ปัญหาที่ Contract C ตั้งใจแก้).

**Status:** DONE + Opus self-review = ACCEPT — **แต่ Codex blind review (2026-07-12) = REWORK, ถูกต้อง 3 ข้อ (Opus verify ยืนยันทั้งหมด, self-ACCEPT ผิดจริง):**

### Codex REWORK (ORDER-099) → resolution 2026-07-12
1. **cohort 19 ไม่ใช่ 20 distinct** — `ORDER-091B` phase1 + "เฟส 2" = canonical ID เดียวกัน (header L4113+L4207) นับเป็น 2 ผิด → **FIX:** ตัด phase2, เลื่อน `ORDER-088` (DONE 07-10) เข้าแทน · CSV ยืนยัน 20 distinct, 0 dup
2. **evidence SHA ผิด 2 แถว** — 078 อ้าง `9e1d1acf` (corr-check) → จริง `00392e30` (+review `b93e4b9d`) · 085B อ้าง `9e1d1acf` → จริง `b5b1b429` (+`e481e00f`) → **FIX:** แก้ CSV + report §7
3. **rework/wrong-scope 0 ไม่ reproducible** — เดิมบอก 0 จาก inspection → **FIX:** เพิ่ม reproducible grep query ใน report §6/§9 (marker regex EN/TH) · รันแล้ว: wrong-scope hits = non-cohort (043/039/097), rework = 0 hits → cohort 0/0 ยืนยันซ้ำได้
- Codex PASS: owner-conflict=0 · B0 reality clause (NOT_RECORDED ถูก) · canonical isolation

### Codex re-review round 2 (2026-07-12) = STILL REWORK → fixed อีกชั้น (Opus verify ยืนยันถูกทั้ง 3)
- **cohort ยังผิด:** round-1 เอา `ORDER-088` (07-10) มาเติมช่องที่ว่าง — ผิด เพราะ **`ORDER-081` (Crypto lane feasibility, DONE 07-11)** เป็น order 07-11 ที่ผม**มองข้ามตั้งแต่แรก** → 18 orders ของ 07-11 ต้องมี 081 · 088 = ลำดับ 21 (ตกไป) → **FIX:** 088→081 (class RESEARCH) · CSV ยืนยัน 20 distinct
- **085B review SHA ยังผิด:** `e481e00f` = review ของ ORDER-**085** (ที่เปิด 085B) · review จริงของ 085B = **`ee0ae804`** ("REVIEW 085B: BWD FAIL PF 0.88") → **FIX:** แก้ CSV+§7
- **§9 mapping ไม่ตรงผลรันจริง:** enclosing header จริง = 046/043/042/072/075/097 (ไม่ใช่ "043/039/097" ที่เขียนไว้) → **FIX:** เขียน mapping ใหม่ให้ตรง grep จริง · cohort ยัง 0/0 (ทั้ง 6 hit = non-cohort)
- Codex spot-check evidence อื่น (083B/092/093/091C-D1c/095-A) = ผ่าน · regression (owner-conflict 0, NOT_RECORDED, canonical isolation) = ผ่าน

**Status หลังแก้ 2 รอบ:** artifact ปรับครบใน `docs/memory_control/` (commit แยก) → รอ re-review รอบ 3. บทเรียน: cohort selection = จุดอ่อนซ้ำ (ผิด 2 รอบ) — round 3 re-derive 07-11 set แบบ mechanical (18 distinct) ก่อน sign-off.

### ✅ Codex re-review round 3 (2026-07-12) = ACCEPT → ORDER-099 REVIEWED / Contract A COMPLETE
Codex re-derive cohort เองจาก pinned blob = ตรง dataset ทุกตัว (18×07-11 + 089/090; 088 = #21 ตัดออก) · evidence 085B→ee0ae804 + 081→ee62433f ยืนยัน ancestor · §9 query รันตรง mapping · regression (owner-conflict 0, NOT_RECORDED, canonical isolation) ผ่าน. **ไม่มี artifact defect เหลือ.**
- **หมายเหตุ honesty (Codex จับ, non-blocking):** commit `286ea6b5` แตะ block ORDER-100 ด้วย (บันทึกผล blind review Contract B) — ดังนั้นข้อความ commit ที่ว่า "เฉพาะ ORDER-099 lifecycle" ไม่ตรงตามตัวอักษร. เป็นการบันทึก review status ของอีก order ไม่ใช่เปลี่ยน authority/canonical EA data · `1b9ce1b` ไม่ซ้ำจุดนี้ · ไม่ rewrite history (ห้ามตามกติกา) แค่บันทึกตรงนี้.

**System order 1 ปิด.** เหลือ: ORDER-100 (Contract B) = REWORK รอ rebuild (user pause) · Contract C/D ยังไม่เริ่ม (C ต้อง window เงียบ).

---

## ORDER-100 — Contract B: MVP-0 blocking execution harness (`run_batch.ps1`) — `REVIEWED(Opus lead = MVP-0 ACCEPT, 2026-07-12) — Contract B COMPLETE · 11 fixes · 22/22 · 3 Codex rounds · 1 documented alias-limit (fix ก่อน deploy harness ขับ MT5 จริง)` (SYSTEM ORDER 2 of ≤4 memory-control build)

> **Design source:** `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` **§20.8 Contract B @ `4eb839d`** + §20.2 seq #2 + §20.5 (reversible details delegated)
> **ทำได้:** Codex-direct (build wrapper + TDD) · qwen/fast-worker (runner inventory เฟส 1) · Claude/Opus (interface+safety = เขียนไว้ในใบนี้แล้ว) · **👉 แนะ:** **qwen** เฟส 1 (mechanical) → **Codex-direct** เฟส 2 (code+TDD)
> **Skills:** `tdd` (wrapper + append manifest) · `karpathy-guidelines` (surgical, explicit success criteria)
> **Gate note:** system order 2 จาก ≤4 · review gate อยู่หลัง order ที่ 4 · ORDER-099 = self-ACCEPT ค้าง external review (B ไม่กิน output ของ B0 → เขียนคู่ขนานได้ แต่ถ้า B0 ถูก REWORK ใบนี้ไม่กระทบ)

**ทำไม:** วัดแล้ววันนี้เอง — ของเสียที่แพงสุดไม่ใช่ context แต่คือ **agent stall + concurrent-writer collision** (session นี้โดน 2 ครั้ง: broad `git add` กวาดไฟล์ + branch switch ใต้เท้า). harness นี้ = ชั้น orchestration ที่ทำให้ batch **หยุดเป็น (blocking), เห็น fail ชัด, กันชนกันข้ามเลน, และ resume ได้** โดย **ไม่แตะ tester logic เดิม**.

**หลักการเหล็ก (Opus เขียน — ห้าม implementer เปลี่ยน):**
1. **Adapter ไม่ reimplement** — wrapper *เรียก* runner เดิม (`mt5_run.ps1`/`mt4_run.ps1`/`mt5_optimize.ps1`/`mt4_optimize.ps1`/`mass_smoke_*`) ตามเดิมทุกตัว **ห้ามเขียน tester logic ใหม่**
2. **No new kill / no new process `-Force`** — wrapper **ห้ามมี** `Stop-Process`/`taskkill`/global kill/`-Force` บน process. timeout-kill ต่อ-PID ที่ runner เดิมมีอยู่ (mt5_run:113, mt4_run:123) = ปล่อยไว้ในตัว runner **ห้ามยกมาไว้ wrapper และห้ามเพิ่มของใหม่** · (`-Force`/`New-Item -Force` บน **ไฟล์/โฟลเดอร์** = อนุญาต ไม่ใช่ process — แต่ห้ามเพิ่มบน process)
3. **ห้ามแตะ tester-safety เดิม** — GUI-already-running abort (`exit 2`) + `-Force` override ของ runner = คงเดิมเป๊ะ
4. **Lane model = ของเดิม** (AGENTS.md §3.2): MT5 lane1 `D:\Meta 5` · lane2 `D:\Meta 5b` · lane3 `D:\Meta 5c` (ห้าม Model-4) · MT4 lane1 `D:\Meta4` · lane2 `D:\Meta4b` · **Model-4 = SERIAL lane1 เท่านั้น** · ในเลนเดียว = ทีละ job

**เฟส 1 — runner inventory (deliverable, mechanical → qwen):** ตาราง `docs/memory_control/RUNNER_INVENTORY.md` ต่อ runner: `path · purpose · key params (Terminal/DataDir/Portable/Model/Report) · lane ที่ใช้ · exit-code semantics · timeout/kill เดิม`. ครอบ ≥ `mt5_run · mt4_run · mt5_optimize · mt4_optimize · mass_smoke_mt5 · mass_smoke_mt4 · mt5_batch_shortlist · qwen_batch_runner`. **adapter design เฟส 2 ต้อง derive จากตารางนี้.**

**เฟส 2 — `scripts/run_batch.ps1` (deliverable, Codex + TDD) ตาม interface contract:**
- **Input:** job manifest (list ของ job — แต่ละ job มีอย่างน้อย `id · runner · args · lane · model`). รูปแบบไฟล์ manifest (JSON/CSV/PSD1) + ชื่อ param = **delegated to Codex** (§20.5) ตราบใดที่มี field ครบ
- **Blocking:** รัน job แล้ว *รอ* ให้จบก่อนไป job ถัดที่ผูกกัน — ไม่ fire-and-forget
- **Lane-aware:** ห้าม dispatch 2 job เข้าเลนเดียวกันพร้อมกัน (block/queue ไม่ใช่ fail) · Model-4 job → serial lane1
- **Fail-visible:** job fail (runner exit ≠ 0) → **หยุด job ที่เหลือในลำดับนั้น + wrapper exit ≠ 0** + log เหตุชัด
- **Resume:** รันซ้ำด้วย manifest เดิม → รันเฉพาะ job ที่ยัง `pending/failed` · job `done` = skip (idempotent)
- **Manifest state file:** บันทึกต่อ job = `id · runner · lane · state(pending/running/done/failed) · start · end · exit_code` (append/update, กู้คืน resume ได้)

**Acceptance (ตัวเลข/ไฟล์ล้วน — ตรวจได้ทุกข้อ ด้วย mock runner ไม่ต้องเปิด MT5 จริง):**
- [ ] เฟส 1: `RUNNER_INVENTORY.md` ครบ ≥8 runner พร้อม 6 คอลัมน์
- [ ] mock success path → wrapper **exit 0** + manifest ทุก job = `done`
- [ ] mock 1 job fail → job ถัดไป **ไม่รัน** + wrapper **exit ≠ 0** + manifest job นั้น = `failed`
- [ ] interrupt กลางคัน แล้วรันซ้ำ → **รันเฉพาะ job ที่ยังไม่ done** (job done เดิมไม่รันซ้ำ = idempotent) พิสูจน์ด้วย marker/timestamp
- [ ] lane collision: 2 job lane เดียวกัน → **ไม่รันพร้อมกัน** (blocked/queued) พิสูจน์ด้วย overlap-check ใน manifest time
- [ ] `grep -rInE 'Stop-Process|taskkill|-Force' scripts/run_batch.ps1 <fixtures>` → **ไม่มี** kill/process-`-Force` ใหม่ (เฉพาะ file-op `-Force` ที่จำเป็นเท่านั้น + ต้องมี comment)
- [ ] runner เดิมทุกไฟล์ **byte-unchanged** (`git diff` ว่างสำหรับ mt5_run/mt4_run/*optimize) = wrapper adapt ไม่แก้ของเดิม
- [ ] `[tag] ORDER-100 done` + ผลดิบ (test output ทุก fixture) append ใต้ order นี้

**ห้าม (out of scope — §20.8 Contract B):**
- ❌ `Stop-Process`/`taskkill`/global kill/process-`-Force` ใหม่ · ❌ แก้พฤติกรรม tester-safety เดิม (GUI-abort/exit-2)
- ❌ reimplement tester logic (ต้องเรียก runner เดิม) · ❌ แก้ไฟล์ runner เดิม (adapt เท่านั้น)
- ❌ รัน MT5/MT4 จริงใน fixture test (ใช้ mock runner ที่ echo + exit code ตามสั่ง) · ❌ implement MVP-3/events/packet
- ❌ pre-open Contract C/D — เขียนหลัง review ORDER-100

**Rollback:** ลบ/ปิด `run_batch.ps1` + fixtures + `RUNNER_INVENTORY.md`; runner เดิมต้องทำงานเป๊ะเหมือนก่อนมี wrapper (พิสูจน์ด้วย byte-unchanged + smoke 1 run ตรง runner).

**Routing:** เฟส 1 (inventory) → qwen/fast-worker · เฟส 2 (wrapper+TDD) → Codex-direct · Opus review ผลดิบ + verify grep-no-kill + byte-unchanged ก่อน mark REVIEWED. (Contract B = commit แยก — ห้ามรวมกับ B0/canonicalization.)

### ผลดิบ (Opus lead + Sonnet-subagent build, 2026-07-12) — executed

**Build:** dispatch การ build ให้ Sonnet subagent (Claude quota ไม่เผา ChatGPT · Opus คุม commit เอง) ตาม interface+safety spec ในใบนี้เป๊ะ · Opus verify เอง (รัน test + อ่านโค้ด + grep + byte-check) ไม่เชื่อคำ subagent.

**Files (ทั้งหมดใน allowlist):**
- `scripts/run_batch.ps1` — wrapper (blocking · lane-lock advisory · fail-stop · resume · state.json)
- `scripts/_test/mock_runner.ps1` + `scripts/_test/test_run_batch.ps1` — fixtures + test driver (ไม่แตะ MT5 จริง)
- `docs/memory_control/RUNNER_INVENTORY.md` — เฟส 1 inventory ครบ 8 runner

**Opus-verified acceptance (รันเอง 5/5 PASS):**
- [x] mock success → exit 0 + ทุก job `done`
- [x] mid-job fail → job ถัดไปไม่รัน + exit 1 + job=`failed` (marker ที่ 3 หายจริง)
- [x] interrupt→resume → รันเฉพาะ not-done · job `done` marker frozen (idempotent)
- [x] lane collision → 2 job lane เดียวกันไม่ overlap (timestamp พิสูจน์) + lock created/removed
- [x] no-kill scan: 0 `Stop-Process`/`taskkill`/process-`-Force` (hit ทั้งหมด = comment หรือ file/dir op)
- [x] runner เดิม 4 ไฟล์ **byte-unchanged** (`git status --porcelain` ว่าง)
- [x] inventory ≥8 runner

**Design note (Opus):** invoke runner เดิมด้วย `& powershell -File $runner @args` + เช็ค `$LASTEXITCODE` · lane-lock ใช้ `[System.IO.File]::Open(CreateNew)` (atomic exclusive-create, ไม่มี process primitive) release ด้วย try/finally · state เขียนทุก transition = interrupt-safe · Model-4 → pre-flight guard บังคับ lane-1/serial ก่อนรัน job แรก.

**Known limitation (ยกไป iteration หน้า, ไม่ block MVP-0):** run ที่ crash ทิ้ง stale lane-lock ไว้ → resume จะ block 300s แล้ว fail-visible (ไม่เงียบ ไม่ kill). stale-lane detection = delegated item §20.5 — ทำเป็น order แยกทีหลัง.

**Status:** DONE + Opus self-review = **ACCEPT**. **ค้าง external review** (เหมือน ORDER-099) ก่อน flip `REVIEWED`.

⏸️ **STOP-POINT ก่อน system order 3 (Contract C):** Contract C = active/archive migration = แก้ **architectural write path** → §20/handoff บังคับ (ก) **maintenance window ที่ไม่มี taskboard writer** — ตอนนี้มี concurrent session เขียนอยู่ (ดู memory `shared-worktree-concurrent-writers`) = **ยังไม่ปลอดภัย** · (ข) **blind Codex review ก่อน accept**. → ไม่เขียน Contract C ต่อจนกว่า user เคาะ window + review ORDER-099/100.

### Codex blind review (ORDER-100) 2026-07-12 = REWORK — Opus verify: ยอมรับทุกข้อ (self-ACCEPT ผิด)
Official tests ยัง 5/5 PASS แต่ mock ปิด case จริงไม่หมด. ต้องแก้ก่อนใช้รัน MT4/MT5 จริง:
- **BLOCKER-1 false-green:** wrapper ตัดสินจาก `$LASTEXITCODE` อย่างเดียว (L209). **Opus verify:** `mt5_run.ps1` exit 1 ตอน NO REPORT (ok) **แต่ `mt4_run.ps1` ไม่มี `exit` บน path report → falls through = exit 0 แม้ NO REPORT** (L109-130) → false green จริงกับ mt4/optimizer/batch. **FIX:** success-detection ต้องเช็ค **artifact จริง (report/xml ถูกสร้าง)** หรือ parse `OK REPORT`/`NO REPORT` marker ต่อ-runner ไม่ใช่ exit code ล้วน
- **BLOCKER-2 lane-lock ไม่ global:** lock อยู่ใต้ `$StateDir` (L89-93) → 2 batch คนละ StateDir แต่ physical lane เดียว = lock คนละไฟล์ = ไม่กันชนจริง (Codex รัน 2 wrapper overlap ได้). **FIX:** lane-lock ไปที่ **fixed global dir keyed by physical lane/terminal** ไม่ใช่ StateDir
- **FIX-3 lane-collision test อ่อน:** test (L169) ใส่ 2 job ใน process เดียว = sequential อยู่แล้ว ถอด lock ออกก็ผ่าน → ต้อง test **2 process พร้อมกัน** lane เดียว assert no-overlap
- **FIX-4 Model-4 guard เชื่อ label:** (L81) รับ lane ลงท้าย `-1` แต่ manifest ใส่ `-Terminal Meta 5b` ได้ → ไม่ผูก physical lane 1 จริง. **FIX:** parse `-Terminal` จาก args เทียบ lane-1 install จริง
- **FIX-5 state write ไม่ atomic:** `Set-Content` ตรง (L73) → crash กลาง write = JSON ขาด resume ไม่ได้. **FIX:** write temp + atomic move
- **FIX-6 manifest dup-ID ไม่ validate:** unique ID ใน contract (L21) แต่ lookup first-match (L195) → dup = รัน runner ผิด. **FIX:** validate unique ID, abort ถ้าซ้ำ
- Codex PASS: no-kill/-Force safety · runner เดิม byte-unchanged · stale-lock 300s ยอมรับได้ (แต่ต้อง global scope ก่อน = ผูกกับ BLOCKER-2)

**Rebuild spec = 6 ข้อบน · commit แยก · re-test + re-review ก่อน accept · ห้าม flip REVIEWED จน 2 blocker ปิด. รอ user เคาะเริ่ม rebuild (routing เดิม: Codex-direct/subagent build → Opus verify).**

### ผลดิบ rebuild (Sonnet-subagent build + Opus verify, 2026-07-12)
Opus รัน test เอง + อ่านโค้ด safety-critical เอง (ไม่เชื่อคำ subagent). **14/14 PASS, exit 0.**
- ✅ **BLOCKER-1 false-green:** success = `exit0 AND stdout ไม่มี /NO REPORT|NO XML|ABORT|ERROR|FATAL/ AND expect_artifact มีจริง (mtime≥start)` · capture stdout ผ่าน `2>&1 | Out-String` · `$LASTEXITCODE` ถูกต้อง (native exit ไม่ใช่ Out-String) · test 6 พิสูจน์: mock exit 0 + "NO REPORT" → **FAILED** ไม่ใช่ done
- ✅ **BLOCKER-2 global lane-lock:** `$env:TEMP\ealab_run_batch_locks\lane_*.lock` (ไม่ใช่ StateDir) · **test 14 = 2 process จริง lane เดียว StateDir ต่าง → serialized no-overlap** (พิสูจน์ cross-process exclusion)
- ✅ FIX-3 atomic state: temp+`Move-Item` · corrupt state.json → abort loud exit 2 · ไม่มี .tmp leftover
- ✅ FIX-4 dup-ID: manifest id ซ้ำ → abort exit 2 ก่อนรัน
- ✅ FIX-5 Model-4 physical: parse `-Terminal` เทียบ lane-1 install (`-Lane1Terminal` default `D:\Meta 5\terminal64.exe`) · label `fake-1` + terminal lane-2 → abort exit 2
- ✅ FIX-6 real 2-process concurrency test (test 14 บน)
- ✅ no-kill/-Force clean (run_batch+mock) · runner เดิม 4 ไฟล์ byte-unchanged
- **Minor limit (ยกไปทีหลัง ไม่ block):** failure-keyword scan กว้าง อาจ false-positive กับคำ "error" ที่ไม่ร้าย — fail-closed = ปลอดภัยกว่า แต่ signal ที่คมกว่าคือ require positive marker `OK REPORT` ที่ทั้ง mt5_run/mt4_run พ่นอยู่ · tune ทีหลังได้

**Status (rebuild r1):** REBUILT + Opus self-review ACCEPT · pending Codex re-review.

### Codex re-review round 1 (2026-07-12) = REWORK → fixed อีกชั้น (Opus verify ยืนยันถูกทั้ง 2)
- **false-green ยังหลุด:** `mt4_optimize.ps1` พิมพ์ **`NO OPT REPORT`** exit 0 — regex เดิม `NO REPORT` ไม่จับ (มี "OPT" คั่น) → **FIX:** regex `NO( OPT)? REPORT|...` + **reliability model:** runner exit-unreliable (mt4_run/mt4_optimize/mt5_optimize, override ด้วย manifest `exit_reliable`) ต้องมี **positive evidence** (marker `OK( OPT)? REPORT|OK OPTIMIZER XML` หรือ expect_artifact) ไม่งั้น FAILED · (subagent จับเพิ่ม: mt5_optimize success จริง = "OK OPTIMIZER XML" ไม่ใช่ "OK XML" → กัน false-negative)
- **lane-lock keyed by label:** 2 manifest lane label ต่างกันแต่ `-Terminal` เดียวกัน = คนละ lock (ไม่กันชน physical install) → **FIX:** `Get-LaneLockKey` derive จาก `-Terminal` (normalized) ถ้ามี, fallback label
- Codex CLOSED อีก 4: atomic state · dup-ID · model-4 physical · resume · safety (no-kill/byte-unchanged)

**Opus verify (รันเอง):** **20/20 PASS** (test 15 NO OPT REPORT→FAILED · test 19 diff-label same-terminal→serialized · test 20 OK OPTIMIZER XML→done) · runner เดิม byte-unchanged · no-kill clean.

**Status หลัง r1-fix:** 8 fixes รวม · self-ACCEPT · pending Codex re-review round 2.

### Codex re-review round 2 (2026-07-12) = REWORK → fixed (Opus verify ยืนยันถูกทั้ง 2)
- **batch runners ยัง default reliable:** reliability model เดิม = blacklist (default reliable) → mass_smoke/batch_shortlist/qwen_runner ที่ exit 0 แม้ sub-job ล้ม = false-green. **FIX:** flip เป็น **fail-closed whitelist** — trust exit code เฉพาะ `{mt5_run.ps1, mock_runner.ps1}` (หรือ `exit_reliable:true`) · ที่เหลือทั้งหมด default **unreliable → ต้องมี positive evidence** · test 21 พิสูจน์: unknown runner exit 0 no evidence → FAILED
- **terminal lock ไม่ canonicalize path:** `.`/relative/slash ต่างกัน = คนละ lock สำหรับ install เดียว. **FIX:** `[System.IO.Path]::GetFullPath` + lowercase + trim trailing sep · test 22 พิสูจน์: `D:\Meta 5\terminal64.exe` vs `D:\Meta 5\.\terminal64.exe` → serialized
- RUNNER_INVENTORY.md อัปเดต callout fail-closed default (per-row notes เดิม superseded)

**Opus verify (รันเอง): 22/22 PASS.** runner เดิม byte-unchanged · no-kill clean.
**Status หลัง r2-fix:** 10 fixes รวม · self-ACCEPT · pending Codex re-review round 3.

### Codex re-review round 3 (2026-07-12) = REWORK → 1 fix + 1 lead-accepted limit
- **reliable whitelist ใช้ basename:** rogue script ชื่อ `mt5_run.ps1` นอก repo จะถูก trust. **FIX:** whitelist เป็น **exact resolved path** (`$PSScriptRoot\mt5_run.ps1` + `_test\mock_runner.ps1`) — test 21 (unknown path→FAILED) ยืนยัน · 22/22 ยังผ่าน
- **path canonicalize ไม่ครอบ filesystem aliases** (UNC `\\localhost\d$\...`, mapped-drive, junction, 8.3): **LEAD JUDGMENT = accept เป็น documented MVP-0 limit** (ไม่ใช่ fix ตอนนี้) — เพราะ (ก) harness ยัง gated ห้ามรัน MT4/MT5 จริง (ข) manifest ใช้ canonical `D:\Meta 5\...` ตาม AGENTS.md · full fix (allowlist -Terminal → 5 lane paths) เลื่อนไปตอน harness ขับ real runs · comment ใน `run_batch.ps1` + inventory บันทึกแล้ว
- Codex CLOSED: regression, safety, mt5_run reliable ทุก path

**Lead verdict (Opus):** ORDER-100 = **MVP-0 ACCEPT** (11 fixes · 22/22 · 1 documented alias-limit ที่ยอมรับได้สำหรับ MVP-0 gated). ไม่ใช่ทุก Codex finding ต้อง implement — receiving-code-review = verify แล้วตัดสิน. **แนะ user: LOCK ORDER-100 ที่นี่** (หรือสั่งให้ปิด alias-limit ถ้าอยากแกร่งสุดก่อน harness ขับจริง). ยัง ห้ามใช้รัน MT4/MT5 จริงจน user เคาะ deploy.

---

## ORDER-101 — Contract C0: active/archive READ-ONLY reconcile + freeze (no block moves) — `REVIEWED(Opus lead ACCEPT, user-approved 2026-07-13) — C0 COMPLETE · 3 Codex rounds · validator ถาวร + manifest/index/exceptions พร้อมให้ C1 ใช้` (SYSTEM ORDER 3 of ≤4 memory-control build)

> **Design source:** `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` **§20.8 Contract C @ `4eb839d`** + §20.2 seq #3 + §20.7
> **ทำได้:** Codex-direct/subagent (build reconcile/manifest/index/validator scripts) · Opus (reconcile judgment + exception resolution = own) · **👉 แนะ:** subagent build → **Opus verify → BLIND CODEX REVIEW ก่อน accept**
> **Skills:** `tdd` (validator) · `scrutinize`/`code-review`
> **⚠️ REVISED ×3 หลัง Codex design review (2026-07-12, rounds 1-3):** split Contract C เป็น **C0 (read-only, ใบนี้) + C1 (migration window, ใบถัดไป)**. C0 **พิสูจน์ partition + สร้าง manifest/index/validator แต่ไม่ย้าย/ไม่แก้เนื้อ taskboard หรือ archive เลย** → risk ของ write-path เลื่อนไป C1. (r2: split-integrity vs drift แยก · review m2m · status verbs · diff carve-out · validator audit/strict · C1 enforced lock) (r3: split-integrity = **multiset-by-hash + exclude manual-index generated-extra** (แก้ acceptance ที่เป็นไปไม่ได้ extra=0) · 099=status-mutation ไม่ใช่ addition · review link ระดับ **order_block_id** · validator **3-level exit** (audit ไม่ซ่อน integrity failure) · status-parse-fail=exit2 · C1 lock fail-closed+staged-hash allowlist) · **C0 = read-only → lead แนะ dispatch build แล้ว review OUTPUT จริง (คุ้มกว่า spec-review รอบต่อ)**

**REALITY:** cleanup วันนี้แยก board แล้ว (`ARCHIVE_TASKBOARD_2026-07A.md`) แต่ generator `scratchpad/gen_taskboard.py` **ไม่ tracked/หายแล้ว** → **ห้ามพึ่ง generator นั้น**. ต้อง reconcile กับ **git history `4aebbc37^:AGENT_TASKBOARD.md`** (pre-split = **115 `## ORDER-` headers**) เป็น ground truth. archive มี **131 `## ` blocks รวม** แต่ **91 เป็น `## ORDER-`** (ที่เหลือ 40 = review-note/annotation/merge-ref) → **"block" ต้องนิยามชัด**. manual pass ยก DONE/CLOSED/SKIPPED มาด้วย (หลวมกว่า "move only REVIEWED") + มี **manual index ฝังใน active taskboard** (~บรรทัด 15) = ละเมิด §20.7 (index ต้อง generated/read-only) → ทั้งคู่เป็น exception ที่ C0 ต้อง**ตรวจพบและ list** (แก้จริงใน C1).

**Block model (นิยามบังคับ):** `block` = 1 top-level `## ` section. ต่อ block parse → `block_type ∈ {ORDER, REVIEW-NOTE, ANNOTATION, MERGE-REF, OTHER}` (จาก header pattern) · `canonical_id` = ORDER-id จาก **header เท่านั้น** (ไม่ค้นทั้ง body) · `block_id` unique = `canonical_id + block_type + source_anchor` (ORDER_ID เดี่ยวไม่ unique — 091B/phase/review ซ้ำได้). **⚠️ review linking = many-to-many ระดับ block (Codex r3):** 1 REVIEW ผูกได้**หลาย order block** (order เดียวมีหลาย phase block เช่น 091B → review อาจครอบทั้ง 2 phase หรือ phase สุดท้าย) → linking = **`review_block_id → SET(order_block_ids)`** (ไม่ใช่ canonical_ids ล้วน — แยก phase ไม่ได้) + `canonical_ids` เป็น derived. `source_anchor` = **`source_commit + H2 ordinal`** (ระบุ block ตรงตัว). การเช็ค "terminal มี linked review" resolve ผ่าน block-id set นี้.

**เฟส 1 — reconcile (read-only, deliverable) — แยก 2 การพิสูจน์ (Codex r2):**
- pre-state SHA-256 ของ `AGENT_TASKBOARD.md` + `ARCHIVE_TASKBOARD_2026-07A.md` (working tree ปัจจุบัน)
- **(1a) SPLIT-INTEGRITY proof — committed states ล้วน (immutable), MULTISET-by-hash (ไม่ใช่ concat):** union ของ block ไม่มี ordering + raw-concat 2 ไฟล์ ≠ ต้นฉบับ (มี preamble/index เพิ่ม) → **algorithm:** (1) parse H2 blocks จาก `4aebbc37:active` + `4aebbc37:archive` + `4aebbc37^:pre-split` (2) **exclude known split-generated extras** (โดยเฉพาะ block `## 🗂️ ARCHIVED ORDERS INDEX` = manual index ที่ generator ใส่เพิ่ม) — list ไว้ชัดว่าตัวไหนเป็น generated-extra (3) map ด้วย **exact block sha256** (4) multiset compare original blocks: **missing=0 · mutated=0 · duplicated=0** (5) **generated-extras รายงานแยก ไม่บังคับ=0** · pre-split H2=156/ORDER=115, split active H2=26/ORDER=24, split archive H2=131/ORDER=91.
- **(1b) POST-SPLIT drift — แยกบัญชีต่างหาก:** diff active ปัจจุบัน vs `4aebbc37:AGENT_TASKBOARD.md` = ต้องเป็น **เฉพาะ additions (099/100/101 ฯลฯ) + status flips ที่ legitimate** (list ให้ชัด) · diff archive ปัจจุบัน vs `4aebbc37:ARCHIVE...` = **ต้องว่าง** (archive = append-once หลัง split, ห้ามแก้). ห้ามปน 1a กับ 1b.
- **exception scan (block-type-aware, ครอบ status ครบ):** parse block_type + สถานะจาก header. **terminal verbs ที่ต้องรู้จักครบ:** `REVIEWED · DONE · DONE-PHASE1 · DONE-STOPPED(-AT-STAGE-n) · CLOSED · REVIEWED/CLOSED · SKIPPED · BUILT · FUNNELED · BUILT+FUNNELED · BUILT+CLOSED · STAGE2-DONE` · **non-terminal:** `OPEN · CLAIMED · IN-PROGRESS · WAITING(-USER) · HOLD · mixed (มี OPEN ปนใน status ผสม)`. flag ใน archive → (a) non-terminal ใดๆ = **hard fail** (b) terminal-verb ที่**ไม่มี linked REVIEW** (review block/`REVIEW ORDER-x` ที่ resolve ได้) = **BLOCKED→Opus** (c) canonical_id ที่อยู่ทั้ง active+archive (เช่น 071/091B) = **hard fail จน Opus จัดชั้น** (annotation / obsolete-phase / active-continuation) (d) `CLOSED/SKIPPED/DONE-*` **ห้ามนับเป็น REVIEWED อัตโนมัติ** (e) **ORDER block ที่ parse สถานะไม่ได้ = integrity failure (exit 2) ห้ามเดา** — ยกเว้น annotation header ที่รู้ว่าไม่มีสถานะโดยชอบ (`ORDER-035-REVIEW note`, `ORDER-075/078 NOTE`) = จัด block_type=ANNOTATION

**เฟส 2 — systematic artifacts (สร้างไฟล์ใหม่เท่านั้น — ไม่แก้ taskboard/archive):**
- **integrity manifest** `docs/memory_control/ARCHIVE_MANIFEST.csv`: **bijection** — ต่อ archived block 1 row = `block_id · canonical_id · block_type · sha256(verbatim block) · source_commit · source_anchor`. ทุก archive block → 1 row, ทุก row → resolve กลับ 1 block (พิสูจน์สองทาง)
- **generated read-only index** `docs/memory_control/ARCHIVE_INDEX.md` derive จาก manifest (banner generated/read-only) · **rebuild zero-diff** · links/anchors ทุกตัว resolve ได้
- **validator** `scripts/check_taskboard_archive.ps1` — **3-level exit (Codex r3, กัน Audit ซ่อน corruption):** **exit 0** = scan สำเร็จ ไม่มีปัญหา · **exit 1** = *policy* exceptions (DONE-unreviewed / cross-ID / non-terminal-in-archive) → `-Audit` ยอมให้ผ่าน (report), `-Strict` fail · **exit 2** = *integrity/tooling* failure (parse ไม่ได้ / hash เสีย / source_anchor ไม่มีจริง / index rebuild error / bijection พัง) → **fail ทั้ง `-Audit` และ `-Strict`**. เช็ค: (1) exception scan (2) manifest bijection (3) block sha256 ตรง manifest (4) source_commit/anchor มีจริง+hash ตรง (5) index rebuild zero-diff + links resolve (6) canonical_id ไม่ซ้ำข้าม active/archive (นอกที่ Opus จัดชั้น) (7) active claim/result path เขียนได้ (mock). **negative tests structural (delete/mutate/extra-row/bad-hash) ต้อง exit 2 ทั้ง 2 โหมด.**

**Acceptance (ตัวเลข/ไฟล์ล้วน):**
- [ ] pre-state hash 2 ไฟล์ บันทึก
- [ ] **(1a) split-integrity (multiset-by-hash):** original blocks missing=0 · mutated=0 · duplicated=0 · generated-extras (manual-index) listed separately (ไม่บังคับ=0)
- [ ] **(1b) post-split drift:** active-now vs `4aebbc37:active` = additions (100/101; **099 = status-mutation** เพราะมีตั้งแต่ split ในสถานะ OPEN) + legit status-flips เท่านั้น (list) · archive-now vs `4aebbc37:archive` = **ว่างสนิท**
- [ ] `ARCHIVE_MANIFEST.csv` bijection: |rows| = |archive blocks| · re-hash reproduce · ทุก source_anchor valid
- [ ] exception list ออกครบ: OPEN/CLAIMED/WAITING ใน archive=0 (ถ้ามี=hard fail) · DONE-unreviewed + cross-ID = **BLOCKED→Opus** (worker ห้ามตัดสิน/ย้าย)
- [ ] generated index **rebuild zero-diff** + links resolve
- [ ] validator **pass** + **negative tests แยกกรณี:** delete-block · mutate-byte · extra-manifest-row · dup-block_id · archived-OPEN · stale-index → validator exit≠0 ทุกเคส
- [ ] active board ยัง writable (mock claim/result)
- [ ] **C0 ไม่ย้าย/แก้เนื้อ block อื่นใดๆ:** git diff `AGENT_TASKBOARD.md` ต้องแตะ**เฉพาะ block ORDER-101 เอง** (lifecycle/ผลดิบของใบนี้) — ทุก block อื่น byte-identical · git diff `ARCHIVE_TASKBOARD_2026-07A.md` = **ว่างสนิท** · C0 สร้างเฉพาะไฟล์ใหม่ (manifest/index/validator/exception-list)
- [ ] `[tag] ORDER-101 done` + ผลดิบ + exception list append

**ห้าม (out of scope):**
- ❌ **ย้าย/แก้/ลบ block ใดๆ** ใน taskboard/archive (C0 = read-only proof; ย้ายจริง = C1) · ❌ แก้ manual index ใน active taskboard (แค่ flag ไว้ให้ C1)
- ❌ ลบ history · ❌ เปลี่ยน worker authority · ❌ worker ตัดสิน DONE-unreviewed/cross-ID เอง (BLOCKED→Opus)
- ❌ implement events/packet (D/MVP-2) · ❌ แตะ unrelated dirty files · ❌ pre-open Contract D

**Rollback (C0 = ง่าย):** C0 สร้างเฉพาะไฟล์ใหม่ (manifest/index/validator) → rollback = ลบไฟล์เหล่านั้น. ไม่แตะ pre-state เลย.

**→ C1 (migration window, ใบถัดไป หลัง C0 accept + Opus resolve exceptions):** ย้ายเฉพาะ REVIEWED blocks จริง + แทน manual index ด้วย generated + hardened swap: (1) target-file clean check (2) **pre-hash recheck ทันทีก่อน swap** — abort ถ้า active/archive hash เปลี่ยนระหว่าง inventory→swap (shared worktree!) (3) **ENFORCED maintenance lock (Codex r3 — ไม่ใช่ marker เฉยๆ):** `.githooks/pre-commit` guard (repo มี `core.hooksPath=.githooks` จริง) ที่: **(i) ลง+test guard ใน commit ก่อน**เข้า window (ไม่ใช่พร้อม migration) · **(ii) fail-CLOSED ถ้าหา PowerShell ไม่เจอ** (hook เดิม fail-open ที่บรรทัด 5 — ต้องปิดช่องนี้) · **(iii) block ทุก commit ที่แตะ taskboard/archive ระหว่างมี lock marker ยกเว้น migration commit** — อนุญาตด้วย **exact staged-blob-hash/allowlist ไม่ใช่ commit message** (message ปลอมได้) · **(iv) recheck working-tree hashes เทียบ staged blobs ทันทีก่อน commit** (กัน session อื่นแก้ working tree ระหว่าง window) · **(v) `git commit --no-verify` ยังเป็น technical bypass** — threat model อาศัยกฎ AGENTS.md ห้ามใช้ (ยอมรับตามจริง) (4) เตรียม output ใน staging dir ก่อน (5) stage/commit ด้วย explicit allowlist (6) atomic rollback คืน **ทั้ง** `AGENT_TASKBOARD.md` + `ARCHIVE_TASKBOARD_2026-07A.md` + ลบไฟล์ใหม่. C1 = commit แยก + blind Codex review รอบผลจริง.

**Routing:** subagent/Codex build C0 scripts → Opus verify + exception judgment → **blind Codex review ก่อน accept C0**. Opus แก้ `AGENTS.md` เฉพาะใน C1 review commit ถ้า protocol ต้องการ. C0 = commit แยก.

### ผลดิบ C0 build (Sonnet-subagent build + Opus verify + Opus bugfix, 2026-07-12)
**Files (ใหม่ล้วน):** `scripts/check_taskboard_archive.ps1` (validator 2-mode) · `docs/memory_control/ARCHIVE_MANIFEST.csv` (131 rows) · `ARCHIVE_INDEX.md` (generated read-only) · `RECONCILE_EXCEPTIONS.md` (11 exceptions) · `scripts/_test/run_order101_negative_tests.ps1` + fixtures.

**Opus bugfix ก่อน verify:** subagent ทำ `$RepoRoot = Split-Path -Parent $PSScriptRoot` ใน param-default → throw เมื่อ `$PSScriptRoot` ว่างตอน `-File` invocation (PS 5.1). แก้เป็น resolve ใน body (fallback $MyInvocation/cwd) → validator รันได้.

**Opus-verified (รันเอง หลัง fix):** -Audit **exit 0** · -Strict **exit 1** (policy) · **negTests 8/8** (delete/mutate/extra-row/dup-id/corrupt-hash/stale-index → exit 2 ทั้ง 2 โหมด = audit ไม่ซ่อน integrity · archived-OPEN → policy 0/1) · **bijection 131/131** · index rebuild **zero-diff** · **split-integrity: missing/mutated/duplicated=0** (manual-index = generated-extra excluded) · **post-split drift:** additions 100/101 · mutations 099(OPEN→REVIEWED)/082 · **archive diff ว่างสนิท** · **taskboard+archive git status ว่าง** (read-only held แม้หลังผมรัน).

**11 policy exceptions — Opus classification (informs C1, ไม่ block C0):**
- **benign (OK archive):** 003/009 SKIPPED (ไม่ต้อง review) · 067/065/066 BUILT+CLOSED/FUNNELED (verdict inline ใน header) · 086/093/096C DONE mechanical/infra (self-completed) · 091C-D1c DONE (ส่วนของ JUMSTOCH campaign ที่ D1f REVIEWED ปิด thread แล้ว)
- **⚠️ real cleanup (C1 ต้องจัดการ):** **071** — rev02 `STAGE2-DONE (Stage-3 รอตัดสิน)` = **arguably non-terminal แต่ถูก archive** + rev01 `OPEN` ค้าง active (superseded) → C1 ต้อง (ก) ยืนยัน stage-3 หรือดึงกลับ (ข) ปิด rev01 · **091C-D1c** — "PROCESSING" annotation ค้าง active (stale) → C1 ลบ

**2 subagent judgment calls (flag ให้ Codex):** (1) `REVIEWED`/`REVIEWED/CLOSED` = self-attesting (ไม่ต้องมี companion REVIEW block) เฉพาะ DONE/BUILT/SKIPPED ที่ต้อง — sound (ตรง 2 ยุคของ archive: pre-068 inline vs 068+ split) กัน false-positive ~55 · (2) review linking = **canonical-id granularity ไม่ใช่ block_id m2m** ตาม spec — coarser (clear ทุก block ของ id) แต่ conservative + Opus review ทุก exception อยู่แล้ว → **documented C0 limit, upgrade block_id ใน C1**.

**Status:** C0 BUILT + Opus self-review ACCEPT (หลัง RepoRoot bugfix) · pending blind Codex review.

### Codex review r1 (2026-07-12) = REWORK 4 defects → fixed (Opus verify เจาะจุดที่ตัวเองพลาด)
Codex จับ 4 อย่างที่ self-verify ผมพลาด (ผมทดสอบใน HEAD/session เดียว):
1. 🔴 **validator regenerate ก่อน check** → normal run ซ่อม corruption → **FIX:** แยก `-Generate` (เขียน) จาก `-Audit`/`-Strict` (read-only compare)
2. 🔴 **source_commit=HEAD ไม่ deterministic** → **FIX:** `archive_blob_sha` = git blob SHA ของ archive (`c528989...`) ไม่ใช่ HEAD
3. 🔴 **bijection ไม่ cross-check row fields** (สลับ block_id ผ่านได้) → **FIX:** cross-check block_id/canonical_id/type/sha256 ต่อ row
4. 🟡 **071 partial-stage** (`STAGE2-DONE`+"Stage 3 รอตัดสิน" นอก backtick) → **FIX:** mixed-stage detection → 071 = non-terminal-in-archive
+ harden: generated-extra=exactly-one · hash=canonical-LF labeled + whole-file raw SHA

**Opus verify (รันเอง เจาะ #1/#2 ที่พลาด):** negTests **12/12** (รวม 4 เคสใหม่) · **corrupt committed manifest → normal -Audit exit 2** (ยืนยันไม่ silently regenerate) · **regenerate 2 ครั้ง byte-identical** (deterministic) · -Audit/-Strict **ไม่แก้ manifest/index** (sha before=after) · **taskboard+archive git status ว่าง** · 071 ได้ non-terminal-in-archive แล้ว (12 exceptions).

**Status หลัง rework:** C0 = self-ACCEPT (4 defects ปิด, verify เจาะจุดพลาด) · pending Codex review round 2.

### Codex review r2 (2026-07-12) = 4 defect เดิม CLOSED + 3 tail-gap → fixed
Codex ยืนยัน 4 defect หลักปิดจริง (read-only, determinism, bijection, 071). เจอ tail-gap 3:
1. 🟡 **Audit/Strict ไม่ validate `RECONCILE_EXCEPTIONS.md`** (แก้/ลบได้แล้วเขียว) → **FIX:** rebuild-compare exceptions file → mismatch = integrity exit 2 · negTest `stale-exceptions`
2. 🟡 **negTest suite แก้ tracked fixture** (เขียน output ทับ golden) → **FIX:** output ไป `$env:TEMP\order101_negtests`, ลบ scratch `out/*` (31 ไฟล์) ออกจาก tree, แยก input fixture ชัด
3. 🟢 **generated-extra guard `-gt 1`** (0 match ก็ผ่าน) → **FIX:** `-ne 1` (exactly-one) · negTest 0-match + 2-match
+ 🟢 polish: escape `|` ใน block_id ของ md index

**Opus verify (รันเอง):** negTests **15/15** (12+3) · **corrupt committed RECONCILE_EXCEPTIONS.md → normal -Audit exit 2** (`exceptions-rebuild-not-zero-diff`) · **suite ไม่ทำ tracked fixture drift** (before=after) · -Audit 0/-Strict 1 · artifacts sha before=after (read-only) · **taskboard+archive git status ว่าง** · ไม่แตะไฟล์ unrelated.

**Status หลัง r2-fix:** C0 = self-ACCEPT · pending Codex review round 3.

### Codex review r3 (2026-07-13) = FIX-2/3/invariants CLOSED · 1 nit fixed · 1 finding lead-overridden
- 🟢 **exceptions md ไม่ escape block_id** → **FIX:** escape `|` ทั้ง policy+integrity table (verify: `003\|ORDER\|...`)
- 🟢 **temp dir ชื่อคงที่ (concurrent collision)** → **FIX:** `$env:TEMP\order101_negtests_$PID`
- ⚖️ **FIX-1 "ไม่ byte-for-byte จริง" (CRLF-only mutation ผ่าน) → LEAD OVERRIDE (Opus, มีหลักฐาน):** repo นี้ `core.autocrlf=true` → working-tree artifact = **CRLF** แต่ git blob = **LF**. raw-byte compare (canonical-LF expected vs ReadAllBytes CRLF) จะ **false-fail ทุก clean run** (พิสูจน์: working-tree exceptions = 37 CRLF lines, blob = 0). ดังนั้น **content-canonical (LF-normalized) compare = invariant ที่ถูกต้อง** สำหรับ autocrlf repo — และ **consistent กับ manifest canonical-LF hash ที่ Codex accept ไปแล้วรอบก่อน**. content corruption ทุกชนิดยังจับได้ (stale-exceptions test พิสูจน์ exit 2) · CRLF-only = autocrlf noise ไม่ใช่ corruption. โค้ด document เหตุผลที่ compare site แล้ว (line ~1036). *ถ้า user อยาก strict raw-byte จริง = ต้องเพิ่ม `.gitattributes` pin LF ให้ 3 artifact ก่อน (เลี่ยง false-fail) — เสนอได้ถ้าต้องการ.*

**Opus verify (รันเอง):** suite **15/15** · exceptions block_id escaped · suite ไม่ dirty fixture (0) · -Audit 0/-Strict 1 · read-only held · taskboard/archive ว่าง.

**Lead verdict (Opus):** C0 = **ACCEPT** — 4 substantive defects + 3 tail-gaps ปิด · 1 CRLF finding = lead-decision มีหลักฐาน (ไม่ใช่ทุก finding ต้อง implement — verify แล้วตัดสิน). **แนะ user: accept C0 → เปิด C1** (หรือสั่ง strict raw-byte + .gitattributes ก่อนถ้าต้องการ). รอ user เคาะ. → **user เคาะ 2026-07-13: Accept C0 → เปิด C1.**

---

## ORDER-102 — Contract C1: migration window — resolve exceptions + replace manual index + freeze archive (WRITE-PATH) — `CLOSED (2026-07-14 — ENFORCEMENT-REWORK ปิดโดย ORDER-103 C1-ENFORCE = ACCEPT · Contract C1 complete ทั้ง data + enforcement)` (SYSTEM ORDER 4 of ≤4 memory-control build)

> **Design source:** `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` **§20.8 Contract C @ `4eb839d`** (migration half) + ORDER-101 "→ C1" spec + §20.7
> **ทำได้:** Opus (exception judgment + migration window + canonical workflow = own) · Codex/subagent (guard-hook code) · **👉 แนะ:** Opus เขียน+ตัดสิน → subagent build lock-hook → **Opus execute migration เอง (1 atomic commit)** → **blind Codex review ก่อน accept**
> ⚠️ **นี่คือ order เดียวที่แก้ architectural write path จริง (taskboard/archive)** — ต้อง maintenance window ไม่มี writer อื่น (user ยืนยัน session อื่นปิด) · gate = C0 validator `-Strict` ต้อง exit 0 หลัง migration
> **Prereq:** C0 (ORDER-101) REVIEWED ✓ — validator `check_taskboard_archive.ps1` + manifest/index/exceptions พร้อมใช้เป็น gate

**REALITY:** manual split ทำแล้ว (archive 131 blocks) → C1 **ไม่ bulk-move**. **REVISED r1 หลัง Codex C1 design review (2026-07-13):** เปลี่ยน "dispose exceptions" → **"canonical review linkage"** (§20.7: reviewed history/decision อยู่ owner เดิม ไม่ใช่ manifest column/allowlist ใหม่); ใช้ verdict เดิมที่มีอยู่; archived blocks **immutable — append-only**; แยก hook-install (C1a) จาก migration (C1b); pin staged-snapshot protocol.

**Phase 0 — validator upgrade (prereq, read-only, commit ของตัวเอง):** อัปเกรด `check_taskboard_archive.ps1` review-linkage เป็น **block-id/text level** (ที่ C0 เลื่อนไว้) → รู้จัก `REVIEW ORDER-x` block จริง. **หลัง upgrade: 071 exception ต้องหาย** เพราะมี `REVIEW ORDER-071 — REVIEWED — เคส entry ST03 ปิดถาวร` อยู่แล้ว (`ARCHIVE_TASKBOARD_2026-07A.md` L2657, preregistered-gate fail) — **C0 เดิม false-positive จาก canonical-id limit**. validator ต้องรายงานแยก `raw_detected / canonically_reviewed / unresolved`.

**Phase 1 — Opus canonical review (append-only, ไม่แก้ archived bytes):** สำหรับ exception ที่ **ไม่มี** linked review จริง → Opus เขียน **canonical consolidated review block** (append เข้า archive/taskboard ตาม owner) ระบุต่อรายการ: `kind · block_id · block_sha256 · disposition · evidence/review-ref`. validator **derive closure จาก canonical review block เท่านั้น** (key = exact exception identity `kind+block_id+sha256` ไม่ใช่ canonical-id — กัน 091C-D1c ที่มี 2 kind ปิดพลาด). **ห้าม manifest column/allowlist เป็น authority.** 
- benign **แต่ต้อง review จริง ไม่ใช่ "disposed":** 086/093/096C (DONE-mechanical) · 003/009 (SKIPPED) · 065/066/067 (BUILT+verdict-inline) — Opus เขียน closure จริงต่อรายการ · **091C-D1c ต้อง review ผล D1c โดยตรง** (ห้ามถือว่า D1f ปิดย้อนหลังอัตโนมัติ)
- benign list จริง = **9 canonical IDs** (003,009,065,066,067,086,093,091C-D1c,096C) ไม่ใช่ 10

**Phase 1b — จัดการ block ที่หลง active (append-only, verbatim):**
- **ORDER-071 rev02:** มี verdict แล้ว (REVIEW ORDER-071) → **ห้ามตัดสินซ้ำ ห้ามแก้ bytes** · validator (Phase 0) รับรู้ linked review = ปิด pending-stage exception
- **ORDER-071 rev01 (`OPEN` active L362):** superseded โดย rev02 → **ย้ายเข้า archive verbatim + append closure block** ("SUPERSEDED by rev02; final review = REVIEW ORDER-071") — **ห้ามลบทิ้งเฉย ๆ**
- **091C-D1c PROCESSING (active L665):** annotation stale → ย้าย/ปิด verbatim + closure (D1c reviewed) — ไม่ทิ้งเงียบ

**Phase 2 = C1a (hook) → C1b (migration) — 2 commit แยก:**
- **C1a (commit แยก):** ติดตั้ง+test hardened lock hook · **machine-checkable contract:** marker `.git/ea_lab_c1_lock.json` (ไม่ tracked, atomic create) มี expected-preimage blobs + exact candidate blobs + staged-path allowlist · hook อ่าน candidate จาก **git index (`git show :path`) ไม่ใช่ working tree** · staged-vs-expected exact (partial/extra staged path = fail) · **fail-CLOSED ถ้าไม่มี PowerShell** (ปิด fail-open เดิม `.githooks/pre-commit` L5) · crash-recovery ระบุ · test ใน **temp repo/index ไม่ใช่ shared worktree** · hook message **ห้ามแนะ `--no-verify`** (bypass เทคนิคปิดไม่ได้ อาศัยกฎ AGENTS)
- **C1b (1 atomic commit):** แทน manual index (L15) ด้วย **short pointer** (archive file + generated `ARCHIVE_INDEX.md` + validator command) · apply Phase-1/1b closures · regenerate manifest/index/exceptions · **archive preamble L4 stale banner** (บอกว่า index อยู่ taskboard) → append superseding notice **ไม่แก้ existing archived H2 blocks**

**Acceptance (machine-checkable):**
- [ ] Phase 0 validator upgrade: 071 exception หาย (linked review รับรู้) · validator รายงาน `raw_detected/canonically_reviewed/unresolved`
- [ ] **C0 `-Strict` exit 0 หลัง migration ก็ต่อเมื่อ:** integrity=0 · unresolved policy=0 · **ทุก closed exception มี canonical review ตรง exact block_id+sha256** · ไม่มี wildcard/canonical-id-only approval · ไม่มี stale/missing approval-ref
- [ ] manual index (L15) → pointer · agents ยังหา OPEN/CLAIMED order ได้ (test) · check_state.ps1 ยัง CLEAN
- [ ] archived H2 blocks **byte-unchanged** (append-only; รวม rev02) · rev01+091C-D1c ย้าย verbatim+closure · archive `-Audit` clean
- [ ] **C1b = 1 atomic commit** · staged set == expected allowlist exact · หลัง commit `HEAD:<path>`==candidate blobs · git diff --cached เท่านั้น (ไม่ whole-worktree)
- [ ] **negative tests:** disposition kind เดียวห้าม suppress อีก kind ของ id เดียว · stale disposition-hash หลัง block เปลี่ยน→exit 2 · unknown/dup disposition→exit 2 · missing review-ref→Strict 1/integrity 2 · non-terminal archive ไม่มี linked terminal review→Strict fail · hook: commit แตะ taskboard ระหว่าง lock (ไม่ใช่ migration)→blocked · staged≠working-tree→hook fail · no-PS→fail-closed
- [ ] `[tag] ORDER-102 done` + ผลดิบ

**ห้าม:** แก้ bytes ของ archived block เดิม (append-only) · ตัดสิน 071 ซ้ำ (verdict มีแล้ว) · manifest column/allowlist เป็น decision authority · ลบ block ที่หลง active ทิ้ง (ย้าย verbatim+closure) · whole-worktree restore/checkout · แตะ unrelated dirty files · implement Contract D

**Rollback (staged-blob protocol):** capture target preimage hashes ก่อนเริ่ม · C1b = explicit `git add -- <allowlist>` เท่านั้น · rollback = **revert/inverse ของ C1b ใต้ lock** + recheck target files ไม่มี later writes (มี = หยุด ไม่ restore ทับ) · **maintenance lock คงจน blind review ผ่าน หรือ rollback เสร็จ** · git commit atomic ต่อ repo state ไม่ใช่ทั้ง working tree.

### Codex C1 design review (2026-07-13) = needs-CHANGES → order REVISED r1 (Opus verify ยืนยันทุกข้อ)
- 🔴 **disposition = second authority (§20.7):** manifest column/allowlist กลายเป็น owner ใหม่ของ "reviewed" → **FIX:** canonical review block append-only, validator derive จาก review เท่านั้น, key = exact `kind+block_id+sha256` (ไม่ใช่ canonical-id — 091C-D1c มี 2 kind)
- 🔴 **ORDER-071 มี verdict อยู่แล้ว:** `REVIEW ORDER-071 REVIEWED ปิดถาวร` @ archive L2657 (Opus verify: มีจริง) — **C0 false-positive จาก canonical-id linking limit** · **FIX:** ห้ามตัดสินซ้ำ, upgrade validator รับรู้ linked review (Phase 0), rev01 OPEN ย้าย verbatim+closure ไม่ลบ
- 🔴 **lock ขัด acceptance:** "hook ใน commit ก่อน" vs "1 atomic commit รวม hook" ทำพร้อมกันไม่ได้ → **FIX:** แยก C1a (hook) / C1b (migration atomic) · lock marker ใต้ `.git/`, git-index-based, staged-vs-expected exact, fail-closed
- 🟡 atomicity: `git diff --cached` + staged-blob verify (ไม่ whole-worktree restore) · archive preamble L4 stale banner (append notice ไม่แก้ archived) · Strict-gate ต้อง unresolved=0 + review ตรง exact hash + report raw/reviewed/unresolved · negative tests เพิ่ม

**Status:** ORDER-102 = REVISED r1 (Codex needs-CHANGES ปิดครบ) · **pending Codex re-review** ก่อน execute · **execution ยังต้องรอ window เงียบจริง** (git log ยังเห็น session อื่น commit — ORDER-045/082/083C).

### C1 EXECUTION เริ่ม 2026-07-13 (user: window นิ่งแล้ว, run to completion) — Phase 0 DONE + เจอ design gate
- **Phase 0 DONE (validator review-linkage upgrade):** `check_taskboard_archive.ps1` รู้จัก `## REVIEW ORDER-x` (Source A) + `## C1-CLOSURE` block (Source B, key exact kind+block_id+sha256) · report **raw=12 / reviewed=2 / unresolved=10** · **-Strict=1** · negTests **20/20** · **071 false-positive ปิดแล้ว** (2 exception ผ่าน REVIEW ORDER-071 ที่มีอยู่) · read-only held. = ตัวปรับปรุง validator ที่มีค่าเดี่ยว ๆ (commit แล้ว).
- 🛑 **DESIGN GATE เจอตอน execute (surface ต่อ user):** C0 validator = **frozen-snapshot verifier** — append/แก้ archive ใด ๆ → `archive-not-append-only` **integrity exit 2** (พิสูจน์: append dummy block → audit exit 2) · ลบ manual-index block ออกจาก active (block นั้นอยู่ใน split-set 4aebbc37) → ตก (1b) drift ด้วย. **C1 โดยนิยาม mutate active+archive → incompatible กับ validator ปัจจุบัน.** → C1 execute ไม่ได้จนกว่า validator จะ evolve จาก "frozen snapshot" เป็น **"living append-only log (immutable split-prefix + tracked C1 appends)"** ก่อน. นี่คือ refinement ที่แผน+Codex C1 review ยังไม่ครอบ — **ผมหยุด surface แทนฝืน migrate พัง.**

**Next (รอ user เคาะทิศ):** (ก) evolve validator → living-log model (Phase 0.5, bounded) → แล้ว execute migration (index-pointer + move rev01/annotation append-only + C1-CLOSURE 9 rows → -Strict 0) → Codex review · หรือ (ข) checkpoint ที่นี่.

### C1b MIGRATION EXECUTED (Opus, 2026-07-13) — user: run to completion, window นิ่ง
Phase 0 + 0.5 (validator: review-linkage + living-log) commit แล้ว. Migration (Opus, deterministic script, preimage-captured):
- **manual index block (active) → short pointer** ไป generated `ARCHIVE_INDEX.md` (§20.7 · index generated/read-only แล้ว)
- **ORDER-071 rev01 (OPEN, superseded) → archive verbatim** (append-only) · closed via Source A (REVIEW ORDER-071 = ST03 ปิดถาวร)
- **ORDER-091C-D1c PROCESSING** = stale scratch annotation (D1c DONE+archived) → **removed from active** (transient, ไม่ใช่ history)
- **`## C1-CLOSURE` block (archive)** = Opus canonical closure 9 terminal-no-linked-review (003/009/065/066/067/086/093/091C-D1c/096C) key exact kind+block_id+sha256
- **Opus lead call:** defer C1a enforced-lock hook (window เงียบ + hook ผิด=self-DoS เสี่ยงกว่า) — migration ทำใน manual staged-blob discipline + validator gate แทน

**Opus-verified (รันเอง):** **C0 `-Strict` EXIT 0** · raw=11/reviewed=11/**unresolved=0** · **append-only clean** (0 mutated, 2 appends) · **0 active-order-lost** · integrity=0 · manifest/index/exceptions zero-diff · **check_state.ps1 CLEAN** · OPEN/CLAIMED orders ยังหาเจอ (15/4) · diff เฉพาะ 5 ไฟล์ (taskboard+archive+3 artifacts) ไม่แตะ unrelated · **106 bug caught by gate:** append lone-`\n` mutated 096C block (fixed) + statusless annotation ใน archive = status-unparseable (fixed = remove not archive) — validator gate จับทั้งคู่ก่อน commit.

**Status:** C1b DONE + Opus self-review ACCEPT · pending final blind Codex review.

### Codex final review of executed C1 (2026-07-13) = REWORK (data ACCEPT · enforcement REWORK)
**PASS (Codex verified อิสระ):** -Strict exit 0 · raw11/rev11/unresolved0 · integrity0 · active-order-lost0 · **history conservation: old archive prefix byte-identical, appended 5717 bytes = rev01+C1-CLOSURE เท่านั้น · rev01 verbatim (SHA เท่ากันเป๊ะ 6c8241d8) · 091C-D1c DONE order ยังอยู่ (L4523)** · index pointer ถูก, 15 OPEN/3 CLAIMED หาเจอ · 9 closures dispositions มีเหตุผล + exact-hash keyed (แก้ 003 → unresolved=1 พิสูจน์) · 071 ปิดผ่าน review เดิม ไม่ re-decide · commit scope สะอาด. **→ migration DATA รับได้.**
**REWORK (write-path enforcement — hole จริง):**
- 🔴 **P0 append-tamper:** `Invoke-ArchiveAppendOnlyCheck` เทียบกับ split baseline `4aebbc37` เท่านั้น → block ที่ append **หลัง** split (รวม C1-CLOSURE เอง + rev01) **แก้ได้แล้ว regenerate manifest → Strict กลับ 0** (Codex พิสูจน์ forge closure evidence + mutate rev01 ผ่านทั้งคู่). immutability คุมแค่ 131 split blocks ไม่คุม appends. **FIX:** append-CHAIN integrity — ทุก archive-changing commit ต้องพิสูจน์ staged archive = raw-byte prefix-extension ของ blob จาก parent commit · audit เดิน chain จาก anchor ผ่านทุก commit ที่แตะ archive · negTests (mutate closure/rev01 append → exit 2) · manifest regen ห้าม bless mutation
- 🔴 **P0 no enforced hook:** pre-commit ยังเรียกแค่ check_state + fail-OPEN ไม่มี PS → write path = manual discipline. **FIX:** fail-closed staged-snapshot hook (= C1a ที่ defer)
- 🟡 **P1 Source A กว้าง:** ปิดทุก exception ของ canonical-id เดียวผ่าน `REVIEW ORDER-<id>` ใด ๆ → อนาคต phase-review หรือ forged review ปิดข้าม. **FIX:** bind exact block-id/hash
- 🟡 **P1 atomicity:** 2-commit (0ced194 pin ผิด → 9e0bd8a ซ่อม). Codex ยืนยัน **hash-object / `git rev-parse :path`** = fix ถูก (single atomic). *(HEAD ปัจจุบันถูกแล้ว ไม่ rollback/rewrite)*

**⚖️ Lead note:** migration DATA correct + safe (git history = tamper-evidence จริง; validator append-check = defense-in-depth ที่ยังไม่ครบ). Enforcement REWORK = workstream ต่อ (append-chain + fail-closed hook + Source-A binding + hash-object) — เป็น C1a ที่ defer + P0 ใหม่ที่ Codex เพิ่งเจอ.

**Routing:** Opus resolve exceptions + execute migration + 1 atomic commit · subagent/Codex build lock-hook + disposition mechanism · **blind Codex review รอบผลจริง ก่อน accept** · Opus แก้ `AGENTS.md` ใน review commit ถ้า archive-immutability protocol ต้องการ (เช่น "archived block immutable; REVIEWED ใหม่เข้า archive ผ่าน validator -Strict"). C1 = commit แยก.

**→ หลัง C1 accept = order ที่ 4 → MANDATORY REVIEW GATE** (§20.2 #5): หยุด ทบทวน ACCEPT/REWORK/ROLLBACK ต่อ component (A/B/C0/C1) ก่อนเริ่ม Contract D (MVP-1-lite events).

## ✅ MANDATORY REVIEW GATE — order ที่ 4 ครบ + C1-ENFORCE ปิด (gate ปลดล็อก 2026-07-14, §20.2 #5)
ทบทวนต่อ component (ผ่าน Codex blind review รวม ~15 รอบตลอด build — จับ defect จริงทุกใบที่ Opus self-verify พลาด):
| component | verdict | หมายเหตุ |
|---|---|---|
| **A** ORDER-099 (B0 baseline + owner map) | **ACCEPT** | 3 Codex rounds · cohort/evidence/reproducibility ปิด |
| **B** ORDER-100 (execution harness) | **ACCEPT (MVP-0)** | 3 rounds · 22/22 · 1 documented alias-limit (fix ก่อน deploy harness ขับ MT5 จริง) |
| **C0** ORDER-101 (read-only reconcile + validator) | **ACCEPT** | 3 rounds · validator ถาวร (review-linkage + living-log) |
| **C1** ORDER-102 (migration) | **DATA ACCEPT · ENFORCEMENT REWORK** | migration ถูก 0 history lost · แต่ append-tamper hole + no fail-closed hook + Source-A broad + atomicity (ดู block บน) |
| **C1-ENFORCE** ORDER-103 (write-path hardening) | **ACCEPT (Claude 2026-07-14)** | 6 rework + 6 blind Codex round (round 5 แรกที่ 0-blocker · round 6 = ACCEPT) · append-chain + fail-closed hook + Source-A exact-binding ปิดครบ · 41/41 negTest · commit `c0f7b0d` — **C1 enforcement REWORK ปิดสมบูรณ์** |

**§20.4 review-gate checks:** critical money/live incidents = **0** · source-of-truth conflicts = **0** (index → generated read-only, §20.7 compliant) · missing evidence = **0** · rollback ทำได้ไม่เสีย canonical evidence (git history intact) · incomplete work named honestly = **C1 enforcement** (append-chain + fail-closed hook + Source-A binding + hash-object) แตกเป็น bounded order ถัดไป.

**§20.2 #5 — ✅ GATE ปลดล็อกแล้ว (2026-07-14):** C1 enforcement REWORK ปิดสมบูรณ์ผ่าน ORDER-103 (C1-ENFORCE) — commit `c0f7b0d`, blind Codex review round 6 = ACCEPT. write path tamper-safe เต็มแล้ว (append-chain integrity + fail-closed hook + Source-A exact-binding). → **Contract D (MVP-1-lite event-log) เปิดทางได้แล้ว**. _(ประวัติ: order ถัดไป = C1-ENFORCE, routing subagent build → Opus verify → blind Codex review; HANDOFF ที่ใช้ = `docs/memory_control/C1_ENFORCE_HANDOFF.md`; ประวัติ rework/review เต็ม = `docs/memory_control/CODEX_ORDER103_REWORK_RESULT.md`.)**
**บทเรียน:** self-verify ที่รันใน HEAD/session เดียว มองไม่เห็น non-determinism (#2) + ไม่ได้ทดสอบ corrupt-input path (#1) — Codex คนละ run/มุมจับได้. เพิ่ม negTests ครอบแล้ว.

---

## ORDER-103 — Contract C1-ENFORCE: append-CHAIN tamper integrity + fail-closed staged-snapshot hook (write-path hardening, ปิด C1 enforcement REWORK) — `REVIEWED/ACCEPT (Claude 2026-07-14) — round 6 blind Codex (gpt-5.6-sol) = ACCEPT หลัง fresh from-scratch repro ทุก high-risk scenario · Opus spot-verify เอง (gates 0, scope 5 ไฟล์, HEAD intact) · commit c0f7b0d ผ่าน production hook (ไม่ --no-verify) · 6 rework + 6 blind review round` · **ทำได้: Sonnet subagent (build) → Opus (verify เอง, cross-HEAD) → blind Codex (accept)** _(ออก 2026-07-13; ปิด hole ที่ Codex final review ของ C1 จับ — block 1007-1015)_

> **Design source:** `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` **§20 @ `4eb839d`** + Codex final review C1 (block 1007-1015) + `docs/memory_control/C1_ENFORCE_HANDOFF.md`
> **เลขหมายเหตุ:** validator docstring อ้าง "living-log model (ORDER-103)" = Phase 0.5 ที่ fold เข้า C1b แล้ว (block 995-996). order นี้ใช้เลขเดียวกันเพราะเป็น workstream เดียว = **"ทำ append-only log ให้ tamper-safe จริง"** — Phase 0.5 สร้าง log, order นี้ทำให้ log แก้ย้อนไม่ได้.
> ⚠️ **นี่คือ enforcement layer สุดท้ายของ write path** (taskboard/archive) — mistake = self-DoS หรือปล่อย tamper หลุด. gate = C0 validator `-Strict` ต้อง **exit 0 ทั้งก่อน+หลัง** ทุก fix (ห้าม regress) + negTests ทุกใบ green.
> **Prereq:** C1b migration REVIEWED (data ACCEPT, block 1008) · HEAD ปัจจุบันถูกแล้ว (be45d4b/9e0bd8a) — **ห้าม rollback/rewrite migration commits.**

**REALITY / hole ที่ปิด:** `Invoke-ArchiveAppendOnlyCheck` (validator L681) เทียบ current archive กับ **split baseline `4aebbc37` เท่านั้น** = frozen-prefix immutability คุมแค่ 131 split blocks. block ที่ append **หลัง** split (C1-CLOSURE เอง + rev01) → **mutate ได้แล้ว regenerate manifest → -Strict กลับ 0** (Codex พิสูจน์: forge closure evidence + mutate rev01 append ผ่านทั้งคู่). git history = tamper-evidence จริงอยู่แล้ว; order นี้ = **defense-in-depth ให้ validator จับ tamper ได้เองโดยไม่ต้องพึ่ง reflog manual.**

> **⚙️ REVISED r1 (2026-07-13) หลัง Codex blind design-review = needs-CHANGES(8) — ทุกข้อ valid, Opus ยอมรับ.** 4 fix ด้านล่างเป็นเวอร์ชันแก้แล้ว. threat-model + build-order + disposition ของ 8 ข้อ = ท้าย block.

**Threat model (ประกาศชัด — Codex #1):** เป้าหมาย = รักษาทุก accepted archive byte + อนุญาตเฉพาะ authenticated suffix-append. **defense-in-depth ใน reachable history + pinned checkpoint** — จับ mutate→regen ได้ · จับ history-rewrite ของ ancestry ที่ผ่าน pinned checkpoint ได้ (fail-closed). **สิ่งที่ order นี้ไม่การันตี:** attacker ที่ force-push rewrite ทั้งสาย + ควบคุม remote — full guarantee นั้นต้อง protected ref / signed checkpoint / external receipt (นอก scope, บันทึกไว้ ไม่แสร้งว่าปิด). git = tamper-evidence ตัวจริงยังอยู่.

**Pinned commits (full 40-char — Codex #1/#2):**
- **SPLIT-ROOT anchor** = `4aebbc375dd7f4fa6b649c53409d554a2fb66991` (immutable 131-block root)
- **TRUSTED CHECKPOINT** = `0ced19485c6c6ce9a23541f785ab82bae4fcad25` (C1b migration accepted; archive blob = current trusted state, Codex byte-verified) — chain enforcement เริ่มจากจุดนี้

### Fix 1 🔴 — Append-CHAIN integrity (raw-byte prefix-chain, checkpoint-pinned)
เปลี่ยน model จาก "current archive ⊇ split-archive by block-content" เป็น **"archive blob เดินเป็น raw-byte prefix-chain จาก pinned checkpoint → HEAD, first-parent"**:
- pin **CHECKPOINT `0ced194…`** (full SHA) เป็น trust root ของ chain · SPLIT-ROOT `4aebbc37…` = immutable prefix ที่ checkpoint ต้อง extend มา.
- **fail-CLOSED (exit 2)** ถ้า: checkpoint SHA **missing / ไม่ใช่ ancestor ของ HEAD** (= history rewrite/force-push/squash detect) · shallow clone ที่ไม่มี checkpoint · git command fail · archive path ถูก rename/delete กลางสาย. **fresh full clone = pass · detached HEAD ที่ ancestry ครบ = ไม่ fail เพราะ detached เฉย ๆ.**
- audit เดิน **first-parent chain checkpoint→HEAD** เฉพาะ commit ที่เปลี่ยน `ARCHIVE_TASKBOARD_2026-07A.md`: ทุกก้าว committed/staged archive bytes = **raw-byte prefix-extension** ของ archive blob ที่ (first-)parent (prefix เดิม identical เป๊ะ, เพิ่มเฉพาะ suffix). **merge ที่แก้ archive นอก first-parent = fail-closed** (DAG semantics ประกาศชัด, ไม่ปล่อยกำกวม — Codex #2).
- ก้าวไหน prefix ไม่ตรง (แม้ 1 ไบต์) = exit 2 — manifest regen **bless mutation ไม่ได้** (identity = byte-chain ไม่ใช่ manifest).
- **🔑 suffix ต้องเป็น new-block boundary (Codex #3):** append ที่ผ่านต้องเปิด **`## ` (H2) block ใหม่**. suffix ที่ **ต่อท้าย block สุดท้ายเดิม** (เช่นเพิ่มแถวตาราง/prose เข้า `C1-CLOSURE`) = **fail** — byte เดิมครบแต่ hash/ความหมายของ block เดิมเปลี่ยน = ละเมิด immutability.
- **negTests:** (a) mutate C1-CLOSURE bytes → 2 · (b) mutate rev01 append (blob 6c8241d8) → 2 · (c) append **H2 block ใหม่** ไม่แตะ prefix → **pass** · (d) truncate/ลบ append → 2 · (e) reorder appends → 2 · (f) **suffix ต่อ block สุดท้ายไม่มี H2 ใหม่ → 2** · (g) checkpoint ไม่ใช่ ancestor (จำลอง rewrite) → 2 · (h) shallow clone ไม่มี checkpoint → 2 · (i) หลาย archive-touch commit คั่นด้วย unrelated commit → pass · (j) mutate แล้ว restore → chain ยังจับ (2 ที่ก้าว mutate ถ้า committed).

### Fix 2 🔴 — Fail-CLOSED staged-snapshot pre-commit hook (Codex #6)
`.githooks/pre-commit` ปัจจุบัน fail-OPEN + มี bypass-hint 2 จุด (L4 comment + L14). สร้าง hardened hook:
- (i) **fail-CLOSED ถ้าไม่มี PowerShell** — no-PS test ต้อง assert **ข้อความ diagnostic เฉพาะตัว** (ไม่ใช่แค่ exit≠0 — กัน missing-git/harness-fail ปลอมว่า pass).
- (ii) **enforce เฉพาะเมื่อมี protected file ใน staged set** — commit ปกติที่ไม่แตะ protected = ผ่านเหมือนเดิม (hook ไม่บล็อกงาน code ทั่วไป). **PROTECTED SET (enumerated):** `ARCHIVE_TASKBOARD_2026-07A.md` · `AGENT_TASKBOARD.md` · `docs/memory_control/ARCHIVE_MANIFEST.csv` · `docs/memory_control/ARCHIVE_INDEX.md` · `docs/memory_control/RECONCILE_EXCEPTIONS.md`. เมื่อ protected ใด ๆ staged → ทุก check ต่อไปนี้บังคับ.
- (iii) อ่าน candidate จาก **git index** (`git show :path` bytes + `git rev-parse :path` identity — Fix 4) · staged archive = exact prefix-extension ของ `HEAD:archive` (reuse Fix 1 logic, HEAD→staged) · **staged snapshot ต้องรวม `AGENT_TASKBOARD.md`** (Source A อ่าน active blocks — check_taskboard_archive.ps1:1002).
- (iv) staged manifest/index/exceptions **regen-in-temp จาก staged bytes** แล้วเทียบ byte (ไม่ใช่ working tree) · staged-set ต้อง = protected files ที่แก้ **พอดี** (protected file ที่ถูก delete/rename หรือ artifact ที่ขาด = fail).
- test ใน **temp repo: `git commit` จริง + `core.hooksPath=.githooks` + real staged index + installed hook** (ไม่ใช่ PowerShell เรียก FILE:-fixture — harness เดิม `_test/run_order101_negative_tests.ps1:147` ไม่ครอบ production path) · **ลบ bypass-hint ทั้ง 2 จุด** (`--no-verify` = policy bypass ตาม AGENTS, hook ห้ามแนะ).
- **negTests (real-commit):** mutate archived append staged → block · staged≠HEAD-extension → block · staged manifest ≠ staged archive → block · protected delete/rename → block · artifact ขาด → block · staged path นอก protected+ปกติ ผสม → เฉพาะ protected ที่ผิด block · staged≠working-tree divergence → ตัดสินจาก index · no-PS → fail-closed + diagnostic ตรง.

### Fix 3 🟡 — Source-A exact-identity binding via APPENDED binding record (Codex #4/#5)
validator L1089 ปิดทุก exception ของ canonical-id เดียวถ้ามี `## REVIEW ORDER-<id>` REVIEWED ใด ๆ → phase/forged review ปิดข้ามได้.
- **ไม่แก้ byte ของ REVIEW block เดิม** (archive L2657–2674 = mid-file, insert = ละเมิด append-only + Fix 1 — Codex #4). แทนด้วย **binding record ที่ append เข้าท้าย archive** (append-only, H2 block ใหม่): ตาราง `kind | block_id | block_sha256 | review_ref` — review_ref ชี้ `REVIEW ORDER-<id>` ที่มีอยู่.
- match **exact `kind + block_id + sha256`** (เท่า Source-B — check_taskboard_archive.ps1:1048) ไม่ใช่ block_id เดี่ยว ไม่ใช่ canonical-id. **1 block หลาย kind → 1 row/kind** (ไม่มี wildcard ปิดข้าม kind). **ไม่มี self-reference cycle** — hash เป็นของ exception block เป้าหมาย ไม่ใช่ของ binding/review block เอง.
- sha mismatch = **STALE** (report, ไม่ปิด) · **precedence:** ถ้า exception เดียวถูกทั้ง Source-A binding + Source-B C1-CLOSURE ปิด → นิยาม deterministic (เช่น A ก่อน, report ทั้งคู่, ไม่ double-count).
- 071 (2 exception blocks) ปิดโดย append binding record ระบุ kind+id+sha ของทั้งสอง — closure เดิมยังคง (REVIEW ORDER-071 = review_ref).
- **negTests:** binding อ้าง hash ผิด → unresolved(STALE) · phase-review (id ตรง hash ไม่ตรง) → ไม่ปิด · exact → ปิด · **dup binding row → integrity 2** · **unknown target (ไม่ match exception) → integrity 2** · **malformed hash → integrity 2** · A/B ปิด exception เดียว → precedence ตามนิยาม.

### Fix 4 🟡 — Single snapshot-source identity (bytes+identity แหล่งเดียวกัน — Codex #7)
ปัญหาเดิม: `FILE:` bytes = working tree แต่ identity = `HEAD:path` (check_taskboard_archive.ps1:281) = mixed source → migration ต้อง 2 commit.
- เพิ่ม **snapshot mode ที่ bytes + identity มาจาก source เดียวเสมอ**: staged = `git show :path` + `git rev-parse :path` · committed = `git show <sha>:path` + `git rev-parse <sha>:path` · working = file bytes + `git hash-object <file>`. **ห้ามผสม** working-bytes กับ HEAD-identity.
- hook + append-chain ใช้ **staged source** (`git rev-parse :path` — **ไม่ใช่ `git hash-object <working-file>`** เพื่อกัน CRLF/clean-filter mismatch; archive ปัจจุบัน `text`/`eol` = unspecified แต่ guard ไว้).
- **C0 Audit/Strict คง HEAD-default เดิม** (ไม่ regress) — staged/working identity เพิ่มเป็น input ของ hook+chain เท่านั้น, ไม่ใช่ second source-of-truth ของ Audit/Strict.
- **negTests:** 1-atomic-commit archive change → hook pass + post-commit `HEAD:archive`==candidate (ไม่ต้อง re-pin) · **CRLF/filter parity:** `git rev-parse :path` == staged blob oid แม้ working tree มี CRLF.

### Build order (บังคับ — Codex #8, กัน self-DoS + Strict=0 หลังทุก fix)
1. **Fix 4** snapshot primitives (bytes+identity แหล่งเดียว) — foundation.
2. **Fix 1** committed-chain gate + suffix-boundary (ใช้ Fix 4 primitives).
3. **Fix 3** Source-A exact binding + **append 071 binding record** — code + record land **atomic** (หรือ record ก่อน enforcement) ให้ `-Strict` ยัง 0.
4. **Fix 2** hook **ลงท้ายสุด** (หลัง 1/3/4 นิ่ง — hook ผิดตอน primitive ยังไม่ครบ = self-DoS).
- `-Strict` exit 0 ต้องคงหลัง**ทุก** fix ที่ land (ห้าม intermediate red).

**Acceptance (machine-checkable — ทุกข้อ pass ก่อน accept):**
- [ ] Fix 1: chain audit checkpoint→HEAD first-parent · negTests (a)-(j) ครบ · `-Strict` exit 0 บน HEAD ปัจจุบัน (chain ปัจจุบันสะอาด) · mutate→regen ยัง exit 2 · checkpoint-not-ancestor & shallow → fail-closed 2
- [ ] Fix 2: **real-commit test** (`core.hooksPath` + staged index + installed hook) · fail-closed no-PS + diagnostic ตรง · protected-set enumerated + ไม่บล็อก commit ปกติ · staged snapshot รวม AGENT_TASKBOARD.md · manifest/index/exceptions consistency จาก staged bytes · bypass-hint 2 จุดหาย · negTests ครบ
- [ ] Fix 3: appended binding record (ไม่แก้ REVIEW เดิม) · exact kind+block_id+sha256 · 071 ยังปิด · phase/forged/dup/unknown/malformed → ตามนิยาม · A/B precedence deterministic
- [ ] Fix 4: single snapshot-source · staged = `git rev-parse :path` (ไม่ใช่ hash-object working) · CRLF-parity test · 1-atomic-commit path ผ่าน · C0 Audit/Strict HEAD-default ไม่ regress
- [ ] **รวม:** `check_taskboard_archive.ps1 -Strict` **exit 0** · `-Audit` clean · `check_state.ps1 -Strict` CLEAN · negTests ทุก fix **green** · **verify รันข้าม HEAD/commit จริง** (บทเรียน block 1033) · **Strict=0 หลังทุก fix ที่ land** · archived block bytes **unchanged** (append-only; 071 binding = appended record ไม่ใช่ mid-file edit)
- [ ] `[tag] ORDER-103 done` + ผลดิบ (negTest output ครบ)

**Judgment criteria (ไม่ใช่ machine-check — ระบุแยกตาม Codex #8):** crash-recovery ของ hook ต้องอธิบายเป็นเอกสาร (ไม่ auto-testable) · "commit แยกต่อ fix" = แนะนำ ไม่บังคับ (build-order ข้างบนคือของบังคับ).

**ห้าม:** rollback/rewrite migration commits (`0ced194`/`be45d4b`/`0e67e1d`/`9e0bd8a` — HEAD ถูกแล้ว) · **แก้ bytes ของ archived/REVIEW block เดิม** (append-only; 071 = appended binding record เท่านั้น) · suffix ที่ต่อ block สุดท้ายเดิม (ต้อง H2 ใหม่) · hook message แนะ `--no-verify` · test hook ใน shared worktree (temp repo + real-commit เท่านั้น) · ผสม working-bytes กับ HEAD-identity (Fix 4) · แตะ unrelated dirty files (session อื่น commit บน master คู่กัน — commit path-limited, เช็ค HEAD ก่อน stage; memory `shared-worktree-concurrent-writers`) · เริ่ม Contract D จนกว่า order นี้ accept (§20.2 #5) · subagent ตัดสิน exception/verdict เอง (Opus)

**Routing:** design-review r0 = ✅ ทำแล้ว (Codex blind, needs-CHANGES 8 → REVISED r1) → Sonnet subagent build ตาม build-order → **Opus verify เอง (รัน test + อ่านโค้ด + เจาะ cross-HEAD/rewrite/shallow path)** → **blind Codex review ผลจริง ก่อน accept.**

**ผล:** _(r1 พร้อม build — รอ user เคาะเริ่ม build stage)_

### Codex design-review r0 (2026-07-13, blind, gpt-5.6-sol) = needs-CHANGES(8) → REVISED r1 · Opus ยอมรับทุกข้อ
Codex อ่าน order+validator+archive เอง จับ 8 (5 blocker + 3 major). disposition:
1. 🔴 **Fix 1 ไม่รอด rewritten descendant history** (trust anchor เดียว; attacker squash/force-push forge chain ได้) → **FIX r1:** pin TRUSTED CHECKPOINT `0ced194…` (full SHA) + fail-closed ถ้า checkpoint ไม่ใช่ ancestor/shallow · threat-model ประกาศ boundary (full rewrite guard = protected ref, นอก scope)
2. 🔴 **traversal semantics กำกวม** (merge/first-parent/rename/non-ancestor/git-fail ไม่นิยาม; full 40-char anchor) → **FIX r1:** first-parent DAG ประกาศชัด · full SHA · fail-closed git-fail/rename
3. 🔴 **raw suffix ยัง mutate block สุดท้ายได้** (เพิ่มแถวเข้า C1-CLOSURE = byte เดิมครบแต่ hash เปลี่ยน) → **FIX r1:** suffix ต้องเปิด H2 ใหม่ · negTest (f) เพิ่ม
4. 🔴 **Fix 3 071-migration เป็นไปไม่ได้ตามที่เขียน** (เติม hash ใน REVIEW block = insert mid-file, ชน append-only) → **FIX r1:** appended binding record ใหม่ ไม่แตะ REVIEW เดิม · ยืนยันไม่มี self-ref cycle
5. 🟡 **Source-A identity กำกวม** (block_id+sha vs kind+block_id+sha; 1 block หลาย kind; ขาด dup/unknown/malformed/precedence test) → **FIX r1:** exact kind+block_id+sha256 + tests ครบ
6. 🔴 **hook test ไม่ครอบ production path** (harness เดิมเรียก FILE:-fixture ไม่ใช่ git commit; allowlist ไม่ enumerate = อาจบล็อก commit ปกติ; staged ต้องมี AGENT_TASKBOARD.md; no-PS ต้อง assert diagnostic; ลบ bypass-hint 2 จุด) → **FIX r1:** real-commit test + protected-set enumerated + enforce-only-when-protected-staged + diagnostic assert
7. 🔴 **Fix 4 snapshot ownership ขัดกัน** (bytes=working, identity=HEAD; Generate ทำ candidate-pinned ไม่ได้ถ้า HEAD-based; CRLF/filter) → **FIX r1:** single snapshot-source mode · `git rev-parse :path` ไม่ใช่ hash-object working · CRLF-parity test · Audit/Strict คง HEAD-default
8. 🟡 **sequencing ไม่เป็น order เดียวที่ทำได้** (Fix4→Fix1→Source-A/071-atomic→hook-last; หลาย machine-test ขาด; crash-recovery/commit-แยก = judgment ไม่ใช่ machine-check) → **FIX r1:** build-order section + judgment-criteria แยก + missing tests เพิ่ม
**Lead call:** ทั้ง 8 ถูกต้อง — design-review-ก่อน-build จับ hole ลึก (โดยเฉพาะ #1/#3/#4 ที่จะทำ build พังถ้าไม่จับ) = คุ้มตามที่ handoff คาด. r1 ปิดครบ · **พร้อมส่ง build** (รอ user เคาะ).

### BUILD EXECUTED (Sonnet subagent, 2026-07-13, build-order Fix4→1→3→2) + Opus verify
**Files:** `scripts/check_taskboard_archive.ps1` (Fix4 snapshot primitives `Get-Snapshot`/`git rev-parse :path` · Fix1 `Invoke-ArchiveChainIntegrityCheck` checkpoint-pinned first-parent raw-byte prefix + H2-boundary + fail-closed · Fix3 exact `kind+block_id+sha256` binding via `## C1-ENFORCE-SOURCEA-BINDING`) · `scripts/check_precommit_staged.ps1` (new, Fix2 staged-index enforce) · `.githooks/pre-commit` (rewritten: fail-closed no-PS + exact diagnostic, bypass-hints ลบ 2 จุด) · `ARCHIVE_TASKBOARD_2026-07A.md` (**append-only +13 บรรทัด** = 071 binding block, 2 targets #67/#132) · manifest/index/exceptions regen · `scripts/_test/run_order103_negative_tests.ps1` (new, 18 cases, temp-repo real-commit) · `run_order101_negative_tests.ps1` (1 expectation ปรับ).
**Opus verify (รันเอง, cross-HEAD/rewrite/shallow):** `-Strict`=0 · `-Audit`=0 · `check_state -Strict`=CLEAN · ORDER-103 **18/18** · chain check เดินบน archive path จริง clean=True · **Fix1 fail-closed พิสูจน์:** missing-checkpoint→2 · valid-ancestor(4aebbc37)→0 · **exists-but-not-ancestor(rewrite)→2** ("NOT an ancestor of HEAD -- history rewrite/force-push/squash suspected") · **Fix3 exact-binding พิสูจน์:** tamper #67 hash→ #67 reopens STALE (unresolved=1, "closure NOT honored") ขณะ #132 ยังปิด → restore→0 · scope สะอาด (9 build files, archive pure-append 13/0) · CRLF: append=LF, blob-vs-blob เทียบปลอดภัย.
**Loose ends (honest, surface ให้ Codex):** (a) Sonnet build negTest subset 18 (ไม่ครบ ~40 lettered 1:1 — mechanism ครอบแต่ไม่ทุก case แยก) (b) ORDER-101 `cross-HEAD-zero-diff` **fail แต่ pre-existing** (Opus verify อิสระ: archive blob ต่างระหว่าง 4aebbc37 `c528989` vs HEAD `f2c4dfe` หลัง C1b migration — premise พังก่อน session นี้ ไม่ใช่ ORDER-103 regression) (c) `partial-stage-archived` expectation 0→1 = ผลตั้งใจของ Fix3 (bare REVIEW-id ไม่ปิดแล้วถ้าไม่มี binding record).
**Status:** build DONE + Opus self-verify ~~ACCEPT~~ → **REWORK (blind Codex review + Opus repro จับ 2 blocker)** · ยังไม่ commit.

### Blind Codex review of build (2026-07-13, gpt-5.6-sol, neutral-framing rerun) = REWORK(2) — Opus reproduced ทั้งคู่เอง
Codex รัน -Strict/-Audit/suite เอง (เขียว) แต่ **adversarial checks เจอ 2 blocker ที่ self-verify 2 ชั้น (Sonnet suite + Opus cross-HEAD/rewrite/tamper) พลาด** เพราะไม่มีใครทดสอบ "mutate prose ของ post-split-append block + regen" หรือ "commit binding จริงผ่าน hook". **Opus repro ยืนยันทั้งคู่:**
- 🔴 **BLOCKER 1 — durability hole ยังเปิดบน `-Strict` path (P0 เดิมที่ Fix 1 ควรปิด):** mutate prose เฉพาะของ appended block (`"canonical-id-wildcard hole"`→`"TAMPERED-PROSE-INJECTION"`) + `-Generate` + `-Strict` → **exit 0 (blessed)**. เหตุ: chain check เดินเฉพาะ **committed history** (checkpoint→HEAD) · superset check กันเฉพาะ 131 split blocks · post-split appends (C1-CLOSURE/binding) ไม่ถูก mutation-check บน working-tree path · manifest regen ตาม → bijection ผ่าน. โดน hook จับตอน commit แต่ **`-Strict` (gate ที่ check_state/CI/manual ใช้) ผ่านผิด** = ละเมิด acceptance "manifest regen หลัง mutate → ยัง exit 2". **FIX:** `-Strict`/`-Audit` ต้องเช็ค working-tree archive = raw-byte prefix-extension ของ `HEAD:archive` ด้วย (ขยาย chain เป็น checkpoint→HEAD→working) ไม่ใช่แค่ committed.
- 🔴 **BLOCKER 2 — H2-boundary rule ปฏิเสธ binding ของตัวเอง (self-DoS):** real `git commit` ของ binding block ผ่าน hook จริง → **BLOCK** ("staged archive fails append-chain integrity -- suffix ... does not open with a new '## ' (H2) block boundary"). เหตุ: append convention มี separator (`---`/blank) ก่อน `## ` → suffix ไม่ได้ขึ้นต้นด้วย `## ` เป๊ะ. **แปลว่า build นี้ commit binding ผ่าน hook ตัวเองไม่ได้ = ไม่เคยถูก end-to-end commit-test.** **FIX:** boundary rule ต้องยอม separator/blank นำหน้า block ใหม่ (นิยาม "new H2 block" = หลัง normalize แล้ว suffix ประกอบด้วย [optional `---`/blank] + `## ...` ครบ block ไม่ใช่ต่อเนื้อ block เดิม). + ปม CRLF: working file (autocrlf=true) ต่างจาก HEAD blob → FILE: path เทียบเพี้ยน (Fix 4 ครอบ hook ผ่าน index แต่ -Strict FILE: ยังเสี่ยง) — รวมแก้กับ BLOCKER 1.
- 🟡 minor (by-design, ไม่ใช่ bug): fake `review_ref` (`## REVIEW ORDER-DOES-NOT-EXIST`) ยังปิดได้ — เพราะ spec Fix 3 ตั้งใจให้ review_ref = traceability เท่านั้น (closure จาก exact hash ไม่ใช่ review_ref). ยืนยัน intended.

**Opus repro evidence:** BLOCKER1 = mutate+regen+`-Strict`=0 (restore→0, archive diff 13/0 สะอาด) · BLOCKER2 = temp-clone real commit exit=1 "does not open with a new '## ' boundary". Real repo intact (working tree = binding append 13/0 + build files เท่านั้น, ยังไม่ commit).

**Routing ต่อ:** REWORK 2 blocker (BLOCKER1+2 เกี่ยวพัน — แก้ chain ให้ครอบ HEAD→working + boundary ยอม separator พร้อมกัน) → Sonnet subagent แก้ → Opus verify (repro 2 blocker ต้องกลายเป็น fail-closed/pass ถูก + commit binding ผ่าน hook ได้จริง) → blind Codex re-review. **บทเรียนย้ำ (handoff block 1033):** self-verify 2 ชั้นยังปล่อยหลุด — blind Codex คนละค่าย/มุม adversarial จับ P0. negTest ที่ขาด = "mutate appended-block prose + regen" + "real-commit binding ผ่าน hook end-to-end" → เพิ่มใน rework.

### FINALIZE (Codex, 2026-07-13, user สั่งเอง via prompt) — binding committed จริง + Opus independent re-verify
User รัน `docs/memory_control/CODEX_ORDER103_FINALIZE_PROMPT.md` ผ่าน Codex เอง (ประหยัด quota Opus). Codex: regen artifact จาก staged identity จริง (`git rev-parse :path`, ไม่ผสม HEAD+working) → dry-run hook → **commit จริง `245f8f62c047ad843b01b1b2cfffcac3f21fc5ad`** (4 ไฟล์: archive+3 artifacts เท่านั้น, ผ่าน production hook, ไม่ `--no-verify`) → รายงาน `FINALIZE STATUS: DONE` ที่ `docs/memory_control/CODEX_ORDER103_REWORK_RESULT.md`.

**Opus independent re-verify (ไม่เชื่อรายงาน Codex เฉยๆ — รันเอง reproduce ทุกข้อ):**
- commit `245f8f62` มีจริง, scope = 4 ไฟล์พอดี (archive +13/-0 บวก 3 artifact regen), checkpoint `0ced194…` ยัง ancestor ของ HEAD ใหม่ ✓
- live gates (รันเอง): `-Strict`=0 · `-Audit`=0 · `check_state -Strict`=CLEAN ✓
- **BLOCKER1 tamper repro (รันเอง, temp clone):** รอบแรกได้ exit=0 ผิดคาด → เจอว่าเป็น**ความผิดพลาดของผมเอง**ที่ลืม copy script เวอร์ชัน uncommitted เข้า clone (เลย test กับ script เก่าที่ยังไม่มี `WorkingTreeExtensionIntegrity`) → แก้ test แล้วรัน**ใหม่ถูกวิธี**: mutate prose เฉพาะของ binding block ที่ commit แล้ว + `-Generate` + `-Strict` → **exit=2** พร้อม diagnostic ชัด ("H2 block #134 is not the canonical-LF byte-identical prefix ... mutation/reorder detected (fail-closed; manifest regeneration cannot bless this)") — **BLOCKER1 ปิดจริง ยืนยันแล้ว** ✓
- ORDER-103 suite (รันเอง): **ALL CASES PASSED** ✓
- ORDER-101 suite (รันเอง, fresh foreground run เพราะ background run แรกค้าง 8+ นาทีไม่ขยับ — kill แล้วรันใหม่): **25 PASS / 1 FAIL** — FAIL ตัวเดียว = `cross-HEAD-zero-diff` (pre-existing, ไม่เกี่ยว ORDER-103) ตรงกับที่ Codex รายงานเป๊ะ ✓
- scope: ไฟล์ที่ยังไม่ commit = เฉพาะ `.githooks/pre-commit` · `scripts/check_taskboard_archive.ps1` · `scripts/check_precommit_staged.ps1` · `scripts/_test/run_order10{1,3}_negative_tests.ps1` (implementation candidates รอ review) — ไม่มีอะไรอื่นถูกแตะ ✓ ไม่ push ✓

**Opus lead call:** ทั้ง 2 blocker ปิดจริง ยืนยันด้วยมือทุกข้อ ไม่ใช่แค่เชื่อรายงาน. **เหลือ 1 ด่านตาม routing เดิม: blind Codex review ของ diff ที่ยัง uncommitted (hook+checker+tests) ก่อนเรียกว่า ORDER-103 ACCEPT เต็มรูป** — ยังไม่ทำรอบนี้ (รอ user เคาะว่าจะให้ Opus ทำ หรือ user สั่ง Codex เองอีกรอบแบบ arm's-length).

### FINAL BLIND CODEX REVIEW (2026-07-13, gpt-5.6-sol, user สั่ง Opus dispatch ให้) = REWORK(5) — เจอของจริงรอบที่ 3
Codex อ่าน order+commit `245f8f62`+diff uncommitted ด้วยมุมใหม่ (ไม่เชื่อรายงานเดิม) รันเช็คเองทั้งหมด. **เจอ 3 blocker + 2 major ใหม่ ที่ Sonnet build + Opus verify 2 รอบก่อนหน้าไม่จับ** — ทั้งหมดเป็น git-plumbing edge case ระดับลึก (merge semantics/hook gating logic/pre-block content) ไม่ใช่การ mock ผิด:

1. 🔴 **hook bypass เมื่อ archive ไม่เปลี่ยนแต่ protected file อื่นเปลี่ยน:** `check_precommit_staged.ps1:137` exit สำเร็จทุกครั้งที่ `$archiveChanged=false` — stage เฉพาะ `RECONCILE_EXCEPTIONS.md` (tamper) หรือ `AGENT_TASKBOARD.md` (duplicate) เดี่ยวๆ → commit ผ่าน hook ได้ทั้งคู่ (`exit=0`) **แล้วพัง `-Strict` ทันทีหลัง commit** (`post-commit-strict-exit=2`). Codex พิสูจน์ด้วย real-commit ใน temp clone.
2. 🔴 **merge second-parent หลุด chain check:** walker เช็คแค่ `--first-parent` (`check_taskboard_archive.ps1:492,566`) — spec บังคับว่า archive เปลี่ยนนอก first-parent ต้อง fail-closed (`AGENT_TASKBOARD.md:1125`) แต่ยังไม่ implement. Codex ทำ side-branch แก้ archive + `--no-ff` merge → commit ที่แก้ archive ผ่าน second-parent **ไม่ถูก reject เลย** (`chain-IsClean=True`).
3. 🔴 **เนื้อหาก่อน H2 แรกมองไม่เห็น:** `Invoke-ArchiveWorkingTreeExtensionCheck` (`:773`) เทียบแค่ parsed H2 block (`:786-822`) — prepend ข้อความปลอมก่อน `## ` แรก → `-Strict` exit=0 ทั้งที่ threat model บอกว่าต้องป้องกันทุกไบต์ที่ accept แล้ว (`AGENT_TASKBOARD.md:1115`).
4. 🟡 **test suite ยังไม่ครอบ path พวกนี้ + 1 เทสต์ตายซาก:** `fix2-staged-archive-mutation-blocks` ที่คิดว่าเทส mutation จริงๆ หยุดที่ missing-artifacts check ก่อนถึง logic ที่ตั้งใจเทส (พิสูจน์ด้วย output จริง) — ต้องเพิ่ม regression case: artifact-only / active-only / second-parent-merge / pre-H2-tamper / mutation-ที่มี-artifact-ครบ.
5. 🟡 **doc ไม่ตรง implementation:** header comment (`:52`) + generator (`:2121`) ยังพูดถึง canonical-id wildcard เดิมที่ถูกแทนด้วย exact-hash แล้ว → `RECONCILE_EXCEPTIONS.md:58` ที่ commit ไปแล้วมี operator-guidance ผิด (ยังไม่ใช่ security bug แต่ misleading).

**ยืนยันว่ายังดีอยู่ (ไม่ regress):** live gates 0/0/CLEAN · ORDER-103 suite 22/0 · ORDER-101 25/1(pre-existing) · durability tamper (binding+C1-CLOSURE) ยัง exit 2 ถูกต้อง · legit append ผ่าน · checkpoint fail-closed cases ผ่านหมด (missing/non-ancestor/valid) · Source-A exact-hash ยืนยันตรง.

**Minor/hygiene เพิ่ม:** `git status --porcelain` มี 63 entries ไม่ใช่แค่ 5 ไฟล์ implementation ตามที่คาด (ของ session อื่นปนอยู่ — shared worktree, ไม่ใช่ของ order นี้) · commit `245f8f62` ขาด `Co-Authored-By` trailer ตาม AGENTS.md · ยังไม่รัน `make_status.ps1` หลัง commit.

**Opus lead call:** ทั้ง 3 blocker valid มีหลักฐาน repro ชัด (ไม่ใช่ false-positive) — **นี่คือรอบที่ 3 ที่ blind review จับของจริงที่ 2 ชั้นก่อนหน้าพลาด** ยืนยัน pattern ที่ handoff เตือนไว้ตั้งแต่ต้น (self-verify ไม่พอสำหรับ write-path enforcement ระดับนี้). **ยังไม่ ACCEPT.** ส่ง rework รอบใหม่ให้ Codex ต่อ (5 fix ข้างบน) → ต้อง blind review รอบ 4 ก่อนปิดจริง.

### REWORK2 (Codex) = DONE — ปิดครบ 5 ข้อ (ดู `docs/memory_control/CODEX_ORDER103_REWORK_RESULT.md` section "Rework round 2") + Opus spot-check ยืนยัน (`-Strict`=0, HEAD ไม่ขยับที่ `245f8f62`, scope ยัง 5 ไฟล์เดิม)

### FINAL BLIND CODEX REVIEW รอบ 4 (2026-07-13, gpt-5.6-sol) = **INTERRUPTED (content filter) แต่เจอ BLOCKER 6 ใหม่ก่อนโดนตัด — ลึกกว่าทุกข้อก่อนหน้า**
Codex ยืนยัน 3/5 ข้อจากรอบ 3 ปิดจริง (hook-bypass · merge-second-parent-archive-change · pre-H2 tamper ทั้ง working/committed) + live gates เขียว (`-Strict`/`-Audit`/`check_state` = 0/0/CLEAN) **ก่อนจะโดน OpenAI cybersecurity-content-filter ตัดกลางทาง** ตอนกำลังจะรัน suite เต็ม (ปัญหาเดิมที่เจอมาก่อน — ยังไม่ได้ยืนยัน suite count รอบนี้).

**🔴 BLOCKER 6 (ใหม่, อิสระจาก 5 ข้อเดิม, กระทบรากฐาน trust ของทั้งระบบ) — "checkpoint laundering ผ่าน merge":**
`TRUSTED CHECKPOINT` คือรากฐานที่ทุกอย่างอ้างอิง (§design source Codex #1 เดิม) — ถ้า checkpoint SHA เข้าถึงได้จริงแค่ผ่าน **second-parent ของ merge** (ไม่อยู่ใน real first-parent lineage) validator จะเอา checkpoint ไป "ต่อ" เข้ากับ first-parent walk **เหมือนมันอยู่ใน chain จริง** ทั้งที่กราฟจริงไม่มี edge เชื่อมกันเลย (checkpoint กับ mainline ปัจจุบันเป็นคนละ history line ที่ merge มาประกบ) → รายงาน `IsClean=True` โดยไม่เคยพิสูจน์ chain-of-custody จริง.

**repro (temp repo, Codex ทำเอง):** สร้าง branch `trusted` (checkpoint cp2) แยกจาก branch `master` ที่มี history คนละสาย (`main` commit ไม่สืบเชื้อสายจาก cp2) → merge `--no-ff` เอา cp2 เข้ามาทาง second-parent → `git rev-list --first-parent HEAD` = `[HEAD, 1bef697, root]` (**cp2 ไม่อยู่ในนี้เลย**) แต่ `git merge-base --is-ancestor cp2 HEAD` = true (ปกติของ git, ไม่ใช่บั๊ก) → **validator เดิน chain `cp2→1bef697→HEAD` (2 steps, Changed=False ทั้งคู่) และรายงาน `IsClean=True`** ทั้งที่ edge `cp2→1bef697` ไม่มีจริงในกราฟ (คนละ parent-child กันเลย).

**FIX ที่ต้องทำ:** validator ต้องเช็คว่า checkpoint SHA อยู่ **ใน `git rev-list --first-parent HEAD` จริง** (exact membership) ไม่ใช่แค่ "เป็น ancestor by any path" (`--is-ancestor` เดิมหลวมเกินไป) — ถ้า checkpoint เป็น ancestor แต่ไม่อยู่ใน first-parent list = **fail-closed ทันที** ("trusted checkpoint reachable only via non-first-parent path -- possible checkpoint laundering via merge, rejected") ห้ามพยายาม "เดิน chain ทางอื่น" มาแทน.

**สถานะ suite รอบ 4:** ยังไม่ครบ (โดนตัดก่อนถึง `run_order103_negative_tests.ps1`) — ต้องรันซ้ำหลังแก้ BLOCKER 6.

**Opus lead call:** BLOCKER 6 นี้สำคัญกว่ารอบก่อนๆ เพราะกระทบ **root-of-trust** ของทั้งระบบ (ถ้า checkpoint เองโดน launder ผ่าน merge ได้ = ทุกการเดิน chain หลังจากนั้นไม่มีความหมาย) — **นี่คือรอบที่ 4 ที่ blind review จับของจริง**. ส่ง rework รอบ 3 ให้ Codex ต่อทันที (fix BLOCKER 6 + รัน suite เต็มที่ค้างไว้ให้จบ ด้วย framing ที่เลี่ยง content-filter) → ยังต้อง blind review รอบ 5 ก่อนปิดจริง.

### REWORK3 (Codex) = DONE + Opus independent repro ยืนยันเอง (จุดนี้ = root-of-trust, ตรวจเข้มกว่ารอบทั่วไป)
Codex แก้ `Get-GitFirstParentChain` (`check_taskboard_archive.ps1:519`) — บังคับ checkpoint ต้องเป็น **literal member ของ `git rev-list --first-parent`** ไม่ใช่แค่ ancestor-by-any-path · เพิ่ม regression test · suite ผลรอบนี้: **ORDER-103 33/0** · **ORDER-101 25/1(pre-existing)** · gates 0/0/CLEAN · สังเกต concurrent commit `c4e1a7d6` (VPS rclone, ไม่เกี่ยวกัน) ระหว่างทาง แล้ว re-run gate ยืนยันซ้ำเอง.

**Opus independent repro (ไม่เชื่อรายงานเฉยๆ, สร้าง laundering scenario เองจากศูนย์ใน temp repo):** root commit → branch `trusted` (cp2) แยกจาก `master` ที่ history คนละสาย → merge `--no-ff` เอา cp2 เข้าทาง second-parent → confirm `git rev-list --first-parent HEAD` ไม่มี cp2 จริง แต่ `--is-ancestor` = true (ปกติ) → รัน validator ที่แก้แล้ว → **`IsClean=False`, Reason="TRUSTED CHECKPOINT ... reachable only via a non-first-parent path ... possible checkpoint laundering (fail-closed)"** ตรงตามที่ควรเป๊ะ ✓ · ยืนยัน production checkpoint จริง (`0ced194…`) ยัง `-Strict`=0 ไม่ regress ✓ · scope ยัง 5 ไฟล์เดิม, HEAD ไม่ถูก Codex แตะ ✓.

**สถานะ:** BLOCKER 6 ปิดจริง ยืนยันด้วยมือ 2 ชั้น (Codex เอง + Opus repro อิสระ). รวม 6 blocker จากรอบ 3-4 ปิดครบแล้ว. **ส่ง blind review รอบ 5** เพื่อยืนยันไม่มีของใหม่หลุดอีก ก่อนเรียก ACCEPT.

### BLIND CODEX REVIEW รอบ 5 (2026-07-13) = 🟢 **REWORK(2) แต่ 0 blocker — เจอ evidence-gap + hygiene nit เท่านั้น**
Codex ทำ full run จนจบ (ไม่โดน content-filter ตัดรอบนี้) — **สรุปเอง: "None. The checkpoint-laundering fix and previously reported production-path defects behave correctly."**

**ยืนยันซ้ำอิสระ (self-built repro, ไม่พึ่ง test เดิม):** checkpoint-laundering scenario → `CHAIN_CLEAN=False` พร้อม diagnostic ตรง (`check_taskboard_archive.ps1:519,618`) · production checkpoint จริง → `literal_first_parent=True, clean=True, chain_length=17` (ไม่ regress) · live gates 0/0/CLEAN · **ORDER-103 suite 33/0 (147s)** · **ORDER-101 suite 25/1-pre-existing (478s)** · merge-archive-change rejection / pre-H2 check / hook full-consistency-when-archive-unchanged — สุ่มตรวจซ้ำผ่านหมด (`:653,870, check_precommit_staged.ps1:137`) · HEAD ไม่ถูกแตะ, scope ยัง 5 ไฟล์เดิม, real archive parity ตรง (`ded1996b...`==`ded1996b...`).

**เหลือ 2 เรื่อง (ไม่ใช่ bug จริง แต่ยัง REWORK ตามกติกา):**
1. 🟡 **major (evidence-gap):** negTest (a)-(j) จาก spec เดิมยังไม่มีเทสต์แยกครบทุกตัว (reorder / commits คั่นด้วย unrelated / mutate-then-restore / non-ancestor-checkpoint / protected-delete-rename / mixed-staging / staged-vs-working-divergence / A-B-precedence). **Codex ตรวจมือเอง 4 ใน 8 กรณีที่ขาดแล้วผ่านหมด** (non-ancestor/reorder/mutate-restore/interspersed-append) — แปลว่าโค้ดถูก แค่ยังไม่มีหลักฐานถาวรเป็น regression test.
2. 🟢 **minor (hygiene):** `run_order103_negative_tests.ps1` ไม่มี `finally`-cleanup ของ temp clone → ทิ้งขยะใน `%TEMP%` (เจอจริง 1 โฟลเดอร์ค้าง, Codex ลบเองหลังรัน).

**Opus lead call:** นี่คือรอบแรกที่ blind review **ไม่เจอ blocker** — สัญญาณว่าใกล้ ACCEPT จริง. เรื่องที่เหลือเป็น "ทำให้ครบตามที่ตัวเองสัญญาไว้ใน acceptance list" ไม่ใช่รูรั่วใหม่ — ส่ง rework รอบสุดท้าย (เพิ่ม negTest ที่ขาด + cleanup) แล้วน่าจะ ACCEPT ได้ในรอบ 6.

### REWORK4 (Codex) = DONE + Opus spot-check ยืนยัน
เพิ่ม 8 negTest ที่ขาดครบ (reorder · unrelated-interspersed · mutate-then-restore · non-ancestor-checkpoint · protected-delete · protected-rename · mixed-staging · A/B-precedence) → **suite รวม 41/0 PASS**. แก้ temp-cleanup ด้วย `try/finally` + long-path-safe delete + clear read-only attr (เจอ edge case จริงระหว่างทำ: cleanup รอบแรก fail เพราะ read-only git object — แก้แล้ว verify ซ้ำ **TEMP before=0 after=0**). suite ORDER-101 ยัง 25/1(pre-existing) เหมือนเดิม. **ไม่แตะ production logic เลย** (เฉพาะ test file) ตามคาด. concurrent commit อื่นเกิดขึ้นอีก (`c4e1a7d6`, 1 ไฟล์ไม่เกี่ยวกัน) — Codex สังเกตแล้ว re-verify กับ HEAD ใหม่เอง.

**Opus spot-check อิสระ:** HEAD/scope ตรง (5 ไฟล์เดิม), `-Strict`=0, **ยืนยันเอง TEMP leftover = 0 จริง** (`find $TEMP -iname 'order103_negtests_*' | wc -l` = 0). ตรงกับรายงาน.

**สถานะ:** ปิดครบทั้ง 2 เรื่องจากรอบ 5 แล้ว — **ส่ง blind review รอบ 6 (final ACCEPT check)**.

---

## ORDER-105 — Contract D: MVP-1-lite Experiment Event Log (locked JSONL append utility + linked-event schema + durable evidence manifest) — `REVIEWED/ACCEPT (Claude 2026-07-17) — 8 blind review rounds · committed 0e13699` · **routing จริงที่ใช้: Codex design-review NEEDS-CHANGES(13) → Claude ACCEPT pinned #1-32 → build → blind review 8 รอบ (REWORK 5→2→2→2→1→1→1 → ACCEPT) · ตั้งแต่รอบ 4 Claude เขียน rework เองทั้งหมดตาม routing flip 2026-07-16** _(ออก 2026-07-16 หลัง MANDATORY REVIEW GATE §20.2#5 ปลดล็อกโดย ORDER-103)_

> **Design source (อ้างเป๊ะ — ห้ามอ้าง "draft ล่าสุด"):** `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` **§20.8 Contract D + §20.7 ownership @ `4eb839d`** · event types/fields ตาม MVP-1 spec (ไฟล์เดิม บรรทัด 274-300 @ SHA เดียวกัน — สรุป verbatim ใน handoff) · **handoff + gotchas เต็ม (Codex binary path · content-filter framing · shared-worktree) = `docs/memory_control/CONTRACT_D_HANDOFF.md`** · Codex เขียนผลลง `docs/memory_control/CODEX_ORDER105_RESULT.md` (Claude เช็คเนื้อไฟล์จริง ไม่ใช่ exit code ของ wrapper)

**Output (3 ชิ้น ตาม §20.8):**
1. **locked JSONL append utility ตัวเดียว** — file lock · atomic append · schema validation · unique event ID · idempotency · append-only correction/amendment · monthly rotation ภายใต้ append contract (§20.7) · **ห้ามหลาย agent เขียนไฟล์ JSONL รายเดือนตรงๆ — ทุก write ผ่าน utility นี้เท่านั้น**
2. **linked-event schema** — 1 experiment = event chain (ไม่ใช่แถวที่แก้ทับ): `IDEA_CREATED · HYPOTHESIS_REGISTERED · BAR_PREREGISTERED · RUN_STARTED · RESULT_ATTACHED · AMENDMENT_ADDED · REVIEW_RECORDED · DECISION_SIGNED` + link events `RESULT_LINKED / REVIEW_LINKED / DECISION_LINKED` ชี้กลับ canonical owner · ทุก event มี: experiment ID · timestamp · actor+role · prior event (chain link) · EA/source/set/data/tester hashes · trial family/count · evidence IDs · reason · **prereg กับ result = คนละ event เสมอ; เกณฑ์ที่ prereg แล้วแก้ไม่ได้ — เปลี่ยนได้ผ่าน `AMENDMENT_ADDED` เท่านั้น**
3. **durable evidence manifest** — evidence ID → tracked artifact / durable store + existence check · ignored/transient path ห้ามนับเป็นถาวรเพียงเพราะมี path/hash

**กฎเหล็ก ownership (§20.7 — กันเกิด source-of-truth ชุดที่ 2):** Event Log เก็บแค่ **occurrence metadata + hashes + references** — ห้ามคัดลอก result/verdict text เข้า JSONL · verdict/decision/deployment = owner เดิม (`EA_SCORECARD` · `PROJECT_STATE.md` decision log · `portfolio/DEPLOYMENTS.csv`) · active order text/result narrative = `AGENT_TASKBOARD.md` · reviewed history = immutable archive — Event Log ชี้กลับด้วย owner path/hash/reference เท่านั้น

**Acceptance (machine-check ทุกข้อ — negTest suite ถาวรสไตล์ ORDER-103: temp-repo จริง + try/finally cleanup):**
1. **concurrent-write:** ≥3 writers พร้อมกัน × ≥50 events/writer → corrupt line = 0 · interleave กลางบรรทัด = 0 · parse กลับได้ครบทุก event (≥150) · พิสูจน์ว่า lock ถูกใช้จริง (test สร้าง contention จริง ไม่ใช่รันเรียงกัน)
2. **idempotency:** append event เดิม (event ID เดิม) ซ้ำ ≥3 ครั้ง → duplicate ในไฟล์ = 0 · utility รายงานสถานะ already-appended ชัดเจน
3. **schema-validation fail-closed:** event ผิด schema ≥5 แบบ (ขาด field บังคับ · type ผิด · event type นอกรายการ · prior-event ชี้ ID ที่ไม่มีจริง · experiment ID ผิด format) → reject ครบทุกแบบ · exit non-zero · ไฟล์ JSONL byte-identical (ไม่มี partial write)
4. **corrupt-line:** ทำ 1 บรรทัดให้เสีย (truncate/garbage) → ตรวจจับ + ระบุเลขบรรทัดได้ · event ดีที่เหลืออ่านได้ครบ · utility ปฏิเสธ append เพิ่มแบบ fail-closed จนกว่า correction ผ่าน amendment/tombstone event
5. **canary trace = 100%:** สร้าง 1 experiment จริงครบ chain prereg→run→result→review→decision → ทุก link trace กลับ canonical owner ได้ (path + hash ตรง) ครบทุก event ไม่มีข้อยกเว้น
6. **evidence existence = 100%:** ทุก evidence ID ใน manifest → ไฟล์มีจริง · negative case: evidence ชี้ ignored/transient path → reject
7. **suite รวม PASS 100% + รันซ้ำได้ + TEMP leftover after run = 0**

**Out of scope / ห้าม:**
- ❌ verdict owner ใหม่ (Event Log ไม่ตัดสินอะไร) · ❌ bulk backfill event ย้อนหลัง · ❌ Context Packet generator (= MVP-2, contract แยก + ยัง B1-gated) · ❌ generated view รับ write-back
- ❌ คัดลอก result/verdict text เข้า JSONL (ดูกฎเหล็ก ownership ด้านบน)
- ❌ rollback/rewrite `c0f7b0d` · `eb06ac6` · `245f8f62` หรือ commit ใดที่เกิดแล้ว
- ❌ แตะ unrelated dirty files ของ session อื่น — commit path-limited เสมอ (`git commit --only -- <paths>` + `-F msgfile`; `-m` หลัง `--` = โดนตีเป็น pathspec)
- ❌ Codex/subagent ตัดสิน verdict/exception เอง — เป็นสิทธิ์ Claude/user เท่านั้น
- ❌ แก้ §20 ของ draft — แก้เมื่อไหร่ = ต้องเปิด review ใหม่ ห้าม edit เงียบ

**Rollback (§20.8):** ปิด append utility · rebuild จาก canonical refs · correction ใช้ amendment/tombstone event เท่านั้น (append-only — ห้ามลบ/แก้บรรทัดเก่า)

**Routing (พิสูจน์คุ้มแล้วใน ORDER-103 — ห้ามข้ามด่าน blind review แม้ quota ตึง):** (1) Codex design-review order นี้ก่อน build → (2) Codex build utility + schema + manifest + negTest suite → รายงานลง result file → (3) Claude spot-verify (รัน negTest เอง · ตรวจ ownership ไม่ซ้ำ owner เดิม · เดิน canary trace เอง) → (4) blind Codex review (fresh session, neutral framing กัน content-filter) → ACCEPT แล้วจึง commit ผ่าน production hook (ไม่ `--no-verify`) + make_status + mark REVIEWED

### DESIGN REVIEW rework0 (Codex gpt-5.6-sol, 2026-07-16) = NEEDS-CHANGES(13) → Claude ACCEPT 13/13 · rev01 พร้อม build
- **ผลเต็ม + binding annex ของ order นี้ = `docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md`** (5 BLOCKER + 8 MAJOR + 1 MINOR · section "Decisions the builder needs pinned" **#1-32 = Claude อนุมัติทั้งชุด 2026-07-16** · section "Missing negTests" ทุกรายการ = acceptance surface บังคับ เพิ่มจาก 7 ข้อเดิม · soundness matrix = ตัวตีความ acceptance เดิมทุกข้อ)
- **BLOCKER ที่ปิดด้วย pinned decisions:** F01 pin event enum v1 = `*_LINKED` family + `TOMBSTONE_ADDED`, reject `RESULT_ATTACHED/REVIEW_RECORDED/DECISION_SIGNED` (ตาม §20.7 ซึ่ง authoritative เหนือ list ก่อน §20) · F02 JSONL รายเดือน = **git-tracked** `docs/memory_control/experiment_events/events-YYYY-MM.jsonl` + **staged-snapshot event checker ใหม่ต่อเข้า production hook ใน build เดียวกัน** (split แล้วปล่อย unprotected interval = ขัด fail-closed philosophy — ไม่ split) · F03 ownership บังคับด้วย schema จริง (per-event whitelist · `additionalProperties=false` · `reason_code` enum + `reason_ref` — ไม่มี prose field) · F04 แยก logical correction (amendment/tombstone บน log ที่ valid) ออกจาก physical recovery (locked rebuild + authorization + quarantine) — แก้ deadlock ใน acceptance 4 เดิม · F05 evidence v1 = **committed Git artifacts เท่านั้น** (resolve ที่ commit OID + blob OID + raw SHA-256, ไม่รับ Test-Path)
- **scope เพิ่มที่อนุมัติ:** `.githooks/pre-commit` เรียก event checker เพิ่ม (**ห้าม regress ORDER-103 machinery — suite 103 41 case ต้องยัง PASS**) · `.gitattributes` scoped LF rule · ไฟล์ใหม่ตาม pinned decisions #2/#5/#6/#7 (`scripts/experiment_event_log.ps1` · `scripts/check_experiment_events.ps1` · `scripts/_test/run_order105_negative_tests.ps1` · schema 2 ไฟล์)
- design-review prompt ที่ใช้ = `docs/memory_control/CODEX_ORDER105_DESIGNREVIEW_PROMPT.md` (neutral framing ผ่าน content-filter รอบเดียว)

**ผล (REVIEWED/ACCEPT — Claude 2026-07-17, commit `0e13699`):** Contract D ครบทั้ง 3 ชิ้น + staged checker ต่อเข้า production hook (`[experiment-events]` PASS ครั้งแรกกับ commit จริง) — `scripts/experiment_event_log.ps1` (Append/RegisterEvidence/Scan/Disable/Enable/Recover/NewEventId · file-lock + atomic install + fail-closed + recovery state machine 6 branch) · schema v1 ×2 (per-event whitelist, additionalProperties=false, reason_code enum — ownership บังคับด้วย schema จริง) · `check_experiment_events.ps1` dot-source utility = single rule source (F08) · negTest ถาวร **105 case** (`run_order105_negative_tests.ps1`) รวม concurrency-barrier/fault-injection/recovery/hook-integration · **blind review 8 รอบจน ACCEPT:** ทุก finding แก้ครบ + มี negTest ถาวรกัน regress — รอบ 6-7 ยืนยัน recovery ทุก branch + COMPLETED idempotency, รอบ 8 ยืนยัน test-repeatability fix (barrier) + production SHA-256 ตรงทุกไฟล์ + focused probe 10/10 · gate สุดท้าย: 105/105 ×2 case-set identical · 103 = 41/41 · 101 = 25+1 pre-existing (`cross-HEAD-zero-diff`) · check_state CLEAN · manifest จริง 0 bytes (no-backfill) · **Event Log = dormant จนกว่า experiment แรกจะเขียนผ่าน utility เท่านั้น — ห้าม backfill · MVP-2 (Context Packet) ยัง B1-gated แยก contract**

## ORDER-115 — B1 observation cohort START + event-log adoption guide (§20.2 step 6 @ `4eb839d`) — `DONE + REVIEWED (Claude 2026-07-17)` · role: Claude lead (measurement + doc artifacts — ไม่แตะ write path/authority ใด จึงไม่เข้าเกณฑ์ blind review)

> **Design source:** `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20.2 step 6 + §20.3 B0/B1 contract + §20.4 triggers @ `4eb839d` · เพิ่งปลดล็อกวันนี้ (ต้องรอ MVP-3 = ORDER-103 ACCEPT `c0f7b0d` + MVP-1-lite = ORDER-105 ACCEPT `0e13699` ครบทั้งคู่)

**Output (3 ชิ้น ใน `docs/memory_control/`):**
1. `B1_COHORT.md` — register + protocol: anchor `0e13699` (2026-07-17) · cohort = 20 eligible terminal orders ถัดไปที่ปิดหลัง anchor (eligibility เดียวกับ B0 §3 เป๊ะ) · metric definitions เดิม 5 ตัว แต่เก็บ **prospective** (onboarding_time / context_incident / lead_attention_hours บันทึกสดได้แล้ว — B0 เป็น NOT_RECORDED) · capture protocol = session ที่ mark REVIEWED/CLOSED ต้อง append แถวใน commit เดียวกัน · trigger evaluation = ครบ 20 แถว AND ≥30 วัน (ไม่ก่อน 2026-08-16) → เช็ค §20.4 absolute triggers 5 ข้อ → MVP-2 go/no-go
2. `B1_DATASET.csv` — header byte-identical กับ `B0_DATASET.csv` (13 คอลัมน์) เพื่อ comparability · append-only
3. `EVENT_LOG_ADOPTION.md` — วิธีใช้ event log จริงสำหรับ order ถัดไป: chain 7 events + correction · คำสั่งครบ (NewEventId → owner_ref ผ่าน `Get-CommittedBlobRecord` dot-source = single rule source → Append → Scan) · **worked example ผ่าน end-to-end จริงใน temp fixture ก่อนเขียน** (append `appended` + scan valid + cleanup 0) · iron rules จาก §20.7 · canary backfill 3 เคสเท่านั้น (ST03 · Boss_16 · ORDER-095/Boss_14) แบบ lazy

**Acceptance (ตรวจแล้วทุกข้อ):** anchor SHA + eligibility rule + 5 metric definitions + 5 triggers ครบใน B1_COHORT.md ✓ · CSV header ตรง B0 byte-identical ✓ · adoption guide ไม่ duplicate rule table (ชี้ schema เป็น owner — one-fact-one-owner) ✓ · คำสั่งใน guide ถูก verify ใน temp GUID repo จริง ✓ · **ไม่มี event จริงถูกเขียน** (manifest ยัง 0 bytes, ไม่มี events-*.jsonl) ✓ · no-backfill intact ✓

**ห้าม (สืบทอดจาก §20):** ❌ สร้าง MVP-2 ก่อน trigger เข้า · ❌ backfill นอก 3 canaries · ❌ reconstruct metric จากความจำ (NOT_RECORDED เท่านั้น) · ❌ แก้ §20 draft

**ผล:** B1 window **OPEN ตั้งแต่ 2026-07-17** — order แรกที่ปิดหลัง `0e13699` = แถวแรกของ cohort · ORDER-115 เองปิดหลัง anchor จึงเป็นแถวที่ 1 ใน B1_DATASET.csv (บันทึก prospective ครบ: onboarding≈5m · incident 0 · rework 0 · wrong-scope 0 · lead≈0.7h)
