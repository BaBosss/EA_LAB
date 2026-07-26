# HANDOFF 2026-07-26B — the labels were fixed yesterday; today we walked the boxes

> Session owner: Opus-seat. Commits: `0e37c0a` · `85b55fd` · `7fb0c15` · `9bcc6c2` · `bcc1e59` · `aee0645`
> (+ this one). **ไม่แตะบัญชีใดเลย · ไม่ใช้ holdout · ไม่รัน optimize · ไม่แก้ `.set` ให้ EA ติดอาวุธ**
> ⚠️ มี session คู่ขนานทำงานหนักวันเดียวกัน (`5110c51e` handoff, `6010543b` Boss_16 attach,
> `eda47330` CR-P0) — commit ของผม path-limited ทุกครั้ง, HEAD ขยับกลางทาง 2 ครั้งจริง

## เริ่มจากอะไร
คำถามเดียว: "991001 บนเงินจริงรัน v2 หรือ v3" (v3 ถูกเลือกบนหน้าต่างที่กิน holdout)
คำตอบได้แล้ว **แต่สิ่งที่เจอระหว่างทางใหญ่กว่าคำถาม**

## ✅ ปิดแล้ว — 991001 = v2 บนเงินจริง (CR-002 set-lineage ปิด)
user เปิดหน้า Inputs บน VPS อ่านสด 2026-07-26: `Bars40 · Sl1.5 · Tp5.0 · Ema200 · AllowLive=true`
บน XAUUSDc H1 = **v2 เป๊ะ** → `ATTESTATION_MAP` 991001 ยกเป็น **high**
v3 ไม่เคยถูกโหลดขึ้นเงินจริง และตอนนี้ติด `⛔ DO-NOT-DEPLOY` แล้ว

หลักฐานเอกสารที่นำไปก่อนการอ่านจริง (เก็บไว้เพราะวิธีใช้ซ้ำได้): `git log -L <line>,<line>:<file>`
บน default 3 ตัว → commit เดียวต่อบรรทัด = ไม่เคยถูกแก้ตั้งแต่วันสร้างไฟล์ ⇒ .ex5 build ไหนก็ได้ v2

## 🔴 ธีมของวัน — sweep 2026-07-25 แก้ "ป้ายในทะเบียน" แต่ไม่ได้แตะ "README ข้างกล่อง .ex5"
README คือสิ่งที่คนอ่านจริงตอน attach **ตรวจ 22 กล่องใน `_vps_deploy` แล้วติด banner 11 กล่อง**

| กล่อง | โรค |
|---|---|
| `BRK_XAU_live_v3.set` (+ MASTER_BACKLOG + DEMO plan) | **คำสั่งค้างให้โหลดทับของจริง 3 ที่** — checkbox ที่ไม่เคยติ๊ก + แถว `🟡 RELOAD` |
| `MACROGATE_DEMOLEG` | ยังนำด้วย "eqDD −54..−56%" ที่ ORDER-211 สั่งห้ามอ้าง |
| `MACDDIV_XAU` | "full funnel cleared" โดยใช้ plateau ปลอมเป็นเหตุผลนำ |
| `BOSS14_GBPJPY` | ไม่มีหมายเหตุว่า 2026H1 ถูกใช้ไปแล้ว |
| `WAVE5_XAU/XAG/USDJPY` | contaminated selection (ดูข้างล่าง) |
| `EA_BREAKOUT_US30` | พาดหัว 1.46 → clean re-run 1.21 (~58% ของ net มาจาก 6 เดือนที่ไหม้) |
| `ST03_GBPUSD` | ยังเขียน "DEPLOY SMALL" ทั้งที่ถูกถอดจากบัญชีจริง 2026-07-18 |
| `CB_EUR` | ยังเขียน "deploy with close monitoring" ทั้งที่ทะเบียน DROP ตั้งแต่ 2026-06-25 |
| `EA_SUPERTREND_XAU` | หัวข้อ "validated" แต่ OOS สะอาดหน้าเดียวที่มี = **PF 0.88 / net −91.49 หายไปจากไฟล์** |
| `BRK_XAU_Bars8` | ไม่มี README เลย · เลขใน `.set` เป็นของ cell คนละใบ (2.61/3.92 vs จริง 1.66/3.85) |
| `EXP_ADAPTGRIDMC` | `.set` 2 ใบ ไม่มี README ไม่มี .ex5 นั่งใน attach surface ของ EA ที่ DEAD-STRUCTURAL |

