# PROJECT_STATE — EA_LAB single living state (👉 AI START HERE)

> **last updated:** 2026-07-24D (Opus — **ORDER-136 Wave 2 → BUILD-ON + ORDER-197 NOT-ADOPTED, จาก on-return triage:** เริ่มจาก user ถาม "มีงานอะไรต้องทำต่อ" → review taskboard → ปิด 2 verdict. **ORDER-197 (fxDreema MM-parts retrofit):** Fibonacci lot lever (LotProg=56) แพ้ PROG_LOG_POWER เดิมบน Boss_14 XAU MAIN → NOT-ADOPTED, ปิด campaign B1/B3 retrofit สำหรับ leg นี้. **ORDER-136 Wave 2 (escalation overlay):** user ท้วง 2 ครั้ง**ถูกทั้งคู่** พลิกผลกลับ — (1) "BWD<1 อย่าเพิ่งฆ่า" → เจอว่า Wave2 เดิมเทส .set ผิด (dist=3.0 แต่ config live จริง 990208 = dist=2.0); รันใหม่ถูก config → **LOG13 escalation ชนะ flat จริงบน BWD real-tick (PF 1.32 vs 1.07, eqDD ต่ำกว่า 8.08% vs 10.71% ทั้งที่ lot ไต่) = campaign's first win → BUILD-ON, keep LotProg=55 อย่า revert flat** (2) "พื้นที่อยู่ D ลบ cache C ไม่ช่วย" → trace junction chain เจอ data folder จริงอยู่ D: (`9CA16B` bases 28.5GB, 112GB free) ส่วน C: `9CA16B` = stub เปล่า; MT5 error "no disk space in ticks generating function" = **memory/pagefile commit ceiling ไม่ใช่ disk** (RAM 4GB free/32, pagefile+TEMP บน C ตึง) → MAIN Model-4 blocked แต่ non-load-bearing, ปิด BUILD-ON ด้วย evidence ที่มี. **Campaign ยังเปิด** (Wave3+ = MacdDiv/EmaStoRev/PivotBreakout ต้อง port entry เข้า chassis ก่อน = build task, รอ user). บทเรียน 3 memory ใหม่: `mt5-no-disk-space-is-memory-ceiling` · `escalation-overlay-needs-strong-bwd-host` · `feedback-verify-set-matches-live-before-verdict`. commits `32f32402`(197)+`29e3e0a1`(136) + trail. handoff `_triage/HANDOFF_2026-07-24D_ORDER136_WAVE2_BUILDON.md`. ⚠️ session คู่ขนาน (Sonnet 192b/195/196 + CR-track) active วันเดียวกัน — commit ปนกันบน shared taskboard, เช็ค git log ก่อนต่อ) · ก่อนหน้า: 2026-07-24C (Fable — **EA Template money/safety hardening เต็มรอบ (Codex review → fix → Codex re-review → fix, จบด้วย judge-readiness re-run) — commits `f5c093f`→`6eeed41` (~16 ก้อน):** user ส่ง Codex review ของ `FirstLotMode=43` (balance-scaled) มาให้รีวิวซ้ำ+วางแผน กลายเป็น hardening cycle เต็มวัน. **ORDER-187:** เลิก silent lot-mode fallback (config ใช้ไม่ได้ = INIT_FAILED ที่ OnInit, runtime พลาด = ข้ามไม้ ไม่ถอยไป `_41_FixedLot`) + Wave5 naked-order guard (structural SL re-validate ไม่ผ่าน = skip ไม่เปิด naked) + guard G4 บังคับจริง (เดิมแค่คอมเมนต์). **ORDER-188:** `mm_lotmode_test.ps1` positive-path cage ใหม่ (11 เคส, cage เดิมพิสูจน์ได้แค่ "ของใหม่ปิดอยู่ไม่กระทบเก่า" ไม่ใช่ "เปิดแล้วถูก") — เจอแถม: fixed-lot ตายที่ DD25% ไม้ 115/164 ส่วน balance-scaled หด lot เองจบครบ 164/164. **ORDER-189:** registry 183/183 + guide §3.6 (USD/CENT account profile). **ORDER-190:** `_16_BaseLotMode` ให้ Boss_16 scale ตาม balance ได้ (opt-in, default off) — **แก้ acceptance bar เดิมที่เขียนผิดเอง** (A/B PF วัด compounding ไม่ใช่ edge, ขัดกฎ repo เอง). **ORDER-194/194b/194c: hard-kill re-fire bug ที่เจอเอง** (halt แล้วยิงซ้ำทุก tick ตลอด run, log 777MB/ไฟล์) — **Codex 2 รอบจับว่าซ่อมไม่ครบ 2 จุด + ผมสร้างบั๊กใหม่ 1 จุด** (retry ติดหลัง sweep ไม่มีวันรัน, dirty-flag ไม่ reset ข้าม OnInit, SLMode check ยิงผิดตอน Wave5 struct SL เป็นแหล่งจริง) แก้ครบทุกรอบพร้อม cage CLEAN 8/8. **ORDER-191/192/193/195/196 (tooling):** registry line-fixer (พบบั๊กตัวเอง `$Matches` ถูกทับ, แก้แล้ว) + `PARAM_LINKAGE.md`(11 override pairs, 9 silent) + `[CFG]` effective-config summary (ครอบครบ 11/11 pair แล้ว) + **`optimize_guard.ps1`** (19/184 param never-optimizable — ทดลองยิงคลัง .ini จริง 67 ไฟล์: REFUSE 19, เจอ 16 ไฟล์แคมเปญ O133 กวาด `_9_MaxLevels` ชน ENGINE-EDGE doctrine ตรงๆ) + truncated-run detector (`check_truncated_run.ps1`) — retro-scan 4,233 รายงาน → SUSPECT 141 → กรอง account-blowup ออกเหลือ 65 จริง → 7 ถูกอ้าง verdict จริง (รอบแรกนับผิด 10 เพราะไม่ exclude entry ที่เขียนเอง) → 3 นั่งเพดาน kill → **ตรวจครบ = กระทบ verdict 0 ใบ** (BOSS14_XAU_OOS_M1 rerun ×10 deposit ยืนยัน PF 1.13≈1.15 เดิม) + V1 chassis (`EA_LabTemplate.mq5`+`modules/`) ประกาศเลิกใช้ (ตายจริง 0 deployment/report/.set, banner comment-only ไม่ลบไฟล์). **ปิดท้าย: Control Room judge-readiness re-run (read-only)** แทนที่เลขเก่า "3/38" — fleet 56 ACTIVE, 6 decision-capable, forecast 6-capable/**18-shortfall**, 4 no-sensor, **account 463666728 sensor STALE + ถือ shortfall EA เยอะสุด**, unknown magic 6 ตัวไม่มีทะเบียน. **บทเรียนกระบวนการ:** Codex CLI เรียกตรงได้ผลจริง (subagent รายงานผิดว่าไม่ได้ติดตั้ง) · retro-audit ต้อง exclude งานเขียนตัวเอง (ค้นบน commit ก่อน session) · heuristic ที่เพิ่งเขียนต้องยืนยันด้วย rerun ไม่ใช่เชื่อทันที (detector ตัวเองเตือนผิด 1 เคส) · index.lock ค้างต้องเช็ค process ก่อนลบเสมอ (เจอ Codex Desktop hash-object ไม่ถือ lock จริง). **งานคู่ขนานที่เห็นแต่ยังไม่ตรวจเอง:** ORDER-197 (Fib lot lever NOT ADOPTED) + ORDER-136 Wave2 verdict RETRACTED. **ค้าง:** บังคับ optimize_guard ใน pipeline จริงไหม (decision) · 18 shortfall EA ตัดสินใจทาง (RSI-MR precedent/ขยาย judge/ปล่อยตก) · sensor 463666728 · unknown magic 6 ตัว. handoff เต็ม `_triage/HANDOFF_2026-07-24C_TEMPLATE_HARDENING_AND_JUDGE_READINESS.md`) · ก่อนหน้า: 2026-07-24B (Opus — **taskboard archive maintenance: ย้าย 52 REVIEWED orders เข้าคลัง, `AGENT_TASKBOARD.md` 604K→268K (commit `a0c06c8`)** — งาน housekeeping ล้วน ไม่แตะ verdict/EA/DEPLOYMENTS/scorecard. user ถามว่าบอร์ดบวมไหม ย้ายได้ไหม ต้องระวังอะไร + ให้รีวิว PROJECT_STATE ว่าควรลดขนาดไหม. **กติกาที่ค้นเจอและต้องจำ:** ย้ายเข้าคลังได้ **เฉพาะ order สถานะ `REVIEWED*`** (self-attesting — reviewer+date ฝังในคำกริยาแล้ว) · ใบที่เป็น `DONE`/`CLOSED` เปล่า **ย้ายไม่ได้** เพราะ validator ต้องการ `## REVIEW ORDER-x` คู่กัน ไม่งั้นจุด `terminal-no-linked-review` (ต้องทำ C1-CLOSURE ก่อน) · header ที่มี pending-stage marker นอก backtick ("Stage 3 = รอ...") = non-terminal แม้กริยาใน backtick จะ terminal · archive อยู่ใต้ contract **append-only ORDER-103** (raw-byte prefix-extension + suffix ต้องเปิดด้วย `## `). **ผลตรวจ:** 52/52 บล็อกที่ย้ายกู้คืน byte-identical ในคลัง · 68/68 บล็อกที่เหลือไม่ถูกแตะแม้แต่ byte เดียว · `check_taskboard_archive.ps1 -Strict` หลัง commit = exit 0 (chain integrity clean · append-only clean · 0 unresolved exception · 0 integrity failure · manifest/index/exceptions zero-diff) · เหลือ **63 order** บนบอร์ด (OPEN/CLAIMED/WAITING-USER/CAMPAIGN + ใบ DONE/CLOSED ที่ยังย้ายไม่ได้) + บรรทัดชี้ทางบนบอร์ดระบุครบว่าย้ายเลขไหนไปบ้าง. **แก้ hook 1 จุด (user เคาะเลือกทางนี้แทน `--no-verify`):** presence-check ของ `scripts/check_precommit_staged.ps1` บังคับ stage ครบ 3 artifact เมื่อ archive เปลี่ยน แต่ REVIEWED-only append **ไม่ก่อ exception ใหม่** → `RECONCILE_EXCEPTIONS.md` byte-identical, git stage ไม่ได้ = false-block ตายตัว. เปลี่ยนเป็น NOTE แล้วให้ content-consistency check (staged blob vs fresh `-Generate`) เป็นด่านตัดสินแทน — **ยังบล็อก artifact ที่ stale จริงเหมือนเดิม** ไม่ได้ลดความเข้มงวด. **gotcha ที่เสียเวลาที่สุด:** `-Generate` **ใช้ไม่ได้ตอน archive ยังไม่ commit** เพราะฝัง `archive_blob_sha` จาก `HEAD:path` (= archive เก่า) ขณะที่ pre-commit เทียบกับ staged identity → mismatch เสมอ; ต้อง generate เองจาก `Get-Snapshot -Mode Staged` แล้วส่ง `$stagedArchive.Identity` เข้า `New-ArchiveManifestRows`/`Build-ArchiveIndexMarkdown` (เลียนแบบ hook lines 293-299). **⚠️ รอบแรกล้มทั้งชุด:** session คู่ขนานแก้+commit `AGENT_TASKBOARD.md` ระหว่างทาง (HEAD ขยับ 6 ก้อน, คว้า `index.lock` สลับไปมาไม่หยุด) แล้ว**เขียนทับ active board เวอร์ชันผม** เหลือ archive ค้าง +52 = half-state (52 order จะซ้ำทั้งสองไฟล์) → **restore ทิ้งทั้งชุดกลับ HEAD สะอาด** ไม่ปล่อยให้หลุด commit แล้วเริ่มใหม่ตอนนิ่ง (รอบสองผ่านฉลุย). **งานนี้ต้องทำตอนไม่มี session อื่น active เท่านั้น** — ตรงกับ directive user เรื่อง single-session. **PROJECT_STATE ตรวจแล้ว = ไม่บวม ไม่ต้องลดขนาด:** 384 บรรทัด / ~52K ตัวอักษรจริง (ที่เห็น 105KB เพราะไทยกิน 3 bytes/ตัว) โครงยังดี · §3 Decision log 23K ใหญ่สุดแต่ lock ห้ามรื้อ ลดไม่คุ้มความเสี่ยง. memory `taskboard-archive-move-rules` บันทึกกติกา+ขั้นตอน+gotcha ครบแล้วสำหรับรอบหน้า) · ก่อนหน้า: 2026-07-24A (Opus — **RSI-MR (990103) full re-optimize funnel + demo-isolate attach — ORDER-182→186, commits `3242a91`→`a2842d3` (~10 ก้อน):** session เต็มไปกับ EA ตัวเดียวตามคำขอ user ("ทำเลย"/"ทำต่อเลย" ต่อเนื่องหลายรอบ). **finding methodology สำคัญที่สุด:** WFA เดิม (ORDER-168, 2026-07-23) วัด RSI-MR ด้วย 3 window แยกกัน (equity reset ทุกรอบ) ทั้งที่มันเป็น **basket EA จริง** (dual-side, MaxPositions=8, LOG escalation) — ตรง failure-mode ที่ skill `backtest-optimize-rigor` เตือนไว้ว่า stitched windows หลอกได้ ~10x สำหรับ basket/grid. รัน **continuous single-span ใหม่** (D:\Meta 5b กัน session คู่ขนานที่ใช้ D:\Meta 5) เจอ edge แข็งแรงกว่าที่คิดมาก: both-window plateau เท่ากันเป๊ะ 1.37/1.37 (ORDER-182) → lever sweep (RSI band × SL-width) เจอ config ดีขึ้นทุกมิติ **RSI25/75+SL25+Dist9** MAIN1.96/BWD1.56 (ORDER-183) → sensitivity fan **สะอาดที่สุดของทั้ง session** ทุก 1 ใน 8 variant (รวม frozen spacing axis) ยัง PF>1 ทั้งคู่ ไม่มี flip ลบเลย (ORDER-185) → full MC ผ่าน comfortable bar ทั้ง 2 window (PF-5th 1.544/1.209, ORDER-186). **จุดอ่อนเดียวที่เหลือ = holdout 2026H1 ล้มจริง (0.76/n=21, ไม่ใช่แค่บาง)** ยืนยันซ้ำบน 2 config อิสระว่าเป็น regime feature จริง ไม่ใช่ tuning bug. ระหว่างเตรียม deploy bundle เจอว่า **RSI-MR เคยรันจริงบนบัญชี real 159503454 มาก่อน แล้วถูกถอด 2026-07-18 เพราะโดน DD25% kill trigger** — ข้อมูลนี้พลาดไปตอนแรกที่แนะนำ demo-isolate (เทียบผิดกับ XAGUSD/LondonORB ที่ holdout แค่บางไม่ใช่ล้ม) แก้ไขให้ user ทราบก่อนตัดสินใจ. **user ตัดสินใจ**: เข้าคิว demo (463666728 EURUSDm, PENDING_ATTACH) แล้ว **attach จริงสำเร็จ 2026-07-24** (ยืนยันโดยอ้อมว่าบัญชีเป็น Hedging-mode ตามที่ EA ต้องการ) → ยก ACTIVE, judge 2026-10-24. bundle เต็ม `_vps_deploy/RSI_MR_EURUSD/` (ex5 เดิมไม่แก้โค้ด + .set ใหม่ + README ประวัติเต็ม). **บทเรียนกระบวนการ:** เจอ pre-commit hook ช้าจริง (3-7 นาทีต่อ commit ที่แตะ AGENT_TASKBOARD.md ใหญ่) 2 ครั้งดูเหมือน hang แต่พิสูจน์ว่าเป็น hook ทำงานจริงไม่ใช่ stuck (เช็ค process ก่อนแก้ lock ทุกครั้ง) · เจอ session คู่ขนาน**หลายตัวมาก**ทำงานพร้อมกันทั้งวัน (SS2 NyIgnition/LondonORB/cent-scalp strategies/portfolio_risk_admission ORDER-170 round 9-10/correlation backfill ORDER-184) — commit หนึ่งของผมถูก sweep เข้าคอมมิทของ session อื่นไปเฉยๆ (ไม่มีข้อมูลหาย แค่ attribution ปนกัน, ตรวจด้วย `git show HEAD:<file>` ยืนยันเนื้อหาถูกต้อง). **ค้างสำหรับ session ถัดไป:** ไม่มีงาน optimize ค้างสำหรับ RSI-MR (ครบทุก lever+fan+MC แล้ว จุดเดียวที่เหลือคือรอเวลา/holdout n เพิ่ม) → hand off ให้ `ea-live-monitor` ติดตาม RSI-MR ต่อจากนี้ (จำ: holdout ล้มจริงไม่ใช่บาง อย่าตีความ losing streak แรกเป็นสัญญาณใหม่) · ORDER-170/174 (correlation/risk-admission) ดูจาก commit ล่าสุดว่ามี session อื่นเดินต่อจนปิดแล้วระหว่างวัน (ORDER-184 corr backfill 27/28 magic) — ยังไม่ได้ตรวจ verdict/รายละเอียดเอง ควรอ่านก่อนอ้างอิง. handoff เต็ม `_triage/HANDOFF_2026-07-24A_RSIMR_FUNNEL_AND_ATTACH.md`) · ก่อนหน้า: 2026-07-23F (Opus — **session close: portfolio_risk_admission.py build→2 audit rounds→still open (ORDER-154/170/174), systems backlog ORDER-152-174, context full, handoff written — งานคนละสายกับ 23E (TrendRider/SS4) ที่ทำขนานกันวันเดียวกัน:** เริ่มจาก review workplan Codex เสนอ → เคลียร์ ROADMAP §3 backlog (ORDER-152 เป็นต้นไป, ไม่ใช่งาน verdict) → **ระหว่างทางเจอ MT5 tester input-cache + leverage bug ร่วมกับ session 23D** (root cause เดียวกัน คนละเส้นทางค้นพบ, cross-validate กันเอง) → เวลาที่เหลือส่วนใหญ่ไปกับสร้างเครื่องมือ `scripts/portfolio_risk_admission.py` (ORDER-154, attach-time portfolio DD budget) แล้วส่ง **Codex blind audit 2 รอบ ทั้งคู่เจอบั๊กจริง** — รอบ 1 เจอ SEV-1 5 ข้อ (basket double-count, DD95=0/inf ผ่าน, bounds guard bypass, broker-min placeholder, corrupt P&L กลายเป็น 0) แก้แล้ว(`2a5fdcc`) → รอบ 2 (user รัน Codex CLI เองหลัง Agent-tool dispatch หลุดไม่รายงาน 2 ครั้ง, model `gpt-5.6-sol`) **เจอ SEV-1 ใหม่อีก 3 ข้อ** รวมบั๊กที่ผมสร้างเองตอนแก้รอบแรก (basket_id/magic namespace ชนกันได้) — **ORDER-170 ยัง OPEN ไม่ปิด ต้องแก้ต่อ+audit รอบ 3** (`_triage/CODEX_ORDER170_RISK_ADMISSION_REAUDIT.md`). ระหว่างทางเปิด **ORDER-174**: DD95 backfill (17/48 magic, ORDER-159 ต่อ) ทำให้ตัวเลข portfolio พุ่ง 61%→87%/56% แต่ตรวจแล้วพบว่า **corr ทุกคู่ตกไป default 1.0 หมด** เพราะ live_deals มีแค่ ~1 เดือน (ต้องการ 4 เดือนขั้นต่ำ) ทั้งที่ design เดิมของ ORDER-154 ระบุให้ใช้ backtest correlation (`corr_monthly.py`) ซึ่ง implementation ไม่ได้ทำตาม — ตัวเลขปัจจุบัน (87.39%/56.20%) = **เพดาน ไม่ใช่ค่าจริง ห้ามใช้ตัดสินใจ**. **งานอื่นที่ปิดจบวันนี้:** AGENTS.md Codex-routing doctrine sync กับ Decision log 07-16 · 177-param registry + dependency-audit clean (ORDER-163/164) · judge criteria 4 แหล่งขัดกัน → skill `ea-live-monitor` เลิกฝังเลขเอง อ่านจาก canonical แทน (ORDER-169/173, เลขชนกับ session คู่ขนานอีกรอบ) · Recovery-mode "(stub)" label ผิดข้อเท็จจริงแก้แล้ว (ORDER-158/160) · multi-account combiner + walk-forward tool + doc B-list ปิดครบ. **บทเรียนกระบวนการ (สำคัญพอๆ กับงาน):** git index race เกิดจริง 3 ครั้ง (commit หลุด message/เนื้อหาไม่ตรงกัน 2 ครั้ง, sweep ไฟล์ session อื่นเข้ามา 1 ครั้ง — ไม่มีข้อมูลหาย แต่ต้องเช็ค `git diff --cached --stat` ก่อน commit ทุกครั้งไม่ใช่แค่หลัง `git add`) · order-number collision กับ session คู่ขนาน 2+ ครั้ง · `check_state.ps1` false-positive ตัวเดิมโดนซ้ำ 3 ครั้ง (needle "ไฟล์เดียว" ชนกับ prose ธรรมดา) · agent หลุด background-wait ไม่รายงาน 3+ ครั้ง (memory `subagent-no-background-wait` อัปเดตแล้ว) · **Codex audit ผ่าน Agent-tool dispatch ไม่เสถียร (หลุด 2 ครั้ง) — user รันตรงผ่าน Codex CLI ได้ผลจริงทันที**. commits `c6d431f`→`575e6be` (~16 ก้อน) · handoff เต็ม `_triage/HANDOFF_2026-07-23E_SYSTEMS_BACKLOG_AND_RISK_TOOL.md`. **ค้างสำหรับ session ถัดไป:** ORDER-170 แก้ 3 SEV-1 ที่เหลือ+audit รอบ 3 (ก่อน) → ORDER-174 ต่อ corr จาก backtest (หลัง, แตะไฟล์เดียวกัน) → DD95 backfill ส่วนที่เหลือ) · ก่อนหน้า: 2026-07-23E (Opus — **TrendRider XAGUSD funnel essentially completed (ORDER-180/181) + SS4 EURUSD last-optimize closed (ORDER-173) — both continuations of 23D's re-validate work:** XAGUSD H4 (สายพันธุ์ของ 992004) เดิม BUILD-ON แล้วตก BWD (0.97) บน center ที่ยืมจาก XAU — optimize เฉพาะ silver จริงเจอ plateau ที่ **AdxMin=25** (BWD ผ่านทั้ง 3 SepAtr พร้อมกัน, ตรงข้ามกับ AdxMin20 ที่ยืมมาซึ่งตกทุกจุด) ไล่ทิศทางจนล็อก **AdxMin=30/Sep=0.5/Ch=2.5** — both-window MAIN 2.10/BWD 1.49, M4 confirm ตรงเป๊ะ, MC PF-5th 1.266 ruin 0%, sensitivity fan ผ่าน (Sep แบนราบ, Ch เป็นเทรนด์ทางเดียวไม่ตาย), **corr vs XAU sibling 992004 = -0.244 และ vs Boss_14 XAU leg 990207 = 0.236 (ทั้งคู่ต่ำ ไม่มี concentration risk แม้เป็นโลหะเหมือนกัน)**. จุดอ่อนเดียวที่เหลือ = holdout n=7 บาง (ไม่ล้มแต่ไม่มั่นใจเต็ม) → **BUILD-ON ที่แข็งแรงที่สุดของวันนี้ เหมาะให้ user พิจารณา demo-isolate ได้เลย**. SS4 EURUSD: กวาด SweepAtr×TpAtr ปิด lever สุดท้าย ceiling ยังแค่ 1.06-1.21 ไม่ทะลุ 1.2 มั่นใจ — **ครบทุก lever ที่มีแล้วจริง (last-optimize เสร็จสมบูรณ์)** คง PARKED-VERIFY. **⚠️ เจอ order-number collision กับ session คู่ขนาน 2 ครั้งเพิ่มเติมวันนี้** (ORDER-171 ชนกับ MacroGate investigation ของเขา, ORDER-174 ชนซ้ำกับ risk-admission fix ของเขา) — renumber ของผมเป็น 173/180/181 ตาม precedent เดิมทั้งคู่ เนื้อหาไม่กระทบ, กระโดดเลขให้มี buffer เพราะชนถี่ผิดปกติวันนี้ (2 session ทำงานหนักพร้อมกันบน taskboard เดียว). commits `8115811`→`41b8a2d2` (3 ก้อนเพิ่มจาก 23D). check_state -Strict CLEAN. **ค้าง (ไม่เร่งด่วน):** RSI-MR full re-optimize ถ้าจะดัน CANDIDATE · CR-002 lock bundle รอ user เติม .set จาก VPS · ORDER-091B/142(สอง) BLOCKED รอ user · ถ้า user อยากดัน XAGUSD เป็น CANDIDATE เต็มตัว ต้องขยาย holdout ให้ n มากกว่า 7) · ก่อนหน้า: 2026-07-23D (Opus — **MT5 tester nondeterminism root-caused + fixed (ORDER-162/165), NOT engine drift — highest-value finding this week:** สอง session อิสระเจอ backtest reproduce ไม่ได้คนละทาง (ผม: regression cage 8/8 drift · อีก session: RSI-MR fold2 PF 1.74→1.08) — user สั่ง "ตรวจสอบซ้ำให้เคลียร์" 2 รอบ, รอบแรกสรุปผิดว่าเป็น "engine drift" แล้วโดนหักล้างด้วยการทดลองจริง (falsification test: single-position EA ไม่เพี้ยนข้าม lane, grid EA เพี้ยน 53x). **root cause จริง = สอง silent no-op ใน MT5 build 5836:** (1) `[TesterInputs]` override เฉพาะ input ที่ระบุ ที่เหลือมาจาก per-terminal cache `MQL5\Profiles\Tester\<EA>.set` (ค่าล่าสุดที่ session ไหนก็ตามเคยรันทับไว้) — cage เดิมรัน 6/8 EA ไม่มี set เลย = ไม่เคย deterministic ตั้งแต่ต้น (2) `Leverage=100` (เลขเปล่า) = no-op เงียบ ต้อง format `1:N`. แก้ `mt5_run.ps1` (leverage 1:N + assertion exit-3 ถ้าไม่ตรง + WARN ถ้าไม่มี -SetFile) + capture full compiled-default sets ทั้ง 8 Boss EA + re-pin baseline → **พิสูจน์ reproducible 8/8 byte-exact**. memory `mt5-tester-cache-nondeterminism` บันทึกข้ามเซสชันแล้ว. **ผลกระทบต่อ evidence เก่า (ORDER-166→169, user อนุมัติ re-validate ทั้งหมด):** RSI-MR (990103, ยังไม่ attach) full WFA re-run = 3/3 OOS ยัง profitable แต่ margin ไม่เท่ากัน (1.30/1.08/2.51) → PARKED-VERIFY ลดความเชื่อมั่นจาก ROBUST-89 · **Boss_14 bench ×8 (ACTIVE demo) full-pin M4 = 5/8 ผ่าน bar, อันดับพลิก** (AUDNZD "champion 3.37" เดิม = อ่อนสุดจริง 1.09, XAU แข็งสุดจริง 1.91) — ไม่ kill ตัวไหน, demo-forward (judge 2026-10-09) ยังตัดสิน · MacdDiv D1-majors ปิดตระกูล (2/2 ตายที่ holdout, resolve ปมตัวเลขไม่ตรง ORDER-117 vs 149 = คนละ config จริง ไม่ใช่ error) · TrendRider expansion 2/3 ตาย, XAGUSD เหลือ BUILD-ON (BWD ตกบน pinned config, ห้าม attach) · SS4 EURUSD coarse grid ceiling ~1.06-1.21 ยังไม่ผ่าน bar (คง PARKED-VERIFY). **แก้ verdict ตัวเองผิด 3 ครั้งระหว่างทางวันนี้** (ORDER-149 เหตุผลผิดทั้งที่ verdict ถูก, ORDER-147 เรียกตายว่า BUILD-ON, ORDER-166 สรุปด่วนจาก 1 datapoint) — ทุกจุดแก้ด้วยการทดลองจริงไม่ใช่อนุมาน, บันทึกไว้ตรงๆใน taskboard ไม่ลบทิ้ง. **งานอื่นเซสชันนี้:** template portable money params + `FIRSTLOT_BALANCE=43` (ORDER-161, user request cent/USD-safe) neutrality พิสูจน์แล้ว · S1 TrendRider attach ยืนยัน 415573666 (ไม่ใช่ 463666728 ที่วางแผนไว้, magic ไม่ชน) · AdaptGridMC = DEAD-STRUCTURAL (static-zone realized-path artifact, 2026H1 holdout พิสูจน์ 0 เทรด) เข้า EDGE_CATALOG เป็นบทเรียนใหม่ (zone-exhaustion dormancy) · parse_htm.ps1 space-thousands-separator bug พบระหว่างทางและแก้แล้ว. commits `738c490`→`20503f4` (8 ก้อน). **ค้าง (ไม่เร่งด่วน):** RSI-MR full re-optimize ถ้าจะดัน CANDIDATE · XAGUSD optimize-for-silver ถ้าจะดัน BUILD-ON · SS4 SweepAtr/TpAtr lever ยังไม่แตะ · CR-002 lock bundle ต้องได้ .set จริงจาก VPS (ค้างจากต้นเซสชัน) · ORDER-091B/142(สอง) BLOCKED รอ user เติมไฟล์/ข้อมูล) · ก่อนหน้า: 2026-07-23C (Sonnet — **ORDER-152(c) doc-retirement B-list ปิดครบ 7/7, งาน housekeeping ล้วน ไม่แตะ verdict/DEPLOYMENTS/scorecard):** ย้าย 7 doc เข้า `_archive_docs/` (`DEPLOY_CHECKLIST_2026-06-29` + 5 one-off analysis + `OPTIMIZE_PROCEDURE_AND_AUDIT`) · ย้าย `docs/RECOVERED_PLATFORM_DESIGN_20260614.md` เข้า archive **หลัง content-check** — ไม่ใช่ "ดูดเข้าที่อื่นแล้ว" แต่ *ถูกแทนที่ด้วยระบบใหม่คนละระบบ* (scoring v1/gate chain = retired vocabulary → VERDICT GATE · Pass 0/1/2/4 → skill LADDER · window เก่า → pinned MAIN/BWD/HOLDOUT · §7 EA table ค้าง GSMC DISQUALIFIED ไปแล้ว) จึงใส่ SUPERSEDED banner ก่อนย้าย · ลบ `portfolio/port_01/` (5 โฟลเดอร์ว่าง) + `_archive_docs/QWEN_RUN_LOG_updated.md` (พิสูจน์แล้วว่าเป็น subset 100% ของ `QWEN_RUN_LOG.md` ไม่มีเนื้อหาหาย) · **`DEPLOYMENT_PLAN.md` ตรวจแล้ว = ไม่ใช่ของซ้ำ เก็บไว้** (คนละเรื่องกับ `DEMO_DEPLOYMENT_PLAN.md` — EA_RUNNER_v1 magic 5001 + GSMC/MatchaGrid basket, มี banner แยก scope อยู่แล้ว) · แก้ path reference ใน `PROJECT_STATE`/`README`/`MASTER_BACKLOG`/`PLATFORM_INDEX`/`_archive_docs/README` · check_state -Strict CLEAN ทุกขั้น · commits `1ac8b56`+`ee8db79`+`1b0ebb9`. **⚠️ เจอนอกสโคป ยังไม่แก้:** `scripts/select_robust_pass.py`+`scripts/score_backtest.py` ยัง implement สูตร BacktestScore v1 ที่ retire แล้ว (docstring อ้างไฟล์ที่เพิ่ง archive) — ยังไม่ตรวจว่ายังถูกเรียกใช้จริงในพายป์ไลน์ไหม = งานแยก. **⚠️ บทเรียน git วันนี้:** shared working tree + หลาย session = index race จริง (commit `52e9fcd` ได้ message ของอีก session, และ `git mv` หลังแก้ไฟล์ทำให้ banner ตกหล่นต้องตามเก็บใน `1b0ebb9`) → ย้ำกฎ: stage แบบ path-limited เสมอ + verify `git show HEAD:<file>` หลัง commit ที่มี rename) · ก่อนหน้า: 2026-07-23B (Opus — **systems backlog tranche (ORDER-152→160, ไม่ใช่งาน verdict EA):** เคลียร์ ROADMAP §3 development backlog + review แผน `EA_CORE_TEMPLATE_WORKPLAN_FOR_CLAUDE.md` (rev-B) ในเซสชันเดียว. **ตัวเลขที่ต้องรู้:** attach-time portfolio risk admission (`scripts/portfolio_risk_admission.py`, ORDER-154) คำนวณ 463666728 (16 EA บนบัญชีเดียว) = **portfolio_DD_est 61.03% เทียบงบ demo 25%** จากข้อมูล DD95 ที่รู้แค่ 6/17 magic (ORDER-159 backfill 4→12/48 แถวรวม) — **เกินงบจริงแม้รู้ไม่ครบ ยังไม่ใช่ verdict แต่ต้องระวังก่อนแปะ EA เพิ่มบนบัญชีนี้**. เจอ+แก้ basket DD95 double-count (IchiADX 990066-9) ระหว่างทาง. multi-account combiner (`portfolio_sim.py --live`, ORDER-156) เจอ net full-history -5,273.97 ต่างจาก LIVE_DASHBOARD +9,532.63 (dashboard ตัด hand-experiment trades ที่ combiner ไม่ตัด — สองเลขถูกคนละคำถาม). walk-forward generalizer (`walkforward.ps1`, ORDER-157) พิสูจน์ assert กัน HOLDOUT-leak ทำงานจริง แต่ **ยังมี discrepancy ที่ไม่ปิด** (RSI-MR fold2-OOS PF 1.74 เดิม vs 1.08 ใหม่ บนเลนรองต่างกัน — ต้อง rerun-confirm บน `D:\Meta 5` ก่อนเชื่อผล). Hedge/Recovery A/B harness (ORDER-158) พบว่าป้าย "(stub)" ของ RecoveryMode 82/83 ใน `Inputs.mqh` ผิดข้อเท็จจริง (โค้ดทำงานจริง เป็น escalation engine ตัวจริง) → แก้ป้ายแล้ว (ORDER-160), sweep 8-cell MAIN-only เดี่ยวโชว์ 82/83 beat flat-lot twin (+0.34/+0.08 PF) แต่**ยังไม่ผ่านกรง ENGINE-EDGE เต็ม ห้ามอ่านเป็นสัญญาณ**. แก้ doctrine ขัดกันเอง 2 จุด (`AGENTS.md` Codex-routing vs Decision log 07-16, `OPTIMIZATION_PROCEDURE_V2.md` verdict vocabulary เก่า) — ดู `AGENTS.md` §5.2. **เจอ order-number collision สดกับ session คู่ขนาน** (ORDER-152 ชนกัน 2 เรื่อง) renumber ให้ session อื่นเป็น ORDER-161 ตาม precedent เดิม, เนื้อหาเขาไม่ถูกแตะ. ถอด worktree ค้าง `great-mendeleev-a35c44` (สะอาด+merge แล้ว). commits `c6d431f`+`733c1db`+`4095ce9`. **ค้าง:** Codex blind audit ของ ORDER-154 (dispatch แล้วยังไม่กลับ) · ORDER-157 rerun-confirm · ~~ORDER-152(c) doc-retirement B-list รอ user เคาะ~~ → **user เคาะแล้ว + ปิดครบ 7/7 (2026-07-23C ด้านล่าง)** · เริ่ม decompose CORE-002+PARAM-001 จาก workplan rev-B เมื่อ user greenlight) · ก่อนหน้า: 2026-07-20A (Fable — **Wave-2 batch night (user-approved pacing override):** ORDER-136 ยืนยันปิดโดย `2cf741d7` ก่อนเริ่ม · **ORDER-139: S1 TrendRider XAU H4 = VALIDATED CANDIDATE demo-ready 992004** — funnel เต็มจบใน session เดียว (plateau 6-cell AdxMin20 · center a20/s0.5/c2.5 MAIN 1.63/BWD 1.03 · holdout 2026H1 1.33/23t **ไหม้แล้ว** · M4 1.61/1.01 retained · MC ruin 0 DD95 4.15 · corr ≤0.32) → bundle `_vps_deploy/W2_S1_TRENDRIDER_XAU` + DEPLOYMENTS PENDING_ATTACH รอ user attach; ⚠️ BWD borderline → demo isolate + ห้ามเป็น DCA-overlay host · SS4 SweepRev = PARKED-VERIFY(user) (MAIN 1.31–1.85 จริง/BWD<1 ทุก healthy-n cell) · ORDER-140 SS1 ORB expand = ไม่มี home ใหม่ (UJ M15 1.14/1.10 + XAU M30 1.13/1.08 = กว้างแต่บาง) คง BUILD-ON · ORDER-141 (EXP)_AdaptGridMC built (compile 0/0 + zone script tested, ยังไม่ backtest — ต่อไป: export D1 CSV จริง → BWD hard-gate) · commits `5f015f1`+`917b21a`) · ก่อนหน้า: 2026-07-19F (Fable — **Control Room track เดินต่อ: CR-001 ปิดสมบูรณ์ + CR-002 รอบแรก + CR-005-lite v2** · CR-001: ถอด `$cohort` hardcode ออกจาก `live_dashboard.ps1` → generate จาก DEPLOYMENTS.csv (checker 4/5 เขียนใหม่เป็น generation-link guard; ทดสอบ daily chain -Force เต็ม ผ่าน) · CR-002: owner ใหม่ `portfolio/ATTESTATION_MAP.csv` + snapshot v2 sections attestation/unknown_magics/judge_cohorts — **ผลรอบแรก: 18/40 magics hashed ครบ · 20 NO_BUNDLE (Boss_14 bench ×7 + เงินจริง 990101/991004/991002) · 991001 set-lineage กำกวม · เจอ 9 magic เทรดจริงบนบัญชีเงินจริง 159475669 ไม่มีแถว registry (20240001 CHFJPY + ตระกูล 800x XAU) = enumeration แถว UNVERIFIED สำเร็จ · 146237 collector file ว่างเปล่า (header-only) · 11 แถวไม่มี judge_date = user-decision list** → รายงาน `_triage/CR002_ATTESTATION_REPORT_2026-07-19.md` · promotion-evidence reconstruction พิสูจน์แล้ว 1 candidate (999094 MacdDiv: chain ครบ source→set→M4 reports→verdict→approval, +6 รายการเข้า Contract-D evidence-manifest, gaps เชิงระบบ 4 ข้อบันทึกใน `_triage/CR002_EVIDENCE_RECONSTRUCTION_999094.md`) · commits `50f9ff7b`+`deead551`+`e8d653a1`) · ก่อนหน้า: 2026-07-19E (Opus/Fable — **ROADMAP ครึ่งหลัง 5 ปี APPROVED** (Final product = EA Portfolio OS + track record 3 ท่อรายได้ · Phase 4.5 Control Room CR-000..007 · Phase 5 Prop gate ม.ค. 2027 · Phase 6 Monetize · กติกากวาด v2 · Codex review 2 BLOCKER+14 MAJOR แก้ครบ — commits `d49843fe`+`5cb0b1ec`) · **Control Room เริ่มจริง:** CR-001a snapshot one-command (`scripts/control_room_snapshot.ps1` → `portfolio/control_room_snapshot.json`) + CR-001b เข้า daily chain + CR-005-lite judge-readiness forecast (`5034025f`+`22e9bb7b`) — **finding แรก: judge ต.ค. มีข้อมูลพอตัดสินแค่ 3/38 EA · บัญชี 463666728 (candidate 14 ตัว) + 69424711 ไม่มี sensor · 146237 stale 13 วัน** → rotation pre-registered รอ user สร้าง folder `D:\Monitor\MT5 - 463666728` · **ORDER-125 ปิด:** vertical-barrier `_2_MaxHoldBars` BUILT+Codex-hardened default OFF แต่ **DEAD-ON-GRID ที่ M4** (M1 หลอกผ่าน M4 พลิก — grid recovery tail = engine ห้าม time-cut; lesson เข้า EDGE_CATALOG; `b6ca0f6e`+`5252f24d`) · ORDER-138 #1-3 ยืนยันปิดโดย session คู่ขนาน · **คิวถัดไป: ORDER-124 → 136 (pace 1-2 cell) แยก session กับ Control Room track**) · ก่อนหน้า: 2026-07-18D (Opus — **3-lane exec (first under re-settle framework): Lane A JumStoch Trend-seed→Boss_18 built+caged then DEAD-OPTIMIZED (28 M4 runs uniformly sub-1; edge=standalone 4-basket+BEP not the seed; direction A/B moot both losing; kept basket-close-DCA lever) · Lane B MacdDiv XAU H4 M4 CONFIRMED 1.88/0.97/1.28 (no fill-artifact) → demo attach-ready (bundle-10 999094, BWD 0.97 marginal user-approved) · Lane C SMCxSTO fan = SL-FRAGILE WEAK candidate → demo-keep 991070 w/ SL-lock≥3.0; rebuild (35 M4 runs) = NO SWAP (holdout soft + SL fragility moves sides + BWD < demo; EURUSD-H1 edge genuinely marginal, next build-on = new HOME not SL). orders LANEA-AB/LANEC-FAN/LANEC-REBUILD REVIEWED + 3 B1 rows. user REMOVED ST_EA03 ×3 from VPS.** decision-log §3 · handoffs in `_triage/ORDER_LANE*`) · ก่อนหน้า: 2026-07-18C (Opus — **research session: D1g pending/TP=NULL (ORDER-080 closed) + event-log dogfood #1 (7 rough-edges fixed) · ORDER-116 split=narrow lever · ORDER-117 coverage+filter=low-yield (1 PARKED-VERIFY GBPUSD MacdDiv D1) · new rule LAST-OPTIMIZE-BEFORE-VERDICT · big read: pipeline MATURE, cheap levers worked → EV=operate/judge**. handoff scratchpad `HANDOFF_2026-07-18.md`, decision-log §3 rows 2026-07-18) · ก่อนหน้า(อีก session วันเดียวกัน): **ORDER-073 news/macro risk system CLOSED end-to-end**: Phase-2.5 MRIS SHIPPED live (web feeder all-8 barometers from Yahoo · thresholds LOCKED v1.0 + in-file tuning guide · whisper embedded in LIVE_DASHBOARD + daily chain · Codex-hardened 5 fixes) · **Phase-3 MacroGate = VALIDATED deploy-candidate** (GV bridge block+lot-mult · A/B Boss_12_Breakout full-year-2024 2-symbol = **eqDD −54..−56%, P&L flat→much-better** · manage-only grid = no-op · cage inert · Codex QA 7/7 fixed) → WAITING-USER live attach · commits `7ee6bbd8`→`e219db8e`, safe branch `order073-macrogate-safe` · handoff `handoff/SESSION_2026-07-18_ORDER073_CLOSE.md`) · ก่อนหน้า: 2026-07-17B (Opus — #098 corpus sprint: 098-F pairs-spread stat-arb = 🟢 CANDIDATE H4 z2.5; handoff scratchpad `HANDOFF_2026-07-17B.md`) · owner: patip
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
| live portfolio — **ข้อมูล** (account/EA/magic/status/kill/judge) | **`portfolio\DEPLOYMENTS.csv`** (inventory เดียว, ORDER-093) | link · checker validate ทุก commit |
| deployment → approved bundle artifacts (attestation expectations) | **`portfolio\ATTESTATION_MAP.csv`** (CR-002, 2026-07-19) | link · snapshot v2 hash เทียบรายวัน |
| live portfolio — **บัญชี** (governance_scope/expected_sensor/SLA/alert_policy ระดับ account) | **`portfolio\ACCOUNTS.csv`** (CR-003b, 2026-07-24) | link · snapshot อ่าน account universe จากไฟล์นี้ · DEPLOYMENTS = per-EA เท่านั้น |
| live portfolio — **คำอธิบาย/บริบท** (ทำไม attach, คำเตือน, ประวัติ) | **DEMO_DEPLOYMENT_PLAN.md** | link |
| backlog · coverage · hunt | **MASTER_BACKLOG.md** | link |
| ทะเบียน EA · scoring · kill-reason | **EA_SCORECARD_AND_REGISTRY.md** | link |
| แผนที่ไฟล์ · 5 ที่อยู่ | **PLATFORM_INDEX.md** | link |
| EA_CORE framework | `D:\EA_Project` docs + `EA_CORE_ST03_LOOP_PLAN.md` | link |

ถ้า 2 ไฟล์พูดเรื่องเดียวต่างกัน → **INVARIANTS (ข้อ 3) ชนะ** แล้วแก้ไฟล์ที่ผิดทันที.

**2) PROJECT_STATE = entry เดียว** — ไฟล์อื่นห้ามเขียน "เปิดไฟล์นี้ไฟล์เดียวพอ". secondary doc ขึ้นต้นด้วย
banner: `> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: <X เท่านั้น>`.

