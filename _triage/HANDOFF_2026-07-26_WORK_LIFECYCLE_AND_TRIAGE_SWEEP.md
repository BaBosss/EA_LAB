# HANDOFF 2026-07-26 — วงจรชีวิตงาน + กวาด taskboard/_triage

> อ่าน `PROJECT_STATE.md` → ไฟล์นี้ · กติกาการทำงานที่เพิ่งตั้งขึ้น = **`docs/WORK_LIFECYCLE.md`** (อ่านก่อนเริ่มงาน)
> เลนที่เปิดอยู่ = `docs/SESSION_LEDGER.md` · **อย่าเชื่อไฟล์นี้เหนือ repo** — ขัดกันเมื่อไร เชื่อ repo แล้วแก้ไฟล์นี้

## ทำอะไรไป

user ถามว่างานที่ handoff ไว้เข้า taskboard ครบไหม และอันไหนทำแล้ว — คำตอบคือ **ไม่ครบ** และหาไม่เจอด้วย
เลยกวาดทั้งระบบแล้ววางกติกาไม่ให้เกิดซ้ำ

**สิ่งที่วัดได้ตอนเริ่ม:** บอร์ด 102 order (551KB) ในนั้น 82 ใบจบไปแล้วแต่ยังนั่งอยู่ · `_triage/` 198 ไฟล์
ในนั้น 159 คือผลผลิตของงานที่ปิดแล้ว · handoff 17 ใบ 100 รายการ **27 รายการไม่เคยเข้าบอร์ดเลย**

**ผลลัพธ์ (รวม 3 รอบ):** บอร์ด **102 → 39 order** (ย้ายเข้าคลัง 76 ใบ, เปิดใหม่ 17) · `_triage/` **198 → 55 ไฟล์**
(ย้าย 153 ไฟล์เข้า `_triage/_archive/`) · archive **186 → 274 บล็อก** · validator เขียวตลอด (unresolved 0, integrity 0)
<sub>รอบแรกจบที่ 93 order / 208 บล็อก · รอบสอง (ORDER-260/261) ปลดอีก 51+3 ใบ — รายละเอียดหัวข้อ "รอบสอง" ด้านล่าง</sub>

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
2. **validator ตี REVIEWED เป็น NonTerminal** เพราะ `'holdout' -match 'HOLD'` — 17 ใบติดกับนี้ → **ORDER-260 แก้แล้วรอบสอง** `6cb6848d`
3. **digest generator ล้มเงียบ** — `$PSScriptRoot` ว่างใต้ `-File <relative>` + ผมกลบ output ⇒ commit digest ที่ผิด 219 บรรทัด **แก้แล้ว** `8e86c21f`

<sub>บทเรียนร่วม: **substring matching ชนกัน 3 ครั้งใน session เดียว** — `HOLD` ใน "holdout" · `ไฟล์เดียว` ใน "ในไฟล์เดียวกัน"
(check_state §7) · `_archive` ใน "check_taskboard_archive.ps1" (ตัวกรองของผมเอง ซึ่งเกือบทำให้ commit กวาดงาน
session อื่นที่ค้างอยู่). ภาษาไทยไม่มีเว้นวรรค ยิ่งชนง่าย</sub>

---

## รอบสอง (20:00-22:00) — ปิด ORDER-260/261 + root-cause ORDER-270

**บอร์ด 96 → 42 order** (ตอนนี้ 43 เพราะ REV04 เปิด ORDER-280) · **archive 262 บล็อก**

**ORDER-260 ปิด** — `Get-StatusClass` เช็ค NonTerminal ด้วย bare substring ⇒ `'holdout' -match 'HOLD'` = True
⇒ order ที่ REVIEWED แล้วถูกตีเป็น NonTerminal เพราะ verdict ตัวเองมีคำว่า holdout/open
แก้โดย anchor ที่ต้นช่วง backtick · **วัดก่อน/หลัง:** Terminal 47→69 · Terminal+REVIEWED 7→24 (+17) ·
Unparseable คงที่ 4 · archive ไม่ขยับ · กรงใหม่ `scripts/_test/run_statusclass_tests.ps1` 19 เคสจาก corpus จริง
**พิสูจน์แล้วว่า fail ได้** (revert ของที่มันคุม → 3 เคสแดงเป๊ะ)

**ORDER-261 ปิด** — เขียน review 28 ใบตามหลักฐานที่ resolve ได้จริง + แก้ข้อความ 9 ใบที่ถูกหลักฐานใหม่หักล้าง
→ ย้ายเข้าคลัง **54 ใบ** · กันไว้ = `095/#4` (แม่ CAMPAIGN ยัง OPEN)

