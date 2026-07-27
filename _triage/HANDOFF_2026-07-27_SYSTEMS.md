# HANDOFF 2026-07-27 SYSTEMS — ปิด ORDER-370 แล้วเจอบั๊กที่ใหญ่กว่า 2 ตัวระหว่างทาง

> อ่าน `PROJECT_STATE.md` → ไฟล์นี้ · กติกาทำงาน = `docs/WORK_LIFECYCLE.md` · เลนที่เปิดอยู่ = `docs/SESSION_LEDGER.md`
> **อย่าเชื่อไฟล์นี้เหนือ repo** — ขัดกันเมื่อไร เชื่อ repo แล้วแก้ไฟล์นี้
> เลนนี้ = `S-2026-07-27-SYSTEMS` (block 410-419) รับช่วงจาก `HANDOFF_2026-07-26_WORK_LIFECYCLE_AND_TRIAGE_SWEEP.md`

## ทำอะไรไป (สั้น)

รับ handoff ของเลน TRIAGE มาทำต่อ. ของที่ค้างจริงในใบนั้นเหลือไม่มาก (ORDER-270 ปิดไปแล้ว) จึงหยิบ
**ORDER-370** ซึ่งเป็นใบ `🔴 ops/integrity` ที่ไม่มีเลนไหนถือ. **ปิดได้ · แต่ระหว่างทางเจอบั๊กเงียบอีก 2 ตัว
ที่ไม่มีในใบสั่ง** — ทั้งคู่เป็นตระกูลเดียวกับที่ repo นี้จ่ายค่าเรียนมาแล้ว 3 รอบ

**บอร์ด 39 → 41 order · archive 234 บล็อก** (ย้าย ORDER-370 + ORDER-411 เข้าคลัง · เปิด ORDER-410)

## 1. ORDER-370 ปิด — `960dd178`

detector `check_stale_binaries.ps1` มี 4 root ที่ล้วนเป็นที่ที่ binary ถูก **build/test** ไม่มี root ไหนเป็นที่ที่มัน
**ถูกส่งขึ้นชาร์ต** (`_vps_deploy`) และ `.ex5` ถูก gitignore ⇒ ไม่มีอะไรในเครื่องนี้มองเห็นได้เลย

- **กรงมาก่อนแก้ · พิสูจน์ว่า fail ได้** — `scripts/_test/run_stale_binaries_tests.ps1` **แดง 3/14 ก่อนแก้ → 14/14 หลังแก้**
- เคส scope อ่าน default `$Roots` ด้วย **AST ไม่ใช่ grep** (เพราะตัว fix เองใส่คำว่า `_vps_deploy` ในคอมเมนต์ —
  เทสแบบ grep จะเขียวเพราะคอมเมนต์)
- **acceptance ครบ 3 ข้อ:** record `_vps_deploy` **0 → 23** (จาก 30 `.ex5`, อีก 7 = `NO_SOURCE` ของ EA ที่ซื้อมา
  ถูกนับไม่ list ตามพฤติกรรมเดิมที่ถูกต้อง) · Boss_16 bundle **ไม่ stale** ตามที่ใบสั่งเช็คมือไว้ — **แต่ label จริงคือ
  `HASH_DIFFERS` ไม่ใช่ `OK`** (มีสำเนาที่อื่น + คอมไพเลอร์ไม่ byte-reproducible) **เขียนไว้ตรงๆ ไม่กลบ** ·
  bundle ที่ไม่มี `.mq5` คู่ → `NO_SOURCE` ไม่พัง

## 2. 🔴 บั๊กที่กรงจับได้เอง (ไม่มีในใบสั่ง) — detector โกหกเมื่อเจอ **พอดี 1 ตัว**

`$badCount = ($results | Where-Object {...}).Count` คืน **`$null` ไม่ใช่ `1`** เมื่อมีผลลัพธ์ชิ้นเดียว (PS 5.1.26100)
⇒ `$null -gt 0` = False ⇒ **รันที่เจอ STALE พอดี 1 ตัว exit 0 แล้วพิมพ์ `[OK] every .ex5 matches its source`**