**3) INVARIANTS — fact ที่ต้องตรงทุกที่ (ที่ไหนเขียนต่าง = ที่นั่นผิด):**
- **deployment ทั้งหมด (account/EA/magic/status/kill/judge) = `portfolio\DEPLOYMENTS.csv` แถวต่อ magic**
  (ORDER-093, 2026-07-11 — แทน invariant ชุดเก่า "9 EA/1 account/judge 09-22" ที่ค้างตั้งแต่ยุค 06-22;
  reality ปัจจุบัน = 5 บัญชี ดู DEMO_DEPLOYMENT_PLAN §DEPLOYMENT REALITY 2026-07-09) · แก้ deploy ที่ไหน
  ต้องแก้ CSV ก่อนเสมอ แล้ว checker จะบังคับ dashboard map + docs ให้ตรงเอง
- backtest window: **MAIN 2023.01–2025.12** (36 เดือน ไม่กิน holdout 2026H1) · re-opt/re-pin ทุก 6 เดือน
- magic ห้ามชน — บังคับโดย checker จาก CSV (duplicate account|magic = WARN/block)
- **bot บังคับเอง:** git **pre-commit hook** (`.githooks/pre-commit`) รัน `scripts/check_state.ps1 -Strict`
  อัตโนมัติทุก commit → validate ทุก doc/dashboard-map เทียบ `DEPLOYMENTS.csv` สองทิศ (แถว CSV ไม่มีใน map =
  magic ไม่ถูก monitor · map มีแต่ CSV ไม่มี = ghost row) + entry เดียว + banner. setup ครั้งเดียวต่อเครื่อง:
  `git config core.hooksPath .githooks`. bypass ฉุกเฉิน: `git commit --no-verify`. รันมือ: `powershell -File scripts/check_state.ps1`
  > ⚠️ **ขอบเขต guard:** คุมโครงสร้าง deployment consistency — **ไม่ใช่เนื้อหาทั้งหมด** (PF, สถานะ EA,
  > ตัวเลขอื่น ยังต้องอ่าน/อัปเดตมือ). GUI commit client อาจซ่อน output hook — commit ถูก block แบบงงๆ ให้รัน check มือ.

