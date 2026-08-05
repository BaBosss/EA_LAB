# HANDOFF 2026-07-27 — LEVERFAN (ORDER-340 · 341 · 236)

> อ่าน `PROJECT_STATE.md` → ไฟล์นี้ · กติกา = `docs/WORK_LIFECYCLE.md` · เลนที่เปิดอยู่ = `docs/SESSION_LEDGER.md`
> **อย่าเชื่อไฟล์นี้เหนือ repo** — ขัดกันเมื่อไร เชื่อ repo แล้วแก้ไฟล์นี้
> ใบก่อนหน้าของ session เดียวกันนี้ = `_triage/HANDOFF_2026-07-27_GREENYELLOW_BATCH.md` (ORDER-270/238/252/251/231/250/205/206)

## รอบนี้ทำอะไร

user สั่ง "ทำต่อ" หลังปิดกองเขียว+เหลือง · หยิบ 2 งานที่ตัดสินอะไรได้จริง: fan ที่ขาดของ GBPJPY และ lever A/B ที่ค้างมานาน
· ระหว่างทางเจอบั๊กเครื่องมือที่เกือบทำให้ A/B วัดอะไรไม่ได้เลย

## ✅ ORDER-340 ปิด — GBPJPY 1.37 คือเกาะจุดเดียว

| SlAtrMult | 0.75 | 1.0 | 1.25 | **1.5** | 2.0 | 2.5 |
|---|---|---|---|---|---|---|
| PF | 0.93 | 0.87 | 0.94 | **1.37** | 1.01 | 0.90 |

ORDER-206 วัดขึ้นข้างเดียวจาก base ⇒ แยกไม่ออกว่า plateau หรือหน้าผา · วัดฝั่งที่ขาดแล้ว = **หน้าผา ตรงตามบาร์ที่ pre-register**
และแย่กว่านั้น: เพื่อนบ้านสองข้างอยู่ที่ 0.94 / 1.01 ⇒ **ทั้งแกนขาดทุนยกเว้นจุดเดียว** = overfit point ไม่ใช่ edge
**ตายแค่ cell GBPJPY×SL-axis** — ไม่ใช่ EA · PivotBreakout XAU (992017) ยังเป็น CANDIDATE แข็งสุดของ Wave-1 เหมือนเดิม
**ต้นทุนของการรู้ = 3 run · ต้นทุนของการไม่รู้ = demo slot + 3 เดือน**

## ✅ ORDER-341 ปิด (ครึ่งแรก) — detector รายงาน 8 จาก 56

`check_stale_binaries.ps1` ให้ `$status` ช่องเดียวแบบ first-wins และเช็ค `HASH_DIFFERS` **ก่อน** staleness
· MQL5 compile ไม่ byte-reproducible ⇒ EA ที่มี >1 สำเนา hash ต่างเสมอ ⇒ **`STALE` ไม่มีวันถูกติดป้าย**
· ข้อความ staleness ยังอยู่ใน `detail` มาตลอด — **ข้อมูลครบ แต่ไม่มีป้าย** และป้ายที่ block คือสิ่งที่ทำให้คนมอง
**แก้เป็น ranking** `STALE > HASH_DIFFERS > OK` + ฟิลด์ `hash_differs` แยก ⇒ **8 → 56** (advisory คงที่ 132 ไม่มีอะไรหาย)

🔴 **ของจริงที่เกือบเกิด:** `Boss_14_GridLog.ex5` ในเลน 5b คอมไพล์ 07-18 = ก่อน `Inputs.mqh` เปลี่ยน 6 วัน และไม่ครอบ lever ที่จะ A/B
ถ้าปล่อยไป → input ไม่มีในไบนารี → MT5 ดึงค่าจาก per-terminal cache → **A/B สองฝั่งเป็น run เดียวกัน รายงานออกมาเป็น null ที่ดูสะอาด**
· refresh ก่อนรัน และ worker ยืนยันจากหน้า Inputs ของรายงานแล้วว่า lever โผล่จริง

## 🔴 ORDER-236 = `BLOCKED` ที่ประตูของตัวเอง (รัน 2 จาก 8)

CTRL (Boss_14 AUDNZD H1, **Model 4 real ticks**, `B14_AB_off.set`): **MAIN 1.09 / BWD 0.84** (net −510.30)
บาร์ pre-register: "control BWD ไม่เกิน 1.0 แบบสบาย ⇒ หยุด" ⇒ worker หยุด **ประหยัด Model-4 ไป 6 run**

