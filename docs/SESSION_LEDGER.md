# SESSION_LEDGER — ใครกำลังทำอะไรอยู่ตอนนี้

> ⚠️ canonical entry = `PROJECT_STATE.md` · ไฟล์นี้ owns: **การจองเลน (order number + ไฟล์ + เลน MT5) ของ session ที่ยังเปิดอยู่ เท่านั้น**
>
> **ทุก session / agent lane ต้อง append แถวของตัวเองที่นี่ก่อนแตะไฟล์ใดๆ** แล้ว commit แถวนั้นเป็น commit แรก
> (path-limited: `git commit -- docs/SESSION_LEDGER.md`). ไม่จอง = `scripts/check_order_collision.ps1` จะเตือน
> และถ้าเลข order ชนของคนอื่น = **บล็อก commit**.
>
> ที่มา: 2026-07-26 — เกิด collision จริง 3 ครั้ง (`fd5264f8` renumber 205-208→210-213 · `30598b55` renumber 203→204 ·
> `ORDER-098-C` ถูกใช้ซ้ำโดย 2 order คนละเรื่อง) + รอบกวาด archive ครั้งแรกล้มทั้งชุดเพราะ session คู่ขนาน
> commit `AGENT_TASKBOARD.md` ทับกลางทาง (memory `shared-worktree-concurrent-writers`).

## กติกา 5 ข้อ

1. **จองก่อนแตะ** — เปิด session → append แถว → commit แถวนั้นก่อน แล้วค่อยเริ่มงาน
2. **เลข order = จองเป็นบล็อกละ 10** — เอา `max(เลขที่ใช้แล้วทั้ง 2 บอร์ด)` ปัดขึ้นสิบถัดไป แล้วเว้น 1 บล็อกเป็นกันชน
   ห้ามหยิบเลขนอกบล็อกที่ตัวเองจอง (hook บล็อก)
3. **commit path-limited เสมอ** — `git commit -- <path> <path>` ห้าม `git add -A` / `git add .`
   (working tree นี้แชร์กันจริง — `git add -A` กวาดงานของ session อื่นไปด้วย)
4. **ไฟล์รวมชนกันได้** — ถ้าจะแตะ `AGENT_TASKBOARD.md` / `EA_SCORECARD_AND_REGISTRY.md` / `EA_MASTER_INDEX.csv` /
   `ARCHIVE_TASKBOARD_2026-07A.md` ให้ประกาศในคอลัมน์ `owns paths` และ**รวบให้เหลือการเขียนครั้งเดียวตอนจบงาน**
   ก่อน stage ให้เช็ค `git log -1` ว่า HEAD ไม่ขยับตั้งแต่ตอนอ่าน — ขยับ = อ่านใหม่แล้วทำใหม่
5. **ปิด session = แก้ status เป็น `CLOSED`** พร้อมเวลา · แถวที่ `ACTIVE` เกิน 12 ชม. โดยไม่มี commit = `ABANDONED`
   (ใครก็ตามที่เห็น มีสิทธิ์ mark ให้)

## เลนที่เปิดอยู่

| session id | เริ่ม | order block | owns paths | เลน MT5 | status |
|---|---|---|---|---|---|
| `S-2026-07-26-REV04` | 2026-07-26 20:30 | **280-289** | `ea_projects/(TRD)_SuperTrendFlip/**` · `_mt5_auto/ab_sets/genstanding_stf/**` · `_mt5_auto/**` (รันเทส) | `D:\Meta 5b` (portable — BTC ต้องเลนเดียวกับ campaign เดิม) | `ACTIVE` |

