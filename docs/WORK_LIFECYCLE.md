# WORK_LIFECYCLE — งานเกิดยังไง ตายยังไง เก็บไว้ตรงไหน

> ⚠️ canonical entry = `PROJECT_STATE.md` · ไฟล์นี้ owns: **วงจรชีวิตของ order/handoff/ไฟล์ triage + กติกากันหลาย session ชนกัน** เท่านั้น
> · verdict ของ EA → VERDICT GATE ใน `CLAUDE.md` · โปรโตคอลข้าม agent → `AGENTS.md` · เลนที่เปิดอยู่ตอนนี้ → `docs/SESSION_LEDGER.md`

**ที่มา 2026-07-26:** กวาด `AGENT_TASKBOARD.md` + `_triage/` แล้วเจอ 3 อาการที่รากเดียวกัน — *งานเสร็จแล้วไม่มีขั้นตอนปิด*
- บอร์ด 102 ใบ ในนั้น **82 ใบจบไปแล้ว** แต่ยังนั่งอยู่ (551KB ที่ต้องเลื่อนผ่านทุกครั้ง)
- `_triage/` 198 ไฟล์ ในนั้น **159 ไฟล์คือผลผลิตของงานที่ปิดแล้ว** ปนอยู่กับของที่ยังใช้จริง
- handoff **27 รายการไม่เคยเข้าบอร์ดเลย** — เขียนไว้ใน handoff แล้วรอบหน้าไม่มีใครหยิบ

---

## 1. วงจรของ ORDER

```
เกิด: Claude/user เขียนแถวลงบอร์ด (+ จองเลขจาก SESSION_LEDGER ก่อน)
  ↓
OPEN → CLAIMED(agent, เวลา) → DONE / BLOCKED(คำถาม)
  ↓
REVIEWED(Claude, วันที่)   ← จุดเดียวที่ Claude ตัดสิน · agent เขียนเองไม่ได้
  ↓
【 TRIGGER 】ย้ายเข้าคลังใน commit เดียวกับที่เขียน REVIEWED
```

### 🔑 กฎเดียวที่ต้องจำ: **`REVIEWED*` = ย้ายทันที ไม่รอกวาดรอบใหญ่**

พอเขียน `REVIEWED` ปุ๊บ commit เดียวกันนั้นทำครบ 3 อย่าง:

| # | ทำอะไร | ปลายทาง |
|---|---|---|
| 1 | ยกบล็อก order ทั้งดุ้น **verbatim** | ต่อท้าย `ARCHIVE_TASKBOARD_2026-07A.md` |
| 2 | ย้ายไฟล์ `_triage/ORDERxxx_*.md` ที่ใบนั้นอ้าง | `_triage/_archive/<หมวด>/` (ดู `_triage/_archive/README.md`) |
| 3 | `powershell -File scripts/make_taskboard_digest.ps1` | อัปเดต `TASKBOARD_DIGEST.md` |

**ทำไมต้องทันที ไม่รอกวาดทีเดียว:** รอบกวาดครั้งแรก (2026-07-24, `a0c06c8`) ย้าย 52 ใบพร้อมกัน แล้ว**ล้มทั้งชุด**
เพราะ session คู่ขนาน commit บอร์ดทับกลางทาง ต้อง restore ใหม่หมด. ย้ายทีละใบตอนปิด = หน้าต่างชนแคบจน
แทบไม่มี และไม่ต้องหาจังหวะ "ตอนไม่มีใครทำงาน" ซึ่งไม่เคยมีจริง

### ย้ายได้เฉพาะ `REVIEWED*` — ทำไมกอง `DONE` เปล่าย้ายไม่ได้

`scripts/check_taskboard_archive.ps1` จุด exception ทันทีถ้าย้ายผิดชนิด:

| สถานะ | ย้ายแล้วเกิดอะไร |
|---|---|
| `REVIEWED*` | ✅ ผ่าน — คำกริยาฝัง reviewer+วันที่ในตัวเอง = เป็น review อยู่แล้ว |
| `DONE` / `CLOSED` / `SKIPPED` / `BUILT*` เปล่า | ❌ `terminal-no-linked-review` — ต้องมี `## REVIEW ORDER-x` คู่กันใน archive ก่อน |
| `OPEN` / `CLAIMED` / `WAITING-USER` / `HOLD` | ❌ `non-terminal-in-archive` |
| header มีคำค้างนอก backtick ("Stage 3 = รอ…", "pending") | ❌ `non-terminal-in-archive` แม้กริยาใน backtick จะ terminal |
| id โผล่ทั้ง active และ archive | ❌ `cross-active-and-archive` |

**แปลว่า:** ถ้าอยากปิดใบที่เป็น `DONE(agent)` เฉยๆ → Claude ต้อง**ตัดสินก่อน** แล้วอัปเกรดเป็น `REVIEWED`
หรือเขียน `## REVIEW ORDER-x` คู่กัน. นี่ไม่ใช่ระบบราชการ — มันคือกฎที่ว่า *ผลดิบของ agent ห้ามกลายเป็นข้อสรุปเองโดยแค่ผ่านเวลาไป*