สองตัวขึ้นไปรายงานถูก — ต้นไม้จริงบังเอิญมี 8 บั๊กเลยรอด. **เคสที่เงียบคือวันที่แก้ทุกอย่างอื่นหมดแล้วเหลือตัวเดียว**
⇒ **ครั้งที่ 4 ใน 8 วันของอาการเดียวกัน** (ORDER-260 substring · ORDER-341 label ranking · ORDER-390 nested backtick):
**detector ยังทำงาน แต่เงียบลง** · <sub>เทสของผมเองก็โดนตระกูลเดียวกันชั้นถัดไป: `@(... | ConvertFrom-Json)` นับได้ 1
สำหรับ array 3 แถว เพราะ PS 5.1 ส่ง array ลง pipeline เป็นก้อนเดียว ขณะที่ per-row assertion ผ่านหมด (ยิ่งหลอก)</sub>

## 3. 🔴 ORDER-411 — BOM บน stdin ทำให้กรง archive โทษ history — `0891a202`

**เกิดสดตอนจะ commit การปิด 370.** `check_precommit_staged` บล็อกด้วย
`archive path ... not readable at 0ced1948 (renamed/deleted mid-chain?)` ขณะที่ `git ls-tree` แสดงไฟล์อยู่ตรงนั้น

ต้นเหตุ: ORDER-270 เปลี่ยนมาป้อน ref ทาง stdin · `Process.StandardInput` บน .NET Framework สร้างจาก
**`[Console]::InputEncoding`** + `AutoFlush=true` ซึ่ง**ปล่อย preamble ตอนสร้าง** ⇒ console UTF-8 ยิง `EF BB BF`
นำหน้าคำขอแรก ⇒ git ตอบ `missing`

**สามอย่างที่ทำให้แพง (วัดทั้งหมด):** (1) **positional ไม่ใช่เจาะจง commit** — สลับลำดับ ref ความผิดย้ายไป commit อื่น
(2) **ขึ้นกับ session** — console OEM codepage ไม่มี preamble ⇒ **โค้ดเดียวกันผ่านให้เลนที่ปิด ORDER-390 เมื่อเช้า
แล้วบล็อกผมอีกชั่วโมงถัดมาบน commit เดียวกัน** (3) **fix แรกผมผิด** — เขียนลง `BaseStream` ด้วย writer ไม่มี BOM
ไม่ช่วย เพราะแค่*อ่าน* property `.StandardInput` ก็สร้าง writer แล้ว · จับได้ด้วยการ **dump ไบต์ที่ลูกได้รับจริง**
(`239 187 191 ...`) · และมันคือ `InputEncoding` **ไม่ใช่** `OutputEncoding`

กรง `run_blobmap_encoding_tests.ps1` **7/7 เมื่อมี pin · 5/7 เมื่อถอด pin บรรทัดเดียว** (restore กลับ byte-identical แล้ว) ·
มีเคสยืนยันว่า path ที่หายจริงยัง map เป็น `$null` ⇒ **ไม่ได้เปลี่ยน fail-closed เป็น fail-open** ·
`run_chainwalk_tests` **11/11** · `run_statusclass_tests` **23/23** ไม่ถอยหลัง

> **บทเรียน:** ⚠️ **error ที่ชี้ไปที่ commit เก่า ≠ history พัง** — ถ้ากลไกมี "คำขอแรก" ที่พิเศษกว่าคำขออื่น
> ให้สงสัย**ตำแหน่ง**ก่อน**เนื้อหา** · **fail-closed ที่ให้เหตุผลผิด แพงกว่าที่คิด** มันส่งคนไปล่าปัญหาที่ไม่มีจริง

## 4. สิ่งที่ตาที่เพิ่งเปิดมองเห็น — และสิ่งที่ผม**ไม่**ทำ

