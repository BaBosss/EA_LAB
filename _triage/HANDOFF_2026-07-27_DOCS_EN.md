# HANDOFF 2026-07-27 DOCS-EN — เอกสารที่โหลดทุก session เป็นอังกฤษล้วน + แยก PROJECT_HISTORY ออก

> อ่าน `PROJECT_STATE.md` → ไฟล์นี้ · กติกาทำงาน = `docs/WORK_LIFECYCLE.md` · เลนที่เปิดอยู่ = `docs/SESSION_LEDGER.md`
> **อย่าเชื่อไฟล์นี้เหนือ repo** — ขัดกันเมื่อไร เชื่อ repo แล้วแก้ไฟล์นี้
> เลนนี้ = `S-2026-07-27-DOCS-EN` (ไม่จองบล็อกเลข — งานเอกสารล้วน ไม่เปิด order ใหม่)

## ทำอะไรไป (สั้น)

user สั่งแปลเอกสารที่โหลดทุก session จากไทย/อังกฤษปนเป็น **อังกฤษล้วน** เพื่อลด startup token
(ไทย tokenize แพงกว่าอังกฤษ ~4 เท่า) + แยก `PROJECT_STATE.md` เป็น current/history

**ผล:** startup context ลดจาก **~73k → ~8.5k token (−88%)**

| ไฟล์ | ก่อน | หลัง |
|---|---|---|
| `CLAUDE.md` | 21 KB | 19.5 KB |
| `AGENTS.md` | 39 KB | 28.5 KB |
| `PROJECT_STATE.md` | **172 KB** | **34 KB** |
| `PROJECT_HISTORY.md` | — | 121 KB (ไม่โหลดทุก session) |

**ตัวที่ให้ผลจริงคือบรรทัดเดียว:** `PROJECT_STATE.md` บรรทัด 73 = changelog สะสม **34,605 ตัวอักษร
บรรทัดเดียว** ≈ 1/3 ของไฟล์ ≈ ~24k token — ย้ายออกอย่างเดียวก็ลดไป 1/3 แล้ว (แตกเป็น 18 bullet ใน history)

## กฎที่ตั้งใหม่

`CLAUDE.md` §LANGUAGE RULE: **เอกสาร/commit message/log = อังกฤษ · ตอบ chat กับ user = ไทย**

## สิ่งที่ต้องรู้ก่อนแตะเอกสารพวกนี้ต่อ

- **`PROJECT_STATE.md` §3 ไม่ใช่ decision log ฉบับเต็มอีกแล้ว** — เก็บเฉพาะ **กฎที่ยังผูกมัดงานข้างหน้า
  40 แถว** (ตรวจแล้ว: กฎ 39/39 จาก log เดิมอยู่ครบ histogram วันที่ตรง · +1 คือ doctrine ที่ยกจาก
  closure record ขึ้นมาเอง) · **ฉบับเต็ม 55 แถวพร้อมที่มา = `PROJECT_HISTORY.md` §E**
- **ห้ามย้าย §3 หรือ §4 ออกจาก `PROJECT_STATE.md`** — มีสคริปต์ parse อยู่จริง:
  - `check_state.ps1` #1 ต้องเจอสตริง `DEPLOYMENTS.csv` ใน §0.5
  - `make_status_html.ps1` parse หัวข้อ `## 4.` + ตาราง 9 แถว + บรรทัด `judge <วันที่>`
- **`PROJECT_HISTORY.md` = single-writer (Claude/user)** เพิ่งใส่ใน `AGENTS.md` §2 + red-line §5.3 แล้ว
  — ตอนแยกไฟล์ครั้งแรก **ลืม** ⇒ decision log หลุดการคุ้มครองชั่วคราว
- **`PROJECT_HISTORY.md:103` มี `ENTRY-CLAIM-OK`** เพราะบรรทัดนั้น *อ้างถึง* needle ของ
  `check_state.ps1` ขณะอธิบายบั๊กของ guard ตัวเอง — mark ไม่ใช่ reword (ตาม comment ORDER-219)

## ของที่เปลี่ยนพฤติกรรมจริง (ไม่ใช่แค่แปล)

**STATUS.html วัน judge เปลี่ยน `2026-07-24` → `2026-09-22`** — `make_status_html.ps1` เอา**บรรทัดแรก**
ที่ match `judge[^\d]*(\d{4}-\d{2}-\d{2})` ของเดิมไปโดนบรรทัด narrative เข้า จึงโชว์วันที่ผ่านมาแล้ว
พอย้าย narrative ออก บรรทัดแรกกลายเป็น §4 ที่ตั้งใจจริง ⇒ **นี่คือแก้บั๊กที่มีอยู่เดิม ไม่ใช่ regression**

