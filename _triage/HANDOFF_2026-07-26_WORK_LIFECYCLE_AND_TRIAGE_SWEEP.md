# HANDOFF 2026-07-26 — วงจรชีวิตงาน + กวาด taskboard/_triage

> อ่าน `PROJECT_STATE.md` → ไฟล์นี้ · กติกาการทำงานที่เพิ่งตั้งขึ้น = **`docs/WORK_LIFECYCLE.md`** (อ่านก่อนเริ่มงาน)
> เลนที่เปิดอยู่ = `docs/SESSION_LEDGER.md` · **อย่าเชื่อไฟล์นี้เหนือ repo** — ขัดกันเมื่อไร เชื่อ repo แล้วแก้ไฟล์นี้

## ทำอะไรไป

user ถามว่างานที่ handoff ไว้เข้า taskboard ครบไหม และอันไหนทำแล้ว — คำตอบคือ **ไม่ครบ** และหาไม่เจอด้วย
เลยกวาดทั้งระบบแล้ววางกติกาไม่ให้เกิดซ้ำ

**สิ่งที่วัดได้ตอนเริ่ม:** บอร์ด 102 order (551KB) ในนั้น 82 ใบจบไปแล้วแต่ยังนั่งอยู่ · `_triage/` 198 ไฟล์
ในนั้น 159 คือผลผลิตของงานที่ปิดแล้ว · handoff 17 ใบ 100 รายการ **27 รายการไม่เคยเข้าบอร์ดเลย**

**ผลลัพธ์:** บอร์ด **102 → 93 order** (ย้ายเข้าคลัง 22 ใบ, เพิ่ม order ใหม่ 15) · `_triage/` **198 → 51 ไฟล์**
(ย้าย 153 ไฟล์เข้า `_triage/_archive/`) · archive 186 → 208 บล็อก · validator เขียวตลอด (unresolved 0, integrity 0)

## กติกาใหม่ 2 ข้อ (นี่คือของจริงที่เหลือไว้)

**1. `REVIEWED*` = ย้ายทันทีทีละใบ ไม่กวาดรอบใหญ่** (`docs/WORK_LIFECYCLE.md` §1)
commit เดียวกันทำครบ: ยก order block เข้า archive verbatim → ย้ายไฟล์ `_triage/ORDERxxx_*` → รัน
`scripts/make_taskboard_digest.ps1`. เหตุผล: รอบกวาดใหญ่ครั้งแรกล้มทั้งชุดเพราะ session คู่ขนาน commit ทับ

**2. handoff = บันทึกส่งเวร ไม่ใช่คิว** (`docs/WORK_LIFECYCLE.md` §2)
คิวมีที่เดียว = บอร์ด. ทุกรายการ "งานถัดไป" ต้องมีที่อยู่ — order หรือแถวใน `MASTER_BACKLOG.md` §9 พร้อมช่อง "ปลุกเมื่อ"
**บังคับด้วย `scripts/check_handoff_contract.ps1`** — handoff ที่ไม่มีตาราง `<!-- HANDOFF-ROUTING -->`
หรือมี id ที่ resolve ไม่ได้ = commit ถูกบล็อก

## เกราะกัน session ชนกัน (3 ชั้น)

| ชั้น | ของ |
|---|---|
| จอง | `docs/SESSION_LEDGER.md` — จองเลข order เป็นบล็อกละ 10 + ประกาศไฟล์ที่จะเขียน + เลน MT5 |
| บังคับ | `scripts/check_order_collision.ps1` ใน pre-commit — เลขซ้ำ/นอกบล็อก = **BLOCK** · แตะไฟล์ของเลนอื่น = WARN |
| นิสัย | commit path-limited เสมอ · ห้าม `git add -A` · เช็ค `git log -1` ก่อน stage |

⚠️ **hook อ่าน ledger จาก `HEAD` ไม่ใช่ index** ⇒ **ต้อง commit การจองก่อน แล้วค่อยใช้เลขนั้น** (โดนบล็อกตัวเองมาแล้ว)

## ของที่แตะเงินจริง — user ต้องเคาะ

- **ORDER-230** บัญชี 463666728 เป็น cent หรือ USD (`ACCOUNTS.csv` เขียน USD, user บอก cent) — ~13 EA คิว ต.ค. กินเลขนี้
- **ORDER-232** MacroGate 990120 ยัง ACTIVE ทั้งที่ถูกถอดเป็น ADVISORY-ONLY · มีคำแนะนำขัดกัน 2 ฉบับ (ผมแนะฉบับหลัง = เก็บเป็น sensor)
- **ORDER-234** PERSIST_MIGRATION checklist ยังไม่เคยเดิน — block Boss_14 GBPJPY ขึ้นเงินจริง
- **ORDER-235** บาร์ 30 ไม้ใช้กับ 4 EA ไม่ได้ (ต้องรอถึง 2028-29) — ต้อง ratify ไม่ใช่เลื่อนวันไปเรื่อย

## เจอบั๊กจริง 3 อย่าง

1. **ORDER-073 อ้างเลขที่ถูกสั่งห้าม** — บอร์ดคือพื้นผิวสุดท้ายที่ยังเขียน `eqDD −54..−56%` ที่ ORDER-211 ห้ามไว้ตรงๆ **แก้แล้ว** `e2098c9e`
2. **validator ตี REVIEWED เป็น NonTerminal** เพราะ `'holdout' -match 'HOLD'` — 17 ใบติดกับนี้ → **ORDER-260** (ยังไม่แก้ จงใจ: ห้ามเปลี่ยนตรรกะ status ระหว่างย้ายบอร์ด)
3. **digest generator ล้มเงียบ** — `$PSScriptRoot` ว่างใต้ `-File <relative>` + ผมกลบ output ⇒ commit digest ที่ผิด 219 บรรทัด **แก้แล้ว** `8e86c21f`

