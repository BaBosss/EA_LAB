# HANDOFF → next session: ปิด ORDER-105 (Contract D) — เหลือขั้นสุดท้ายขั้นเดียว

> อ่าน `PROJECT_STATE.md` → this file. ถ้าขัดกับ repo เชื่อ repo. Design source เป๊ะ =
> `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` **§20.8 Contract D + §20.7 @ `4eb839d`** ·
> order + binding annex = AGENT_TASKBOARD `## ORDER-105` (rev01) + `docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md` (pinned decisions #1-32)

## สถานะ ณ ตอนเขียน (2026-07-17 ~10:50)

**Contract D เสร็จ 99% — ทุกอย่าง build + verify แล้ว เหลือแค่รอ verdict blind review รอบ 7 (final) แล้ว commit.**

- **Blind review รอบ 7 อาจกำลังรัน/จบแล้ว** ตอน session เก่าปิด: เช็ค `grep 'REVIEW7 VERDICT' docs/memory_control/CODEX_ORDER105_RESULT.md` ก่อนทำอะไร (ผลเขียนลง result file โดย Codex เอง — เชื่อไฟล์ ไม่ใช่ exit code) ถ้าไฟล์ไม่มี section `## Independent review round 7` = โดนตัดกลางทาง → relaunch:
  ```
  '/c/Users/patip/AppData/Local/OpenAI/Codex/bin/3135b80b111fd431/codex.exe' exec -m gpt-5.6-sol -c model_reasoning_effort=high --skip-git-repo-check - < docs/memory_control/CODEX_ORDER105_REVIEW7_PROMPT.md
  ```
- **ประวัติ review:** design-review NEEDS-CHANGES(13) → build → review รอบ 1-6 = REWORK 5→2→2→2→1 ทุก finding ถูกแก้ + มี negTest ถาวรครบ · รอบ 6 ยืนยัน recovery state machine ทุก branch แล้ว → รอบ 7 ตรวจแค่ COMPLETED-classification fix สุดท้าย + no-regression → **คาด ACCEPT สูง**
- **Gate ล่าสุด (ก่อนส่งรอบ 7):** ORDER-105 suite **105/105 ×2** (case-set byte-identical) · ORDER-103 41/41 · ORDER-101 25+1 known pre-existing (`cross-HEAD-zero-diff`) · `-Strict`/`-Audit`=0 · check_state CLEAN · parser 0 · `evidence-manifest.jsonl` = 0 bytes (ห้ามมี event จริง — no-backfill)
- **Working tree (ยังไม่ commit, path ORDER-105 ล้วน):** `scripts/experiment_event_log.ps1` · `scripts/check_experiment_events.ps1` · `docs/memory_control/experiment_events/` (schema 2 + manifest) · `scripts/_test/run_order105_negative_tests.ps1` (ใหม่) · `scripts/_test/run_order103_negative_tests.ps1` (แก้ fixture) · `.gitattributes` (แก้) · `docs/memory_control/CODEX_ORDER105_*.md` (result + prompts) — **`.githooks/pre-commit` commit ไปแล้ว** (session อื่นพาไปกับ `cf45bf4a`)

## ถ้า REVIEW7 = ACCEPT → ปิดงานตามลำดับนี้

1. **Commit ทั้งชุด path-limited ผ่าน production hook (ห้าม --no-verify, ห้าม git add -A):**
   ```
   git add docs/memory_control/CODEX_ORDER105_RESULT.md docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md \
     docs/memory_control/CODEX_ORDER105_*PROMPT*.md scripts/experiment_event_log.ps1 \
     scripts/check_experiment_events.ps1 docs/memory_control/experiment_events/ \
     scripts/_test/run_order105_negative_tests.ps1
   git commit --only -F <msgfile> -- <ทุก path ข้างบน> .gitattributes scripts/_test/run_order103_negative_tests.ps1
   ```
   เช็ค `git rev-parse HEAD` ก่อน stage · `git reset -q HEAD -- <path เรา>` ก่อนถ้า index มีของ session อื่น · msg: `[claude] ORDER-105 Contract D COMPLETE: locked JSONL event log + schemas + evidence manifest + staged checker (7 blind review rounds)` + `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` (ระวัง `-m` หลัง `--` = pathspec ต้องใช้ -F ก่อน --)
   ⚠️ hook จะรัน `check_experiment_events.ps1` กับ staged event paths — ทุกไฟล์ event เป็นไฟล์ใหม่/ว่าง ควรผ่าน ถ้าบล็อกอ่าน diagnostic
2. **Mark REVIEWED บน taskboard:** แก้ header block `## ORDER-105` → `REVIEWED/ACCEPT (Claude 2026-07-17) — 7 blind review rounds ...` + เพิ่มสรุปผลใน block → commit path-limited (protected-set hook: ถ้า RECONCILE_EXCEPTIONS mismatch ใช้ pattern regen จาก staged — สคริปต์ตัวอย่าง = scratchpad session เก่า `gen_staged_exceptions.ps1` ดูวิธีใน result file "Rework round 1")
3. **PROJECT_STATE decision log:** เพิ่มแถว Contract D ปิด (commit path-limited แยก)
4. `scripts/make_status.ps1` ถ้ามี
5. **Memory:** เขียน `contract-d-closed.md` (type: project) — Contract D ปิด, 7 review rounds, event log dormant รอ experiment แรก, MVP-2 ยัง B1-gated + อัปเดต MEMORY.md
6. รายงาน user

## ถ้า REVIEW7 = REWORK(n)

Routing ใหม่ (user เคาะ 2026-07-16, commit `283d341d`): **Claude แก้เอง — Codex ห้าม build.** แก้ → parse-check → รัน suite 105 ×2 + 103 + 101 → เขียน rework round ถัดไป → blind review รอบ 8 (prompt แบบ REVIEW7 เปลี่ยนเลข) → วนจน ACCEPT → ปิดตามข้างบน

## Gotchas (จ่ายจริงมาแล้วทั้งหมด session 2026-07-16/17)

- **Codex prompt = neutral QA words เท่านั้น** (ห้าม attack/bypass/abuse/breach/tamper/leak/inject) — content-filter ฆ่าตอนจบหลังเผา 337k tokens มาแล้ว · grep prompt ก่อนยิงทุกครั้ง
- **เชื่อ result file ไม่ใช่ exit code** — wrapper exit 0 ทั้งที่โดน capacity/filter ตัด · เช็ค `grep -icE 'usage limit|at capacity|flagged for' <log>` ด้วย
- **Codex quota:** user เพิ่ง reset (17 ก.ค.) · "at capacity" = server เต็มชั่วคราว รอ 10-15 นาที relaunch ได้ · "usage limit ... try again at <date>" = quota หมดจริง หยุดถาม user
- **Norton:** user ใส่ exclusion `D:\EA_LAB` + `%TEMP%` แล้ว แต่ถ้าไฟล์หาย/Permission denied ผิดปกติ = Norton quarantine → ให้ user restore
- **Shared worktree:** session อื่น commit ตลอดเวลา — HEAD ขยับ = ปกติ ห้าม rewrite · commit path-limited เสมอ · working-tree edit ของเราอาจโดน commit อื่นกวาดไป (เกิดแล้ว 2 ครั้ง ผลลัพธ์ intact แต่เช็ค byte ก่อนเชื่อ)
- **suite ORDER-101 ใช้เวลา 15-30+ นาที** — timeout ต้องกว้าง · `cross-HEAD-zero-diff` FAIL 1 ตัว = pre-existing ไม่ใช่ regression
- **ห้าม:** สร้าง event จริงใน repo (no-backfill) · แก้ §20 draft · rollback commit ที่เกิดแล้ว · Codex ตัดสิน verdict เอง

## ไฟล์อ้างอิงหลัก

- ประวัติ build/review เต็ม 7 รอบ = `docs/memory_control/CODEX_ORDER105_RESULT.md` (อ่าน section ท้ายๆ พอ)
- Binding annex (pinned #1-32) = `docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md`
- Routing flip decision = PROJECT_STATE decision log 2026-07-16 + memory `agent-workflow-post-fable`