### ขั้นตอนย้ายจริง (ลำดับสำคัญมาก)

1. ย้าย **verbatim ล้วน** — ห้าม trim newline ต่อบล็อก (`$_.Content` ตรงๆ `-join ''`) ไม่งั้น sha เพี้ยน
2. archive ต้องเป็น **raw-byte prefix-extension** เสมอ (append เท่านั้น) · suffix เปิดด้วย `## ` · **archive = CRLF, active = LF** รักษาไว้
3. `git add` บอร์ดทั้งสองก่อน → แล้วค่อย generate artifact
4. ⚠️ **`-Generate` ใช้ไม่ได้ตอน archive ยังไม่ commit** — มันฝัง `archive_blob_sha` จาก `HEAD:path` (ของเก่า) แต่ pre-commit เทียบกับ staged identity → mismatch เสมอ
   ต้อง generate เองด้วย `Get-Snapshot -Mode Staged` แล้วส่ง `$stagedArchive.Identity` เข้า `New-ArchiveManifestRows`/`Build-ArchiveIndexMarkdown`
5. รัน `scripts/check_precommit_staged.ps1` ให้ PASS ก่อน commit
6. **อ่านสถานะใหม่ก่อน stage เสมอ** — ห้ามเชื่อผลสแกนที่ทำไว้เมื่อครึ่งชั่วโมงก่อน
   (2026-07-26 ORDER-222 เปลี่ยน `OPEN` → `DONE + REVIEWED` ระหว่างที่กำลังทำงานอยู่)

---

## 2. วงจรของ HANDOFF

handoff คือ **บันทึกส่งเวร ไม่ใช่คิวงาน** — คิวงานอยู่ที่บอร์ดที่เดียว

```
จบ session → เขียน handoff → 【บังคับ】ทุกรายการ "งานถัดไป" ต้องมีที่อยู่บนบอร์ด
                              ├─ มี order อยู่แล้ว → อ้างเลขใบนั้น
                              ├─ ยังไม่มี + ทำเร็วๆ นี้ → เปิด order ใหม่ (จองเลขก่อน)
                              └─ ยังไม่มี + รอเงื่อนไข → แถวใน MASTER_BACKLOG.md §9 พร้อมช่อง "ปลุกเมื่อ"
```

**กติกา:** ให้มี handoff ที่ยังเดินอยู่ **ใบเดียว** ที่ `_triage/` เสมอ. พอเขียนใบใหม่ → ใบเก่าย้ายเข้า
`_triage/_archive/handoffs_closed/` **หลังเช็คแล้วว่าทุกรายการในนั้นมีที่อยู่บนบอร์ด**

### 🔒 บังคับด้วย `scripts/check_handoff_contract.ps1` (ใน pre-commit)

handoff ทุกใบต้องมีตารางปลายทาง ไม่งั้น **commit ถูกบล็อก**. รูปแบบที่ถูกต้อง — **marker ต้องอยู่ใต้หัวข้อ
ไม่ใช่เหนือหัวข้อ** (บล็อกจบที่ `## ` ตัวถัดไป ⇒ วาง marker ไว้เหนือหัวข้อจะได้บล็อกว่างทันที · ผมโดนมาแล้วตอนเขียนใบแรก):

```markdown
## ปลายทางของทุกรายการ

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| เรื่องที่ต้องทำต่อ            | ORDER-231   |
| เรื่องที่รอเงื่อนไข            | BACKLOG-D7  |
| เรื่องที่จบในเซสชันนี้แล้ว   | DONE        |
```

ตัวตรวจ resolve ทุก token จริง: `ORDER-x` ต้องมี `## ORDER-x` อยู่บนบอร์ดหรือในคลัง · `BACKLOG-Dn` ต้องมีแถว
`| Dn |` ใน `MASTER_BACKLOG.md` · `DONE` ผ่านเสมอ. **สิ่งที่มันไม่ตรวจ (และตรวจไม่ได้):** ว่าคุณลงรายการครบทุกอัน —
สคริปต์อ่านใจไม่ได้ มันตรวจได้แค่ว่า *ที่เขียนไว้ มีอยู่จริง* · handoff ใน `_triage/_archive/**` ไม่ถูกตรวจ (ปิดไปแล้ว)

> **ทำไมต้องมีข้อบังคับนี้:** 2026-07-26 ตรวจ handoff 17 ใบ เจอ 100 รายการ **27 รายการไม่เคยเข้าบอร์ด**
> รายการที่แรงสุด (`_9_RegimeGateAdds` + `CONF_PA_ENGULF`) build เสร็จ cage ผ่าน มี `.set` รอ — แต่ไปลงที่ host
> ที่ตายตั้งแต่ base gate ⇒ **เซลล์ lever ไม่เคยรันสักเซลล์** แล้วก็ไม่มีใครหยิบต่ออีกเลย. ของดีหายเงียบเพราะ
> ไม่มีขั้นตอน "เอาเข้าบอร์ด" ไม่ใช่เพราะใครขี้เกียจ