## 🔴🔴 ของที่ใหญ่ที่สุด — ORDER-202 retro-scan มีช่องโหว่ในวิธีการ (Part 4 ในไฟล์นั้น)
scan นับว่าเป็น "selection" เมื่อ `Optimization != 0` — **flag นั้นบอกแค่ว่า optimizer ของ MT5 ขับ run
ไหม ไม่ได้บอกว่ามีการเลือกพารามิเตอร์เกิดขึ้นหรือเปล่า** repo นี้เลือก param ด้วย PowerShell loop เป็น
เรื่องปกติ (ini ใบละ cell → ทุกใบ `Optimization=0` → ผลลง CSV → อ่านแถวที่ชนะด้วยมือ)

**นิยามที่ถูก:** run เป็น selection ถ้าผลของมันถูกเอาไปเทียบกับ run อื่นเพื่อเลือก config — ไม่ว่า flag
จะเป็นอะไร. `Optimization != 0` = เงื่อนไข**เพียงพอ ไม่ใช่จำเป็น**

- **Wave5 ทั้ง 3 ขาที่ deploy** (990301/302/303, demo 463666728) เลือกจาก grid ที่ทุก cell รันถึง
  `2026.07.01` · ไม่มี `.ini` สักใบใน funnel นี้ที่ MAIN จบ ≤ `2025.12.31` (เช็คครบ 41 ใบ)
- agent กลุ่ม 1 วัดอิสระว่า flag **นับ selection ขาดราว 6:1** ในกลุ่มนั้น
- **clearance ที่ต้องเช็คใหม่ (คิวไว้ ยังไม่ทำ ห้ามเดา):** `EmaStoRev` 991070 · `MacdDiv_Naked` 999094 ·
  `EA_DONCHIAN` 990030 — ทั้งสามถูกเคลียร์ด้วยประโยค "optimize passes จบที่ 2026.01.01" = ใช้ flag เป็นตัวกรอง
- **clearance ที่ยังยืนได้** = แบบที่ trace ค่าที่ deploy ไปหา pass สะอาดโดยตรง (Boss_14 = ตัวอย่างที่ดี)

## guard sweep — 38 แถว (`_triage/AUDIT_GUARDS_NEVER_FIRED.md`)
`FIRED-AND-MEASURED` 6 · `NEVER-FIRED` 13 · `NO-CONTROL` 14 · `NO-EVIDENCE` 4 · `DEAD-CODE` 1
ผม spot-check 2 แถวที่หนักสุดเอง **ทั้งคู่ต้องแก้** (บันทึกไว้ท้ายไฟล์นั้น):

- **🔴 TrendlineBreakout 991002 (เงินจริง 159503454) — agent misattribute ข้าม EA แล้วผมส่งต่อโดยไม่ตรวจ binary**
  agent โยง `_04_UseAdxGate` มาที่ deployment นี้ **แต่ EA ที่รันจริงคือ `rev01` ซึ่งไม่มี input ตัวนั้นเลย**
  (trend filter ของมันคือ `_03_UseEma`) — A/B `TL2*`/`TL2NG*` รันบน `Expert=(BRK)_TrendlineBreakout_rev02`
  คนละไฟล์. user เปิดหน้า Inputs ให้ดู 2026-07-26 = จบ **ไม่มีอะไรต้องแก้บนชาร์ต**
  agent ยังเขียน "gate แพ้ 2/3 หน้าต่าง" ผิดด้วย — BWD 1.25 vs 1.26 คือ noise, gate ชนะชัดช่วง 2023-25
  ข้อความที่ถูก: **ชนะหน้าต่างกลาง แพ้หน้าต่างล่าสุด** (2025-2026.07: on `0.99/−12.97/63t` vs off `1.23/+339.87/81t`)
  ⇒ ค่าที่เหลือของผลนี้ = **ห้ามอัปเกรด 991002 เป็น rev02** (กรณีกลับด้านจาก "ของเก่าค้าง" ที่เราระวังกันทั้งวัน)
  **ของจริงที่โผล่แทนจากภาพเดียวกัน:** live `_02_TpAtrMult=8.0` ขณะที่ default ของ `rev01` = 4.0
  ⇒ มีการเลือกอย่างน้อย 1 แกนบนเงินจริงโดยไม่รู้ที่มา → **BACKLOG-D21**
  <sub>⚠️ magic 991002 ถูกใช้ 2 ที่: ตัวนี้ (Trendline บน 159503454, ACTIVE) กับ BRK Bars8 บน
  159475669 ที่ **user ถอดแล้ว 2026-07-26** — คนละตัว อย่าสับสน</sub>
  <sub>บทเรียน: guard/lever finding ต้อง**ยืนยันว่า input นั้นมีอยู่ใน binary ที่ deploy จริง**ก่อนเสมอ —
  ชื่อ EA ตรงกันไม่พอเมื่อ repo มี rev01/rev02 อยู่ข้างกัน</sub>
