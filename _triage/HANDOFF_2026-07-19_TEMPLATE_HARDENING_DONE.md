# HANDOFF 2026-07-19 — template hardening จบแล้ว · คุมงานต่อผ่าน session เดียว

**สำหรับ:** session ถัดไปที่ user ใช้คุมงานทั้งหมด (แทนการเปิดหลาย session คู่ขนาน)
**สถานะ ณ handoff:** HEAD = `ef24a267` · working tree มีไฟล์ค้างของ session อื่น (.obsidian/STATUS.html/_mt5_auto ต่างๆ) — **อย่ากวาด commit รวม, path-limit เสมอ**

## 1. อะไรปิดไปแล้ววันนี้ (อย่ารื้อ)

| Order | สถานะ | commit หลัก |
|---|---|---|
| ORDER-132 + 132b | DONE+REVIEWED — transactional exits + persist scoping, Codex 20 findings → fix 12 / defer 4 / reject 2 | `0dcf60e2` + `1a0dd7ff` |
| ORDER-138 (#1-4) + 138b + 138c | DONE+REVIEWED (session คู่ขนาน) — `RC_AdoptLegacyHalt` fail-closed migration consent · atomic pair persist + commit-marker · closing-intent persisted · test tester-only guard · Codex audit 2 รอบ | `a1d0a54a` → `29b31b76` → `ef24a267` |
| ORDER-119 | REVIEWED: DEAD-OPTIMIZED (ST03 flat-lot MACD-reversion) — campaign ปิด | (session คู่ขนาน) |
| ORDER-126 | DONE+REVIEWED: NO LIFT, keep demo 991070 as-is | (session คู่ขนาน) |
| ORDER-131 | CLOSED: Boss_18 drift = benign FP layout | `1217b1da` |

**ผลรวมเชิงระบบ:** template core (Persist/RiskControl/Execution/ExitManager/Stack/Kangaroo/LabCore) ผ่าน SEV-1 pack 3 รอบ (129 → 132 → 138) + Codex audit ครบทุกรอบ · cage 8/8 CLEAN · **code blocker ของ live rollout = ปลดหมดแล้ว**

## 2. รอ USER ทำ (ปลดล็อคแล้ว — ก่อน roll binary ใหม่ขึ้นบัญชีจริง)

เดิน checklist `ea_template/PERSIST_MIGRATION_ORDER132.md` ตามลำดับ: F3 snapshot GV → demo attach → เช็ค journal `[PERSIST] migrated` → restart 1 รอบยืนยัน state → ค่อย Boss_14 GBPJPY live. จุดเพิ่มจาก 138: upgrade บัญชีตัวเองที่มี legacy state ต้องตั้ง **`RC_AdoptLegacyHalt=true` หนึ่ง attach แล้วปิดกลับ false** (ไม่ตั้ง = OnInit FAIL โดยตั้งใจ, กัน state ข้ามบัญชี)

## 3. คิวงานถัดไป (เรียงแล้ว)

1. **ORDER-125** — vertical-barrier exit `_2_MaxHoldBars` (spec+bars ครบใน taskboard :158; default 0=off byte-identical; host test = Boss_14; bar: recovery-days ลง AND both-window PF ≥1.0 retained)
2. **ORDER-124** — chassis chores ×3 (taskboard :148)
3. **ORDER-136** — escalation-MM overlay campaign บน validated cohort (Wave1=Boss_17) — **pace 1-2 cell/รอบ ห้าม burst** (memory: feedback-pacing-batch-small)
4. Backlog มีเงื่อนไข (จาก 132b defer — เปิด order ใหม่เฉพาะเมื่อมี EA mode-93 หรือ partial-close ขึ้น live จริง): X1 milestone persist ข้าม restart · S1/S2 ladder restart/cancel reconcile · S3 continuous margin re-budget

## 4. Gotchas ที่จ่ายเงินเรียนมาแล้ว (session ใหม่ต้องรู้)

- **0-trade artifact โผล่ได้แม้ tester ว่าง** (Boss_18 เจอวันนี้ทั้งที่ไม่มี sweep ชน) → เจอ 0-trade ผิดคาด = **re-run เดี่ยวก่อนสรุป drift เสมอ** ห้ามรีบ isolate
- **Boss_18 = FP-boundary-sensitive** (kill fire ที่ eqDD~25% พอดี, 6020 trades) — drift เล็กๆ เฉพาะตัวนี้ = เช็ค class benign ตาม ORDER-131 ก่อนตกใจ
- **cage ไม่มี cell StackMode=93** — แตะ `Stack.mqh` เมื่อไหร่ ต้อง A/B ด้วย `_mt5_auto/ab_sets/order132_93probe.set` (Boss_11 XAU H1 2024.01-07 M1 → ต้องได้ **net 347.16 / PF 62.01 / 6 trades / eqDD 3.46%** เป๊ะ)
- แก้ `ea_template/core/*` = compile 0/0 ×9 + `tests/run_tests.ps1` 6/6 + `scripts/tpl_regression.ps1` CLEAN ก่อน commit เสมอ · Codex blind-audit บังคับเฉพาะ money/irreversible code
- `PersistMigrate_Test` = **tester-only โดยตั้งใจ** (มัน `GlobalVariablesDeleteAll("Boss")` — attach chart จริง = ล้าง state ทุก Boss) — อย่าถอด guard
- shared worktree: เช็ค `git log` + HEAD ก่อน stage ทุกครั้ง, commit path-limited

## 5. เอกสารอ้างอิงเร็ว

- Audit ทั้งสาม: `_triage/CODEX_ORDER129_AUDIT.md` · `_triage/CODEX_ORDER132_AUDIT.md` · (138 อยู่ใน commit messages `29b31b76`/`ef24a267`)
- Migration doc: `ea_template/PERSIST_MIGRATION_ORDER132.md`
- แผน implementation 132: `docs/superpowers/plans/2026-07-19-order132-transactional-exits-persist-scoping.md`
- B1 rows ครบถึง ORDER-132 แล้ว (`docs/memory_control/B1_DATASET.csv`)
