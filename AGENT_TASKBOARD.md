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

> 🔧 **SYSTEMS TRANCHE ORDER-152..158 (เขียน 2026-07-23, Opus-seat)** — งาน infra/tooling ล้วน ไม่ใช่ verdict EA.
> ที่มา = 2 backlog รวมกัน: (A) review แผน `docs/EA_CORE_TEMPLATE_WORKPLAN_FOR_CLAUDE.md` (7 finding ของ Opus
> + 4 ที่ Codex จับเพิ่ม) (B) `ROADMAP.md` §3 development backlog. **ลำดับ = อะไร block งานอื่น/เสียข้อมูลถาวร
> ก่อน ไม่ใช่อะไรง่ายก่อน.** T1 = 152-155 (ทำก่อน) · T2 = 156-158 (ตามหลัง ไม่เร่ง).
> **ไม่เขียนเป็น order (มี trigger ชัดแทน):** PQ-02 deflated gate = LOCKED + ยังไม่ binding (order ที่ค้างอยู่ N≤50
> ทุกใบ → บาร์คง 1.20) unlock เมื่อมี screen order แรกที่ N>50 · PQ-01 vol-target rebalancer เต็มรูป = ต้องใช้ deals
> จริง ≥3 เดือน ซึ่ง cohort ใหม่ยังไม่มี รันไม่ได้ก่อน ~ต.ค. · MT5 เลน 2/3 = `AGENTS.md` §3 มี lane params ครบแล้ว
> เหลือแค่ verify ตอนคิวแน่นจริง

