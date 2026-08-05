# HANDOFF 2026-07-19 — template hardening จบแล้ว · คุมงานต่อผ่าน session เดียว

**สำหรับ:** session ถัดไปที่ user ใช้คุมงานทั้งหมด (แทนการเปิดหลาย session คู่ขนาน)
**สถานะ ณ handoff:** อัปเดต 2026-07-19 ท้าย session (single-session control) · working tree มีไฟล์ค้างของ session อื่น (.obsidian/STATUS.html/_mt5_auto ต่างๆ) — **อย่ากวาด commit รวม, path-limit เสมอ** · ⚠️ order numbering เคยชน (133 StoMultiTap ของ session คู่ขนาน · ST03-leverA = 135 · overlay = 136 · StoMultiTap = 137) — collision reconcile แล้ว

## 1. อะไรปิดไปแล้ววันนี้ (อย่ารื้อ)

| Order | สถานะ | commit หลัก |
|---|---|---|
| ORDER-132 + 132b | DONE+REVIEWED — transactional exits + persist scoping, Codex 20 findings → fix 12 / defer 4 / reject 2 | `0dcf60e2` + `1a0dd7ff` |
| ORDER-138 (#1-4) + 138b + 138c | DONE+REVIEWED (session คู่ขนาน) — `RC_AdoptLegacyHalt` fail-closed migration consent · atomic pair persist + commit-marker · closing-intent persisted · test tester-only guard · Codex audit 2 รอบ | `a1d0a54a` → `29b31b76` → `ef24a267` |
| ORDER-119 | REVIEWED: chassis-cell DEAD (ST03 flat-lot MACD signal 0/6 both-window) | `09b34913` |
| ORDER-135 | REVIEWED: ST03 lever-A engine test chassis-cell DEAD (generic DCA 0/9, แค่ leverage regime-dep) — **แต่ scope = chassis-cell ไม่ใช่ concept ถาวร** | `2dcbc239` + `754d2a60` |
| ORDER-126 | DONE+REVIEWED: NO LIFT, keep demo 991070 as-is | (session คู่ขนาน) |
| ORDER-131 | CLOSED: Boss_18 drift = benign FP layout | `1217b1da` |
| ORDER-125 | DONE+REVIEWED: MaxHoldBars = NO LIFT DEAD-ON-GRID; Boss_14 baseline re-pin n=84 (partial-leak bugfix, money-identical) | `b6ca0f6e` + `5252f24d` |
| P1 ops | DONE: gist account-redact + credential-inventory skeleton (2 MASTER_BACKLOG P1 ปิด) | `a241176b` |

### 🆕 กฎใหม่ที่ user ratify วันนี้ (สำคัญ — อ่านก่อน judge EA ตัวถัดไป)
**ENGINE-EDGE class (CLAUDE.md VERDICT GATE ข้อ 1 · decision log 2026-07-19 · memory `feedback-engine-edge-class`):** "flat-lot PF<1 ขณะ escalated PF>1" **เลิก auto-kill** → เดินต่อได้ภายใต้กรง 5 ข้อ (worst-case ≤15% equity · **BWD 2020-22 HARD** · Model-4 บังคับ · MC ruin ≤2% · label engine-edge = sizing เล็กถาวรห้าม size-up ตาม PF). flat-lot probe = เครื่องวินิจฉัยว่า edge อยู่ signal/engine ไม่ใช่ใบมรณะ. **uncapped ruin (no SL + no cap + geometric) ยังฆ่าทันที.** precedent = NuiIndy (geometric+CutLoss30 live PF~2.0). first application = ORDER-135 (ผ่านกรงแล้วยังตาย = earned, กฎ balance ถูก).

**ผลรวมเชิงระบบ:** template core (Persist/RiskControl/Execution/ExitManager/Stack/Kangaroo/LabCore) ผ่าน SEV-1 pack 3 รอบ (129 → 132 → 138) + Codex audit ครบทุกรอบ · cage 8/8 CLEAN · **code blocker ของ live rollout = ปลดหมดแล้ว**

## 2. รอ USER ทำ (ปลดล็อคแล้ว — ก่อน roll binary ใหม่ขึ้นบัญชีจริง)

เดิน checklist `ea_template/PERSIST_MIGRATION_ORDER132.md` ตามลำดับ: F3 snapshot GV → demo attach → เช็ค journal `[PERSIST] migrated` → restart 1 รอบยืนยัน state → ค่อย Boss_14 GBPJPY live. จุดเพิ่มจาก 138: upgrade บัญชีตัวเองที่มี legacy state ต้องตั้ง **`RC_AdoptLegacyHalt=true` หนึ่ง attach แล้วปิดกลับ false** (ไม่ตั้ง = OnInit FAIL โดยตั้งใจ, กัน state ข้ามบัญชี — gate ครอบทุก legacy key รวม `rc_peak_eq`). Boss_16: เช็ค F3 หา `Boss2_..._k16_pair_a/b` (pair liquidation in-flight) ก่อน swap binary — มี = รอ resolve/flat ก่อน. อีกงานเร่งของ user: **`gh auth login -h github.com`** (token BaBosss ตาย — dashboard มือถือเน่าเงียบ, ORDER-128 leg ค้าง)

## 3. คิวงานถัดไป (เรียงแล้ว — ORDER-125 ปิดแล้ว ออกจากคิว)

1. **ORDER-124** — chassis chores ×3 (taskboard :148; baseline ปลดบล็อคแล้ว)
2. **ORDER-136** — escalation-MM overlay campaign บน validated cohort (Wave1=Boss_17 Wave5, XAU H4) — **money-adjacent (escalation), judge ที่ expectancy+worst-case DD ไม่ใช่ PF อย่างเดียว · pace 1-2 cell/รอบ ห้าม burst** (memory: feedback-pacing-batch-small). ⚠️ ตัวนี้ = signal-edge + MM overlay (funnel ปกติ) ต่างจาก ENGINE-EDGE (ST03)
3. Backlog มีเงื่อนไข (จาก 132b defer — เปิด order ใหม่เฉพาะเมื่อมี EA mode-93 หรือ partial-close ขึ้น live จริง): X1 milestone persist ข้าม restart · S1/S2 ladder restart/cancel reconcile · S3 continuous margin re-budget

### งานฝั่ง USER (ไม่ใช่ Claude queue)
- **ST03 standalone optimize** — chassis dead แต่ standalone (LOT_Repeat/tp3/near/spacing/vol-gate tuned, 30+ sets ใน worktree `_mt5_auto/`) = **PARKED-VERIFY(user)** ไม่ตายถาวร. handoff เต็ม + open levers (spacing UNSWEPT/per-sym TP/LR×vol-gate) = `_triage/HANDOFF_ST03_OPTIMIZE_2026-07-19.md`. both-window winner → ping lead → funnel
- **ORDER-137** StoMultiTap ADX-gate fork (`_triage/HANDOFF_ORDER137_STOMULTITAP.md`, PARKED-VERIFY)

## 4. Gotchas ที่จ่ายเงินเรียนมาแล้ว (session ใหม่ต้องรู้)

- **0-trade artifact โผล่ได้แม้ tester ว่าง** (Boss_18 เจอวันนี้ทั้งที่ไม่มี sweep ชน) → เจอ 0-trade ผิดคาด = **re-run เดี่ยวก่อนสรุป drift เสมอ** ห้ามรีบ isolate
- **Boss_18 = FP-boundary-sensitive** (kill fire ที่ eqDD~25% พอดี, 6020 trades) — drift เล็กๆ เฉพาะตัวนี้ = เช็ค class benign ตาม ORDER-131 ก่อนตกใจ
- **cage ไม่มี cell StackMode=93** — แตะ `Stack.mqh` เมื่อไหร่ ต้อง A/B ด้วย `_mt5_auto/ab_sets/order132_93probe.set` (Boss_11 XAU H1 2024.01-07 M1 → ต้องได้ **net 347.16 / PF 62.01 / 6 trades / eqDD 3.46%** เป๊ะ)
- แก้ `ea_template/core/*` = compile 0/0 ×9 + `tests/run_tests.ps1` **7/7** (138 เพิ่ม `PersistIntent_Test`; `PersistMigrate_Test` มี `.set` เปิด acct gate) + `scripts/tpl_regression.ps1` CLEAN ก่อน commit เสมอ · Codex blind-audit บังคับเฉพาะ money/irreversible code
- codex-rescue agent เคย **background-แล้วหยุดรอ ×2** (2026-07-19) — brief ต้องสั่ง foreground ชัด; ถ้าหยุดกลางคัน = SendMessage nudge กู้ได้, อ่าน result file ไม่ใช่ exit code
- `PersistMigrate_Test` = **tester-only โดยตั้งใจ** (มัน `GlobalVariablesDeleteAll("Boss")` — attach chart จริง = ล้าง state ทุก Boss) — อย่าถอด guard
- shared worktree: เช็ค `git log` + HEAD ก่อน stage ทุกครั้ง, commit path-limited

## 5. เอกสารอ้างอิงเร็ว

- Audit: `_triage/CODEX_ORDER129_AUDIT.md` · `_triage/CODEX_ORDER132_AUDIT.md` · 138 สองรอบ = `_triage/CODEX_ORDER138_AUDIT.md` + `_triage/CODEX_ORDER138B_REAUDIT.md` + triage `_triage/CODEX_ORDER138_AUDIT_TRIAGE.md`
- Migration doc: `ea_template/PERSIST_MIGRATION_ORDER132.md`
- แผน implementation 132: `docs/superpowers/plans/2026-07-19-order132-transactional-exits-persist-scoping.md`
- B1 rows ครบถึง ORDER-138 แล้ว (`docs/memory_control/B1_DATASET.csv`)
- Roadmap ทิศทาง (FIX-THEN-SCALE, FIX=ops/evidence 80/20): `_triage/CODEX_ROADMAP_2026-07-19.md` — direction 2 (terminal attestation/judge-readiness) = ops order ถัดไปหลังคิว §3
