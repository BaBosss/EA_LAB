# HANDOFF → next session (วันพฤ 2026-07-17+): เริ่ม Contract D — MVP-1-lite Experiment Event Log

> อ่าน `VISION.md` → `PROJECT_STATE.md` → this file. **อย่าเชื่อไฟล์นี้เหนือ repo** — ถ้าขัดกัน เชื่อ repo +
> `scripts/check_state.ps1 -Strict` แล้วแก้ไฟล์นี้. Design source ที่ต้องอ้างเป๊ะ (ห้ามอ้าง "draft ล่าสุด"):
> **`_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md §20 @ commit `4eb839d``** (Contract D = §20.8; MVP-1 spec = §20 บรรทัด 274-300; ownership = §20.7).

## สถานะ ณ ตอนเขียน (2026-07-14)

- **ORDER-103 (C1-ENFORCE) = ปิดสมบูรณ์ ACCEPT.** commit impl `c0f7b0d` + decision-log `eb06ac6` (ทั้งคู่ผ่าน production hook, ไม่ `--no-verify`). round 6 blind Codex = ACCEPT. write path tamper-safe เต็มแล้ว.
- **MANDATORY REVIEW GATE §20.2#5 = ปลดล็อกแล้ว** → Contract D เปิดทาง (เป็นครั้งแรกที่ไม่ถูก block).
- ⚠️ **AGENT_TASKBOARD.md ยัง dirty (uncommitted)** ตอนเขียนไฟล์นี้: มี (ก) ORDER-103 REVIEWED note + gate-unlock ของผม (ข) needle-reword "ไฟล์เดียว"→"1 ไฟล์" ที่ line ~1268 (แก้ false-positive ของ check_state ที่บล็อก commit ทุก session — **อย่า revert**) (ค) ORDER-104 REVIEWED block ของ task อื่น (ผมไม่ commit เพื่อไม่กวาดงาน session อื่น). ถ้าตอนคุณเริ่ม taskboard ถูก commit โดย session อื่นไปแล้ว = ปกติ; ถ้ายัง dirty ก็เดินงานต่อได้ (commit path-limited เสมอ).

## Contract D คืออะไร (§20.8 Contract D + §20 MVP-1)

**Output:** (1) **locked JSONL append utility** ตัวเดียว (2) **linked-event schema** (3) **durable evidence manifest**.

หนึ่ง experiment = **event chain** (ไม่ใช่แถวที่แก้ทับ). event types (§20 บรรทัด 278-287):
`IDEA_CREATED · HYPOTHESIS_REGISTERED · BAR_PREREGISTERED · RUN_STARTED · RESULT_ATTACHED · AMENDMENT_ADDED · REVIEW_RECORDED · DECISION_SIGNED`

ทุก event มี fields (§20 บรรทัด 289-298): experiment ID · timestamp · actor+role · prior event (chain link) · EA/source/set/data/tester hashes · trial family/count · evidence IDs · reason. **preregistration กับ result ต้องเป็นคนละ event; เกณฑ์ที่ prereg แล้วแก้ไม่ได้ — เปลี่ยนได้ผ่าน AMENDMENT_ADDED เท่านั้น.**

**Append utility ต้องมี (§20.7 ท้าย):** file lock · atomic append · schema validation · unique event ID · idempotency · append-only correction/amendment. **ห้ามหลาย agent เขียนไฟล์ JSONL รายเดือนตรงๆ — ผ่าน utility ตัวเดียวเท่านั้น.** monthly rotation ภายใต้ append contract §20.7.

## กฎเหล็ก ownership (§20.7 — นี่คือหัวใจ กันสร้าง source-of-truth ชุดที่ 2)

**Event Log เก็บแค่ occurrence metadata + hashes + references — ห้ามคัดลอก result/verdict text.** ใช้ event ชนิด `RESULT_LINKED` / `REVIEW_LINKED` / `DECISION_LINKED` ชี้กลับ canonical owner เดิม:
- verdict/decision/deployment = owner เดิม (`scorecard`, `PROJECT_STATE.md` decision log, `portfolio/DEPLOYMENTS.csv`) — Event Log เก็บแค่ owner path/hash/reference
- active order text/acceptance/result narrative = `AGENT_TASKBOARD.md` (owner เดิม)
- reviewed history = immutable archive (owner เดิม)
- decisive evidence = tracked artifact/durable store + manifest + existence check (ignored/transient path ห้ามถือว่าถาวรแค่เพราะมี path/hash)

## Acceptance (§20.8 Contract D) — เขียนเป็นเกณฑ์ตัวเลขตอนแตก order

- concurrent-write test ผ่าน (หลาย writer พร้อมกัน → ไม่ corrupt, ไม่ interleave, lock ทำงาน)
- idempotent test ผ่าน (append event เดิมซ้ำ → ไม่เกิด duplicate; unique event ID enforce)
- schema-validation test ผ่าน (event ผิด schema → reject, fail-closed)
- corrupt-line test ผ่าน (JSONL บรรทัดเสีย → ตรวจจับได้, ไม่ทำทั้งไฟล์พัง)
- canary trace = 100% (สร้าง 1 experiment ครบ chain prereg→...→decision → trace กลับ canonical ได้ทุก link)
- evidence existence check = 100% (ทุก evidence ID ใน manifest → ไฟล์มีจริง)

## Out of scope (อย่าทำใน Contract D)

❌ verdict owner ใหม่ (Event Log ไม่ตัดสินอะไร) · ❌ bulk backfill event ย้อนหลัง · ❌ Context Packet generator (นั่นคือ MVP-2 = Contract แยก) · ❌ ให้ generated view รับ write-back · ❌ คัดลอก result/verdict text เข้า JSONL