<sub>บทเรียนร่วม: **substring matching ชนกัน 3 ครั้งใน session เดียว** — `HOLD` ใน "holdout" · `ไฟล์เดียว` ใน "ในไฟล์เดียวกัน"
(check_state §7) · `_archive` ใน "check_taskboard_archive.ps1" (ตัวกรองของผมเอง ซึ่งเกือบทำให้ commit กวาดงาน
session อื่นที่ค้างอยู่). ภาษาไทยไม่มีเว้นวรรค ยิ่งชนง่าย</sub>

## ที่ยังไม่ได้ทำ (ตั้งใจ)

- **กอง B 28 ใบ** ยังอยู่บนบอร์ด — หลักฐานตรวจครบแล้วแต่ยังไม่ได้เขียน REVIEWED → **ORDER-261**
- **`ORDER-098-C` ยังซ้ำ** (2 order คนละเรื่อง) — grandfather ไว้ใน collision hook ยังเป็นหนี้
- **`findyour8_pdfs/` 888MB** ยังอยู่ที่เดิม (gitignored) — user ต้องเคาะว่าจะย้ายออกนอก repo ไหม
- **corpus 8 โฟลเดอร์** (`*_youtube/`, `chatgpt_convs/`) ยังไม่ย้าย — `fxdreema_youtube/` tracked ครึ่งเดียว ต้องแยกทีละไฟล์

---

## ปลายทางของทุกรายการ

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| บัญชี 463666728 currency cent vs USD | ORDER-230 |
| 992001 TsMom ไม่เคยมี Monte Carlo (ACTIVE, judge ต.ค.) | ORDER-231 |
| MacroGate 990120 disposition | ORDER-232 |
| `--resolve-single-leg-baskets` รอ Codex audit + ratify | ORDER-233 |
| PERSIST_MIGRATION checklist | ORDER-234 |
| บาร์ 30 ไม้ไม่พอดีกับ 4 EA | ORDER-235 |
| lever `_9_RegimeGateAdds` + `CONF_PA_ENGULF` ยังไม่เคยยิงใส่ CORE จริง | ORDER-236 |
| "GBPJPY leg-8" = 3 magic 2 spacing | ORDER-237 |
| `2026.06.01` ค้างใน 5 สคริปต์นอกกรง | ORDER-238 |
| RSI-MR หาง basket 98-182 วัน ยาวกว่าวัน judge | ORDER-239 |
| SS1 LondonORB 992003 ไม่มี order-of-record + corr ยังไม่วัด | ORDER-250 |
| คลัง skill อยู่นอก repo ไม่มี version control | ORDER-251 |
| staleness linter (จับ pattern 073/143/188) | ORDER-252 |
| validator substring ตี REVIEWED เป็น NonTerminal | ORDER-260 |
| กอง B 28 ใบรอ REVIEWED + 9 ใบต้องแก้ข้อความ | ORDER-261 |
| Boss_16 เช็ค F3 `k16_pair_a/b` ก่อนสลับ binary | BACKLOG-D1 |
| X1 persist / S1-S2 ladder reconcile / S3 margin re-budget | BACKLOG-D2 |
| ขุด QuantCorner FB ย้อนหลัง | BACKLOG-D3 |
| PDF ทฤษฎี 11 ใบที่ยังไม่แกะ | BACKLOG-D4 |
| Wave-3 XAU 3 ดีไซน์ที่ไม่เคยสร้าง | BACKLOG-D5 |
| สมมติฐาน SL width vs noise floor | BACKLOG-D6 |
| DynClose บน Kangaroo | BACKLOG-D7 |
| พอร์ตเกินงบ 25% จะ resize/ถอด/ยอมรับ | BACKLOG-D8 |
| ยืนยัน MT5 local agent = 18 | BACKLOG-D9 |
| เช็ค bundle ที่ staged ขึ้นชาร์ตจริงกี่ตัว | BACKLOG-D10 |
| re-pin `$mainEnd` ตอน MAIN เลื่อน | BACKLOG-D11 |
| MRIS core ยังไวเกิน (2019 = 48% risk-off) | BACKLOG-D12 |
| ST03 lever 2 (TP ต่อ symbol × exit-mode) | BACKLOG-D13 |
| ST03 lever 3 (LOT_Repeat × vol-gate) | BACKLOG-D14 |
| PA_LotMult ตาม Bulkowski tier | BACKLOG-D15 |
| SMC / S-R เป็นชั้น confluence | BACKLOG-D16 |
| ORDER-073 อ้างเลขที่ ORDER-211 สั่งห้าม | DONE |
| ย้าย order ที่ REVIEWED เข้าคลัง 22 ใบ | DONE |
| ย้าย `_triage` 153 ไฟล์เข้า `_archive` + rewrite citation 138 จุด | DONE |
| 6 สคริปต์ที่ wave 1 ทำพัง (hardcoded path) | DONE |
| digest generator ล้มเงียบ + `-Check` ที่โกหก | DONE |
| SESSION_LEDGER + collision hook + WORK_LIFECYCLE + handoff contract | DONE |
