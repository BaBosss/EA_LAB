# HANDOFF → next session: C1-ENFORCE (memory-OS build, last hardening piece)

> อ่าน `VISION.md` → `PROJECT_STATE.md` → this file. State ทั้งหมดอยู่ใน git + `AGENT_TASKBOARD.md`
> (ORDER-099..102 + "MANDATORY REVIEW GATE" table) + `docs/memory_control/`. **อย่าเชื่อไฟล์นี้เหนือ
> repo** — ถ้าขัดกัน เชื่อ repo + `check_state.ps1` แล้วแก้ไฟล์นี้.

## อยู่ตรงไหน (2026-07-13)

Memory-Controlled OS build เดินครบ **4 orders + ผ่าน mandatory review gate**:
- **A** ORDER-099 (B0 baseline + fact→owner map) = REVIEWED · artifacts `docs/memory_control/{B0_DATASET.csv,B0_REPORT.md,FACT_OWNER_MAP.md}`
- **B** ORDER-100 (`scripts/run_batch.ps1` execution harness) = REVIEWED MVP-0 · 1 doc'd limit (UNC/alias `-Terminal` — fix ก่อน deploy harness ขับ MT5 จริง)
- **C0** ORDER-101 (`scripts/check_taskboard_archive.ps1` reconcile + validator) = REVIEWED
- **C1** ORDER-102 (migration: taskboard index→generated read-only `ARCHIVE_INDEX.md` · archive = append-only log · 12 exceptions closed via `## C1-CLOSURE` + `## REVIEW ORDER-071`) = **DATA ACCEPT · ENFORCEMENT REWORK**

**สถานะปัจจุบันปลอดภัย+ถูกต้อง:** `powershell -File scripts/check_taskboard_archive.ps1 -Strict` = **exit 0** · migration data ถูก, 0 history lost (Codex verify แล้ว) · git = tamper-evidence ตัวจริง.

## งานถัดไป = **C1-ENFORCE** (order เดียว, bounded) — ปิด write-path hole ที่ Codex final review จับ

Codex ยืนยัน migration data รับได้ แต่ **validator กัน tamper เฉพาะ 131 split blocks ไม่กัน blocks ที่ append หลัง split** (รวม `C1-CLOSURE` เอง + ORDER-071 rev01) → แก้แล้ว regenerate manifest = "bless" การแก้ได้. 4 fix:

1. 🔴 **Append-CHAIN integrity** (แทน superset-vs-split เดี่ยว): ทุก archive-changing commit ต้องพิสูจน์ staged archive bytes = **raw-byte prefix-extension** ของ archive blob จาก parent commit · audit เดิน chain จาก anchor ผ่านทุก commit ที่แตะ archive · **manifest regen ต้อง bless mutation ของ existing append ไม่ได้**. negTests: mutate `C1-CLOSURE`/rev01 append → exit 2 · append raw suffix ใหม่ (ไม่แตะ prefix) → pass.
2. 🔴 **Fail-closed staged-snapshot hook** (= C1a ที่ defer): `.githooks/pre-commit` ต้อง (i) **fail-CLOSED ถ้าไม่มี PowerShell** (ตอนนี้ fail-open ที่ `.githooks/pre-commit:5`) (ii) ตรวจ staged archive เป็น exact extension ของ `HEAD:archive` (iii) staged manifest/index/exceptions ตรง staged archive (iv) exact staged allowlist · test ใน **temp repo/index ไม่ใช่ shared worktree** · `--no-verify` = policy bypass ตาม AGENTS (hook message ห้ามแนะ bypass).
3. 🟡 **Source-A exact binding:** ตอนนี้ปิดทุก exception ของ canonical-id เดียวผ่าน `REVIEW ORDER-<id>` ใด ๆ (`check_taskboard_archive.ps1:1089`) → bind ด้วย **exact target block-id/hash** กัน phase-review หรือ forged review ปิดข้าม.
4. 🟡 **hash-object atomicity:** เปลี่ยน archive identity จาก `git rev-parse HEAD:ARCHIVE...` เป็น **`git hash-object <file>` / `git rev-parse :ARCHIVE...`** (staged/working-tree content) → archive-changing migration ลง **atomic commit เดียว** (ตอนนี้ต้อง re-pin 2 commit).

**Routing:** subagent build (Sonnet) → **Opus verify เอง (รัน test + อ่านโค้ด + เจาะ path ที่เคยพลาด: รันข้าม HEAD/commit จริง ไม่ใช่ session เดียว)** → **blind Codex review ก่อน accept**. แนะ **ให้ Codex design-review ตัว C1-ENFORCE order ก่อน build** (append-chain = design ยาก, review ก่อนสร้างคุ้ม — เหมือน C1).

## ห้าม
- ❌ rollback/rewrite migration commits (be45d4b/0e67e1d ฯลฯ — HEAD ถูกแล้ว)
- ❌ เริ่ม **Contract D (MVP-1-lite event-log)** จนกว่า C1-ENFORCE ปิด (§20.2 #5 — write path ยังไม่ tamper-safe เต็ม)
- ❌ แก้ bytes ของ archived block เดิม (append-only) · worker ตัดสิน exception เอง (Opus)
- ❌ แตะ unrelated dirty files (session อื่น commit อยู่บน master คู่กัน — ดู memory `shared-worktree-concurrent-writers`: commit path-limited, เช็ค HEAD ก่อน stage)

## กติกาที่ยึดมาตลอด build (ได้ผล)
self-verify เดี่ยวปล่อยของผิดหลุด**ทุกใบ** → **Codex blind review (คนละค่าย) จับได้** · commit แยก + `scripts/make_status.ps1` หลัง commit · guard `scripts/check_state.ps1 -Strict` ต้อง CLEAN · order ทุกใบอ้าง `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md §20 @ 4eb839d`.