## บทเรียนที่ควรจำ

- 🔴 **การแปล `PROJECT_HISTORY.md` (121 KB) ไม่คุ้ม** — ไฟล์นี้ไม่เคยถูกโหลดอัตโนมัติ ⇒ ประโยชน์ต่อ
  เป้าหมาย = **0** แต่เผา subagent ~660k token · **ครั้งหน้าอย่าแปล archive แปลเฉพาะไฟล์ที่โหลดจริง**
- 🔴 **การแยกไฟล์ = สร้างพื้นผิวใหม่ให้คำอ้างที่ถูกถอนไปแล้ว** — `eqDD −54..−56%` (ORDER-211 ห้ามอ้าง,
  ORDER-073 ถอน) ถูกยกเข้า history แบบไม่มี banner. แถว §3 ที่บันทึกการถอน**เขียนไว้เองว่า "บอร์ดคือ
  พื้นผิวสุดท้ายที่ยังอ้างอยู่"** แล้วผมก็สร้างอันใหม่ในคอมมิตเดียวกัน ⇒ **ย้ายเนื้อหาเมื่อไร ต้องไล่หา
  คำอ้างที่ถูกเพิกถอนในก้อนที่ย้ายเสมอ** (แก้แล้ว: ขีดฆ่า + `[RETRACTED]`)
- **numeric-token diff เป็นกรงที่ใช้ได้จริง** — จับได้ว่า subagent แปลตก 1 clause (Contract D/ORDER-102)
  ที่อ่านผ่านตาไม่มีทางเห็น · **แต่มันจับได้แค่ตัวเลข** prose ที่หายโดยไม่มีตัวเลขติดมาด้วยยังมองไม่เห็น

## ต่อจากนี้ → ORDER-371 (แนะให้หยิบใบนี้)

**ทำไมสำคัญที่สุดในคิว:** ORDER-371 บอกว่า tick history ของ `Meta 5b` ต่างจาก terminal หลัก **14 เท่า**
(window เดียวกันเป๊ะ `2020.01.01–2023.01.01`, bars เท่ากัน 74,778, แต่ ticks 61,093,205 vs 4,399,319
⇒ PF 1.77 vs 2.08) และ **ORDER-280 เจออาการเดียวกันบน BTC** ⇒ **ไม่ใช่เคสเดียว มันคือสมบัติของเครื่อง**

⇒ นี่อยู่**เหนือน้ำของทุก verdict** ที่กำลังจะเขียน: ถ้าเลขข้าม install เทียบกันไม่ได้ การเทียบ A/B
ที่รันคนละเลนก็ไม่มีความหมาย · งานนี้ **user ต้องทำเอง** (โหลด history) Claude verify ได้

**อย่าลืม:** ห้ามลบ `Bases` ของ install ไหนโดยไม่เช็คว่ามีเลนรันอยู่ — ORDER-341/340/350 ใช้ครบทั้ง 3 install

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| แปล `CLAUDE.md` · `AGENTS.md` · `PROJECT_STATE.md` เป็นอังกฤษล้วน | DONE |
| แยก `PROJECT_HISTORY.md` + ตรวจ token หาย 0 | DONE |
| `PROJECT_HISTORY.md` ไม่มีเจ้าของ (หลุด single-writer + red-line oc-qwen) | DONE |
| `AGENTS.md` §3.4 ชี้ "full version in PROJECT_STATE §3" ที่บีบแล้ว | DONE |
| `eqDD −54..−56%` ที่ถูกถอนแล้วโผล่ใน history แบบไม่มี banner | DONE |
| `check_block_staleness.ps1` `$selfReferential` ขาด `PROJECT_HISTORY.md` | DONE |
| commit trailer `Claude Opus 4.8` → `Claude Opus 5` (user เคาะ 2026-07-27) | DONE |
| mojibake `Â§` → `§` 2 จุดใน `PROJECT_HISTORY.md` | DONE |
| user เคาะแล้วว่า **ไม่ตัด** คอลัมน์ Why ใน §3 (คง 34 KB) | DONE |
| citation ค้างชี้ `PROJECT_STATE §7 "SESSION 2026-07-08"` ที่ถูก archive ไปแล้ว 2 จุด | BACKLOG-D28 |
| tick history `Meta 5b` เพี้ยน 14 เท่า — เลขข้าม install เทียบกันไม่ได้ | ORDER-371 |
| `_vps_deploy` binary เก่ากว่า source (13/23 bundle) | ORDER-410 |
| NuiIndy CutLoss 30-vs-100 ยืดหน้าต่าง | ORDER-372 |