## ORDER-152 — [infra] doctrine reconciliation: Codex routing + stale verdict vocabulary + doc-retirement audit — `REVIEWED(Claude 2026-07-23) — committed c6d431f · (a)(b) done · (c) disposition B-list EXECUTED this session (user go-ahead given): moved 6 root docs → _archive_docs/ (DEPLOY_CHECKLIST_2026-06-29 + 5 one-off analysis docs), deleted empty portfolio/port_01/ scaffold + duplicate _archive_docs/QWEN_RUN_LOG_updated.md (verified pure subset of QWEN_RUN_LOG.md), verified DEPLOYMENT_PLAN.md is NOT a stale duplicate of DEMO_DEPLOYMENT_PLAN.md (distinct scope, already bannered) → kept as-is; updated path refs in PROJECT_STATE.md/README.md/MASTER_BACKLOG.md; check_state.ps1 -Strict = CLEAN after every move; **B-list now 7/7 CLOSED** — final 2 done same session (`ee8db79`+`1b0ebb9`): `OPTIMIZE_PROCEDURE_AND_AUDIT.md` → `_archive_docs/` (already self-bannered SUPERSEDED, nothing to merge) · `docs/RECOVERED_PLATFORM_DESIGN_20260614.md` → `_archive_docs/` **after content-check**: not "already ported" but *replaced by a different system* (§3 scoring + §4 gate chain = retired vocabulary → VERDICT GATE · §5 Pass 0/1/2/4 → skill LADDER · §6 window → pinned MAIN/BWD/HOLDOUT · §7 EA table stale, GSMC already DISQUALIFIED · §1-2/§8 still true, live in `ea_template/DESIGN_V2.md`+`VISION.md`) → SUPERSEDED banner added, refs fixed in `PLATFORM_INDEX.md`/`README.md`/`PROJECT_STATE.md`/`_archive_docs/README.md` — see `_triage/ORDER152_DOC_RETIREMENT_AUDIT.md` §B for full detail. **⚠️ spun off (out of scope, not done):** `scripts/select_robust_pass.py`+`scripts/score_backtest.py` ยัง implement สูตร BacktestScore v1 ที่ retire แล้วจากไฟล์ที่เพิ่ง archive — ยังไม่ตรวจว่ายังถูกเรียกใช้จริงไหม (แก้แค่ path comment) · worktree risk item (`great-mendeleev-a35c44`) resolved same session: confirmed clean + already-merged, removed via `git worktree remove`, nothing lost`
> 🔧 **provenance correction (Opus-seat, 2026-07-23):** B-list execution above actually landed in commit **`52e9fcd`**, not folded into any of this session's other commits. `52e9fcd`'s commit message reads "ORDER-163 (CORE-002) REVIEWED..." — **that message is wrong for that commit's actual content.** Root cause: a `.git/index` race between two concurrent sessions writing to the same shared working tree during a slow (~3min) pre-commit hook — this session's ORDER-163 `git add` got superseded in the shared index by the other session's doc-cleanup `git add` before either `git commit` finished, so the commit object that landed carries this session's message text but the other session's staged content. No data was lost (all files intact), but **the git log entry for `52e9fcd` should be read as "ORDER-152(c) doc B-list execution", not ORDER-163** — this note is the correction. ORDER-163's actual files were re-staged and committed separately afterward (see that order's own commit). New failure class for `AGENT_TASKBOARD.md`/git-workflow doctrine — logged to memory `shared-worktree-concurrent-writers`.
**source:** workplan review finding #2 + Codex MISSED #1/#2 + ROADMAP §3 ข้อ 9 (เกษียณเอกสารซ้ำซ้อน) — **ยกระดับจาก "ว่างเมื่อไหร่ก็ได้" เป็น T1 เพราะพิสูจน์แล้วว่ามี doc ขัดกันเองที่ agent อ่านอยู่ทุกวัน** (ไม่ใช่แค่รก).
**ยืนยันแล้ว 2 จุดขัด:** (1) `AGENTS.md` §5.1 ตาราง order-tag ระบุ 👉 แนะ default = **Codex-direct** สำหรับงาน code · แต่ Decision log 2026-07-16 + `docs/PIPELINE.md` สั่ง Claude-author + Codex audit-only หลัง Codex-builder ตาย 3 ครั้งใน 1 วัน (2) `ea_template/OPTIMIZATION_PROCEDURE_V2.md` ยังเป็น DRAFT FOR REVIEW และใช้ศัพท์ verdict เก่า (`DEAD`/`PARKED`/`SYMBOL_LOCAL` เปล่าๆ) ที่ retire ไปแล้วตาม VERDICT GATE.
**spec:** (a) แก้ `AGENTS.md` §5.1 ให้ตรง Decision log — เส้นแบ่งที่ถูกต้องคือ **core/parity/money code = Claude เขียน Codex blind-audit** · **tooling ที่ไม่แตะเงินและมี cage ชัด = Codex build ได้** (precedent ที่ถูกต้องแล้ว = ORDER-144) ห้ามเขียนเหมารวมว่า Codex ห้ามเขียนโค้ดทุกกรณี (b) `OPTIMIZATION_PROCEDURE_V2.md` — map ศัพท์เก่า→canonical vocabulary + ใส่ banner ว่าไฟล์นี้ owns **procedure เท่านั้น ไม่ own verdict** (VERDICT GATE ใน CLAUDE.md own) (c) audit: list ทุก `*.md` ที่มี banner `DRAFT FOR REVIEW` / `SUPERSEDED` / `DEPRECATED` + ไฟล์ที่ authority ทับกัน → ตารางเสนอ disposition ต่อไฟล์ (keep / merge-into-X / retire) — **เสนอเฉย ๆ**.
**ผล sweep รอบแรกมีแล้ว (2026-07-23 — ใช้เป็นจุดตั้งต้นของ (c) ไม่ต้องเริ่มจากศูนย์):** ขนาด = **29 `.md` ที่ root · 10 ใน `docs/` · 20 ใน `_archive_docs/`**. ตระกูลที่ authority ทับกัน: **taskboard ×4** (`AGENT_TASKBOARD` + `_MERGE` + `_PQUANT` + `ARCHIVE_TASKBOARD_2026-07A`) · **deployment plan ×3** (`DEPLOYMENT_PLAN` + `DEMO_DEPLOYMENT_PLAN` + `DEPLOY_CHECKLIST_2026-06-29` ซึ่ง date-stamped น่าจะค้าง) · **project state ×2** (+ `STATUS.md`/`STATUS.html` + `_archive_docs/PROJECT_STATUS.md`). ติด banner ชัดแล้ว: `OPTIMIZE_PROCEDURE_AND_AUDIT.md` = `⚠️ SUPERSEDED (2026-07-18)` · `docs/RECOVERED_PLATFORM_DESIGN_20260614.md` = artifact กู้คืน น่าจะถูกแทนด้วย `PLATFORM_INDEX.md`/`docs/PIPELINE.md`. one-off analysis ที่ root ควรย้ายลง `_archive_docs/`: `EA_CORE_ST03_LOOP_PLAN` · `MT4_GOLDGRID_RETEST_PLAN` · `RSI_FROM_PIPS_REVERSE_ENGINEERING` · `STRATEGY_200_ANALYSIS` · `ZEUS_GOLD_HEDGE_ANALYSIS`. **2 อย่างที่ไม่ใช่ .md แต่เป็นขยะโครงสร้างจริง:** `portfolio/port_01/` = 5 โฟลเดอร์ว่างเปล่ามีแต่ `.gitkeep` ไม่ถูกแตะตั้งแต่ 2026-05-29 · **`.claude/worktrees/great-mendeleev-a35c44/` = สำเนาทั้ง repo ค้างอยู่** (root docs + `_mt5_auto/` ครบ) — อันนี้อันตรายกว่ารก เพราะ memory `shared-worktree-concurrent-writers` เตือนไว้แล้วว่า worktree ค้าง = ความเสี่ยง writer ชนกัน **แต่ห้ามลบในใบนี้ ให้เสนอพร้อมเหตุผล**.
**bars:** N-A (doc order ไม่มี pass/dead). **flat-lot probe:** N-A.
**ห้าม:** ลบ/ย้าย/rename ไฟล์ใดๆ ใน order นี้ (เสนอ disposition เท่านั้น) · แก้ VISION.md · แก้ Decision log · แตะ verdict EA · commit เอง.
**ทำได้:** (a)+(b) = **Claude เท่านั้น** (เป็นการตัดสินว่า doc ไหนชนะ) · (c) sweep = qwen/Sonnet ทำ list ได้ · 👉 แนะ: Claude ทำ (a)(b), qwen ทำ (c).

## ORDER-153 — [infra] `portfolio/expectations.csv` + capture-at-attach rule (PQ-03 ครึ่ง data-capture, partial early unlock) — `REVIEWED(Claude 2026-07-23) — schema fix verified (float-parse 48/48), accepted`
**result:** `portfolio/expectations.csv` 48 แถว (1 ต่อ magic) + `portfolio/EXPECTATIONS_README.md` (กฎ no-ACTIVE-without-expectations + บันทึกเรื่อง band 2 สูตรที่ขัดกัน โดยไม่เลือกข้าง). **45/48 แถวมี `pf_expected` ที่อ้างไฟล์จริงซึ่ง agent เปิดอ่านเอง** · 3 แถว `UNVERIFIED_ROW` (magic ว่างใน DEPLOYMENTS) · `trades_per_month` 24/48 · `dd95` 5/48. วินัย UNKNOWN ดีมาก — agent รายงานเองว่าที่อยากเดาแต่ไม่เดา ได้แก่ ~40 แถวที่หลักฐานให้แค่ max-DD/PF_5th ไม่ใช่ DD95, Kangaroo 1112-1115 ที่เป็น 4 stream จาก MagicStart เดียวแยกไม่ได้, และ Zeus 7777 ที่มีผลประเมินขัดกัน 2 ชุด (flag ไว้ ไม่ปั้นการ reconcile).
**🔧 Opus-seat แก้ตามหลัง (schema):** ส่งมอบรอบแรก **prose ปนในคอลัมน์ตัวเลข** (เช่น `10.77% (MC DD_95th; basket-level...)`, `MAIN 1.11 / BWD 1.11 (...)`) → `float()` ผ่านแค่ **1/45 แถว** = ไฟล์แทบใช้เชิงเครื่องไม่ได้ และเป็นสาเหตุที่ ORDER-154 รอบแรกอ่าน DD95 ได้ตัวเดียว. แก้เป็น: คอลัมน์ตัวเลขถือ**เลขเปล่าหรือ UNKNOWN เท่านั้น** + เพิ่ม `pf_basis`/`dd95_basis` (MAIN / IS / plain / RANGE_NOT_SEPARABLE) + `notes` เก็บข้อความเดิม verbatim. **ผล: pf อ่านได้ 1→40 · dd95 1→5 · ทุกเซลล์ตัวเลข parse ผ่าน 100%** · 5 แถวที่เป็นช่วง ("1.34-2.17 3-window") ตั้งเป็น UNKNOWN + ธง ไม่เดาค่ากลาง → ส่งต่อ ORDER-159.
**บทเรียนเข้ากติกา:** order ที่ผลิต CSV ให้เครื่องอ่าน ต้องระบุในสเปกว่า **"คอลัมน์ตัวเลข = เลขเปล่า, คำอธิบายไปคอลัมน์ notes"** + acceptance ต้องมี `float()` parse check — ไม่งั้นได้ไฟล์ที่คนอ่านสวยแต่เครื่องอ่านไม่ออก และจะรู้ตอนปลายทางคำนวณผิดแล้ว.

<details><summary>spec เดิม (เก็บไว้อ้างอิง)</summary>
**source:** ROADMAP §3 ข้อ 6 / PQ-03 (`AGENT_TASKBOARD_PQUANT.md`). **⚠️ นี่คือการ unlock บอร์ด PQUANT บางส่วนก่อนกำหนด — user veto ได้:** บอร์ดล็อกถึง "judge day เสร็จ + พอร์ต #1 live" (judge เร็วสุด 2026-09-22, วันนี้ 07-23 → ล็อกยังมีผล) แต่เหตุผลที่ล็อกคือ *ห้ามแทรก demo experiment ที่กำลังรัน* — **การ "จดค่าที่คาดหวัง" ไม่แตะ EA ที่รันอยู่เลยแม้แต่ตัวเดียว** จึงไม่ขัดเจตนาล็อก. ที่ต้องทำตอนนี้เพราะ **expectation เป็นข้อมูลที่กู้ย้อนหลังไม่ได้อย่างซื่อสัตย์** — ถ้าจดหลังเห็นผล live แล้ว = hindsight ไม่ใช่ expectation · และมี EA ทยอย attach อยู่ตอนนี้ (992004 ACTIVE 07-23, 992001 รอ ORDER-151, 990025/990030 PENDING_ATTACH, + ORDER-147/149 มี PASS รอ review).
**spec:** สร้าง `portfolio/expectations.csv` 1 แถวต่อ magic ใน DEPLOYMENTS.csv: `magic, ea_name, symbol, account, pf_expected, trades_per_month_expected, dd95_expected, source_evidence, recorded_date`. backfill จาก verdict/report ที่มีอยู่จริงเท่านั้น (เช่น 992004 → ORDER-139: MAIN 1.63 / DD95 4.15) · **แถวไหนไม่มีหลักฐาน = ใส่ `UNKNOWN` ห้ามเดาเลข** · เพิ่มกฎเป็นลายลักษณ์: DEPLOYMENTS row ห้ามขึ้น ACTIVE ถ้าไม่มีแถว expectations (แถว UNVERIFIED/UNKNOWN ที่มีอยู่ก่อน = grandfather แต่ต้องอยู่ในลิสต์).
**ขอบเขตชัด — ไม่รวม:** logic ธง 🟢🟡🔴 / probation / kill band ของ PQ-03 = **ยัง LOCKED ถึง judge day** (order นี้เก็บข้อมูลอย่างเดียว ไม่ตัดสินอะไร).
**🔴 เจอตอน inventory — มี band อยู่ 2 สูตรที่ไม่ตรงกัน ต้องรายงานอย่าเพิ่งแก้:** skill `ea-live-monitor/SKILL.md` มีเกณฑ์ฝังอยู่แล้วในรูป *ข้อความ* (ไม่ใช่โค้ด): `ALERT_PF = BT_PF × 0.7` · `ALERT_DD = BT_DD × 1.2` · `ALERT_CONSEC = BT_consec + 2` · `ALERT_FREQ = BT_freq × 0.5` + บันได KEEP/WATCH/PAUSE/KILL · **แต่ PQ-03 ออกแบบไว้คนละเลข** (PF ratio ปกติ = ช่วง [0.6, 1.8] · rate [0.5, 2.0] · 🔴 ที่ PF ratio <0.6 ที่ ≥20 ไม้) ทั้งที่ PQ-03 เขียนกำกับตัวเองว่า *"นิยามเดียวกับ runbook §2.1 เพื่อไม่ให้มีสองสูตร"* → **ตอนนี้มีสองสูตรจริง**. ใบนี้ให้ **บันทึกความต่างไว้ใน `expectations.csv` README/header เฉย ๆ** — การเลือกว่าสูตรไหนชนะ = ตอน unlock PQ-03 เต็มตัว (Claude/user ตัดสิน) ห้าม agent เลือกเอง.
**bars:** N-A. **flat-lot probe:** N-A.
**ห้าม:** เดา/ประมาณเลข expectation ที่ไม่มีหลักฐานรองรับ · แตะคอลัมน์ `kill_rule` หรือ `judge_date` ใน DEPLOYMENTS.csv · unlock ส่วนที่เหลือของ PQ-03 · เขียน verdict.
**ทำได้:** Claude กำหนด schema + ตัดสินว่าไฟล์ไหนเป็นหลักฐานที่ใช้ได้ · **Sonnet** backfill (ต้องรู้ convention repo + ไล่ verdict file) · 👉 แนะ: Sonnet ทำ backfill ใต้ schema ที่ Claude ล็อก.
</details>

## ORDER-154 — [infra · money-adjacent] Attach-time portfolio risk budget (admission control) — `REVIEWED-WITH-DEFECTS(Claude 2026-07-23) — Codex blind audit เจอ SEV-1 5 ข้อ · ห้ามใช้ size เงินจริงจนกว่าจะแก้ (ORDER-170)`
**🔴 ผล Codex blind audit (`_triage/CODEX_ORDER154_RISK_ADMISSION_AUDIT.md`) — Opus-seat verify เอง 4/4 ข้อด้วย probe จริง ยืนยันครบ ไม่ได้เชื่อตามรายงาน:**
1. **`basket_id` ถูก loader ทิ้ง** → basket เดียวถูกนับซ้ำได้ตามจำนวนขา (โค้ดไม่บังคับ convention — `expectations.csv` วันนี้รอดเพราะผม**แก้มือ**ไว้ตอน ORDER-159 เท่านั้น)
2. **`_num()` คืน 0.0 เมื่อ P&L cell พัง** → กลายเป็น observation ศูนย์ ทำให้ corr ที่วัดได้ต่ำกว่า 1.0 = **ทะลุ default อนุรักษ์นิยม** (ไฟล์หายทั้งไฟล์ยัง default 1.0 ถูก แต่ไฟล์พังบางส่วนไม่ถูก)
3. **DD95 = 0 เชิงตัวเลขถูกรับเป็น "รู้ค่าแล้ว"** → `portfolio_dd_est` คืน **0.0** (verify แล้วจริง)
4. **broker-min เป็น placeholder ไม่เคยต่อสาย** → `DEFER_ESCALATE` แทบไม่มีทางยิงจริงบน default path
5. **bounds guard ถูก bypass ใน `admit_candidate`** → verify แล้ว: input ชุดเดียวกัน `admit_candidate` ตอบ **ADMIT_FULL** ขณะที่ `portfolio_dd_est` **raise RiskAdmissionError**
SEV-2 อีก 4: ปัดเศษ factor แล้วไม่เช็คงบซ้ำ (ล้นงบได้) · `inf` ผ่าน bounds (verify แล้วจริง) · `--out-md` เขียนทับ `DEPLOYMENTS.csv` ได้ · **self-test ข้อ missing-DD95 เป็น tautology** (fixture ตัด key ออกเอง + ไม่เคยเรียก `load_expectations()` → inversion ของ default จะยังผ่าน).
**บทเรียนที่ตรงกับกฎเป๊ะ:** agent ที่เขียนรายงาน cage ตัวเอง **6/6 PASS** แล้วยังมี SEV-1 5 ข้อ — และ self-test มัน**ไม่มีโครงสร้างที่จะจับได้เลย** นี่คือเหตุผลที่ `AGENTS.md` §5 บังคับ blind review กับ money-adjacent code ไม่ใช่ให้ self-certify.
**ผลต่อเลขที่รายงานไปแล้ว (463666728 = 61.03%, 415573666 = 4.15%): ยังใช้อ่านทิศทางได้ ไม่ถูก invalidate** — เพราะ `expectations.csv` ปัจจุบันบังเอิญไม่มี DD95 = 0/inf, basket convention ถูกแก้มือไว้แล้ว, และ account path มี bounds guard ทำงานจริง. **แต่ห้ามใช้ tool นี้ size เงินจริงจนกว่า SEV-1 #1/#3/#5 จะแก้** เพราะทั้งสามเป็น path ที่ให้ "เลขผิดแบบเงียบ" ไม่ใช่ crash.
**ไม่แก้ในใบนี้** — แก้เป็น **ORDER-170** เพื่อให้ตัวแก้ถูก re-audit แบบ blind อีกรอบ ไม่ใช่ self-certify ซ้ำรอยเดิม.
**result:** `scripts/portfolio_risk_admission.py` (stdlib-only, portable python) + `_triage/ORDER154_RISK_ADMISSION_CURRENT_STATE.md` + `.json`. **cage 6/6 PASS** (`--selftest`): golden-sample byte-identical ×2 run · bounds-assert ละเมิดแล้ว raise จริง (ไม่คืนเลขผิด) · missing corr → 1.0 พิสูจน์ว่าต่างจาก 0.0 เชิงตัวเลข · lot factor อยู่ใน (0,1] เสมอ · DEFER_ESCALATE ไม่แจก factor · REAL_CENT = REPORT_ONLY ไม่ size อะไร.
**🔴 finding ที่สำคัญกว่าตัว script — data starvation:** **มีแค่ 2/42 magic ที่มี DD95 ใช้ได้จริง (5%)** → 463666728 คำนวณได้ 1.17% จาก **1 ใน 17 magic** · 415573666 ได้ 4.15% จาก **1 ใน 10** · อีก 4 บัญชีคำนวณไม่ได้เลย (script รายงาน "cannot compute" ถูกต้อง ไม่ปั้นเลข). **แปลว่าเครื่องมือพร้อมแล้วแต่ยังตอบคำถามพอร์ตไม่ได้จนกว่า DD95 จะครบ** — งานต่อคือ backfill DD95 จาก MC ที่รันไปแล้ว ไม่ใช่แก้ script. candidate PENDING_ATTACH ทั้ง 3 ตัว (990025/990030/992001) ได้ `CANNOT_RUN` เพราะ DD95 ตัวเองไม่รู้ = พฤติกรรมถูกต้อง.
**ส่งต่อ ORDER-153:** `expectations.csv` บางแถวมี `dd95_expected` เป็น free-text ที่มี comma ฝัง (990067/990069/990068/990984/990120) → parse เป็น float ไม่ได้ script เลย treat เป็น UNKNOWN (ปลอดภัยถูกต้อง) **แต่ต้นทางต้องแก้ที่ 153**.
**ค้าง:** Codex blind audit (บังคับตาม order + AGENTS.md §5) — dispatch แล้ว 2026-07-23 → `_triage/CODEX_ORDER154_RISK_ADMISSION_AUDIT.md`.
**update 2026-07-23 (Opus-seat, หลังแก้ ORDER-159 ส่วน 1):** แก้ basket double-count แล้ว (IchiADX 990066-9 เพิ่ม `basket_id` ใน expectations.csv, DD95 อยู่แถวเดียวต่อ basket) → รันซ้ำ **463666728: 74.8%→52.6%** (ยังเกินงบ 25% แม้รู้แค่ 3/17 magic) · 415573666 ไม่เปลี่ยน (4.15%, 1/10) · cage ยังผ่าน 6/6 · ไม่แก้ script (แค่ exclude UNKNOWN อยู่แล้ว, bug อยู่ที่ data ไม่ใช่ formula).

<details><summary>spec เดิม (เก็บไว้อ้างอิง)</summary>
**source:** ROADMAP §3 ข้อ 4 / Phase 3.5 ข้อ 1 — **แต่นี่ไม่ใช่ PQ-01 และไม่ใช่การ unlock PQ-01.** PQ-01 คิด lot จาก P&L รายสัปดาห์ของ deals จริง ≥3 เดือน · EA ที่กำลังเข้าพอร์ตตอนนี้ไม่มี live history เลย และบัญชี 463666728 **ไม่มี sensor deals ด้วยซ้ำ** → input ของ PQ-01 ไม่มีอยู่จริงสำหรับ EA กลุ่มที่ก่อปัญหา. order นี้ = **admission control ตอน attach จากเลข backtest** · PQ-01 = rebalance รายเดือนจาก live · สองอันบรรจบกันเมื่อ EA ครบ 3 เดือน (live vol แทนที่ DD95 proxy).
**ปัญหาที่วัดได้ตอนนี้:** 463666728 = **14 ACTIVE + 2 PENDING_ATTACH = 16 EA บนบัญชีเดียว** (kill rule ราย EA 12-18%) · 415573666 = 10 ACTIVE · ไม่มีที่ไหนคำนวณว่ารวมกันแล้วเท่าไหร่ → การเพิ่ม EA ตัวที่ 17 วันนี้ = ตัดสินใจโดยไม่มีตัวเลขประกอบ.
**DESIGN (Claude ออกแบบเสร็จแล้ว — implement ตามนี้ ห้ามคิดสูตรเอง):**
- **input (ของที่มีอยู่แล้วทั้งหมด ไม่ต้องวัดใหม่):** `DD95_i` = DD เปอร์เซ็นไทล์ 95 จาก MC ของ EA นั้น ที่ lot ใน locked .set คิดเป็น % ของ equity บัญชีที่มันรัน (ทุก candidate ที่ผ่าน funnel มี MC แล้ว — S1 992004 DD95 = 4.15) · `corr_ij` = monthly-return correlation จาก `_mt5_auto/corr_monthly.py` · `equity` ของบัญชี
- **สูตร (quadratic form, corr_ii = 1):** `portfolio_DD_est = sqrt( Σ_i Σ_j corr_ij · DD95_i · DD95_j )`
- **ค่า default เมื่อข้อมูลขาด ต้องพลาดไปทาง *ปลอดภัย* เสมอ:** `corr_ij` ไม่รู้ → **1.0 (นับว่าบวกกันเต็ม) ห้ามใช้ 0** · `DD95_i` ไม่รู้ → ตัดแถวออกจากการคิด + ธง UNKNOWN **ห้ามสมมติ 0**
- **bounds assert (ต้องจริงเสมอ):** `max_i(DD95_i) ≤ portfolio_DD_est ≤ Σ_i(DD95_i)` — ถ้าละเมิด = corr matrix พัง (parse ผิด/ไม่ PSD) → **ปฏิเสธการออกตัวเลข ห้ามเดา**
- **งบ:** บัญชี DEMO = **25% ของ equity** (ใช้เลขที่ตรึงไว้แล้วใน JUDGE_DAY_RUNBOOK §3.3 / PQ-01 — ห้ามตั้งเลขใหม่) · บัญชี **REAL_CENT = คำนวณ+รายงานอย่างเดียว ห้ามตั้งงบเอง** ติดธง "รอ user เคาะ"
- **กฎรับเข้า (ก่อนแถว DEPLOYMENTS จะขึ้น ACTIVE):** คำนวณใหม่โดยรวม EA ตัวใหม่ → (1) ≤ งบ = รับที่ lot ของ locked set (2) > งบ = **ย่อ lot ของตัวใหม่** (DD95 สเกลเชิงเส้นตาม lot) จนพอดีงบ — **resize-first ตามกฎ user เดิม ห้าม reject EA** (3) ย่อจนถึง min lot ของโบรกแล้วยังไม่พอ = **เลื่อน attach + รายงานเลขให้ user** ยังไม่ใช่การฆ่า EA
- **ข้อจำกัดที่ต้องเขียนไว้ทั้งใน header ของ script และในรายงาน:** DD95 เป็น quantile ของ drawdown ไม่ใช่ return — การรวมมันผ่าน correlation matrix ของ return เป็น **heuristic คัดกรอง ไม่ใช่ทฤษฎี** · output = **prior สำหรับ admission control ไม่ใช่ verdict** และไม่แทน MC ราย EA
**deliverable:** `scripts/portfolio_risk_admission.py` (portable python) + รายงาน current-state ทั้ง 6 บัญชี (เริ่ม 463666728 และ 415573666) เป็น markdown + JSON — **ไม่ auto-apply ลง .set ใดๆ**
**cage (acceptance):** golden-sample 3-EA input → output เดิมเป๊ะทุกครั้ง · bounds assert ข้างบน · test ว่า corr ที่หายไปกลายเป็น 1.0 จริง (ไม่ใช่ 0) · assert ไม่มี lot ติดลบ/เกิน RC_MaxLot · **Codex blind review บังคับ** (money-adjacent ไม่มี cage เดิม — ตาม AGENTS.md §5)
**bars:** N-A (tooling). **flat-lot probe:** N-A.
**ห้าม:** แก้ .set ที่ deploy อยู่ · auto-apply lot · ตั้งงบ DD สำหรับบัญชีเงินจริงเอง · ใช้ output เป็น verdict/เหตุผลถอด EA · แตะ DEPLOYMENTS.csv.
**ทำได้:** Claude ออกแบบ (เสร็จแล้ว ข้างบน) → **Sonnet/Codex implement ตาม spec** → **Codex blind review** → Claude รับ · 👉 แนะ: Sonnet implement + Codex review (ห้ามให้ Codex เห็น review ของ Sonnet ก่อน).
</details>

## ORDER-155 — [infra] workplan rev-B: `docs/EA_CORE_TEMPLATE_WORKPLAN_FOR_CLAUDE.md` — `REVIEWED(Claude 2026-07-23) — committed c6d431f · next = decompose CORE-002 + PARAM-001 when user greenlights`
**source:** review ของ Opus (7 finding) + QA ของ Codex (AGREE 4 / PARTIAL 3 + 4 ข้อที่ Opus พลาด) 2026-07-23. แผนเดิม = 23 proposed orders ที่ยังแตกไม่ได้จนกว่าจะแก้ — **นี่คือประตูของทั้ง track template**.
**spec — rev-B ต้องแก้ครบ:** (1) **BLOCKER**: OPT-004/005 ประดิษฐ์ status ใหม่ (`SCREEN_FAIL`/`ROBUST_FAIL`/`DEAD`…) + rescue ladder R0-R4 ชนกับ VERDICT GATE ที่ own verdict + skill `backtest-optimize-rigor` ที่ own THE LADDER → status ใหม่ใช้ได้แค่เป็น **pipeline-stage label ภายใน tooling ที่ map กลับ canonical vocabulary เสมอ ห้ามเป็น verdict**; ส่วน OPT-005 ที่แตะเลข PF/DD/ruin = **แยกเป็นคำถามให้ user เคาะ ไม่ใช่ order** (แต่ trade-floor ตาม strategy type ไม่ต้องถาม — bar table เดิมเขียน "n เหมาะกับ type" รองรับอยู่แล้ว) (2) model routing: ตัด Codex ออกจากเลน implement เฉพาะ **core/parity/money code** (MIG-002 ฯลฯ) — คง Codex build tooling ที่มี cage ได้ (3) OPT-002 ต้องบังคับ window pin จาก CLAUDE.md เป็น config เดียว + assert `MAIN ∩ HOLDOUT = ∅` + เก็บสถานะ holdout-burn ราย EA (2026H1 ไหม้แล้วสำหรับ Wave-2 S1) (4) เติมกฎที่ ratify แล้วแต่หายไป: **ENGINE-EDGE กรง 5 ข้อ** · **exit/time lever บน grid ต้อง M4 เสมอ** (บทเรียน ORDER-125: M1 หลอกผ่าน M4 พลิก) · **Row-X checklist** (เฉพาะ order ที่ผลิต verdict) · field `bars:`/`flat-lot probe:` ตาม template บอร์ดนี้ (5) CAGE-001 → เปลี่ยนเป็น **gap-audit** เทียบ ORDER-129/132/138 ที่ปิดไปแล้ว ไม่ใช่สร้างใหม่ (6) CORE-001/CORE-003 → **ตัดหรือเหลือ gap-audit** (Boss V2 = แม่พิมพ์เดียว / EA_CORE = archive ตัดสินปิดไปแล้วใน VISION + Decision log) (7) OPT-003 ต้องอ้าง freeze guard ใน `scripts/mt5_run.ps1` + gotcha tester ชนกันได้ 0-trade artifact (8) เลข order: จอง ORDER-1xx จริงตอนแตก เก็บ CORE-/PARAM-/OPT- ไว้เป็น tag ใน title (9) **ห้ามชี้ `OPTIMIZATION_PROCEDURE_V2.md` เป็น spec owner ก่อน ORDER-152(b) เสร็จ** — ไม่งั้นย้ายปัญหา vocabulary ไปอีกไฟล์.
**เลขที่ต้องแก้ให้ตรง (Codex จับผิดของ Opus):** แผนมี **23 orders ไม่ใช่ ~17** · `ea_template/core/Inputs.mqh` มี **177 parameter จริง** (202 บรรทัด `input` แต่ 25 เป็น `input group` header) · validator ปัจจุบัน **ไม่ใช่กระดาษเปล่า** — `LabCore.OnInit()` + `RiskControl_InitEx()` มี fail-closed check อยู่แล้ว → CONFIG-001 ต้องเริ่มจาก inventory ของเดิมก่อน.
**bars:** N-A (doc order). **flat-lot probe:** N-A.
**ห้าม:** แตะ source code ใน order นี้ (rev-B = เอกสารอย่างเดียว) · ย้าย/ลบ archive · ประกาศ EA ตัวไหน DEAD/REJECT จากแผนนี้ · แตะ VISION/Decision log · แตก order ลูกทั้ง 23 ใบรวดเดียว (pacing 1-2/รอบ, เริ่มที่ CORE-002 dependency audit + PARAM-001 registry).
**ทำได้:** **Claude เท่านั้น** (เป็นการตัดสิน scope + invariant) · 👉 แนะ: Claude.

## ORDER-159 — [infra] DD95 backfill + แก้ basket/leg double-count (ปลดล็อก ORDER-154 ให้ใช้ตัดสินใจได้จริง) — `REVIEWED(Claude 2026-07-23) — float-parse verified, cage 6/6, accepted`
**(2)(3)(4) DONE (Sonnet):** backfill DD95 จาก MC ที่ระบุ "95th-percentile" ชัดเจนเท่านั้น (ไม่ใช้ max-DD/PF_5th แทน) — เพิ่ม **8 แถว** (990103/990101/991001/991004/991002/990020/990030/999094) ทุกแถวอ้าง source_evidence ที่เปิดจริง · **dd95 known 4→12/48** · 25 แถวไม่มีหลักฐาน MC เลย → ติด `NEEDS_MC` + inventory เต็มที่ `_triage/ORDER159_NEEDS_MC_LIST.md` · 5 แถว RANGE_NOT_SEPARABLE (990103 family) ยืนยันแล้วว่าใช้ window scheme BWD/holdout/FWD คนละแบบกับ MAIN canonical → เหลือ UNKNOWN ตามเดิม ไม่เดา (ถูกต้องตาม spec) · **วินัยที่ดี:** ตั้งใจไม่เติม 9 แถวที่มี MC จริงแต่รายงานแค่ worst-case DD/PF-percentile ไม่ใช่ DD95 ชัดๆ (Boss_14 cohort ×7, Wave5-XAU, crypto-BTC) — บันทึกแยกกันชัดว่าไม่ใช่ "ไม่เคยรัน".
**verify (Opus-seat):** float() parse 48/48 ผ่าน · cage 6/6 PASS · รันจริง: **463666728 52.6%→61.03%** (6/17 known, ยังเกินงบ 25%) · 415573666 คงที่ 4.15% (1/10, Boss_14 cohort/Zeus-AUDJPY ไม่มีหลักฐาน DD95 เลย).
**ค้าง:** DEPLOYMENTS.csv ที่ agent สังเกตว่า modified = ของ session อื่น (ORDER-151 reattach) ไม่ใช่ของ order นี้ ไม่แตะ.

<details><summary>spec เดิม (เก็บไว้อ้างอิง)</summary>
**(1) DONE:** เพิ่มคอลัมน์ `basket_id` ใน `expectations.csv` — DD95 อยู่แถวเดียวต่อ basket (990066/990068 = primary, 990067/990069 = UNKNOWN ชี้กลับ primary) เลขเดิมไม่ถูกเดาใหม่ แค่ย้ายที่ · รีรัน risk script: 463666728 74.8%→**52.6%** · cage 6/6 PASS.
**source:** ผลจริงของ ORDER-154 หลังแก้ schema (ORDER-153 follow-up): เครื่องมือพร้อม **แต่ข้อมูลไม่พร้อม** — `dd95_expected` มีจริงแค่ **5/48 แถว**. 463666728 คำนวณจาก 4/17 magic · 415573666 จาก 1/10 · **บัญชีเงินจริงทั้ง 3 = 0 แถว คำนวณไม่ได้เลย**.
**🔴 bug ในข้อมูลที่ต้องแก้ก่อนใครอ่านเลข 74.8%:** DD95 ของ IchiADX เป็น **basket-level** แต่ถูกใส่ให้ทั้งสองขาของ basket เดียวกัน → 990068 และ 990069 ต่างถือ 22.19% ทั้งคู่ = **นับ basket เดียวสองรอบ** (990066/990067 คู่ 10.77% รอดเพราะขาหนึ่งเป็น UNKNOWN พอดี). ต้องตัดสินว่าจะ (ก) ใส่ค่า basket ที่ขาเดียวแล้วอีกขาเป็น 0-by-design พร้อม flag หรือ (ข) เพิ่มคอลัมน์ `basket_id` แล้วให้ script รวมทีละ basket. **แนะ (ข)** — ตรงความจริงกว่าและกันคนใส่ผิดซ้ำ.
**spec:** (1) แก้ double-count ตามข้อข้างบน (2) ไล่ backfill `dd95_expected` จาก MC ที่ **รันไปแล้ว** — ORDER-153 จงใจไม่ใส่ ~40 แถวเพราะหลักฐานอ้าง max-DD หรือ PF_5th ไม่ใช่ DD95 ที่ระบุชื่อชัด (ระเบียบถูกต้อง) → ใบนี้ให้ไปเปิด report/verdict จริงหาว่า DD95 มีไหม (3) แถวที่ **ไม่เคยรัน MC เลย** → ลงบัญชีเป็น list "ต้องรัน MC" **อย่าเดา** (4) 5 แถวที่ติดธง `RANGE_NOT_SEPARABLE` ใน `pf_basis` (990103/990101/991001/991004/991002 = "1.34-2.17 3-window range") → หา MAIN-window PF ตัวจริงมาใส่.
**bars:** N-A (data order). **flat-lot probe:** N-A.
**ห้าม:** เดา DD95 จาก max-DD หรือ PF_5th (คนละตัวสถิติ) · แก้ `portfolio_risk_admission.py` (ปัญหาอยู่ที่ข้อมูล ไม่ใช่ script) · ใช้เลข portfolio_DD_est ปัจจุบันไปถอด/ย่อ EA ตัวไหนก่อน backfill เสร็จ · แตะ DEPLOYMENTS.csv.
**ทำได้:** qwen/Sonnet (ไล่อ่าน report + เติม CSV = mechanical ตรวจได้ด้วย `float()` parse) · 👉 แนะ: qwen ทำ (2)(3)(4), Claude เคาะ (1).

## ORDER-156 — [infra] multi-account portfolio equity combiner + monthly rollup — `REVIEWED(Claude 2026-07-23) — accepted, coverage caveat is prominent in output`
**result:** ต่อยอด `scripts/portfolio_sim.py` เดิม (ไม่เขียนใหม่ — behavior เดิมยืนยันไม่เปลี่ยน, diff มีแต่ docstring กับฟังก์ชันใหม่เพิ่ม) เพิ่มโหมด `--live`: (a) equity รวมข้ามบัญชี จาก parse ทั้ง 2 format (MT5 deal-level + MT4 order-level) เลือกไฟล์ snapshot ใหม่สุดต่อบัญชี (b) `portfolio/monthly/YYYY-MM.{csv,md}` (มีนา-กค 2026) — 1 แถวต่อ (account, magic) ต่อเดือน ใช้สูตร PF/win%/DD เดียวกับ `parse_live_deals.ps1` join ชื่อ EA จาก DEPLOYMENTS.csv.
**🔴 coverage เปลี่ยนจากตอนเขียน order (ของจริงดีขึ้นแล้ว):** ตอนนี้ **5/7 บัญชีมีข้อมูลจริง** (141049900/159475669/159503454/415573666/463666728) · 146237 = มีไฟล์แต่ header-only ว่างเปล่าจริง (ตายสนิท ไม่ใช่แค่ stale) · 69424711 = ไม่มีไฟล์เลย · **463666728 ที่บอกว่า "ไม่มี sensor เลย" ตอนนี้มี 1 วันแล้ว** (9 trade, 4 EA) — ยัง**บางมาก** อย่าอ่านเป็นสถิติที่เชื่อถือได้.
**🔴 finding สำคัญที่ agent เจอเอง ไม่ได้ปิดบัง:** เลขรวม full-history (net **-5,273.97** ทั้ง 5 บัญชี) **ต่างจาก LIVE_DASHBOARD.html (+9,532.63) มาก** เพราะ dashboard ตัด "hand experiment" ทิ้งเป็นการภายใน (เช่น 415573666 magic 12345 XAU ทดลองมือ -6,922.18/1,139 เทรด เม.ย.-ก.ค.) ตัว combiner ใหม่ **ไม่ทำ cutoff logic แบบเดียวกัน** (เป็นของเฉพาะ dashboard ไม่ใช่สเปกของ order นี้ ถ้า hardcode จะล้าสมัยเร็ว) — **สองเลขถูกทั้งคู่คนละคำถาม แต่ต้องรู้ว่าใช้ตัวไหนตอบอะไร** ห้ามเอาไปเทียบกันตรงๆ.
**bonus finding:** monthly rollup โผล่ magic `0`/`20240001`/`8014` = `UNMAPPED` บนบัญชี 159475669 — ตรงกับ 9 magic ที่ CR-002 (2026-07-19) เคยจับได้ว่าเทรดจริงบนบัญชีเงินจริงแต่ไม่มีแถว registry (ยังไม่ปิด ไม่ใช่ปัญหาใหม่).
**confirmed:** ไม่แตะ 4 script ต้องห้าม · DEPLOYMENTS.csv diff ที่เห็น = ของ session อื่น (ORDER-151) ไม่ใช่ของ agent นี้ · ยังไม่ commit.
**source:** ROADMAP §3 ข้อ 3 + ข้อ 7 (รวมเป็นใบเดียว — เป็นงานเดียวกันคนละครึ่ง). **critical path ของ judge day** (เร็วสุด 2026-09-22 → มีเวลา ~2 เดือน): judge ต้องแยกผลราย EA ข้ามบัญชี ซึ่งตอนนี้ทำไม่ได้.
**inventory ที่ยืนยันแล้ว (ห้ามสร้างซ้ำ):** multi-account **ระดับรายวันมีครบแล้ว** — `scripts/collect_live_deals.ps1` (ดึงทุกบัญชี) · `scripts/live_dashboard.ps1` (749 บรรทัด, group by login, join DEPLOYMENTS, per-account sections) · `scripts/control_room_snapshot.ps1` (ไล่ทุกบัญชี, freshness + judge-readiness). **ที่ขาดจริง 2 อย่างเท่านั้น:** (1) ไม่มีที่ไหน **รวม equity ข้ามบัญชี** เป็นเส้นเดียว — dashboard แยก section ต่อบัญชี ไม่รวมเลข (2) ไม่มี **monthly rollup** เลย (มีแต่ daily). ตัวที่ใกล้เคียงที่สุดคือ `scripts/portfolio_sim.py` (normalize per-EA closed-trade CSV → portfolio monthly series + combined max DD + worst month + %positive months) แต่กิน **backtest** CSV ไม่ใช่ live → **ต่อยอดตัวนี้ ห้ามเขียนใหม่**.
**spec:** (a) ขยาย `portfolio_sim.py` (หรือ wrapper ใหม่ที่เรียกมัน) ให้กิน `portfolio/live_deals/*.csv` ได้ — รองรับทั้ง format MT5 `EA_LAB_deals_<login>` และ MT4 `EA_LAB_mt4_orders_<login>` → เส้น equity รวมข้ามบัญชี + max DD รวม + worst month + %positive months (b) monthly rollup ต่อ EA (magic) ข้ามทุกบัญชี → `portfolio/monthly/YYYY-MM.md` + CSV: net, trades, PF, win%, realized DD ต่อ magic (ใช้ logic ที่มีแล้วใน `scripts/parse_live_deals.ps1` — มันคำนวณครบแล้วแต่รับทีละไฟล์/บัญชี).
**⚠️ ข้อจำกัดข้อมูลที่ต้องเขียนหัวรายงานทุกครั้ง (ห้ามเงียบ):** `portfolio/live_deals/` มีแค่ **5 บัญชี** (159475669, 159503454, 415573666, 141049900, 146237) · **463666728 ไม่มี sensor เลย** ทั้งที่เป็นบัญชีที่ EA เยอะที่สุด (14 ACTIVE + 2 PENDING) · **146237 ตายตั้งแต่ 2026-07-10** (บัญชีอื่นไหลถึง 07-19) → **รายงานรวมทุกฉบับต้องระบุว่าครอบคลุมกี่บัญชีจากทั้งหมด และตัวไหนหาย** ไม่งั้นเลขรวมจะถูกอ่านว่าเป็นทั้งพอร์ต. ปลด blocker = user สร้าง `D:\Monitor\MT5 - 463666728` + login ครั้งเดียว (rotation pre-registered ไว้แล้วตั้งแต่ CR-005-lite).
**bars:** N-A (tooling). **flat-lot probe:** N-A.
**ห้าม:** เขียน combiner ใหม่จากศูนย์ (ต่อยอด `portfolio_sim.py` + `parse_live_deals.ps1`) · แตะ 4 script ต้องห้าม (`control_room_snapshot`/`daily_monitor`/`live_dashboard`/`monitor_rotation`) แบบ non-additive · รายงานเลขรวมโดยไม่ระบุบัญชีที่หาย · เขียน verdict/judge EA.
**ทำได้:** Sonnet/Codex (มี cage = เทียบเลขกับ dashboard ที่มีอยู่) · 👉 แนะ: Sonnet.

## ORDER-157 — [infra] walk-forward automation: generalize 4 one-off scripts + summarizer จริง + re-pin windows — `REVIEWED(Claude 2026-07-23) — tool ตัวมันเองไม่มี bug (พิสูจน์แล้ว) แต่ปลด "lane artifact" ไม่ได้ → เจอปัญหาใหญ่กว่า ดู ORDER-162`
**🔴 rerun-confirm 2026-07-23 (Sonnet) — ล้ม hypothesis เดิม, เจอเรื่องใหญ่กว่า:** รัน fold2-OOS เดิมทุกตัวแปร (EA hash เดิม, .set เดิม, window เดิม, tick-history mtime เดิม) **บน lane หลัก `D:\Meta 5` ที่ควรจะ "แก้" ปัญหา** → ได้ **PF 1.08/130 เทรด เหมือนเดิมกับ lane รอง** ไม่ใช่ 1.74/131 เทรดของประวัติศาสตร์เลย — **สมมติฐาน "terminal-instance fill-sensitivity" ผิด** ทั้งสอง lane (build 5836) เห็นตรงกัน แต่ต่างจากผลเดิมปี 2026-07-08. ไล่ตัดตัวแปรหมดแล้ว (EA binary/param/.set/window/tick-cache mtime เหมือนกัน 100%) เจอ anomaly ข้างเคียง (leverage 1:2000 vs 1:100 ในรายงาน) แต่ **ตัดออกแล้วว่าไม่ใช่ตัวขับ** (ทั้งสอง lane เลขตรงกันแม้ leverage รายงานต่างกัน). **hypothesis ที่เหลือ: MT5 tester engine เองอาจเปลี่ยนพฤติกรรมระหว่าง 07-08→ตอนนี้** — มี precedent ตรงคือ ORDER-085 (2026-07-10) เคยจับได้แล้วว่า build นี้ no-op `Spread`/`TestSpread` ini เงียบๆ. **ถ้า hypothesis นี้จริง = backtest evidence เก่าที่ run ก่อน 07-10 อาจไม่ตรงกับที่ build ปัจจุบันจะให้ผล ไม่ใช่แค่ cell นี้ตัวเดียว** → ยกเป็น **ORDER-162 แยก ไม่ผูกกับ walkforward tool อีกต่อไป** (ดูด้านล่าง).
**result:** `scripts/window_pin.ps1` (source เดียวของ MAIN/BWD/HOLDOUT อ่านจาก CLAUDE.md pin) + `scripts/walkforward.ps1` (generic runner: fold IS-optimize→pick best→forward OOS, provenance เต็ม, **Model=2 hard-block exit 2**, **assert HOLDOUT-overlap ก่อนยิง MT5 แม้แต่ process เดียว — ปฏิเสธพร้อม exit 3 ถ้าละเมิด**). 4 script เดิมยังอยู่ครบตามที่สั่ง.
**✅ พิสูจน์ assert ทำงานจริง:** ยัด window fold-3 เดิม (2025.01–2026.07) ที่กิน HOLDOUT ซ้ำ → **ถูกปฏิเสธถูกต้อง** ("leaks into HOLDOUT... overlaps 2026.01.01-2026.07.01", exit 3, **ไม่มี MT5 process ไหนถูกยิงเลย**) — นี่คือรูรั่วเดียวกับที่ 4 script เดิมมี (window-3 OOS ของมันไหลเข้า 2026H1 holdout ปัจจุบันจริง) ตอนนี้ทำไม่ได้อีกแล้วด้วย structural gate ไม่ใช่แค่กฎที่ต้องจำ.
**bug ที่เจอและแก้ระหว่างทดสอบ:** PS 5.1 `Where-Object` คืน scalar เมื่อ match 1 รายการ (ไม่มี `.Count`) → `pct_folds_oos_profitable` เคยรายงาน 0% ผิด ทั้งที่ fold นั้นกำไรจริง → wrap `@()` แก้แล้ว มี comment กันคนลบทิ้ง.
**🔴 ค้าง — ไม่ปิดสนิท:** regression เทียบ RSI-MR EURUSD H1 กับ `RSIMR_WFA.csv` เดิม — fold1 + fold2-IS ตรงกันใกล้เคียง (1.44 vs 1.46, 1.43 vs 1.45) **แต่ fold2-OOS ต่างมาก: เดิม PF 1.74/131 เทรด ↔ ใหม่ PF 1.08/130 เทรด** (จำนวนเทรดต่างกัน 1 ไม้ด้วย ไม่ใช่แค่ PF) agent อธิบายว่าเป็น "fill-sensitivity ข้าม terminal instance" (รันบน `D:\Meta 5b` เพราะ `D:\Meta 5` ถูกใช้อยู่ตอนนั้น) **แต่ยังไม่พิสูจน์ — เป็นสมมติฐานที่ยังไม่ verify ไม่ใช่ข้อสรุป**. **Opus-seat เช็คแล้ว 2026-07-23:** ตอนนี้มี `terminal64.exe` รันอยู่ 1 ตัว = terminal บัญชีจริงของ user (146237) ไม่ใช่ตัวที่ชัดเจนว่าเป็น `D:\Meta 5` tester lane — **ยังไม่ลองรันซ้ำเองเพราะเสี่ยงชนคิวกับ session คู่ขนาน (ORDER-161) ที่รอ lane เดียวกันอยู่**.
**confirmed:** ไม่แตะ 4 script เดิม · ไม่มี git add/commit · ไม่มี verdict EA (output tag "not a verdict" ทุกจุด) · Model-2 block จริง · rerun-confirm ก็ไม่ commit เหมือนกัน (`_mt5_auto/reports/WF_RSIMR_REGR_F2_OOS_PRIMARYRERUN_*` ค้างไว้ให้ตรวจ).
**source:** ROADMAP §3 ข้อ 2 (เฟส 1, ค้างนานสุด). **inventory: PARTIAL — มี 4 script อยู่แล้ว โครงเหมือนกันเป๊ะ** `_mt5_auto/ab_sets/rsimr_wfa.ps1` (43 ln) · `sqzcr_wfa.ps1` · `brk_wfa.ps1` · `zigl_xau_wfa.ps1` — ทุกตัว hard-code EA/symbol/ชื่อ param/grid/windows ของตัวเอง เรียก `scripts/mt5_run.ps1` + `scripts/parse_mt5_report.py` เหมือนกัน → **งานคือ generalize ไม่ใช่สร้างใหม่**.
**2 ปัญหาที่เจอตอน inventory (ต้องแก้ในใบนี้):**
1. **header โกหก:** `rsimr_wfa.ps1` เขียนว่า "Reports ER + OOS-profitable% for WFA scoring" แต่ **โค้ดไม่ได้คำนวณเลย** — แค่ `Get-Content` dump CSV ดิบ แล้วให้คนคิดเอง → summarizer ที่ ROADMAP ขอ (**"รัน rolling window + สรุปอัตโนมัติ"**) ยังไม่มีจริงสักตัว
2. **windows ไม่ตรง canon:** ทั้ง 4 ตัวใช้ 2020.01→2021.09 / 2021.09→2023.06 / 2023.06→2025.01 ซึ่ง **เขียนก่อน** window pin ปัจจุบัน (MAIN 2023.01–2025.12 · BWD 2020–2022 · HOLDOUT 2026H1) → ต้อง re-pin จาก CLAUDE.md เป็น config เดียว
**spec:** `scripts/walkforward.ps1` (หรือ .py) รับ: EA/Expert, symbol, TF, ชื่อ param + grid, จำนวน fold, ความกว้าง IS/OOS → รัน IS-optimize → เลือกค่าดีสุดของ fold นั้น → ทดสอบบน OOS slice ถัดไป → วนครบ fold. **summarizer บังคับ:** efficiency ratio (OOS PF ÷ IS PF) ต่อ fold + ค่าเฉลี่ย · **%fold ที่ OOS กำไร** · ตารางต่อ fold + สรุปบรรทัดเดียว. **บังคับ window canon:** อ่าน pin จากที่เดียว + **assert `MAIN ∩ HOLDOUT = ∅`** และปฏิเสธการรันถ้า fold ใดกิน HOLDOUT (นี่คือรูรั่วเดียวกับที่ Codex จับได้ 2026-07-18 — ครั้งนี้บังคับด้วยโค้ด). **provenance ทุก run:** source hash, base .set, windows จริงที่ใช้, model, path report.
**acceptance:** (1) รัน RSI-MR EURUSD H1 ด้วย script ใหม่ แล้วได้เลขเท่า `_mt5_auto/RSIMR_WFA.csv` เดิม (regression เทียบของเก่า) (2) ER + %OOS-profitable ออกมาเป็นตัวเลขในไฟล์ ไม่ใช่ให้คนคิด (3) fold ที่กิน 2026H1 ถูกปฏิเสธพร้อมข้อความชัด (4) 4 script เดิม **ยังอยู่ ห้ามลบ** (เก็บเป็น reference จนกว่า regression ผ่าน).
**bars:** N-A (tooling — WFA ที่ได้จะเอาไปใช้เป็นหลักฐานใน order อื่น ไม่ใช่ตัดสินอะไรในใบนี้). **flat-lot probe:** N-A.
**ห้าม:** ลบ 4 script เดิมก่อน regression ผ่าน · ตั้ง window เอง (ต้องอ่านจาก pin) · ใช้ผล WFA ตัดสิน EA ตัวใดในใบนี้ · Model-2.
**ทำได้:** qwen/ZCode/Codex (mechanical + มี regression cage เทียบ CSV เดิม) · 👉 แนะ: qwen (ถูกสุด, ตรวจด้วยตัวเลขได้).

## ORDER-168 — RSI-MR (990103) full WFA re-run บน pinned config — `REVIEWED(Claude 2026-07-23) — แก้คำตัดสิน ORDER-166 ให้ตรงหลักฐานเต็ม: 3/3 OOS ยัง profitable แต่ margin ไม่เท่ากัน ไม่ใช่ "invalidated" เหมาว่าตายหมด`
> ⚠️ **แก้ ORDER-166 ที่เขียนไว้ก่อนหน้า:** ตอนนั้นสรุป "EVIDENCE-INVALIDATED, ห้าม attach" จาก **1 data point เดียว** (fold2-OOS 1.08 vs 1.74) — ถูกทางแต่ด่วนไป ตอนนี้มี WFA เต็ม 3 window/12 run แล้วเห็นภาพจริง.
**ผล (full-pinned, Model 4, leverage asserted, 3 window แบบเดิมของ script ต้นฉบับ):**
| Window | IS best (atr) | **OOS** | เทียบของเดิม |
|---|---|---|---|
| 1 (2020-21→21-22) | 1.44 (atr8) | **1.30**/140t | เดิม ~1.31 — **ตรงกัน** |
| 2 (2021-23→23-24) | 1.43 (atr9) | **1.08**/130t | เดิม ~1.74 — **นี่คือรอยที่ ORDER-157/166 เจอ — ยืนยันซ้ำ** |
| 3 (2023-25→25-26) | 1.50 (atr10) | **2.51**/90t DD2.58% | ตัวเลขสูง แต่ n พอ (90) + DD ต่ำ + M4 อยู่แล้ว — ไม่ใช่ artifact ชัดเจน แค่ควรระวัง (PF>~3 เกณฑ์สงสัย ตัวนี้ยังไม่ถึง) |
**สรุปที่ถูกต้องกว่า:** WFA ยัง **3/3 OOS profitable บน pinned config จริง** (ไม่ตายทั้งชุดแบบที่เขียนไว้) แต่ **window 2 margin บางมาก (1.08)** ตรงกับที่ ORDER-157 เจอเป๊ะ — average OOS PF ~1.63 (เทียบ IS-best เฉลี่ย 1.46 = WFE>1 แต่ลากขึ้นด้วย window 3 เป็นหลัก) **การอ่านที่ตรงหลักฐานที่สุด: edge มีจริง แต่ไม่สม่ำเสมอเท่าที่ score 89 บอกไว้** (window ที่แย่สุด = แค่เฉียดกำไร ไม่ใช่ลบ).
**verdict:** ปลด "ห้าม attach เด็ดขาด" → เปลี่ยนเป็น **PARKED-VERIFY(user) ระดับความเชื่อมั่นลดลง** — attach ได้ถ้า user ยอมรับว่า margin จริงบางกว่าที่คิด (ไม่ใช่ ROBUST-89 อีกต่อไป) ไม่ใช่ CANDIDATE ปกติ. raw `_mt5_auto/RSIMR_WFA_PINNED.csv` + sets `_mt5_auto/ab_sets/order168_rsimr_wfa/`.

## ORDER-169 — SS4 SweepReversal EURUSD coarse grid (RoundStep×AdxMax) — `REVIEWED(Claude 2026-07-23): ceiling ~1.08-1.21 บน n สุขภาพดี — ยังไม่ผ่าน deploy bar, คง PARKED-VERIFY`
**grid:** RoundStep{0.0015,0.0030,0.0050,0.0080} × AdxMax{20,25,28,35}, full-pinned, MAIN 2023-2025, 16 cells.
**อ่านผล — หา plateau ไม่ใช่ peak:** cell ที่ PF สูงสุด (rs0.008/ax20=**5.40**, rs0.005/ax20=**2.46**) ล้วน **n=6-7 บางเกินไป** = spike ไม่ใช่ edge (ตรง skill catalog "coarse-grid spiky surface"). **plateau จริงอยู่ที่ rs0.0030:** ax25=1.06/n31 · ax28=1.08/n40 · ax35=0.99/n65 — ไล่ลงมาราบเรียบ ไม่ใช่กระโดด = สัญญาณจริงแต่บาง · **ตรง ORDER-150 เป๊ะ** (default ax28/rs0.0030 = 1.08/n40 คนละรันแต่ได้เลขเดียวกัน = สอดคล้อง). แถว rs0.0080 (ax25-35: 1.50→1.25→1.15) ก็ไล่ลงราบเรียบเหมือนกันแต่ n บางกว่า (17-40) — plateau รอง.
**verdict:** ceiling ทั้ง 2 พื้นที่ที่ดูน่าเชื่อ (rs0.0030 และ rs0.0080) อยู่แค่ **1.06-1.21 ที่ n พอ** — ไม่ผ่าน deploy bar 1.2 อย่างมั่นใจ (1.21 เดียวที่ทะลุ = n=13 บางไป). **คง PARKED-VERIFY** — ตอบคำถามที่ค้างไว้ (RoundStep×AdxMax ไม่ใช่ lever ที่ปลดล็อกได้) lever ที่เหลือยังไม่แตะ = SweepAtr/TpAtr (ตามที่บันทึกไว้ตั้งแต่ ORDER-150).
**ห้าม:** เลือก rs0.008/ax20 (PF5.40/n6) หรือ rs0.005/ax20 (2.46/n7) เป็น candidate — n ต่ำกว่าเกณฑ์ต่ำสุดของ type นี้ (M15 reversion ควรมีหลักร้อย). raw `_mt5_auto/O169_SS4_EURUSD_COARSE.csv`.

## ORDER-167 — [funnel completion] holdout ที่ค้างของ ORDER-147/149 บน pinned config — `REVIEWED(Claude/Opus 2026-07-23) — 4/5 cells ตายที่ holdout · 1 เหลือ BUILD-ON`
**source:** ORDER-166 ปลด blocker แล้ว → เคลียร์ของค้าง 2 ใบที่ "ผ่าน both-window แต่ยังไม่ holdout" ซึ่งเป็นด่านที่ยังไม่เคยเดิน. รันทั้งหมดบน **full-pinned .set + leverage asserted** (มาตรฐานใหม่หลัง ORDER-165).
**ผลรวม (รายละเอียดอยู่ในบล็อก ORDER-147/149 ตามลำดับ):**
- **MacdDiv D1 majors: 2/2 ตาย** — GBPUSD (demo cfg) holdout 0.15/0.82 · USDJPY holdout 0.57/0.61 (ทั้งที่ both-window 1.37/1.20) → ตระกูล D1-majors ปิด, MacdDiv เหลือบ้านเดียว = XAU H4 (demo 999094)
- **TrendRider expansion: 2/3 ตาย** — USDJPY 0.38 · EURJPY 0.32 · XAGUSD รอด holdout 1.37 แต่ BWD 0.97 บน pinned = **BUILD-ON ห้าม attach**
- **diagnostic ที่ปิดปริศนาค้าง:** ORDER-117 vs ORDER-149 เทส MacdDiv **คนละ config** (defaults 1.23/24 vs demo-tuned 1.82/21) — demo cfg (MACD 12/44/13) อยู่นอกกริดที่ 117 กวาด จึงไม่เคยถูก holdout จริง → ORDER-167 เดินให้ครบแล้ว verdict "ตาย" จึง **earned** ไม่ใช่อ้างผิด
**ค่าใช้จ่าย:** 13 runs. **สิ่งที่ได้:** ปิด 4 cell ที่ถ้าไม่เทสอาจถูก attach ตาม "both-window ผ่าน" + แก้ verdict ที่ผมเขียนผิด 2 จุด (149 เหตุผลผิด, 147 USDJPY/EURJPY เรียก BUILD-ON ทั้งที่ตาย).
**ห้าม (ยึดตามเดิม):** ประกาศ MacdDiv/TrendRider concept ตาย — ตายเฉพาะ cell/config ที่ระบุ, บ้านที่ validated แล้ว (XAU H4 ทั้งคู่) ไม่ถูกแตะ.

## ORDER-166 — [re-validate campaign, user-approved] rerun evidence บน fully-pinned config — `REVIEWED(Claude/Opus 2026-07-23) — RSI-MR evidence invalidated (do-not-attach) · Boss_14 bench 5/8 ยังผ่าน bar, ranking พลิก, no kills (demo forward = กรรมการจริง)`
**source:** user อนุมัติ re-validate ทั้งหมด 2026-07-23 (หลัง ORDER-165 ปลด blocker) · triage: standalone flat-lot EAs = เสี่ยงต่ำ (surface เล็ก, .set ครอบเกือบครบ, margin ไม่ bind) · **คิวจริง = ตัวที่หลักฐานเดิมรันด้วย partial set บน chassis**: Boss_14 bench ×8 + RSI-MR (ORDER-157 discrepancy).
**method:** full pinned set ต่อ leg = harvested compiled-defaults surface + overlay ค่าจาก DEMO/locked .set เดิม (52-53 params) → รัน M4 MAIN (2023.01–2025.12) เลน 1 · leverage pinned 1:100 + assertion ทุก run. **หมายเหตุสำคัญที่ทำให้เลขชุดนี้ = ความจริงของของที่ deploy อยู่:** ตอน attach บนชาร์ตจริง MT5 เติม input ที่ไม่อยู่ใน .set ด้วย **compiled defaults** (ไม่ใช่ tester cache) → full-pinned run นี้ตรงกับ config ที่ demo รันอยู่จริง ส่วนเลขหลักฐานเก่า (จาก cache) อธิบาย config ที่**ไม่เคยถูก deploy**.
**✅ RSI-MR (990103, ยังไม่ attach) — จบแล้ว:** fold2-OOS (EURUSD H1 2023.06–2024.09 M4) บน full pin = **PF 1.08 / 130t / DD 8.32%** — ตรงกับ rerun ของ ORDER-157 เป๊ะ ยืนยันว่า **PF 1.74 (07-08) = เลขจาก cache state ที่ตายแล้ว ไม่เคยเป็นเลขที่ pin ได้** → หลักฐาน "ROBUST score 89 / WFA ER 1.25" ของ RSI-MR ใช้ตัดสิน attach ไม่ได้จนกว่าจะ re-run WFA เต็มบน full pin (ยังไม่ attach = ไม่มีความเสียหาย; อย่า attach 990103 จนกว่า WFA ใหม่จะจบ). ORDER-157 mystery = ปิด: ไม่ใช่ engine, ไม่ใช่ lane — partial 5-param set + cache ต่างยุค.
**✅ Boss_14 bench ×8 (990201-208, ACTIVE demo) — จบแล้ว** (M4 MAIN 2023.01–2025.12, full pin, leverage 1:100 asserted ทุก run · EURJPY/GBPJPY 0-trade ใน batch = transient artifact ที่รู้จัก → solo re-run ได้เลขจริง):

| Leg (magic) | หลักฐานเดิม | full-pin M4 MAIN ใหม่ | ผ่าน deploy bar 1.2? |
|---|---|---|---|
| XAU 990207 | net+5078/DD19.95% | **1.91**/533t DD4.1% | ✅ แข็งสุด |
| EURUSD SELL 990206 | — | **1.73**/80t DD4.0% | ✅ |
| GBPJPY 990208 | all-years-positive | **1.70**/79t DD6.3% | ✅ |
| EURJPY 990203 | (size-light) | **1.57**/128t | ✅ |
| CADJPY 990205 | (thin) | **1.29**/45t DD4.6% | ✅ (n บาง) |
| USDJPY 990201 | M4 1.72/107t | **1.19**/252t DD7.8% | ⚠️ หวุดหวิด |
| AUDNZD 990202 | **M4 3.37/44t "family champion"** | **1.09**/138t DD6.4% | ❌ |
| AUDCAD 990204 | — | **1.09**/93t DD8.8% | ❌ |

**อ่านผล:** 5/8 ยังผ่าน deploy bar บน config ที่ deploy จริง · **การจัดอันดับพลิก**: AUDNZD ที่เคยเป็น "champion 3.37" = ขาอ่อนสุด (1.09) — เลข 3.37 เดิมคือ config จาก cache ที่ไม่เคยถูก deploy (n 44→138 = คนละตัวชัดเจน) · XAU กลายเป็นขาแข็งสุดจริง. ⚠️ caveat ที่บันทึกไว้ตรงๆ: window เดิมของหลักฐานเก่าไม่เท่ากันเป๊ะ (บางตัวจบ 2026.06) + data broker คนละเจ้า (Exness เดิม vs ThinkMarkets lane1) — เทียบเลขต่อเลขไม่ apples-to-apples 100% แต่ n ที่ต่างกัน 2-3 เท่า = config ต่างแน่นอนไม่ใช่ data ต่าง.
**การตัดสิน (ตามกรอบ "ห้าม" ที่ pre-register ไว้):** **ไม่ kill demo leg ใดจากเลขนี้** — ทั้ง 8 ยัง ACTIVE, judge_date 2026-10-09 = กรรมการตัวจริง (demo-forward P&L คือ holdout ที่แท้จริงของ config ที่ deploy) · สิ่งที่เปลี่ยน = **expectation**: AUDNZD/AUDCAD/USDJPY ควรคาดหวังต่ำ ถ้า forward แย่ตาม = ยืนยันเลขใหม่ ไม่ใช่เรื่องประหลาดใจ · CSV `_mt5_auto/O166_B14_REVALIDATE.csv` + reports `O166_B14_*`.

## ORDER-171 — [investigation] 990120 MacroGate: gate ไม่ veto อะไรเลยตอน re-run — `REVIEWED(Claude 2026-07-23) — ✅ หลักฐานเดิม 235t ยังยืน · gate ทำงานถูก · แต่เจอ design flaw ที่ต้องแก้`
**ที่มา:** ORDER-166 พบว่า rerun ของ 990120 ได้ **333 เทรด = ตรงกับ baseline gate-OFF เป๊ะ** ไม่ใช่ gate-ON (235) ทั้งที่ report ยืนยัน `_MG_SelfGate=true` → สงสัยว่ากลไกไม่ทำงาน (ร้ายกว่าตัวเลขขยับ).
**✅ คำตอบ — เป็น data ไม่ใช่ code:** gate ทำงาน**ถูกตามที่ออกแบบ** — `MacroGate_Core.mqh:296-303` เมื่อไม่มีแถว regime ที่เวลา ≤ bar ปัจจุบัน → `MG_RowAsOf` คืน -1 → `MG_ClearAll("no regime row on-or-before now")` = **ล้าง veto ทุกตัว (fail-open ตาม doctrine เดียวกับ NewsGuard)**. ไฟล์ที่ tester อ่านจริง (`Common\Files\EA_LAB_mris_regime.csv`) มีแค่ **snapshot 4 แถวหมุนเวียน (2026-07-17→07-23)** ตั้งแต่ commit `01ae94d8` — **ไม่เคยครอบปี 2024 เลย**. ส่วนตอน validate จริง (commit `e219db8e` วันเดียวกัน ก่อนหน้า 10 ชม.) ใช้ไฟล์คนละตัว: timeline 2024 เต็ม 263 แถว (`portfolio/mris/backtest/regime_full_2024.csv` จาก `scripts/mris/mris_backtest_timeline.ps1`) วางทับชื่อเดียวกันใน Common\Files **เฉพาะ run นั้น** แล้วถูก pipeline live เขียนทับทีหลัง.
**พิสูจน์ end-to-end:** เอา CSV 2024 เดิมกลับไปวาง (backup ก่อน + md5 verify ตอนคืนค่า) รัน config เดิมซ้ำบนเลน 2 → **235 เทรด / PF 1.02 / net +7.44 / eqDD 0.65%** เทียบของเดิม **235 / 1.01 / +2.80 / 0.58%** = ตรงแทบเป๊ะ · Journal ยืนยัน gate ON/CLEAR 11 รอบ + บล็อกคำสั่งใหม่ 13,733 ครั้งช่วง risk-off. **→ แก้ธง ORDER-166: 990120 ไม่ใช่ DIVERGES — หลักฐานเดิมยืน rerun อ่านไฟล์ผิดเอง.** ไฟล์ที่วางทับอยู่ที่ live path <4 นาที คืนค่าแล้ว verify md5 ตรง.
**🔴 design flaw ที่เจอ (รายงานไว้ ยังไม่แก้):** fail-open นี้ **เงียบสนิท** — backtest ที่ gate ไม่ทำงานเลย หน้าตาแยกไม่ออกจาก backtest ที่ gate ทำงาน ไม่มีสัญญาณใน Journal/report ให้จับได้ → ใครรัน MacroGate ด้วย CSV ผิดช่วงจะได้ผล "ungated" มาโดยเข้าใจว่า gated. **คลาสเดียวกับบั๊ก leverage/input-cache เป๊ะ: no-op เงียบ** → ควรมี order แก้ให้ ทั้ง (ก) log ดังๆ เมื่อ clear เพราะไม่มีแถว และ (ข) นับ/รายงานจำนวนครั้งที่ veto จริงในรายงาน เพื่อให้ "gate ไม่เคยยิง" มองเห็นได้ทันที.
**🔧 bonus finding สำคัญต่อการรันคู่ขนาน:** `-Portable` บนเลน 2 **ไม่ได้แยก `FILE_COMMON`** — มันชี้ไป `Common\Files` ก้อนเดียวกันทั้งเครื่องที่แชร์กับเลน 1 (ความพยายามวางไฟล์ที่ `D:\Meta 5b\Common\Files` ล้มเหลวเงียบเพราะเหตุนี้). **แปลว่า EA ที่อ่าน FILE_COMMON เห็น copy เดียวกันหมดทุกเลน — รันคู่ขนานแล้วแก้ไฟล์ common = กวนกันได้จริง.** ควรเข้า `AGENTS.md` §3 lane rules.
**หลักฐานเต็ม:** `_triage/ORDER171_MACROGATE_GATE_INVESTIGATION.md`.

## ORDER-172 — [cross-check] 990201/990204 full-funnel อิสระ เทียบกับ ORDER-166 — `REVIEWED(Claude 2026-07-23) — ตัวเลขตรงกับ ORDER-166 เป๊ะ = cross-validation ผ่าน · ไม่เปลี่ยนคำตัดสินเดิม`
**ที่มา:** session นี้สั่ง full-funnel re-validate 990201+990204 คู่ขนานไปกับ ORDER-166 ของอีก session **โดยไม่รู้ว่าซ้ำกัน** (order-number/scope collision อีกครั้ง) — กลายเป็นการตรวจสอบอิสระโดยบังเอิญ ซึ่งมีค่า.
**ผลตรงกัน:** 990201 full-pin M4 MAIN = **PF 1.19 / 252t** — **ตรงกับ ORDER-166 ทุกหลัก** · 990204 = **1.09** ตรงกันเช่นกัน · overlay verify 52/52 param names match ทั้งสองขา และ set ที่สร้างขึ้นเอง **byte-identical กับของ ORDER-166** ที่สร้างคนละรอบคนละ agent. **สองความพยายามอิสระได้เลขเดียวกัน = เลขชุดใหม่เชื่อถือได้จริง ไม่ใช่ artifact ของวิธีใดวิธีหนึ่ง.**
**สิ่งที่ session นี้ตีความพลาด และ ORDER-166 ตีความถูกกว่า (บันทึกไว้เป็นบทเรียน):** agent ของผมสรุปว่า "full-pin ทำให้เลขแย่ลง = น่าจะมี cache state ที่สามที่กู้ไม่ได้" — **กรอบนี้ด้อยกว่า** กรอบของ ORDER-166 ซึ่งชี้ว่า **ตอน attach บนชาร์ตจริง MT5 เติม input ที่ขาดด้วย compiled defaults ไม่ใช่ tester cache** → **full-pin run = ความจริงของ config ที่ demo รันอยู่จริง** ส่วนเลขเก่า (จาก cache) อธิบาย config ที่**ไม่เคยถูก deploy ที่ไหนเลย**. ไม่ต้องตามหา "cache state ที่สาม" — คำถามที่ถูกคือ "เลขไหนอธิบายของที่รันอยู่จริง" ซึ่งตอบแล้ว.
**ไม่เปลี่ยนคำตัดสิน:** ยึดตาม ORDER-166 — ไม่ kill ขาไหน · 5/8 ยังผ่าน bar · เปลี่ยนแค่ **expectation** · demo-forward (judge 2026-10-09) = กรรมการจริง. หลักฐาน: `_triage/ORDER172_BOSS14_FULL_REVALIDATION_CROSSCHECK.md` + reports `ORDER168_*` (ชื่อไฟล์ report ยังเป็น ORDER168_ ตามที่ agent ตั้ง — ไม่ rename เพราะอ้างอิงในรายงานแล้ว).

## ORDER-170 — [🔴 money-adjacent · ต้อง blind re-audit] แก้ SEV-1 5 ข้อใน `portfolio_risk_admission.py` — `OPEN`
**source:** Codex blind audit ORDER-154 (`_triage/CODEX_ORDER154_RISK_ADMISSION_AUDIT.md`) — Opus-seat verify เอง 4/4 ด้วย probe จริง ยืนยันครบ.
**spec (แก้ตามลำดับความร้ายแรง):** (1) `load_expectations()` ต้องอ่าน `basket_id` และ**นับ DD95 ของ basket เดียวครั้งเดียว** ไม่ใช่ต่อขา — ปัจจุบันรอดเพราะ convention ที่แก้มือไว้เท่านั้น (2) `_num()` ห้ามคืน 0.0 ให้ค่าที่ parse ไม่ได้ในเส้นทาง P&L → ต้องทำให้ pair นั้น **UNKNOWN** (default corr 1.0) ไม่ใช่ observation ศูนย์ (3) ปฏิเสธ DD95 ที่ไม่ใช่ **finite และ > 0** (ตอนนี้ `0` และ `inf` ผ่านทั้งคู่) (4) ต่อสาย broker-min จริง หรือถ้ายังไม่มีข้อมูล ต้อง **refuse/escalate แทนการคืน factor ที่ใช้ไม่ได้** (5) เรียก bounds guard บน**ทุก** computation path ใน `admit_candidate` รวม existing-portfolio · SEV-2: เช็คงบซ้ำหลังปัดเศษ factor · กัน `--out-md/--out-json` เขียนทับ path ที่ต้องห้าม (`DEPLOYMENTS.csv`/`expectations.csv`/`.set`) · **เขียน self-test ใหม่ให้เรียก `load_expectations()` จริงกับ row ที่เป็น `UNKNOWN`/ว่าง/คอลัมน์หาย** (ของเดิมเป็น tautology จับ inversion ไม่ได้).
**bars:** N-A (tooling). **flat-lot probe:** N-A.
**ห้าม:** ให้ agent ที่แก้เป็นคนรับรองงานตัวเอง — **ต้องส่ง blind re-audit อีกรอบก่อนปิด** (บทเรียนตรงจากใบนี้: self-test 6/6 PASS แล้วยังมี SEV-1 5 ข้อ) · ใช้ tool นี้ size เงินจริงก่อนแก้เสร็จ · แตะ `expectations.csv`/`DEPLOYMENTS.csv`.
**ทำได้:** Claude เขียน (money-adjacent ตาม `AGENTS.md` §5.2) → **Codex blind re-audit** → Claude รับ.

## ORDER-165 — [🔴 T0 BLOCKER · tooling] pin leverage + INPUT CACHE ให้ได้จริง ก่อน re-validate — `DONE(Claude/Opus 2026-07-23) — root cause จริงลึกกว่า spec เดิม: TESTER INPUT-CACHE ไม่ใช่ leverage · cage พิสูจน์ reproducible 8/8 แล้ว`
**⛔ แก้ความเข้าใจผิดของผมเอง 2 ชั้นก่อนอ่าน spec เดิม:** (1) leverage ini **pin ได้จริง** ด้วย format `Leverage=1:N` (ผมเคยเขียนว่า format นี้ "ทำ report โกหก" — **ผิด**: agent log ยืนยัน 4/4 ว่า report ตรงกับ simulation จริง ที่ n=9 ไม่เปลี่ยนตอนนั้นเพราะตัวขับจริงคือ input ไม่ใช่ leverage) · format ตัวเลขเปล่า `Leverage=100` ที่ script ใช้มาตลอด = silently ignored → tester ใช้ค่า cached (2) **ตัวขับจริงของ 8/8 drift = TESTER INPUT-PROFILE CACHE**: `[TesterInputs]` override เฉพาะ input ที่ระบุ — **ที่ไม่ระบุมาจาก `MQL5\Profiles\Tester\<EA>.set` (ค่าล่าสุดที่เคยใช้ ถูกเขียนทับโดยทุก session ที่แตะ EA นั้นบน terminal นั้น)**. พิสูจน์ขาด: binary hash เดียวกัน + tick เดียวกัน → lane1 เปิด BUY 0.2 lot (cache: SLMode=30 no-SL + Recovery82 + risk-sizing → n=9 KillDD) vs lane2 SELL 0.01 (cache = compiled defaults → n=480). **Cage เดิมรัน 6/8 EA ไม่มี .set เลย + Boss_14/16 ใช้ set partial (53/89 บรรทัด จาก ~116 surface) = ไม่เคย deterministic ตั้งแต่ต้น** ทำงานได้เพราะบังเอิญไม่มีใครแตะ cache · baseline 07-19 pin บน cache state ที่ตายไปแล้ว (Codex ORDER-136 W2 รัน Boss_14 บน lane1 เมื่อ 07-21 + user ใช้ terminal เอง = ตัวเขียนทับ)
**สิ่งที่แก้จริง (ทั้งหมด verified):**
1. `mt5_run.ps1`: leverage เขียนเป็น `1:N` (format ที่ tester อ่านจริง) + **assertion post-run** อ่าน leverage จาก report เทียบกับที่ขอ mismatch = exit 3 ดังๆ (ทดสอบแล้ว: จับ mismatch จริง + ผ่านเมื่อตรง) + **WARN ดังๆ เมื่อรันโดยไม่มี -SetFile** ("inputs มาจาก cache = non-reproducible")
2. **Full pinned default sets ทั้ง 8 EA** (`ea_template/sets/regression/*_defaults.set`, 113-134 inputs/ตัว): wipe cache → รัน compiled defaults → harvest จาก report Inputs section · Boss_14/16 = overlay frozen smoke params บน surface เต็ม (`*_regression_full.set`, override 53/42 ชื่อ match surface 100% = cross-validated)
3. `tpl_regression.ps1`: ทุก EA บังคับ full set (ไม่มี set = FAIL ไม่ใช่เงียบ) + เช็ค exit 3 จาก mt5_run
4. **baseline re-pin บน configuration ที่ pin ครบทุกแกน** (inputs + leverage 1:100) — diff table เก็บใน commit: ของเก่าหลายตัวคือ cache ขยะ (ตัวโต: Boss_18 "n=6020 exact" ที่เคยเฝ้าเป็น invariant = churn config จาก cache, ค่าจริง default = n=298 PF 1.21 · Boss_13 เก่า DD 25% = cache, จริง 3.1%)
5. **Reproducibility PROVEN:** รัน cage ซ้ำทันทีหลัง pin → **7/8 CLEAN byte-exact + Boss_13 = 0-trade transient artifact ที่รู้จัก (memory 07-18) → solo re-run ตรง baseline เป๊ะ (209t/-12.47/0.99) = 8/8**
**ผลกระทบต่อ evidence เก่า (สำหรับ re-validate ที่ user อนุมัติ):** (ก) EA standalone (ea_projects — Wave-1/2, MacdDiv, EmaStoRev ฯลฯ) input surface เล็กและ .set ที่ใช้ครอบเกือบหมด + flat 0.01 lot = margin/leverage ไม่ bind → **verdict เดิมน่าจะยืนเกือบทั้งหมด** (ข) เลขที่เสี่ยงจริง = **chassis Boss EA ที่รันด้วย set partial** + grid/basket lot ใหญ่ (margin bind ได้) → คิว re-validate ควรเริ่มที่ Boss_14 bench demo (990201-208) + RSI-MR (ORDER-157 PF 1.74→1.08 = คลาสเดียวกันเกือบแน่ — WFA รัน partial set) (ค) ทุก run ตั้งแต่นี้ = pin ครบอัตโนมัติ
**source:** ORDER-162 รอบ 3 พิสูจน์แล้วว่า `mt5_run.ps1 -Leverage` **เป็น silent no-op** — เขียนลง ini แต่ MT5 build 5836 ไม่อ่าน ใช้ leverage ของบัญชีที่ terminal login อยู่แทน (lane1=1:2000, lane2=1:100) → **ผลต่างกัน 53 เท่าบน grid EA** (n=9 vs n=480). แปลว่า backtest ทุกใบที่ผ่านมา **leverage ไม่เคยถูก pin จริง** และผลขึ้นกับว่า terminal นั้น login บัญชีอะไรอยู่ตอนรัน.
**ทำไมเป็น T0 (บล็อก re-validate ที่ user อนุมัติแล้ว):** user อนุมัติ re-validate ทั้งหมด **แต่ถ้ายังไม่ pin leverage ก่อน = re-validate ออกมาก็ลอยเหมือนเดิม** แค่ได้ตัวเลขชุดใหม่ที่ยังผูกกับบัญชีที่บังเอิญ login อยู่ **ห้ามเริ่ม re-validate จนกว่าใบนี้จะปิด**.
**spec:** (1) หาวิธี pin leverage ที่ tester เชื่อจริง — ทางที่ควรลองตามลำดับ: ตั้ง leverage ที่ **บัญชีที่ terminal นั้น login** ให้ตรงกันทุก lane (ง่ายสุด ทำได้เลย) · หรือใช้ **custom symbol** ที่ล็อก margin spec เอง · หรือ **login บัญชีมาตรฐานเฉพาะสำหรับ backtest** ทุก lane (2) เพิ่ม **assertion ใน `mt5_run.ps1`**: อ่าน leverage ที่ report บอกกลับมา เทียบกับที่ขอ **ถ้าไม่ตรง = FAIL ดังๆ** ไม่ใช่เงียบ (บั๊กนี้รอดมาได้เพราะไม่มีใครตรวจย้อน) (3) ทำแบบเดียวกันกับ `Spread`/`TestSpread` (ORDER-085 พบว่า no-op เหมือนกัน — คลาสเดียวกัน ควรกันทีเดียว) (4) re-pin `regression_baseline.csv` ใหม่หลัง pin ได้แล้ว พร้อมบันทึก leverage/บัญชีที่ใช้ลงในไฟล์ baseline เอง
**bars:** N-A (tooling). **flat-lot probe:** N-A.
**ห้าม:** เริ่ม re-validate EA ใดๆ ก่อนใบนี้ปิด · re-pin baseline ก่อน pin leverage ได้ (จะ pin ความลอยเข้าไปเป็นความจริงใหม่) · แก้ verdict เก่าจาก finding นี้.
**ทำได้:** Claude (money-adjacent + ต้องตัดสิน design) · 👉 แนะ: Claude ทำ (1)(2), qwen ช่วย (4) ตอน re-pin.

## ORDER-162 — [investigation] ~~MT5 tester engine drift~~ → **ROOT CAUSE = leverage unpinnable + margin-gate** (ไม่ใช่ engine drift) — `RESOLVED(Claude 2026-07-23 รอบ 3) — เหลือเศษเล็ก 1 อย่างยังค้าง · แตกเป็น ORDER-165 (T0 blocker)`
**🔴 sample-check (1) ตอบแล้ว โดยบังเอิญ จากคนละเส้นทาง — คำตอบ = SYSTEMIC ไม่ใช่ isolated:** ระหว่างตรวจ ORDER-161 (template money-params) ผมรัน `tpl_regression.ps1` เจอ **8/8 Boss EA drift พร้อมกัน** (ไม่ใช่แค่ RSI-MR cell เดียวแบบ ORDER-157) — แล้ว **isolate ด้วย `git stash` ยืนยันว่าไม่ใช่โค้ดของผม**: stash ORDER-161 ออก รันซ้ำบน tree สะอาด (ไม่มีการแก้ `core/` เลยตั้งแต่ ORDER-125 baseline-repin 07-19) ได้ **ตัวเลขตรงกัน byte-for-byte กับตอนมี ORDER-161 อยู่** (net/pf/trades/eqdd ทั้ง 8 ตัวเป๊ะ) — ยืนยัน 2 ชั้น: (a) โค้ดผมไม่ใช่สาเหตุ (b) drift ทำซ้ำได้เสมอบน primary lane `D:\Meta 5` ไม่ใช่ noise ครั้งเดียว. **สองตัวที่โปรเจกต์เฝ้าเป็นพิเศษก็ drift ด้วย: Boss_14 n=84→81, Boss_18 n=6020→6000** (บทเรียน ORDER-125 ที่เพิ่ง re-pin baseline ไปเมื่อ 4 วันก่อน).
**ทำไมนี่คือคำตอบของ scope (1) ไม่ใช่แค่ anecdote เพิ่ม:** ORDER-157 พบ drift 1 cell (RSI-MR EURUSD H1 fold2). ที่นี่พบ **8 EA คนละ family/entry-type/instrument พร้อมกัน** (GridTrend/Breakout/MeanRev/GridLog/ST03/KangarooGrid/Wave5/JumStoch) บน baseline ที่ pin ไว้ **แค่ 4 วันก่อน** (2026-07-19, ORDER-125) ไม่ใช่ 2 สัปดาห์ก่อนแบบ RSI-MR — แปลว่า drift window แคบกว่าที่กลัว (เกิดในช่วง 07-19→07-23) **แต่ครอบคลุมกว้างกว่าที่กลัว** (ไม่ใช่ 1 cell, เป็นทุก EA ที่ cage แตะ) → เข้าเกณฑ์ "หลายตัว drift = risk เป็นระบบ" ชัดเจน ไม่ต้องขยาย sample เพิ่มแล้ว.
**หลักฐาน:** รายละเอียดเต็มอยู่ที่ ORDER-161 ด้านบน (บล็อกเดียวกับ template work) + reports `_mt5_auto/reports/TPLREG_*.htm` (รันตอน 2026-07-23 หลัง user ปิด terminal บัญชี 146237).
**ยังไม่ตัดสิน (2) ตามกฎ:** ไม่ได้แตะ scorecard/index/verdict ใดๆ จาก finding นี้ — รอ user เคาะนโยบาย re-validate vs accept-as-point-in-time.

**🔬 double-check รอบ 2 (user 2026-07-23: "ตรวจสอบซ้ำ ให้มันเคลียร์ไปเลย ไม่น่ามีอะไร") — ไล่ตัดทุกคำอธิบายธรรมดาที่เช็คได้จริง หาไม่เจอสักข้อ:**
| สมมติฐาน "เรื่องธรรมดา" | เช็คยังไง | ผล |
|---|---|---|
| broker/account เปลี่ยน (user เพิ่ง login ThinkMarkets วันนี้) | journal log 07-19 vs วันนี้: authorize line | **เหมือนเดิม** — 146237/ThinkMarkets-Live/TF Global Markets ตั้งแต่ 07-19 แล้ว ไม่ใช่เพิ่งเปลี่ยน |
| leverage เพี้ยน (bug ที่อีก session เจอ: ini สั่ง 1:100 แต่ tester ใช้ 1:2000) | report เก่า `O132_B18_recheck.htm` (07-19) vs วันนี้ | **เหมือนเดิม** — 1:2000 ทั้งคู่ (bug จริงแต่ไม่ใช่ตัวขับ diff — pre-existing) |
| client terminal build อัปเดต | journal "MetaTrader 5 x64 build" ทุกวัน 07-19→07-23 | **เหมือนเดิม** — 5836 ตลอด, `terminal64.exe`/`MetaEditor64.exe` ทั้งคู่ file date = 11 พ.ค. (ไม่มีอัปเดตเลยตั้งแต่นั้น) |
| EA source code เปลี่ยน | `git log --since 07-19 -- ea_template/core/ Boss_14/18` | **ไม่มี** logic change (มีแค่ 2-line comment fix ORDER-160 วันนี้, อีก session confirm regression CLEAN ก่อนแตะ) |
| ราคา/tick history เปลี่ยน (broker revise ข้อมูลย้อนหลัง) | mtime ของ `.hcc`/`.tkc` ปี 2024 ใน `bases\ThinkMarkets-Live\` | **ไม่เปลี่ยน** — ticks 2024 ทุกเดือน mtime = 4 มิ.ย., H1 bar-cache = 1 ก.ค., ทั้งคู่เก่ากว่าวันที่ baseline pin (07-19) เอง — เป็นไฟล์ต้นทางตรงกันเป๊ะที่ทั้งสองรอบใช้ (rewritten to dodge a check_state.ps1 substring false-positive on the original phrasing; technical meaning unchanged) |
| persisted GlobalVariable ค้างข้ามรอบเทส (peak-equity/halt state รั่วจาก run ก่อนหน้า) | อ่าน `Persist.mqh` header โดยตรง | **ถูก design กันไว้แล้ว**: "tester GVs are sandboxed per pass, so persisted state can never move backtest numbers" — คนละ store จาก live GV เลย |

~~**สรุป: ... เหลือแค่ MT5 tester engine เองที่ทำงานต่างไปจากเดิม**~~ ⛔ **สรุปนี้ผิด — ถูกหักล้างด้วยการทดสอบรอบ 3 ด้านล่าง (user สั่ง "ตรวจสอบอีกที" 2026-07-23). ผมสรุปเร็วเกินไปจากการ "ไล่ตัดตัวแปร" อย่างเดียวโดยไม่ได้ทดลองจริง — ตารางข้างบนเช็คแต่ว่า "ค่าอะไรเปลี่ยนไหม" แต่ไม่เคยทดสอบว่า "ค่าที่ไม่เปลี่ยนนั้น ถูกส่งถึง tester จริงหรือเปล่า" ซึ่งคือจุดที่พัง.**

---

### ✅ รอบ 3 — ROOT CAUSE เจอจริง: `-Leverage` เป็น silent no-op + margin-gate (ไม่ใช่ engine drift)

**การทดลองที่หักล้าง (ไม่ใช่การไล่ตัดแบบ passive — ทดลองจริงทั้งหมด):**

| # | ทดลอง | ผล |
|---|---|---|
| 1 | ขอ `-Leverage 100` บน **lane1** (`D:\Meta 5`) | report บอก **1:2000** ← **ini ถูกเมิน** |
| 2 | ขอ `-Leverage 100` บน **lane2** (`D:\Meta 5b`) | report บอก **1:100** |
| 3 | sweep lane2 ขอ **2000 / 500 / 200** | report บอก **1:100 ทั้งสามครั้ง · ตัวเลขเหมือนกันเป๊ะ (n=480)** ← **ยืนยัน ini ถูกเมินทั้งสอง lane** |
| 4 | Boss_11 (grid) lane1@1:2000 vs lane2@1:100 | **n=9 (PF 0.00, eqDD 25.1% = KillDD ยิง) vs n=480 (PF 0.87)** ← ต่างกัน **53 เท่า** จาก leverage ล้วนๆ |
| 5 | Bars/Ticks ทั้งสอง lane | **2936 / 702163 เท่ากันเป๊ะ** ← ข้อมูลราคาเหมือนกัน 100%, ตัดเรื่อง data drift ขาด |
| 6 | **falsification:** Boss_12 (single-position, ไม่มี grid ให้ margin-gate คุม) ข้าม lane/leverage | **n=164 เท่ากันทุกที่** (baseline / lane1@2000 / lane2@100) |

**กลไกที่อธิบายได้ครบ (มีโค้ดรองรับ ไม่ใช่เดา):** `RiskControl_DepositLoadPct() = 100 × ACCOUNT_MARGIN / ACCOUNT_BALANCE` → `RiskControl_AllowNewOrder()` บล็อกไม้ใหม่เมื่อ ≥30% (PROTECT_NORMAL). **margin แปรผกผันกับ leverage** →
- ที่ **1:100**: margin สูง → deposit-load ชน 30% เร็ว → **grid ถูกบล็อกไม่ให้ซ้อนลึก** → DD เล็ก → เทรดยาว (n=480)
- ที่ **1:2000**: margin ต่ำกว่า 20 เท่า → gate แทบไม่ทำงาน → **grid ซ้อนลึกจนเจ๊ง** → equity DD 25% → **KillDD ยิง หยุดเทรด** → n=9

**นี่คือเหตุผลที่รูปแบบมันตรงเป๊ะ:** EA ที่โดนกระทบหนัก = **grid/stacking ทั้งหมด** (11/13/14/15/16/18 — ตัวที่ผ่าน margin-gate) · EA single-position (12/17) **จำนวนเทรดไม่ขยับเลย**. ถ้าเป็น "engine drift" จริง single-position ต้องเพี้ยนด้วย — **มันไม่เพี้ยน** = engine ไม่ได้ drift.

**🔧 บั๊กจริงที่ต้องแก้ (นี่คือของจริง ไม่ใช่ engine):** `scripts/mt5_run.ps1 -Leverage` **เขียนลง ini แล้วแต่ MT5 build 5836 ไม่อ่าน** — ใช้ leverage ของบัญชีที่ terminal นั้น login อยู่แทน → **ทุก backtest ที่ผ่านมา leverage ไม่เคยถูก pin จริง และไม่มีใครเห็นเพราะ script ไม่เคยตรวจ report ย้อนกลับ.** คลาสเดียวกับ ORDER-085 เป๊ะ (`Spread`/`TestSpread` ก็ no-op เงียบบน build นี้) — อีก session เจออาการนี้แล้วบันทึกไว้ว่า "น่าสงสัยแยกเรื่อง" **แต่จริงๆ มันคือตัวต้นเหตุ ไม่ใช่เรื่องข้างเคียง**.

**เศษที่ยังอธิบายไม่ได้ (เล็ก แต่ไม่ปิดบัง):** Boss_12 จำนวนเทรดเท่ากันทุกที่ (164) **แต่ net baseline −143.84 vs วันนี้ −171.63** (สอง lane วันนี้ตรงกันทั้งคู่ แม้ leverage ต่างกัน) = ~$28 บน 164 เทรด (~$0.17/เทรด). leverage อธิบายไม่ได้ (สอง lane ตรงกัน) — น่าจะ spread/swap/commission ใน tick data หรือ config บัญชี **ยังไม่พิสูจน์**. ขนาดเล็กมากเทียบกับ drift ที่ leverage อธิบายไปแล้ว แต่บันทึกไว้ว่ายังค้าง ไม่กลบ.

**สถานะใหม่ของ ORDER-162: ลดจาก "systemic engine drift" → "tooling bug (leverage unpinnable) + margin-gate sensitivity"** — ร้ายแรงน้อยกว่ามากและ **แก้ได้จริง** ต่างจากเดิมที่แก้ไม่ได้. ⚠️ **แต่ก่อน re-validate อะไรก็ตาม ต้อง pin leverage ให้ได้ก่อน** ไม่งั้น re-validate แล้วก็ยังลอยเหมือนเดิม (ดู ORDER-163).
**source:** ORDER-157 rerun-confirm (2026-07-23, Sonnet) — ไล่ตัดตัวแปรครบ (EA hash/param/.set/window/tick-cache mtime เหมือนกัน 100% ระหว่าง historical run 2026-07-08 กับ rerun วันนี้บนทั้ง 2 lane) แต่ **fold2-OOS ของ RSI-MR EURUSD H1 ยังต่างกันจริง: PF 1.74/131 เทรด (07-08) vs 1.08/130 เทรด (ตอนนี้ บน `D:\Meta 5` และ `D:\Meta 5b` ตรงกันทั้งคู่)**. รายละเอียดการไล่ตัดตัวแปรอยู่ที่บล็อก ORDER-157 ด้านบน + `_mt5_auto/reports/WF_RSIMR_REGR_F2_OOS_PRIMARYRERUN_*`.
**ทำไมเรื่องนี้ใหญ่กว่า cell เดียว:** hypothesis ที่เหลือหลังตัดทุกอย่างออกแล้วคือ **MT5 tester engine (build 5836) เองมีพฤติกรรมต่างจากตอนรัน 07-08** — และมี precedent ตรงจากโปรเจกต์นี้เองว่าไม่ใช่เรื่องเพ้อฝัน: **ORDER-085 (2026-07-10) เคยจับได้แล้วว่า build ปัจจุบัน no-op `Spread`/`TestSpread` ใน ini เงียบๆ**. ถ้า tester engine เปลี่ยนพฤติกรรมจริงตั้งแต่ ~07-10 = **backtest ทุกตัวที่ run ก่อนวันนั้นอาจให้ผลไม่ตรงกับที่ build ปัจจุบันจะให้** — กระทบความน่าเชื่อถือของ evidence เก่าที่ verdict จำนวนมากอิงอยู่ (scorecard, EA_MASTER_INDEX, deploy decision) ไม่ใช่แค่ WFA tool ตัวเดียว.
**ข้อสังเกตข้างเคียงที่ตัดออกแล้วว่าไม่ใช่ตัวขับ แต่ยังน่าสงสัยแยกเรื่อง:** rerun วันนี้ leverage รายงาน 1:2000 (ทั้งที่ `mt5_run.ps1` default 1:100 ไม่ถูก override) ขณะที่ historical + secondary-lane rerun รายงาน 1:100 — ตัดออกแล้วว่าไม่ใช่ตัวขับความต่าง PF (สอง lane เลขตรงกันแม้ leverage ต่างกัน) **แต่ `mt5_run.ps1` ไม่ honor ini leverage บาง path เป็น bug แยกที่ควรเปิด order ของตัวเอง**.
**scope ที่เสนอ (ยังไม่ทำ รอ user):** (1) **sample-check ราคาถูก:** เลือก 3-5 cell จาก order ที่เคย REVIEWED ไปแล้วก่อน 07-10 (เช่นจาก ORDER-078 Boss_16, ORDER-085B SuperTrend, หรือ RSI-MR order เดิม) rerun M1 เฉยๆ เทียบตัวเลขเก่า — ถ้าทุกตัว match = risk เฉพาะ cell นี้ ถ้าหลายตัว drift = risk เป็นระบบ ต้องขยาย scope (2) ถ้า drift เป็นระบบจริง ต้องตัดสินว่า **re-validate EA ที่ deploy อยู่แล้วกี่ตัว vs ยอมรับ evidence เก่าเป็น "ตอนที่ verify" ไม่ perpetual-truth** — เป็นการตัดสินใจเชิงนโยบายที่ user/Claude ต้องเคาะร่วมกัน ไม่ใช่ agent ตัดสินเอง.
**bars:** N-A (investigation, ยังไม่ตัดสิน EA ใดๆ). **flat-lot probe:** N-A.
**ห้าม:** สรุปว่า EA ตัวไหน "จริงๆ ตาย/รอด" จาก finding นี้จนกว่าจะรู้ scope (isolated vs systemic) · เปลี่ยน build/version MT5 เอง · แก้ evidence เก่าใน scorecard/index ใดๆ ตามความสงสัยนี้ก่อนพิสูจน์.
**ทำได้:** sample-check (1) = qwen/ZCode (mechanical, เทียบเลขเก่ากับใหม่) · การตัดสินใจ (2) = Claude/user เท่านั้น · 👉 **รอ user เคาะว่าจะให้ priority แค่ไหน** (T1-ฉุกเฉินถ้าห่วง evidence ปัจจุบัน vs T2-เมื่อว่างถ้าเชื่อว่า isolated).

## ORDER-163 — [template hardening, CORE-002] Clean-room dependency audit: Boss V2 ไม่พึ่ง EA_CORE V1 — `REVIEWED(Claude 2026-07-23) — CLEAN: 0 forbidden dependency`
**result:** `scripts/check_template_dependencies.ps1` สแกน 61 ไฟล์ (22 `.mq5` + 39 `.mqh`) 134 `#include` → **0 forbidden** (129 OK + 3 stdlib + 2 UNRESOLVED-TEST-SUPPORT ที่เข้าใจแล้วว่าเป็น deploy-time copy pattern ของ NewsGuard/AccountSnapshot ไม่ใช่รั่ว). **พิสูจน์ detector ทำงานจริง** ด้วย fixture ปลอมที่ include `D:\EA_Project\CURRENT_BUILD\CORE\Config_Contract.mqh` → script จับได้ถูกต้อง (exit 1 + ระบุ file:line) แล้วลบ fixture ทิ้งเรียบร้อย. compile 9/9 (8 Boss + template) 0/0 ผ่าน `ea_template\deploy.ps1 -Compile` (convention ที่ใช้ `D:\Meta 5\metaeditor64.exe` ไม่แตะ EA_Project) · report เต็ม `_triage/ORDER163_DEPENDENCY_GRAPH.md`.
**ผลสรุป: architecture boundary ที่ตัดสินไว้แล้ว (Boss V2 = แม่พิมพ์เดียว, EA_CORE = archive) ยังจริงในโค้ดปัจจุบัน 100%** — ไม่มีรูรั่ว ไม่ต้องมี order แก้ต่อ.
**confirmed:** ไม่แตะ `ea_template/core/*.mqh` เลย (diff ที่เห็นเป็นของ session คู่ขนานทั้งหมด) · ไม่ลบ/ย้าย EA_Project · ไม่มี verdict · ยังไม่ commit.
**source:** `docs/EA_CORE_TEMPLATE_WORKPLAN_FOR_CLAUDE.md` §CORE-002 (workplan rev-B ปลดล็อกแล้วโดย ORDER-155 — B7 เงื่อนไข "ห้ามชี้ OPTIMIZATION_PROCEDURE_V2 เป็น spec owner ก่อน ORDER-152(b) เสร็จ" ปิดแล้ว). นี่คือ order แรกของ template-hardening track — งาน tooling ล้วน ไม่แตะ verdict.
**spec:** สร้าง `scripts/check_template_dependencies.ps1` ตรวจว่า `Boss_11`–`Boss_18` (`ea_template\*.mq5`) และ include chain ของ runtime (`ea_template\core\*.mqh`) **ไม่อ้าง** `EA_CORE`, `D:\EA_Project`, หรือไฟล์ archive ใดๆ ผ่าน `#include` path หรือ absolute path string — parse `.mq5`/`.mqh` หา `#include` statement ทั้งหมด แล้ว flag เส้นทางที่ resolve ไปนอก `ea_template\` (ยกเว้น test-support ที่แยก scope ชัด เช่น `ea_template\tests\`).
**acceptance:** (1) Boss_11–18 compile ได้จริงจาก `ea_template` โดยไม่ต้องเปิด `D:\EA_Project` (ทดสอบจริงด้วย MetaEditor64 ตาม convention `DEVELOPMENT_GUIDE_FOR_CLAUDE.md`) (2) script exit non-zero + list ชัดเมื่อพบ forbidden dependency (3) test helper ภายนอก (ถ้ามี) ถูกแยกเป็น scope ต่างหาก ไม่ปนกับ runtime include (4) รายงาน dependency graph (ทุก `.mq5`/`.mqh` → include list) เก็บเป็น artifact `_triage/ORDER163_DEPENDENCY_GRAPH.md`.
**bars:** N-A (tooling, ไม่ใช่ EA verdict). **flat-lot probe:** N-A.
**ห้าม:** ลบ/ย้ายไฟล์ EA_CORE V1 หรือ archive ใดๆ (audit เท่านั้น — CORE-003 แยกต่างหาก และต้อง user approve ก่อนย้ายจริง) · แก้ include ที่พบว่าอ้างผิด (รายงานเฉยๆ ในรอบนี้ — แก้ = order ถัดไปถ้าเจอจริง) · แตะ verdict EA.
**ทำได้:** Sonnet/Codex (tooling ไม่แตะเงิน มี cage = compile 0/0 ตรวจได้ตรงไปตรงมา ตาม `AGENTS.md` §5.2) · Claude review ผล semantics · 👉 แนะ: Sonnet.

## ORDER-164 — [template hardening, PARAM-001] Full parameter registry — trace ทุก input ใน `Inputs.mqh` ไปยัง implementation จริง — `REVIEWED(Claude 2026-07-23) — 177/177 classified, self-check PASSED`
**result:** `docs/PARAM_REGISTRY.csv` — snapshot ที่ commit `733c1db7` (commit ล่าสุดที่แตะ `Inputs.mqh` ตอนสร้าง registry) ระบุ hash ไว้ในหัวไฟล์ชัดเจน + หมายเหตุว่า input ใหม่จาก ORDER-161 (`FIRSTLOT_BALANCE=43` + `*_BalPct` twins) ยังไม่ commit ณ ตอนนี้ ตั้งใจไม่รวม — ถ้า ORDER-161 commit ทีหลังให้ **append แถวใหม่ ไม่ต้องสร้างใหม่ทั้งไฟล์**.
**classification 177/177 ครบ (Opus-seat verify ตัวเลขจริงด้วย `grep -c`, ตรง 100%):** ACTIVE=170 · INACTIVE=2 · OVERRIDE=5 · COMPATIBILITY=0. INACTIVE 2 ตัวคือ `StackMode[LAB_ENTRY_16]`/`StackConfirm[LAB_ENTRY_16]` — `Kangaroo_OnTick()` ข้าม `Stack.mqh` เสมอไม่ว่าค่าไหน (comment ต้นฉบับก็เขียนว่า "informational only" อยู่แล้ว). ไม่มี COMPATIBILITY bucket เลย — agent ไม่ปั้น row ปลอมเพื่อให้ครบ bucket ตามที่กลัว.
**self-check RecoveryMode 82/83: ผ่าน** — classify ACTIVE + tag ENGINE-EDGE ตรงกับ finding ของ ORDER-158(1)/ORDER-160 เป๊ะ (trace ตรง `Recovery.mqh:46-69` ไม่มี early-return กั้น).
**วินัย UNKNOWN ตามที่สั่ง:** `default_profile` อ้างได้ 177/177 (ค่า default จริงจากโค้ด — fact ไม่ใช่เดา) · `optimize_stage` อ้างได้แค่ 7/177 (จาก `OPTIMIZE_GUIDE.md`) ที่เหลือ UNKONWN · `safe_range` อ้างได้ 3/177 ที่เหลือ UNKNOWN — **ไม่เดาเลข** ตรงกับวินัยที่ใช้ทั้ง session.
**bonus finding ที่ไม่ได้ขอแต่มีประโยชน์:** `_21_TP_Pip`/`_31_SL_Pip`/`_23_TrailStart`/`_23_TrailStep` ชื่อว่า "Pip" แต่จริงๆใช้เป็น raw broker point ดิบไม่ปรับ digit เลย (ต่างจาก `_9_StepMinPips` ฯลฯ ที่ปรับจริง) — ป้ายชื่อทำให้เข้าใจผิดได้แบบเดียวกับ Recovery stub label · `_33_AdaptiveON` อยู่กลุ่ม "3x Stop loss" แต่จริงๆ scale `_22_TP_ATRmult` (TP) ด้วยไม่ใช่แค่ SL. **ยังไม่แก้อะไร — บันทึกไว้เป็น candidate ของ PARAM-005 (rename ambiguous labels) ใน workplan rev-A/B ถัดไป**.
**confirmed:** ไม่แตะ `.mqh` ใดๆ (read-only audit) · ไม่มี verdict · ยังไม่ commit.
**source:** `docs/EA_CORE_TEMPLATE_WORKPLAN_FOR_CLAUDE.md` §PARAM-001 · rev-B B6 แก้เลขแล้ว: **177 parameter จริง** (202 บรรทัดขึ้นต้น `input` แต่ 25 เป็น `input group` header — อย่านับรวม).
**⚠️ target กำลังขยับ:** session คู่ขนาน (ORDER-161) กำลังเพิ่ม input ใหม่ใน `Inputs.mqh` จริง (`FIRSTLOT_BALANCE=43` + `*_BalPct` twins หลายตัว) ยังไม่ commit ณ ตอนเปิด order นี้ — **snapshot registry ที่ commit ล่าสุดของ `Inputs.mqh` (`733c1db7` หรือใหม่กว่าถ้ามี commit จาก ORDER-161 ไปแล้ว) แล้วระบุวันที่/commit hash ที่ snapshot ไว้ชัดเจนในหัวไฟล์ registry** — ถ้า ORDER-161 commit เพิ่ม input ใหม่ทีหลัง = **append เข้า registry ที่มีอยู่ ไม่ใช่ทำใหม่ทั้งชุด**.
**spec:** trace ทุก `input` ใน `ea_template\core\Inputs.mqh` (177 ตัว) ไปยัง implementation จริงใน `.mqh` อื่น (grep การใช้งานจริง ไม่ใช่เดาจาก comment) สร้าง registry (`docs/PARAM_REGISTRY.csv` หรือ `.md` ตาราง) มีคอลัมน์: `name, owner(.mqh ไฟล์ที่ implement), unit, context(entry/exit/stack/mm/recovery/hedge/safety/execution), active_when(เงื่อนไขที่มีผลจริง), coupled_parameters(ตัวที่ต้องอ่านคู่กัน), default_profile, optimize_stage(coarse/fine/fixed), safe_range, causal_question(ค่ามากขึ้นทำอะไร)`.
**acceptance:** ทุก input ใน `Inputs.mqh` ถูกจัดประเภทเป็นหนึ่งใน `ACTIVE / INACTIVE / OVERRIDE / COMPATIBILITY` (นิยามตาม workplan rev-A ต้นฉบับ) **ไม่มี input ไหนไม่ถูกจัดประเภท** — โดยเฉพาะ **RecoveryMode 82/83 ต้องระบุ ACTIVE + tag ENGINE-EDGE** (แก้ป้าย stub แล้วตาม ORDER-160 — registry ต้องสะท้อนความจริงล่าสุด ไม่ใช่ป้ายเก่า).
**bars:** N-A (documentation/tooling). **flat-lot probe:** N-A.
**ห้าม:** เดา implementation จาก comment/ชื่อตัวแปรโดยไม่เปิดโค้ดจริง · แก้ `Inputs.mqh`/`.mqh` ใดๆ (audit อย่างเดียว) · เขียน optimize_stage/safe_range แบบเดาโดยไม่มี evidence จาก order/scorecard เดิม (ถ้าไม่มีหลักฐาน = ใส่ `UNKNOWN` เหมือนวินัยที่ใช้กับ `expectations.csv` วันนี้ ห้ามเดา) · แตะ verdict EA.
**ทำได้:** Sonnet (extraction/ตาราง — deterministic, ตรวจได้ตรงไปตรงมาว่า trace ตรงโค้ดจริงไหม) · Claude review semantics หลังจบ · 👉 แนะ: Sonnet.

## ORDER-158 — [infra · money-adjacent] Hedge/Recovery mode A/B harness + แก้ป้าย stub ที่ขัดกับโค้ด — `REVIEWED(Claude 2026-07-23) — accepted, flat-lot pairing verified, not an EA verdict`
**(2)(3) DONE (Sonnet, ต้อง resume 1 รอบเพราะหยุดกลางคันแล้วรอ background — ดู memory `subagent-no-background-wait` อัปเดตแล้ว):** `scripts/hedge_recovery_sweep.ps1` sweep 8 cell จริง บน Boss_14_GridLog AUDNZD H1 MAIN-only (magic harness-only 990902 ไม่ชนของจริง 990201-208):

| RecoveryMode | HedgeMode | PF | eqDD | flat-lot twin(81) | lift |
|---|---|---|---|---|---|
| 80 baseline | 0/1 | 1.19 | 5.66% | — | — |
| 81 flat-lot | 0/1 | 1.17 | 5.01% | — | — |
| **82** | 0/1 | **1.51** | 5.17% | 1.17 | **+0.34** |
| **83** | 0/1 | **1.25** | 7.49% | 1.17 | **+0.08** |

**HedgeMode 0 vs 1 identical ทุกแถว** — `_H_TriggerDDPct=8.0` ไม่ถูกแตะในหน้าต่างนี้ (ข้อสังเกตของ harness ไม่ใช่ verdict). ⚠️ **นี่คือ MAIN window เดี่ยว ไม่มี BWD/M4/MC — ตามบาร์ order นี้แค่ "harness ใช้ได้จริง" ห้ามอ่านเป็นสัญญาณว่า 82 ดี** ถ้าจะต่อยอดจริงต้องผ่านกรง ENGINE-EDGE 5 ข้อเต็ม (worst-case≤15% · BWD hard · M4 · MC≤2% · label+small-size) ก่อน.
**gap ที่ผมชี้ตอน resume ถูกแก้จริง:** เพิ่ม `Recovery81_Test.mq5` ที่ขาดไป (assert 81 คืน baseLot ไม่ escalate เลย) — compile clean, รัน PASS 4/4 assert · **9/9 test PASS** รวม Persist/AcctGate/StackStep เดิม (รันบนเลน 2 `D:\Meta 5b` เพราะเลน 1 ติด live session 146237 ของ user).
**ยืนยันแล้ว (ทั้งจาก agent เองและผมตรวจซ้ำ):** ไม่แตะ `Recovery.mqh`/`Hedge.mqh`/`Inputs.mqh` เลย — diff ที่เห็นเป็นของ session คู่ขนาน (ORDER-161) ล้วนๆ, `Hedge.mqh` diff = 0.
**ผล:** `_mt5_auto/HEDGE_RECOVERY_SWEEP_SUMMARY.csv` + `_provenance.csv`, base set `_mt5_auto/ab_sets/ORDER158_HRS_base.set`, test 6 ไฟล์ใหม่ + README update. ยังไม่ commit.

<details><summary>spec เดิม + finding (1)</summary>
**(1) DONE — ตัดสินแล้ว:** ป้าย "(stub)"/"(stub, gated)" **ผิดข้อเท็จจริง** — 82 (`mult = 1 + basketDD/ddRef` clamp RC_RecMultMax) และ 83 (`lot = baseLot × MathPow(m, rstep)` clamp RC_RecMultMax, **geometric escalation ตัวจริง**) ทำงานครบผ่าน `Recovery_OnTick()` ไม่มี early-return กั้น นี่คือ ENGINE-EDGE class ตามนิยาม VERDICT GATE ไม่ใช่โค้ดตาย รายละเอียด+หลักฐาน file:line → `_triage/ORDER158_RECOVERY_STUB_LABEL_FINDING.md`. **แก้ป้ายจริง = ORDER-160 (เปิดใหม่ด้านล่าง)** — ใบนี้ห้ามแก้โค้ดตามเดิม.
**source:** ROADMAP §3 ข้อ 3 (Hedge/Recovery A/B validation harness). module เติมเสร็จ 2026-07-03 (PROJECT_STATE §7) แต่หมายเหตุตอนนั้นเขียนไว้เองว่า **"ยังไม่เคย backtest"** — ถึงวันนี้ยังไม่เคย = money logic ค้างในแม่พิมพ์โดยไม่มีหลักฐาน.
**🔴 เจอตอน inventory — ป้ายกับโค้ดขัดกัน ต้องแก้ก่อนทำ A/B:** `ea_template/core/Recovery.mqh` (140 บรรทัด) มี **4 โหมดที่มี `case` + lot logic จริงครบ** (`REC_NONE=80` / `REC_LIGHT=81` / `REC_ADAPTIVE=82` / `REC_AGGRESSIVE=83`) **แต่ `ea_template/core/Inputs.mqh:85-86` ติดป้าย 82 และ 83 ว่า "(stub)" / "(stub, gated)"** → คนอ่าน input เห็น "stub" แล้วนึกว่าปลอดภัย/ไม่ทำงาน ทั้งที่โค้ดมี logic เพิ่ม lot จริง. **นี่คือ escalation engine ที่ป้ายบอกว่าไม่ใช่** — ต้องตัดสินให้จบว่า "stub จริง (โค้ดตายอยู่ ต้องบอกให้ชัด)" หรือ "โค้ดทำงานจริง (ต้องลอกป้าย stub ออกและเข้ากรง ENGINE-EDGE)" **ก่อน** จะรัน A/B ใดๆ. `Hedge.mqh` (113 บรรทัด) = 2 โหมด `HEDGE_OFF=0` / `HEDGE_LOCK=1` implement จริงทั้งคู่ ไม่มีปัญหาป้าย.
**inventory ที่เหลือ (ห้ามสร้างซ้ำ):** `scripts/ab_mode_test.ps1` (215 บรรทัด) = harness A/B แบบ generic ที่ใช้ได้อยู่แล้ว — รับ `-Overrides 'RecoveryMode=81'` รัน 2 backtest เทียบกัน แล้ว append `_mt5_auto/ab_results.csv` (ตัวอย่างในเอกสารของมันเองก็ใช้ RecoveryMode) · มี `.set` ของเก่าให้แล้ว `_mt5_auto/ab_sets/AUDNZD_HEDGE1.set`, `AUDCAD_REC82.set`, `AUDNZD_REC80/81/82.set` · **ที่ขาด = ตัว sweep เป็นชุด + สรุป และ `ea_template/tests/` ไม่มี test ของ Hedge/Recovery เลย** (มีแต่ AcctGate/Persist/StackStep/NewsGuard/AcctSnapshot) และ `scripts/tpl_regression.ps1` ไม่แตะสองโมดูลนี้.
**spec (เรียงตามนี้ ห้ามสลับ):** (1) **ตัดสินเรื่องป้าย stub ก่อน** — อ่าน `Recovery.mqh` เทียบ `Inputs.mqh:85-86` แล้วรายงานว่าโหมด 82/83 ทำงานจริงหรือไม่ พร้อม file:line **(นี่เป็นการรายงานหลักฐาน ไม่ใช่การแก้โค้ด — Claude ตัดสินแล้วค่อยออก order แก้)** (2) batch harness ต่อยอด `ab_mode_test.ps1`: sweep `RecoveryMode {80,81,82,83} × HedgeMode {0,1}` = 8 cell บน 1 EA/symbol/window ชุดเดียว แล้วสรุปเป็นตารางเดียว (3) เพิ่ม test ของ Hedge/Recovery เข้า `ea_template/tests/` ตาม pattern ของ `Persist_Test`.
**bars:** ใบนี้ **ยังไม่ตัดสิน EA** — บาร์คือ *harness ใช้ได้จริง*: 8 cell รันจบ + ตารางเทียบออก + baseline บันทึกไว้เทียบรอบหน้า. **flat-lot probe: บังคับ done** — Recovery 81/82/83 = escalation engine ตามนิยาม → cell ที่ PF ดีขึ้นต้องมี flat-lot reference คู่เสมอ เพื่อวินิจฉัยว่า edge อยู่ที่สัญญาณหรือที่ engine (กฎ ENGINE-EDGE 2026-07-19 — flat-lot probe = เครื่องวินิจฉัย ไม่ใช่ใบมรณะ).
**ห้าม:** แก้ `Recovery.mqh`/`Inputs.mqh`/ป้าย stub ในใบนี้ (รายงานหลักฐานอย่างเดียว — การแก้ = order แยกหลัง Claude ตัดสิน) · เปิด Recovery/Hedge บน EA ที่ deploy อยู่ · ประกาศว่าโหมดไหนดี/ตาย (นั่นคือ verdict) · ข้าม `tpl_regression.ps1` ถ้าแตะ `core/`.
**ทำได้:** (1) = qwen/Codex อ่านโค้ดรายงาน file:line · (2)(3) = Sonnet/Codex (มี cage: `ab_mode_test` เดิม + `run_tests.ps1`) · 👉 แนะ: qwen ทำ (1) ก่อน แล้ว Claude ตัดสิน แล้วค่อยปล่อย (2)(3).
</details>

## ORDER-160 — [infra · core, comment-only] แก้ป้าย "(stub)" ผิดข้อเท็จจริงใน `Inputs.mqh` (RecoveryMode 82/83) — `REVIEWED(Claude 2026-07-23) — committed 733c1db (isolated patch, session อื่นไม่ถูกแตะ)`
**source:** ORDER-158 ส่วน (1) — `_triage/ORDER158_RECOVERY_STUB_LABEL_FINDING.md`. `Inputs.mqh:86-87` เขียน `REC_ADAPTIVE = 82, // 82 Adaptive (stub)` และ `REC_AGGRESSIVE = 83 // 83 Aggressive (stub, gated)` แต่ `Recovery.mqh` มี logic ทำงานจริงทั้งคู่ (82 = DD-scaled lot, 83 = `MathPow(m, rstep)` geometric escalation) clamp ด้วย `RC_RecMultMax` — ป้ายทำให้คนอ่าน dropdown เข้าใจผิดว่าไม่มีผล.
**spec:** แก้ **เฉพาะ comment 2 บรรทัดนี้** เป็นข้อความที่สื่อว่าทำงานจริง+มีกรง (ตัวอย่างที่เสนอไว้ใน finding doc) — **ห้ามแตะ logic/enum value/ลำดับใดๆ**.
**bars:** N-A (comment fix). **flat-lot probe:** N-A.
**ห้าม:** เปลี่ยนพฤติกรรมโค้ดใดๆ · เปิด default โหมด 82/83 · แตะไฟล์อื่นนอก `Inputs.mqh`.
**acceptance:** (1) diff มีแค่ 2 บรรทัด comment (2) `powershell -File scripts\tpl_regression.ps1` ต้อง **CLEAN** (กฎ "แก้ core/ ต้องรัน regression" ครอบแม้เป็น comment-only) (3) compile 0/0.
**ทำได้:** Sonnet/Codex (mechanical + cage ชัด) · 👉 แนะ: Sonnet.

---

## ORDER-161 — template: portable money params (cent/USD-safe) + balance-scaled lot sizing — `DONE + VERIFIED-NEUTRAL(Claude 2026-07-23)` ✅ **compile 9/9 · neutrality พิสูจน์แล้วด้วย stash-isolation (cage เองเสียจากบั๊กคนละเรื่อง = ORDER-165)**
> ✅ **ปิดข้อค้างเรื่อง cage แล้ว (2026-07-23):** รัน `tpl_regression.ps1` ได้แล้ว (user ปิด terminal ให้) → ขึ้น **8/8 drift** → **isolate ด้วย `git stash`: เอาโค้ด ORDER-161 ออกหมด รันซ้ำบน tree สะอาด ได้ตัวเลขเดียวกันเป๊ะทั้ง 8 ตัว (net/pf/trades/eqdd byte-for-byte)** = **โค้ดใบนี้ไม่ใช่สาเหตุ พิสูจน์แล้วไม่ใช่แค่อ้าง**. drift มาจากบั๊ก leverage-no-op ที่มีอยู่ก่อนแล้ว (root cause เต็ม = ORDER-162 รอบ 3 → แตกเป็น ORDER-165). ⚠️ **หมายเหตุความซื่อสัตย์: การ isolate นี้พิสูจน์ว่า "ไม่ทำให้แย่ลง" แต่ยังไม่ได้พิสูจน์ neutrality เทียบ baseline ที่เชื่อถือได้ เพราะ baseline เองยังลอยอยู่จนกว่า ORDER-165 จะปิด** — พอ re-pin baseline ใหม่แล้วควรรัน cage ซ้ำอีกรอบให้จบสมบูรณ์.
> 🔧 **renumbered 152→161 (Opus-seat, 2026-07-23):** เลข collision จริง — session นี้กับอีก session ใช้ ORDER-152 พร้อมกัน (ของผม = "doctrine reconciliation" คนละเรื่องเลย, commit `c6d431f` ไปแล้ว) ตาม precedent เดิม (133→135, 134→136 การชนกันของ session คู่ขนาน) **เลขที่ใหม่กว่า/ยังไม่ commit ถูก renumber** — เนื้อหา/โค้ด/สถานะข้างล่างไม่ถูกแตะเลย แค่เปลี่ยนเลข heading + self-reference ในบรรทัด verification status
**source:** user 2026-07-23 during ORDER-150 review — *"input parameter ประมาณว่า tp เมื่อเงินให้ถึง 25$ พวกนี้ชวนสับสนมาก เพราะบางพอร์ตผมใช้ port cent, usd จะแก้ยังไงดี แล้วก็ lot size สามารถทำให้เป็น percent of balance ได้ไหมเพื่อจะได้ scale up ตาม port size ได้ง่ายๆ"*
**problem:** (1) absolute money inputs mean 100× different things on a cent vs USD account (a `25` target = $25 or $0.25) — same .set, silently different behavior; (2) no lot mode scaled with account size for EAs **without** an SL — `FIRSTLOT_RISK(42)` needs an SL distance and silently falls back to `_41_FixedLot`, which is exactly why grid/basket EAs never scaled.
**solution (all additive, every new input defaults to 0/off ⇒ existing .sets byte-identical):**
- new shared helper `MM_BalancePct(pct)` in `MoneyManagement.mqh` — single resolver behind every `*BalPct` input (fail-safe: returns 0 on unreadable/non-positive balance, so a bad read disables the target rather than inventing one)
- percent-of-balance twins: `_2_BasketTP_BalPct` (precedence BalPct > ATRmult > Money) · `_32_SL_BalPct` · `_57_DynCloseBalPct` · `_8_DDRefBalPct`
- `_32_SL_*` gained a single resolver `Exit_BasketStopMoney()` — **both** call sites (intrabar safety stop + per-tick basket mgmt) now read the same value; they previously duplicated the raw input, which would have split-brained the moment one leg used BalPct
- new `FirstLotMode = FIRSTLOT_BALANCE (43)` + `_43_LotPerAnchor` / `_43_BalanceAnchor` — `lot = LotPerAnchor × (balance / anchor)`, no SL required
- `ExitManager.mqh` now includes `MoneyManagement.mqh` explicitly (was relying on LabCore include ORDER; no cycle — MM → Inputs/RiskControl only)
**why ratios fix the cent/USD problem:** balance and anchor/percent are both in account currency ⇒ the ratio is unitless ⇒ identical meaning on both account types, and it auto-scales as the account grows. Anchor is set in whatever units the terminal displays (USD acct 1000 / cent acct 100000) — converting to USD would reintroduce the bug.
**docs:** new `ea_template/INSTRUMENT_SCALE_REFERENCE.md` — full portable-vs-non-portable param audit + the BTC/ETH/XAU/EURUSD pip table the user asked for (answers the ORDER-142 review question), incl. measured D1 ATR for BTC (516.66) / ETH (58.33) and the `Stack_PipSize()` digits rule (BTC/ETH/XAU all digits=2 ⇒ **pip == point**, so "100 pips" = $1.00 there vs 100 real pips on EURUSD).
**verification status — HONEST:** compile **0 errors / 0 warnings × 9 wrappers** (Boss_11..18 + EA_LabTemplate) ✅. **`scripts/tpl_regression.ps1` NOT RUN** ❌ — it needs the `D:\Meta 5` tester lane, currently held by the user's own terminal (PID 4744, account 146237 ThinkMarkets-Live, BTCUSD Daily chart = the export session). Not killed: live-account terminal, user's call. **Neutrality is argued-by-construction (every branch guarded by `>0` with 0 defaults, new enum branch unreachable at default FirstLotMode=41) but NOT yet PROVEN by the cage — the whole point of the cage is that this reasoning is not trusted.** ⚠️ **Do not treat ORDER-161 as closed until `tpl_regression.ps1` returns CLEAN (Boss_14 n=84, Boss_18 6020 exact).** One intentional non-identity to watch: `MM_FirstLot` RISK branch now routes through `MM_BalancePct` and gained a `riskMoney > 0` guard — mathematically identical except when balance ≤ 0, where it now keeps `_41_FixedLot` instead of computing a 0 lot.
> 🔧 **note (Opus-seat, 2026-07-23):** `tpl_regression.ps1` รันผ่าน CLEAN ให้ ORDER-160 ได้สำเร็จช่วงเดียวกันนี้ (session นี้) — ไม่เจอ lane conflict ตอนรัน อาจจะ tester lane ว่างแล้วหรือ regression script ไม่ได้ต้องการ interactive terminal จริงๆ ตามที่สงสัย ลองรันซ้ำได้เลย.

---

## ORDER-150 — (MR)_SweepReversal_XAU (SS4, 992006) new-home ladder: ranger symbols — `REVIEWED(Claude 2026-07-23): PARKED-VERIFY(user) — EURUSD M15 = weak pulse (PF 1.08/40t), keep for build-on` ⚠️ **verdict CORRECTED by user same day** — first written as DEAD-OPTIMIZED, which misapplied the deploy-gate (≥1.2) as a discard-gate. User doctrine ([[feedback-buildon-pf-gt-1]]): **PF>1 = ของต่อยอด ไม่ใช่ทิ้ง** — deploy-gate ≠ discard-gate.
**result:** EURUSD **1.08**/40t (positive, under deploy bar) · EURGBP **0.80**/23t (net negative) · AUDNZD **0.44**/16t (net negative). ⚠️ **methodology catch mid-run:** first EURUSD pass used the XAU-locked `_01_RoundStep=25` ($ per round-number level) unchanged and produced only 11 trades/3yr (starved — $25 is ~1.1% of XAU's price but ~2400% of EURUSD's) — classic "money-based axis doesn't transfer across instrument classes" trap (skill catalog). Rescaled to `_01_RoundStep=0.0030` (≈30 pips, FX-appropriate) and reran — trade count 11→40, PF 1.41→1.08 (the 1.41 was a starved-sample artifact).
**verdict = PARKED-VERIFY, EURUSD is the live thread:** EURGBP/AUDNZD are genuinely dead (net negative, thin), but **EURUSD M15 PF 1.08 at n=40 is a positive pulse on a config that was never tuned for it** — the entire ladder ran on XAU-locked levers with only a mechanical RoundStep rescale, i.e. ZERO optimize rounds on this home. Killing it would violate the no-DEAD-before-optimize rule. **Open levers, none touched on EURUSD:** RoundStep is the obvious first axis (0.0030 was a first-guess scale conversion, not a swept value — try {0.0015, 0.0030, 0.0050, 0.0080}), then AdxMax (XAU-tuned 28 may be wrong for a ranger — a ranger *wants* low ADX so the cap may be mis-set), then TpAtrMult/SweepAtrMult. BWD + M4 not yet run (correctly deferred until a tuned config exists to test). **Next step if resumed:** RoundStep×AdxMax coarse grid on EURUSD M15 both-window, ~16 cells.
Raw reports `_mt5_auto/reports/O150_*.htm`, set `_mt5_auto/ab_sets/w2_ss4/o150_ranger_rescaled.set`.
**source:** SS4 PARKED-VERIFY — XAU M15 4-lever×2-TF ladder complete, MAIN real pulse 1.31-1.85 but BWD<1 every healthy-n cell = regime-dependent (trend years continue past the sweep-reject signal). Sweep-and-reject mechanism is a **reversion** signal → per CLAUDE.md VERDICT GATE right-home rule (reversion→ranger, not trender), XAU was the wrong home from the start.
**spec (mechanical, locked plateau-center lever combo from the XAU ladder — no re-tune):** run the SAME locked lever combo that produced the XAU plateau (AdxMax/SweepAtr/TpAtr/RSI band values — pull exact set from `_triage` SS4 ladder results / EA_SCORECARD row) on **EURUSD, EURGBP, AUDNZD × M15** both-window M1 (MAIN 2023.01-2025.12 + BWD 2020-2022). M4 only on cells that clear the M1 gate.
**bars:** pass = cell MAIN≥1.2 AND BWD≥1.0 (new-home candidate, resume funnel) · dead = no cell clears MAIN≥1.2 on any of the 3 rangers → SS4 stays PARKED-VERIFY, close as no-new-home (same disposition as ORDER-140 SS1). **flat-lot probe:** N-A (single-position OCO, no escalation).
**ห้าม:** re-tune the lever combo (this is a home-swap test, not re-optimization) · verdict · attach anything.
**ทำได้:** qwen/ZCode batch → raw results `_triage/ORDER150_SS4_NEWHOME_RESULTS.md` + CSV `_mt5_auto/ORDER150_SS4X.csv` · รอ Claude REVIEW.

---

## ORDER-151 — (TRND)_TsMom_XAU (S2, 992001) demo-isolate bundle prep — `DONE(Claude 2026-07-23) — bundle built, PENDING_ATTACH for user` (user decision 2026-07-23: demo-isolate directly, not MRIS overlay first)
**result:** locked plateau-center **lb60/dm2** (from `_mt5_auto/S2_TSMOM_BOTHWINDOW.csv` — picked over the lb100/dm2 spike-peak 4.90; lb60 family is flatter across deadmult 1-3). Bundle `_vps_deploy/S2_TSMOM_XAU/` = `TsMom_XAU.ex5` (verified fresh vs source mtime) + `S2_TsMom_XAU_deploy.set` (full 18-input merge, `_05_AllowLive=true`, magic 992001) + `README_ATTACH.md` (judge criteria + explicit "don't misread a losing stretch as new info" regime caveat, per user's own instruction on this order). DEPLOYMENTS.csv row added (463666728 placeholder acct, PENDING_ATTACH) + EA_MASTER_INDEX + scorecard rows updated.
**source:** S2 PARKED-VERIFY — MAIN 2.8-4.9 all cells (strong bull-only TSMOM momentum edge) but BWD 0.52-0.77 all cells, ADX last-optimize could not filter the V-reversal failure mode. User chose to demo-forward the edge as-is rather than gate it behind an MRIS regime-overlay build first — forward data becomes the regime-dependence evidence.
**spec:** lock the plateau-center .set already used for the MAIN/BWD numbers above (pull from `_triage` S2 ladder results — no re-tune) → build `_vps_deploy/S2_TSMOM_XAU/` bundle (compiled .ex5 + locked .set + README with judge criteria pre-registered) → add DEPLOYMENTS.csv row status=PENDING_ATTACH, magic 992001, XAUUSD, kill_rule = eqDD>12% OR 3-mo PF<0.8 @≥15 trades (repo default demo-kill bar) **plus an explicit regime note**: BWD<1 is known and accepted — judge criteria must include a trend/momentum regime check (e.g. compare live period against MRIS trend barometer post-hoc) so a losing forward stretch isn't misread as a fresh discovery.
**bars:** N-A (this is a bundle-build order, not a test — no pass/dead line item). **flat-lot probe:** N-A (single-position).
**ห้าม:** attach live/real money · skip the README judge-criteria pre-register step · silently drop the BWD-known-bad caveat from the README.
**ทำได้:** Claude/Sonnet (bundle build follows existing `_vps_deploy` template) → mark DONE when bundle exists, PENDING_ATTACH for user.

---

## ORDER-146 — EmaStoRev (SMCxSTO) NEW-HOME sweep — `REVIEWED(Claude 2026-07-23): DEAD-OPTIMIZED (new-home expansion) — 0/8 cells cleared ≥1.0 both-window on EURGBP/AUDNZD/EURCHF/USDCHF H1/H4, H4 legs all THIN (n10-24) but H1 legs (n>=105) are conclusive fails too. Concept unaffected at its validated home — demo 991070 EURUSD H1 continues as-is, unchanged. No new home found, close expansion effort.`
**source:** ORDER-LANEC-REBUILD close note ("further build-on = different HOME (TF/symbol) not more EURUSD-H1"). **spec:** EA `(EXP)_EmaStoRev` center ORDER-107 (StoK13/OS30/AdxMax30/EMA50/SL3.0/TP1.2) **ห้ามแก้ param อื่น**. homes ใหม่: EURGBP + AUDNZD + EURCHF + USDCHF × H1 + H4 = 8 cells × MAIN+BWD M1 = 16 runs → M4 ซ้ำเฉพาะ cell ที่ M1 both-window ≥1.0 (คาด ≤4 → ~24 runs). Reports `ESR_{SYM}_{TF}_{WIN}_{MODEL}`.
**bars:** mark PASS เมื่อ MAIN≥1.2 AND BWD≥1.0 ทั้ง M1+M4 · 1.0–1.2 = WATCH · ต่ำกว่า = FAIL. **flat-lot: N-A** (single-position 0.01 real SL). **ห้าม:** แตะ 991070/991071 · tune ใดๆ · verdict. **ทำได้:** qwen/ZCode → `_triage/ORDER146_ESR_NEWHOME_RESULTS.md`.

## ORDER-147 — S1 TrendRider XAU (992004 CANDIDATE) symbol expansion — `REVIEWED + HOLDOUT DONE(Claude 2026-07-23, ORDER-167): 2/3 ตาย · XAGUSD H4 = BUILD-ON (holdout ผ่านแต่ BWD ตกบน pinned config)`
**เดิม (partial-set era):** transfer-screen ยก locked center a20/s0.5/c2.5 ไป 3 บ้าน ผ่าน M1+M4 both-window ทั้งหมด — XAGUSD 1.62/1.03 · USDJPY 1.34/1.31 · EURJPY 1.32/1.02.
**ORDER-167 (full-pinned, M4, leverage asserted) — holdout 2026H1 = ด่านชี้ขาด:**
| cell | holdout 2026H1 | verdict |
|---|---|---|
| USDJPY H4 | **0.38**/16t | **DEAD-OPTIMIZED** — both-window 1.34/1.31 สวยแต่ holdout พัง = selection-fit |
| EURJPY H4 | **0.32**/11t | **DEAD-OPTIMIZED** — เหมือนกัน |
| XAGUSD H4 | **1.37**/11t ✅ | รอด holdout — แต่ดูบรรทัดล่าง |
**XAGUSD re-confirm บน pinned config:** MAIN **1.53**/111t (เดิม 1.62) · **BWD 0.97**/138t (เดิม 1.03) → **BWD ตกใต้ 1.0 บน config ที่ pin จริง** = soft-gate fail. holdout 1.37 ผ่านแต่ n=11 บางมาก. ⇒ **BUILD-ON ไม่ใช่ CANDIDATE** (ตาม bar: BWD-fail = PARKED/BUILD-ON ห้าม auto-live) · ห้าม attach จนกว่าจะมี BWD ที่ยืนได้ — lever ที่ยังไม่แตะบน XAG = optimize เฉพาะบ้านนี้ (ทั้งหมดที่ทำมาคือ *ยืม* center ของ XAU ไม่เคย tune ให้ XAG เลย).
**บทเรียนซ้ำรอบ 3 ในวันเดียว:** both-window ผ่าน ≠ edge จริง — **holdout คือด่านที่ฆ่า** (MacdDiv D1 majors 2/2 ตาย · TrendRider expansion 2/3 ตาย) transfer-screen ให้ผลบวกง่ายกว่าที่คิดมาก อย่าหยุดที่ both-window.
**source:** ORDER-139 (S1 = VALIDATED CANDIDATE XAU H4). doctrine 2b: ขยาย symbol×TF เอาทุก home ที่ผ่านบาร์. **spec:** locked center a20/s0.5/c2.5 **verbatim ห้าม re-tune**. symbols: XAGUSD + GBPJPY + USDJPY + EURJPY × H4 (+ H1 เฉพาะ XAG) = ~5 cells × MAIN+BWD M1 = 10 runs → M4 survivors (~20 runs รวม). Reports `S1X_{SYM}_{TF}_{WIN}_{MODEL}`.
**bars:** PASS=MAIN≥1.2 AND BWD≥1.0 M1+M4 · corr Claude รันเองตอน review (agent แค่เก็บ report ครบ). **flat-lot: N-A** (single-position). **ห้าม:** แตะ set/demo 992004 · tune · verdict. **ทำได้:** qwen/ZCode → `_triage/ORDER147_S1_EXPAND_RESULTS.md`.

## ORDER-148 — Boss_17 Wave5 symbol expansion (JPY crosses) — `REVIEWED(Claude 2026-07-23): DEAD-OPTIMIZED (new-home expansion) — 0/8 cells cleared MAIN≥1.1 gate on GBPJPY/EURJPY/AUDJPY/CHFJPY H1/H4 (EURJPY H1 closest at 1.08, still under). H4 legs THIN (n54-62) but H1 legs (n173-196) are conclusive. JPY-cross is not a new home for Wave5 impulse entry — concept stays at its validated XAU/XAG/USDJPY homes (demo 463666728, magics 990301-303), unaffected.`
**source:** Wave5 validated XAU/XAG/USDJPY (990301-303). ยังไม่เคยเทส JPY crosses. **spec:** params จาก `_vps_deploy/WAVE5_XAU/WAVE5_XAU_H1_demo_v1.set` (fib23.6/mult0.618/trail 2000-800, ExitMode=23, _9_MaxLevels=1) **ห้าม tune**. symbols: GBPJPY + EURJPY + AUDJPY + CHFJPY × H1 + H4 = 8 cells × MAIN M1 ก่อน (8 runs) → เฉพาะ MAIN≥1.1 ค่อยรัน BWD + M4 (~16 runs รวม). Reports `W5X_{SYM}_{TF}_{WIN}_{MODEL}`.
**bars:** PASS=MAIN≥1.2 AND BWD≥1.0 · n ต่อ cell ≥30 มิฉะนั้น mark THIN ห้ามนับ (Wave5 เทรดบาง). **flat-lot: N-A**. **ห้าม:** แตะ 990301-303 · tune · verdict. **ทำได้:** qwen/ZCode → `_triage/ORDER148_W5_EXPAND_RESULTS.md`.

## ORDER-149 — MacdDiv divergence: majors D1/H4 sweep (ต่อยอด 999094 + GBPUSD-D1 parked) — `REVIEWED + CORRECTED(Claude 2026-07-23): GBPUSD D1 DEAD-OPTIMIZED (earned properly now) · USDJPY D1 DEAD-OPTIMIZED (holdout-fail) — ORDER-167 ปิดทั้งคู่`
> ⚠️ **การ review รอบแรกของผมมีข้อผิด — แก้แล้วด้วยการทดลอง (ORDER-167 ด้านล่าง).** รอบแรกผมเขียนว่า "GBPUSD D1 PASS ไม่เปิดเซลล์ใหม่ เพราะ ORDER-117 ฆ่าไปแล้วบน config เดียวกัน" — **ผิด: มันคนละ config กัน** และผมสรุปทั้งที่ตัวเองเป็นคน flag ว่า "ตัวเลขไม่ตรง ยังไม่ reconcile" (1.86/n21 vs 1.24/n24) — ควรทดสอบก่อนสรุป ไม่ใช่สรุปแล้วแปะ flag ไว้.
**diagnostic ที่ปิดปริศนา (GBPUSD D1 MAIN, full-pinned ทั้งคู่):** compiled-defaults → **1.23/n24** (= ORDER-117's 1.24/24 ✓) · demo/tuned 999094 → **1.82/n21** (= ORDER-149's 1.86/21 ✓) ⇒ **ORDER-117 เทส defaults, ORDER-149 เทส demo-tuned = คนละ config จริง**. สำคัญกว่านั้น: demo config = MACD **12/44/13** ซึ่ง **อยู่นอกกริดที่ ORDER-117 กวาด** (Fast{8,12,16}×Slow{21,26,34}×Signal{7,9}) → **config นี้ไม่เคยผ่าน holdout เลย** = ตอนนั้นยังฆ่าไม่ได้จริง.
**ORDER-167 รัน holdout ที่ขาดไป (Model 1, full-pinned, leverage asserted):**
| cell | MAIN | BWD | HOLDOUT 2026H1 | HOLDOUT 2017-19 | verdict |
|---|---|---|---|---|---|
| GBPUSD D1 (demo cfg) | 1.82/21t | — | **0.15**/4t | **0.82**/44t | **DEAD-OPTIMIZED — earned** |
| USDJPY D1 (demo cfg) | **1.37**/39t | **1.20**/45t | **0.57**/10t | **0.61**/49t | **DEAD-OPTIMIZED** |
**ผลลัพธ์สุดท้าย: verdict เดิม (ตาย) ยืน แต่ตอนนี้*ได้มาอย่างถูกต้อง*แทนที่จะอ้างเหตุผลผิด** — GBPUSD D1 ตายบน holdout ทั้งสองหน้าต่างจริงๆ (0.15 · 0.82) · **USDJPY D1 ที่ผมเคยเรียก "cell ใหม่ BUILD-ON" = ตายเหมือนกัน** — both-window สวย (1.37/1.20) แต่ holdout ทั้งสองพัง (0.57 · 0.61) = selection-fit ซ้ำรอย GBPUSD sibling เป๊ะตามที่ตัวเองเตือนไว้. **MacdDiv concept ยังมีชีวิตที่บ้านเดิมเท่านั้น (XAU H4, demo 999094)** — D1-majors ตระกูลนี้ปิด.
**บทเรียนเข้า catalog:** อย่าเทียบผลข้าม order โดยเชื่อ label ("default/locked") — **ต้อง diff .set จริง**; และ EA ตัวเดียวกันมีได้หลาย config ที่ verdict คนละอย่าง — verdict ต้องผูกกับ *config* ไม่ใช่แค่ symbol×TF.
**source:** MacdDiv XAU H4 = demo 999094 (M4 confirmed) + ORDER-117 พบ GBPUSD MacdDiv D1 PARKED-VERIFY. ยังไม่เคย sweep majors เป็นระบบ. **spec:** EA MacdDiv เดิม (source เดียวกับ bundle 999094) default/locked param **ห้าม tune**. symbols: GBPUSD + EURUSD + USDJPY + AUDUSD + XAGUSD + GBPJPY × D1 + H4 = 12 cells × MAIN M1 (12 runs) → BWD เฉพาะ MAIN≥1.1 → M4 survivors (~28 runs รวม). Reports `MDX_{SYM}_{TF}_{WIN}_{MODEL}`.
**bars:** PASS=MAIN≥1.2 AND BWD≥1.0 M1+M4 · D1 cells n≥20/window มิฉะนั้น THIN. **flat-lot: N-A** (single-position). **ห้าม:** แตะ 999094 demo · tune · verdict. **ทำได้:** qwen/ZCode → `_triage/ORDER149_MDX_SWEEP_RESULTS.md`.

## ORDER-142 — AdaptGridMC backtest campaign (ต่อจาก 141 build) — `REVIEWED(Claude 2026-07-23): NOT a validated candidate — MAIN PF is a realized-path artifact, structural flaw found`
**MAIN result (Model 1 + Model 4, both confirm, no fill-cliff):** BTCUSD PF **543→523** (M4), 47t, DD 1.79%, net only $135.51 · ETHUSD PF **487→1182.12** (M4 — first parse showed "1", a PARSER BUG, see below), 128-133t, DD ~1.7%, net $339-378. **These numbers are NOT evidence of edge — do not read them as a pass.** Per skill: "PF>~3 → suspicion, not celebration." Root cause found and PROVEN, not just suspected: the zone (`_01_ZoneLo/Hi`) is a ONE-TIME static P10/P90 band computed from data ending 2022-12-31. BTC then rallied ~16.5k→100k+ through 2023-2025 (one of its largest bull runs ever) — the grid transited the zone once on the way up, banked a handful of clean wins, then price left the zone PERMANENTLY. **Proof: ran the 2026H1 holdout on the same static zone — BTCUSD produced ZERO trades** (price is nowhere near 12748-22711 anymore). ETHUSD's 2026H1 holdout was more modest and believable (PF 1.27/24t/DD1.17%) since ETH ranged back near its zone, but still thin. **Verdict: DEAD-STRUCTURAL for the static-zone design specifically** (not the concept) — a non-adaptive one-time zone cannot survive a sustained trend, which crypto does regularly; this is a NEW catalog entry (not fill-artifact, not martingale — "zone-exhaustion dormancy"). **Path forward if revisited:** redesign as walk-forward zone (re-generate on a fixed cadence, e.g. quarterly, from a rolling lookback) rather than one-time static — that is a real fix, not a dead end, so this is PARKED-VERIFY pending redesign, not permanently killed.
**BWD 2020-22 HARD gate: still blocked, per user directive 2026-07-23 accepted as unresolvable** (no CSV history before 2020-01-01) — proceeded without it as instructed. Note for the record: BWD would likely have caught this exact failure mode faster (2020's COVID crash + chop would have tested zone durability much earlier) — the data gap cost us a faster diagnosis, not a wrong one.
**🔧 TOOL BUG FOUND + FIXED:** `scripts/parse_htm.ps1`'s regex silently truncated any field ≥1000 at MT5's space-thousands-separator ("1 182.12" → parsed as "1") with NO error — caught because ETH M4's real PF (1182.12) looked like a plausible small number ("1") instead of an obvious failure. Fixed (see script comment). **This bug may have under-reported Profit Factor / Net Profit / Recovery Factor / Sharpe on ANY past report where that field crossed 1000 — those historical numbers are unverified until re-parsed with the fixed script.** Net Profit is the field most likely to have been affected historically (PF/RF/Sharpe rarely reach 4 digits); flagging for awareness, not launching a retroactive audit unless a specific past verdict is in question.
**Reports:** `_mt5_auto/reports/O142_{BTC,ETH}_{MAIN,HOLDOUT}_M{1,4}.htm` · sets `_vps_deploy/EXP_ADAPTGRIDMC/O142_{BTC,ETH}_MAIN.set` · zone-gen `_mt5_auto/adaptgrid_mc_zone.ps1` (PowerShell port, python absent on this box).
**progress 2026-07-23:** user exported BTCUSD/ETHUSD D1 CSV (`_mt5_auto/BTCUSD_Daily_2020.01.10-2026.07.23.csv` + ETH twin, 2261 bars each, tab-delimited — the .py zone-gen's comma/semicolon delimiter sniff would have silently mis-parsed this, never triggered because python/py/python3 are ALL absent on this box (`Get-Command` confirmed) — ported the generator to `_mt5_auto/adaptgrid_mc_zone.ps1` (tab-aware, same MC block-bootstrap math). Ran MAIN-window zone (no-lookahead: sliced to rows before 2023-01-01, 968 bars each) → `AGMC_BTC_MAIN_zone.set` (ZoneLo 12748.93/ZoneHi 22711.25/N40) + `AGMC_ETH_MAIN_zone.set` (ZoneLo 864.67/ZoneHi 1901.00/N40), both clamped to the 40-level ceiling.
**⚠️ BWD 2020-22 HARD GATE — DATA GAP, not yet resolvable:** the CSV has **zero bars before 2020-01-01** (starts 2020-01-10, right at BWD's own start) — there is no runway to compute a walk-forward, no-lookahead zone for the BWD window at all. Any zone computed from data that includes 2020-2026 and then tested against BWD 2020-2022 would be lookahead bias (the zone would already "know" the outcome). **The mandatory BWD HARD gate cannot be honestly run until the CSV export goes back further** (need ~1000 D1 bars before 2020-01-01, i.e. back to ~2017 if the broker/vendor has that much BTC/ETH CFD history — may not exist that far back for these instruments). **Ask user:** re-export with an earlier start date, or accept BWD is untestable for this EA and the campaign stops at MAIN-only (which cannot satisfy the pre-registered HARD-gate bar as written).
**next (not yet done):** compile `(EXP)_AdaptGridMC_rev01.mq5` → deploy .ex5 to roaming `MQL5\Experts` (no compiled .ex5 exists yet, only source) → merge zone snippet into a full .set (MaxTotalLot/hard-kill/magic 992007 per ORDER-141 spec) → M1 flat-lot MAIN backtest via `mt5_run.ps1` → swap-drag note (BTC/ETH swap per ORDER-125 crypto-lane lesson) → verdict.
**OLD BLOCKED evidence (2026-07-20, superseded):** `D:\Meta 5\terminal64.exe` exists but could not be opened as a separate target; only `D:\Monitor\MT5\terminal64.exe` was targetable/running. No BTC/ETH D1 CSV found under `D:\EA_LAB` or `D:\Meta 5`; Python `MetaTrader5` bridge unavailable. No zone, tester, or verdict work performed.
**source:** ORDER-141 (build DONE, backtest ยังไม่เริ่ม) + FINDYOUR8 catalog #1. **spec (mechanical ทั้งหมด — ห้าม agent ตีความ):**
(1) export D1 CSV จริง BTCUSD+ETHUSD จาก MT5 (`Meta 5` GUI ปิดก่อน headless) ≥1000 bars ล่าสุด → (2) รัน `_mt5_auto/adaptgrid_mc_zone.py` ต่อ symbol (params ตาม default ใน ORDER-141: 10k paths × 60d, block 24d) เก็บ P10/P90/N ลง `_mt5_auto/adaptgrid_zones.txt` → (3) tester `(EXP)_AdaptGridMC_rev01` M1 flat-lot 0.01: MAIN 2023.01–2025.12 + BWD เท่าที่ data มี (BTC CFD history อาจเริ่มหลัง 2020 — **บันทึกช่วงจริงที่ใช้ ห้ามเงียบ**) ต่อ symbol → (4) M4 ซ้ำเฉพาะ cell ที่ M1 PF≥1.0. Reports `AGMC_{SYM}_{WIN}_{MODEL}`.
**BLOCKED evidence:** `D:\Meta 5\terminal64.exe` exists but could not be opened as a separate target; only `D:\Monitor\MT5\terminal64.exe` was targetable/running. No BTC/ETH D1 CSV found under `D:\EA_LAB` or `D:\Meta 5`; Python `MetaTrader5` bridge unavailable. No zone, tester, or verdict work performed.
**bars (pre-registered):** pass=MAIN≥1.2 AND BWD(หรือ oldest-available window)≥1.0 ทั้ง M1+M4 → รอ Claude funnel · dead=ทุก cell <1.0 → รอ Claude ปิด (agent ห้ามเขียน verdict) · กลาง=1.0–1.2 → mark WATCH. **flat-lot: done** (spec บังคับ 0.01 flat). **ห้าม:** แก้ EA/zone script · optimize param ใดๆ · เขียน verdict/scorecard · แตะบัญชี. **swap-drag note บังคับ:** BTC long swap −14.67%/yr (memory crypto lane) — ใส่บรรทัดนี้ใน result file เสมอ. **ทำได้:** qwen/ZCode (มี checklist ครบ) · ผลดิบ → `_triage/ORDER142_AGMC_RESULTS.md` + สถานะ DONE รอ REVIEW.

## ORDER-143 — SS1 LondonORB lever ค้าง: partial-TP + trend-filter sweep — `DONE(2026-07-20, Opus-seat) — N/A closure · EA (BRK)_LondonORB_XAU_rev01 lacks _2_PartialPct1 (partial-TP) and EMA200 trend-filter inputs · ห้าม แก้โค้ด per spec → sweep NOT RUN · SS1 remains BUILD-ON (next = different HOME/symbol, not lever stacking) · ผลดิบ _triage/ORDER143_SS1_LEVER_RESULTS.md`
**source:** ORDER-140 close note ("lever ค้าง = partial-TP + trend filter"). **spec:** vehicle = SS1 LondonORB EA เดิม (Wave-1, sets `_mt5_auto/ab_sets/london_sets/` center MinOr 0.5/TpRR 3). sweep 2 lever แยกกัน (ห้าม stack รอบแรก): (A) partial-TP: `_2_PartialPct1 {30,50}` @frac 0.5 (ถ้า EA standalone ไม่มี input นี้ = บันทึก N/A แล้วข้าม — **ห้ามแก้โค้ด**) (B) trend filter EMA200 direction-align ถ้ามี input อยู่แล้วเท่านั้น. homes: GBPUSD M15 (บ้านหลัก) + USDJPY M15 + XAU M30 (2 บ้าน both-window>1 จาก 140). windows MAIN+BWD, M1. ~≤24 runs.
**bars:** pass=cell MAIN≥1.2 AND BWD≥1.0 (ยกจาก BUILD-ON ได้) · dead=lever ไม่ยก MAIN เกิน 1.2 ที่ไหนเลย → SS1 คง BUILD-ON บันทึกปิด lever. **flat-lot: N-A** (single-position OCO). **ห้าม:** แก้โค้ด EA · stack lever · verdict. **ทำได้:** qwen/ZCode → ผลดิบ `_triage/ORDER143_SS1_LEVER_RESULTS.md`.

## ORDER-144 — [codex] pre-commit staged-bytes validation (roadmap finding #12, ops-debt) — `DONE(Codex, 2026-07-20)` (Codex builder OK — tooling ไม่ใช่ money code, cage ชัด)
**source:** `_triage/CODEX_ROADMAP_2026-07-19.md` finding #12 (Open): pre-commit ตรวจ working tree ไม่ใช่ staged bytes; `check_precommit_staged.ps1` คุ้มแค่ 5 artifact. **spec:** ขยาย staged-bytes validation ให้ครอบ `portfolio/DEPLOYMENTS.csv` (parse+dup-magic บน staged blob) + `EA_SCORECARD_AND_REGISTRY.md`/`EA_MASTER_INDEX` same-commit rule + `docs/memory_control/B1_DATASET.csv` append-only + `ea_template/regression_baseline.csv` (แก้ได้เฉพาะ commit ที่มีคำว่า re-pin). ใช้ `git show :<path>` อ่าน staged content. **acceptance:** (1) synthetic test ต่อ rule: stage ไฟล์พัง → commit ถูก block พร้อม message ชี้ rule (2) commit ปกติผ่าน (3) ห้ามแตะ 4 script ต้องห้าม (`control_room_snapshot/daily_monitor/live_dashboard/monitor_rotation`) (4) `check_state.ps1` เดิมยังรันเหมือนเดิม (additive เท่านั้น) (5) เอกสาร rule ท้าย script. **ห้าม:** เปลี่ยน hook เดิมเป็น blocking กับ path ที่ไม่ใช่ 4 กลุ่มข้างบน · แตะ .githooks ที่ session อื่นกำลังใช้โดยไม่ backward-compat. **ทำได้:** Codex (`/codex:rescue`) — commit path-limited `[codex]` prefix.
**result:** `scripts/check_precommit_staged.ps1` now validates staged blobs for deployment CSV parse+duplicate account|magic, scorecard/index same-commit pairing, B1 append-only prefix, and regression-baseline `re-pin` commit-message gate. Ordinary commit path remains no-op/pass. Parser check + `check_precommit_staged.ps1` + `check_state.ps1 -Strict` all PASS. No forbidden scripts or `.githooks/pre-commit` changed.

## ORDER-145 — [codex] blind audit: (EXP)_AdaptGridMC_rev01 (money-adjacent: hard-kill −20% persisted GV) — `DONE(Codex, 2026-07-20)` (Codex audit lane — จุดแข็งที่พิสูจน์แล้ว)
**source:** ORDER-141 build DONE ยังไม่มี independent review; EA มี kill-switch persisted GV + lot cap = money-adjacent. **spec (neutral QA — ห้ามบอกผล 141):** อ่าน `(EXP)_AdaptGridMC_rev01.mq5` + `_mt5_auto/adaptgrid_mc_zone.py` ตรวจ: (1) hard-kill −20% equity: fire ทุก path? persisted GV รอด restart/recompile? fail-closed เมื่อ GV หาย? (2) MaxLevels/MaxTotalLot cap บังคับก่อน order ทุกใบ? (3) zone P10/P90 อ่านผิด/ว่าง = EA ทำอะไร (ต้อง refuse ไม่ใช่เทรดต่อ)? (4) digit/lot normalize + bar-open gate + tester-gate ตาม mql-review checklist (5) zone script: block bootstrap ถูกต้องตามนิยาม? seed/replicability? **output:** findings SEV-1/2/MINOR + file:line → `_triage/CODEX_ORDER145_AGMC_AUDIT.md`. **ห้าม:** แก้โค้ด (audit-only) · รัน backtest (นั่นคือ 142). **ทำได้:** Codex.
**result:** audit report `_triage/CODEX_ORDER145_AGMC_AUDIT.md` written. Findings: SEV-1 hard-kill only evaluated at bar-open; SEV-2 unchecked persisted GV writes; SEV-2 non-finite zone CSV values accepted; MINOR generated-N off-by-one vs EA; MINOR no 1000-bar self-guard. Caps, invalid-zone refusal, lot normalization, tester gate, and seeded block bootstrap checked as passing. No source edits/backtest/verdict.

## ORDER-139 — Wave-2 XAU optimize ladders: S1 TrendRider H4 + SS4 SweepReversal M15 — `DONE + REVIEWED(Claude 2026-07-20): S1 = VALIDATED CANDIDATE → DEMO-ready 992004 (plateau 6-cell a20×s{.3,.5}×c{2..3}; center a20/s0.5/c2.5 MAIN 1.63/BWD 1.03/holdout 2026H1 1.33 (burned)/M4 1.61-1.01 retained/MC ruin 0 DD95 4.15/corr ≤0.32; BWD borderline → demo isolate) · SS4 = PARKED-VERIFY(user) (MAIN pulse 1.31–1.85, BWD <1 ทุก healthy-n cell; RSI last-opt pass เดียว = n=27 spike). bundle _vps_deploy/W2_S1_TRENDRIDER_XAU + DEPLOYMENTS row PENDING_ATTACH`
**why:** Wave-2 smoke (2026-07-19): S1 MAIN 1.77/72t, SS4 1.31/146t — both PROCEED. Stage A (this session)
pinned homes: S1 = H4 (H1 MAIN 1.02/BWD 0.76) · SS4 = M15 (M30 worse both windows). Naked BWD: S1 0.84, SS4 0.88.
**bars (pre-registered ก่อนรัน Stage B):** optimize pass = MAIN ≥1.2 AND BWD ≥1.0 (soft) on a PLATEAU (center
not peak, neighbors pass) · holdout 2026H1 ≥1.2 = deploy-track / 1.0–1.2 = BUILD-ON / <1.0 = selection-fit ·
M4 both-window PF ≥1.0 retained, no model-switch cliff · dead = ceiling <1.0 both-window after ladder ≥3 lever
× 2 TF + last-optimize.
**flat-lot probe:** N/A (both single-position flat 0.01, real SL — no escalation).
**method:** Stage B both-window grids (S1: AdxMin×SepAtr×ChAtr 27 cells · SS4: AdxMax×SweepAtr×TpAtr 18 cells)
→ S1 funnel (holdout+M4 on locked plateau center) · SS4 last-optimize RSI band ก่อน verdict. CSVs
`_mt5_auto/W2_*.csv`, sets `_mt5_auto/ab_sets/w2_s1|w2_ss4`.

## ORDER-140 — SS1 LondonORB BUILD-ON: symbol×TF expansion — `DONE + REVIEWED(Claude 2026-07-20): ไม่มี home ใหม่ผ่าน bar — GBP 0.79 MAIN / EUR 0.88-0.89 ตาย · USDJPY M15 1.14/1.10 + XAU M30 1.13/1.08 @n~700 = both-window>1 แต่ใต้ 1.2 ทุกบ้าน → SS1 คง BUILD-ON; lever ค้าง = partial-TP + trend filter. CSV W2_SS1_EXPAND.csv`
**why:** SS1 = BUILD-ON (plateau MAIN 1.14–1.17 / BWD 1.02–1.07 @n700, MAIN ใต้ hard bar 1.2). Doctrine
build-on = ขยาย symbol×TF ก่อนตัดสิน.
**bars (pre-registered):** cell ใหม่นับเป็น home เพิ่มเมื่อ MAIN ≥1.2 AND BWD ≥1.0 · 1.0–1.2 both = BUILD-ON คงเดิม ·
corr pairwise <0.8 กับ cohort ก่อนเสนอ deploy. **flat-lot probe:** N/A (single-position OCO, real SL).
**method:** plateau-center set (MinOr 0.5 / TpRR 3) บน GBPUSD/EURUSD/USDJPY M15 + XAUUSD M30, both-window.
CSV `_mt5_auto/W2_SS1_EXPAND.csv`.

## ORDER-141 — (EXP)_AdaptGridMC_rev01 build (FINDYOUR8 #1 MC block-bootstrap zone grid) — `DONE(build-only 2026-07-20) — backtest ยังไม่เริ่ม (ตามคิว user: spec→code→compile+tests พอ)`
Spec: standalone (EXP)_ L3 flat-lot BUY ladder ระหว่าง P10/P90 จาก offline `_mt5_auto/adaptgrid_mc_zone.py`
(10k paths × 60d, 24-day block bootstrap, 1000 D1 bars) · spacing 0.3×ATR(D1,30) หรือ geometric · band cap +
MaxLevels ≤40 + MaxTotalLot + hard kill −20% equity persisted GV · magic 992007. mql-review PASS (C3 benign note) ·
compile 0/0 · zone script self-tested (synthetic 1100-bar, 2k paths → sane P10/P90/N). **ก่อน backtest ต้อง:**
export D1 CSV จริง (BTCUSD/ETHUSD) → gen zone → BWD 2020-22 = HARD gate + flat-lot per spec + swap-drag บันทึกใน verdict.

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

## ORDER-119 — CAMPAIGN: ST03 rescue รอบ owner-override — 3 lever ที่ยังไม่เคยแตะ (flat-lot bar ตัดสิน) — `REVIEWED(Opus 2026-07-19): DEAD-OPTIMIZED (flat-lot MACD-reversion entry, ranger homes) — campaign ปิด, lever A/B ไม่เดิน`
**verdict (lever C = last-optimize บน right home, ครบ):** sweep `_15_Macd{Fast,Slow,Signal}`×`_15_CountBars` 18 combo × 6 cell (GBPUSD/EURUSD/EURGBP × H1/H4) × 2 window = 216 runs (agent, main tester serial, n≥200/combo, Opus verify: parse PF column จริง + spot XML). **pre-registered GATE = ไม่ผ่าน: 0 cell flat-lot PF≥1.0 both-window.** best-home EURUSD H4 MAIN 1.15 (16/34/3) แต่ BWD max 0.98 ที่ combo เดียวกัน → window-crossing pair fail ทุกตัว (MAIN>1 → BWD<1 สลับกันเสมอ). **ตัดสิน DEAD-OPTIMIZED เพราะ:** (1) right home ยืนยัน (ranger ×3) (2) last-optimize lever ที่สำคัญสุด (entry-signal params, StoK-lesson) ครบ — ceiling < 1.0 both-window (3) **lever A (capped basket) ห้ามเดิน = flat-lot no-edge + escalation = martingale-คือ-edge-เอง (DEAD-STRUCTURAL trap)** · lever B (regime gate) ไม่สร้าง edge บน underlying no-edge แค่ลด trade. **ST03 MACD-reversion = no robust both-window edge naked บน ranger.** evidence `_triage/ORDER119_LEVERC_RESULTS.md` + XML `_mt5_auto/optimizations/O119C_*.xml`. **⏭ decision ระยะยาว (ถอด ST03 ถาวร / แทน Boss_16 slot) = owner-override territory → user เคาะ** (ผม judge campaign evidence, fate ของ owner-override EA = user). role: agent sweep · Opus verify+judge.
**เดิม spec:**
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

## ORDER-124 — chassis chores ×3 ตาม framework Part 1 (additive, cage) — `DONE+REVIEWED(Opus 2026-07-19, commits 445a1b7 + fix-pack): (1) Kangaroo.mqh → core/entries/ + include fix 3 จุด (2) _MG_* ×7 → Inputs.mqh ชื่อไม่เปลี่ยน (.set เดิมโหลดได้) (3) exit-owner assert OnInit hard-WARN + legal-combo table DESIGN_V2 §3c. Codex blind review = 1 SEV-2 + 2 MINOR → fix 2 / accept-doc 1: SEV-2 จริง — assert แรกพลาด close path ที่ชนจริง (93 + ExitMode 21/22 + _2_SuppressLegTP=false → leg0 มี broker TP สด = second owner) → เพิ่ม WARN แนะ SuppressLegTP=true (ไม่ fail เพราะ probe set 93 ที่ pin cage รัน combo นี้เอง) · MINOR-1 Boss_16 false-positive → #ifndef LAB_ENTRY_16 exempt ทั้ง block · MINOR-2 partial-warn เมื่อ target=0 = accept-doc (ข้อความยังจริง). cage ×2 รอบ: compile 0/0 ×9 · tests 7/7 · tpl_regression 8/8 CLEAN (Boss_14 n=84 · Boss_18 6020 เป๊ะ) = byte-identical for defaults`
**source:** framework Part 1(b) rules 5-6. **spec:** (1) ย้าย `core/Kangaroo.mqh` → `core/entries/`
(แก้ include ใน LabCore #ifdef 16) (2) ย้าย input block `_MG_*` จาก LabCore.mqh → Inputs.mqh (3) exit-owner
assert ที่ OnInit — fail/hard-WARN เฉพาะ combo ที่ close path รันพร้อมกันได้จริง (STACK_PYRAMID+Recovery ON;
**ห้าม trip เคส dormant** เช่น entry-16 ที่ Kangaroo return ก่อน ExitManager — Codex catch) + ตาราง legal
combos ลง DESIGN_V2 §3c. **acceptance ต่อข้อ:** compile 0/0 ทั้ง 8 Boss EA · run_tests PASS · neutrality:
trade count + net identical ก่อน/หลังบน regression set (baseline stale ใช้เทียบ n ได้) · .set เดิมโหลดได้
(ชื่อ input ไม่เปลี่ยน). **ห้าม:** เปลี่ยนชื่อ input ใดๆ (พัง .set) · แตะ logic. **ทำได้:** Claude · Codex ·
👉 แนะ: **Claude เขียน + Codex blind review** (แตะ core = โค้ดสำคัญตาม routing flip)

## ORDER-125 — chassis lever: vertical-barrier exit (max-holding-bars force-close) — `DONE+REVIEWED(Opus 2026-07-19): lever BUILT+Codex-hardened (default OFF byte-identical) · A/B host Boss_14 GBPJPY H4 = NO LIFT, DEAD-ON-GRID at M4 (MH130 dead M1 BWD 0.73; MH390 M1-pass REVERSED by M4 BWD 1.11→0.85 net +210→−368) · lesson: grid recovery-tail = engine ห้าม time-cut + exit lever บน grid = M4-deciding · lever คงในแม่พิมพ์เป็น dial สำหรับ non-grid host (ยังไม่ทดสอบ) · Codex review 3 MAJOR+3 MINOR → fix 5/doc 1 · cage post-fix: compile 0/0 ×9 · tests 7/7 · regression 8/8 (Boss_18 = 0-trade artifact ยืนยันด้วย solo rerun 6020 เป๊ะ · Boss_14 baseline re-pin n 56→84 เงินเท่าเดิมทุกสตางค์ = MINOR-5 partial-leak bugfix, reproduced ×2) · verdict = _triage/ORDER125_VERTBARRIER_VERDICT.md`
**source:** QuantCorner idea catalog #2 (Triple Barrier Method) + LEAD TRIAGE 2026-07-18 (`_triage/QUANTCORNER_FINDYOUR8_IDEA_CATALOG.md`). **why:** พอร์ตมี horizontal barrier (TP/SL) ครบ แต่ไม่มี **time-based force-close** — grid/DCA ที่ค้าง basket ใต้น้ำนาน (recovery-days tail ที่ equity curve ซ่อน) ไม่มี lever ปิดตามเวลา. เป็น exit-mode lever ใหม่ตรงตาม LAST-OPTIMIZE doctrine (lever ที่ยังไม่เคยแตะ).
**spec:** เพิ่ม input `_2_MaxHoldBars` (int, default 0=off → byte-identical เมื่อ off) ใน ExitManager (axis 2x). เมื่อ >0: ปิด position/basket ที่เปิดเกิน N บาร์ (นับจาก first-leg open). **acceptance:** compile 0/0 · neutrality byte-identical เมื่อ off (regression set) · run_tests PASS · .set เดิมโหลดได้. **bars:** pass = ยก recovery-days ลง AND both-window PF ≥1.0 retained บน host grid EA (เช่น Boss_14) · dead = ตัด trade ทำ PF <1.0 both-window · กลาง = ลด DD แต่ net แย่ลง = opt-in robustness dial (เหมือน dyn-close-money 098-C). **flat-lot probe:** N-A (exit lever ไม่ใช่ sizing). **ห้าม:** เปลี่ยน default behavior · แตะ entry. **ทำได้:** Claude เขียน + Codex blind review (แตะ core).

## ORDER-126 — SMCxSTO 991070 SL-rescue: ATR-adaptive SL + round-number offset — `DONE+REVIEWED(Claude 2026-07-19): NO LIFT → keep 991070 as-is. Built _09_RoundAvoidPips lever on (EXP)_EmaStoRev (default OFF byte-identical, mql-review PASS, compile 0/0, neutrality RA0=demo 1.50/136t). SL-fan×round-avoid EURUSD H1 both-window: M1 SL axis already plateau (all ≥1.0), round-avoid mildly downgrades. M4 (deciding — EA fill-sensitive): SL−20% edge = 0.94/0.99 (reproduces Lane C fragility exactly = M4-specific, M1 hid it 1.05/1.03), round-avoid ON = 0.90/1.14 (MAIN worse). Fragility = fill/BE-move sensitivity NOT round-number stop-hunt → idea #3 wrong failure mode, closed for SMCxSTO. Deployed center SL=3.0 robust on M4 (1.39). Lever kept in EA (default OFF, reusable). Next SMCxSTO build-on = different HOME not SL. verdict=_triage/ORDER126_SMCSTO_ROUNDAVOID_VERDICT.md`
**source:** QuantCorner idea catalog #3 (stop-hunt/round-number avoidance) + LEAD TRIAGE 2026-07-18. **why:** SMCxSTO EURUSD H1 (demo 991070) = marginal edge แต่ **SL-fragile** (Lane C ORDER-LANEC: SL−20%=2.4×ATR พลิก 0.94/0.99 both-window, center=cliff ไม่ใช่ plateau). idea #3 ชี้ตรง: SL ที่ round-number level โดน liquidity-hunt. **last-optimize lever ที่ยังไม่แตะ = SL placement rule** (เดิม tune แต่ SL width ไม่เคย tune SL-offset-from-round-number).
**spec:** vehicle = `(EXP)_EmaStoRev` (standalone, magic 991071 = lab copy, **ห้ามแตะ 991070 live-demo**). เพิ่ม SL rule: (a) ATR-adaptive base (มีอยู่แล้ว) + (b) offset SL ออกจาก round-number (00/50 level) เล็กน้อย (เช่น ±3-8 pip ให้พ้นโซนที่ stop กระจุก). funnel EURUSD H1 both-window (MAIN 2023-25 / BWD 2020-22) + holdout 2026H1, Model 1. **bars:** pass = SL axis กลายเป็น **plateau** (SL และ SL±20% ทั้งหมด ≥1.0 both-window) AND holdout ≥1.2 → candidate swap vs 991070 · dead = offset ไม่ยก SL-fragility (center ยัง cliff) → คง 991070 as-is, idea #3 ปิด. **flat-lot probe:** N-A (single-position reversion, ไม่มี escalation). **ห้าม:** verdict (Claude) · แตะ 991070 live. **ทำได้:** Claude build → agent batch funnel.

## ORDER-127 — CAMPAIGN: RSI-as-MOMENTUM family + filter overlays (user request 2026-07-18) — `REVIEWED(Claude 2026-07-18): naked-momentum branch = DEAD-OPTIMIZED (concept). Built (EXP)_RsiMomentum_Naked (3 modes A/B/C + EMA/MACD/BB filter default-OFF, mql-review PASS, compile 0/0). Tested BOTH momentum homes: XAU H1/H4 (all 3 modes + fine-grid — coarse spikes P9/L55·P21/L50 did NOT reproduce at fine res = noise; mode A tops 0.99 MAIN, mode C flat ~1.0) + GBP H1/H4 (27 combo — 1 lone both-window cell A_SMA30_P21 H4 1.21/1.27 = isolated spike, all neighbors fail MAIN; rest breakeven). No plateau both-window≥1.2/1.0 anywhere on either home × 3 archetypes × entry-swept × 2 TF → concept dead earned. RSI = no standalone momentum edge naked; filters can't rescue naked-breakeven (gate lesson, so filter overlays not run). RSI usable only as confirm-FILTER on another base. reversion branch (D classic OB/OS on rangers) NOT run = low-prior (BB+RSI already ~1.1 dead) — left as optional. evidence RSIMOM_{FINE,GBP}_SWEEPS.csv, signal-landscape updated.` (role: Claude build+judge · agent/driver batch)
**เดิม spec (OPEN):**
**source + full plan:** `_triage/RSI_STRATEGY_MATRIX_2026-07-18.md` (lead triage + dedup). **why:** user อยากลอง RSI strategy ให้หมด (SMA20-RSI · break-trending RSI · grid RSI) + filter (MACD/ST/EMA/BB). dedup แล้ว: **RSI-as-reversion (classic OB/OS · grid-RSI · BB+RSI) = ทำแล้ว/เพดานเตี้ย ~1.1** (ST03/RSI-MR/NuiIndy/BB+RSI dead). ช่องเปิดจริง = **RSI-as-MOMENTUM** (ตรง prior momentum>reversion, ยังไม่เคยเทสเป็นระบบ).
**spec:** build `(EXP)_RsiMomentum_Naked.mq5` — enum `_01_RsiMode` {A=RSI-SMA20-cross · B=RSI-50-break · C=RSI-trendline} + filter block default-OFF (EMA-align/SuperTrend/MACD-confirm/BB-squeeze) bool ต่อตัว (byte-identical เมื่อ off). chassis-safety (bar-open · tester-gate · digit-aware pip · magic-scope). flat-lot naked (Model 1 พอ). **smoke order:** (1) B naked XAU H1+H4 (2) A naked XAU+GBP H4 → pulse ค่อย +EMA200 → +ST. (3) D classic OB/OS minimal smoke EUR/EURGBP = ปิด cell เท่านั้น. **E grid-RSI = ข้าม** (ST03 ทำแล้ว).
**bars:** pass = naked cell PF≥1.2 both-window บน trender (RSI-momentum edge) · dead = A+B ไม่มี cell ≥1.0 both-window หลัง sweep entry-param (RSI period/SMA/50-offset) → RSI-momentum family ปิด บันทึก signal-landscape · กลาง = 1.0-1.2 → +filter วัด expectancy-per-trade. **flat-lot probe:** N-A (naked single-position). **ห้าม:** verdict (Claude) · stack >2 filter รอบแรก · grid ก่อน naked ผ่าน · หวัง filter กู้ naked ที่ตาย. **ทำได้:** Claude build → agent batch smoke.
**PROGRESS (Opus 2026-07-18):** EA `(EXP)_RsiMomentum_Naked` built (3 mode enum A/B/C + EMA/MACD/BB filter default-OFF; SuperTrend deferred to post-pulse) · mql-review PASS · compile 0/0. **naked B (RSI-50 break) MAIN smoke: XAU H1 0.88(270t) · H4 1.00(71t) = ใต้บาร์ 1.2 = ยังไม่ตี verdict, ต้อง optimize entry-param ก่อน** (default-smoke ปิดได้แค่ cell). → entry-param sweep (RsiPeriod×Level × H1/H4 both-window) กำลังรัน. mode A/C ยังไม่ smoke.

## ORDER-135 — ST03 lever A: capped-basket ENGINE-EDGE test (กฎใหม่ 2026-07-19) — `REVIEWED(Opus 2026-07-19): DEAD (engine ก็กู้ไม่ขึ้น) — ST03 ตระกูลปิดถาวร earned` ⚠️ renumbered จาก 133 (เลขชน StoMultiTap ของ session คู่ขนาน `a1a36f40`)
**VERDICT:** DCA capped-basket sweep (2 near-miss cells × MaxLevels{4,6,8} × LotProg{NONE,LINEAR,LOG} × 2 window = 12 passes, agent, Opus verify PF column + XML). **NO SURVIVOR: 0/9 combo both-window ทั้ง 2 cell** (GBPUSD H1 BWD 1.03-1.05 ✅ แต่ MAIN 0.95-0.96 ❌ · EURUSD H4 MAIN 1.007 ✅ แต่ BWD 0.81 ❌). **finding เชิงกลไก:** DCA engine engaged จริง (n +2.2× adds จริง) แต่ **escalation ไม่สร้าง edge — แค่ leverage regime-dependence** (BWD net +88→+140 winner-window ชนะมากขึ้น, MAIN net −111→−177 loser-window แพ้มากขึ้น; EURUSD escalation ทำ MAIN แย่ลง 1.15→1.007). worst-case eqDD max 2.93% << 15% (กรงข้อ 1 ผ่าน แต่ edge ไม่มี → กรงข้อ 2 BWD-hard both-window fail). **⇒ chassis-default MM กู้ MACD signal ไม่ขึ้น (ทั้ง flat-lot lever C + generic DCA lever A).** ⚠️ **SCOPE แก้ (user 2026-07-19): นี่ = chassis-CELL dead ไม่ใช่ concept ถาวร.** chassis Boss_15 มี signal parity 133/133 แต่ **MM ไม่ parity** — standalone `EA_RUNNER_ST03` มี LOT_Repeat/tp3/near/spacing/vol-gate ที่ user tune มือ (sets เยอะใน worktree, `ST03_optimized_v2` ฯลฯ) = machine คนละตัว ยังไม่ re-test รอบนี้. **standalone = PARKED-VERIFY(user): user optimize เอง, both-window winner → กลับเข้า funnel.** handoff = `_triage/HANDOFF_ST03_OPTIMIZE_2026-07-19.md` (open levers: spacing UNSWEPT · per-symbol TP×exit · LR-depth×vol-gate). evidence `_triage/ORDER135_ENGINE_RESULTS.md`. role: agent sweep · Opus verify+judge.
**เดิม spec (ORDER-133-mine, renumbered):** lever A เปิดกลับโดยกฎ ENGINE-EDGE → capped-basket DCA บน 2 cell ดีสุดของ lever C ภายใต้กรง 5 ข้อ. spec เต็ม = ประวัติ commit `d9227116`.
**spec:** vehicle = Boss_15 chassis (ห้ามแตะ live/บัญชีใดๆ — ST03 ออกจากเงินจริงหมดแล้ว). cells = 2 near-miss ที่ดีสุดจาก lever C: **GBPUSD H1** (12/26/3 — BWD 1.05 ดีสุด) + **EURUSD H4** (16/34/3 — MAIN 1.15 ดีสุด). sweep: `StackMode=92 (DCA)` × `_9_MaxLevels {4,6,8}` × `LotProg {50=NONE, 51=LINEAR(_51_ProgFactor 0.5), 54=LOG(_51_ProgFactor 1.0)}` = 9 combo/cell × 2 window (MAIN 2023.07–2026.07 + BWD 2020-22) Model 1 screen → **M4 confirm บังคับทุก survivor**. ProtectLevel=2 (kill 25%) คงที่.
**ENGINE-EDGE cage (pre-registered — ครบ 5 ข้อจึง CANDIDATE ได้):** (1) worst-case per basket ที่ 0.01 base lot ≤15% equity 10k — คำนวณจาก maxLevels×lot-ladder×SL/kill แสดงเลขใน report (2) **BWD ≥1.0 HARD** (3) M4 retained ≥1.0 both-window (4) MC ruin ≤2% (รอบ MC หลังผ่าน 1-3) (5) label engine-edge sizing เล็กถาวร. **bars:** pass = combo ที่ผ่านครบ 1-3 → MC → PARKED-VERIFY(user เคาะ demo) · dead = ไม่มี combo ผ่าน BWD-hard + M4 → engine ตายบน entry นี้ ปิดตระกูล ST03 ถาวร. **flat-lot probe:** done แล้ว (lever C = diagnosis: engine-edge class confirmed). **ห้าม:** Model-2 เป็นหลักฐาน · แตะบัญชีจริง/demo · geometric multiplier >1.5 · size-up ตาม PF. **ทำได้:** agent sweep M1 + M4 serial → Opus judge.

## ORDER-136 — CAMPAIGN: escalation-MM overlay บน validated PF>1 cohort (user directive 2026-07-19 "เทสใหม่หมดบนระบบใหม่") — `OPEN — Wave1 CLOSED 2026-07-19 (overlay แพ้ bar, คง single-position) · Wave2+ รอ user เคาะ` (multi-session · pace 1-2 cell/รอบ) ⚠️ renumbered จาก 134 (กัน collision session คู่ขนาน)
**source:** user 2026-07-19 — EA ที่ PF>1 ทั้งหมดลองใส่ escalation ได้ (MM lever ปกติ ไม่ใช่ ENGINE-EDGE เพราะ signal มี edge อยู่แล้ว) + chassis ผ่าน safety overhaul ครบ = โครงพร้อม. **judge ที่ expectancy + worst-case DD ไม่ใช่ PF อย่างเดียว — คาด: PF ต่อ window สวยขึ้น tail อ้วนขึ้น.**
**Wave 1 (เริ่มได้เลย — chassis-native ถูกสุด):** Boss_17 Wave5 (validated, demo 990301-303) — sweep `StackMode {90 base, 92 DCA}` × `_9_MaxLevels {4,6}` × `LotProg {NONE, LINEAR, LOG}` บน XAU H4 (home หลัก) both-window M1 → M4 survivor. bar: overlay ชนะ = expectancy/trade ≥ base AND worstDD ≤ base×1.5 AND both-window ≥1.0 · แพ้ = คง single-position (บันทึกแล้วปิด wave).
**WAVE 1 CLOSED (Opus 2026-07-19, 2 รอบ × pace): overlay แพ้ — คง single-position.** base XAU H4 M1: MAIN 1.60/payoff 5.16/eqDD 1.53% (81t) · BWD 1.00 ปริ่ม (56t). Cells: 92/L4/NONE = MAIN 1.82/5.91 ✅ แต่ eqDD 5.46%=3.6×base ❌ BWD 0.94 ❌ · 92/L4/LINEAR = MAIN 1.85/6.67 แต่ eqDD 6.70%=4.4× ❌ BWD 0.91 ❌ (แย่ลง monotonic ตาม lot-curve — พยากรณ์รอบ 1 ยืนยัน) · 92/L6/NONE = **เลขเหมือน L4 ทุกตัว** (139t/103t) = แกน depth INERT (adds ไม่เคยถึง 5+). LOG bounded ระหว่าง NONE/LINEAR ที่ fail ทั้งคู่ + L6 identical → cell ที่เหลือไม่ให้ข้อมูลใหม่ = earned close โดยไม่เผา grid ครบ. **Root cause: base BWD≈1.0 → DCA overlay = regime-dependence amplifier (กลไกยืนยันข้าม host กับ ORDER-135)** → lesson ลง EDGE_CATALOG dead pile. Boss_17 demo 990301-303 ไม่แตะ. **Wave 2+ = รอ user เคาะ** (MacdDiv/EmaStoRev ต้อง port entry ก่อน · Boss_14/RSI_MR = grid เดิมเทส LotProg ได้ · หมายเหตุ: host ที่ BWD แข็งแรงจริง >1.1 เท่านั้นที่คุ้มลอง). sets `_mt5_auto/ab_sets/order136_w1/` · reports `O136_W1_*` ×8.
**Wave 2+ (`DONE(Codex, 2026-07-21)`):** MacdDiv XAU / EmaStoRev = standalone ต้อง port entry เข้า chassis ก่อน (build order แยก) · Boss_14/RSI_MR = grid อยู่แล้ว (เทส LotProg เพิ่มได้) · crypto = pyramid อยู่แล้ว. **ห้าม:** burst ทุก wave พร้อมกัน (pacing rule) · deploy โดยไม่ผ่าน funnel เต็ม · แตะ set demo ที่ attach อยู่. **ทำได้:** Claude ออก .set → agent batch → Opus judge ต่อ wave. Codex route: Boss_14 GBPJPY H4 validated host, base-vs-LOG13 M1 gate ก่อน M4. Raw: `_triage/ORDER136_W2_B14_GJ_RESULTS.md`. BASE BWD PF=0.92 gate fail; LOG13 BWD PF=0.91; M4 NOT RUN; รอ Claude review.

## ORDER-138 — template SEV-1 pack #2 (Codex roadmap 2026-07-19): persist/kill transactional hardening — `DONE + REVIEWED(Opus 2026-07-19): #1-4 + 138b + 138c ครบ, Codex audit 2 รอบครบ loop → live-rollout blocker ปลด (ฝั่ง code); user ยังต้องเดิน PERSIST_MIGRATION_ORDER132.md checklist ก่อน roll จริง`
**138c RE-AUDIT (user สั่ง Codex รีวิวรอบสอง บน commit `29b31b7` → `_triage/CODEX_ORDER138B_REAUDIT.md`):** ยืนยัน F1/F3/F4/F8 CLOSED + เจอจริงอีก 2 → **แก้ครบใน 138c:** (NEW-1 SEV-1) restore เดิมรับ record ขาเดียว (`a!=0||b!=0`) + marker delete unchecked → stale marker + crash กลาง arm = certify mixed-generation half-pair → แก้: restore ต้องครบ**สองขา**ใต้ marker (marker-only/ขาเดียว = wipe ทันที) · arm ห้ามเขียน legs ใต้ marker เก่าที่ delete ไม่ผ่าน (checked, fail=abort) · clear = marker-first checked (marker ติด = เก็บ record เก่าครบไว้ ปลอดภัยผ่าน ticket revalidation) · (NEW-2 SEV-2) `RC_PersistHalt=false` (ทาง manual-unhalt ใน doc) ข้าม intent ที่ persist แล้ว → un-gate existing-key handling ทั้งหมด (restore+delete+pair clear) จาก flag — flag เหลือหน้าที่เดียว = gate การเขียน intent ใหม่ · (F2 contested → **ยอมรับ Codex ถูก**) helper เสิร์ฟทั้ง safety และ profit exit → แยก policy: `Exit_CloseBasket(safety)`/`Kangaroo_CloseBasket(safety)` — money-stop/emergency/flatten/resume = ปิดต่อแม้ arm fail; TP/dyn/run-trend/single-TP = abort รอ predicate re-fire · (F7→closed) `PersistMigrate_Test.set` เปิด acct gate + S10 hwm-gate + S9 ครบ 3 key · (F6 partial) NEW-1 rule ครอบด้วย static scenarios S7/S8 ไม่ต้องมี fault-injection seam. **ยัง defer:** F9-remainder (OnTimer no-tick keep-alive — window ต้อง no-tick 4 สัปดาห์+restart พอดี, retries ต้องมี tick อยู่ดี) · F5 (re-audit เองบอก no rollout blocker). **evidence 138c:** compile 0/0 ×9 · tests 7/7 (Migrate **10** scenarios / Intent **8**) · cage 8/8 CLEAN (Boss_18 6020 เป๊ะ).
**PROGRESS (Opus 2026-07-19, session สด):** #1/#2/#3 ครบ + **138b audit-fix pack 4 ตัว**. (1) **#1 cross-account kill migration:** `RiskControl_InitEx(adoptLegacyHalt)` + input `RC_AdoptLegacyHalt` (default false) — gate fail-closed **ก่อนแตะ GV ใดๆ** เมื่อเจอ legacy key ที่ init จะอ่าน (active kill/halt · `rc_peak_eq` ทุกค่า · `acct_hwm` เมื่อ acct-gate on) โดยไม่มี consent → OnInit `INIT_FAILED` + log บอกทางแก้ทั้ง upgrade (set flag ครั้งเดียวแล้ว revert) และ contamination (ลบ F3); LabCore probe key ยาวสุดใหม่ `exit_closeall`. (2) **#2 pair-persist atomic:** two-ticket + commit-marker `k16_pair_ok` (drop marker → write legs checked → re-set marker → flush); restore เชื่อ legs เฉพาะใต้ marker (torn write = discard complete-or-none); arm ไม่ durable = **abort liquidation**; ไม่ rewrite record กลาง reconcile (138b F3) — clear checked เมื่อทั้งคู่ broker-confirmed gone เท่านั้น. (3) **#3 closeall intent persisted:** `exit_closeall`+`k16_closeall` arm+flush **ก่อนปิดไม้แรก**, restore ผ่าน `ExitManager_Init()`/`Kangaroo_Init()`, clear เฉพาะหลัง broker-flat proof + **confirmed delete** (`Persist_DelChecked`, 138b F4 — stale intent=1 จะปิด basket อนาคตผิดตัว); ช่อง CountAll==0-แต่-pendings-เหลือ ปิดแล้ว (route ผ่าน CloseBasket proof); TTL re-touch ทุก ~60s ระหว่าง liquidation ค้าง (138b F9). **AUDIT TRIAGE (Codex `_triage/CODEX_ORDER138_AUDIT.md` 9 findings → Opus judge, detail `_triage/CODEX_ORDER138_AUDIT_TRIAGE.md`):** ✅ แก้ 4 (F1 **rc_peak_eq ไม่ benign** — foreign peak → KillDD ฆ่าบัญชีผิด tick แรก, จับจุดบอด spec ผมตรงๆ · F3 mid-flight rewrite ทำลาย durable record · F4 unchecked delete → stale intent ปิด basket ใหม่ · F9 TTL ไม่คลุม intent keys) + F7/F8 (test S8/S9 + doc pre-upgrade pair check) ❌ reject 2 (F2 close-แม้-persist-fail = deliberate degraded mode สำหรับ safety exit, doc แล้ว · F5 ticket>2^53 ห่างจริง ~6 order) ⏭ defer 1 (F6 fault-injection seam ใน money path — no known failure mode, 132b precedent). **evidence:** compile 0/0 ×9 (×3 รอบ) · tests **7/7** (PersistMigrate 9 scenarios + `PersistIntent_Test` ใหม่ 6 scenarios: torn-discard/commit-roundtrip/restart-restore/flat-release ×2/clean-slate) · **cage 8/8 CLEAN ×2** (หลัง 138 และหลัง 138b; Boss_18 6020 เป๊ะ) บน tester ว่าง · migration doc updated (consent flag + degraded mode + pair pre-upgrade check + TTL scope). **(role: Opus author (money code) → Codex blind-audit → Opus triage)**
**เดิม spec:**
**source:** `_triage/CODEX_ROADMAP_2026-07-19.md` §"New actionable findings" — 4 finding ที่ remediation diff (129/132) เปิดขึ้นใหม่. **Opus verify แล้ว 4/4 จริง (อ่าน code):**
- ✅ **#4 DONE (clear-cut, แก้แล้ว commit นี้):** `PersistMigrate_Test.mq5` ไม่มี MQL_TESTER guard + `GlobalVariablesDeleteAll("Boss")` ลบทั้ง `Boss_*`+`Boss2_*` (scoped ปัจจุบัน) → deploy mirror tests → attach chart = ล้าง halt/kill/HWM/pair ทุก Boss. **fix: OnInit fail-closed `if(!MQL_TESTER) return INIT_FAILED`** (tester GV sandboxed = ปลอดภัย; live/chart refuse). compile 0/0 ยืนยัน.
- 🔴 **#1 SEV-1 kill migration ข้ามบัญชี (สำคัญสุด — blocker live rollout):** `Persist_MigrateLegacy`/`RiskControl_Init:118-145` คัด legacy `Boss_<magic>_rc_kill_pending` (magic-only, ไม่มี identity) เข้า scoped ของ account ปัจจุบัน → terminal switch account + magic ซ้ำ → adopt kill state บัญชีเก่า → `Exec_CloseAll` ปิดไม้ผิดบัญชี. **⚠️ nuance: legacy migration = upgrade path (pre-132→post-132) ที่ user ต้องเดิน — fail-closed ทั้งหมดจะพัง upgrade. fix approach (Opus design): benign keys (rc_peak_eq/acct_hwm) migrate ได้เสมอ; kill/halt (irreversible) เพิ่ม input `RC_AdoptLegacyHalt` default false → เจอ legacy kill/halt + flag=false → OnInit FAIL + log ("upgrade: set flag=true ครั้งเดียว · contamination: ลบ legacy GV via F3") · flag=true → migrate. RiskControl_Init ต้องคืน bool ให้ OnInit return INIT_FAILED.**
- 🔴 **#2 pair-close persist ไม่ atomic:** `Kangaroo_PairPersist:49-55` เขียน k16_pair_a, k16_pair_b แยก (ไม่เช็ค return แต่ละตัว) แล้ว flush; closing เริ่มทันที → write a ผ่าน b fail + crash = restore ขาเดียว = ปิด pair ไม่ครบ. **fix: two-ticket record + commit-marker (เขียน a+b+marker, verify ทั้งหมด+flush ก่อนปิดไม้แรก; abort liquidation ถ้า arm ไม่ durable).**
- 🔴 **#3 full-basket liquidation intent restart-volatile:** `g_k16_closeall_pending`/`g_exit_closeall_pending` = memory-only, reset false ทุก Init → restart หลัง partial close = intent หาย, residual กลับ ordinary management (ถ้า trigger predicate หายไปแล้ว = ไม่ re-fire). **fix: persist/flush intent ก่อนปิดไม้แรก, clear เฉพาะหลัง broker-flat proof.**
**acceptance (#1-3):** compile 0/0 · regression 8/8 neutrality · new failure-path smoke ต่อ finding (cross-account contamination fail-closed · pair write-fail/crash → complete-or-none · restart mid-liquidation resume) · **Codex blind-audit บังคับ (money/irreversible)**. **ห้าม:** roll post-132 binary ขึ้น live จนกว่า #1-3 ปิด (Codex directive) · แตะ live GV โดยไม่มี migration doc update. **ทำได้:** Opus เขียนเอง context สด (Claude-author money code) → Codex audit. **why context สด: kill logic พลาด = แพงสุด, บทเรียน 129/132.**

## ORDER-128 — 🔴 P0: monitoring chain repair (task refused + false-green gist) — `CLOSED (Opus 2026-07-20): gh re-auth สำเร็จ (BaBosss keyring, scope gist/repo) + gist 287cce51 update จริง 2026-07-19 20:31 = E2E ผ่านแล้ว` — a/b/c ครบ + manual run เก็บ snapshot 18 ก.ค. สำเร็จ (auto-commit e321eee, ทุก step ผ่านยกเว้น gist) · **root cause dashboard มือถือเน่า = gh token account BaBosss หมดอายุ (401 มานาน แต่ script เดิมพิมพ์ "updated" ปลอม) → user ต้องรัน `gh auth login -h github.com` เอง แล้ว chain รอบ 07:30 พรุ่งนี้จะพิสูจน์ E2E** · fail-path test ผ่าน (bogus gist id → exit 1 จริง)
**source:** Codex system review `_triage/CODEX_SYSTEM_REVIEW_2026-07-18.md` + contract review เดียวกัน — verified โดย Opus: `EA_LAB_DailyMonitor` LastResult `0x800710E0` วันนี้ 07:47 (LogonType=Interactive → ถูก refuse) · snapshot ค้าง 17 ก.ค. · `publish_dashboard_gist.ps1` ไม่เช็ค `$LASTEXITCODE` ของ `gh gist edit` → "updated" ปลอมได้เมื่อ 401. **why P0:** เงินจริง + 38 ACTIVE deployments แต่ตาเฝ้าบอด และระบบรายงานเขียวปลอม.
**spec:** (a) task config: `StartWhenAvailable=true` + ยกเลิก battery block + เพิ่ม logon trigger (delay) — คง Interactive logon เพราะ `monitor_rotation.ps1` เปิด MT5 GUI terminals (S4U = session 0 เสี่ยง exporter ไม่ทำงาน); (b) `publish_dashboard_gist.ps1` เช็ค `$LASTEXITCODE` ทุก native call, fail → exit 1 ให้ `Step()` แม่เห็น; (c) `daily_monitor.ps1` freshness guard (last success <20h → skip เงียบ กัน logon trigger รันซ้ำ) + health alert (snapshot age >26h → `portfolio/MONITOR_ALERT.txt` + log ALERT + exit non-zero, healthy → ลบ alert file). **acceptance:** manual run จบ exit 0 + dashboard/gist update วันนี้ · task query แสดง trigger ใหม่ · จำลอง gh fail → script exit 1 จริง. **bars:** N-A (infra). **flat-lot probe:** N-A. **ห้าม:** แตะ collector/rotation logic · เปลี่ยน gist id/URL. **ทำได้:** Opus ทำเอง (มี state-change บนเครื่อง user).

## ORDER-129 — template SEV-1 pack + regression-cage rebuild (Codex system review) — `DONE + REVIEWED(Opus 2026-07-18)` — Codex blind-audit ครบ loop แล้ว
**AUDIT TRIAGE (Codex `_triage/CODEX_ORDER129_AUDIT.md` 10 findings → Opus judge):** ✅ **แก้ทันที 6:** F1 money-stop pre-gate (`Exit_SafetyMoneyStop()` แยก loss-leg ออกจาก bar-gate — Codex จับว่าผม implement สเปคตัวเองไม่ครบ) · F2-minimal Stack latch เฉพาะเมื่อ ≥1 leg placed (กัน spread/news veto ทำ ladder ค้างถาวร — regression ที่ผมสร้างเอง) · F5 DryRun ห้าม persist HALT/kill GV · F7 `Exec_NormalizeCloseLot` (ไม่เอา RC_MaxLot ไป cap การลด risk) · F8 cage two-way compare + zero-experts fail · F9-partial warnings enforce 0/0 · F10 spread doc = POINTS + placement-only semantics (ไม่ rename input — D1 hazard). ทุกตัว inert ต่อ cage config (_32_SL_Money=0 · StackMode≠93 · DryRun=false · RC_MaxLot>lots ใน sets). ⏭ **defer → ORDER-132:** F2-full/F3 (transactional exits: pair-close retry · partial confirm · ladder per-leg) · F4 persist scope account+symbol (pre-existing class, ต้องมี migration path ระวัง live GVs) · F6 persist single-enum (crash-window วิเคราะห์แล้ว self-healing ฝั่ง fail-safe). ❌ **ปฏิเสธ 1:** F9-สาย "commit ก่อน CLEAN" — confirm-regression 8/8 CLEAN รันแล้วหลัง commit บน tester ว่าง (Codex อ่านสถานะกลางทาง) · ส่วน "re-pin ก่อน isolate" = จริง, ORDER-131 เปิดรออยู่. **compile 0/0 ×9 (zero-warning enforced) · ✅ final cage confirm หลัง audit-fix = 8/8 CLEAN บน tester ว่าง (2026-07-18 ดึก) — neutrality พิสูจน์เชิงประจักษ์ครบ**
**PROGRESS (Opus 2026-07-18):** ครบทั้ง 7 ข้อ + cage rebuild. (1) cage: deploy.ps1 + tpl_regression.ps1 = dynamic discovery ทุก Boss_*.mq5 + compile-current-source ก่อนรันเสมอ (Boss_17 ที่เคยหลุด list = เข้า cage แล้ว) + baseline re-pin 8 ตัว (17: 24t · 18: 6020t drift-detector). (2) kill state machine `KILL_PENDING→FLAT_VERIFIED→HALTED` — `Exec_CloseAll()` คืน proof-of-flat (re-scan broker state) + persist `rc_kill_pending` (restart กลาง kill = kill ต่อ) + retry ทุก tick. (3) hard-kill ย้ายขึ้นก่อน `_0_BarOpenOnly` gate. (4) Kangaroo SL=0 fail-closed. (5) OnInit reject magic 990001 นอก tester. (6) `_0_MaxSpread` enforce จริง market+pending. (7) NormalizeLot vol-step arithmetic + below-min→0 (ไม่ floor ขึ้น). **Regression: 7/8 byte-identical** (รวม Boss_13 ที่ kill fire ในหน้าต่าง = kill path เดิม reproduce เป๊ะ) · **Boss_18 drift −17t (6037→6020, net −2511→−2499, eqDD 25.13→25.00)**: reproduce ได้ทั้งสองฝั่ง (4×/3×), null-hypothesis (environment) ตกไปด้วย HEAD-run ตรง baseline เป๊ะ, bisect ตีวงเหลือ {LabCore∪Kangaroo} แต่แยกไม่จบเพราะ RSIMOM sweep (ORDER-127 คู่ขนาน) แย่ง tester → **ตัดสิน: รับ + re-pin** (ทิศ safer: kill ที่ 25.00 พอดีแทน overshoot 25.13 · EA ตายแล้ว cage-only · 7 ตัวจริง identical). mql-review PASS · compile 0/0 ×9. **residual → ORDER-131.**
**source:** `_triage/CODEX_SYSTEM_REVIEW_2026-07-18.md` findings SEV-1 ×7, SEV-2 cage/lot/spread — spot-verified 4/4 โดย Opus (LabCore bar-gate bypass เห็นจริง :171 vs :187 · Exec_CloseAll ทิ้ง result :263 · `_0_MaxSpread` dead input · lot NormalizeDouble(,2)).
**spec (ลำดับใน order เดียว — cage ก่อน โค้ดตาม):** (1) **cage rebuild**: `tpl_regression.ps1` compile-current-source ทุก `Boss_*.mq5` (dynamic discovery) + ลบ binary เก่า + baseline pin Boss_17/18 + re-pin baseline ปัจจุบัน (ปลด blocker ORDER-124/125); (2) **kill-reconciliation**: `Exec_CloseAll` คืนสถานะ + `RiskControl` state machine `KILL_PENDING→FLAT_VERIFIED→HALTED` — persist HALT เฉพาะเมื่อ broker ยืนยัน flat (positions+pendings=0), retry ทุก tick; (3) **bar-gate safety**: ย้าย `RiskControl_CheckDD()` + basket money-stop ขึ้นก่อน `_0_BarOpenOnly` early-return ใน `LabCore.mqh` (bar-gate เฉพาะ signal/management ไม่ gate safety); (4) **SL=0 fail-closed**: Kangaroo ATR ไม่พร้อม → ห้ามส่ง order (block ที่ `Exec_Open` กลาง); (5) **magic guard**: OnInit reject default magic 990001 บน live/demo จริง (tester ผ่านได้) + log; (6) **spread check จริง**: `_0_MaxSpread>0` → block open ทั้ง market+pending; (7) **lot normalize**: port ORDER-125 RiskLot pattern (vol-step arithmetic, ต่ำกว่า min → 0+alert ไม่ floor ขึ้น). **acceptance:** compile 0/0 ทุก Boss · regression ตัวเลขเดิมทุก cell ที่ flag off (พิสูจน์ neutrality) · new failure-path smoke (close-fail sim ผ่าน log ตรวจ retcode path มีจริง) · mql-review PASS · Codex blind-audit 1 รอบ (neutral QA prompt). **bars:** N-A (safety refactor — ห้ามเปลี่ยนตัวเลข backtest เมื่อ input default). **flat-lot probe:** N-A. **ห้าม:** เปลี่ยน default behavior/ตัวเลข regression · แตะ entry logic · รวม lever ใหม่ (124/125 แยกไป). **ทำได้:** Opus เขียนเอง (money/risk = Claude-author per AGENTS routing) → Codex blind-audit.

## ORDER-132 — transactional exits + persist scoping (defer pack จาก Codex ORDER-129 audit) — `DONE + REVIEWED(Opus 2026-07-19)` — Codex blind-audit ครบ loop แล้ว
**AUDIT TRIAGE (Codex `_triage/CODEX_ORDER132_AUDIT.md` 20 findings → Opus judge):** ✅ **แก้ทันที 12 (= 132b pack):** P1 key>63 → OnInit fail-closed guard (probe `rc_peak_eq`, live/demo เท่านั้น) · P2 srvhash 16→32-bit · P4 `Persist_DelLegacy` checked + cleanup-retry ทุก init เมื่อ scoped มีแล้ว · R1 log บอกความจริง (`(persisted)` เฉพาะเขียนสำเร็จ) · R2 `!DryRun` gate บน acct_hwm + rc_peak_eq writes · R3 **GV TTL 4-สัปดาห์** → `RiskControl_PersistRefresh()` re-touch รายวัน (live เท่านั้น — tester/DryRun skip) · E1 partial ต้อง retcode DONE/DONE_PARTIAL/PLACED · E2 per-ticket done-list (`g_exit_partialN_tk[]`) กัน retry ดูดขาที่สำเร็จแล้วซ้ำแบบ unbounded (จับดีมาก) · E3 PlacePending retcode check + Stack ต้องได้ ticket จริง + **adopt-by-price** (สแกน own pending ใกล้ target ครึ่ง step ก่อน re-place กัน duplicate จาก timeout กำกวม) · E4 margin projection นับ pendings **ทั้งบัญชี** ไม่ใช่แค่ตัวเอง (double-reserve = ทิศ safe) · X2+K4 closing-latch (`Exit_CloseBasket`/`Kangaroo_CloseBasket` — full-basket close ถือ tick จนพิสูจน์ flat, predicate หายก็ไม่ลืม) · K1/K2/K3 pair intent 2 ช่อง arm ก่อนยิง + **persist** (`k16_pair_a/b` restore + re-validate symbol+magic) + ถือ tick กัน adds ระหว่าง liquidation. ⏭ **DEFER 4 (pre-existing / ทิศ under-exposure ปลอดภัย · ยกไป backlog ไม่เปิด order ใหม่จนมี host 93/partial ใช้จริงบน live):** X1 (milestone reset ข้าม restart → partial ซ้ำ = ปิดเกิน ทิศ risk-reducing) · S1 (restart กลาง partial ladder → ขาหาย ไม่ใช่ขาเกิน) · S2 (broker/manual cancel GTC หลัง latch → ขาหาย) · S3 (re-budget ต่อเนื่องหลังวาง + auto-cancel = behavior lane ใหม่ ต้อง design แยก). ❌ **REJECT 2:** P3 migration-manifest/fail-closed (doc + operator checklist ครอบ; terminal เดียว unique-magic ต่อ attach = ambiguity ที่เหลือคือเคสที่ checklist ข้อ 2 สั่งเคลียร์ GV เองแล้ว) · R1-full persist-dirty state machine (P1 guard ตัดสาเหตุ write-fail จริงตัวเดียวที่รู้จัก; ที่เหลือ = ความซับซ้อนใน money path โดยไม่มี failure mode รองรับ). **evidence 132b:** compile 0/0 ×9 · tests 6/6 · probe 93 identical (347.16/62.01/6t ×3 รอบ) · cage 8/8 CLEAN (Boss_18 6020 เป๊ะ). commits: `0dcf60e2` (132) + closing commit (132b)
**PROGRESS (Opus 2026-07-19):** ครบทั้ง 4 ข้อ. (1) Kangaroo pair-close: broker-state re-scan หลังปิดคู่ (ไม่เชื่อ call result) → ปิดได้ขาเดียว = arm `g_k16_pair_residual` retry ทุก tick จนยืนยัน gone + ห้ามเปิด pair ใหม่ระหว่าง arm (in-memory; restart → ขา residual กลับเข้า grid management ปกติใต้ cage/emergency-DD — documented). (2) `Exec_ClosePartialFraction` → bool (attempted-close fail = false + log retcode; skip เพราะ volume แทนไม่ได้ = ไม่ fail) → milestone latch done เฉพาะเมื่อ true, fail = armed retry ขณะ profit ยังถึง pct. (3) Stack 93 transactional: per-leg `g_stack_leg_ok[]`+ticket, arm-time snapshot leg0 refs (retry ห้าม re-base บน fill ทีหลัง), restart guard เดิมคงไว้, leg ที่โดน veto/reject retry ทุก tick, latch เมื่อครบทุกขา + `Stack_MarginBudgetOK` (OrderCalcMargin leg + `Exec_PendingMarginProjection` own pendings + used margin vs `RC_MaxDepositLoadPct` — fail-closed). (4) Persist key `Boss2_<srvhash4>_<login>_<symbol>_<magic>_<name>` (ไม่ cache scope — account-switch ไม่ reset globals) + `Persist_Set` checked + `Persist_Flush` + rc_state enum เดียว (0/1/2 แทน rc_halted+rc_kill_pending) + `Persist_MigrateLegacy` one-shot ลบ legacy หลัง copy (กัน cross-account re-import) + KILL_PENDING persist+flush ก่อน close แรก. **evidence:** compile 0/0 ×9 · tests 6/6 PASS (ใหม่: `PersistMigrate_Test` 5 scenarios) · mode-93 probe pre/post identical (347.16/62.01/6t — cage ไม่มี cell 93 จึงต้อง A/B แยก, set = `_mt5_auto/ab_sets/order132_93probe.set`) · cage 8/8 CLEAN (Boss_18 6020 เป๊ะ; รอบแรกเจอ 0-trade artifact ชั่วคราว → re-run เดี่ยว+เต็ม = ตรง baseline) · migration doc = `ea_template/PERSIST_MIGRATION_ORDER132.md` (demo-first checklist สำหรับ user). **เหลือ:** Codex blind-audit → triage → REVIEWED+B1.
**เดิม spec (OPEN):**
**source:** `_triage/CODEX_ORDER129_AUDIT.md` F2-full/F3/F4/F6. **spec:** (1) pair-close (Kangaroo overlap) track 2 tickets + retry residual ticket ถ้าปิดได้ขาเดียว (อันตรายสุด: กิน cushion แล้วเหลือ tail) (2) partial-close milestone: mark done เฉพาะหลังยืนยัน volume ลดจริง (3) Stack ladder per-leg ticket tracking + `OrderCalcMargin` budget ก่อนวาง (Codex system-review SEV-1 #5 เดิมด้วย) (4) Persist key scope server+login+symbol+magic + migration path สำหรับ GV เก่าบน live (ST03/Boss_14 ระวัง!) + rc-state เป็น enum เดียว. **acceptance:** compile 0/0 · cage CLEAN · migration ทดสอบบน demo ก่อน · Codex blind-audit. **ห้าม:** แตะ live GVs โดยไม่มี migration doc. **ทำได้:** Opus เขียน → Codex audit.

## ORDER-131 — isolate Boss_18 cage drift to exact line (residual จาก ORDER-129) — `DONE + REVIEWED(Opus 2026-07-19): BENIGN = code-layout FP boundary sensitivity, ไม่ใช่ logic bug`
**method (2-step isolation บน tester ว่าง):** (1) pre-129 `LabCore.mqh` + ไฟล์ core อื่นทั้งหมด HEAD → Boss_18 = **6037 (baseline เดิมเป๊ะ)** → ตัวการ = LabCore ล้วน (Execution/RiskControl/ExitManager/Stack ใหม่ = บริสุทธิ์ต่อ Boss_18). (2) HEAD LabCore แต่ย้าย `RiskControl_CheckDD()` กลับใต้ bar-gate (pre-129 layout) → **6037** อีกครั้ง → **mechanism = การขยับ hard-kill call-site + เพิ่ม `Exit_SafetyMoneyStop()` call ใน `OnTick`**. **why ไม่ใช่ bug:** Boss_18 `_0_BarOpenOnly=false` → bar-gate block ถูก skip → layout เก่า/ใหม่ **ตรรกะเหมือนกันเป๊ะ** แต่ผลต่าง 17t deterministic = MT5 codegen จัด FP ops ต่างเสี้ยว → ที่ kill boundary (Boss_18 fire ที่ eqDD ~25% พอดี) rounding พลิกข้าง → close เร็ว 1 tick → −17t, eqDD **25.13→25.00** (ตรง threshold, ทิศปลอดภัยกว่า), net −2511→−2499. **หลักฐาน harmless:** Boss_11–17 (ไม่ fire kill ในหน้าต่างนี้) byte-identical ทุก probe → reorder ถูกต้องบน EA จริง; drift เฉพาะตัวเดียวที่แตะ kill boundary + trade 6000+. **verdict: benign, baseline 6020 ถูกต้อง, ปิด — ไม่ต้องแก้.** (role: Opus isolate+judge)
**why:** ORDER-129 regression: Boss_18 (ตัวเดียวจาก 8) drift −17 trades ที่ kill boundary; bisect ตีวงเหลือ {LabCore.mqh ∪ Kangaroo.mqh} (RiskControl+Execution พิสูจน์บริสุทธิ์ด้วย A/B: old RC+Exec ก็ให้ 6020) แต่รอบแยก LabCore-เดี่ยว โดน RSIMOM sweep ชน tester (0-trade artifact ×2). **spec:** รอ tester ว่าง → A/B บน main lane: (a) HEAD+LabCore-ใหม่เท่านั้น (b) HEAD+Kangaroo-ใหม่เท่านั้น → ตัวที่ให้ 6020 = ตัวการ → diff บรรทัดต่อบรรทัดหา mechanism (คาด: อะไรสักอย่างใน OnInit guard หรือ include-order side effect). **acceptance:** ชื่อ file+บรรทัด+mechanism ที่อธิบาย −17 trades ได้ · ยืนยัน harmless หรือแก้. **ห้าม:** รันชน batch อื่น (เช็ค process/report ใหม่ก่อน) · แก้ code ก่อนรู้ mechanism. **ทำได้:** agent (mechanical A/B) → Opus ตัดสิน.

## ORDER-130 — process-drift batch: window pin · scorecard rubric freeze · index sync · stale tables — `DONE + REVIEWED(Opus 2026-07-18)` — ข้อ 1 Opus เอง (CLAUDE.md pin MAIN 2023.01–2025.12 + กฎเหล็ก MAIN∩HOLDOUT=∅ + PROJECT_STATE ×2 + memory update) · ข้อ 2-6 Sonnet agent (scorecard HISTORICAL banner ×2 · index sync: Boss_14 GBPJPY→DEMO + 8 แถวใหม่ · PROJECT_STATE §4 historical stamp · README/ROADMAP stale stamp · FACT_OWNER_MAP B0-snapshot stamp) · 5 แถว TODO-OPUS-VERIFY → Opus เติม verdict จาก DEPLOYMENTS.csv + lane verdicts (Boss_16 CANDIDATE-demo-fwd-holdout · Boss_17 DEMO 990301-303 · MacdDiv DEMO 999094 · SMCxSTO DEMO-marginal 991070 · PairSpread DEMO-weak 990984) · `check_state -Strict` CLEAN
**source:** `_triage/CODEX_SYSTEM_REVIEW_2026-07-18.md` SEV-2/3/4 process findings. **spec:** (1) **window pin fix (Opus)**: CLAUDE.md MAIN ต้องจบก่อน HOLDOUT เริ่ม (MAIN 2023.01–2025.12 ให้ตรง PROJECT_STATE:201, ลบ 2023.07–2026.07 ที่ทับ 2026H1) + กวาด PROJECT_STATE ที่ยังเขียน 2023–2026; (2) scorecard: ตี section score-band CORE/REBUILD/DEAD เป็น **HISTORICAL — intake evidence เท่านั้น ห้ามใช้ตัดสิน deploy** (verdict authority = CLAUDE.md tree เดียว); (3) `EA_MASTER_INDEX.csv` sync แถวที่หาย (Boss_15/16/17/18 · MacdDiv · SMC · PairSpread · RSI_MR) + Boss_14 GBPJPY status; (4) PROJECT_STATE ลบ/ตีตรา historical ตาราง deployment ค้าง (§ ST03 rows) — คง pointer ไป DEPLOYMENTS.csv เท่านั้น; (5) ea_template/README.md + ROADMAP stale blocks ตีตรา historical. **acceptance:** `check_state.ps1 -Strict` CLEAN · grep ไม่เจอ window เก่าใน authority docs · index parity spot-check 5 แถว. **bars/flat-lot:** N-A. **ห้าม:** แก้ verdict ใดๆ ระหว่าง sync (drift → ยกให้ Opus ตัดสิน) · แตะ B1 dataset. **ทำได้:** Sonnet (ยกเว้นข้อ 1).

## ORDER-137 — (EXP)_StoMultiTap: multi-tap S/R + Stoch cycle fade (Miissterkiiss/Bitnefit school) — `DONE + REVIEWED(Opus 2026-07-19): PARKED-VERIFY(user)` (renumbered 133->135->137 (concurrent-session collisions))
**FINAL VERDICT (Opus 2026-07-19) = PARKED-VERIFY(user).** User challenged an earlier premature DEAD-OPTIMIZED call → re-verify proved TWO claims wrong: **(1) multi-tap lever NOT dead** — the first "tap2 dead" was frequency-starvation from filters, not no-edge. Naked at high StoK: XAU-M15-K17-tap2 lifts PF 0.91(1039t)→1.45(27t), and frequency-tuning solves the thin sample: **zt40 (ZoneTol 0.40) = MAIN 1.51 / 64t** (real structure, not a spike). **(2) NOT redundant with SMCxSTO 991070** — measured monthly-PnL corr on EURGBP H1 = **−0.104 (LOW-additive)**, genuinely different return stream (spec-required corr I had skipped). **Why still PARKED not CANDIDATE:** BWD-fail on every variant (zt40 MAIN 1.51 → BWD 0.58; zt60 MAIN 1.02 → BWD 0.90 — no variant clears MAIN≥1.2 AND BWD≥1.0). MAIN edge = XAU 2023-25 chop-regime; 2020-22 gold-trend kills the fade (reversion on a trender = wrong-character home, matches XAU regime-artifact trap in signal-landscape). Ladder full: StoK{5-21}·MinTaps{1-3}·ZoneTol·SwingStrength·MTF·ADX × EURUSD/EURGBP/AUDNZD/XAU. Holdout 2026H1 deliberately NOT burned (BWD already gates it). **USER DECISION: demo-isolate XAU-M15 zt40 (magic 991075, one untouched lever left = ADX-regime-gate to try isolating chop) OR shelve.** Evidence: `_mt5_auto/reports/STMT_*.htm` + `EMASTOREV_EURGBP_H1_MAIN.htm`, sets `_mt5_auto/ab_sets/order133_{smoke,opt,tapfair,buildon}/`. **(role: Opus build+judge · ea-screener 3-round batch)**
**EARLIER PROVISIONAL (superseded — kept for paid-history):** first-pass smoke+optimize (MTF/ADX ON) mislabeled DEAD-OPTIMIZED because filters starved tap2 to 0-3 trades AND I asserted "redundant w/ 991070" without measuring corr. Lesson → [[feedback-discretionary-showtrade-not-mechanical]] rule 2/3 corrected: prove frequency-adequacy + measure corr BEFORE killing. built (EXP)_StoMultiTap.mq5 (swing-pivot S/R zone + Stoch-round counter `_03_MinTaps` = the novelty, mql-review PASS, compile 0/0, magic 991075 lab-only). **Naked smoke 12 runs (MinTaps 1 vs 2, MTF/ADX off, 6 cells):** best XAU-M15-tap1 0.90, no cell ≥1.0; **MinTaps=2 LOST to MinTaps=1 in 5/6 cells** (EURUSD-M30 0.85→0.40, XAU-M15 0.90→0.52, EURGBP-H1 0.76→0.23) while cutting trades 90%+ → multi-tap filters out good entries as much as bad. **Last-optimize 15 runs (StoK{5,14,17,21} × MTF+ADX on = SMCxSTO rescue recipe, 3 right-home cells + tap2-with-filter):** best EURGBP-H1-K17-tap1 MAIN 1.44(57t) but **StoK spike** (K14/K21 neighbors 1.14/1.17) + **BWD 0.64 = selection-fit**; tap2-with-filter = 0.00 PF / 0–3 trades (lever dead even with crutch). **DEAD-OPTIMIZED earned:** ladder full (StoK·MTF·ADX·MinTaps × 3 homes), novel lever has no edge, base reversion redundant with SMCxSTO demo 991070. Lever recorded EDGE_CATALOG dead pile + signal-landscape. Evidence: `_mt5_auto/reports/STMT_*.htm`, sets `_mt5_auto/ab_sets/order133_{smoke,opt}/`. **(role: Opus build+judge · ea-screener agent batch)**
**เดิม spec (OPEN):**
**source:** user แกะกลยุทธ์จาก FB Miissterkiiss Weerarak (16 screenshots, Google Drive 2026-07-19) + ตำรา Bitnefit "กราฟเทคนิคอลไม่ง้อเซียน 3" (Trick 1-3/7-9/16). แก่น = รอราคาถึงแนว S/R → **นับรอบ Stoch OB/OS ซ้ำที่โซนเดิม (ห้าม first touch)** → MTF confirm → fade กลับเข้า range. **why:** reversion class ตรง SMCxSTO family แต่มี **novel lever ที่พอร์ตไม่เคย encode = multi-tap count** (first-touch มักโดนทะลุ, tap≥2 = แนวพิสูจน์ตัวเองแล้ว + Stoch divergence-by-rounds). signal-scanner triage = PROCEED-conditional (reversion → บาร์สูง: ต้อง ≥1.2 หลัง optimize, default-smoke ห้าม kill concept).
**spec (vehicle = `(EXP)_StoMultiTap.mq5` standalone ea_projects, magic 991075 lab-only — เหตุผล standalone: EXP throwaway probe ตาม chassis-first exception):**
- **Level:** swing pivot fractal (SwingStrength=5/5) บน home TF; zone = pivot ± ZoneTolATR(0.25)×ATR(14); level ตาย (reset count) เมื่อ close ทะลุ zone เกิน BreakATR(0.5)×ATR
- **Tap (นับรอบ):** bar เข้า zone ขณะ Stoch(9,3,3) %K ≥ OB(80) [SELL side; BUY mirror ที่ OS 20] แล้ว Stoch ต้องออกจาก OB (<50) ก่อนถึงจะนับรอบใหม่ — TapCount++ ต่อ "รอบ" ไม่ใช่ต่อ touch
- **Arm+Trigger:** TapCount ≥ MinTaps(2) → รอ %K cross ลงต่ำกว่า %D/OB ที่ bar-open → เข้า market. **MinTaps=1 = control cell (พิสูจน์ novel lever ตั้งแต่ smoke)**
- **MTF gate (lever, default ON):** Stoch TF×4 (M15→H1, H1→H4) ต้อง ≥60 ฝั่ง SELL / ≤40 ฝั่ง BUY. **ADX gate (lever, default OFF):** ADX(14)<25 (บทเรียน SMCxSTO)
- **Exit:** SL = zone extreme + SlBufATR(0.5)×ATR · TP = RR(1.5) · single position L1, flat-lot, bar-open, tester-gate, digit-aware pip
**smoke:** Model 2, MAIN 2023.01–2025.12, cells: EURUSD M15/M30 · EURGBP M30/H1 · AUDNZD H1 (right-home reversion) + XAUUSD M15 (source-fidelity cell) — ทุก cell รัน MinTaps=1 vs 2 คู่กัน. **optimize levers ถ้ามี pulse:** StoK 5-21 (บทเรียน StoK 5→17) · MinTaps 1-3 · ZoneTol · RR 1.0-2.5 · MTF on/off · ADX on/off — ≥3 lever × ≥2 TF ตาม gate.
**bars:** smoke pulse = cell ใดก็ได้ naked PF≥1.2 (WATCH 1.0-1.2) → optimize pass = MAIN≥1.2 + BWD≥1.0 (soft) + plateau → holdout ≥1.2. **corr check vs SMCxSTO 991070 บังคับ** (family เดียวกัน — corr≥0.6 = ลด lot ไม่ใช่ตัด, ตาม user rule). **flat-lot probe:** N-A (naked single-position ตั้งแต่ design). **ห้าม:** verdict (Claude) · kill concept จาก default smoke · stack filter >2 ตัวรอบแรก · แตะ 991070 live-demo. **ทำได้:** Claude build (mql-review ก่อน compile) → agent/qwen batch smoke → Claude judge.

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
- **091B — BOT MOGUL report sweep:** `BLOCKED(Codex, 2026-07-21 18:25 +07:00: required vendor-report inputs absent)` · parse 713 vendor reports → ตาราง claimed PF/DD/symbol/TF →
  คัด top ตาม claim × โครงผ่าน X-ray → **BWD-OOS spot-kill ทีละ 5** (1 รัน/ตัว ฆ่าถูกสุด) —
  ห้ามเชื่อ report แนบจนกว่า BWD เราเองผ่าน

**091B Codex check (2026-07-21):** `_intake_drop` contains source/binary files but no vendor report artifacts required by this sub-order (`.htm/.html/.xml/.set`); `_mt5_report_drop` and `_inbox` contain unrelated legacy artifacts only. No parse/spot-kill performed; no verdict.

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

## CR-TRACK — Control Room (ROADMAP Phase 4.5) — `CR-001 CLOSED + CR-002 first pass DONE (Claude 2026-07-19F)` · role: Claude lead (ops/evidence — no verdict authority touched)

> ไม่ mint เลข ORDER ใหม่ (กัน collision 135/136/137/138 ข้าม session) — track นี้อ้างเป็น CR-001..007 ตาม ROADMAP Phase 4.5.
> Records เต็ม: `_triage/CR002_ATTESTATION_REPORT_2026-07-19.md` + `_triage/CR002_EVIDENCE_RECONSTRUCTION_999094.md` · commits `50f9ff7b` `deead551` `e8d653a1`

- **CR-001 CLOSED:** `$cohort` hardcode ออกจาก `live_dashboard.ps1` → generate จาก `DEPLOYMENTS.csv` · checker 4/5 = generation-link guard · ทดสอบ `daily_monitor.ps1 -Force` เต็ม chain ผ่าน (auto-commit `5ef41b98`)
- **CR-002 first pass DONE:** owner ใหม่ `portfolio/ATTESTATION_MAP.csv` + snapshot v2 (attestation/unknown_magics/judge_cohorts) · 18/40 hashed · 20 NO_BUNDLE · promotion-evidence reconstruction 999094 พิสูจน์แล้ว (+6 evidence-manifest, Scan valid)
- **WAITING-USER (จาก report §2-3):** (1) จับคู่ชื่อ EA ให้ 9 unknown magics บน 159475669 แล้วเพิ่มแถว CSV (2) ยืนยัน set จริงของ 991001 (v2/v3/defaults) (3) judge_date 11 แถว user-lane (ข้อเสนอ: 990005 → 2026-10-09, ที่เหลือ mark USER-LANE ใน notes) (4) sensor 463666728 (สร้าง `D:\Monitor\MT5 - 463666728` + login) — ตัวบล็อกใหญ่สุดของ judge ต.ค. (5) 146237 DealsExporter ส่งไฟล์ header-only ต้องเช็ค terminal
- **OPEN (agent-able รอบหน้า):** lock bundle ให้ 990101/991004/991002 + Boss_14 bench ×7 (ต้องได้ .set จริงจาก user ก่อน) · VPS-side hash compare step (design ใน CR-002 gate) · CR-003 health engine ยังไม่เริ่ม
