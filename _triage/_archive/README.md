# `_triage/_archive/` — งานที่ปิดแล้ว

> ⚠️ canonical entry = `PROJECT_STATE.md` · โฟลเดอร์นี้ owns: **ผลผลิตของงานที่ปิดแล้วเท่านั้น** ห้ามเอาไปอ้างเป็นสถานะปัจจุบัน
>
> ของที่ยัง**ใช้อ้างอิงอยู่**ยังอยู่ที่ `_triage/` ชั้นบนตามเดิม — ที่ลงมาข้างล่างนี้คือของที่ **order เจ้าของมันปิดไปแล้ว**
> อยากรู้ว่าเรื่องไหนจบยังไงแบบย่อ ให้ดู [`TASKBOARD_DIGEST.md`](../../TASKBOARD_DIGEST.md) ก่อน แล้วค่อยลงมาขุดที่นี่

## กติกาการย้ายเข้า (trigger เดียว)

order เปลี่ยนสถานะเป็น **`REVIEWED*`** เมื่อไร → คอมมิตเดียวกันนั้นย้าย 3 อย่างพร้อมกัน:
1. บล็อก order → `ARCHIVE_TASKBOARD_2026-07A.md` (verbatim, append-only)
2. ไฟล์ `_triage/ORDERxxx_*.md` ที่ใบนั้นอ้าง → โฟลเดอร์ที่ตรงหมวดข้างล่าง
3. `powershell -File scripts/make_taskboard_digest.ps1` เพื่ออัปเดตสรุปย่อ

รายละเอียดเต็ม + เหตุผล → [`docs/WORK_LIFECYCLE.md`](../../docs/WORK_LIFECYCLE.md)

## โครง

| โฟลเดอร์ | มีอะไร |
|---|---|
| `codex_reviews/order170_risk_admission/` | ORDER-170 risk-admission audit 8 รอบ (PROMPT + RESULT + raw log) |
| `codex_reviews/order174_correlation/` | ORDER-174 correlation audit 4 รอบ + ORDER-154 audit รอบแรก |
| `codex_reviews/order129_132_138/` | Codex audit ของ ORDER-129 / 132 / 138 / 138B |
| `codex_reviews/system_and_roadmap/` | system review · roadmap review · control-room design · 5yr OS vision |
| `handoffs_closed/` | handoff ที่ทุกรายการในนั้นถูกติดตามแล้ว (ปิดจริง ไม่ใช่แค่เก่า) |
| `verdicts/order076-098/` · `order104-126/` · `order135-149_results/` | verdict/result ของ order ตามช่วงเลข |
| `audits_and_investigations/` | audit/investigation ที่ไม่ใช่ verdict ของ EA |
| `attestations/` | CR-002 terminal attestation |
| `frameworks_superseded/` | แผน/กรอบที่มีของใหม่มาแทนแล้ว (ระบุตัวแทนไว้ในตารางล่าง) |
| `campaigns_closed/` | ผลดิบของ campaign ที่ปิดแล้ว (mass smoke, ORDER-091A, ORDER-111) |
| `one_off_analyses/` | บทวิเคราะห์ครั้งเดียวจบ |
| `corpora_cold/` | คลังดิบที่กลั่นเป็น catalog แล้ว (WOBR · BotMogul · YouTube · ChatGPT) |

`**/*.log` ในโฟลเดอร์นี้ **ไม่เข้า git** โดยตั้งใจ (~16MB transcript ดิบ) — คู่ `PROMPT`/`RESULT` ข้างๆ คือบันทึกที่อ่านได้จริง

## `frameworks_superseded/` — อะไรแทนอะไร

| ไฟล์ | ถูกแทนด้วย |
|---|---|
| `CODEX_ROADMAP_2026-07-19.md` + `_PROMPT` | `ROADMAP.md` (ครึ่งหลัง APPROVED 2026-07-19) |
| `FABLE_REVIEW_PROMPT.md` | `_archive/codex_reviews/system_and_roadmap/CODEX_RESETTLE_REVIEW_2026-07-18.md` |
| `KNOWLEDGE_SYNTHESIS_EA_DEVPLAN.md` | ยังไม่มีตัวแทนเต็ม — ส่วนที่ยังมีชีวิตถูกยกไป `MASTER_BACKLOG.md` §9 แถว D15/D16 |
| `XAU_STRATEGY_WAVE12_2026-07-19.md` | Wave 1/2 จบแล้ว · 3 ดีไซน์ที่ไม่เคยสร้าง = `MASTER_BACKLOG.md` §9 แถว D5 |

## ⚠️ ลิงก์ archive-to-archive

ไฟล์ในนี้อ้างถึงกันเองด้วยชื่อเดิม `_triage/<NAME>` ซึ่งตอนนี้ย้ายแล้ว **ลิงก์พวกนั้นตายเงียบ** — เจตนา ไม่ใช่บั๊ก
(ไล่แก้ทุกจุดไม่คุ้ม และไฟล์เหล่านี้คือประวัติ ไม่ใช่เอกสารที่ยังเดินอยู่). วิธีหา: ชื่อไฟล์ยังเหมือนเดิมทุกตัว
ใช้ `git ls-files _triage/_archive | grep <ชื่อ>` หรือ `find _triage/_archive -name '<ชื่อ>'` เจอแน่นอน

**ไม่มีเอกสารที่ยังเดินอยู่ (live doc) ตัวไหนลิงก์เสียจากการย้ายรอบนี้** — Wave 2 แก้ทุก citation พร้อมกับการย้าย