**ORDER-270 root cause เจอแล้ว (STEP 1-2 ปิด) — และผมวินิจฉัยผิดครั้งแรก**
ผมเคยเขียนว่า suite "ค้าง" โดยอ้าง CPU <1 วินาที — **นั่นคือ CPU ของ process แม่ที่แค่นั่งรอลูก**
ต้นเหตุจริง: `Invoke-ArchiveChainIntegrityCheck` วนทุก commit ในสาย checkpoint→HEAD แล้วยิง
git subprocess **3 ครั้ง/commit** ⇒ **502 commit × 3 ≈ 1,506 spawn ต่อการเรียก 1 ครั้ง** แต่มีแค่
**5 commit ที่แตะ archive** ⇒ ~1,491 ครั้งเป็นงานเปล่า × ~40ms = ~60 วินาที ตรงกับที่วัด
สมมติฐาน 2 อันแรกผิดทั้งคู่ (git chain walk = 42ms · regex cache = precompute แล้วไม่ต่าง 254→278 วิ
⇒ เคลียร์ว่า ORDER-260 ไม่ได้ทำให้ช้า)
🔴 **ยังไม่แก้ walk** — path-filter อาจเปิดรู **BLOCKER 6 "checkpoint laundering ผ่าน merge"** ที่ ORDER-103
REWORK3 จ่ายราคาปิดไปแล้ว · ต้องเขียน targeted test ของ chain-walk ก่อน แล้วค่อยแก้

**B1 ปิดแล้ว** — เติมแถวเฉพาะ ORDER-260/261 (2 ใบที่ผมทำเองและเห็นเอง) · **~30 ใบที่ review ย้อนหลังไม่เติม**
เพราะ metric ของ B1 เป็น live observation และ §3 ห้าม reconstruct — เติมไปก็ได้ค่าปลอมที่ทำลาย signal
· `B1_COHORT.md` แก้เป็น **running log** ตามที่ user เคาะ (เอกสารเขียน 20 ใบ ของจริง 61 ใบ)

**แก้กฎของตัวเอง 2 ข้อ**
1. **ledger ข้อ 3 เขียนเกินจริง** — `git commit -- <path>` commit เนื้อ working tree ของ path นั้น ⇒
   session อื่นแก้ไฟล์เดียวกันระหว่างนั้น การแก้ของเขาติดไปด้วย (เกิดจริง `eda48dd8` พา ORDER-215 ของ REV04 ไป
   งานเขาไม่หาย แต่ provenance เพี้ยน) · **path-limit กันข้ามไฟล์ ไม่กันข้ามบรรทัดในไฟล์เดียวกัน**
   ตัวที่กันจริงมีแต่ข้อ 4 (หนึ่งไฟล์รวม หนึ่งคนเขียน)
2. **"handoff ใบเดียว" ต้องเป็น "ใบเดียวต่อเลน"** ไม่ใช่ต่อ repo — ตอนนี้มี 2 เลนทำงานคู่กันจริง
   แต่ละเลนมี handoff ของตัวเองถูกต้องแล้ว (`SUPERTRENDFLIP` = REV04 · ใบนี้ = systems)

---

## รอบสาม (2026-07-27 08:00-10:00) — ตรวจงานคนอื่น แล้วเจอบั๊กที่ใหญ่กว่า

**บอร์ด 51 → 39 order · archive 274 บล็อก**

**ORDER-270 (คนอื่นทำ) ตรวจแล้วผ่านทุกข้อ** — `-Audit` 254s→**9.7s** (เขาอ้าง 7.6s) · ผล bit-identical ·
chainwalk **11/11** · ชุด 103 **41/0** · ชุด 101 **25/1 ใน 116 วินาที** (จากที่เคยค้าง 30-45 นาที · 1 ที่ FAIL =
`cross-HEAD-zero-diff` ที่ documented ว่า pre-existing)
**วิธีเขาดีกว่าที่ใบสั่งเสนอ** — ปฏิเสธ path-filter ของผมด้วยเหตุผลที่ถูก (มันเปลี่ยน "commit ไหนถูกเดินผ่าน"
แล้ว history simplification อาจตัด merge ที่สำคัญพอดี) ใช้ `cat-file --batch-check` map commit→blob OID ครั้งเดียวแทน