---

## 1. เป้าหมาย + ภาพรวม 4 ชั้น (โรงงาน 1 + แม่พิมพ์ 1 + คลังอะไหล่ 1 → พอร์ตจริง)

> **เป้าหมายสูงสุด:** 10 พอร์ต × 2–3 EA ที่ **ไม่ correlate กัน** × 10,000 cent → passive income.
> **ภาพใหญ่/ปรัชญาโรงงานของเจ้าของ → `VISION.md`** (อ่านคู่ไฟล์นี้ทุก session — ถ้างานขัดกับ VISION ให้หยุดถามเจ้าของ)

| ชื่อ | ที่อยู่จริง | บทบาท (aligned 2026-07-03) | สถานะ % |
|---|---|---|---|
| **EA_LAB** | `D:\EA_LAB` (repo นี้) | โรงงาน — หา/validate/deploy EA + automation pipeline | 85% โตเต็มวัย |
| **EA_Template (Boss V2)** | `D:\EA_LAB\ea_template` | **แม่พิมพ์หลักตัวเดียวของโรงงาน** (UNFREEZE 2026-07-03) — function กลางร่วมกัน (MM/lot/SL/grid/hedge/recovery) ต่างแค่ entry+TF · งานผลิต EA ใหม่ทุกตัวออกจากที่นี่ | chassis เสร็จ · เหลือเติม Hedge/Recovery + smoke-regression |
| **EA_Project / EA_CORE** | `D:\EA_Project\CURRENT_BUILD` (CORE = engine) | 🏛️ **read-only ARCHIVE (MERGE-08, 2026-07-06)** — อะไหล่ port เข้าแม่พิมพ์ครบแล้ว (pyramid→93 · guardian→acct-gate · persist→Persist.mqh · test pattern→tests\) · เหลือเป็น reference/หลักฐาน ห้ามลบ ห้ามงานใหม่ · TEMPLATE\ standalone เดิม = grandfather ถึง judge | 100% — track ปิด (`AGENT_TASKBOARD_MERGE.md`) |
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
  2026-07-02** (GR opt = null result, goldgrid = all fail, ดู §2 EA_CORE/signal hunt) (log: `_archive_docs/QWEN_RUN_LOG.md`).