- **SqueezeBreakout 991004 (เงินจริง)** — agent บอก "ไม่มี ini เลย" = artifact ของการ match ชื่อ
  (มี 120 ใบใต้ alias `Expert=SQZ`) **แต่ข้อสรุปรอดด้วยเส้นทางแย่กว่า:** ไม่มีสักใบที่มีบรรทัด
  `EmergencyDdPct`/`DailyLossPct` ⇒ ตาม tester-cache defect ค่ามาจาก cache ⇒ **ไม่รู้ว่าค่าอะไรทำงานอยู่**

**สองตัวที่โครงสร้างปกป้องไม่ได้:** RSI_MR 990103 `EmergencyDdPct=40` ขณะที่คนถอดมันออกจากเงินจริงที่
DD **25%** (guard สูงกว่าจุดที่มนุษย์ทนไม่ไหว 15 จุด) · Boss chassis `_0_MaxSpread=0` ใน 613/613 run
และทุก `.set` ที่ deploy + `TrendFilter=70` (= NONE)

**ข้อจำกัดที่ต้องเก็บไว้:** `portfolio/live_deals/*.csv` **ไม่มีคอลัมน์บันทึกไม้ที่ถูกบล็อกหรือ kill ที่ทำงาน**
⇒ ไม่มีอะไรในบันทึกจริงยืนยันได้เลยว่า guard ตัวไหนเคยทำงานในสนามจริง — ความเชื่อ "เดี๋ยว guard รับ"
ทุกข้อในรีโปนี้ตอนนี้**พิสูจน์ผิดไม่ได้**

## ปลายทางของทุกรายการ

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| 991001 = v2 ยืนยันจากหน้า Inputs สด · ATTESTATION low→high | DONE |
| banner 11 กล่องใน `_vps_deploy` (v3 · MACROGATE_DEMOLEG · MACDDIV · BOSS14 · WAVE5 ×3 · US30 · USDJPY · ST03 · CB_EUR · SUPERTREND · Bars8 · ADAPTGRIDMC) | DONE |
| ORDER-202 Part 4 — blind spot ของ scan + นิยาม selection ที่แก้แล้ว | DONE |
| replay v2-vs-v3 ปิด INCONCLUSIVE + ห้ามรันซ้ำ | DONE |
| ADX gate 991002 = ไม่ applicable (live เป็น rev01 ไม่มี gate) + `_02_TpAtrMult=8.0` ไม่มีที่มา | BACKLOG-D21 |
| ตรวจ 3 clearance เดิม (EmaStoRev · MacdDiv · EA_DONCHIAN) ด้วยนิยามใหม่ | BACKLOG-D22 |
| Wave5 3 ขา — รัน MAIN สะอาดก่อน judge | BACKLOG-D17 |
| banner กลุ่ม 1 ที่เหลือ 6 กล่อง (+ ICHIADX ไม่มีแถวทะเบียน) | BACKLOG-D18 |
| NuiIndy — base control run ที่ขาด | BACKLOG-D19 |
| `live_deals` ไม่บันทึก guard ที่ทำงาน | BACKLOG-D20 |
| MacroGate leg 990120 — เก็บ/ย้าย/ถอด + `.set` ที่ยังขาด | DONE (user ratified 2026-07-26, `608f9d5` — ORDER-211 REVIEWED อยู่แล้วใน archive) |
| ร่างกฎ guard-evidence เข้า VERDICT GATE | DONE (user ratified 2026-07-26, `608f9d5` — เข้า `CLAUDE.md` แล้ว) |