**🎯 ORDER-390 — บั๊กที่โผล่เพราะไปตรวจ** · ORDER-270 **ย้ายเข้าคลังไม่ได้**ทั้งที่ REVIEWED แล้ว
เพราะ markdown backtick เดี่ยว**ซ้อนกันไม่ได้**: `` `DONE(..., `3a2cee7e`) ... + REVIEWED(...)` `` แตกเป็นหลายสแปน
สแปนแรกมีแค่ `DONE` ⇒ parser return ทันที **ไม่เคยเห็น REVIEWED**
**วัดได้ 6 ใบ** (`341` `270` `238` `251` `252` `097`) เขียน REVIEWED แล้วแต่ถูกจัดเป็น `DONE` ⇒ **นั่งบนบอร์ด
เหมือนงานที่ยังไม่เสร็จ** · **คลาสเดียวกับบั๊ก substring ของ ORDER-260 เป๊ะ** — โมเดล parser ไม่ตรงกับวิธีคนเขียนจริง
และพังแบบเงียบ · จะเกิดซ้ำเรื่อยๆ เพราะอ้าง commit sha ในสถานะเป็นเรื่องธรรมชาติ
แก้แบบแคบ (ต้องเป็น `REVIEWED(` มี attribution ไม่ใช่คำเปล่า · รันหลัง NonTerminal scan) · **กรงมาก่อนแก้**
(2 เคสแดงก่อน → **23/23** หลังแก้) ⇒ archivable **6 → 12** · ย้าย 12 ใบ

**บทเรียนที่ต้องจำ:** ⚠️ **อย่าเชื่อจำนวน order ที่ยังเปิดโดยไม่คำนวณจากตรรกะ validator เอง** — grep คำว่า
`REVIEWED` แล้วเชื่อ = พลาดทั้ง 2 บั๊ก (substring ของ 260 และ nested-backtick ของ 390)

## ที่ยังไม่ได้ทำ (ตั้งใจ)

- ~~**🔴 ORDER-270 = งานถัดไปที่ชัดที่สุด**~~ **✅ ปิดแล้ว 2026-07-27 โดย session อื่น (`3a2cee7e`) · ผมตรวจยืนยันเอง**
  254s→9.7s · chainwalk 11/11 · ชุด 103 41/0 · ชุด 101 25/1 · **เขาไม่ใช้ path-filter** (เหตุผลถูกกว่าที่ใบสั่งเสนอ)
  <sub>ข้อความเดิมด้านล่างเก็บไว้เป็นประวัติ — ตอนเขียนมันคือ current state จริง:</sub>
  <sub>root cause เจอแล้ว ทางแก้เขียนไว้ครบ **แต่ห้ามแก้ก่อนมี targeted test
  ของ chain-walk** (path-filter อาจเปิดรู BLOCKER 6 merge-laundering กลับมา) · ตอนนี้ระบบ tamper-integrity
  ของ ORDER-102/103 ยืนอยู่บนกรงที่ใช้เวลา 30-45 นาที = de-facto ไม่มีใครรัน</sub>
- **`ORDER-098-C` ไม่ซ้ำแล้ว** — ทั้ง 2 บล็อกย้ายเข้าคลังพร้อมกันในรอบสอง · แต่ **grandfather entry ใน
  `check_order_collision.ps1` ยังอยู่** (095 · 082 ยังซ้ำจริง) ควรรีวิว allowlist ใหม่
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
| validator substring ตี REVIEWED เป็น NonTerminal | DONE |
| กอง B 28 ใบรอ REVIEWED + 9 ใบต้องแก้ข้อความ | DONE |
| กรง validator ใช้ไม่ได้ (1,506 git spawn/run) — แก้แล้วโดย session อื่น · ผมตรวจยืนยันเอง 254s→9.7s | DONE |
| inline code ใน status span ซ่อน REVIEWED ⇒ 6 ใบค้างบอร์ดเงียบๆ | DONE |
| 2 negative suite รันต่อกันใน process เดียวไม่ได้ (false FAIL ทั้งกำแพง) | BACKLOG-D24 |
| ORDER-280 `CLAIMED` ค้าง (REV04 ปิดโดยไม่ปล่อย) — SLBUFFER ACTIVE ถือแถวนั้นอยู่ | ORDER-280 |
| B1 rows สำหรับ order ที่ทำเอง + แก้ `B1_COHORT.md` เป็น running log | DONE |
| ledger ข้อ 3 เขียนเกินจริง (path-limit ไม่กัน co-edit ในไฟล์เดียวกัน) | DONE |
| grandfather allowlist ใน collision hook ควรรีวิว (098-C ไม่ซ้ำแล้ว) | BACKLOG-D23 |
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