**13 ใน 23 bundle ใน `_vps_deploy` เป็น `STALE`** และ**ไม่ใช่ artifact ของ git checkout** (ตรวจ `git log` แล้ว:
`LabCore.mqh` แก้จริง 07-24 `83ecce78` · `EA_BREAKOUT_XAU.mq5` 07-23 `84bfe452` · `MacdDiv_Naked.mq5` 07-25 `b45320a1`)

**ไม่ประกาศเป็นเหตุการณ์ และไม่ rebuild อะไรทั้งสิ้น** — `_vps_deploy` = จุดพักก่อน**อัป** ไม่ใช่ตัวบนชาร์ต ⇒
"bundle เก่ากว่า source" ยังไม่เท่ากับ "ชาร์ตรันของผิด" · เลขที่ขาดคือฝั่ง VPS ซึ่งวัดจากเครื่องนี้ไม่ได้ →
**ORDER-410** (STEP 1 = user อ่าน hash+mtime บน VPS ก่อน · ห้าม rebuild ก่อนจบ STEP 3
เพราะบางตัว attach อยู่บนเงินจริง — **rebuild ทับ = เปลี่ยน EA ใต้ตำแหน่งที่เปิดค้าง** ซึ่งแพงกว่าปัญหาเดิม)

## 3b. ORDER-412 — `/scrutinize` งานตัวเองแล้วพบว่า fix ของ 411 **ผิดทรง**

user สั่ง `/scrutinize` หลังผมรายงานว่าเสร็จ. ของที่ commit ไป**ทำงานถูกจริง** (archive move ผ่าน end-to-end)
**แต่ดีไซน์แย่กว่าที่ควร 3 ข้อ:** (1) pin `[Console]::InputEncoding` = `SetConsoleCP` = **mutation ทั้ง process**
เพื่อแก้ปัญหาระดับไปป์เดียว (2) **รั่วจริง** — getter throw + setter สำเร็จ ⇒ `finally` ไม่ restore ⇒ codepage ค้าง
(3) **branch absorber ไม่เคยถูกกรงแตะ** ⇒ โค้ดที่รันเฉพาะใน environment ที่ reproduce ไม่ได้ = โค้ดที่ไม่มีเทส

**แก้ด้วยการลบ** — absorber เป็นทางเดียว ยิงเสมอ (วัดแล้วให้ผลถูกต้องเหมือนกันทั้งสอง encoding) ⇒ ไม่แตะ global ·
ไม่มี branch ที่ไม่ถูกเทส · สั้นลง ~25 บรรทัด · เพิ่ม invariant ตรวจว่า reply แรกคือ absorber จริง

**กรงพิสูจน์ว่า fail ได้ 3 ทาง:** สะอาด 9/9 · ใส่ mutation กลับ **8/9 แดง** · ลืม drop แถว → `throw 3 rows for 2 inputs`
· ถอด absorber → `throw` + ref แรก `missing` (ยืนยันบั๊ก BOM ยังมีชีวิต) · **chainwalk 11/11 · statusclass 23/23 ·
`-Audit` จริง exit 0 zero-diff**

> 🔴 **ของแถมที่มีค่าสุด: เทสของผมเองไม่ discriminate ตอนแรก** — เคส "no global side effect" **ผ่านทั้งที่โค้ดมี
> mutation เต็มๆ** เพราะจับ `$encBefore` ไว้ท้ายบล็อก ซึ่งการเรียกก่อนหน้า reset encoding ไปแล้ว ⇒ before=after=สะอาด
> **บทเรียน: assertion เรื่อง side effect ต้องเป็นเจ้าของ state ที่มันวัด — ตั้งค่าศัตรูใหม่บรรทัดติดกันก่อนเรียก**

## 4b. BACKLOG-D24 น่าจะเป็นบั๊กเดียวกับ ORDER-411 (อนุมาน ไม่ใช่พิสูจน์)