---

## 3. วงจรของไฟล์ `_triage/`

`_triage/` = **โต๊ะทำงาน ไม่ใช่ตู้เก็บของ** — อะไรที่วางแล้วไม่หยิบอีก ต้องลงลิ้นชัก

| ชนิด | อยู่ `_triage/` ตอนไหน | ลงคลังเมื่อ |
|---|---|---|
| `ORDERxxx_*_VERDICT.md` / `_RESULTS.md` | ระหว่าง order ยังเปิด | order เจ้าของกลายเป็น `REVIEWED*` |
| `CODEX_*_PROMPT.md` + `_RESULT.md` | ระหว่างรอบ audit เดินอยู่ | audit ปิด — **ย้ายเป็นคู่เสมอ** |
| `HANDOFF_*.md` | เป็นใบล่าสุด | มีใบใหม่มาแทน + รายการมีที่อยู่ครบ |
| คลังดิบ (YouTube/PDF/ChatGPT) | ระหว่างกลั่น | กลั่นเป็น catalog แล้ว |
| catalog / index ที่ยังขุดอยู่ | **ไม่ย้าย** | — |

---

## 4. กันหลาย session ชนกัน — 3 ชั้น

ปัญหาจริงที่วัดได้: 2 session แชร์ working tree + HEAD เดียวกัน ⇒ ชนกัน 4 แบบ —
เลข order ซ้ำ · `git add -A` กวาดงานอีกฝั่ง · แก้ไฟล์รวมพร้อมกัน · แย่ง MT5 terminal

| ชั้น | กลไก | จับอะไรได้ |
|---|---|---|
| **1 จอง** | `docs/SESSION_LEDGER.md` — append แถวก่อนแตะไฟล์: เลข order ที่จอง (บล็อกละ 10) · ไฟล์ที่จะเขียน · เลน MT5 | กันไว้ก่อน (คนลืมได้) |
| **2 บังคับ** | `scripts/check_order_collision.ps1` ใน pre-commit — เลขซ้ำ = **block** · เลขนอกบล็อกที่จอง = **block** · แตะไฟล์ที่คนอื่นจอง = **warn** | ลืมไม่ได้ — นี่คือชั้นจริง |
| **3 นิสัย** | commit path-limited เสมอ · รวบการเขียนไฟล์รวมให้เหลือครั้งเดียวตอนจบ · เช็ค `git log -1` ก่อน stage · subagent ห้ามเขียนไฟล์รวม → เขียน `_triage/_inbox/` แล้ว lead รวบ | ลดโอกาสชนให้เหลือน้อยสุด |

**ห้าม `git add -A` / `git add .` เด็ดขาด** — working tree นี้แชร์กันจริง คำสั่งนี้กวาดงานที่ session อื่นกำลังทำค้างไปด้วย

### ทำไมชั้น 2 ถึงจำเป็น (ไม่ใช่ over-engineering)

collision เกิดจริงมาแล้ว 3 ครั้งในเดือนเดียว และทุกครั้ง**คนที่ทำก็รู้กฎอยู่แล้ว**:
- `fd5264f8` — ต้อง renumber 205-208 → 210-213 เพราะ session คู่ขนานลง 205/206 ไว้ก่อน
- `30598b55` — ต้อง renumber 203 → 204
- `ORDER-098-C` — ถูกใช้โดย order คนละเรื่อง 2 ใบ (บรรทัด 1732 กับ 2576) **ยังไม่ได้แก้**

กฎที่พึ่งความจำ = กฎที่พังตอนคนยุ่ง. hook ไม่ยุ่ง

---

## 5. เช็คลิสต์เปิด/ปิด session

**เปิด:**
1. อ่าน `PROJECT_STATE.md` → handoff ใบล่าสุดใน `_triage/`
2. อ่าน `docs/SESSION_LEDGER.md` — มีใครเปิดอยู่? จองอะไรไว้?
3. **append แถวของตัวเอง แล้ว commit แถวนั้นก่อน** (path-limited)
4. `git log --oneline -15` หา `[codex]`/`[zcode]`/session อื่น → review ผลก่อนเริ่มงานใหม่

**ปิด:**
1. ทุก order ที่ตัดสินแล้ว → `REVIEWED` + **ย้ายเข้าคลังทันที** (ข้อ 1)
2. เขียน handoff ใบใหม่ → เช็คว่าทุกรายการมีที่อยู่บนบอร์ดหรือ backlog (ข้อ 2)
3. handoff ใบเก่า → `_triage/_archive/handoffs_closed/`
4. `scripts/make_taskboard_digest.ps1` → commit
5. แก้แถวตัวเองใน `SESSION_LEDGER.md` เป็น `CLOSED` + ย้ายลงตาราง "ประวัติเลนที่ปิดแล้ว"