## รอ user
1. ~~`_04_UseAdxGate` ของ 991002~~ → **ปิดแล้ว 2026-07-26: live เป็น `rev01` ซึ่งไม่มี ADX gate เลย**
   (A/B `TL2*` รันบน `_rev02` คนละไฟล์ — ผมโยงผิดแล้วส่งต่อ). ของใหม่ที่โผล่แทน = `_02_TpAtrMult=8.0`
   บนเงินจริงขณะที่ default = 4.0 → **BACKLOG-D21**
2. **เคาะ 990120** — ข้อเสนอผม: **คงไว้ที่ USDJPY เป็น plumbing sensor ไม่ย้าย ไม่ถอด**
   (ไม่เห็นด้วยกับ "ย้ายไป AUDJPY" ของ session ก่อน — host ขาดทุนทั้ง ON และ OFF ทั้งสองคู่
   เปลี่ยน symbol ก็ยังแยก "จับจังหวะถูก" จาก "แค่เทรดน้อยลง" ไม่ได้)
3. **เคาะร่างกฎ** `_triage/PROPOSAL_GUARD_EVIDENCE_RULE.md` — guard ที่ไม่เคยติด = `UNTESTED`
   ห้ามเขียนว่าผ่าน (ผมไม่แก้ `CLAUDE.md` เอง — gate tree เป็นของ user)
4. *(ต่ำสุด)* save `.set` ของ 990120 ปิด attestation gap — ทำตอนสะดวก

## ยังไม่ทำและตั้งใจไม่ทำ
- ไม่ติด banner กลุ่ม 1 ที่เหลือ 6 กล่อง (`ZEUS_AUDJPY` · `ICHIADX` ×2 · `SMCSTO` · `CB_GBP` ·
  `RSI_MR`) — เป็น HOLDOUT-SPENT/contaminated จริง แต่**ไม่มีคำสั่งค้างให้ใครหยิบไปทำ** จึงไม่เร่ง
- ไม่เปิด clearance 3 ตัวข้างบนใหม่ — เข้าคิว ไม่เดา
- **ไม่แก้ `.set` ให้ `AllowLive=true`** ตอนเจอเคส crypto — การติดอาวุธให้ EA ส่งคำสั่งเป็นการตัดสินใจ
  ของเจ้าของ แม้เป็นเดโม (user อ่านเจอเองแล้วแก้เอง 2026-07-26, judge re-base เป็น 2027-01-26)

## บทเรียนกระบวนการ
**ตัวชี้วัดเชิงรูปแบบถูกใช้แทนสิ่งที่มันควรบ่งบอก — เจอ 3 แบบในเดือนเดียว:** flag `Optimization` แทน
"มีการเลือกไหม" · guard ที่ไม่เคยติดแทน "guard ปลอดภัย" · neighbour บนแกนตายแทน "plateau ทน"
⇒ **เจอหลักฐานที่ "ผ่านเพราะไม่มีอะไรขัด" ให้ถามว่ากลไกที่ควรทำให้มันขัด เคยทำงานหรือยัง**

และความผิดของผมเองในวันนี้: สั่ง replay v2-vs-v3 ทั้งที่**วิธีนั้นตอบไม่ได้ตั้งแต่ต้น** (high 55 บาร์
≥ high 40 บาร์เสมอ ⇒ ไม้ v3 เป็น subset ของ v2 ⇒ การเห็นไม้เกิดขึ้นไม่แยกอะไร) เหตุผลล็อกไว้ใน
`_triage/ORDER_BRKXAU_LIVE_REPLAY.md` พร้อมคำสั่งห้ามรันซ้ำ

## memory ใหม่/อัปเดตจาก session นี้
`optimization-flag-launders-hand-rolled-selection` (ใหม่) ·
`discriminating-test-must-be-able-to-discriminate` (ใหม่) ·
`inert-axis-fake-plateau` (+NuiIndy guard case, +ข้อ 6 ใช้กับ guard) ·
`brk-xau-991001-v3-selected-into-leak` (ปิดเป็น v2)