D24 บันทึกว่า `run_order101` + `run_order103` **รันต่อกันใน process เดียวไม่ได้** — 103 พังหลายเคสด้วย
`archive path 'ARCHIVE.md' not readable at <sha>` และตั้งสมมติฐานว่าเป็น temp fixture dir / leftover git state

**วัดใหม่หลังแก้ ORDER-411** (รัน 101→103 ต่อกันใน process เดียว · 881 วินาที): **103 = ALL CASES PASSED ·
`not readable` = 0 ครั้ง** · 101 เหลือ FAIL เดิมตัวเดียวที่ documented (`cross-HEAD-zero-diff`)

**error string ที่ D24 จดไว้ = ของ ORDER-411 เป๊ะ** และกลไก "พังเฉพาะเมื่อรันต่อจาก 101" เข้ากับ
**session-dependence** ของบั๊กนั้นพอดี (ถ้าชุด 101 ทิ้ง `[Console]::InputEncoding` ที่มี preamble ค้างไว้
ชุด 103 จะรับเคราะห์) · **แต่ผมไม่ได้ reproduce อาการก่อนแก้** ⇒ **สาเหตุ = อนุมาน ไม่ใช่พิสูจน์
· ไม่ปิด D24** แค่เขียนผลวัดใส่แถวไว้ให้คนถัดไปดู `InputEncoding` ก่อน fixture dir

## 5. ⚠️ เรื่องที่ต้องบอกเลนอื่น

- **ผมลบ `.git/index.lock` ที่ค้าง** (10:50, 0 ไบต์, ไม่ขยับ 6 นาที, **ไม่มี `git.exe` รันอยู่เลย** และเปิดไฟล์แบบ
  exclusive ได้ = ไม่มี process ถือ) — มันบล็อกทุกเลน. ไม่มีเนื้องานอยู่ในนั้น (0 ไบต์) แต่**ผมไม่ใช่คนสร้าง** จึงแจ้งไว้:
  ถ้าเลนไหนโดน `git add` ล้มช่วง 10:50-10:57 ให้ stage ใหม่ ไม่มีอะไรหาย
- **ORDER-413 ถูกยกเลิกกลางคัน → กลายเป็น `BACKLOG-D27` แทน** — ตอนจะเขียนใบนี้ลงบอร์ด เจอว่า **เลน SLBUFFER
  กำลังแก้ `ORDER-280` ค้างอยู่ใน working tree** (timestamp `CLAIMED(Claude, 2026-07-27 12:20)`) ·
  `git commit -- AGENT_TASKBOARD.md` จะ**ลากงานเขาไปด้วย** (path-limit กันข้ามไฟล์ ไม่กันข้ามบรรทัดในไฟล์เดียวกัน —
  กฎข้อ 3 ของ ledger) ⇒ **ถอนบล็อกของตัวเองออกจาก working tree ด้วยมือ** (ห้าม `git checkout <file>` เด็ดขาด
  มันจะล้างงานที่เขายังไม่ commit) แล้วลงเป็นแถว backlog พร้อมช่อง "ปลุกเมื่อ = บอร์ดว่าง" · **เลข 413 ยังไม่ถูกใช้**
- **index ที่แชร์กันมีของเลน MONITORING staged อยู่** (`scripts/monitor_rotation.ps1`, `portfolio/expectations.csv`,
  `portfolio/control_room_snapshot.json`, `portfolio/live_deals/**`) ⇒ ผม commit แบบ **path-limited** เพื่อ
  **ไม่แตะ index ของเขา** · ตรวจแล้ว commit `960dd178` มีแค่ 8 ไฟล์ของผม และของเขายัง staged อยู่ครบ
  <sub>นี่คือกฎข้อ 4 ของ ledger ทำงานจริง: `git diff --cached` ก่อน commit เห็นของคนอื่นติดมา = หยุด ไม่ใช่ commit ทับ</sub>