- **🏁 EA_CORE merge track = ปิดสมบูรณ์ (เปิด+จบ 2026-07-06 วันเดียว):** user สั่งรวมข้อดี EA_CORE
  เข้า Boss V2 ให้จบ — ทำครบ DoD 6/6 · บันทึกเต็ม = **`AGENT_TASKBOARD_MERGE.md` (CLOSED)**:
  ✅ MERGE-01 (cage ครอบ Boss_14,
  CLEAN×2) · ✅ MERGE-02 (Codex independent converge 4/4 — สลับลำดับเสี่ยงต่ำก่อน + exit-owner
  mitigation) · ✅ MERGE-05A (restart audit: hard-kill state = 🔴 memory-only) · ✅ MERGE-04
  (acct-DD gate `RC_AcctDDLimitPct` default 0 — regression CLEAN, trip พิสูจน์แล้ว 107→48 trades) ·
  ✅ MERGE-05B (`core\Persist.mqh` + persist hard-kill state, `RC_PersistHalt` default ON =
  ข้อยกเว้น additive ที่ signed off · Persist_Test 8/8 PASS · regression CLEAN โดย persist ON) ·
  ✅ MERGE-03 (**STACK_PYRAMID(93) pending ladder เข้าแม่พิมพ์แล้ว** — smoke: placed 24 =
  filled 20 + cancelled 4 บัญชีปิดเป๊ะ, failed 0 · A/B 91 vs 93 = mechanism ต่างจริง · regression
  CLEAN · one-exit-owner: ไม่มี per-leg TP, โหมด 93 ปิด Recovery/Hedge/partial · spec →
  `ea_template/DESIGN_V2.md` §3c) · ✅ MERGE-06 (`tests\run_tests.ps1` — ALL TESTS PASS 3/3:
  Persist 8 · AcctGate 5 · StackStep 4 asserts) · ✅ MERGE-08 (EA_Project ติดป้าย ARCHIVE + docs
  sync ครบ) · ✅ MERGE-07 (**user override hold 2026-07-06:** `Boss_15_ST03` + `Entry_ST03.mqh`
  v4 verbatim — **signal parity 133/133 entry ตรง runner ทั้ง bar+ทิศ, 0 miss** · regression CLEAN ·
  ALL TESTS PASS · **⛔ ห้าม deploy Boss_15 จนกว่า replica 990010 ผ่าน judge** — port ≠ รับรอง edge)
  — **track ครบ 8/8 order · EA_Project ไม่มีงานใหม่อีกถาวร · แม่พิมพ์ Boss V2 = ตัวเดียวจบ ตาม
  VISION (entry 11–15 + stack 90–93 + cage 2 ชั้น)**
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
- 🔴 **(2026-07-10) ST03 family = entry ไม่มี edge — ยืนยันแล้ว (ORDER-068, STRUCTURAL):** flat-lot probe
  ของ config live จริง: GBP(9397) PF 0.68 / CAD(9398) PF 0.40 — **ล้างพอร์ตทั้งคู่เมื่อปิด escalation** =
  กำไร backtest ทั้งตระกูล (PF 2.51/1.67) มาจาก uncapped recovery ล้วน ๆ (no SL · no cap · ratchet defect
  linear→doubling = ที่มาไม้ 33.73 lots บนบัญชี user 939721 ซึ่ง config เหมือน 9397 เป๊ะ) · eqDD ลอย 57-61%
  ทุกปี · **ผลตัดสิน: 9397/9398/990010 อยู่บน demo ต่อเพื่อเก็บ data ได้ แต่ห้าม promote สู่เงินจริง
  ไม่ว่า demo PF จะสวยแค่ไหน (structural — tune ไม่ช่วย) · บัญชีจริง user 159475669 แนะนำถอดทั้งตระกูล** ·
  ทางสร้างใหม่ = Entry_ST03 บน Boss V2 + capped recovery (spec Kangaroo, ORDER-070) · หลักฐาน
  AGENT_TASKBOARD ORDER-068 + `_mt5_auto\reports\ST03LAB_*` · เพิ่มเติม: ZeusInspired บน EURUSD =
  dead cell (ORDER-069: 216 pass, PF สูงสุด 1.14, gate ผ่าน 0) — EURUSD ไม่ใช่บ้านของ reversion-grid ตัวนี้
  · **UPDATE 2026-07-10 บ่าย (ORDER-071 ปิดเคส): entry ST03 ตายสมบูรณ์ทุกแกน** — sweep exit ×4 +
  symbol ×2 + H4 gate ×3 (18 config) ดีสุด 0.99 (บาร์ 1.05) → ห้ามขุด Count-MACD entry อีกทุกรูปแบบ ·
  ของที่รอด: H4-MACD-direction gate (ลด DD 21→5.5%) = อะไหล่ใช้กับสัญญาณอื่น · ทางต่อ = Boss_16 (ORDER-072)