**ผมเลือก host ผิด 2 ครั้งในใบเดียว รากเดียวกัน:**
· RSI-MR — เลือกเพราะ BWD 1.56 สวยสุด **ไม่ได้เปิด `.mq5`** ⇒ standalone ไม่มี input ทั้งสองตัว (= failure mode ของ ORDER-143 เป๊ะ)
· Boss_14 AUDNZD — เลือกเพราะ **prose ในสกอร์การ์ด** บอกว่าเป็น leg แข็งสุด **ไม่เคยวัด BWD ของ config ที่ A/B ใช้จริง**
⇒ **เลือก host จากชื่อเสียง ไม่ใช่จากการวัด artifact ที่จะใช้จริง** · ที่กันไว้ได้คือ**ประตูที่เขียนก่อนเห็นตัวเลข** ไม่ใช่ผมเลือกเก่งขึ้น

⚠️ **อย่าเอา 1.09/0.84 ไปหักล้าง demo cohort** — `B14_AB_off.set` คือ ORDER-006 ISpick parity set (lot 0.10, magic 990101)
**ไม่ใช่** `Boss14_GridLog_AUDNZD_DEMO.set` (0.25x) ที่ deploy บน 990202 · มันบอกว่า**config ฐานของ A/B**ไม่ผ่านประตูเท่านั้น

## สิ่งที่ยังไม่ได้ทำ (ตั้งใจ)

- **host search ยังไม่เปิดเป็นใบ** — วิธีที่ถูก: รัน **CTRL อย่างเดียว 2 run/host (Model 4)** ไล่ตระกูล `Boss_11..18`
  หาตัวที่ BWD > 1.0 สบายจริง แล้วค่อยเอา lever เข้า · **ถ้าไล่ครบไม่มีใครผ่าน = คำตอบของใบนี้** (lever ไม่มีบ้าน ≠ lever ไม่ดี → park)
- **55 binary ที่ stale จริงบนดิสก์** — ไม่กวาดรวดเดียวโดยเจตนา ต้องไล่ทีละตัวว่ามันเคยผลิตหลักฐานอะไรไปแล้ว
  โดยเฉพาะ `MacdDiv_Naked` ที่ ORDER-205 เพิ่งรันเมื่อเช้า (สำเนา 5c สืบสายจาก `c091c\` ที่อยู่ในกอง masked)
- **GBPJPY แกนอื่น** — deploy set เป็นของ XAU ไม่เคย optimize สำหรับ GBPJPY เลยสักแกน ⇒ cell ยังไม่ปิด

## หมายเหตุข้ามเลน

เลน `VERIFY270` ตรวจ ORDER-270 ของ session นี้แบบอิสระแล้ว **ยืนยันได้ทุกข้อ** (254s→9.7s · ผล bit-identical · chainwalk 11/11 · ชุด 103 41/0)
และไปเจอ **ORDER-390** ต่อ (inline code ใน status span ทำให้ `Get-StatusClass` มองไม่เห็น REVIEWED ⇒ 6 ใบนั่งบอร์ดเงียบๆ)
— คลาสเดียวกับ ORDER-260 ที่ผมอ้างถึงใน ORDER-252 · บอร์ด 51→39

---

## ปลายทางของทุกรายการ

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| GBPJPY SL fan ฝั่งต่ำกว่า base — plateau หรือหน้าผา | ORDER-340 |
| stale detector รายงาน 8 จาก 56 (ป้าย advisory ทับ blocking) | ORDER-341 |
| 55 binary ที่ stale จริง ยังไม่ไล่ว่าตัวไหนผลิตหลักฐานอะไร | ORDER-341 |
| lever 2 ตัวยังไม่มี host ที่ผ่านประตู BWD | ORDER-236 |
| host search: CTRL-only ไล่ตระกูล Boss_11..18 หา BWD>1.0 | ORDER-236 |
| GBPJPY ต้อง optimize แกนอื่น (deploy set เป็นของ XAU) | ORDER-206 |
| optimize MacdDiv บน USDJPY H4 (บ้านที่ผ่าน both-window) | ORDER-205 |
| PF-5th เป็นบาร์ที่ตกไม่ได้ภายใต้ MC ปัจจุบัน | BACKLOG-D11 |
| 1088 คู่ correlation ที่ยังอยู่บน default 1.0 | BACKLOG-D8 |
| ORDER-280 rev04 ค้างที่ STEP 0 ไม่มีตัวเลข | ORDER-280 |
| บัญชี 463666728 currency cent vs USD | ORDER-230 |
| MacroGate 990120 disposition | ORDER-232 |
| flag `--resolve-single-leg-baskets` รอ Codex audit | ORDER-233 |
| PERSIST_MIGRATION checklist | ORDER-234 |
| บาร์ 30 ไม้ไม่พอดีกับ 4 EA | ORDER-235 |
| RSI-MR หาง basket ยาวกว่าวัน judge | ORDER-239 |
| 4 commit hash ที่ resolve ไม่ได้ (102/103/128) | BACKLOG-D23 |