- 🔬 **แล้วมันก็เกิดกลับทิศให้ดูสดๆ ในวันเดียวกัน:** commit `99a73910` (เลน SLBUFFER, ORDER-280) **พาแถว B1 ของ
  ORDER-412 ที่ผมยังไม่ commit ไปด้วย** เพราะเขา path-limit ที่ `docs/memory_control/B1_DATASET.csv` ซึ่ง commit
  **เนื้อ working tree ทั้งไฟล์** · **ไม่มีอะไรหาย** (ตรวจแล้ว: แถว 370 · 411 · 412 อยู่ครบใน HEAD) **แต่ provenance เพี้ยน** —
  แถวของผมไปอยู่ใต้ commit ของเขา · **ยืนยันคำเตือนในกฎข้อ 3 ของ ledger ด้วยตัวอย่างที่สอง และชี้ว่ามันเกิดสองทาง
  ไม่ใช่แค่ทางเดียว** ⇒ ไฟล์ append-only ที่หลายเลนเขียน (`B1_DATASET.csv`) คือจุดที่เกิดบ่อยสุด

## 6. ของที่ยังไม่ได้ทำ (ตั้งใจ) — จาก handoff ใบก่อนที่ยังค้าง

- **4 ใบ 🔴 เงินจริงที่รอ user เคาะ ยังไม่ขยับเลย** — `ORDER-230` (บัญชี 463666728 cent vs USD) ·
  `ORDER-232` (MacroGate 990120) · `ORDER-234` (PERSIST_MIGRATION checklist) · `ORDER-235` (บาร์ 30 ไม้)
  **นี่คือคอขวดจริงของ track นี้ ไม่ใช่งาน tooling** — tooling เดินเองได้ ของ 4 ใบนี้เดินไม่ได้ถ้า user ไม่เคาะ
- `findyour8_pdfs/` 888MB · corpus 8 โฟลเดอร์ — ยังไม่ย้าย (รอ user เคาะ)
- grandfather allowlist ใน `check_order_collision.ps1` — hook ยัง NOTE `ORDER-095` (2x) และ `ORDER-082` (2x) ทุกครั้ง

---

## ปลายทางของทุกรายการ

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| `check_stale_binaries` ไม่ส่อง `_vps_deploy` | DONE |
| `($pipeline).Count` = `$null` เมื่อมีผลลัพธ์ชิ้นเดียว ⇒ STALE 1 ตัวเงียบ | DONE |
| BOM บน stdin ทำให้ chain-walk โทษ commit ที่บริสุทธิ์ | DONE |
| fix ของ 411 pin global + branch ที่ไม่มีกรง (เจอจาก `/scrutinize`) | DONE |
| digest แสดง `DONE(attr) + REVIEWED(attr)` เป็น `DONE` ⇒ 341/370/411/412 ดูเหมือนยังไม่ review | BACKLOG-D27 |
| 13 bundle staged เก่ากว่า source — บน VPS รันตัวไหนจริง | ORDER-410 |
| บัญชี 463666728 currency cent vs USD | ORDER-230 |
| MacroGate 990120 disposition | ORDER-232 |
| `--resolve-single-leg-baskets` รอ Codex audit + ratify | ORDER-233 |
| PERSIST_MIGRATION checklist | ORDER-234 |
| บาร์ 30 ไม้ไม่พอดีกับ 4 EA | ORDER-235 |
| lever `_9_RegimeGateAdds` + `CONF_PA_ENGULF` STEP 2 | ORDER-236 |
| RSI-MR หาง basket 98-182 วัน ยาวกว่าวัน judge | ORDER-239 |
| tick history `Meta 5b` เพี้ยน 14 เท่า | ORDER-371 |
| NuiIndy CutLoss 30-vs-100 ยืดหน้าต่าง | ORDER-372 |
| grandfather allowlist ใน collision hook ควรรีวิว | BACKLOG-D23 |
| 2 negative suite รันต่อกันใน process เดียวไม่ได้ | BACKLOG-D24 |
| `findyour8_pdfs/` 888MB + corpus 8 โฟลเดอร์ จะย้ายออกนอก repo ไหม | BACKLOG-D25 |