- 🛡️ **(2026-07-11) วัน audit-hardening: CODEX_AUDIT ตัดสินครบ + Layer D ปิดหมด** — Codex audit เต็มระบบ
  (`_triage\CODEX_AUDIT_FULL_2026-07-10.md`) ถูก judge ทีละข้อ (accept ส่วนใหญ่ Layer A/C/D · โต้กลับ
  Keltner/Ichimoku Model-2 kill + ZSCORE ladder — เหตุผลใน taskboard §REVIEW CODEX-AUDIT) · **แก้วันเดียว:**
  daily chain fail-visible + stale guard + dashboard map ครบ 141049900 · ORDER-092 floating-telemetry
  (exporter+FLOATING RISK panel) · ORDER-083B/C NewsGuard MT4 port + hardening 7 ช่อง (พร้อม attach —
  รอ user ทำ `VPS_TRANSPORT_AND_ATTACH.md`) · ORDER-094 cage 4 ตัว fail-closed + Boss_15/16 เข้า regression ·
  ORDER-093(4) ซ่อม encoding ไฟล์นี้ 556 บรรทัด (อ่านออก 100% แล้ว — เหลือ sub-task 1-3 inventory+checker) ·
  **SuperTrend 085B: BWD ตก (PF 0.88) / plateau ผ่าน 18/18 → bench + user อนุมัติ attach demo (magic 990020)** ·
  **user เคาะ:** RSI-MR ออกจาก real→demo isolate · ST03 = user ขอ optimize มือก่อนถอด (PARKED-VERIFY) ·
  crypto lane (ORDER-081) = **PARK** (ไม่มี maker rebate จริง — premise โพสต์ FB ถูกหักล้าง) ·
  doctrine ใหม่จาก audit: **cage ต้อง fail-visible เสมอ** + Model-2 ใช้ฆ่าได้อย่างเดียวห้ามใช้ผ่าน
- 🟢 **(2026-07-11 เช้า) Boss_16 BUY 21/30 XAU H1 = PASS-TO-BENCH (ORDER-078 REVIEWED)** — funnel
  ครบ 4 ขั้นไม่ตกด่าน pre-registered: 27-cell spacing/TP plateau 0 ตัวขาดทุน (PF 1.371-1.854,
  center อันดับ 20/27 = ไม่ใช่ peak) · year-split 6/7 ปีบวก (ลบเดียว 2021 PF 0.78 ขาดทุนมีเพดาน) ·
  Model 0 confirm PF 1.41 (ไม่ละลาย) · MC ruin 0% DD95 4.6% (permutation = DD-only, แกน PF
  ไม่ถูกทดสอบ — จดตรง ๆ) · **ยังไม่ใช่ PASS เงินจริง: BWD เคยใช้เลือก 21/30 เหนือ 14/30 → ไม่มี
  holdout สะอาด → demo forward = holdout ตัวจริง** · locked set `Boss16_Kangaroo_XAU_21_30.set` ·
  judge criteria pre-registered ใน REVIEW ORDER-078 (kill eqDD>12% · judge 3 เดือน PF<0.8 ที่
  ≥15 ไม้) · ห้ามสลับไปโซน sweep ที่สวยกว่า (select หลังเห็นข้อมูล) — เก็บไว้รอบ re-opt 6 เดือน ·
  **✅ (2026-07-11) corr check ปิดแล้ว: corr 0.077 vs BRK_FULLSPAN (25 เดือนร่วม) = LOW-additive**
  ไม่ต้อง reduce-lot · **Boss_16 21/30 พร้อม attach demo ทุกเงื่อนไขแล้ว** เหลือแค่ magic+attach
  จริง (งานของ user) — candidate real-money ตัวแรกหลัง funnel ครบตามที่บันทึกไว้ forward plan
- 🧭 **(2026-07-10 ค่ำ) ปรัชญาโรงงาน + EA-SCORE v1 จารึกแล้ว** — สามชั้น edge/MM/portfolio → `VISION.md`
  §ปรัชญาโรงงาน · rubric คะแนน→สิทธิ์ + กุญแจเพดาน 3 ดอก → `EA_SCORECARD` §EA-SCORE · กฎ user ชุดใหม่:
  rescue-ladder ≥3 รอบ×2 TF ก่อน DEAD · PARKED-VERIFY(user) · diagnosis→lever · pacing batch เล็ก ·
  **retro-audit 154 verdicts รอบแรกจบ (ORDER-084→090):** Keltner/Ichimoku/Oracle/ZSCORE ปิดหลักฐานเต็ม ·
  **SuperTrend XAU H4 = 6/10 รอ 085B (BWD+plateau) — ผ่าน = เงินจริง 1/3 lot** · swb bundle รอ attach ·
  เครื่องมือใหม่: top-5-concentration check · ⚠️ MT5 เมิน Spread= ใน ini (stress ต้อง arithmetic บน trade list) ·
  NewsGuard MT5 พร้อม attach (คู่มือท้าย ORDER-083; 083B = MT4 port คิวถัดไป)