<sub>แถว `S-2026-07-26-GENSTANDING` เขียนย้อนหลังโดย session TRIAGE จากหลักฐาน git (commit `6df2d6b5`, `47319bef`,
`09a6fb7b`, `ca922653` + ไฟล์ที่ค้างใน working tree) — session นั้นเปิดก่อนที่ ledger นี้จะมีอยู่ ไม่ใช่การละเมิดกติกา.
มันทำงานบน ORDER-GEN-STANDING ซึ่งเป็น standing order ไม่กินเลขใหม่ **แต่จอง 240-249 ให้ล่วงหน้า** เพราะ
`check_order_collision.ps1` RULE 2 บล็อกเลขที่อยู่นอกบล็อกของทุกเลนที่ ACTIVE — ถ้าไม่จองให้ เลนนั้นจะโดนบล็อก
กลางคันทั้งที่ไม่ได้ทำอะไรผิด. การจองล่วงหน้า = **ผ่อนให้เท่านั้น ไม่ปิดกั้นอะไรเพิ่ม** จึงปลอดภัยที่จะเดาแทน.</sub>

## ประวัติเลนที่ปิดแล้ว

| session id | ช่วง | order block | สรุป 1 บรรทัด |
|---|---|---|---|
| `S-2026-07-26-GENSTANDING` | 2026-07-26 ~10:00–20:00 | 240-249 (ไม่ได้ใช้ — standing order) | ORDER-GEN-STANDING ชุด 2: matrix 19 cell → **VALIDATED CANDIDATE ตัวเดียว = BTCUSD H4 `rev03` pyramid** (MAIN 2.257 · BWD 3.949 · holdout 4.274 · MC ruin 0%) · lever ใหม่ 2 ตัวเข้า rev02/rev03 (ER gate · capped pyramid) · วัด swap ได้ว่า tester คิด POINTS แต่ไม่คิด INTEREST ⇒ `scripts/swap_adjust_crypto.py` · handoff = `_triage/HANDOFF_2026-07-26_SUPERTRENDFLIP_LEVER_CAMPAIGN.md` |
| `S-2026-07-26-TRIAGE-B` | 2026-07-26 18:45–20:15 | 270-279 (ไม่ได้ใช้ — ปิดใบเก่า) | **ORDER-260** แก้บั๊ก `Get-StatusClass` (substring `HOLD`/`OPEN`) → ปลด 17 ใบ + กรงใหม่ `run_statusclass_tests.ps1` (พิสูจน์แล้วว่า fail ได้) · **ORDER-261** เขียน review 28 ใบ + แก้ข้อความ 9 ใบ → ย้ายเข้าคลัง 51+3 ใบ **บอร์ด 96→42** · เปิด **ORDER-270** (negative suite 2 ชุดค้าง = validator ไม่มีกรง) · ⚠️ **B1_DATASET.csv rows ยังค้าง** (ไฟล์อยู่ในมือ session คู่ขนาน) |
| `S-2026-07-26-TRIAGE` | 2026-07-26 13:00–18:30 | 230-239 · 250-252 · 260-269 (ใช้จริง 230-239, 250-252, 260-261) | วางวงจรชีวิตงาน (`docs/WORK_LIFECYCLE.md`) + เกราะกัน session ชน 3 ชั้น · บอร์ด 102→95 order (ย้ายเข้าคลัง 22) · `_triage/` 198→51 ไฟล์ (ย้าย 153 + rewrite citation 138 จุด) · เปิด order ใหม่ 15 ใบจาก 27 รายการที่ handoff ทิ้งไว้ · handoff = `_triage/HANDOFF_2026-07-26_WORK_LIFECYCLE_AND_TRIAGE_SWEEP.md` |

## เลขที่ใช้ไปแล้ว (อัปเดตเมื่อจองบล็อกใหม่)

- สูงสุดที่ใช้จริง ณ 2026-07-26 = **222**
- ว่างและ**ห้ามใช้** (เว้นเป็นกันชน/รอยแผลเดิม): 207 · 208 · 209 · 223-229
- บล็อกถัดไปที่จองได้ = **300-309** (290-299 เว้นกันชน · 280-289 จองแล้วโดย `S-2026-07-26-REV04`)