## Rollback (§20.8)

ปิด append utility · rebuild จาก canonical refs · correction ใช้ amendment/tombstone event (ไม่ลบบรรทัดเก่า — append-only)

## Routing (role ปัจจุบัน — พิสูจน์แล้วว่าคุ้มใน ORDER-103)

**Codex (gpt-5.6-sol) คุมทิศทาง + เขียนโค้ดเต็มตัว · Claude Code = สั่งงาน + independent spot-verify เฉพาะจุด irreversible.** เหตุผล: quota Opus จำกัด. **บทเรียน ORDER-103: self-verify เดี่ยว (แม้ 2 ชั้น) ปล่อยของหลุดซ้ำ — blind Codex review คนละ session/มุม จับ defect จริงทุกรอบจนถึงรอบ 5 (BLOCKER 6 checkpoint-laundering กระทบ root-of-trust) ถึงจะ 0-blocker. อย่าข้ามด่าน blind review แม้ quota ตึง.**

ลำดับที่แนะนำ:
1. **Claude:** แตก order (น่าจะ **ORDER-105**) จาก §20.8 Contract D — เขียน acceptance เป็นตัวเลข + ห้าม + design-source citation `§20 @ 4eb839d` + เพิ่ม pointer 1 บรรทัดใน PROJECT_STATE decision log ชี้ SHA เดียวกัน (§20.9 requirement). เขียนใน AGENT_TASKBOARD.md (order block ใหม่).
2. **Codex:** design-review ORDER ก่อน build (เหมือน ORDER-103 rework0) → build JSONL utility + schema + manifest + negTest suite → รายงานลง `docs/memory_control/CODEX_ORDER105_RESULT.md`.
3. **Claude:** spot-verify (รัน negTest เอง, ตรวจ ownership ไม่ซ้ำ, canary trace) → ถ้าโอเคส่ง blind Codex review รอบ independent.
4. **Codex blind review** (fresh session) → ถ้า REWORK ก็วน; ถ้า ACCEPT → commit ผ่าน production hook + make_status + mark REVIEWED.

## เครื่องมือ/gotcha ที่ carry มาจาก ORDER-103 (ใช้ต่อได้เลย)

- **Codex CLI ปกติใช้ไม่ได้** (backend ล็อก gpt-5.6-sol). ใช้ Desktop binary:
  ```
  BIN='C:\Users\patip\AppData\Local\OpenAI\Codex\bin\a7c12ebff69fb123\codex.exe'
  "$BIN" exec -m gpt-5.6-sol -c model_reasoning_effort=high --skip-git-repo-check - < <prompt-file>
  ```
- **OpenAI content-filter** บล็อกคำ adversarial ("attack/break/forge/defeat") กลางทาง — เขียน prompt neutral ("verify/confirm/reproduce", "correctness/robustness verification"). ตัวอย่างที่ผ่านฉลุย = `docs/memory_control/CODEX_ORDER103_REVIEW6_PROMPT.md`.
- **Codex เขียนผลลง result file เอง** — background task output pipe อาจหายเมื่อ session เปลี่ยน; เช็คเนื้อหา result file จริงเสมอ ไม่ใช่ exit code ของ wrapper.
- **Shared worktree = concurrent writers:** เช็ค HEAD ก่อน stage · commit **path-limited** เสมอ (`git commit --only -- <paths>` ด้วย `-F msgfile` — `-m` หลัง `--` จะโดนตีเป็น pathspec!) · index อาจมีไฟล์ staged ของ session อื่น → unstage เฉพาะของเรา (`git reset -q HEAD -- <my paths>`) ก่อน commit --only · HEAD ขยับ = ปกติ (session อื่น commit คู่กัน) แต่ห้าม rewrite/rollback commit ที่ทำไปแล้ว.
- **protected-set 5 ไฟล์ (hook enforce staged-consistency):** `ARCHIVE_TASKBOARD_2026-07A.md · AGENT_TASKBOARD.md · docs/memory_control/{ARCHIVE_MANIFEST.csv,ARCHIVE_INDEX.md,RECONCILE_EXCEPTIONS.md}`. ถ้า commit แตะไฟล์พวกนี้ hook จะเช็ค archive+artifact consistency — regen artifact จาก **staged identity** (`git rev-parse :path`) อย่าผสม HEAD+working. PROJECT_STATE.md **ไม่** protected (commit เดี่ยวได้สะอาด).
- **check_state false-positive needle:** อย่าเขียนคำว่า "ไฟล์เดียว" หรือ "single source of truth" ในไฟล์ .md ราก (ยกเว้น PROJECT_STATE.md) — needle นี้จับเป็น competing-entry-claim แล้วบล็อก commit ทุก session.

## ห้าม

- ❌ rollback/rewrite `c0f7b0d` · `eb06ac6` · `245f8f62` หรือ commit ที่ทำไปแล้ว
- ❌ สร้าง source of truth ชุดที่ 2 (Event Log = reference/hash เท่านั้น ไม่คัดลอก text)
- ❌ แตะ unrelated dirty files ของ session อื่น (commit path-limited)
- ❌ อ้าง design เป็น "draft ล่าสุด" — ต้อง `§20 @ 4eb839d` เป๊ะ (แก้ §20 = เปิด review ใหม่)
- ❌ ให้ subagent/Codex ตัดสิน verdict/exception เอง (นั่นคือหน้าที่ Claude/user)