- **Signal hunt — ⚠️ ไม่อิ่มตัวแล้ว หลัง 2026-07-03** เดิมเขียนว่า "98% อิ่มตัว รอไอเดียใหม่" (บรรทัดนี้
  **ล้าสมัย**) — concept เก่าที่ตายแล้วยังตายอยู่ (NR7/AsianRange/LNBREAK/EURCHF/Donchian/Keltner/
  Ichimoku/PrevDay/EMA-cross/SuperTrend/GR optimize/#20 Trend+Pyramid/MT4 goldgrid ทั้งหมด — ดูรายละเอียด
  ที่ `MASTER_BACKLOG.md`) **แต่มี candidate ใหม่จริงจากงาน 2026-07-03: `(Boss)_ZeusInspired_GridLog_rev01`
  บน AUDUSD/AUDJPY (ผ่าน IS/OOS จริง)** — ดู bullet ถัดไปนี้ + `ZEUS_GOLD_HEDGE_ANALYSIS.md` +
  `EA_SCORECARD_AND_REGISTRY.md` Â§FRESH TEMPLATE EAs
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
| 2026-07-24 | **Control Room judge-readiness re-run (ยังไม่ตัดสินใจอะไร — บันทึกไว้เป็น baseline สำหรับตัดสินใจต่อ):** fleet 56 ACTIVE (61 rows รวม removed/pending) · **6 decision-capable วันนี้** (≥30 trades) · 1 PARTIAL (22 trades, ไม่มี judge_date ตั้ง — เป็น gap) · **45 ยังเก็บข้อมูลอยู่** แบ่งเป็น 21 ตัวยังเร็วเกินจะ forecast (0 trade สังเกตได้ หรือยังไม่มี judge_date, 11 ตัวไม่มี judge_date เลย) · **forecast ของ 24 ตัวที่พอมีอัตราสังเกตแล้ว: 6 projected-capable / 18 projected-shortfall** (ต่ำกว่า 30 trades ตอน judge date) · **4 ตัว (69424711) ไม่มี sensor เลยตั้งแต่ต้น = DATA_INSUFFICIENT ถาวรจนกว่าจะติดตั้ง collector** · account `463666728` sensor STALE (30.2h เพิ่งเลยเส้น 30h) และเป็น account ที่ถือ EA กลุ่ม shortfall เยอะที่สุด (IchiADX×3, Breakout×2, Wave5, MacdDiv, PairSpread, RSI-MR, PivotBreakout ฯลฯ) — ความเสี่ยงคือถ้า sensor นี้หลุดถาวรจะเสียการมองเห็นของ EA เกือบ 13 ตัวพร้อมกัน · **เจอ unknown magic 6 ตัว** (159503454: 1851/7810/4378 · 415573666: 1114/12345/2670) เทรดอยู่จริงแต่ไม่มีแถวใน DEPLOYMENTS.csv — governance gap แยกจากเรื่อง judge · attestation: **16/56 hash ยืนยันตรงกับ approved bundle ที่เหลือ 40 มีช่อง (NO_BUNDLE 20/NO_MAP 18/PARTIAL 2)** = พิสูจน์ไม่ได้ว่า .ex5/.set บน VPS ตรงกับที่อนุมัติจริงสำหรับ EA ส่วนใหญ่. **แก้ memory เดิม 2026-07-19E ที่เขียนว่า "3/38 decision-capable"** — เลขนั้นล้าสมัย fleet โตขึ้นมากตั้งแต่นั้น ใช้เลขชุดนี้แทน. raw = `portfolio/control_room_snapshot.json` | user สั่ง "ทำเลย" ต่อจากคำแนะนำให้เช็ค judge-readiness ก่อน judge เดือนตุลา — เป็น read-only investigation ยังไม่ได้ตัดสินใจอะไรเพิ่ม แค่ทำให้เห็นภาพจริงก่อนมีเวลาแก้ (~2.5 เดือนถึง judge แรก) |
| 2026-07-24 | **KillDD 25% = ไม่ผ่อนเพดานกลาง — แต่คำถามของ user ชี้ไปเจอปัญหาจริงคนละเรื่อง.** user ถามว่า "DD 25% แล้ว hard kill เข้มไปไหม ถ้าโดนก็ optimize/ลด lot เอา" → คำตอบที่ให้ และ user สั่งเดินต่อตาม order ที่เปิด: (1) เลข 25 **ปรับได้อยู่แล้วต่อ EA** ผ่าน `ProtectLevel` (TIGHT 15 / NORMAL 25 / LOOSE 40) = deploy-time decision ไม่ใช่การรื้อ doctrine (2) วิธีที่ user เสนอ (ลด lot/เพิ่มระยะจนไม่แตะเพดาน) **ถูกแล้ว** และ `FirstLotMode=43` ที่เพิ่ง harden วันนี้คือกลไกที่ทำให้อัตโนมัติ — วัดได้: fixed 0.10 ตายที่ eqDD 25.09% ไม้ 115/164 ขณะ balance-scaled จบครบ 164 ที่ 22.66% (3) **สิ่งที่ขาดคือสัญญาณเตือน ไม่ใช่เพดานที่สูงขึ้น** → ORDER-193 (4) ห้ามผ่อนฝั่งเงินจริงด้วยเหตุผล "โดนแล้วค่อย optimize" — พอถึง 25% เงินหายไปแล้ว และ re-optimize หลังขาดทุน = fit กับ drawdown ที่เพิ่งกิน | hard-kill **ไม่ถูก tester-gate** (`RiskControl.mqh:287` gate แค่ persist) → ยิงใน backtest ด้วยแล้ว halt ยาวจนจบ run โดยรายงานไม่บอก = **PF ที่อ่านอยู่คือ PF ของ sample ที่ถูกตัด** และจุดตัดขึ้นกับ `-Deposit` ซึ่งเป็น run setting ไม่ใช่คุณสมบัติกลยุทธ์ → รูรั่ว comparability ของ funnel ทั้งระบบ. เจอพ่วง ORDER-194: kill ยิงซ้ำทุก tick หลัง halt (log 14.4M บรรทัด/ไฟล์ 777MB + `GlobalVariablesFlush()` ทุก tick บน live) |
| 2026-07-24 | **rule ใหม่: stitched-window WFA ห้ามใช้กับ basket/grid/multi-position EA** — ต้องวัดด้วย continuous single-span เท่านั้น (ขยาย rule เดิมจาก tiled-window case 2026-07-08 ให้ครอบ WFA fold-based validation ด้วย). พิสูจน์จาก RSI-MR (ORDER-182): WFA 3-fold เดิมให้ fold2-OOS PF 1.08 (บาง) แต่ continuous span เดียวกันให้ MAIN/BWD PF เท่ากันเป๊ะ 1.37/1.37 (plateau จริง) — WFA ไม่ได้แค่ underestimate มันวัด **คนละความจริง** (equity reset ทุก fold ตัดวงจร basket/escalation ที่ยาวข้าม fold) | จ่ายเงินจริงมาแล้ว 2 รอบ (Zeus GridLog confluence-breakout 2026-07-08 PF 7.17/3.97/7.64 tiled→0.583 continuous, RSI-MR 2026-07-23→24) — pattern เดียวกันซ้ำ 2 EA คนละ family = systematic ไม่ใช่ fluke |
| 2026-07-24 | **RSI-MR (990103) demo-isolate attach = accepted แม้ holdout ล้มจริง (0.76, ไม่ใช่แค่บาง)** — user ตัดสินใจ (463666728 EURUSDm, judge 2026-10-24) หลังรับทราบครบ: (1) เคย live บน real 159503454 มาก่อน โดนถอด 2026-07-18 เพราะ DD25% kill (2) holdout ล้มยืนยันซ้ำบน 2 config อิสระ = regime feature ไม่ใช่ tuning bug (3) funnel ที่เหลือครบทุกด่าน (lever 3/3, fan สะอาดที่สุดของวัน, MC ผ่าน comfortable ทั้งคู่). ต่างจาก precedent XAGUSD/LondonORB วันเดียวกันที่ holdout แค่บาง (≥1.0) ไม่ใช่ล้ม (<1.0) — นี่คือ exception ที่กว้างกว่า precedent เดิม ไม่ใช่แค่ทำตาม pattern | user เห็นความเสี่ยงเต็มก่อนตัดสินใจ (แก้คำแนะนำเดิมที่เทียบผิดกับ XAGUSD ก่อน queue) · basket-duration tail (98-182 วัน) ต้อง monitor ต่อผ่าน ea-live-monitor · ไม่ใช่ precedent ให้ EA อื่นที่ holdout ล้มจริงข้ามไป demo อัตโนมัติ — แต่ละเคสยังต้อง user เคาะเอง |
| 2026-07-19 | **ROADMAP ครึ่งหลัง 5 ปี = APPROVED (user):** Final product = **EA Portfolio OS + track record ตรวจสอบได้ (3 ท่อรายได้: ทุนตัวเอง → prop firm ×50–100 → copy-trading)** · **Phase 4.5 Control Room** (CR-000..007: Snapshot ก้อนเดียว → attestation → deterministic health → TODAY+AI advisor → drift/judge-readiness → portfolio control → semi-autonomous; AI authority L0–L3, L4 money = human เสมอ) · **Phase 5 Prop** (gate: พอร์ต #1 live รอด 3 เดือน ~ม.ค. 2027 · research firm ได้ Q4 2026 แบบเบา) · **Phase 6 Monetize** (2028+, verified ≥2 ปี) · **กติกากวาด v2**: intake ไม่จำกัดเฉพาะชั้น smoke เลน agent 100% · WIP validate ≤3 · บัตรผ่าน = payoff-shape ที่พอร์ตขาด · **สัดส่วนงาน 50/25/15/10** (operate/evidence/portfolio/ideas) | user: "กวาดไปก่อนยิ่งเยอะยิ่งดี แต่เห็นด้วยว่าควรก้าวต่อ" — reconcile: กวาด=ชั้นถูก(agent) คุม WIP ชั้นแพง(ปฏิทิน) · แหล่ง: Codex 2 เอกสาร (`_triage/CODEX_CONTROLROOM_DESIGN_2026-07-19.md` + `_triage/CODEX_5YR_OS_VISION_2026-07-19.md`) + Opus เพิ่มฝั่งรายได้ (ท่อ 2/3 ตาม VISION North Star) ที่แผน Codex ไม่ครอบ · รายละเอียดเฟส = `ROADMAP.md` §1.5 + Phase 4.5/5/6 · **Codex blind review รอบสอง 2 BLOCKER + 14 MAJOR → แก้ครบ 16/17 (1 deferred-to-order) = `_triage/CODEX_ROADMAP5YR_REVIEW_2026-07-19.md`** — เด่น: hard prerequisite CR-002 ก่อนเปิด account/prop · vertical slice ให้ทัน judge ต.ค. · SQLite=read-model ห้ามชน owner · automation หยุดที่ SMOKE_SURVIVOR ห้ามออก verdict |
| 2026-07-19 | **user rule ใหม่: ENGINE-EDGE class** — "flat-lot<1 แต่ escalated>1" เลิก auto-kill (ยกเลิก structural-kill ข้อแรกเดิม) → เดินต่อได้ภายใต้กรง 5 ข้อ: worst-case ≤15% equity คำนวณได้ (cap+SL/DD-kill) · BWD 2020-22 hard · Model-4 บังคับ · MC ruin ≤2% · label engine-edge = sizing เล็กถาวรห้าม size-up ตาม PF. flat-lot probe เปลี่ยนหน้าที่เป็นเครื่องวินิจฉัย. uncapped-ruin ยังฆ่าทันทีเหมือนเดิม. **ผล: ORDER-119 lever A (ST03 capped basket) เปิดกลับเป็น testable + validated PF>1 cohort ใส่ escalation-MM overlay ได้ (เข้า funnel ใหม่เต็มใบ)** | philosophy user: "เปิดจุดดีสุดไม่ได้ทุกครั้ง MM คือตัวรอด" + precedent NuiIndy (geometric+CutLoss30 live PF~2.0) + trap เดิมกันครบผ่านกรง (fake plateau→M4 · unseen tail→BWD hard · ruin→cap+MC · size-up→label) |
| 2026-07-18 | **Framework re-settle 5 ส่วน = FINAL (Fable seat + Codex review) + user เคาะ 5 ข้อใน grill:** (1) MAIN window = **rolling 36 เดือน re-pin ทุกรอบ re-opt** (convention ที่ถูก: 36 เดือนที่**ไม่กิน holdout** เช่น 2023.01–2025.12) — แก้ "2023–2026" ที่งอกเป็น 3.5 ปีเงียบๆ (2) vocabulary verdict เหลือชุดเดียว (DEAD-STRUCTURAL/DEAD-OPTIMIZED/PARKED-VERIFY/BUILD-ON/CANDIDATE/DEMO/LIVE) — backtest-report-analyzer + robustness-validator ลดชั้นเป็นเครื่องคิดเลข (3) BWD≥1.0 = ด่าน funnel อัตโนมัติ ไม่ใช่ hard gate — BWD-fail → PARKED-VERIFY(user) → user เคาะ demo-isolate ได้แต่**ปิดทางเงินจริงอัตโนมัติ** (precedent SuperTrend 990020) (4) แหล่ง edge ลำดับ EV: ตัวคูณบน edge ที่มี → กลไก×symbol → ไอเดียมือ user (session เคาะ spec สด) → corpus filler (5) **ST03 owner-override: เก็บบนบัญชีจริงต่อ + บังคับกรง CutLoss ก่อน (ORDER-118) + rescue campaign เฉพาะ 3 lever ที่ไม่เคยแตะ (ORDER-119: entry-params/capped-basket/MRIS leading gate) — ORDER-071 ban แก้ขอบเขตโดย owner: lever ที่ปิดแล้วยังปิด · ตัดสินด้วย flat-lot bar** | framework เต็ม = `_triage/FABLE_RESETTLE_FRAMEWORK_2026-07-18.md` (Codex review 2 BLOCKER/8 MAJOR แก้ครบ = `_triage/CODEX_RESETTLE_REVIEW_2026-07-18.md`) · implement orders ตามไฟล์ §(c) ทุก part · grill = session Fable 2026-07-18 |
| 2026-07-18 | **Lane A/B/C exec conclusions (first campaign under re-settle framework):** (1) **JumStoch Trend-seed = DEAD-OPTIMIZED on chassis** — 28 M4 runs uniformly sub-1 both-window; the standalone's PF1.18 edge is the 4-basket+Counter+BEP engine, NOT the LWMA+Stoch seed → **lesson: don't port a composite EA's seed alone expecting the edge to travel**; direction A/B (faithful vs reversion) moot, both lose equally. kept lever: basket-close beats per-leg-TP on DCA (+0.30 PF). (2) **SMCxSTO EURUSD-H1 = marginal edge, not robust** — fan SL-fragile, 35-run rebuild found no SL-plateau (fragility just moves sides) + holdout soft across whole plateau (2026H1 regime) → keep demo 991070 (SL-lock≥3.0), no swap; next build-on = new HOME (TF/symbol) not more EURUSD-H1 SL tuning. (3) MacdDiv XAU M4 confirmed = demo-ready. | verdicts `_triage/ORDER_LANEA_JUMSTOCH_VERDICT.md` · `_triage/ORDER_LANEC_SMCSTO_FAN_VERDICT.md` · `_triage/ORDER_LANEC_REBUILD_VERDICT.md` · `_triage/ORDER098B_MACDDIV_M4_VERDICT.md`. Boss_18 kept in chassis (dead-seed, not-deploy banner). commits f30d2f72→02e42879 |
| 2026-07-18 | **user rule ใหม่: LAST-OPTIMIZE-BEFORE-VERDICT** — ก่อนเขียน PARKED/REJECT กับ EA ที่เคยมีชีพจร (smoke/IS PF>1 หรือ idea ดี) ต้อง optimize รอบสุดท้าย 1 รอบบน lever ที่ยังไม่แตะก่อนเสมอ (holdout-fail→regime-gate/TF/adaptive-exit) — ถ้าไม่ดีขึ้นค่อย reject · ยกเว้น STRUCTURAL death (flat-lot<1/uncapped-ruin/cracked/no-source). จารึก `CLAUDE.md` VERDICT GATE + memory `feedback-last-optimize-before-verdict`. | คุ้มทันทีวันตั้งกฎ: GBPUSD MacdDiv H4 reject (holdout 0.55) แต่ last-opt TF lever เจอ **D1 1.45/1.23 both-window** = กันตาย final ทั้งที่มี edge |
| 2026-07-18 | **ORDER-116 (split-entry) + ORDER-117 (coverage×TF + filter) = CORE DONE, low yield → pipeline MATURE.** split = narrow lever (ยก XAU 40/5 regime-robust แต่ corr 0.861 redundant-slot · เปิด leg ใหม่ไม่ได้) · coverage: MacdDiv XAU-specific (GBPUSD D1 = 1 PARKED-VERIFY) · breakout ไม่ travel FX + hardcode-H1 (TF-expand ไม่ได้) · SuperTrend trend-specific · filter (candle+RSI) = decoration ทั้งคู่. **ไม่มี leg ใหม่สะอาด.** verdicts `_triage/ORDER116_*` + `_triage/ORDER116_CAMPAIGN_CONCLUSION.md`. | เทส pending·split·coverage·filter ครบ ~10 batch ชี้ทางเดียว: cheap improvement levers รีดหมดแล้ว → EV จริง = operate→judge (demo 3 เดือน + 8 bundle staged). doctrine: validated EA = tune แน่นที่บ้าน, cheap expand/filter ไม่ยก both-window (signal รีด edge หมด, filter ตัดไม้ไม่ selective) |
| 2026-07-17 | **ORDER-091C-D1g = NULL → keep JUMSTOCH config · ORDER-080 CLOSED · event-log dogfood #1 complete.** pending-limit + TP-widen A/B บน JUMSTOCH (confirmed-edge base, regression cage PASS) → ทั้งคู่ null/noise: pending Δ+0.01/−0.03/0.00/0.00 (EURGBP+NZDUSD both-window), TP-widen +5 = +0.01-0.02 noise. กลไก: grid เข้าที่ `ask≤trigger` อยู่แล้ว = ไม่มี spread ให้ประหยัด · exit ด้วย BEP+trailing ไม่ใช่ TP. **doctrine: pending-limit rescue ใช้กับ EA ที่ entry market-on-signal เท่านั้น ห้ามใช้กับ grid trigger-touch.** JUMSTOCH คง demo config เดิม (ไม่แตะ 07-11 validation). dogfood พบ rough edges 7 ข้อ → แก้ `EVENT_LOG_ADOPTION.md`. verdict `_triage/ORDER091C_D1G_VERDICT.md` · exp_93d9457a (7-event chain + AMENDMENT) | scope = refinement-lever บน validated EA (VERDICT GATE: ไม่เปลี่ยน config เพราะ +0.01 = selection-fit risk) · pending doctrine characterized ครบหลัง D1d+D1g |
| 2026-07-17 | **B1 observation window = OPEN (ORDER-115, §20.2 step 6 ปลดล็อกหลัง Contract D).** cohort = 20 eligible terminal orders แรกที่ปิดหลัง `0e13699` · นิยาม/denominator เดียวกับ B0 แต่เก็บ **prospective** (onboarding/incident/lead-hours บันทึกสด — กติกา: session ที่ mark REVIEWED ต้อง append แถว `docs/memory_control/B1_DATASET.csv` ใน commit เดียวกัน) · **MVP-2 ตัดสินจาก §20.4 absolute triggers เท่านั้น** ประเมินเมื่อครบ 20 แถว AND ≥30 วัน (ไม่ก่อน 2026-08-16) — ห้ามสร้างก่อน trigger เข้า · adoption guide การใช้ event log กับ order ใหม่ = `docs/memory_control/EVENT_LOG_ADOPTION.md` (worked example ผ่าน end-to-end จริง) · canary backfill = 3 เคส lazy เท่านั้น | §20.2 step 6 เป็นขั้นเดียวที่เหลือระหว่าง Contract D กับ MVP-2 gate — เปิดช้า = trigger evaluation เลื่อน · commits `dc566d77`+`17528d9` |
| 2026-07-17 | **ORDER-105 (Contract D — MVP-1-lite Experiment Event Log) = ACCEPT ปิดสมบูรณ์.** blind review 8 รอบ (REWORK 5→2→2→2→1→1→1 → ACCEPT รอบ 8) · **commit `0e13699` ผ่าน production hook** — staged checker `[experiment-events]` ใหม่ PASS กับ commit จริงครั้งแรก · deliverable ครบ 3 ชิ้นตาม §20.8 @ `4eb839d`: locked JSONL append utility (`scripts/experiment_event_log.ps1` — lock/atomic/fail-closed/recovery 6-branch) + schema v1 ×2 (ownership บังคับด้วย whitelist, ไม่มี prose field) + evidence manifest (committed-Git-artifact only) + negTest ถาวร 105 case · gate สุดท้าย 105/105 ×2 identical · 103=41/41 · 101=25+1 pre-existing · **Event Log dormant จนกว่า experiment แรก (no-backfill) · MVP-2 Context Packet ยัง B1-gated** · ตั้งแต่ rework รอบ 4 = Claude เขียนเองทั้งหมดตาม routing flip — Codex-as-blind-auditor จับ defect จริงต่อเนื่องถึงรอบ 7 (recovery reinstall + test flakiness) | review หลายรอบคุ้มอีกครั้ง: defect ลึกสุด (COMPLETED-state reinstall) โผล่รอบ 6 หลัง 5 รอบก่อนหน้าไม่เห็น — self-verify เดี่ยวไม่มีทางจับ · ประวัติเต็ม = `docs/memory_control/CODEX_ORDER105_RESULT.md` |
| 2026-07-16 | **🔁 ROUTING FLIP (user เคาะ): โค้ดสำคัญ = Claude seat เขียนเอง · Codex = blind auditor/verifier เท่านั้น (เลิกใช้เป็น builder) · Fable-seat = ผู้ตรวจงาน milestone.** มีผลตั้งแต่ order ถัดจาก ORDER-105 (105 จบบนรางเดิม — โค้ดเสร็จแล้วตอนเคาะ) | จ่ายจริงใน 1 วัน (ORDER-105): Codex-as-builder ตายกลางงาน 3 ครั้ง (at-capacity ×2 · content-filter ×1 · ครั้งสุดท้ายเผา 1.2M tokens ไม่จบ gate) — Claude ต้องรับช่วงทุกครั้ง · ขณะที่ Codex-as-auditor จับ defect จริงต่อเนื่อง (5 ตัวใน review รอบเดียว) · แถม Claude-เขียน/Codex-ตรวจ = อิสระสะอาดกว่า (ไม่มี shared authorship) |
| 2026-07-16 | **ORDER-105 (Contract D — MVP-1-lite Experiment Event Log) แตกแล้ว = OPEN.** design source = `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` **§20.8 Contract D + §20.7 ownership @ `4eb839d`** (pointer บรรทัดนี้ = §20.9 requirement) · acceptance เชิงตัวเลข + ห้าม + rollback ทั้งหมด = AGENT_TASKBOARD ORDER-105 · routing แบบ ORDER-103: Codex design-review → build → Claude spot-verify → blind Codex review (fresh session) — ห้ามข้าม blind review แม้ quota ตึง | MANDATORY REVIEW GATE §20.2#5 ปลดล็อกโดย ORDER-103 (2026-07-14) → Contract D เปิดทางเป็นครั้งแรก · handoff เต็ม = `docs/memory_control/CONTRACT_D_HANDOFF.md` |
| 2026-07-14 | **ORDER-103 (C1-ENFORCE) = ACCEPT ปิดสมบูรณ์.** รอบ 6 blind Codex (gpt-5.6-sol) = **ACCEPT** หลัง fresh from-scratch repro ทุก high-risk scenario (checkpoint-laundering / reordered-append / mutate-then-restore / fail-closed hook) · Opus spot-verify เอง (gates 0, scope 5 ไฟล์, HEAD intact, 245f8f62 ไม่ถูกแตะ) · **commit `c0f7b0d` ผ่าน production hook (ไม่ `--no-verify`)** · make_status รันแล้ว · **MANDATORY REVIEW GATE §20.2#5 ปลดล็อก → Contract D (MVP-1-lite event-log) เปิดทาง**. รวม 6 rework + 6 blind review round; เจอ blocker จริงถึงรอบ 5 (สำคัญสุด = BLOCKER 6 "checkpoint laundering ผ่าน merge" กระทบ root-of-trust) ก่อน 0-blocker. **Role กลางเซสชัน:** Codex(gpt-5.6-sol) คุมทิศทาง+โค้ด, Claude Code = สั่งงาน+spot-verify จุด irreversible (quota Opus จำกัด). ประวัติเต็ม = `docs/memory_control/CODEX_ORDER103_REWORK_RESULT.md` | 6 รอบ blind review ยืนยันคุณค่าของ 2-มุมมองซ้ำแล้วซ้ำเล่า — ถ้า self-verify เดี่ยวพอ BLOCKER 6 (root-of-trust) จะหลุดเข้า production |

| วันที่ | การตัดสินใจ | เหตุผล |
|---|---|---|
| 2026-07-13 | **Memory-Controlled OS build เดินครบ 4 orders + ผ่าน mandatory review gate.** A(099 B0-baseline+owner-map) **REVIEWED** · B(100 execution-harness `run_batch.ps1`) **REVIEWED MVP-0** · C0(101 reconcile+validator `check_taskboard_archive.ps1`) **REVIEWED** · C1(102 migration: taskboard index→generated read-only + archive=append-only log) **DATA ACCEPT/ENFORCEMENT REWORK**. ทุกใบผ่าน Codex blind review รวม ~15 รอบ (จับ defect จริงที่ self-verify พลาดทุกใบ). artifacts = `docs/memory_control/`. **Contract D (event-log) ถูก block จนกว่า C1-ENFORCE ปิด** (append-chain tamper-evidence + fail-closed hook + Source-A exact-binding + hash-object atomicity) — ดู AGENT_TASKBOARD ORDER-102 review-gate table | ปัญหาต้นทาง: taskboard 578KB→agent เผา token อ่าน + concurrent-writer collision (โดนจริง session นี้). build นี้ = ทำ coordination backbone ให้เล็ก+เชื่อถือได้+tamper-evident. migration ที่ทำแล้ว correct+safe (git=tamper-evidence จริง) |
| 2026-07-12 | **Memory-Controlled OS final design APPROVED + canonicalized.** implementation source เดียว = `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20 @ `4eb839df09b1911cec2de18ec4a2df51cf766606` · แตก order แบบ **serial (Contract A ก่อน)** · **หยุด review หลัง implementation order ที่ 4** · **MVP-2 ยัง B1-gated** · order ทุกใบต้องอ้าง §20 @ SHA — แก้ §20 เงียบ = เปิด review ใหม่ | first B0 order = ORDER-099 (OPEN). ห้าม implement จาก draft ตรงๆ — order คือ artifact ที่ execute. design detail ไม่ทำซ้ำที่นี่ (owner = §20 @ SHA) |
| 2026-07-06 | **ทิศ "final" ของโปรเจกต์ (user เคาะ): ไม่ไล่เป็น quant firm — ไล่เป็น quant method** · ❌ ไม่ทำ: tick infra หลาย venue / low-latency / ML alpha / custom backtester (ยังไม่ถึงเวลา — คุ้มเมื่อ MT5 tester เป็นคอขวดจริง) · ✅ ทำหลัง judge = **Phase 3.5 PORTFOLIO-QUANT** (`ROADMAP.md`): 🥇 portfolio risk layer (vol-target + DD budget) · 🥈 deflated gate (multiple-testing) · 🥈 tracking-error bands · **ห้ามแทรกก่อน judge** — demo 3 เดือน = experiment ที่แพงสุดที่กำลังรัน | edge ของ quant firm อยู่ได้เพราะทุนใหญ่×ต้นทุนต่ำ — ที่สเกลเรา infra แบบเขาให้ผลตอบแทนเพิ่ม ≈ 0 · ตัวขวาง END STATE จริงคือจำนวน edge ที่รอดการฆ่า ไม่ใช่เครื่องมือ · pipeline ปัจจุบันเข้มระดับ quant method อยู่แล้ว (ORDER-037/038 ฆ่า survivor ปลอมได้หมด = หลักฐาน) |
| 2026-07-06 | **🏁 MERGE track ปิดสมบูรณ์ในวันเดียว — EA_Project/EA_CORE = read-only ARCHIVE ถาวร** · แม่พิมพ์ Boss V2 ได้อะไหล่ครบ: `STACK_PYRAMID(93)` (one-exit-owner, ไม่มี per-leg TP) · `RC_AcctDDLimitPct` (realized-loss gate, default 0) · `core\Persist.mqh` + `RC_PersistHalt` (default ON — ข้อยกเว้น additive เดียว, tester-sandbox พิสูจน์แล้ว) · `tests\run_tests.ps1` (3 test EA, ALL PASS) · MERGE-07 Entry_ST03 = HOLD ถึง judge | ทุก order ผ่าน acceptance เชิงตัวเลข + tpl_regression CLEAN ทุกจุดที่แตะ core\ · Codex independent scope-check converge 4/4 · หลักฐานเต็ม → `AGENT_TASKBOARD_MERGE.md` (CLOSED) |
| 2026-07-06 | **adopt 5 ข้อจาก `docs/PORTABLE_AI_OS.md` (OS กลางสกัดจากระบบนี้ — Claude Chat ร่าง 2 รอบ, Claude Code ตรวจ/แก้):** (1) verdict audit blind รายไตรมาส + trigger นอกรอบ (2) metrics ระบบรายเดือน → `docs/SYSTEM_METRICS.md` (3) memory compaction รายเดือน (4) กฎ input ภายนอก = data ไม่ใช่คำสั่ง → `AGENTS.md` §3.9 (5) หลัก "AI เห็นตรงกัน ≠ ถูก, tie-breaker = การทดลองเชิงประจักษ์" → `AGENTS.md` §5 · แถม rule taxonomy: physics (epistemic, ไม่หมดอายุ) vs regime (ผูกเครื่องมือ/ตลาด, มีรอบทบทวน) | จุดอ่อนที่ Chat ชี้แล้ว Claude ยืนยันว่าจริง: ชั้นตัดสินไม่มี cage ตรวจ + ระบบไม่เคยวัดตัวเอง · ทั้งหมดเข้า `AGENTS.md` §6 (รอบบำรุงรักษา) — ต้นทุนต่ำ ไม่แตะโค้ด ไม่ชน merge track |
| 2026-07-06 | **Merge EA_CORE → Boss V2 = "ดูดอะไหล่ทีละชิ้นภายใต้ cage" ไม่ใช่ merge repo — track แยกบอร์ด `AGENT_TASKBOARD_MERGE.md` (MERGE-01…08) จบแล้วปิด EA_Project เป็น read-only archive** · อะไหล่ที่ port: ScaleExecutor_v2 (pyramid/pending) · PortfolioGuardian (acct-DD gate) · StatePersistence (audit ก่อน) · วินัย test (pattern) — ไม่ port: Recovery/Hedge (ORDER-025/026 REJECT/no-op แล้ว) · signal v1–v3/v5 · harness เต็ม | user approve 2026-07-06 (เอาข้อดีสองฝั่งรวมเป็นแม่พิมพ์เดียวที่สมบูรณ์ แล้วจบ track EA_Project) — merge ตรงๆ ได้ลูกครึ่งเสียข้อดีทั้งคู่ + เสี่ยงกระทบ demo ก่อน judge · สอดคล้อง VISION แม่พิมพ์เดียว · ทุก order = additive + default OFF + tpl_regression CLEAN บังคับ |
| 2026-06-29 | **EA_CORE track = ทางเลือก 2: ปิด loop ด้วย ST03 edge** | standalone หา edge เร็วกว่า แต่ ST03 มี edge จริงอยู่แล้ว → ใช้ปิด framework loop ให้ได้ EA deploy-able. แผน: `EA_CORE_ST03_LOOP_PLAN.md` |
| 2026-07-02 | **EA_CORE loop ปิดแล้ว — FALLBACK: EA_CORE = R&D, ST_EA03 standalone = production** | STEP 3 grid 48/48 combos OOS PF<1.0 (complete enum, M2 ฝั่ง optimistic) + STEP 2 signal เพียว PF 0.67 → ไม่มี durable set. ห้าม re-tune ตระกูลนี้โดยไม่มี signal ใหม่. หลักฐาน: `EA_CORE_ST03_LOOP_PLAN.md` STEP 5 |
| 2026-07-02 | **KAUFMAN_ER = CANDIDATE reserve · SUPERTREND XAU = PARKED** (ยังไม่ deploy) | re-confirm ผ่านทั้งคู่ แต่ corr ระหว่างกัน 0.946 = ตัวเดียวกัน → ถ้าจะ deploy เอา KER ตัวเดียว 0.01 lot (corr 0.75 vs BRK8). ดู EA_SCORECARD §VALIDATED RESERVE |
| 2026-07-02 | **EA_Template = FREEZE 100% เป็น smoke tool** | เครื่องมือเสร็จ วัดเชื่อถือได้ = จบงาน track; ไม่พัฒนา chassis ต่อ, ไอเดียใหม่ยังเสียบผ่าน Boss V2 ได้ (guide: `docs/EA_CORE_AND_TEMPLATE_GUIDE.md`) |
| 2026-07-02 | **ST03 replica (990010) = WATCH** | qwen rerun OOS PF 0.86 ขัด 3.93 provisional → ห้ามใช้เป็น baseline จนกว่า re-confirm ด้วย locked .set |
| 2026-07-10 | **ST03 family no-edge = STRUCTURAL (ORDER-068)** | flat-lot GBP 0.68 / CAD 0.40 ล้างพอร์ต → **ห้าม promote ตระกูล ST03 สู่เงินจริง** (demo เก็บ data ต่อได้) · บัญชีจริง user แนะนำถอด 939721+9398+990010 · ZeusInspired×EURUSD = dead cell (216 pass, PF max 1.14) · Gold_Kangaroo smoke PF 4.86/DD11% H1 = candidate แกะ logic (ORDER-070) |
| 2026-07-10 | **user rule: rescue-ladder ก่อน DEAD + PARKED-VERIFY(user)** | ผ่านเกณฑ์เบื้องต้น → ต้อง optimize ≥3 รอบ lever ต่างชุด × ≥2 TF/symbol (ชุด lever เลือกตาม strategy) ก่อนตีตาย · idea ดีที่ไม่ผ่าน = tag PARKED-VERIFY(user) แจ้ง user เสมอ ห้ามตายเงียบ · เพิ่ม exit-mode เข้า lever list gate (บทเรียน ST03 071) |
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
| ongoing | **backtest window = MAIN 36 เดือน (2023.01–2025.12, ห้ามทับ holdout)** · re-opt ทุก 6 เดือน · ห้ามยืดเป็น 10 ปีเพื่อ "แก้ MC" | memory: backtest-window · โดน re-pin ชัดโดย decision 2026-07-18 |
| ongoing | **demo ≥3 เดือน ห้ามลัด** ก่อน live micro | README กฎเหล็ก |

---

> ⚠️ **HISTORICAL SNAPSHOT — superseded.** ตารางด้านล่างค้างจากช่วงก่อน 2026-07-18 (ST03 ออกจากเงินจริงแล้ว) — ความจริงปัจจุบันดูไฟล์เดียว: `portfolio/DEPLOYMENTS.csv`

## 4. LIVE PORTFOLIO (สรุป — detail เต็มที่ `DEMO_DEPLOYMENT_PLAN.md`)

account เดียว 10,000 cent · judge **2026-09-22** · attribution key = **(magic, symbol)**.

| # | EA | Symbol/TF | Magic | OOS PF | สถานะ |
|---|---|---|---|---|---|
| 1 | Matchagrid MG_v1 | CHFJPY M15 | (GUI default) | 2.08 | 🟢 LIVE |
| 2 | NuiIndy RSI+ADX | EURUSD H1 | 1524 | 2.00 | 🟢 LIVE ⚠️ edge=geometric martingale (2026-07-18) — guardrail rec `CutLoss=30` (`NUI_cut30only.set`); `_triage/ORDER095_NUIINDY_EXPAND_VERDICT.md` |
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

deploy ทำตาม `_archive_docs/DEPLOY_CHECKLIST_2026-06-29.md` → ✅ เสร็จครบ 3 รายการ (user ยืนยัน 2026-07-02).

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

> 🧠 **MEMORY-CONTROL OS BUILD (canonical 2026-07-12):** implementation source = `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20 @ `4eb839d` (full SHA ใน §3 Decision log) · แตก order แบบ **serial — Contract A ก่อน** · **หยุด review หลัง system order ที่ 4** · **MVP-2 ยัง B1-gated** (สร้างต่อเมื่อ B1 เข้า trigger เท่านั้น) · first order = **ORDER-099 (B0 + ownership map)**. design ไม่ทำซ้ำที่นี่ — owner = §20.

### 🆕 PLAN 2026-07-12+ (เขียนโดย Fable-seat 2026-07-11 ก่อนส่งมอบ → **Opus = seat หลักทุก session ถัดไป**)
**👉 session ใหม่อ่าน block นี้ก่อน — งานเรียงตาม EV + การแบ่ง seat Fable/Opus/Codex ชัดแล้ว**

**สถานะส่งมอบ:** CODEX-AUDIT ปิดครบ (Layer D ทั้งหมด + A/C ฝั่ง build · เหลือ user attach) · cage 4 ตัว
fail-closed · deployment truth = `portfolio\DEPLOYMENTS.csv` (checker validate ทุก commit) · คลัง intake
1,592 unique EA พร้อม Wave 1 · NewsGuard+SnapshotExporter พร้อม attach

**คิวงาน (pacing 1-2 order/รอบ เหมือนเดิม):**
1. ~~091A/091B~~ **ปิดแล้ว 2026-07-11:** 091A คลัง→1,592 unique · 091B BOT MOGUL bundle = DEAD
   (BWD ของเราเอง: vendor PF 67→0.39/DD 96% · ห้าม re-mine · memory wobr-botranking อัปเดตเลขจริงแล้ว)
2. **091C — user-priority funnel queue (คิวถัดไป, Opus นำ)** — **เริ่มจาก `_triage\ORDER091C_FINALEA_PREP.md`
   บล็อก "USER-CONFIRMED SCOPE 2026-07-11"**: user ยืนยัน 5 โฟลเดอร์ = ของ backtest ดีแล้วรอ MC/OOS/optimize
   (67 src = funnel target). batch 1 = `JUMSTOCH_FIXEDLOT` (มี flat-lot ให้แล้ว) + `(OH) Recovery Hedging w/ SL V05`
   (มี SL จริง) · gotcha ปิดก่อน: x-ray `MT5 good`+`MT4 good` (7 src ยังไม่อยู่ใน 091A) · NuiIndy RSI+ADX = live แล้ว ข้าม
3. **076 — smoke หัวกะทิ 41 ตัวจาก X-ray** (agent batch, cage ใหม่พร้อมแล้ว) · ตามด้วย **080**
   (limit-entry study — template แตะได้แล้ว regression ครอบ Boss_15/16)
4. **082 — Wave5 spec** รอ user ยืนยัน draft → **ก่อน build ให้ยิง fable-advisor one-shot ตรวจ spec**
   (กลไกจากมือ user เอง — ตีความพลาด = แพงสุด)
5. **[user action ค้าง]** ชุด VPS ทีเดียวจบ (NewsGuard + SnapshotExporter + OneDrive สองทิศ ตาม
   `VPS_TRANSPORT_AND_ATTACH.md`) · ย้าย RSI-MR real→demo · attach SuperTrend 990020 ·
   ระบุบัญชี **146237** (โผล่ใน live_deals ไม่อยู่ใน 5 บัญชี) · ผล optimize ST03 ของ user → คุยด้วยบาร์ flat-lot
6. **P1 audit backlog** (MASTER_BACKLOG §CODEX-AUDIT) แทรกตอน lane ว่าง: gist redact (เร็วสุด) →
   evidence lineage → drift monitor (ต่อยอด 092 หลัง snapshot ไหล) → backup drill
7. **🆕 098 — fxDreema YouTube corpus build-on (CAMPAIGN, 2026-07-12)** — แกะช่อง @fxdreemalearner ครบ
   320 คลิป → catalog 272 EA + shortlist (`_triage/fxdreema_youtube/BUILDON_SHORTLIST.md`, memory
   `fxdreema-youtube-corpus`). Orders stock แล้ว: **098-A** FVG-fill entry flat-lot smoke · **098-B** MACD-
   divergence flat-lot smoke · **098-C** MM-parts library (dynamic close_money + Fibonacci-capped lot =
   "cap+linear/log" ที่ user สั่ง). **⏸ รอ user เคาะลำดับใน session เดียวที่นัดไว้ก่อนลงมือหนัก** — sub-orders
   พร้อมรัน. toolchain แกะคลิปเพิ่ม (yt-dlp+Whisper GPU) = `scripts/yt2text.ps1` · doctrine: flat-lot probe
   บังคับทุก entry (ST03-dead vs Kangaroo-edge) · ห้ามตัด grid/martingale ทิ้ง = ขุด part แปะ chassis validated.

**การแบ่ง seat (user directive 2026-07-11 — Fable เหลือ ~10%):**
- **Opus = lead/judge ทุก session** (ตาม CLAUDE.md transition เดิม — role อยู่ที่ seat) · งานประจำทั้งหมด:
  review agent, verdict ตาม VERDICT GATE, เขียน order, judge 091 waves
- **Fable = จองเฉพาะ 4 กรณี ผ่าน `fable-advisor` one-shot เท่านั้น (ห้ามเผาเป็น session เต็ม):**
  (1) ตัดสินผล ST03 ที่ user optimize มือ (เงินจริง + user ลงแรงเอง — ต้องแม่นและละมุน)
  (2) ตรวจ spec ORDER-082 Wave5 ก่อน build (edge จากมือ user — misread แพง)
  (3) การ promote เงินจริงครั้งแรกของ candidate ใหม่ (Boss_16 หลัง demo forward / ตัวแรกที่ผ่าน funnel เต็ม)
  (4) RCA เหตุการณ์เงินจริงผิดปกติ (stop-out, EA เปิดผิด, NewsGuard ทำงานพลาด)
- **Codex = สมองอิสระ + งาน code หนัก:** second-opinion การตัดสินแพง/ย้อนไม่ได้ (ห้ามให้ดูคำตอบ
  Opus ก่อน) · builds ใหญ่ (Wave-3 Jobot binary-strings tooling · drift monitor P1 · ORDER-080) ·
  คุม quota ChatGPT: batch → qwen/Sonnet เสมอ
- **บทเรียน agent วันนี้ (อยู่ใน memory แล้ว):** brief งานรันยาวต้องบังคับ foreground synchronous —
  agent ที่ background แล้วหยุดรอ notification = ตาย (เกิด 2 ครั้ง: 094, 091A)

---

### 📦 SESSION LOG 2026-06-29 → 07-08 — ย้ายไป archive แล้ว (2026-07-12, Opus)

> 3 session-log เก่า (SESSION 07-08 hunt · เสร็จแล้วครบ 06-29→07-02 · HANDOFF ZeusInspired) ย้ายไป
> `PROJECT_STATE_SESSIONLOG_ARCHIVE.md` เพื่อลดขนาด AI-START-HERE · เนื้อครบใน git history + ไฟล์ archive
> บทเรียนถาวรตกผลึกแล้วใน: **DECISION LOG §3** · **CLAUDE.md VERDICT GATE** (backward-OOS, martingale-recheck) ·
> **EA_SCORECARD** (verdict ทุก EA) · **DEMO_DEPLOYMENT_PLAN** (cohort/attach) — ไม่มีอะไรต้องทำต่อจาก log พวกนี้

---

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
- EA source: `D:\EA_LAB\ea_projects\(Boss)_ZeusInspired_GridLog\(Boss)_ZeusInspired_GridLog_rev01.mq5` (ย้ายออกจาก archive 2026-07-08)
- .set variants ทั้งหมด (baseline/tightened/scaled): `D:\EA_LAB\ea_projects\(Boss)_ZeusInspired_GridLog\set_files\ZeusInspired_*.set` (12 ไฟล์)
- ผลทดสอบทั้งหมด: `D:\EA_LAB\_mt5_auto\reports\ZIGL_*.htm` + `D:\EA_LAB\_mt5_auto\ZIGL_*.csv`
- Correlation script: `D:\EA_LAB\_mt5_auto\zigl_correlation.py`
- Monte Carlo script: `D:\EA_LAB\scripts\mt5_montecarlo.py`
- วิเคราะห์เต็ม + timeline: `ZEUS_GOLD_HEDGE_ANALYSIS.md` · registry: `EA_SCORECARD_AND_REGISTRY.md`
  Â§FRESH TEMPLATE EAs

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
| memory-control OS design (order source เดียว) | `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` **§20 @ `4eb839d`** (order ทุกใบอ้าง §20 @ SHA + Decision-log pointer) |
| ภาพใหญ่/ปรัชญาโรงงานของเจ้าของ | **`VISION.md`** (อ่านคู่กันทุก session) |
| กติกา multi-agent + คิวงานกลาง | `AGENTS.md` · `AGENT_TASKBOARD.md` |
| roadmap ระยะยาว + ภาพสุดท้าย + gate เลื่อนเฟส | `ROADMAP.md` |
| EA_CORE ปิด loop ด้วย ST03 | `_archive_docs/EA_CORE_ST03_LOOP_PLAN.md` |
| live portfolio (source of truth) | `DEMO_DEPLOYMENT_PLAN.md` |
| backlog + coverage matrix เต็ม | `MASTER_BACKLOG.md` |
| ทะเบียน EA + scoring rubric + kill-reason | `EA_SCORECARD_AND_REGISTRY.md` |
| แผนที่ไฟล์/5 ที่อยู่ | `PLATFORM_INDEX.md` · `README.md` |
| สถาปัตยกรรม+วิธีใช้ EA_CORE / EA_Template | `docs/EA_CORE_AND_TEMPLATE_GUIDE.md` |
| design "สมอง" เดิม (archived, superseded) | `_archive_docs/RECOVERED_PLATFORM_DESIGN_20260614.md` |
| automation/MT5 headless | `AUTOMATION_GUIDE.md` · `docs/MT5_AUTOMATION.md` |
| รับ source ใหม่ | `INTAKE_QUEUE.md` |
| idea จาก 200-prompt PDF | `_archive_docs/STRATEGY_200_ANALYSIS.md` |

---

## 9. กฎเหล็ก (ย้ำ)
- อย่าเชื่อ report เก่าบนดิสก์ — rerun ด้วย locked .set ก่อนตัดสินเสมอ.
- ปิด MT5 GUI ก่อนรัน automation (script abort ถ้าเปิด).
- ของก้อนใหญ่กลั่นด้วย script ไม่โหลดดิบเข้า context · ทุกงานใหญ่ commit git.
- grid/martingale ใช้ report DD + every-tick ไม่ใช่ MC อย่างเดียว.
- monitor metric (Myfxbook/Excel/FX Blue) = ดูเพื่อ "วิเคราะห์" เท่านั้น **ไม่ใช่ตัว reject EA** —
  การ reject ใช้ (magic,symbol) attribution + เทียบ backtest ตาม section 6 เท่านั้น.


