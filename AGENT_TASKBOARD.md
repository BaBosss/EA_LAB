# AGENT_TASKBOARD — คิวงานกลางของทุก agent

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **คิวงาน + ผลดิบระหว่างรอ review เท่านั้น** ·
> กติกาเต็ม → `AGENTS.md` (อ่านก่อน claim) · verdict สุดท้ายไม่อยู่ที่นี่ — อยู่ที่ EA_SCORECARD/PROJECT_STATE
>
> สถานะ: `OPEN` → `CLAIMED(agent, เวลา)` → `DONE` / `BLOCKED(คำถาม)` → `REVIEWED(Claude)`
> agent อื่นแก้ได้เฉพาะแถว order ที่ตัว claim · เพิ่ม order ใหม่ = Claude/user เท่านั้น
>
> 📋 **ORDER TEMPLATE (บังคับตั้งแต่ ORDER-124+ · framework Part 5 enforcement #1):** order ทดสอบ/optimize ทุกใบ
> ต้องมี 2 บรรทัดนี้ในสเปก — pre-register ก่อนรัน ห้ามเติมย้อนหลัง:
> - `bars:` pass = X · dead = Y · กลาง(WATCH/build-on) = Z   ← เลขตัดสินที่ล็อกก่อนเห็นผล
> - `flat-lot probe:` done / N-A(single-order) / pending   ← ถ้ามี escalation ต้อง done ก่อนตัดสิน STRUCTURAL
>
> 🌳 **CONDITIONAL-ORDER TEMPLATE (บังคับสำหรับทุก order ที่จ่ายให้ lane ตอน Claude ไม่อยู่ — oc-qwen/qwen/ZCode ·
> user directive 2026-07-25 · ฉบับเต็ม + เหตุผล → `docs/QUOTA_FALLBACK_PLAYBOOK.md`):** order ที่ไม่มีบล็อก
> `TREE:` = **worker ห้ามรับ** (มันจะจบที่ STEP 1 แล้วเครื่องว่าง ซึ่งคือปัญหาที่ template นี้แก้)
> ```
> ## ORDER-xxx — <ชื่อ> — `OPEN` · ทำได้: <agents> · 👉 แนะ: <default>
> **bars:** pass = X · dead = Y · กลาง = Z          **flat-lot probe:** done / N-A / pending
> **STEP 1:** <คำสั่งรันที่ copy ไปวางได้ตรงๆ — EA/symbol/TF/window/path ครบ>
> **TREE:** PF ≥ pass → STEP 2A <สเปกครบ> · pass > PF ≥ กลาง → STEP 2B <สเปกครบ> ·
>           PF < dead → STOP lane นี้ + ไป order ถัดไป (ห้ามสรุปว่า "ตาย" — verdict = Claude) ·
>           ไม่เข้า branch ไหน / รันพลาด 2 ครั้ง → `BLOCKED(<คำถาม + ตัวเลือก A/B>)` แล้วแจ้ง user
> **ห้าม:** verdict · แตะ scorecard/MASTER_INDEX/EDGE_CATALOG/PROJECT_STATE/VISION/B1_DATASET ·
>          แตะ .mq5 หรือ ea_template\core\ · แตะ _vps_deploy/.set ของ EA ที่ demo อยู่ · Model-2 ·
>          ตีความผลนอก branch · เปลี่ยนค่าที่ STEP ไม่ได้ระบุ
> ```
> ทุก branch ต้องรันได้ทันทีโดยไม่ต้องคิด ("SL {2.5,3.0,3.5} step 0.5" = ใช่ · "ลองปรับดู" = ไม่ใช่) ·
> ปลายทุกกิ่งต้องเป็น **STEP ถัดไป / STOP / BLOCKED** เท่านั้น ห้ามมีปลายเปิด · ลึก 2-3 ชั้นกำลังดี
>
> 🏁 **track merge EA_CORE → Boss V2: ปิดแล้ว (เปิด+จบ 2026-07-06)** — อะไหล่เข้าแม่พิมพ์ครบ
> (pyramid 93 · acct-DD gate · Persist · tests\) + EA_Project = read-only archive · บันทึกเต็ม →
> `AGENT_TASKBOARD_MERGE.md` (เหลือ MERGE-07 Entry_ST03 = HOLD ถึง judge — เงื่อนไขอยู่ในบอร์ดนั้น)

---

> 🔧 **SYSTEMS TRANCHE ORDER-152..158 (เขียน 2026-07-23, Opus-seat)** — งาน infra/tooling ล้วน ไม่ใช่ verdict EA.
> ที่มา = 2 backlog รวมกัน: (A) review แผน `docs/EA_CORE_TEMPLATE_WORKPLAN_FOR_CLAUDE.md` (7 finding ของ Opus
> + 4 ที่ Codex จับเพิ่ม) (B) `ROADMAP.md` §3 development backlog. **ลำดับ = อะไร block งานอื่น/เสียข้อมูลถาวร
> ก่อน ไม่ใช่อะไรง่ายก่อน.** T1 = 152-155 (ทำก่อน) · T2 = 156-158 (ตามหลัง ไม่เร่ง).
> **ไม่เขียนเป็น order (มี trigger ชัดแทน):** PQ-02 deflated gate = LOCKED + ยังไม่ binding (order ที่ค้างอยู่ N≤50
> ทุกใบ → บาร์คง 1.20) unlock เมื่อมี screen order แรกที่ N>50 · PQ-01 vol-target rebalancer เต็มรูป = ต้องใช้ deals
> จริง ≥3 เดือน ซึ่ง cohort ใหม่ยังไม่มี รันไม่ได้ก่อน ~ต.ค. · MT5 เลน 2/3 = `AGENTS.md` §3 มี lane params ครบแล้ว
> เหลือแค่ verify ตอนคิวแน่นจริง

> 📦 **ย้ายเข้าคลัง 2026-07-24 (Opus-seat):** 52 order ที่ปิดด้วยสถานะ `REVIEWED*` แล้ว ถูกยกทั้งดุ้น (verbatim ไม่ตัด) ไปต่อท้าย
> `ARCHIVE_TASKBOARD_2026-07A.md` ตาม contract append-only (ORDER-103) — ค้นด้วยเลข order ในไฟล์นั้นได้ตามปกติ.
> **ที่ย้าย:** 153 · 154 · 155 · 159 · 156 · 157 · 168 · 180 · 173 · 169 · 166 · 171 · 172 · 174 · 184 · 170 · 163 · 164 · 158 · 160 · 150 · 146 · 148 · 142 · 140 · 124 · 125 · 126 · 127 · 135 · 138 · 129 · 132 · 131 · 130 · 137 · 098-E · 098-G · 098-J · 098-L · 098-M · 104 · 109 · 110 · 111 · 057 · 099 · 100 · 101 · 103 · 105 · 115
> **ที่ยังอยู่บอร์ดนี้** = order ที่ยัง OPEN/CLAIMED/WAITING-USER/CAMPAIGN + ใบที่สถานะเป็น `DONE`/`CLOSED` เปล่าซึ่งยัง
> ย้ายไม่ได้ (validator ต้องการ `## REVIEW ORDER-x` คู่กัน ไม่งั้นจุด `terminal-no-linked-review`) — ต้องทำ C1-CLOSURE ก่อน.
> 📦 **ย้ายเข้าคลังรอบ 2026-07-26 (Opus-seat):** 22 order สถานะ `REVIEWED*` ยกทั้งดุ้น (verbatim) ไปต่อท้ายไฟล์คลังเดิม — **ที่ย้าย:** 210 · 211 · 212 · 222 · 218 · 219 · 220 · 217 · 221 · 214 · 216 · 204 · 203 · 200 (x2) · 198 · 199 · 201 · 197 · LANEA-AB · LANEC-FAN · 136 · **ที่ไม่ย้าย:** 193(d) + 095/#4 (เลข order ซ้ำกับใบที่ยังค้างบอร์ดนี้ → ย้ายแล้วจะจุด `cross-active-and-archive`)
>
> 📦 **ย้ายเข้าคลังรอบ 2 · 2026-07-26 (ORDER-260 + ORDER-261):** อีก **51 ใบ**. ปลดล็อกได้เพราะ **ORDER-260** แก้บั๊ก
> `Get-StatusClass` ที่ตี `REVIEWED` เป็น NonTerminal เมื่อ verdict มีคำว่า "holdout"/"open" (17 ใบติดกับนี้) และ
> **ORDER-261** เขียน review ให้ 28 ใบที่ตรวจหลักฐานครบแล้ว (`_triage/EVIDENCE_SWEEP_TERMINAL_BLOCKS_2026-07-26.md`)
> พร้อมแก้ข้อความ 9 ใบที่ข้ออ้างเก่าถูกหลักฐานใหม่หักล้าง (073 · 143 · 188 · 193 · 187 · 072 · 036 · 112E · 189).
> **ที่ยังไม่ย้าย:** `095/#4` (แม่ CAMPAIGN ยัง OPEN — ย้ายแล้วจะจุด `cross-active-and-archive` · ต้องรอ campaign ปิด)

> 🔁 **RE-OPTIMIZE WAVE 210..213 (เขียน 2026-07-25, Opus-seat — user สั่ง "วางแผน optimize ใหม่")**
> <sub>⚠️ renumbered 205..208 → 210..213 ทันทีหลังเขียน: session คู่ขนานลง 205/206 (MacdDiv/PivotBreakout expand)
> ไว้ก่อนแล้ว — collision เดิมซ้ำรอย ORDER-201/202 เมื่อวาน. ไฟล์ ranges ยังชื่อ `order205_brkxau/` ตามเดิม
> (prefix = ตอนที่สร้าง ไม่ใช่เจ้าของใบ — เปลี่ยนแล้ว pointer ใน brief ที่ agent ถืออยู่จะพัง). **เลข 209 เว้นว่างไว้.**</sub>
> **หลักการเลือกว่าตัวไหนต้อง re-opt:** ไม่ใช่ "รันใหม่ให้หมด" แต่รันเฉพาะตัวที่ **หลักฐานที่ใช้เลือกพารามิเตอร์เสียจริง**.
> ตรวจแล้วมี 3 แหล่งที่ทำให้หลักฐานเสีย และแต่ละแหล่งกินตัวไหนบ้าง:
> - **(A) holdout leak** (ORDER-202): 87 optimize pass เลือกบนหน้าต่างที่กิน 2026H1 — แต่ deployed จริงโดน
>   **ตัวเดียว = `EA_BREAKOUT_XAU` 991001 (เงินจริง)** → **ORDER-210**. Boss_14 cohort ค่าพารามิเตอร์สะอาด
>   (มาจาก `_IS.ini` 2023.01–2025.06) เสียแค่ "ใบตัดสินว่าจะ ship" → ประกาศ 2026H1 ไหม้ พอ ไม่ต้อง re-opt.
>   Boss_16 สะอาด แต่ **บาร์ที่จะใช้ตัดสิน demo เขียนมาจากเลขที่เฟ้อ** → **ORDER-213** (แก้เลข ไม่ใช่ re-opt).
>   NRBreakout/ST03/ZSCORE/LNBREAK = verdict เป็น "ตก" อยู่แล้ว — contamination มีแต่ทำให้ดูดีขึ้น ไม่ต้องทำใหม่.
> - **(B) MRIS core classifier พัง** (ORDER-203, แก้แล้ว `265de0e3`): ทุกอย่างที่**กินสัญญาณ regime ย้อนหลัง**
>   ต้องวัดใหม่ — ตัวที่โดนจริงคือ **MacroGate 990120** ที่ attach อยู่ → **ORDER-211**.
> - **(C) genetic ที่ไม่มี fine-grid** (ORDER-204 กำลังรัน): ยังไม่รู้ว่ากินใครบ้าง — **ORDER-204 คือใบสำรวจ**,
>   ผลออกมาแล้วค่อยแตกใบ re-opt ต่อ (จะเป็น 209+). ห้ามเดารายชื่อล่วงหน้า.
> **ที่ไม่อยู่ในเวฟนี้และเหตุผล:** EA ที่ verdict = DEAD/ตก (contamination ทำให้ดูดีขึ้นเท่านั้น) · EA ที่ยังไม่ deploy
> และไม่มีใครอ้างเลขมันอยู่ (ไม่มีใครเสียหายถ้าเลขผิด — รอ ORDER-204 คัดมาก่อน) · Boss_14 cohort (ค่าสะอาด).

> 🧹 **TRANCHE 230-239 + 250-252 (เขียน 2026-07-26, Opus-seat · session `S-2026-07-26-TRIAGE`)** — **ไม่ใช่งานใหม่**
> ทุกใบในชุดนี้คืองานที่**มีอยู่แล้วแต่ไม่เคยมีที่อยู่บนบอร์ด**. ที่มา = กวาด `_triage/HANDOFF_*` 17 ใบ (100 รายการ)
> แล้วเจอ **27 รายการที่ไม่เคยเข้า `AGENT_TASKBOARD.md` เลย** + evidence sweep บน 36 order ที่ terminal-แต่ยังไม่ review
> เจอเพิ่มอีก 3. **6 ใบแรก (230-235) = แตะเงินจริงหรือบัญชีจริง** · 236-239 = หลักฐานพร้อมแต่ไม่เร่ง ·
> 250-252 = หนี้ระบบที่ evidence sweep จับได้ · **ที่เหลือ 16 รายการ → `MASTER_BACKLOG.md` §9 พร้อมช่อง "ปลุกเมื่อ"**
> (ไม่เปิดเป็น order เพราะยังไม่มีเงื่อนไขปลุก — เปิดไว้เฉยๆ = บอร์ดบวมโดยไม่มีใครทำ)
> วงจรชีวิตเต็ม + เหตุผล → `docs/WORK_LIFECYCLE.md` · เลนที่เปิดอยู่ → `docs/SESSION_LEDGER.md`

## ORDER-280 — [lever] rev04 re-entry บน BTC H4 — สวีป 3 anchor — `CLAIMED(Claude, 2026-07-26 20:30)` · ทำได้: Claude · 👉 แนะ: Claude
**bars (pre-register 2026-07-26 20:55 — เขียนก่อนรันครั้งแรก ห้ามแก้หลังเห็นผล):**
pass = **ดีขึ้นทั้ง MAIN และ BWD เทียบ baseline rev03/pyr1 ที่รันใหม่ใน "เลนเดียวกัน" AND MC PF-5th ไม่ลดลง** ·
<sub>⚠️ แก้ 20:15 ก่อนมีตัวเลขใดๆ: ฉบับแรกเขียนบาร์เป็นเลขสัมบูรณ์ (2.257 / 3.949 / PF-5th 1.052) ซึ่งเป็นเลข
ของเลน `Meta 5b` เท่านั้น — ถ้ารันเลนอื่นบาร์นั้นใช้ไม่ได้เลย (gotcha: BTC tick ต่างกันข้าม install).
บาร์ที่ถูกต้องคือ **สัมพัทธ์ในเลน**: ต้องรัน rev03 baseline ใหม่ในเลนที่ใช้จริงเสมอ แล้วเทียบกับตัวนั้น
⇒ เลิกผูกงานนี้กับ `Meta 5b` ข้อกำหนดจริงคือ "เลนว่าง 1 เลนที่มี tick BTC ตั้งแต่ 2020"</sub>
dead = แย่ลงหน้าต่างใดหน้าต่างหนึ่ง · กลาง = ดีขึ้นหน้าต่างเดียว **หรือ** PF ดีขึ้นแต่ PF-5th ลด ⇒ ไม่รับ lever
<sub>เงื่อนไข MC อยู่ในบาร์เพราะ ETH สอนมาแล้ว: PF หัวตาราง 1.310/1.099 ผ่านสวย แต่ PF-5th 0.857/0.657
= ขาดทุนเมื่อสุ่มลำดับไม้ใหม่. PF อย่างเดียวมองความบางไม่เห็น</sub>
**flat-lot probe:** N-A (lever นี้ไม่ escalate lot — ทุกไม้ flat `_04_LotSize`; ตัว escalate คือ `[07]` ซึ่ง probe ไปแล้วรอบ campaign)
**EA:** `(TRD)_SuperTrendFlip_rev04` (compile 0/0 · `ebece9d0`) · **เลน:** เลนไหนก็ได้ที่ว่าง **แต่ทั้ง baseline
และ arm ทดสอบต้องอยู่เลนเดียวกัน** · มีแค่ 2 เลนที่มี tick BTC ครบ 2020+: `D:\Meta 5` (80 tick files) และ
`D:\Meta 5b` (80) — **`Meta 5c` ใช้ไม่ได้** (tick 1 ไฟล์ · hcc เริ่ม 2021 ⇒ ทำ BWD 2020 ไม่ได้) ·
`Codex\mt5-boss-advance-run` และ `Monitor\MT5` ไม่มี BTCUSD เลย

**🔴 STEP -1 (วัดแล้ว 2026-07-26 20:10 — อ่านก่อนตัดสินใจว่าจะรัน STEP 1 ไหม):**
นับเหตุผลการออกจากรายงาน Model-4 ครึ่งปี 12 ใบของ pyr1 ที่มีอยู่แล้ว (ไม่ต้องรันอะไรใหม่):
**MAIN 50/50 = SL · BWD 62/66 = SL (อีก 4 = "end of test") ⇒ flip-close ไม่เคยเกิดเลยสักครั้งใน 6 ปี**
โครงสร้างบังคับให้เป็นแบบนั้น: SL วางไว้ที่เส้นพอดี ⇒ ราคาจะปิดเลยเส้นได้ต้องผ่านเส้นก่อน ⇒ SL ยิงก่อนเสมอ
⇒ กิ่ง `CloseAllOwn("flip")` เป็น dead code ในทางปฏิบัติ (เว้นแต่ gap)
**แปลว่า "exit by trailing the ST line" ที่ EA อ้างว่าเป็น edge ของมัน ยังไม่เคยถูกทดสอบจริง** —
ที่ถูกทดสอบคือ "ออกทันทีที่ไส้เทียนแตะเส้น" ซึ่งเกิดก่อนเสมอ
**STEP 0 (กรง — ห้ามข้าม):** parity. รัน `rev04` ด้วย `STF_BTC_H4_rev04_off.set` (ReMode=0) เทียบ `rev03` ด้วย
`STF_BTC_H4_pyr1.set` · MAIN 2023.01.01-2025.12.31 · Model 1 · **เทียบรายไม้ (จำนวน/เวลาเปิด-ปิด/ราคา) ไม่ใช่ PF**
— PF ตรงกันโดยบังเอิญได้ · assert หน้า Inputs ว่า `_08_ReMode=0` จริง (cache กินค่าที่ไม่ได้ระบุ)
**TREE:** ไม่ตรงรายไม้ → `BLOCKED` ทันที หยุดทุกอย่าง (แปลว่า refactor `SuperTrend()` ทำพฤติกรรมเปลี่ยน) ·
ตรง → STEP 1
**STEP 1:** สวีป 3 โหมดแยกกัน บน host pyr1 เดิม (Donchian-20 + pyramid MaxAdds=1) — `_08_MaxReEntries=1` ตรึงทุกโหมด:
· mode 1: `_08_PbAtrMult` {0.5, 1.0, 1.5, 2.0}
· mode 2: `_08_StoLevel` {20, 25, 30} × `_08_StoK` {9, 14}
· mode 3: `_08_SrBars` {10, 20, 40} × `_08_SrAtrMult` {0.3, 0.5, 1.0}
**STEP 2 (บังคับ ก่อนสรุปว่าโหมดไหนชนะ):** **control run `_01_UseDonchian=false`** ของโหมดที่ดีที่สุด.
เหตุผล: re-entry ข้าม Donchian โดยตั้งใจ ⇒ ตอน `UseDonchian=true` ทางเข้า re-entry มีตัวกรอง**น้อยกว่า**
ทางเข้า flip ⇒ สวีปทำกำไรได้จากการหลบตัวกรอง ไม่ใช่จากกลไก pullback. ถ้า control บอกว่ากำไรมาจากการหลบ
⇒ lever ตก ไม่ว่าเลขหน้าตาดีแค่ไหน
**STEP 3:** ตัวชนะ → Model-4 both-window (ซอยครึ่งปี — 3 ปีชน memory ceiling) → หัก swap ด้วย
`scripts/swap_adjust_crypto.py --rate-long 14.67 --rate-short 0.49` → `monte_carlo.py` → เทียบบาร์
**ห้าม:** แตะ 2026H1 (ไหม้ไปแล้วสำหรับ EA ตัวนี้) · เทียบเลขข้ามเลน MT5 · ใช้ผล Model-1 เป็นหลักฐานตัดสิน ·
รับ lever โดยไม่มี control run STEP 2 · แก้บาร์ด้านบนหลังเห็นผล

## ORDER-270 — [tooling/integrity] กรงของ validator ใช้งานไม่ได้จริง — negative suite ช้าจนไม่มีใครรัน — `DONE(Claude/Opus 2026-07-27, `3a2cee7e`) — 254s → 7.6s · **ไม่ได้ใช้ path-filter** ที่ใบสั่งเสนอ (จะเปิดรู BLOCKER 6) · กรงเร็ว 11/11 · ชุด 103 เต็ม 41/41 + REVIEWED(Claude/Opus 2026-07-27)`
### ผล ORDER-270 STEP 3
**ไม่ทำตามทางแก้ที่ใบสั่งเขียนไว้** — path-filter เปลี่ยน **"commit ไหนถูกเดินผ่าน"** และ BLOCKER 6 อยู่ในคอมมิตที่
history simplification อาจตัดทิ้งพอดี · แทนที่ด้วยวิธีที่เดินครบทุก commit เหมือนเดิม แต่เลิกอ่าน byte ที่พิสูจน์ได้แล้วว่าไม่เปลี่ยน:
- `git cat-file --batch-check` **ครั้งเดียว** map ทุก commit → blob OID ของ archive · **OID = content address ⇒ OID เท่ากันคือ byte เท่ากัน**
  ตรงไหน OID ไม่ขยับ ข้ามการอ่าน blob ทั้งสองฝั่ง · ตรงไหนขยับ ตรวจ prefix/H2 แบบเดิมทุกประการ
- `git rev-list --first-parent --parents` **ครั้งเดียว** แทน parent lookup ต่อ commit ⇒ กฎ merge แข็งเท่าเดิม
- drain stdout ก่อนเขียน stdin ไม่งั้นสายยาวๆ deadlock ที่ pipe buffer เต็ม
**กรงมาก่อนตามข้อห้ามของใบสั่งเอง:** `scripts/_test/run_chainwalk_tests.ps1` 11 เคส วินาทีไม่ใช่นาที ·
**พิสูจน์ว่า fail ได้ก่อนแก้โค้ด**: perf case แดงที่ 18.39s บน budget 3s → หลังแก้ 0.35s ·
คุม laundering **2 รูป**: merge ที่ resolve เป็นของที่ไม่ตรง parent ไหนเลย และ merge ที่เอา archive ของ parent ที่สองมาทั้งดุ้น (รูปหลังคือรูปที่ path-filter มีโอกาสกลืนที่สุด)
**ซ่อมกรงเดิมด้วย:** ชุด 103 fail อยู่ 3 เคสด้วยเรื่องที่ไม่เกี่ยวกับสิ่งที่มันทดสอบ — hook เพิ่ม callee 2 ตัวเมื่อ 2026-07-26
(`check_order_collision`, `check_handoff_contract`) แต่ fixture ยัง hardcode รายชื่อเก่า ⇒ ตายที่ "argument to -File does not exist"
· ตอนนี้ fixture **อ่านรายชื่อจาก hook เอง** ⇒ guard ตัวถัดไปที่เพิ่มเข้ามาทำให้มันเน่าอีกไม่ได้
**ยืนยัน:** chainwalk 11/11 · ชุด 103 **41/41** · `-Audit` บน repo จริงผลไม่เปลี่ยนสักหลัก (unresolved 0 · integrity 0 · exit 0) ที่ 7.6 วินาที
**bars:** N-A · **flat-lot probe:** N-A
**⚠️ แก้การวินิจฉัยเดิม (2026-07-26, ผมเขียนผิดเอง):** ใบนี้เคยเขียนว่า "ค้างทั้งคู่ ไม่ใช่แค่ช้า" โดยอ้าง
"CPU < 1 วินาที หลัง 25+ นาที" — **นั่นคือ CPU ของ process แม่ ซึ่งมันแค่นั่งรอลูก** วัดใหม่ด้วยการ
ไล่ดู child process จริง: **ลูกกิน CPU 42→66 วินาทีและเดินหน้าอยู่** (case แรก `clean` รัน `-Generate` จบ
แล้วขึ้น `-Audit`) ⇒ **มันไม่ deadlock มันช้าจริง** · memory `C1_ENFORCE_HANDOFF` เขียนเตือนไว้ตรงตัวว่า
"เช็ค CPU ของ child process ก่อน" และผมข้ามคำเตือนนั้นไปเช็คตัวแม่
**ตัวเลขที่วัดได้จริง:** ~1 CPU-นาที ต่อการเรียก validator 1 ครั้ง · suite มี ~15 case × 2-3 mode
⇒ ประมาณ **30-45 นาที** ต่อชุด (memory เก่าบอก 8-9 นาที ⇒ **ช้าลง ~4 เท่า**)
**สาเหตุที่น่าสงสัยที่สุด:** ทุก child invocation ส่ง `-RepoRoot D:\EA_LAB` แล้ว validator เดิน git first-parent
chain ของ repo จริงทุกครั้ง — ต้นทุนโตตามจำนวน commit และวันนี้ repo เพิ่มไปหลายสิบ commit
(fixtures เล็ก ไม่ใช่ต้นเหตุ) · **ยังไม่ยืนยัน** ต้องวัดเทียบก่อน
**ทำไมยังเป็นปัญหาแม้ไม่ใช่การค้าง:** ผลลัพธ์ทางปฏิบัติเหมือนกัน — กรงที่ใช้เวลา 30-45 นาทีคือกรงที่
ไม่มีใครรัน และ**ไม่มีใครรู้ว่ามันเคยผ่านครั้งสุดท้ายเมื่อไร** ระบบ tamper-integrity ของ ORDER-102/103
จึงยืนอยู่บนกรงที่ de-facto ไม่ทำงาน
**✅ STEP 1-2 ปิดแล้ว 2026-07-26 — root cause เจอแล้ว (วัดครบ):**
| วัดอะไร | ผล |
|---|---|
| `-Audit` บน repo จริง 1 ครั้ง | **254 / 278 วินาที** (วัด 2 รอบ) |
| child ของ suite 1 ครั้ง (fixture **364 ไบต์**) | **~60 วินาที** ⇒ ไม่ใช่ขนาดไฟล์ เป็น **fixed cost** |
| `git rev-list --first-parent` ทั้งสาย | **42 ms** ⇒ **ไม่ใช่ต้นเหตุ** (สมมติฐานแรกของผมผิด) |
| regex cache thrash (สมมติฐานที่ 2) | precompute แล้ว **254→278 วินาที = ไม่ต่าง** ⇒ **ไม่ใช่ต้นเหตุ** และเคลียร์ว่า ORDER-260 ไม่ได้ทำให้ช้า |
| **สาย checkpoint→HEAD** | **502 commit** |
| **ในนั้นที่แตะ archive จริง** | **5 commit** |

**🎯 ต้นเหตุ:** `Invoke-ArchiveChainIntegrityCheck` วน `for ($i=1; $i -lt $chain.Count; $i++)` ทุก commit ในสาย
และ**ต่อ 1 commit ยิง git subprocess 3 ครั้ง** (`Get-GitBlobBytes` prev · `Get-GitBlobBytes` cur ·
`Get-GitCommitParents`) พร้อมอ่าน blob archive เต็มไฟล์ 2 รอบ
⇒ **502 × 3 ≈ 1,506 git spawn ต่อการเรียก 1 ครั้ง** ซึ่ง **~1,491 ครั้งเป็นงานเปล่า** (archive ไม่เปลี่ยน)
× ~40ms/spawn บน Windows = **~60 วินาที** ตรงกับ fixed cost ที่วัดได้เป๊ะ
**และมันโตขึ้น 3 spawn ต่อทุก commit ใหม่** ⇒ อธิบายได้ว่าทำไม 8-9 นาที (memory เก่า) กลายเป็น 30-45 นาที

**STEP 3 — ทางแก้ที่ถูก + ⚠️ กับดักที่ห้ามพลาด:**
- แก้ที่ถูกที่สุด: จำกัดการวนเฉพาะ commit ที่แตะ path archive (`git rev-list --first-parent <ckpt>..HEAD -- <archive>`)
  เพราะ commit ที่ไม่อยู่ใน path-filter **พิสูจน์ได้ว่า blob ไม่เปลี่ยน** → semantically ถูก ไม่ใช่การมองข้าม
- ของแถมฟรี: `$prevBytes` ของรอบถัดไป = `$curBytes` ของรอบนี้ → cache ไว้ ลดการอ่าน blob ครึ่งหนึ่ง
- batch parent lookup: `git rev-list --parents <ckpt>..HEAD` ครั้งเดียว แทนยิงต่อ commit
- 🔴 **กับดัก:** `--first-parent` + path-filter **อาจซ่อน merge ที่เปลี่ยน archive ผ่าน parent ที่สอง** ซึ่งคือ
  **BLOCKER 6 "checkpoint laundering ผ่าน merge"** ที่ ORDER-103 REWORK3 เสียเวลาปิดไปแล้ว
  ⇒ ต้องเก็บการตรวจ merge-parent ไว้ครบ ห้ามให้ optimization เปิดรูเดิมกลับมา
**ห้าม:** แก้ walk นี้โดยไม่มีกรงเร็วที่ครอบ merge-laundering ก่อน (วงจรอุบาทว์: จะแก้ validator ให้ปลอดภัยต้องมี suite ·
         suite ช้าเพราะบั๊กนี้ · ทางออก = เขียน targeted test ของ chain-walk ก่อน แล้วค่อยแก้)
**STEP 3:** ถ้าลดไม่ได้จริง → แยกเป็น 2 ชั้น: smoke เร็ว (<1 นาที) ที่รันได้ทุก commit + full suite ที่รันตามรอบ
          โดย**บันทึกวันที่รันครั้งสุดท้าย**ไว้ในไฟล์ ไม่ใช่ปล่อยให้ไม่มีใครรู้
<sub>กรงแคบที่ใช้ได้จริงมีตัวอย่างแล้ว: `scripts/_test/run_statusclass_tests.ps1` (19 เคสจาก corpus จริง · เสร็จในไม่กี่วินาที ·
พิสูจน์แล้วว่า fail ได้เมื่อ revert ของที่มันคุม) — ไม่ได้แทนของเดิม แต่แสดงว่ารูปแบบนี้เป็นไปได้</sub>
**ห้าม:** สรุปว่า process ค้างจาก CPU ของตัวแม่ (บทเรียนของใบนี้เอง) · ปล่อยให้ suite อยู่ในสถานะ
         "มีอยู่แต่ไม่มีใครรู้ว่ารันผ่านเมื่อไร" ต่อ

## ORDER-230 — [🔴 เงินจริง · integrity] บัญชี 463666728: currency เป็น cent หรือ USD — `OPEN` · ทำได้: user (อ่าน terminal) + Claude (แก้แถว) · 👉 แนะ: user
**bars:** N-A (ops) · **flat-lot probe:** N-A
**ปัญหา:** `portfolio/ACCOUNTS.csv` แถว 463666728 เขียน `USD` + `base_equity=100000` แต่ user อธิบายบัญชีนี้เป็น **cent**
คำเตือนถูกเขียนฝังอยู่ในช่อง note ของแถวนั้นเองตั้งแต่ 2026-07-25 ("confirm USC vs USD before any figure that converts
to money rather than %") แล้ว **ไม่มีใครเป็นเจ้าของ** — handoff ทิ้งไว้ ไม่เคยมีใบสั่งงาน
**ทำไมเร่ง:** บัญชีนี้ถือ EA คิวตัดสิน ต.ค. ~13 ตัว · ทุกเลข DD/risk ที่แปลงเป็นเงิน (ไม่ใช่ %) ตั้งอยู่บนช่องนี้ ·
`base_equity` เพิ่งขยับ 10000→100000 เมื่อ 07-25 ซึ่งทำให้ DD-as-% ตกลง ~10 เท่า = งบ 25% เลิก binding ที่บัญชีนี้พอดี
**STEP 1:** user เปิด terminal 463666728 อ่าน currency จริง (USD/USC) + balance จริง
**STEP 2:** Claude แก้ `portfolio/ACCOUNTS.csv` แล้วรัน `python scripts/portfolio_risk_admission.py` ใหม่ทั้งบัญชี
**ห้าม:** เดาค่าเอง · แก้ช่อง currency โดยไม่มี user ยืนยัน (แถวนี้ถูกเว้นไว้โดยตั้งใจมาแล้วครั้งหนึ่ง)

## ORDER-231 — [demo · funnel gap] 992001 TsMom_XAU: ACTIVE อยู่แต่ไม่เคยมี Monte Carlo — `DONE(Claude/Opus 2026-07-27) — MC รันแล้ว ruin 0.00% · PF-5th 2.75 · dd95=3.39 เข้า expectations.csv (STEP 2A) · แต่ของจริงที่ได้คือ corr ไม่ใช่ MC (ดูผลด้านล่าง) + REVIEWED(Claude/Opus 2026-07-27)`
**bars:** MC ruin ≤ 2% (resize-first ถึง 10%) · PF-5th ≥ 1.0 · **flat-lot probe:** N-A (single-order trend EA)
**ปัญหา:** `portfolio/expectations.csv` แถว 992001 = `pf=UNKNOWN`, `dd95=UNKNOWN`, `RANGE_NOT_SEPARABLE`
EA นี้ **ACTIVE จริงบน 415573666 judge 2026-10-23** แต่ไม่เคยรัน MC / holdout / sensitivity fan
(attach แบบ demo-isolate ตาม user directive ไม่ใช่ funnel ที่เดินครบ) ⇒ portfolio risk ของบัญชีนั้น **ตัดตัวนี้ทิ้งทั้งตัว**
**STEP 1:** รัน MC บน .set ที่ล็อกไว้ `_vps_deploy/S2_TSMOM_XAU/` (lb60/deadmult2) หน้าต่าง MAIN 2023.01-2025.12
**TREE:** ruin ≤2% AND PF-5th ≥1.0 → STEP 2A เติม dd95 ลง `expectations.csv` แล้วรัน risk admission ใหม่ ·
          ruin 2-10% → STEP 2B คำนวณ lot ที่ทำให้ ruin ≤2% แล้ว**เสนอ** resize (ห้ามแก้ live เอง) ·
          ruin >10% → STOP + `BLOCKED(992001 ruin เกินเพดานแม้ resize — ถอด หรือคงจนถึง judge?)`
**ห้าม:** verdict · แตะ .set ที่ demo อยู่ · **เดา dd95** (ค่า UNKNOWN ตอนนี้ถูกต้องแล้ว ห้ามเติมเลขที่ไม่มี run รองรับ)

### ผล ORDER-231 (Claude/Opus 2026-07-27 · `7cd82d9a` + `2e18a7e3`)
รัน MAIN ใหม่จาก **binary+set ที่ deploy จริง** (`_vps_deploy/S2_TSMOM_XAU/TsMom_XAU.ex5` + `S2_TsMom_XAU_deploy.set`,
`_05_Magic=992001` ยืนยันใน .set) · XAUUSD D1 · 2023.01.01-2025.12.31 · lane `D:\Meta 5b` · Model 1 ·
report `TSMOM_XAU_D1_MAIN_MC.htm` · leverage assert 1:100 ผ่าน · quality 98%

| | PF | trades | net | eqDD |
|---|---|---|---|---|
| MAIN re-run | **2.75** | 26 | 1044.12 | 2.9% |

**MC (5000 iter, order-resampling, deposit 10k):** maxDD 5th 1.35 / median 2.08 / **95th 3.39** / worst 4.96 ·
**ruin 0.00%** · P(net<0) 0.0% ⇒ ผ่านบาร์ทั้งสอง → STEP 2A: `dd95_expected=3.39`, `dd95_basis=MC95`

**🔴 3 ข้อที่สำคัญกว่าตัวเลข MC:**
1. **PF-5th = PF จุด (2.75) เป๊ะ** เพราะ order-resampling รักษา multiset ของไม้ไว้ ⇒ net และ PF **invariant**
   ⇒ บาร์ `PF-5th ≥ 1.0` **ตกไม่ได้เลยกับ MC ชนิดนี้ = ไม่ใช่หลักฐาน** มีแต่คอลัมน์ DD ที่มีข้อมูล
   (เข้าเกณฑ์เดียวกับกฎ guard-evidence: เลขที่ขยับไม่ได้ ไม่ใช่หลักฐานว่าปลอดภัย)
2. **n=26 ใน 36 เดือน** — dd95 จาก 26 ตัวอย่างคือการเดาที่กว้างมาก แค่มีทศนิยมติดมา
3. **MAIN re-run ได้ PF 2.75 ไม่ใช่ 3.72 ที่ทะเบียนเขียน** — จำนวนไม้เท่ากันเป๊ะ (26) ⇒ สัญญาณเดียวกัน fill ต่างกัน
   (คนละ lane/model กับตัวที่ผลิต 3.72) · **บันทึกไว้ ยังไม่ reconcile**

**ของจริงที่ได้จากใบนี้ = correlation ไม่ใช่ MC:**
992001 ไม่เคยอยู่ใน `portfolio/backtest_corr_reports.csv` ⇒ ทุกคู่ตกไปที่ default `corr=1.0` (fallback ที่ถูกต้อง แต่แพง)
· เติม map แล้ววัดใหม่ → coverage 422→**452**/1540 คู่

| บัญชี 415573666 | portfolio_DD_est | headroom vs 25% |
|---|---|---|
| ก่อน (13/14 magics, partial) | 33.19% | −8.19 |
| เติม dd95 อย่างเดียว (14/14, corr=1.0 default) | 40.10% | −15.10 |
| **เติม corr ด้วย (14/14, วัดจริง)** | **33.91%** | **−8.91** |

⇒ **DD ของตัวมันเองมีราคา 0.72 จุด · การไม่เคยวัด corr มีราคา 6.19 จุด** (กระทบยอดด้วยมือ: 33.19² + 2·3.39·73.02 + 3.39² = 40.10² พอดี)
· ยังเหลือ **1088 คู่ทั้งพอร์ตที่อยู่บน default 1.0** = ประเมินความเสี่ยงสูงเกินจริงอย่างเป็นระบบตรงที่ไม่มีข้อมูล
· บัญชียัง **OVER budget** ทั้งสองทาง — ใบนี้ไม่ได้เสนอ resize แค่เอา distortion ออกจากเลขที่จะใช้ตัดสิน
**ไม่ได้ทำ:** แตะ .set ที่ demo · เสนอ resize · เดา dd95

## ORDER-232 — [🔴 เงินจริง · disposition] MacroGate 990120: เก็บ / ย้าย AUDJPY / ถอด — `OPEN` · ทำได้: user ตัดสิน + Claude เสนอ · 👉 แนะ: user
**bars:** N-A (decision) · **flat-lot probe:** N-A
**ปัญหา:** ORDER-211 ถอดสถานะ VALIDATED → ADVISORY-ONLY แล้ว แต่ **990120 ยัง ACTIVE บน USDJPYm judge 2026-10-16**
และมี **คำแนะนำที่ขัดกันเอง 2 ฉบับ** ค้างอยู่:
- handoff 2026-07-25C → "ย้ายไป AUDJPY" (ที่ DD-timing จริง)
- bundle sweep 2026-07-26 (`85b55fd9`) → **หักล้างข้อบน**: host ขาดทุนทั้งเปิดและปิด gate ทั้งสอง symbol ⇒ ไม่มี symbol ไหน
  แยก "gate จับจังหวะถูก" ออกจาก "เทรดน้อยลง" ได้ → เก็บเป็น sensor เฉยๆ
**คำแนะนำของผม = ฉบับหลัง** (คงเป็น plumbing sensor · ห้ามนับเป็น edge · ห้าม size ตาม PF)
**STEP 1:** user เคาะ 1 ใน 3 — (a) คงเป็น sensor advisory (b) ย้าย AUDJPY (c) ถอด
**ห้าม:** ตัดสินแทน user · อ้างคำแนะนำฉบับแรกโดยไม่บอกว่ามันถูกหักล้างแล้ว

## ORDER-233 — [🔴 เงินจริง · audit] `--resolve-single-leg-baskets`: flag ที่พลิกงบพอร์ต 73% → 38% — `OPEN` · ทำได้: Codex (audit) → user (ratify) · 👉 แนะ: Codex
**bars:** N-A (audit) · **flat-lot probe:** N-A
**ปัญหา:** fix สร้างเสร็จแล้ว **DEFAULT OFF** · เปิดแล้วบัญชี 463666728 ขยับ **73.04% → 38.36%** เทียบงบ 25%
คำถามจริงไม่ใช่ code diff แต่คือ **เอา DD95 ระดับ basket ไปจับคู่กับ correlation series ของ leg เดียว ชอบธรรมไหม**
**ทำไมมันหลุด:** จอดอยู่ใน `_triage/CODEX_REVIEW_QUEUE_2026-07-25.md` ซึ่ง**ไม่ใช่บอร์ด** — อีก 2 รายการในคิวนั้น
บังเอิญมี order รองรับ (187, 200) ใบนี้ไม่มี ⇒ คนที่อ่าน `AGENT_TASKBOARD.md` อย่างเดียวมองไม่เห็นเลย
**STEP 1:** Codex blind audit คำถามข้างบน (**ห้ามให้ดูคำตอบ Opus ก่อน** — กัน anchoring)
**STEP 2:** user ratify ก่อนเปลี่ยน default · gate เดียวกับ ORDER-200 Phase D
**ห้าม:** เปลี่ยน default เอง · อ้างเลข 38.36% เป็นเลขจริงก่อน audit ผ่าน

## ORDER-234 — [🔴 เงินจริง · migration] PERSIST_MIGRATION checklist: ลอยข้าม handoff 3 ใบโดยไม่มีเจ้าของ — `OPEN` · ทำได้: user (เดิน checklist) + Claude (verify journal) · 👉 แนะ: user
**bars:** N-A (ops) · **flat-lot probe:** N-A
**ปัญหา:** ORDER-132 + ORDER-138 ปิดแล้วทั้งคู่ — แต่ปิดที่ **code** ส่วน **ฝั่ง user ยังไม่เคยเดิน** และไม่มีแถวไหนเป็นเจ้าของ
โผล่ใน handoff 07-19 · 07-20 · 07-24D เหมือนเดิมทุกครั้ง = สัญญาณคลาสสิกว่ามันกำลังจะหายไปเงียบๆ
**checklist:** `ea_template/PERSIST_MIGRATION_ORDER132.md` — F3 snapshot GV → demo attach → เช็ค journal หา
`[PERSIST] migrated` → restart 1 ครั้งยืนยัน state → **แล้วค่อย** ปล่อย Boss_14 GBPJPY ขึ้นเงินจริง
**ข้อที่ ORDER-138 เพิ่ม:** บัญชีที่มี legacy state ต้องตั้ง `RC_AdoptLegacyHalt=true` **แค่ attach เดียว** แล้วกลับเป็น false
(ไม่งั้น OnInit fail by design)
**ห้าม:** ขึ้นเงินจริงก่อนเดิน checklist ครบ · ปล่อย `RC_AdoptLegacyHalt=true` ค้างไว้

## ORDER-235 — [policy] บาร์ 30 ไม้ใช้กับ 4 EA นี้ไม่ได้ — ต้องเคาะ ไม่ใช่เลื่อนไปเรื่อยๆ — `OPEN` · ทำได้: user (ratify) + Claude (เขียนลง gate) · 👉 แนะ: user
**bars:** N-A (ใบนี้แก้บาร์เอง) · **flat-lot probe:** N-A
**ปัญหา:** 991001 / 991004 / 990205 / 990303 ต้องรอถึง **2028-2029** กว่าจะครบ 30 ไม้ปิด
อีก 9 แถวถูกเลื่อน judge date ไปแล้ว แต่ 4 ตัวนี้จงใจไม่เลื่อน เพราะที่พังคือ **บาร์** ไม่ใช่ **วันที่** · 3 ทางเลือกเขียนไว้แล้วใน
`DEMO_DEPLOYMENT_PLAN.md`
**ทำไมต้องเป็น order:** มันแก้ตัวเลขใน VERDICT GATE ⇒ ต้อง ratify ชัดแบบ precedent `rate_flag=ON_RATE` ของ ORDER-198
**ห้าม drift เงียบ**
**ห้าม:** เปลี่ยนบาร์เองโดยไม่มี user เคาะ · ปล่อย 4 ตัวนี้ค้างไร้เกณฑ์ตัดสินต่อไป

## ORDER-236 — [lever/build-on] lever 2 ตัวที่ build เสร็จ + cage ผ่านแล้ว แต่เซลล์ไม่เคยรันสักเซลล์ — `OPEN — STEP 1 (design, Claude) ปิดแล้ว 2026-07-27: host = RSI-MR GridLog EURUSD H1 @ RSIMR_CENTER.set · บาร์เดิมถูกถอนเพราะวัด host ไม่ได้วัด lever · B14_AB_on.set ครอบแค่ lever เดียวและผิด chassis · STEP 2 = 4 cell พร้อมรัน` · ทำได้: **oc-qwen/ZCode (รัน STEP 2)** · 👉 แนะ: oc-qwen
**bars:** ~~pass = MAIN ≥1.2 AND BWD ≥1.0 · dead = ทั้งคู่ <1.0 · กลาง = ผ่านอย่างใดอย่างหนึ่ง~~ **← ถอนแล้ว 2026-07-27: บาร์นี้วัด host ไม่ได้วัด lever (ดู STEP 1 ด้านล่าง) · บาร์ที่ใช้จริง = delta vs control ในเลนเดียวกัน** · **flat-lot probe:** N-A (lever ไม่ใช่ MM escalation)
**ของที่มีอยู่แล้ว:** `_9_RegimeGateAdds` + `CONF_PA_ENGULF` — build เสร็จ (`1aeafc06`, `f65bf2ce`) · cage ผ่าน · byte-identical เมื่อปิด ·
Model-4 A/B บน AUDNZD ได้ **DD 12.3%→5.4%, net −286→+98** · **มี `ea_template/sets/B14_AB_on.set` รออยู่แล้ว**
**ปัญหา:** ที่เดียวที่เคย matrix มันคือ ORDER-LANEA-AB บน Boss_18 JumStoch ซึ่ง **หยุดที่ base gate**
(`DEAD-OPTIMIZED port-level`, base 0.58-0.71) ⇒ **เซลล์ lever ไม่เคยรันเลย** และ Boss_18 ก็ไม่ใช่ CORE ที่ validated ด้วยซ้ำ
หลังจากนั้นไม่มีใบไหนเล็ง lever คู่นี้ไปที่ CORE จริงอีก
**ทำไมน่าทำ:** นี่คือรายการที่ **หลักฐานพร้อมที่สุด** ในกอง untracked ทั้ง 27 — ของสร้างเสร็จ cage ผ่าน .set มีแล้ว เหลือแค่เล็งให้ถูกตัว
**STEP 1:** เลือก host ที่ BWD >1.0 สบายๆ (ตาม memory `escalation-overlay-needs-strong-bwd-host`) — เสนอ Boss_14 GBPJPY leg-8 หรือ RSI-MR 990103
**ห้าม:** ใช้ host ที่ BWD ปริ่ม 1.0 (Wave1 พิสูจน์แล้วว่าแพ้) · Model-2

### STEP 1 ปิดแล้ว — design (Claude/Opus 2026-07-27) · **ส่วนของ Claude จบ · ส่วนที่เหลือ = runner**
**host ที่เลือก = `(Boss)_RSI_MR_GridLog_rev01` EURUSD H1 @ `_mt5_auto/ab_sets/rsimr_fan/RSIMR_CENTER.set`** (RSI25/75+SL25+Dist9)
ไม่ใช่ Boss_14 GBPJPY leg-8 ตามที่ใบสั่งเดาไว้ · เหตุผล 3 ข้อ:
1. **BWD 1.56 (MAIN 1.96)** = เกิน 1.0 แบบสบายจริง ไม่ใช่ปริ่ม — ตรงเงื่อนไข memory `escalation-overlay-needs-strong-bwd-host`
2. **มันเป็น grid** — `_9_RegimeGateAdds` gate ที่ตัว **adds ของ grid** ⇒ host ที่ไม่ใช่ grid ไม่มีอะไรให้ gate เลย
   (memory `regime-gate-grids-not-breakouts`) ⇒ **ตัด PivotBreakout ออกทั้งที่ BWD 1.22 สวย** เพราะผิดคลาส ไม่ใช่เพราะเลขไม่ดี
3. plateau แข็งที่สุดเท่าที่วัดมา: sensitivity fan **8/8 variant ยัง PF>1 ทั้งสองหน้าต่าง** (ORDER-185) ⇒ ถ้า lever ขยับผล จะอ่านออกว่าเป็น lever ไม่ใช่ noise

**🔴 2 อย่างที่ใบสั่งนี้เขียนไว้ผิด และต้องแก้ก่อนใครจะรัน:**
1. **บาร์ปัจจุบัน (`pass = MAIN ≥1.2 AND BWD ≥1.0`) วัด host ไม่ได้วัด lever** — host ตัวนี้ผ่านบาร์นั้นอยู่แล้วตั้งแต่ยังไม่ใส่ lever
   (1.96/1.56) ⇒ ต่อให้ lever ทำให้แย่ลง มันก็ยัง "ผ่าน" ⇒ **การทดสอบที่แยกไม่ออกว่าดีขึ้นหรือแย่ลง = ไม่ควรรัน**
   (memory `discriminating-test-must-be-able-to-discriminate`)
   **บาร์ใหม่ (pre-register ก่อนมีตัวเลขใดๆ 2026-07-27):** วัด **delta เทียบ control run ของ host เดียวกันที่ปิด lever ในเลนเดียวกัน**
   · pass = **ดีขึ้นทั้ง MAIN และ BWD** AND MC PF-5th ไม่ลด · dead = แย่ลงหน้าต่างใดหน้าต่างหนึ่ง · กลาง = ดีขึ้นหน้าต่างเดียว ⇒ ไม่รับ lever
   (รูปแบบเดียวกับที่ ORDER-280 ต้องแก้บาร์ตัวเองเพราะเลขสัมบูรณ์ผูกกับเลน)
2. **`ea_template/sets/B14_AB_on.set` ครอบแค่ lever เดียว** — grep แล้วมี `_9_RegimeGateAdds=true` แต่ **ไม่มี `CONF_PA_ENGULF` เลย**
   และมันเป็น set ของ chassis **Boss_14** ไม่ใช่ของ host ที่เลือก ⇒ ข้อความ "ของพร้อมแล้ว เหลือแค่เล็งให้ถูกตัว" **มองโลกในแง่ดีเกินจริง**
   ต้องสร้าง 3 ไฟล์ใหม่จาก `RSIMR_CENTER.set` เอง เปลี่ยนค่าเดียวต่อไฟล์

**STEP 2 (runner) — 4 cell บนเลนเดียวกันทั้งหมด · Model 1 · EURUSD H1 · MAIN 2023.01.01-2025.12.31 + BWD 2020.01.01-2022.12.31:**
| cell | set | เปลี่ยนจาก CENTER |
|---|---|---|
| **control** | `RSIMR_CENTER.set` (ตามเดิม) | — (บังคับ รันใหม่ในเลนเดียวกัน ห้ามอ้างเลขเก่า) |
| A | `rsimr_lever/A_regimegate.set` | `_9_RegimeGateAdds=true` |
| B | `rsimr_lever/B_paengulf.set` | `CONF_PA_ENGULF` เปิด |
| AB | `rsimr_lever/AB_both.set` | เปิดทั้งคู่ |
**ห้ามเพิ่ม:** อ้างเลข MAIN/BWD เก่าเป็น control (คนละ run คนละเลน) · stack 2 lever ก่อนรู้ผลเดี่ยว · ข้าม control
**หมายเหตุที่ runner ต้องรู้:** holdout 2026H1 ของ host นี้ **ล้มไปแล้วจริง (0.76/n=21) และพิสูจน์แล้วว่าไม่ใช่ artifact ของ config**
⇒ lever ที่ชนะจะ**ไม่**ปลดล็อก CANDIDATE ให้ · ประโยชน์ที่หวังได้จริงคือ "ทำให้ host ที่ยังไงก็ BUILD-ON ดีขึ้น" เท่านั้น — อย่าคาดหวังเกินนั้น

## ORDER-238 — [tooling/integrity] `2026.06.01` ค้างใน 5 สคริปต์ที่ guard มองไม่เห็น — `DONE(Claude/Opus 2026-07-27, `805a443a`) — ของจริง 16 ไฟล์ไม่ใช่ 5 · แบนเนอร์ 12 · guard §9 ขยาย 3 · qwen_batch_runner ปฏิเสธการรัน + REVIEWED(Claude/Opus 2026-07-27)`
**ผล:** ใบสั่งนับไว้ 5 — grep เจอ **16**: 8 ตัวรันหน้าต่างนั้นจริง · 2 ตัวสอนมันผ่าน usage example · **3 ตัวเป็น reusable definition**
· 🔴 ตัวที่แรงที่สุดไม่ได้อยู่ในรายชื่อเดิม: **`run_backtest.ps1` มี `-ToDate = "2026.05.29"` เป็นค่า default** ⇒ เรียกเปล่าๆ ก็กิน holdout 5 เดือนเงียบๆ
· `mt4_run.ps1`/`mt4_optimize.ps1` = ฝาแฝด MT4 ของ 2 ไฟล์ที่อยู่ใน §9 อยู่แล้ว ไม่มีอะไรทำให้มันต่างกัน แค่ตกสำรวจ
**ทำ:** (a) แบนเนอร์ `HOLDOUT-BURNED` 12 ไฟล์ (หน้าต่างเดิม**ไม่แก้** — มันคือประวัติของ run ที่เกิดไปแล้ว)
· (b) `qwen_batch_runner.ps1` **ปฏิเสธการรัน exit 3** เว้นแต่ส่ง `-SpendHoldout2026H1` — **แรงกว่าที่ใบสั่งขอ (warn)** โดยตั้งใจ:
มันคือ batch driver ที่ agent lane หยิบไปรันไม่มีคนดู และ lane ที่ไม่มีคนดู**ไม่อ่าน warning**
· (c) `check_state.ps1` §9 ขยาย scope 3 ไฟล์ + แก้ default/example ที่มันจับได้
**พิสูจน์ว่ากรง fail ได้:** ทุบ default ของ `run_backtest.ps1` เป็น 2026.03.01 → §9 แดงทันที แล้วคืนค่า → เขียว
**bars:** N-A · **flat-lot probe:** N-A
**ปัญหา:** `gsmc_validate.ps1` · `order104*.ps1` · `qwen_batch_runner.ps1` · `mt5_batch_shortlist.ps1` · `optimize_loop.ps1`
ยังถือวันจบที่กิน holdout 2026H1 · `check_state.ps1` §9 จงใจ scope แคบ (เฉพาะ reusable definition:
`.claude/agents/*.md`, `mt5_run.ps1`, `mt5_optimize.ps1`) ⇒ 5 ตัวนี้อยู่นอกกรง
**ตัวที่น่ากลัวสุด = `qwen_batch_runner.ps1`** เพราะเป็น batch driver ที่ agent lane หยิบไปใช้ได้จริง
**STEP 1:** (a) ใส่แบนเนอร์ `HOLDOUT-BURNED` หัวไฟล์ทั้ง 5 · หรือ (b) ขยาย guard ให้เตือนตอนถูก invoke
👉 แนะ (b) สำหรับ `qwen_batch_runner.ps1` + (a) สำหรับอีก 4 ตัวที่เป็น order-specific ของเก่า
**ห้าม:** แก้หน้าต่างในสคริปต์เก่าให้ "ถูก" เฉยๆ — มันคือประวัติของ run ที่เกิดไปแล้ว แก้แล้วหลักฐานเพี้ยน

## ORDER-239 — [monitoring gap] RSI-MR: หางเวลาถือ basket 98-182 วัน ยาวกว่าวัน judge — `OPEN` · ทำได้: Claude · 👉 แนะ: Claude
**bars:** N-A (เพิ่ม field ใน monitoring) · **flat-lot probe:** N-A
**ปัญหา:** config ที่ re-optimize แล้วมี worst basket recovery **98 วัน MAIN / 182 วัน BWD** — หางนี้ไม่เคยถูกเห็นบนข้อมูล live
และ **DD% มองไม่เห็นมัน** · 990103 ACTIVE judge **2026-10-24** ซึ่ง **สั้นกว่าหางที่วัดได้**
**ช่องว่าง:** `portfolio/expectations.csv` ไม่มีช่องอายุ basket · handoff บอกจะส่งให้ `ea-live-monitor` แต่ไม่เคยตั้งค่าอะไรจริง
**STEP 1:** เพิ่ม field "อายุ basket ที่เปิดค้างนานสุด" เข้า monitoring chain + ตั้งเกณฑ์เตือนราว 100 วัน
**ห้าม:** ตัดสิน 990103 จากหางนี้ — มันคือสิ่งที่ยังไม่เคยวัดบน live ไปวัดก่อน

## ORDER-250 — [🔴 demo · order-of-record หาย] SS1 LondonORB 992003: ผ่าน funnel ขึ้น demo โดยไม่มีใบสั่งงานรองรับ — `DONE(Claude/Opus 2026-07-27) — STEP 1 ใบสั่งย้อนหลังเขียนแล้ว (ORDER-143 คงรอยความเห็นตรงข้ามไว้) · STEP 2 corr ปิดแล้ว วัดครบ 13/13 คู่ max |r| 0.543 < 0.8 ผ่านบาร์ · จุดอ่อน MAIN 1.16 < 1.2 ยังอยู่ = เรื่องของวัน judge + REVIEWED(Claude/Opus 2026-07-27)`
**bars:** corr vs cohort < 0.8 (pairwise) · **flat-lot probe:** N-A
**ปัญหา:** ORDER-143 ปิดไปเมื่อ 2026-07-20 ว่า "EA ไม่มี input `_2_PartialPct1`/EMA200 ⇒ **sweep ไม่ได้รัน** · next = หา HOME ใหม่
ไม่ใช่ stack lever". **แล้ววันที่ 07-23 commit `a88db4c6` เพิ่ม input พวกนั้นเข้าไปจริง รัน funnel และดัน SS1 เป็น
VALIDATED CANDIDATE → attach demo magic 992003** (M4 1.16/1.06, holdout 1.21@n=86, MC ruin 0.00%)
**สิ่งที่หายไป:** ไม่มี order block ไหนบันทึกการพลิกนี้เลย — หลักฐานเดียวคือ subject ของ commit กับช่อง `notes` ใน `DEPLOYMENTS.csv`
⇒ **EA ตัวหนึ่งเดิน funnel จนถึง demo โดยไม่มีใบสั่งงานเป็นหลักฐาน**
**จุดอ่อนที่ตัวมันเองประกาศไว้ และยังไม่ถูกปิด:** real-tick MAIN 1.16 **ต่ำกว่าบาร์ 1.2** · ต้องใช้ `MinOr=0.5` เป๊ะ (0.8 → 1.09) ·
cohort holdout โดน TrendRider กินไปบางส่วน · **corr vs cohort ยังไม่เคยวัด** (ค้างมาตั้งแต่ ORDER-174)
**STEP 1:** เขียน order block ย้อนหลังให้ครบ (อะไรเปลี่ยน · หลักฐานอะไรรองรับ · ใครตัดสิน)
**STEP 2:** ปิดช่อง corr vs cohort **ก่อน judge 2026-10-23**
**ห้าม:** ปล่อยให้ถึงวัน judge โดย corr ยังว่าง · เขียน ORDER-143 ทับจนอ่านไม่ออกว่าเคยสรุปตรงข้าม (เก็บรอยไว้)

### ORDER-250 STEP 1 — ใบสั่งย้อนหลัง (order-of-record ที่หายไป) · Claude/Opus 2026-07-27
**เขียนย้อนหลังโดยเจตนา ไม่ใช่การกลบ** — ORDER-143 คงข้อความเดิมไว้ครบพร้อมหมายเหตุกลับด้าน อ่านได้ว่าเคยสรุปตรงข้าม

| | |
|---|---|
| **อะไรเปลี่ยน** | 2026-07-20 ORDER-143 ปิดว่า "EA ไม่มี input `_2_PartialPct1`/EMA200 ⇒ **sweep ไม่ได้รัน** · next = หา HOME ใหม่ ไม่ใช่ stack lever" · **2026-07-23 commit `a88db4c6` เพิ่ม input เข้า EA จริง** (`_07_UseTrendFilter` · `_07_TrendEmaPeriod=200` · `_07_PartialPct` · `_07_PartialAtR`) แล้วรัน funnel |
| **หลักฐานที่รองรับการพลิก** | M4 MAIN 1.16 / BWD 1.06 · holdout 1.21 @ n=86 · MC ruin 0.00% ⇒ VALIDATED CANDIDATE → attach demo **magic 992003** (XAUUSD M15, judge 2026-10-23) |
| **ใครตัดสิน** | Opus-seat 2026-07-23 · **แต่ไม่มี order block รองรับเลย** หลักฐานเดียวคือ subject ของ commit + ช่อง `notes` ใน `DEPLOYMENTS.csv` |
| **ทำไมมันหลุด** | การพลิกเกิดใน session ที่ไม่ได้เปิดใบใหม่ และ ORDER-143 ปิดไปแล้ว ⇒ ไม่มีใบไหนเป็นเจ้าของ ⇒ EA เดิน funnel จนขึ้น demo โดยไม่มีใบสั่งงานเป็นหลักฐาน |
| **ป้องกันซ้ำ** | `scripts/check_block_staleness.ps1` (ORDER-252, commit `6f2d9c47`) จับ pattern นี้อัตโนมัติแล้ว — บล็อกที่ปิดแล้วแต่ artifact ที่มันอ้างถูกถอน/หักล้าง |

**จุดอ่อนที่ EA ประกาศเองและยังไม่ปิด (ยกมาไว้ให้เห็น ไม่ได้แก้):** real-tick MAIN **1.16 ต่ำกว่าบาร์ 1.2** ·
ต้องใช้ `MinOr=0.5` เป๊ะ (0.8 → 1.09 = แกนเปราะ) · cohort holdout โดน TrendRider กินไปบางส่วน

### ORDER-250 STEP 2 — corr vs cohort ✅ ปิดแล้ว (`2e18a7e3`)
บาร์: pairwise corr < 0.8 · **วัดครบ 13/13 คู่ในบัญชี 415573666** (ไม่มีคู่ไหนตกไปที่ default 1.0)

| vs | r | | vs | r |
|---|---|---|---|---|
| 990207 | **+0.543** (สูงสุด) | | 990203 | +0.125 |
| 992001 | +0.535 | | 990201 | −0.106 |
| 990208 | −0.432 | | 992004 | +0.090 |
| 990110 | −0.317 | | 990205 | +0.087 |
| 990206 | −0.242 | | 990202 | −0.070 |
| 990204 | +0.164 | | 990025 | +0.041 |
| 990030 | +0.147 | | | |

⇒ **max |r| = 0.543 < 0.8 = ผ่านบาร์** · 9 ใน 13 คู่ ≤0.40 = additive จริง ไม่ใช่ตัวซ้ำ
**ช่องที่ปิดได้ก่อน judge 2026-10-23 = ปิดแล้ว** เหลือจุดอ่อน MAIN 1.16 < 1.2 ซึ่งเป็นเรื่องของวัน judge ไม่ใช่ของใบนี้

## ORDER-251 — [🔴 integrity · หนี้ระบบ] คลัง skill ที่เป็นเจ้าของบาร์ตัดสินทุกใบ อยู่นอก repo และไม่มี version control — `DONE(Claude/Opus 2026-07-27, `6aa19f62` แล้ว `e56c357f` แก้) — ทาง (a): mirror 33 ไฟล์เข้า docs/skills_mirror/ + MANIFEST.sha256 + check_state §10 · ⚠️ commit แรก mirror ไม่ติดจริง ดูบันทึกความพลาดด้านล่าง + REVIEWED(Claude/Opus 2026-07-27)`
**ผล:** `scripts/sync_skills_mirror.ps1 -Update/-Check` · `docs/skills_mirror/` (mirror ไม่ใช่ move — ของเดิมอยู่ที่เดิม) ·
`check_state.ps1` §10 เทียบคลังจริงกับ manifest ทุก commit · **WARN ไม่ block** โดยตั้งใจ: คลังนี้*ควร*เปลี่ยนได้ แค่ต้องไม่เปลี่ยนแบบไม่มีใครเห็น
**เรื่องที่ต้องรู้:** 11 จาก 26 skill เป็น **symlink ไป `C:\Users\patip\.agents\skills`** = แชร์กับเครื่องมืออื่น แก้จากนอกโปรเจกต์นี้ได้ ·
`Get-ChildItem -Recurse` **ไม่เดินตาม reparse point** ⇒ วิธีที่นึกออกก่อนจะ mirror ได้เปลือกเปล่าแล้วรายงานว่าสำเร็จ ต้องใช้ .NET `EnumerateFiles`
**🔴 ความพลาดที่เก็บไว้เป็นบทเรียน (`6aa19f62` ผิด ไม่ amend ทิ้ง):** `.agents/skills` เป็น git repo ของตัวเอง ⇒ ตาม symlink ไปแล้วลาก `.git` มาด้วย
⇒ git เก็บทั้งโฟลเดอร์เป็น **gitlink (mode 160000) = ตัวชี้ commit เปล่าๆ ไม่มีเนื้อ** · commit นั้นเขียนว่า "mirror 131 ไฟล์" ซึ่ง 98 ไฟล์คือไส้ `.git`
และ **ไม่มีสักไฟล์อยู่ใน repo จริง** · ที่รอดสายตาเพราะ `-Check` เขียว, `check_state` เขียว, จำนวนไฟล์เพิ่ม — **ทุกสัญญาณที่ดูล้วนวัด "คลังจริง vs manifest"
ไม่มีอันไหนวัดสิ่งที่ใบสั่งขอจริงๆ คือ "เนื้ออยู่ใน git ไหม"** · แก้แล้ว: ตัด `.git`/`node_modules`/`__pycache__` · ของจริง 33 ไฟล์ blob ครบ gitlink 0
· ยืนยันด้วยการ diff path-by-path ไม่ใช่นับจำนวน (ที่ขาด 4 ไฟล์คือ `.pyc` ล้วน ตั้งใจตัด)
**พิสูจน์ว่ากรง fail ได้:** ก๊อปคลังไป temp แก้ 1 ไฟล์ ลบ 1 ไฟล์ → `-Check` รายงาน "1 changed, 1 removed" exit 1 · **ไม่แตะคลังจริงในการทดสอบ**
**bars:** N-A · **flat-lot probe:** N-A
**ปัญหา:** ORDER-121 + ORDER-122 ทั้งสองใบคือการเขียน `backtest-optimize-rigor`, DEMOTED banner, corr ladder,
`FINAL RULE` ข้าม 9-11 skill ใหม่ทั้งหมด — **ของทั้งหมดนั้นอยู่ที่ `C:\Users\patip\.claude\skills\` ไม่ได้อยู่ใน `D:\EA_LAB`**
⇒ ไม่อยู่ใน git · ไม่มีประวัติ · `check_state.ps1` มองไม่เห็น · **ใครแก้เมื่อไรก็ได้โดยไม่มีอะไรจับ**
**ทำไมมันย้อนแย้ง:** ORDER-102/103 ลงทุนสร้าง append-chain tamper integrity ให้ taskboard ทั้งระบบ
แต่ **เอกสารที่เป็นเจ้าของบาร์ตัดสินทุกตัว** กลับเปิดโล่ง — verify วันนี้ได้ แต่พิสูจน์ไม่ได้ว่าไม่ drift ตั้งแต่ 07-18
**STEP 1:** เลือกทาง — (a) mirror เข้า repo + เช็ค hash ใน `check_state.ps1` (b) symlink/submodule (c) snapshot+diff รายสัปดาห์
👉 แนะ (a) เพราะถูกที่สุดและเข้ากับกรงที่มีอยู่แล้ว
**ห้าม:** ย้าย skill ออกจากที่เดิมจน Claude Code หาไม่เจอ (mirror = สำเนา ไม่ใช่การย้าย)

## ORDER-252 — [tooling] staleness linter: บล็อกที่ปิดแล้วยังพูดสิ่งที่ถูกหักล้างไปแล้ว — `DONE(Claude/Opus 2026-07-27, `6f2d9c47`) — warn-only · จับ ORDER-073 ได้เอง · STALE 11 · dangling 4 · unresolved 96 + REVIEWED(Claude/Opus 2026-07-27)`
**bars:** N-A · **flat-lot probe:** N-A
**ปัญหา:** ORDER-073 · ORDER-143 · ORDER-188 = **บั๊กเดียวกัน 3 ครั้ง** ไม่ใช่ 3 เรื่อง — หลักฐานปลายน้ำขยับ แต่บล็อก order
ที่ปิดไปแล้วไม่ขยับตาม. และทุกครั้ง **คำแก้ถูกเขียนไว้จริง** แค่ไปอยู่ที่อื่น (banner บนไฟล์ verdict · ช่อง notes ใน
`DEPLOYMENTS.csv` · เนื้อของ order ใบใหม่กว่า)
`check_taskboard_archive.ps1` ตรวจ **การเชื่อม review** ได้ แต่ไม่มีอะไรตรวจว่า **ข้ออ้างในบล็อกที่ปิดแล้วยังตรงกับ repo ไหม**
**STEP 1:** เขียน linter — ทุกบล็อกที่ terminal: resolve path ที่มันอ้าง · resolve commit hash ที่มันอ้าง ·
แล้ว **flag บล็อกที่ artifact ของมันตอนนี้ติด banner `SUPERSEDED`/`WITHDRAWN`/`DEPRECATED`/"ถอน"**
ตัวนี้จะจับ 073 กับ 143 ได้อัตโนมัติ
**หมายเหตุ:** thesis เดียวกับ ORDER-219 ("ทำให้ detector ที่มีอยู่แล้วถูกอ่าน") แค่เอามาใช้กับบอร์ดแทน log
**ห้าม:** ทำเป็น hard block ตั้งแต่แรก (จะ false-fire เยอะ) — เริ่มที่ warn + รายงาน

### ผล ORDER-252 (Claude/Opus 2026-07-27 · `6f2d9c47`)
`scripts/check_block_staleness.ps1` — warn-only, exit 0 เสมอเว้นแต่ `-Strict` · ใช้ `Get-StatusClass` ตัวเดียวกับ validator
(กันไม่ให้สองเครื่องมือเถียงกันว่า terminal แปลว่าอะไร) · **จับ ORDER-073 ได้เองโดยไม่ต้องบอก = acceptance test ผ่าน**
สแกน 316 บล็อก (terminal 276) → **STALE 11 · DANGLING commit 4 · UNRESOLVED path 96**
จูน 3 รอบกับ corpus จริง ทุกรอบ**ตัด noise ไม่ใช่เพิ่มความฉลาด**: 23→11 (banner ต้อง UPPERCASE + อยู่หัวไฟล์ + ไม่ใช่แถวตาราง —
`RECONCILE_EXCEPTIONS.md` คือ*ตาราง*ของของที่ superseded ทุกแถวเลยยิงหมด) · 62→4 dangling (regex hex กินเลขบัญชี
`463666728`/magic/วันที่ `20260709` — บังคับให้มีตัวอักษร a-f อย่างน้อยตัวเดียว) · 231→96 path (ชนิดไฟล์ที่อยู่นอก git
เช่น .htm/.set บอกอะไรไม่ได้ + citation แบบ absolute โดนตัดตัวอักษรไดรฟ์ทิ้ง)
**4 hash ที่ resolve ไม่ได้:** `6c8241d8`(×2 จาก ORDER-102/103) · `ded1996b`(103) · `287cce51`(128) — **รายงานไว้ ไม่ได้แก้** ต้องการการตัดสิน ไม่ใช่การกวาด

## ORDER-213 — [bookkeeping · ก่อน attach] Boss_16/Kangaroo: แก้บาร์ตัดสิน demo ให้เป็นเลขสะอาด — `DONE(Claude/Opus 2026-07-25) — bundle พร้อม attach ที่ `_vps_deploy/BOSS16_KANGAROO_XAU/``
**ตั้งใจมาแก้ตัวเลข 2 ตัว แต่เจอของที่อันตรายกว่าระหว่างทาง:**
### 🔴 `.ex5` ใน `ea_template/` เก่าค้าง และถ้า attach ไปจะ "ทำงานคนละอย่างกับที่คิด"
`ea_template/Boss_16_KangarooGrid.ex5` = **2026-07-23, 128,744 bytes** · ไฟล์ chassis ที่มันคอมไพล์ทับ **7 ไฟล์ถูกแก้
2026-07-24** (`MoneyManagement` · `RiskControl` · `Inputs` · `LabCore` · `ExitManager` · `Recovery` · `entries/Kangaroo`)
= วันที่ ORDER-187/190/194 ลง. build ปัจจุบัน = **134,550 bytes** (โตขึ้น 5,806)
**`_16_BaseLotMode` ถูกเพิ่มโดย ORDER-190 วันที่ 07-24 — คือหลังจากไบนารีตัวเก่าถูกคอมไพล์** ⇒ ไบนารีตัวนั้น**ไม่มี
input นี้อยู่เลย**. MT5 **เมิน input ที่ไม่รู้จักแบบเงียบ ๆ** (memory `mt5-tester-cache-nondeterminism`) ⇒ ถ้า user
ลากตัวเก่าลงชาร์ตแล้วโหลด `..._scaled_demo.set` **EA จะรัน flat mode ทั้งที่คนใช้เชื่อว่ารัน balance-scaled**
และยังขาด safety fix ของ ORDER-187/194 ด้วย. **นี่คือ PENDING_ATTACH ที่ถ้า attach ไปเมื่อวาน จะได้ผลลัพธ์ที่
ตีความผิดทั้ง demo โดยไม่มีอะไรเตือน**
bundle ใหม่ใช้ build ปัจจุบัน · ตรวจแล้วว่า tester ทั้ง 2 instance (`D:\Meta 5b` + roaming `9CA16B`) **hash ตรงกันเป๊ะ**
· `.ex5` ถูก gitignore ⇒ **บันทึก SHA256 ไว้ใน README แทน** `B5001606FC…27CFC` + คำสั่งให้ user verify ก่อน attach
### ตัวเลขที่ตั้งใจมาแก้ (ORDER-202 Part 2)
- **PF คาดหวัง 1.46 ไม่ใช่ 1.57** · **~68 เทรด/ปี (5.7/เดือน) ไม่ใช่ ~81–90** — ORDER-078 รันถึง `2026.07.01` ทั้ง funnel
  และมีแถว year-split เขียนว่า `2026H1 … PF 1.75 / 85t` ตรง ๆ
- **🎯 ผลที่ตามมาซึ่งไม่มีใครสังเกต: อัตราเทรดที่ถูกต้อง ทำให้ "วันตัดสิน" ต้องเลื่อน** — 30 เทรดที่ 5.7/เดือน = **~5.3 เดือน**
  ⇒ judge_date ต้องเป็น **attach + 5.5 เดือน ไม่ใช่ +3** มิฉะนั้น**ต่อให้ทำผลงานดีแค่ไหนก็ผ่านบาร์ 30 เทรดไม่ได้**
  (อัตราเดิมที่เฟ้อจะบอกว่า ~3.9 เดือน) — **นี่คือตัวอย่างว่าการปนเปื้อนเดินทางไปถึง "ตาราง" ไม่ใช่แค่ "พาดหัว"**
### ที่เขียนไว้ใน README ด้วยเพราะจะลืมกัน
- ต้องเริ่มที่ balance **$10,000** เท่านั้น ไม่งั้น scaled กับ flat เทียบกันไม่ได้ตั้งแต่ไม้แรก (anchor = 10000)
- **ความขัดแย้งที่ยังไม่ได้แก้ (จงใจ ไม่เดา):** `EA_MASTER_INDEX` เขียน home = `XAUUSD D1 (D1g)` แต่ `.set` และ funnel
  ORDER-077/078 ที่ให้เลข 1.46/1.30 คือ **H1**. D1 คือ ORDER-091C-D1g ซึ่งปิดไปแล้วว่าไม่มี edge = **คนละหลักฐาน**
  → README สั่งให้หยุดถามถ้าตั้งใจจะ attach D1
- eqDD BWD = 9.70% ขณะที่ kill rule default = 12% ⇒ headroom บาง **ตั้งใจ** — ถ้าทริปเร็ว ให้เช็คก่อนว่า balance-scaling
  โตขึ้นหรือเปล่า ก่อนจะสรุปว่า edge พัง
- เป็น **grid** ⇒ ถ้าแพ้ ให้บันทึกว่าแพ้เพราะ entry ผิด หรือเพราะ grid แบกขาที่สวนอยู่ — คนละความล้มเหลว และมีแค่แบบแรก
  ที่ฆ่า concept
**ยังเป็นของ user:** ลาก attach เอง (agent ทำแทนไม่ได้) แล้วเติมแถว `DEPLOYMENTS.csv` + `expectations.csv` ในเซสชันเดียวกัน
**source:** ORDER-202 Part 2 — Boss_16 **edge จริง** (clean MAIN PF 1.46/205t, BWD 1.30/278t = ผ่านทั้งสองบาร์สบาย)
แต่ criteria ที่ pre-register ไว้คำนวณจาก funnel ORDER-078 ที่รัน `2023.01.01 → 2026.07.01` ทุกขั้น. ถ้า attach ตอนนี้
**demo จะถูกตัดสินด้วยบาร์ที่ leak เป็นคนเขียน**. **spec:** แก้ 2 เลขในทุกที่ที่มันปรากฏ (bundle README + `expectations.csv`
+ DEPLOYMENTS notes + DEMO_DEPLOYMENT_PLAN): **PF คาดหวัง 1.46 ไม่ใช่ 1.57** · **~68 เทรด/ปี ไม่ใช่ ~81–90/ปี**
(ตัวหลังไปตั้ง judge_date ด้วย → ตรวจว่า judge_date ยังสมเหตุผลที่อัตราใหม่). ระบุในหมายเหตุว่า 2026H1 ถูก funnel กินไปแล้ว
→ **demo-forward = holdout จริง** (precedent Boss_16 ที่ CLAUDE.md อ้างอยู่แล้ว).
**bars:** N-A (งานเอกสาร ไม่ใช่ทดสอบ) · **flat-lot probe:** N-A
**ห้าม:** เปลี่ยนพารามิเตอร์ใน .set (edge สะอาด ไม่ต้อง re-opt) · attach แทน user

## ORDER-215 — [🔴 เงินจริง · integrity] MatchaGrid CHFJPY: verdict CORE อ้าง genetic run ที่ไม่มี fine-stage — `PART 1 DONE(Claude/Opus 2026-07-25) · PART 2 CUTLOSS-QUESTION DONE(Claude/Sonnet 2026-07-26): "bounded+SL" ถอนแล้ว — safety switch ไม่ตอบสนอง · re-measure funnel ยัง OPEN`
**ตรวจ ini จริงทั้งชุดแล้ว — ภาพจริงดีกว่าที่ audit เสนอ และแย่กว่าที่ scorecard เขียน:**
- `OPT_MG_CHF_lowDD.ini` (ตัวเลือกพารามิเตอร์) = `Optimization=2` genetic · `Criterion=0` · **`2023.01.01–2026.06.01`
  = กิน holdout 5 เดือน** · ไม่มี fine-grid ไม่มี fan → **ขาที่ใช้เลือก = สกปรกเต็ม ๆ**
- `MG_CHFJPY_IS.ini` = single test (`Optimization=0`) บน window เดียวกันที่สกปรก
- **`MG_CHFJPY_OOS.ini` = single test `2020.01.01–2023.01.01`** ← **สะอาด และเป็น OOS จริง** (คือ BWD ของเราพอดี)
**⇒ นี่คือเหตุผลที่ผมไม่ตีตก:** ตัวเลข **2.08 ที่ scorecard อ้าง มาจากขา OOS ที่สะอาด** — selection สกปรก แต่ confirmation
สะอาด. โครงสร้างแบบนี้ "อ่อน" ไม่ใช่ "เท็จ". แต่ **CORE ยืนบนขาเดียวไม่ได้** โดยเฉพาะเมื่อ EA เป็น **grid** ที่
doctrine บังคับ Model-4 ก่อน verdict และยังไม่เคยมี flat-lot probe เลย ⇒ downgrade เป็น **PARKED-VERIFY(user)**
**🔴 PART 2 — สั่งลำดับใหม่ 2026-07-26 (Claude/Opus) หลัง recon: `_triage/ORDER215_MATCHAGRID_RECON.md`**
recon เจอ 3 อย่างที่ทำให้ "re-measure PF ก่อน" เป็นลำดับที่ผิด:
1. **MatchaGrid ปิดซอร์สจริง** — มีแต่ `.ex5` ใน `D:\Meta 5b` + roaming ไม่มี `.mq5` ที่ไหนเลย
2. **ไม่เคยมี Model-4 run สักครั้ง** — ini ทั้ง 14 ใบเป็น `Model=1` ⇒ ตาม doctrine 2026-07-17 grid ที่วัดต่ำกว่า M4
   **ไม่ใช่หลักฐานเลย** ⇒ แปลว่าตัวเลขทุกตัวที่เคยเขียนถึง EA นี้ รวม 2.08 ที่ใช้ปกป้องมัน อยู่ใต้มาตรฐานหลักฐานของเราเอง
3. **คำว่า "bounded grid + hard SL" — คือสิ่งเดียวที่กันมันจาก uncapped-ruin — แขวนอยู่บน `InpCutLossMode=0`**
   ซึ่งเป็น input ที่เจอได้จากการอ่าน header ของ report เท่านั้น และ **ไม่มีเอกสารที่ไหนในรีโปบอกว่าโหมด 0 แปลว่าอะไร**
⇒ **คำถามที่ต้องตอบก่อนคือ "มันตัดจริงไหม" ไม่ใช่ "PF เท่าไหร่"** — เป็นคำถามเดียวกับ ORDER-222 เป๊ะ และตอบได้ถูกกว่ามาก:
ดันความเสี่ยงจนขาดทุนลึก แล้วดูว่ามีการปิดยกตะกร้าเกิดขึ้นไหม (probe แบบ `scripts/order222_cutloss_probe.ps1`).
**ถ้าไม่มีการตัด = DEAD-STRUCTURAL บนเงินจริง ต้องแจ้ง user ทันที ไม่ต้องรอ funnel** · ถ้ามีการตัด ค่อยจ่ายคิว M4 ที่แพงข้างล่าง
**สเปก funnel เดิม (ยังใช้ได้ แต่เป็นขั้นที่ 2):** clean-MAIN `2023.01.01–2025.12.31` re-measure + fan ±20% ทุกแกน + **flat-lot probe**
(grid ⇒ ต้องรู้ว่า edge อยู่ที่สัญญาณหรือที่ escalation) + **Model-4** ทั้งสองหน้าต่าง. ⚠️ M15 × 3 ปี × grid = คิว M4 หนัก
และเครื่องชน memory ceiling อยู่ (ดู ORDER-210) → **แตก sub-window ตั้งแต่แรก อย่าเพิ่งยิงรวดเดียว**
**bars:** pass = clean MAIN ≥1.2 **และ** BWD ≥1.0 บน M4 + fan ≥70% ถือ ⇒ คืนสถานะได้ · dead = clean MAIN <1.0
⇒ แจ้ง user ว่าแล็บไม่หนุนแล้ว (ถอดหรือไม่ = สิทธิ์ user, เป็น EA ที่เขาเลือกเอง) · กลาง ⇒ คง PARKED-VERIFY
**flat-lot probe:** pending (บังคับ — grid/escalation)
**ห้าม:** แตะค่าบนบัญชีจริง · ใช้ Model-2 เป็นหลักฐานกับ grid (doctrine 2026-07-17: grid บน M2 = ไม่ใช่หลักฐานเลย)

**🔴 UPDATE 2026-07-26 (Claude/Sonnet) — เจอ 2 อย่างก่อนจะรัน probe: `_triage/ORDER215_MATCHAGRID_CUTLOSS_FINDING.md`**
1. **2 ใน 5 report ที่เคยอ้าง เป็น degenerate-tick artifact** — `QWEN_MG_IS`/`QWEN_MG_OOS` มี tick/bar = 3.9
   เทียบ report สุขภาพดี 2 ใบที่ 58-59 (M15 2 ปีควรมี ~50,000 bars แต่ `QWEN_MG_IS` มีแค่ 12,073) = คลาสเดียวกับ
   `mt5-no-disk-space-is-memory-ceiling` ⇒ **ทิ้งทั้ง PF 0.17 และ PF 2.15 ทั้งคู่** (ไม่ใช่เลือกทิ้งใบที่ไม่ถูกใจ)
2. **บนข้อมูลสะอาดที่เหลือ (3.4 ปี, input set เดียวกันทั้งหมดรวม magic 20240001 ที่เป็นเงินจริง) — ไม่เจอการปิดยกตะกร้า
   แบบเปอร์เซ็นต์แม้ครั้งเดียว** (เจอแค่ churn ปกติ 3 ครั้ง −4 ถึง −16 net บน 23-31 ไม้ + forced end-of-test)
⇒ **`InpCutLossMode=0` = ปิดสวิตช์ หรือ = โหมดที่ข้อมูลนี้ไม่เคยดันถึงเกณฑ์ — ยังแยกไม่ออก** ต้องใช้เทคนิคเดียวกับ
ORDER-222 (ดันความเสี่ยงจนลึกแล้วดูว่ามีการตัดไหม)

**🔴 RESOLVED 2026-07-26 (Claude/Sonnet) — ดันแล้ว: `_triage/ORDER215_MATCHAGRID_CUTLOSS_VERDICT.md`**
สร้าง `scripts/order215_matchagrid_cutloss_probe.ps1` (สคริปต์เดียวกับ ORDER-222 แต่ปรับ lever ให้ตรงกับกลไก
MatchaGrid — pin ครบ 15 input เพราะ**ไม่มี ini ไหนของ EA นี้เคย pin ตระกูล `InpCutLoss*` มาก่อนเลย** ค่าที่ recon
เจอมาจาก terminal cache ล้วนๆ):
- **Stage 0 (control):** primary terminal ไม่ว่าง (อีก session ใช้อยู่ ไม่แตะ) → ย้ายไป `Meta 5b` แทน — เจอปัญหาแยกต่างหาก:
  ผลไม่ตรงกับ archive (PF 1.77 vs 2.08, tick ต่างกัน 14 เท่า) เพราะ **tick-history ของ `Meta 5b` เพี้ยนจาก terminal
  หลัก** (ตาม memory `mt5-parallel-instance` — คนละเรื่องกับ CutLoss แต่ต้อง flag แยกไว้ก่อนเชื่อ cross-instance run ใดๆ)
- **Stage 1 (ดันความเสี่ยง):** ลด `InpGridPoints` 350→200 บน window สะอาดเดิม → **66 ไม้พร้อมกัน, eqDD 63.94%**
  (2.5 เท่าของเพดานที่เคยเห็นในข้อมูลสงบ) — เจอ cluster ติดลบ 4 ก้อนตอนแรก แต่**เช็ค balance ก่อน-หลังแล้วพบว่าเป็น
  churn ปกติทั้งหมด** (−0.63%, −0.27%, −0.19%, −0.19% ของ balance ก่อนหน้า — ไม่ใช่การตัด) แก้ script ให้เช็ค
  %-of-balance แทนการนับ cluster เฉยๆ (บทเรียนเดียวกับที่ทำให้ ORDER-222 แม่นยำ)
- **Stage 2 (isolate):** ที่ความเสี่ยงเดียวกัน (DD 63.94%) เทียบ threshold จริง (`Percent=10/Fixed=50`) กับ threshold
  ที่ตึงสุดโต่ง (`Percent=1/Fixed=1`) — **ผลลัพธ์เหมือนกันทุกทศนิยม** (2,961 ไม้, net, DD, cluster ทั้ง 4 ก้อนที่
  timestamp เดียวกันเป๊ะ) ⇒ **`InpCutLossMode=0` ไม่ตอบสนอง threshold เลย** — นี่คือหลักฐานที่หนักแน่นที่สุดเท่าที่ทำได้
  โดยไม่มีซอร์ส ว่าโหมดนี้ **ปิดสวิตช์จริง ไม่ใช่แค่ยังไม่เคยติด**
**⇒ "bounded grid + hard SL" — เหตุผลเดียวที่กัน MatchaGrid จากถัง uncapped-ruin — ถอนแล้ว** สิ่งที่จำกัดจริงคือ
lot ladder **linear** (`InpStepAddLot` บวกคงที่ ไม่ใช่ทวีคูณ) ซึ่งปลอดภัยกว่า geometric martingale ตาม precedent
`rsi-from-pips-mechanism` **แต่ไม่ใช่ stop** ⇒ **ยังไม่ถึง DEAD-STRUCTURAL อัตโนมัติ** (gate เดิมเขียนไว้เฉพาะ
geometric ladder) — ไฟล์เป็น "ถอนคำอ้างเรื่อง safety + สิทธิ์ตัดสินใจเป็นของ user" แบบเดียวกับ NuiIndy (ORDER-222)
**ที่ sizing จริง (GridPoints=350) ยังไม่เคยเห็น DD ขนาดนี้ใน 3.4 ปี ⇒ ไม่มีอะไรต้องเปลี่ยนบนบัญชีจริงวันนี้**
**เปิดไว้ ไม่บล็อก:** `InpCutLossMode` ค่าอื่นทำอะไร (ต้องมี source หรือ sweep ค่า) · reconcile tick history
ของ `Meta 5b` vs primary · funnel re-measure เดิม (clean-MAIN + fan + flat-lot + M4) ยังค้างอยู่

<details><summary>สเปกเดิมของใบนี้</summary>
**source:** ORDER-204 DEBT row `OPT_MG_CHF_lowDD.ini` (`Optimization=2`, `Criterion=0`, window `2023.01.01–2026.06.01`
= **กิน holdout ด้วย**, ไม่มี fine-stage ไม่มี fan). citation = `EA_SCORECARD_AND_REGISTRY.md:156` "MG_v1 MatchaGrid
CHFJPY M15 2.08 CORE — grid but bounded+SL; passed deep-val". agent ตั้งข้อสังเกตถูกว่าแถวนี้อยู่ในตารางที่ขึ้นหัวว่า
`⛔ HISTORICAL, SUPERSEDED 2026-07-09` — **แต่ EA ตัวนี้ ACTIVE อยู่บน REAL_CENT 159475669 (magic 20240001) จริง**
(`DEPLOYMENTS.csv:12`) ⇒ ตารางถูก mark historical ไม่ได้แปลว่าเงินหยุดเดิน.
**spec:** เหมือน ORDER-214 — ยืนยันว่ามีหลักฐาน fine-stage/fan ที่ไหนอีกไหมนอก `ini/` ก่อน; ไม่มี ⇒ แก้ข้อความให้ตรง
(CORE ที่ยืนบน genetic pass เดียว + window ที่กิน holdout = ไม่ใช่ CORE) แล้วค่อยตัดสินว่าจะรัน funnel ไหม
**bars:** N-A รอบแรก · **flat-lot probe:** pending (grid) · **ห้าม:** แตะค่าบนบัญชีจริง
</details>

## ORDER-205 — [expand] MacdDiv_Naked H4: 3 symbol ใหม่ (conditional, เดินต้นไม้เองได้) — `DONE(worker/Sonnet 2026-07-27) — 3/3 symbol รันครบ · GBPJPY 0.83 · USDJPY 1.08/1.09 · EURJPY 1.06/0.90 · ไม่มีตัวถึง 1.2 ⇒ ไม่มี STEP 3A + REVIEWED(Claude/Opus 2026-07-27) = BUILD-ON ทั้งใบ, USDJPY = next home ที่ควร optimize (ยังไม่เคย optimize สักตัว)`
**ที่มา:** ORDER-098-B ปิดด้วย MacdDiv XAU H4 = DEMO-ELIGIBLE (MAIN plateau 1.91 · BWD 1.04 · M4 ยืนยันไม่ใช่ fill artifact) · EURUSD H4 holdout fail แล้วปิด cell ไป · **doctrine BUILD-ON: PF>1 = ของต่อยอด → ยังไม่เคยลอง JPY-cross เลย** ซึ่งเป็นบ้านของ momentum/divergence
**bars:** pass = MAIN PF ≥ **1.2** · dead = MAIN PF < **1.0** · กลาง(WATCH) = **1.0–1.2**
**flat-lot probe:** N-A(single-order — MacdDiv ไม่มี escalation)
**เลน:** `D:\Meta 5c` (lane 3) · **Model 1 เท่านั้น** (5c ไม่มี tick cache — ห้าม Model 4 เด็ดขาด)
**📖 วิธีอ่านผล (ใช้กับทุก order ที่รัน tester — ห้าม Get-Content ไฟล์ .htm มาแกะเอง มันคือ HTML หลายหมื่น token):**
```
powershell -Command ". D:\EA_LAB\scripts\use_python.ps1; python D:\EA_LAB\scripts\parse_mt5_report.py 'D:\EA_LAB\_mt5_auto\reports\<RPT>.htm'"
```
เอาเฉพาะบรรทัด `profit_factor` · `total_trades` · `net_profit` · `balance_drawdown_maximal_pct` (ต้องใช้ **path เต็ม** ทั้ง 2 ตัว ไม่งั้นได้ `NO_REPORT`)

**STEP 1** — รัน MAIN ทีละคำสั่ง (3 ตัว, symbol เปลี่ยนอย่างเดียว):
```
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert "MacdDiv_Naked" -Symbol GBPJPY -Period H4 -FromDate 2023.01.01 -ToDate 2025.12.31 -SetFile "D:\EA_LAB\_vps_deploy\MACDDIV_XAU\MacdDiv_XAU_H4_demo_v1.set" -ReportName MDX_GBPJPY_H4_MAIN -Model 1 -Terminal "D:\Meta 5c\terminal64.exe" -DataDir "D:\Meta 5c" -Portable
```
ทำซ้ำโดยเปลี่ยน `-Symbol` และ `-ReportName` เป็น: **USDJPY** (`MDX_USDJPY_H4_MAIN`) · **EURJPY** (`MDX_EURJPY_H4_MAIN`)

**TREE (ต่อ symbol แยกกัน — symbol หนึ่งตายไม่ลาก symbol อื่นตาย):**
  - **MAIN PF ≥ 1.2** → **STEP 2A:** รัน BWD symbol เดียวกัน `-FromDate 2020.01.01 -ToDate 2022.12.31` `-ReportName MDX_<SYM>_H4_BWD`
    - BWD ≥ 1.0 → **STEP 3A** (ด้านล่าง)
    - BWD < 1.0 → append ผลดิบ + เขียนว่า `BWD-fail` → **STOP symbol นี้** (ห้ามสรุปว่าตาย — lead ตัดสินเอง)
  - **MAIN 1.0–1.2** → **STEP 2B:** รัน BWD เหมือน 2A แล้ว append ผล + ทำเครื่องหมาย `WATCH` → **STOP symbol นี้**
  - **MAIN < 1.0** → append ผลดิบ → **STOP symbol นี้** ไปตัวถัดไป (ห้ามสรุปว่า "ตาย")
  - **trades < 20 ใน MAIN** (ไม่ว่า PF เท่าไหร่) → `BLOCKED(n บาง <20 ใน <SYM> — A: ข้ามไป symbol ถัดไป / B: ลอง H1 บน symbol เดิม)`
  - รันล้ม 2 ครั้งติดบน symbol เดียว → `BLOCKED(<SYM> รันไม่ผ่าน: <error บรรทัดสุดท้าย> — A: ข้าม / B: รอ lead)`

**STEP 3A (ชั้นที่ 3 — sensitivity fan, ทำเฉพาะ symbol ที่ผ่านทั้ง MAIN≥1.2 และ BWD≥1.0):**
คัดลอก .set เดิมเป็น 4 ไฟล์ใน `D:\EA_LAB\_mt5_auto\ab_sets\order205\` แล้วแก้ทีละค่า — เปลี่ยน **ค่าเดียวต่อไฟล์**:
`_01_SwingRadius` = {2, 3, 4, 5} (ค่าอื่นคงเดิมทั้งหมด) → รัน MAIN ทั้ง 4 ไฟล์ `-ReportName MDX_<SYM>_H4_SW<n>`
→ append ตาราง 4 แถว (SwingRadius · PF · trades · DD · net) → **STOP ไปใบถัดไป**
(เหตุผลที่เลือกมิตินี้: ORDER-204 assert พบ `_01_LookbackBars` **inert** บน MacdDiv — กวาดไปก็ไม่ขยับ ส่วน `_01_SwingRadius` ขยับผลจริง)

**ห้าม:** เขียน verdict · แตะ scorecard/EDGE_CATALOG/PROJECT_STATE/VISION/B1_DATASET · รายงานเลข Model 2 · รัน Model 4 · แตะ `_vps_deploy` · ตีความผลนอก branch · เปลี่ยนค่า input ที่ไม่ได้ระบุใน STEP · **แตะหน้าต่าง 2026 ทุกกรณี** (holdout ไหม้แล้ว)

### ผลดิบ ORDER-205
**lane-proof run (Opus-seat 2026-07-25 17:56)** — รันเองเพื่อพิสูจน์ว่าเลน 5c ใช้งานได้ก่อนส่งต่อ worker
(ก่อนหน้านี้ 5c ไม่มี `MacdDiv_Naked.ex5` / `PivotBreakout_XAU.ex5` เลย — copy จาก lane1 `Experts\c091c\` เข้า `D:\Meta 5c\MQL5\Experts\` แล้ว)

| symbol | TF | window | PF | trades | net | eqDD | report |
|---|---|---|---|---|---|---|---|
| GBPJPY | H4 | MAIN 2023.01-2025.12 | **0.83** | 254 | -121.68 | 1.74% | `MDX_GBPJPY_H4_MAIN.htm` |

quality 100% · leverage assert 1:100 ผ่าน · traded through to end of window (idle tail 0 วัน)
→ **TREE: MAIN < 1.0 → STOP symbol นี้** (ไม่ใช่ verdict — แค่ต่ำกว่าบาร์ที่ล็อกไว้ · lead ตัดสินทีหลัง)
→ **เหลือให้ worker: USDJPY + EURJPY**

**worker run (Sonnet, 2026-07-27) — lane 5c · Model 1 · leverage assert 1:100 ทุก run · quality 99-100%**

| symbol | window | PF | trades | net | eqDD | report |
|---|---|---|---|---|---|---|
| USDJPY | MAIN | **1.08** | 250 | 37.24 | 0.80% | `MDX_USDJPY_H4_MAIN.htm` |
| USDJPY | BWD | **1.09** | 221 | 36.84 | 1.01% | `MDX_USDJPY_H4_BWD.htm` |
| EURJPY | MAIN | **1.06** | 236 | 31.57 | 0.86% | `MDX_EURJPY_H4_MAIN.htm` |
| EURJPY | BWD | **0.90** | 243 | −51.03 | 1.87% | `MDX_EURJPY_H4_BWD.htm` |

TREE: ทั้งคู่ MAIN 1.0-1.2 → `WATCH` → รัน BWD ตาม STEP 2B → STOP · ไม่มี STEP 3A (ไม่มีตัวไหนถึง 1.2)

**VERDICT ORDER-205 (Claude/Opus 2026-07-27) = `BUILD-ON` ทั้งใบ — ไม่มีตัวไหนตาย**
- 🎯 **USDJPY = ตัวที่น่าสนใจที่สุดในใบนี้ และเกือบถูกอ่านผิด**: PF 1.08/1.09 ดูจืด แต่มัน **ยืนเหนือ 1.0 ทั้งสองระบอบ**
  ด้วย n เยอะ (250/221) — เสถียรข้ามระบอบมีค่ามากกว่า spike สูงๆ หน้าต่างเดียว (บทเรียน SuperTrend regime-edge)
- 🔴 **ข้อสำคัญ: ทั้งสาม symbol รันด้วย `.set` ที่ tune มาสำหรับ XAU โดยไม่เคย optimize เลยสักตัว**
  ⇒ ตามกฎ "ห้าม DEAD ก่อน optimize" ตัวเลขชุดนี้ **ปิดอะไรไม่ได้เลย** แม้แต่ GBPJPY 0.83 · มันคือ smoke ของบ้านใหม่ ไม่ใช่เพดาน
- next ที่ถูกต้อง = optimize `_01_SwingRadius` + entry-signal บน **USDJPY H4** (บ้านที่ผ่าน both-window แล้ว) ไม่ใช่ไล่ symbol เพิ่ม
  · `_01_LookbackBars` = **inert** (ORDER-204 assert) อย่าเสียเวลากวาด

---

## ORDER-206 — [expand] PivotBreakout H4: 3 symbol ใหม่ (conditional) — `DONE(worker/Sonnet 2026-07-27) — 3/3 symbol + STEP 3A · 🎯 GBPJPY H4 MAIN 1.37 / BWD 1.16 ผ่านทั้งสองหน้าต่าง · XAGUSD 1.13 · US30 1.05 = WATCH + REVIEWED(Claude/Opus 2026-07-27) = BUILD-ON ไม่ใช่ CANDIDATE — SL fan เป็นหน้าผาไม่ใช่ plateau และ base อยู่ที่ขอบช่วงที่ทดสอบ`
**ที่มา:** Wave-1 ปิดด้วย PivotBreakout_XAU (992017) = **VALIDATED CANDIDATE ตัวแข็งสุดของรอบ** (M4 MAIN 1.16 / BWD 1.22 / HOLD 1.33 · MC ruin 0%) — daily-pivot breakout เป็นกลไกที่ portable ข้าม symbol ได้ตามทฤษฎี แต่ยังไม่เคยทดสอบนอก XAU เลย
**bars:** pass = MAIN PF ≥ **1.2** · dead = MAIN PF < **1.0** · กลาง(WATCH) = **1.0–1.2**
**flat-lot probe:** N-A(single-order)
**เลน:** `D:\Meta 5c` (lane 3) · **Model 1 เท่านั้น**
**📖 วิธีอ่านผล:** เหมือน ORDER-205 — ใช้ `scripts\parse_mt5_report.py` ด้วย path เต็ม **ห้าม Get-Content ไฟล์ .htm มาแกะเอง**

**STEP 1** — รัน MAIN 3 ตัว:
```
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert "PivotBreakout_XAU" -Symbol XAGUSD -Period H4 -FromDate 2023.01.01 -ToDate 2025.12.31 -SetFile "D:\EA_LAB\_vps_deploy\PIVOTBREAKOUT_XAU\PivotBreakout_XAU_deploy.set" -ReportName PVT_XAGUSD_H4_MAIN -Model 1 -Terminal "D:\Meta 5c\terminal64.exe" -DataDir "D:\Meta 5c" -Portable
```
ทำซ้ำเปลี่ยน `-Symbol`/`-ReportName`: **US30** (`PVT_US30_H4_MAIN`) · **GBPJPY** (`PVT_GBPJPY_H4_MAIN`)

**TREE (ต่อ symbol แยกกัน):**
  - **MAIN PF ≥ 1.2** → **STEP 2A:** BWD `-FromDate 2020.01.01 -ToDate 2022.12.31` `-ReportName PVT_<SYM>_H4_BWD`
    - BWD ≥ 1.0 → **STEP 3A**
    - BWD < 1.0 → append + `BWD-fail` → **STOP symbol นี้**
  - **MAIN 1.0–1.2** → **STEP 2B:** รัน BWD เหมือนกัน + mark `WATCH` → **STOP symbol นี้**
  - **MAIN < 1.0** → append → **STOP symbol นี้**
  - **symbol ไม่มีใน terminal / no history** → append บรรทัด `NO-DATA:<SYM>` → ข้ามไปตัวถัดไป (ไม่ต้อง BLOCKED)
  - **trades < 20 ใน MAIN** → `BLOCKED(n บาง <20 ใน <SYM> — A: ข้าม / B: ลอง D1)`
  - รันล้ม 2 ครั้งติด → `BLOCKED(<SYM>: <error> — A: ข้าม / B: รอ lead)`

**STEP 3A (ชั้นที่ 3 — SL sensitivity fan, เฉพาะ symbol ที่ผ่านทั้งสองหน้าต่าง):**
คัดลอก `PivotBreakout_XAU_deploy.set` เป็น 3 ไฟล์ใน `D:\EA_LAB\_mt5_auto\ab_sets\order206\` แก้ **ค่าเดียวต่อไฟล์**:
`_02_SlAtrMult` = {**1.5**, **2.0**, **2.5**} (input อื่นคงเดิมทุกตัว — ตรวจแล้ว .set นี้มี 15 input, ไม่มี buffer/offset, lever จริงคือ SL/RR)
→ รัน MAIN ทั้ง 3 `-ReportName PVT_<SYM>_H4_SL<ค่า>` → append ตาราง 4 คอลัมน์ (SlAtrMult · PF · trades · DD) → **STOP ไปใบถัดไป**

**ห้าม:** (เหมือน ORDER-205 ทุกข้อ)

### ผลดิบ ORDER-206 — worker run (Sonnet, 2026-07-27) · lane 5c · Model 1 · leverage 1:100 ทุก run

| symbol | window | PF | trades | net | eqDD | report |
|---|---|---|---|---|---|---|
| XAGUSD | MAIN | 1.13 | 218 | 528.84 | 7.45% | `PVT_XAGUSD_H4_MAIN.htm` |
| XAGUSD | BWD | 0.93 | 190 | −220.43 | 6.95% | `PVT_XAGUSD_H4_BWD.htm` |
| US30 | MAIN | 1.05 | 244 | 23.13 | 0.63% | `PVT_US30_H4_MAIN.htm` |
| US30 | BWD | 0.95 | 213 | −30.80 | 1.60% | `PVT_US30_H4_BWD.htm` |
| **GBPJPY** | **MAIN** | **1.37** | 184 | 327.10 | 1.13% | `PVT_GBPJPY_H4_MAIN.htm` |
| **GBPJPY** | **BWD** | **1.16** | 181 | 158.43 | 1.17% | `PVT_GBPJPY_H4_BWD.htm` |

XAGUSD/US30 → `WATCH` → STOP · **GBPJPY ผ่านทั้ง MAIN ≥1.2 และ BWD ≥1.0 → STEP 3A**

**STEP 3A — SlAtrMult fan, GBPJPY MAIN** (`_mt5_auto/ab_sets/order206/GBPJPY_SL{1.5,2.0,2.5}.set`)

| SlAtrMult | PF | trades | net | eqDD |
|---|---|---|---|---|
| **1.5** (base) | **1.37** | 184 | 327.10 | 1.13% |
| 2.0 | 1.01 | 113 | 5.27 | 1.88% |
| 2.5 | 0.90 | 95 | −89.31 | 1.67% |

**VERDICT ORDER-206 (Claude/Opus 2026-07-27) = `BUILD-ON` ยังไม่ใช่ CANDIDATE**
🎯 GBPJPY H4 คือของที่ดีที่สุดที่ออกมาจากทั้งสองใบ — ผ่าน both-window ด้วย n ที่ใช้ได้ (184/181) และ eqDD ต่ำมาก
🔴 **แต่ยกเป็น CANDIDATE ไม่ได้ เพราะบาร์เขียนว่า "plateau ไม่ใช่ spike" และ fan นี้ไม่ใช่ plateau — มันคือหน้าผา**
1.37 → 1.01 → 0.90 ลงทางเดียวชัน และ **1.5 คือขอบล่างสุดของช่วงที่ทดสอบ** ⇒ เราไม่รู้ว่ามันเป็นยอด plateau หรือปลายหน้าผา
เพราะ**ไม่มีใครวัดฝั่งต่ำกว่า 1.5 เลย** · trade count ร่วงจาก 184→95 ตาม SL ที่กว้างขึ้น ⇒ แกนนี้เปลี่ยน**จำนวนไม้** ไม่ใช่แค่คุณภาพไม้
· ข้อบกพร่องนี้อยู่ที่**การออกแบบใบสั่ง** (ระบุ {1.5,2.0,2.5} โดยวาง base ไว้ที่ขอบ) ไม่ใช่ที่ worker — worker เดินตามที่เขียนเป๊ะ
**next ที่บังคับก่อนคุยเรื่อง deploy:** (1) fan ลงล่าง `_02_SlAtrMult` {0.75, 1.0, 1.25} เพื่อดูว่า 1.5 อยู่ตรงไหนของสันจริง
(2) ถ้ามี plateau จริง → Model-4 (breakout = fill-sensitive, lane 5c ทำไม่ได้ ต้องย้ายเลน) (3) holdout 2026H1 **ไหม้แล้ว**
สำหรับตระกูลนี้ ⇒ ต้องประกาศ demo-forward-as-holdout ตาม precedent Boss_16
**ห้าม:** เอา 1.37 ไปอ้างเป็นหลักฐาน deploy ก่อนรู้ว่ามันเป็น plateau หรือหน้าผา

---

## ORDER-GEN-STANDING — matrix screening (standing order, ไม่มีวัน DONE) — `OPEN-STANDING` · ทำได้: oc-qwen · ZCode
> ⚠️ **หยิบใบนี้ได้เฉพาะเมื่อไม่มี order OPEN ใบอื่นเหลือแล้วเท่านั้น** — ใบนี้คือกันเครื่องว่าง ไม่ใช่คิวหลัก
> ผลจากใบนี้ = **screening ดิบ** ห้ามใช้เป็นหลักฐาน promote อะไรทั้งสิ้นจนกว่า lead review
**bars:** pass = PF ≥ **1.2** · dead = PF < **1.0** · กลาง(WATCH) = **1.0–1.2** (ใช้กับทุก cell ในตาราง)
**flat-lot probe:** N-A(ทุก EA ในตารางเป็น single-order)
**เลน:** `D:\Meta 5c` · **Model 1 เท่านั้น** · หน้าต่าง MAIN `2023.01.01 → 2025.12.31` เสมอ
**📖 วิธีอ่านผล:** เหมือน ORDER-205 — ใช้ `scripts\parse_mt5_report.py` ด้วย path เต็ม **ห้าม Get-Content ไฟล์ .htm มาแกะเอง**

**วิธีทำ:** หยิบ cell **บนสุดที่ยังไม่มีผล** → รัน 1 คำสั่ง → append ผลดิบใต้ตาราง → เติม PF ในช่อง → cell ถัดไป
**template คำสั่ง** (แทน `<EXPERT> <SYM> <TF> <SET> <RPT>` จากแถวที่หยิบ):
```
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert "<EXPERT>" -Symbol <SYM> -Period <TF> -FromDate 2023.01.01 -ToDate 2025.12.31 -SetFile "<SET>" -ReportName <RPT> -Model 1 -Terminal "D:\Meta 5c\terminal64.exe" -DataDir "D:\Meta 5c" -Portable
```

| # | EXPERT | SYM | TF | SET | RPT | PF |
|---|---|---|---|---|---|---|
| 1 | MacdDiv_Naked | AUDJPY | H4 | `_vps_deploy\MACDDIV_XAU\MacdDiv_XAU_H4_demo_v1.set` | GEN_MDX_AUDJPY_H4 | |
| 2 | MacdDiv_Naked | XAUUSD | D1 | `_vps_deploy\MACDDIV_XAU\MacdDiv_XAU_H4_demo_v1.set` | GEN_MDX_XAU_D1 | |
| 3 | MacdDiv_Naked | GBPJPY | D1 | `_vps_deploy\MACDDIV_XAU\MacdDiv_XAU_H4_demo_v1.set` | GEN_MDX_GBPJPY_D1 | |
| 4 | PivotBreakout_XAU | XAUUSD | D1 | `_vps_deploy\PIVOTBREAKOUT_XAU\PivotBreakout_XAU_deploy.set` | GEN_PVT_XAU_D1 | |
| 5 | PivotBreakout_XAU | USDJPY | H4 | `_vps_deploy\PIVOTBREAKOUT_XAU\PivotBreakout_XAU_deploy.set` | GEN_PVT_USDJPY_H4 | |
| 6 | PivotBreakout_XAU | EURUSD | H4 | `_vps_deploy\PIVOTBREAKOUT_XAU\PivotBreakout_XAU_deploy.set` | GEN_PVT_EURUSD_H4 | |
| 7 | MacdDiv_Naked | USDCAD | H4 | `_vps_deploy\MACDDIV_XAU\MacdDiv_XAU_H4_demo_v1.set` | GEN_MDX_USDCAD_H4 | |
| 8 | MacdDiv_Naked | AUDUSD | H4 | `_vps_deploy\MACDDIV_XAU\MacdDiv_XAU_H4_demo_v1.set` | GEN_MDX_AUDUSD_H4 | |
| 9 | PivotBreakout_XAU | XAGUSD | D1 | `_vps_deploy\PIVOTBREAKOUT_XAU\PivotBreakout_XAU_deploy.set` | GEN_PVT_XAG_D1 | |
| 10 | PivotBreakout_XAU | GBPUSD | H4 | `_vps_deploy\PIVOTBREAKOUT_XAU\PivotBreakout_XAU_deploy.set` | GEN_PVT_GBPUSD_H4 | |
| 11 | MacdDiv_Naked | NZDUSD | H4 | `_vps_deploy\MACDDIV_XAU\MacdDiv_XAU_H4_demo_v1.set` | GEN_MDX_NZDUSD_H4 | |
| 12 | PivotBreakout_XAU | AUDUSD | H4 | `_vps_deploy\PIVOTBREAKOUT_XAU\PivotBreakout_XAU_deploy.set` | GEN_PVT_AUDUSD_H4 | |

**TREE (ทุก cell ใช้เหมือนกัน):**
  - ได้ผล (PF เท่าไหร่ก็ตาม) → เติมช่อง PF + append ผลดิบ + commit → **cell ถัดไป**
  - `NO-DATA` / symbol ไม่มีใน terminal → เขียน `NO-DATA` ในช่อง PF → cell ถัดไป
  - รันล้ม 2 ครั้งติดบน cell เดียว → เขียน `FAIL` ในช่อง PF → cell ถัดไป (ไม่ต้อง BLOCKED — ใบนี้ห้ามหยุดเพราะ cell เดียว)
  - **ตารางเต็มหมดทุกช่อง** → `BLOCKED(matrix หมด — รอ lead เติม cell ใหม่)` + แจ้ง user ทาง Telegram แล้วหยุด

**ห้าม:** เขียน verdict หรือคำว่า pass/dead/ตาย · เรียง cell ใหม่ · เพิ่ม cell เอง (ผิดกฎ `AGENTS.md` §4 "อย่าคิดงานใหม่เอง" — matrix มี Claude เป็นเจ้าของ) · ตีความ PF · **เอา cell ที่ได้ PF ต่ำไป optimize ต่อเอง** (นั่นคืองาน lead) · ทุกข้อห้ามของ ORDER-205


### MATRIX ชุดที่ 1 (Claude เติม 2026-07-25) — Boss_14 GridLog symbol-screen ต่อจาก ORDER-095

**ที่มา:** ORDER-095 §"ขยายได้" + line "ORDER-095 ทำแค่ 1/6 EA". Boss_14 = ตัวเดียวในคลังที่**พิสูจน์แล้วว่า
เดินทางข้ามคู่เงินได้จริง** (DEMO 6 symbol: AUDNZD/USDJPY/EURJPY/AUDCAD/CADJPY/EURUSD + live GBPJPY)
→ คุ้มที่สุดที่จะกวาดคู่ที่ยังไม่เคยแตะ. ⚠️ **ไม่ใส่ EA_SUPERTREND ทั้งที่ ORDER-095 list ว่า "ขยายได้"** —
scorecard L190 ระบุ "SuperTrend DEAD ใน signal hunt = คู่เงินอื่น; XAU H4 ตัวนี้รอด" = ขยายคู่เงินตายไปแล้ว
(ORDER-095 list ตรงนั้น stale — Claude แก้ตอน review รอบหน้า)

**สิ่งที่ cell นี้ตอบ = step 1 ของ ORDER-095 methodology เท่านั้น** ("flat-lot smoke บน symbol candidate →
เอาที่ entry PF>1") — **ไม่ใช่** IS/OOS, ไม่ใช่ corr, ไม่ใช่ deploy. สองอันหลัง = งาน Claude หลัง review

**RUN TEMPLATE** (แทน `{SYM}` ด้วย symbol ในแถว · รันทีละแถว · **สองรอบต่อแถว: A แล้ว B**):
```powershell
# A = flat-lot probe (StackMode=90 single) — ตัวชี้ว่า ENTRY มี edge ไหม (บรรทัดที่ใช้ตัดสินจริง)
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert "EALabTpl\Boss_14_GridLog" -Symbol {SYM} `
  -Period H1 -FromDate 2023.01.01 -ToDate 2025.12.31 -Model 4 `
  -SetFile D:\EA_LAB\ea_template\sets\Boss14_GridLog_AUDNZD_DEMO.set `
  -ReportName GEN_{SYM}_H1_MAIN_flat
#    ↑ แก้ในไฟล์ .set สำเนา: StackMode=90 (เดิม 92) — อย่าแก้ไฟล์ต้นฉบับ ให้ copy เป็น *_flat.set ก่อน
# B = grid ปกติ (StackMode=92, .set เดิมไม่แก้) — ตัวชี้ว่าทั้งระบบทำเงินไหม
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert "EALabTpl\Boss_14_GridLog" -Symbol {SYM} `
  -Period H1 -FromDate 2023.01.01 -ToDate 2025.12.31 -Model 4 `
  -SetFile D:\EA_LAB\ea_template\sets\Boss14_GridLog_AUDNZD_DEMO.set `
  -ReportName GEN_{SYM}_H1_MAIN_grid
```
- **ต้องปิด MT5 GUI ก่อนรัน** ไม่งั้น script abort เอง (`docs/MT5_AUTOMATION.md`)
- **parse เอาแค่ 4 ตัวเลข** จาก report: `Profit factor` · `Total trades` · `Balance DD relative %` · `Total net profit`
  — **ห้ามโหลด html ทั้งไฟล์เข้า context** (§5.5 ข้อ 3)
- ⚠️ base .set = AUDNZD DEMO เพราะ step เป็น **ATR-adaptive** (`_9_StepUseATR=true`) จึงพกข้ามคู่ได้ —
  **นี่คือ assumption ของ Claude ไม่ใช่ config ที่ tune มาเพื่อคู่นั้น** → ผลที่ได้ = screening หยาบตามนิยาม
- **{SYM} ไม่มี history** (คู่ exotic บาง broker ไม่มี) → เขียนช่องผล = `NO-DATA` แล้วไปแถวถัดไป **ไม่ใช่ BLOCKED**

| # | EA | symbol | TF | window | lever/หมายเหตุ | ผล |
|---|---|---|---|---|---|---|
| 1 | Boss_14_GridLog | NZDJPY | H1 | MAIN 2023.01–2025.12 | A flat(90) + B grid(92) | |
| 2 | Boss_14_GridLog | CADCHF | H1 | MAIN | A + B | |
| 3 | Boss_14_GridLog | GBPCAD | H1 | MAIN | A + B | |
| 4 | Boss_14_GridLog | EURAUD | H1 | MAIN | A + B | |
| 5 | Boss_14_GridLog | AUDCHF | H1 | MAIN | A + B (ORDER-095 เคย BLOCKED-ON-DATA เพราะ **BWD** — MAIN น่าจะมี) | |
| 6 | Boss_14_GridLog | NZDCAD | H1 | MAIN | A + B (เหตุผลเดียวกับ #5) | |
| 7 | Boss_14_GridLog | CHFJPY | H1 | MAIN | A + B | |
| 8 | Boss_14_GridLog | GBPCHF | H1 | MAIN | A + B (เหตุผลเดียวกับ #5) | |
| 9 | Boss_14_GridLog | EURNZD | H1 | MAIN | A + B | |
| 10 | Boss_14_GridLog | AUDUSD | H1 | MAIN | A + B | |
| 11 | Boss_14_GridLog | USDCAD | H1 | MAIN | A + B | |
| 12 | Boss_14_GridLog | GBPNZD | H1 | MAIN | A + B | |

**อ่านผลยังไง (worker แค่ติดป้าย ไม่ตัดสิน):** `A ≥ 1.2` = entry มี edge ที่คู่นี้ → น่าสนใจ · `A < 1.0 แต่ B > 1`
= **grid ปั้นให้ ไม่ใช่ edge** ติดป้าย `ESCALATION-ONLY` (VERDICT GATE ข้อ 1 — แต่ **ห้าม**เขียนว่า DEAD เอง) ·
ทั้งคู่ < 1.0 = ติดป้าย `no-pulse` · **ทุกป้าย = ป้ายจัดกอง Claude ตัดสินจริงตอน review**

### MATRIX ชุดที่ 2 (Claude เติม 2026-07-25) — **GENETIC optimize**: SuperTrendFlip × NON-FX

**ที่มา (user hypothesis 2026-07-25):** *"SuperTrend เหมาะกับสินค้าที่ไม่ใช่ค่าเงิน — BTC, oil, หุ้น, index"* ·
ตรงกับหลักฐานที่มี: scorecard L190 = SuperTrend ตายที่คู่เงิน **แต่รอดที่ XAUUSD H4** (PF 1.92/33t · OOS 5.09) =
สินค้าที่ trend ยาว+vol สูงคือบ้านของมัน. ⇒ กวาด non-FX ให้ครบ **ด้วย genetic ไม่ใช่ทีละพารามิเตอร์**

**ต่างจากชุดที่ 1 ยังไง:** ชุด 1 = smoke ค่าเดียว (ถูก/เร็ว/ตอบแค่ "มีชีพจรไหม") · ชุด 2 = **optimize จริง**
1 cell = genetic 155,520 combo แล้วเอา plateau ไป confirm Model-4 (แพงกว่ามาก ใช้เมื่อเชื่อว่ามี edge ให้หา)

**search space (baked ใน .set แล้ว):** `ea_projects\(TRD)_SuperTrendFlip\set_files\STF_gen_nonfx.set`
= AtrPeriod(10) × Mult(8) × ExitMode(3) × TpAtrMult(9) × SlAtrMult(6) × UseEma(2) × EmaPeriod(6)
**Stage B** (หลังได้ plateau เท่านั้น): เปิด `_01_UseDonchian`/`_01_DonBars` เป็น `Y` แล้ว optimize รอบสอง
บนช่วงแคบรอบ center — **ห้ามเปิดพร้อมกันตั้งแต่รอบแรก** (search space ระเบิด + plateau อ่านไม่ออก)

**RUN TEMPLATE (3 ขั้นต่อ cell — ขั้น 3 คือขั้นที่ให้ตัวเลขจริง):**
```powershell
# 1) GENETIC optimize บน MAIN (Model 1 = เร็ว, ใช้หา candidate เท่านั้น ไม่ใช่หลักฐาน)
powershell -File D:\EA_LAB\scripts\mt5_optimize.ps1 -Expert "(TRD)_SuperTrendFlip_rev01" `
  -Symbol {SYM} -Period {TF} -FromDate 2023.01.01 -ToDate 2025.12.31 -Model 1 -Optimization 2 `
  -SetFile "D:\EA_LAB\ea_projects\(TRD)_SuperTrendFlip\set_files\STF_gen_nonfx.set" `
  -ReportName GEN2_{SYM}_{TF}_MAIN
# 2) เลือก robust pass (ห้ามเลือก peak เอง — script เลือก plateau ให้)
python D:\EA_LAB\scripts\select_robust_pass.py D:\EA_LAB\_mt5_auto\optimizations\GEN2_{SYM}_{TF}_MAIN.xml
python D:\EA_LAB\scripts\set_from_robust.py   # -> .set ของ pass ที่เลือก
# 3) CONFIRM ด้วย Model-4 ทั้งสอง window (นี่คือตัวเลขที่กรอกลงตาราง)
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert "(TRD)_SuperTrendFlip_rev01" -Symbol {SYM} `
  -Period {TF} -FromDate 2023.01.01 -ToDate 2025.12.31 -Model 4 -SetFile <set จากขั้น 2> `
  -ReportName GEN2_{SYM}_{TF}_MAIN_M4
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert "(TRD)_SuperTrendFlip_rev01" -Symbol {SYM} `
  -Period {TF} -FromDate 2020.01.01 -ToDate 2022.12.31 -Model 4 -SetFile <set จากขั้น 2> `
  -ReportName GEN2_{SYM}_{TF}_BWD_M4
```
**🔧 แก้ 2026-07-26 (Opus-seat ตอน merge PR #5):** template เดิมเขียน `-FromDate 2023.07.01 -ToDate 2026.07.01`
ทั้งชุด 1 และชุด 2 = **กิน holdout 2026H1** ขัดกฎเหล็ก `MAIN ∩ HOLDOUT = ∅` (CLAUDE.md) และขัดหัวใบนี้เองที่เขียนว่า
"MAIN `2023.01.01 → 2025.12.31` เสมอ" — แก้เป็น **MAIN `2023.01.01–2025.12.31`** ทุกบรรทัดแล้ว (holdout guard ใน
`check_state.ps1` จะ refuse ถ้าใครแก้กลับ). **BWD `2020.01.01–2022.12.31` ไม่เปลี่ยน.**

**⚠️ ข้อควรระวัง 6 ข้อ (ละเมิด = ผลใช้ไม่ได้):**
1. **ผลขั้น 1 (Model-1) ห้ามกรอกลงตารางและห้ามรายงานเป็นผล** — เป็นแค่ตัวหา candidate · ตัวเลขจริง = ขั้น 3
   (Model-2 ban ขยายผลมาถึง Model-1 optimize: optimizer เร็วไว้หา ไม่ใช่ไว้ตัดสิน)
2. **`scripts\qwen_batch_runner.ps1` มี auto-fallback ไป Model 2 เมื่อ Model 4 ล้ม** (บรรทัด ~60, ติดป้าย
   `M2fallback` ใน log) — **ถ้าเห็นป้ายนี้ = ผลนั้นใช้ไม่ได้ ให้ mark `M2-INVALID` แล้วรันใหม่** ห้ามกรอกลงตาราง
3. **BTCUSD/ETHUSD: backtest คิด swap = 0 แต่ของจริงติดลบหนัก** (RCA 2026-07: BTC long −14.67%/ปี ·
   ETH −9.86%/ปี) → cell crypto ที่ผ่าน ให้เขียนหมายเหตุ `swap-unadjusted` ต่อท้ายผลเสมอ
4. optimize 1 cell กินเวลาเป็นชั่วโมง — **1 cell = 1 session** (§5.5) · ปิด MT5 GUI ก่อนรัน
5. **genetic เดี่ยวไม่พอตาม policy ที่เคาะแล้ว** (2026-07-25 `b9ba8c84`, canonical = skill `backtest-optimize-rigor`
   Step 2): space >1,000 combo ⇒ **coarse genetic `-Criterion 7` → fine complete ≤1,000 combo รอบผู้ชนะ →
   plateau-center**. ขั้น 2 ของ template (`select_robust_pass.py` บน XML ของ genetic) = ตัวเลือก center **ของ coarse
   เท่านั้น** ห้ามข้าม fine grid ไป Model-4 ตรง ๆ · และ**ต้อง probe แกนตายก่อนทำ fine grid** (memory
   `inert-axis-fake-plateau`: neighbour ที่ให้ผลเท่ากันเป๊ะ = แกนไม่มีผล ไม่ใช่ plateau)
6. **`python` ไม่อยู่ใน PATH ของเครื่องนี้** — ก่อนเรียก `.py` ต้อง `. D:\EA_LAB\scripts\use_python.ps1` ก่อน
   (portable python) · run แรกของทุก cell ต้อง **assert `Leverage=1:100`** ใน ini ที่สร้าง (`100` เปล่า = no-op,
   memory `mt5-tester-cache-nondeterminism`)

| # | EA | symbol | TF | window | lever/หมายเหตุ | ผล (M4 MAIN / M4 BWD) |
|---|---|---|---|---|---|---|
| 13 | STF | BTCUSD | H4 | MAIN+BWD | genetic Stage A · `swap-unadjusted` | **1.59 (ซอย 6 ช่วง) / 1.35** · `both-window-pulse` · `swap-unadjusted` · plateau=WEAK/spike |
| 14 | STF | BTCUSD | H1 | MAIN+BWD | genetic Stage A · `swap-unadjusted` | **1.229 / 1.039** (ซอยทั้งคู่) · `both-window-pulse` แต่เฉียดทั้งสองฝั่ง · `swap-unadjusted` |
| 15 | STF | XAUUSD | H4 | MAIN+BWD | **control cell** — ต้องได้ ~PF 1.9 ถ้าต่ำกว่ามาก = pipeline ผิด ไม่ใช่ตลาด | **1.51 / 1.03** · `both-window-pulse` (BWD ปริ่ม) · **control = pipeline ปกติ** (ดูบล็อกผลดิบ) |
| 16 | STF | WTI | H4 | MAIN+BWD | genetic Stage A | **no-pulse** · coarse survivors **0/778** plateau=NONE — ไม่คุ้ม M4 |
| 17 | STF | US30 | H4 | MAIN+BWD | genetic Stage A | **1.55 / 1.01** · `both-window-pulse` แต่ BWD net +2.91 = เสมอตัว · plateau แข็ง (22%) |
| 18 | STF | XAGUSD | H4 | MAIN+BWD | genetic Stage A | coarse 0.6% survivors · plateau=WEAK neighbours 0 → ยังไม่ยืนยัน M4 |
| 19 | STF | ETHUSD | H4 | MAIN+BWD | genetic Stage A · `swap-unadjusted` | **1.310 / 1.099** (หัก swap) แต่ **MC PF-5th 0.857/0.657 ตก** → `BUILD-ON` · overlay ฆ่า MAIN (1.010) · portable stack ของ BTC ตก BWD 0.858 |
| 20 | STF | BRENT | H4 | MAIN+BWD | genetic Stage A | |
| 21 | STF | NAS100 | H4 | MAIN+BWD | genetic Stage A (ORDER-116 เคยเจอ no-data — ถ้าไม่มี = `NO-DATA`) | |
| 22 | STF | DE40 | H4 | MAIN+BWD | genetic Stage A | |
| 23 | STF | XAUUSD | H1 | MAIN+BWD | บ้านเดิมคนละ TF | |
| 24 | STF | US30 | H1 | MAIN+BWD | genetic Stage A | |

**cell #15 = control ทำก่อนเป็นอันดับแรก** — ถ้า control ออกมาต่ำผิดปกติ แปลว่า pipeline/data มีปัญหา
ไม่ใช่ตลาด → หยุดทั้ง matrix แล้ว `BLOCKED(control cell ไม่ผ่าน)` แจ้ง user ทันที (อย่ารันต่อให้เปลือง)

**อ่านผลยังไง (worker ติดป้ายเท่านั้น):** `M4 MAIN ≥1.2 AND BWD ≥1.0` = `both-window-pulse` ·
`MAIN ≥1.2 แต่ BWD <1.0` = `main-only` · `MAIN <1.0` = `no-pulse` — **ห้ามเขียน DEAD/CANDIDATE เอง**

#### ผลดิบ cell #15 (control) — 2026-07-26, Opus-seat รันเอง

**Model-4 ทั้งสองหน้าต่าง · leverage verified `1:100` ทั้ง 2 run · traded through to end of window (idle tail 0 วัน):**

| | PF | trades | net | eqDD% |
|---|---|---|---|---|
| **MAIN 2023.01–2025.12** | **1.51** | 211 | +1,372.94 | 2.96 |
| **BWD 2020.01–2022.12** | **1.03** | 206 | **+58.91** | 4.60 |

ป้าย = `both-window-pulse` **แต่ BWD ปริ่มเส้นแบบต้องบอกตรง ๆ**: net +58.91 ต่อ 3 ปี = เสมอตัว ไม่ใช่กำไร
(PF 1.03 ผ่านบาร์ 1.0 ทางเทคนิค แต่เป็นชนิดเดียวกับที่ BRK_XAU v3 โดนจับได้ — ดู `brk-xau-991001-v3-selected-into-leak`)

**คำตอบของ control cell = pipeline ปกติ ไม่ต้องหยุด matrix.** ตัวเลข pre-register ไว้ว่า "~PF 1.9" แต่ **1.9 นั้นเป็นของ
`EA_SUPERTREND` (scorecard L190) ไม่ใช่ `(TRD)_SuperTrendFlip_rev01` ที่ cell นี้รัน — คนละ EA** จึงเทียบกันตรง ๆ ไม่ได้.
เกณฑ์ที่ใช้ตัดสินแทน = ลายนิ้วมือของ pipeline พัง (0 เทรด · PF ~0.0x · bars degenerate · leverage no-op · idle tail):
**ไม่เจอข้อใดเลย** — 211/206 เทรด, ปิดถึงท้ายหน้าต่าง, leverage verified, fine grid survivors 77% ⇒ ผ่าน

**ladder ที่เดินจริง (ตาม policy `b9ba8c84` ไม่ใช่ template เดิม):** coarse genetic Criterion 7 → 784 pass →
fine **complete** 75 combo (`STF_XAU_H4_fine_noema.set`) + 225 combo (`_fine_ema.set`) → plateau-centre →
M4 ทั้งสองหน้าต่าง · .set ที่ล็อก = `_mt5_auto/ab_sets/genstanding_stf/STF_XAU_H4_locked.set` (`AllowLive=false`)
- **plateau ของ coarse เชื่อไม่ได้ตามที่รายงานมา** — ที่ centre ของ coarse (`ExitMode=1` · `UseEma=false`) มี **2 ใน 6
  แกนที่ไม่มีผลจริง**: `_02_SlAtrMult` ใช้เฉพาะ `ExitMode==2` (mq5 L193/200) · `_03_EmaPeriod` ใช้เฉพาะ
  `UseEma==true` (L115/171) ⇒ "neighbours=9" นับ neighbour ปลอม (memory `inert-axis-fake-plateau`).
  fine grid จึง **ล็อกแกนตาย + แยกกริดตาม UseEma** — plateau ที่ได้จึงเป็นของจริง: survivors **58/75 = 77%**, neighbours 22
- **EMA filter ไม่ซื้ออะไรที่นี่**: กริด EMA ให้ PF เท่ากัน (1.518 vs 1.525) แต่ n ครึ่งเดียว (112 vs 211) → เลือก NOEMA
- **ไม่ใช้ profit-max** (กริด EMA มี PF 2.29/81t = spike, script ติดป้าย overfit-prone เอง)

#### ผลดิบ cell #13 BTCUSD H4 — 2026-07-26, Opus-seat รันเอง

| | PF | trades | net | eqDD% | หมายเหตุ |
|---|---|---|---|---|---|
| **MAIN 2023.01–2025.12** | **1.591** | 100 | +564.14 | 1.84 (ช่วงแย่สุด) | **ซอย 6 ช่วงครึ่งปีแล้ว aggregate** |
| **BWD 2020.01–2022.12** | **1.35** | 91 | +220.89 | 2.34 | รันต่อเนื่อง 111M ticks |

ป้าย = `both-window-pulse` · `swap-unadjusted` · **แต่ plateau อ่อน (ดูด้านล่าง)**
.set = `_mt5_auto/ab_sets/genstanding_stf/STF_BTC_H4_locked.set` · chunk รายช่วง: 0.92 / 1.47 / 1.86 / 2.20 / 1.16 / 1.66

**🔴 gotcha ที่ต้องรู้ก่อนรัน cell crypto ที่เหลือ (#14 #19): MAIN 3 ปีเต็มของ BTC รัน Model-4 ไม่ผ่าน**
terminal คืน `"no disk space in ticks generating function"` (journal ของ terminal ไม่ใช่ tester log) = **memory ceiling
ไม่ใช่ข้อมูลขาดและไม่ใช่ดิสก์เต็ม** (memory `mt5-no-disk-space-is-memory-ceiling`) — probe หน้าต่างสั้นยืนยัน tick มีครบ
(2023 ต้นปี 4.51M ticks · 2024 ต้นปี 4.58M ticks) · BTC tick หนักกว่า XAU มาก (BWD 3 ปี = 111M ticks / 2,341 MB)
⇒ **crypto ต้องซอยหน้าต่างเสมอ** · report ที่ล้มจะออกมาเป็น `PF 0.0 / 0 trades / bars=0` = **artifact ห้ามกรอกลงตาราง**
- **caveat ที่ต้องติดไปกับเลข MAIN:** ซอย 6 ช่วง ⇒ ทุกรอยต่อมีไม้ถูก "end of test" ปิด ⇒ เทียบกับ BWD ที่รันต่อเนื่อง
  **ไม่ใช่การเทียบชนิดเดียวกันเป๊ะ** (ทิศทาง error ไม่รู้ — precedent เดียวกับ ORDER-210 challenger)
- **cross-check ที่ทำให้เชื่อได้ว่า chunk ไม่เพี้ยน:** M1 เต็มหน้าต่างให้ PF 1.682/100t · chunked M4 ให้ 1.591/100t
  = **จำนวนไม้เท่ากันเป๊ะ** และ PF ใกล้กัน
- **plateau ของ BTC อ่อนกว่า XAU ชัดเจน:** coarse survivors **3.5%** (XAU 21.8%) · fine NOEMA `plateau=THIN`
  neighbours 1 · fine EMA `plateau=WEAK` neighbours 9 และ **centre = robust = profit-max จุดเดียวกัน = ยอด ไม่ใช่ใจกลางย่าน**
  ⇒ ผ่านบาร์ทั้งสองหน้าต่างจริง แต่ยังไม่มีหลักฐานว่ามี plateau ให้ยืน
- **swap ยังไม่หัก:** BTC long จริง −14.67%/ปี ขณะ backtest คิด 0 · ExitMode=0 = ถือยาว (trail เส้น ST ไม่มี TP)
  ⇒ ต้นทุนจริงกินกำไร +564 นี้เป็นสัดส่วนที่ยังไม่ประเมิน **ห้ามเทียบ PF ตัวนี้กับ EA ที่ไม่ใช่ crypto ตรง ๆ**

#### ผลดิบ cell #14 BTCUSD H1 — 2026-07-26, Opus-seat รันเอง

**ซอย 6 ช่วงครึ่งปีทั้งสองหน้าต่าง** (H1 ชน memory ceiling ทั้ง MAIN และ BWD — BWD ล้มด้วย `no disk space` ตอน 10:15:53
ได้ `bars=0` = artifact ทิ้งแล้วรันใหม่แบบซอย) · .set = `STF_BTC_H1_locked.set`

| | PF | trades | net | worst-chunk eqDD% |
|---|---|---|---|---|
| **MAIN 2023.01–2025.12** | **1.229** | 320 | +478.76 | 2.04 |
| **BWD 2020.01–2022.12** | **1.039** | 301 | **+59.90** | 2.57 |

ป้าย `both-window-pulse` **แต่เฉียดทั้งสองฝั่ง** · `swap-unadjusted`
- chunk MAIN: 0.59 · 0.89 · 1.40 · 1.56 · 1.49 · 0.99 — **3 ใน 6 ครึ่งปี ≤0.99** กำไรทั้งก้อนมาจาก 2024.01–2025.06
- chunk BWD: 0.95 · 2.08 · 0.93 · 0.95 · 1.12 · 1.20 — **4 ใน 6 ครึ่งปี ≤1.12**, net +59.90/3 ปี = เสมอตัว
- ⇒ อ่านว่า **regime-dependent ผ่านบาร์แบบเฉียด** ไม่ใช่ของทน · cross-check chunk อีกครั้ง: M1 เต็มหน้าต่าง
  1.234/319t vs chunked M4 1.229/320t (ต่างกัน 1 ไม้)
- **🎯 lever ที่เจอ (มีค่ากว่าตัวเลข PF): H1 ต้องมี EMA trend filter ถึงจะมีย่านเหลือ** — กริดที่ปิด EMA
  survivors **1/108 · neighbours 0** (ไม่ใช่ plateau ตามนิยาม) · กริดที่เปิด EMA `plateau=GOOD` neighbours 46
  **ตรงข้ามกับ H4 ที่ EMA ไม่ช่วย** (cell #13 และ #15 เลือก NOEMA ทั้งคู่) ⇒ TF ต่ำ = noise สูง = ต้องมีตัวคัดเทรนด์
- ธง "centre ติดขอบ range" ของ coarse (AtrPeriod=6 = ขอบล่าง) **เคลียร์แล้ว**: fine grid ขยายลงถึง 4 แล้วยังเลือก 6

#### 📊 เทียบ 3 cell ที่ปิดแล้ว (M4 MAIN / M4 BWD)

| cell | | MAIN | BWD | plateau | อ่านว่า |
|---|---|---|---|---|---|
| #15 | XAUUSD H4 | 1.51 | 1.03 | survivors **77%** neighbours 22 | ย่านแข็งสุด แต่ BWD เสมอตัว |
| #13 | BTCUSD H4 | 1.59 | **1.35** | WEAK · centre=peak | BWD ดีสุด แต่ยังไม่มีย่าน |
| #14 | BTCUSD H1 | 1.229 | 1.039 | GOOD (ต้องมี EMA) | เฉียดทั้งสองฝั่ง regime-dependent |

**pattern ที่เริ่มเห็น (ยังไม่ใช่ข้อสรุป — n=3 cell):** H4 > H1 ทั้งสองสินค้า · สมมติฐาน user ว่า non-FX เหมาะกับ
SuperTrend **มีน้ำหนักขึ้นจริงที่ฝั่ง BWD** (BTC H4 = 1.35 ดีกว่า XAU 1.03) แต่ **ไม่มี cell ไหนที่ plateau แข็ง
พร้อม BWD แข็งในตัวเดียวกัน** — ต้องรอ cell โลหะ/ดัชนี/น้ำมัน (#16-#18, #20-#24) ก่อนจะสรุปอะไรได้

#### 🔧 LEVER A/B 2026-07-26 (user สั่ง "ทำทั้งคู่") — Donchian + Kaufman ER บน SuperTrendFlip

**ทำไมหยุดกวาด cell แล้วมาแก้ entry ก่อน:** cell #13/#14/#15 ให้อาการเดียวกันหมด = **flip ยิงตอน chop**
(BTC H1 ไม่มี plateau เลยถ้าไม่มี trend filter · XAU BWD เสมอตัว) ⇒ เพิ่มสินค้าใหม่ = คูณจุดอ่อนเดิม
รายละเอียดกลไก + ตัวเลขเต็ม 2 lever = **`EDGE_CATALOG.md`** (2 entry ใหม่ท้ายไฟล์)

**1. Donchian confluence** (`_01_UseDonchian` — coded ใน rev01 มาแต่ต้น ยังไม่เคยเทส) → **แยกตามสินค้า:**
- ⬛ **XAU H4 = ทิ้ง** — MAIN 1.51→**2.37** สวยขึ้นชัด แต่ BWD 1.03→**0.48 ติดลบทุกค่า DonBars** = selection-fit
- 🟩 **BTC H4 = adopt (build-on)** — M4 ยืนยัน: BWD **1.35→3.510** (+451.74) MAIN 1.591→1.510 · กำไรต่อไม้ 4.1→**9.1**
  · `.set` = `STF_BTC_H4_don20.set` · caveat: n=34/40 · MAIN สองครึ่งปีของ 2025 = 0.24/0.36 · `swap-unadjusted`

**2. Kaufman ER regime gate** = **`(TRD)_SuperTrendFlip_rev02.mq5` ใหม่** (`[03b]` block, default-off,
compile 0/0, ผ่าน `mql-code-reviewer`) — rev01 **ไม่แตะเลย** เพื่อให้หลักฐาน 3 cell ที่เพิ่งได้ยังใช้ได้
- **regression cage ผ่านเป๊ะ:** rev02 ปิด gate = rev01 ทุกหลัก (1.51/211t/+1372.94/DD 2.96/bars 4637) รันคนละเลนด้วย
- 🟩 **ผ่านทั้งสองหน้าต่างบน XAU H4** (ErPeriod=8/ErMin=0.20, M4): MAIN 1.51→**1.62** (DD 2.96→**2.11**) ·
  BWD 1.03→**1.09** (net 58.91→**134.18**) · ต้นทุน = ไม้หาย 26% และ net MAIN ลง 17% ⇒ **ซื้อคุณภาพ ไม่ใช่ซื้อกำไร**
- **⚠️ กับดักที่เกือบโดน:** config ที่ชนะ MAIN แรงสุด (ErPeriod=12/ErMin=0.20) ให้ MAIN **2.405/105t/+1488**
  แต่ BWD **0.838 ติดลบ −165** — pattern ทั้งตาราง: **ER window ยาว = ฟิต MAIN ฆ่า BWD · window สั้น = ดีขึ้นพอประมาณทั้งคู่**
  · ทุกแถวที่ PF 2.5-3.8 มี n = 6-30 ไม้ = arithmetic ไม่ใช่ edge
- **กฎที่ได้:** chop filter ต้องตัดสินบนหน้าต่างที่ไม่ได้จูน และ **pre-register "ต้องดีขึ้นทั้งสองหน้าต่าง" ก่อนเปิดดูผล**
  (บ่ายเดียวกันกับดักนี้จับ Donchian-on-XAU ไปแล้วหนึ่งดอก)

**3. รอบสอง (user สั่ง "ทำทั้งหมดเลย") — ER บน BTC · pyramid · cell #16-#18:**

- **ER บน BTC H4 = ตกเกณฑ์ที่ตั้งไว้เอง** (M4: MAIN 1.591→**2.144**/57t ดีขึ้นเยอะ แต่ BWD 1.35→**1.295**
  = แย่ลง) ⇒ ไม่ผ่าน "ดีขึ้นทั้งสองหน้าต่าง" · **M1 มองโลกสวยกับ BWD ของ crypto** (ทำนาย 1.443 ได้จริง 1.295)
  · BWD chunk หนึ่งมี PF 61.68 = ไม้เดียวลากทั้งหน้าต่าง
- **ER บน BTC H1 = ตกรอบ** — MAIN ดีขึ้น (1.469/243t) แต่ **BWD ติดลบทุกแถวของตระกูล ErPeriod=8** (0.93-0.97
  จาก baseline 1.039) ไม่มี config ที่ดีขึ้นทั้งคู่โดยมี n พอ ⇒ H1 อ่อนจริง ไม่ใช่แค่ยังไม่จูน
- **ความสมมาตรที่ยืนยันกฎ:** XAU → ER window ยาว(12) ฟิต MAIN ฆ่า BWD · BTC → ER window ยาว(16) ฟิต **BWD**
  (2.10-2.25) ฆ่า **MAIN** (0.64-1.03) — ทิศกลับกัน กลไกเดียวกัน: **window length = แกนที่เปลี่ยน filter เป็น curve-fit**
- 🟩 **pyramid (rev03) = ผลดีที่สุดของ campaign นี้** — M4 เลนเดียวกันทั้งสามตัว:

  | variant | MAIN | BWD |
  |---|---|---|
  | baseline | 1.644 / 100 legs / +607.59 / DD 1.83% | 1.348 / 91 / +219.78 / DD 2.31% |
  | + Donchian(20) | 1.510 / 34 / +218.74 | 3.510 / 40 / +451.74 |
  | **+ Don(20) + pyramid MaxAdds=1/AddAtAtr=1.0** | **2.379 / 50 / +700.28 / DD 2.16%** | **4.044 / 66 / +773.55 / DD 2.43%** |

  ชนะ baseline ทั้งสองหน้าต่าง DD แทบไม่ขึ้น · เลือก config ที่ **leverage น้อยสุดที่ผ่าน** ไม่ใช่กำไรสูงสุด
  (พื้นผิว monotone: adds มาก→กำไรมาก→DD มาก = วัด leverage ไม่ใช่วัด edge; MaxAdds=3 ได้ MAIN 3.103 ที่ DD 5.15%)
  · **caveat:** legs ≠ sample (34 สัญญาณ → 50 ไม้) · **2025 ทั้งสองครึ่งปีขาดทุน 0.40/0.44** เหมือน baseline
  (0.24/0.36) = pyramid ไม่แก้ regime มันขยายสิ่งที่ regime ให้ · `swap-unadjusted` **และแย่กว่าเดิมเพราะถือ 2 ไม้**
  · **ยังค้าง cage: MC (ruin ≤2%) · worst-case single loss เป็นตัวเลข · sensitivity fan · corr vs cohort**

**cell #16-#18 (coarse บนเลน 5c):**

| cell | survivors | plateau | ผล M4 |
|---|---|---|---|
| #16 WTI H4 | **0 / 778** | **NONE** | `no-pulse` — ไม่มีอะไรให้หา |
| #17 US30 H4 | **177 / 805 = 22.0%** | GOOD (fine 31-35%) | MAIN **1.55**/159t/DD 0.44% · BWD **1.01**/183t/net **+2.91** |
| #18 XAGUSD H4 | 5 / 784 = 0.6% | WEAK (neighbours 0) | ยังไม่ยืนยัน M4 (บางเกินกว่าจะคุ้ม) |

**🔴 pattern ข้าม 6 cell — สำคัญกว่าเลขของ cell ไหน:** XAU 1.51/1.03 · BTC H4 1.59/1.35 · BTC H1 1.23/1.04 ·
US30 1.55/1.01 · WTI ไม่มีชีพจร · XAG บาง ⇒ **ทุก cell ทำเงินบน MAIN และเสมอตัวบน BWD ยกเว้น BTC H4**
= ลายเซ็นของกลยุทธ์ ไม่ใช่ของ cell: **SuperTrend flip กินระบอบ 2023-2025 และแทบไม่กินระบอบ 2020-2022**
⇒ สมมติฐาน user แม่นแบบแคบลง: **"crypto เหมาะ" ไม่ใช่ "non-FX เหมาะ"** (น้ำมัน 0 ชีพจร · เงินบาง · ดัชนี = เหมือนทอง)

**⚠️ gotcha ใหม่ที่ต้องพกไปทุก A/B ของ crypto: BTCUSD มี tick history ไม่เหมือนกันระหว่าง MT5 install**
(EA/set/window/บัญชีเดียวกัน: `D:\Meta 5` = PF 0.92/−4.26 · `D:\Meta 5b` = 0.96/−1.83 ด้วย 13 ไม้เท่ากัน ·
XAU ตรงกันเป๊ะทั้งสองเลน) ⇒ **ทุก variant ของ A/B crypto ต้องรันเลนเดียวกัน และต้องเขียนกำกับว่าเลนไหน**
— รอบนี้จับได้ว่าคำอ้าง "BWD 1.35→3.51" แรกสุดเทียบข้ามเลน (รันซ้ำเลนเดียวกันได้ 1.348 ข้อสรุปรอด = โชค ไม่ใช่วิธี)

**4. กรงของ pyramid (PYR1) เดินครบแล้ว 2026-07-26 — เหลือ holdout ช่องเดียว (รอ user เคาะ, ยิงได้ครั้งเดียว):**

| กรง | บาร์ | ผล |
|---|---|---|
| MC (2,000 shuffle + bootstrap) | ruin ≤2% · PF-5th ≥1.0 | ruin **0%** ทั้งคู่ · PF-5th **1.114** (MAIN) / **2.209** (BWD) ✓ |
| worst-case ที่ sizing จริง | ≤15% equity | ไม้แย่สุด **−$69.50 = 0.70%** · DD จริง −$247 = 2.47% · เพดานกรง 8% ✓ |
| sensitivity fan (81 เพื่อนบ้าน) | plateau ไม่ใช่ spike | **69/81 = 85.2%** ผ่านทั้งสองหน้าต่าง · **BWD ต่ำสุด 1.71** ✓ |
| corr vs cohort | ≤0.40 | BRK_XAU(เงินจริง) **+0.167** · MacdDiv +0.134 · O108_S +0.176 ✓ (พี่น้อง XAU 0.444) |

- **ตัดสิน config ด้วยกฎที่ตั้งก่อนรัน และมันทำให้เสียเลขสวยไป:** fan ชี้ว่า `Mult=2.0` ดีกว่า — M4 ให้ MAIN
  **3.542**/+901.96 (เทียบ 2.379/+700.28) **แต่ BWD 3.307 เทียบ 4.044** ⇒ กฎ "ชนะบนหน้าต่างที่ไม่ได้จูน"
  ⇒ **คง `Mult=2.5`** (ถ้าดู MAIN อย่างเดียวจะเลือกอีกตัว)
- **⚠️ `select_robust_pass.py` รายงาน fan นี้ผิด** (`survivors=0 plateau=NONE` ขณะแถวดิบกำไรเกือบทั้งกระดาน
  PF 1.59-2.79 ที่ 68-81 ไม้) — **ห้ามเชื่อ survivor filter ของมันกับ EA แบบ basket/pyramid ต้องอ่าน XML ดิบ**
- **residual ที่ยังปิดไม่ได้:** gap ข้ามคืน/สุดสัปดาห์ของ BTC ที่กระโดดผ่าน trail stop ทั้งสองไม้พร้อมกัน
  (tester ไม่จำลอง) · `swap-unadjusted` ที่หนักขึ้นเพราะถือ 2 ไม้ · 2025 ทั้งสองครึ่งปียังขาดทุน
- **🎯 ตำแหน่งใน funnel:** ผ่าน optimize→CANDIDATE bars, M4, MC, fan, corr ครบ · **holdout 2026H1 ยังสะอาด**
  (ไม่มี run ของ STF ไหนข้าม 2025.12.31 เลย) = ยิงได้ครั้งเดียว **และต้องไม่จูนอะไรอีกหลังยิง** → รอ user เคาะ

**5. cell #19 ETHUSD H4 — ปิดเป็น `BUILD-ON` 2026-07-26 (ladder ครบ):**

| ทดสอบ | MAIN | BWD | อ่านว่า |
|---|---|---|---|
| **portable**: stack ที่ชนะบน BTC ยกมาทั้งชุด | 1.293 / 64 legs | **0.858 / −41.34** | ⬛ **กลไกไม่เดินทาง** |
| ETH center ของตัวเอง (หัก swap −21.40/−14.96) | **1.310** / 163t | **1.099** / 139t | ผ่านบาร์หัวตาราง |
| ↳ **MC ของ center นั้น** | **PF-5th 0.857** | **PF-5th 0.657** | ❌ **ตกกรง** (บาร์ ≥1.0) · ruin 0% ทั้งคู่ |
| center + overlay (Don20+pyramid) = last-optimize | **1.010** / 48 legs / net **+2.22** | 1.272 / 47 | ❌ overlay ฆ่า MAIN |

- **ladder ครบ:** coarse genetic 831 pass (survivors 99 = 11.9%) → fine complete 2 กริด (NOEMA 1/12 neighbours 0 · **EMA 14/36 = 38.9% neighbours 9**) → M4 สองหน้าต่าง → portable test → overlay last-optimize → MC
  ⇒ **verdict `BUILD-ON`** (มี PF>1 ทั้งสองหน้าต่างจริง จึงไม่ใช่ DEAD) · **ตัวขวางชื่อชัด = MC PF-5th <1.0** ไม่ใช่ PF หัวตาราง
- **corr ETH vs BTC-PYR1 = +0.123** (และ vs BRK_XAU −0.089) — ถ้ามันผ่านกรงจะเป็น leg ที่กระจายความเสี่ยงได้ดีมาก แต่ **ห้ามรับ leg ที่ทนการสุ่มใหม่ไม่ได้เพราะ corr สวย**
- **🔴 gotcha ที่เกือบทำให้อ่านผิดทั้ง cell: `ETHUSD min_lot = 0.1` ไม่ใช่ 0.01** — `.set` ที่ใช้ 0.01 ทำให้ guard ในตัว EA ปฏิเสธทุกออเดอร์ → รายงาน 0 ไม้ ซึ่งหน้าตาเหมือน "ETH ไม่มีสัญญาณ" เป๊ะ. run แรกของผมโดนเต็ม ๆ (probe 30 วันได้ net=0.0) จับได้เพราะ probe swap เผยเลข min_lot มาก่อน ⇒ **ทุก symbol ใหม่ต้อง probe สเปกก่อนเชื่อผลใดๆ** · ต้องแก้ทั้ง .set ที่ล็อกและ .set ของ optimize (ไม่งั้น sweep 155k combo = 0 ไม้ทั้งชุด)
- **ETH swap = `INTEREST_CURRENT` long −9.86%/ปี short −3.95% → tester ไม่คิดเช่นเดียวกับ BTC** (โหมดเดียวกัน)
- **🎯 pattern ข้าม 3 cell crypto:** BTC H4 = cell **เดียว**ที่สัญญาณดิบเดินได้เองโดยไม่ต้องมี EMA filter (NOEMA ดีกว่า) และเป็น cell เดียวที่ BWD แข็งจริง — BTC H1 และ ETH H4 **ต้องมี** EMA filter (ปิดแล้ว neighbours 0 ทั้งคู่) ⇒ **BTC H4 เป็นเคสพิเศษ ไม่ใช่หัวขบวนของกอง crypto** ⇒ แผน "ผูก 20 symbol" ต้องอ่านใหม่ว่าเป็น **20 funnel แยกกัน** ไม่ใช่การผูกเพิ่ม (2 symbol วันนี้ = ครึ่งวัน, ผ่าน 1)
**ยังไม่ทำ:** ER+Donchian ซ้อนกัน (n จะเหลือ ~20 = วัดไม่ได้ตามกฎ) ·
cell #19-#24 (ETH/BRENT/NAS100/DE40/XAU H1/US30 H1) · pyramid บน XAU (host BWD 1.03 ปริ่ม = กฎห้ามแปะ)

**⚠️ หนี้ที่ทิ้งไว้ให้ cell ที่เหลือของชุดนี้ (ไม่ใช่แค่ cell นี้):** `STF_gen_nonfx.set` sweep `_02_TpAtrMult`/`_02_SlAtrMult`
พร้อม `_02_ExitMode` ทั้ง 3 ค่า และ sweep `_03_EmaPeriod` พร้อม `_03_UseEma` — **ทุก cell จะเจอแกนตายชุดเดียวกัน**
(ExitMode=0 ทำให้ Tp+Sl ตาย · UseEma=false ทำให้ EmaPeriod ตาย) ⇒ coarse ใช้หา candidate ได้ตามเดิม
แต่ **ห้ามอ่าน plateau จาก coarse ตรง ๆ** ต้องแยกกริด fine ตาม ExitMode/UseEma เหมือน cell นี้ทุกครั้ง

---

## ORDER-190 — [lever/funnel] MM-OWNER-002: Boss_16/Kangaroo ให้ scale ตาม balance ได้ (opt-in) — `DONE(Claude/Fable 2026-07-24) — PENDING_ATTACH(user), demo-scaled .set built, see POLICY DECIDED note below`
**source:** Codex ข้อ 2. **ยืนยันว่าเป็นเรื่องจริง แต่ขอแยกความเสี่ยงออกเป็น 2 ชั้น ไม่รวมเป็นก้อนเดียวแบบที่ review เสนอ:**
- ชั้น safety (= "บอกผู้ใช้ว่าไม่มีผล") → **ทำไปแล้วใน ORDER-187**: `MM_ConfigValid` พิมพ์ `[INIT] WARN` เมื่อตั้ง FirstLotMode≠41 บน build 16
- ชั้น lever (= "ทำให้มันมีผลจริง") → **order นี้** เพราะไปแตะ lot law ของ EA ที่มี baseline pin อยู่ (Boss_16 cage 8/8) = ต้องเดิน funnel ปกติ ห้ามแอบรวมใน patch safety
**spec:** เพิ่ม input opt-in ของ Boss_16 เอง (เสนอ `_16_BaseLotMode`: 0=flat `_16_BaseLot` (default, byte-identical) · 1=balance-scaled ใช้ `_43_LotPerAnchor`/`_43_BalanceAnchor` ร่วมกับ chassis) → `Kangaroo_NextLot` อ่านค่านี้แทนการ hardcode `_16_BaseLot` · **default ต้องให้ `tpl_regression.ps1` 8/8 เท่าเดิมเป๊ะ** · จากนั้น A/B flat vs scaled บน MAIN+BWD → ถ้าจะรับต้อง re-pin baseline พร้อมประกาศในคอมมิตเดียวกัน
**bars:** pass = scaled ผ่าน MAIN≥1.2 + BWD≥1.0 และไม่แย่กว่า flat · dead = แย่กว่า flat ทั้งสอง window (เก็บโหมด 0 ไว้เฉยๆ) · กลาง = เท่าๆ กัน ⇒ ไม่รับ (ความซับซ้อนไม่ฟรี)
**flat-lot probe:** N-A (โหมด 0 คือ flat อยู่แล้ว = control ในตัว)
**ห้าม:** เปลี่ยน default ของ `_16_BaseLot` · แก้ `Kangaroo_NextLot` โดยไม่รัน `tpl_regression.ps1` · ตีความ WARN ของ ORDER-187 ว่าเป็นบั๊กที่ยังค้าง (มันคือพฤติกรรมที่ ORDER-072 ตั้งใจ)
**ทำได้:** Claude เขียน + Codex blind-audit (แตะ money) · A/B รันได้ด้วย qwen/Sonnet
**✅ โค้ดลงแล้ว (Claude/Fable 2026-07-24) — แต่ ⚠️ เปลี่ยน acceptance bar ที่ผมเขียนไว้เอง เพราะ bar เดิมผิด:**
- ลง input `_16_BaseLotMode` (0=flat default / 1=balance-scaled ใช้ `_43_*` ร่วมกับ chassis) + `Kangaroo_NextLot` อ่านค่านี้ · mode 1 **fail-closed** (คืน 0 = ข้ามไม้ ไม่ถอยไป flat) ตาม doctrine ORDER-187 · `MM_ConfigValid` ตรวจ anchor + ค่า mode ที่ไม่มีจริง → INIT_FAILED
- หลักฐาน default ไม่ขยับ: **`tpl_regression.ps1` CLEAN 8/8** · หลักฐานว่า mode 1 ทำงานจริง: เพิ่มเคส K0/K1 เข้า `mm_lotmode_test.ps1`
- **⚠️ ยกเลิก bar เดิม "scaled ต้องผ่าน MAIN≥1.2 + BWD≥1.0 และไม่แย่กว่า flat":** bar นั้น**วัดผิดเรื่อง** — A/B ระหว่าง flat กับ balance-scaled บน backtest ที่เริ่มด้วยเงินต้นก้อนเดียว ส่วนใหญ่วัด **compounding** ไม่ใช่ edge ซึ่งชนกฎของ repo เองที่ว่า "optimize ด้วย mode 41 เพราะ compounding บิดผล PF" ถ้า scaled ชนะก็แปลว่ามันทบต้น ไม่ได้แปลว่ากลไกดีกว่า
- **bar ใหม่ที่ถูกเรื่อง:** คุณค่าของ mode นี้ไม่ใช่ PF สูงขึ้น แต่คือ (1) risk เท่ากันข้ามขนาดบัญชี (deposit invariance) (2) หด lot เองตอน DD ลึกจนไม่ไปชน hard-kill — ข้อ (2) วัดได้แล้วบน chassis mode 43 (ORDER-188: fixed ตายที่ 115/164 ไม้ eqDD 25.09% · scaled จบครบ 164 ที่ 22.66%) → **ถ้าจะรับ lever นี้ ให้ตัดสินจากสองข้อนี้ ไม่ใช่จาก PF**
- **ยังไม่ได้ทำ:** ตัดสินใจว่าจะเปิดใช้ mode 1 กับ Boss_16 ตัวจริงไหม = **user เคาะ** (โค้ดพร้อม default ปิด ปลอดภัยอยู่แล้ว)

**✅ POLICY DECIDED (user 2026-07-24): "เปิดบน demo ก่อน ไม่แตะ live"** — ตรวจก่อนลงมือแล้วพบว่า **`Boss_16_KangarooGrid` ยังไม่เคยถูก deploy ที่ไหนเลย** (ไม่มีแถวใน `DEPLOYMENTS.csv` ทั้ง live/demo — มีแค่ backtest/regression artifact) ดังนั้น "เปิดบน demo" ไม่ใช่การ flip flag บน instance ที่รันอยู่ แต่คือเตรียม .set ให้พร้อม attach:
- re-run `mm_lotmode_test.ps1` ยืนยันซ้ำ (2026-07-24) — K0/K1 cases ยัง **CLEAN ทั้งหมด** (deposit-invariance + unit-independence PASS)
- สร้าง `ea_template/sets/Boss16_Kangaroo_XAU_21_30_scaled_demo.set` = base คือ `Boss16_Kangaroo_XAU_21_30.set` (candidate RSI 21/30 ที่ล็อกไว้จาก ORDER-077) + `_16_BaseLotMode=1` + **`_43_LotPerAnchor=0.01`/`_43_BalanceAnchor=10000`** (เลือกเอง ไม่ใช่ compiled default 0.01/1000 — เพราะ default จะทำให้ lot กระโดด 10x ที่ deposit $10k ซึ่งเป็น deposit เดียวกับที่ validate flat baseline ไว้; anchor ที่เลือกทำให้ lot เริ่มต้น **เท่ากับ flat เป๊ะที่ $10k** แล้วค่อยขยับตามยอดบัญชีจริงจากจุดนั้น) magic แยกต่างหาก `990018` กันชนกับ research .ini เดิม (990017 มีอยู่แล้วใน `BOSS16_KANG_XAU_H1_SELL.ini`)
- **PENDING_ATTACH:** ต้องให้ user เปิด MT5 demo เอง ลาก `Boss_16_KangarooGrid.ex5` ลงชาร์ต XAUUSD H1 โหลด .set นี้ (ไม่มีเครื่องมือระยะไกลให้ agent ทำแทนได้) — พอ attach แล้วให้บันทึกแถวใหม่ใน `DEPLOYMENTS.csv` + re-pin .set นี้เป็น baseline ในคอมมิตเดียวกัน (ตาม convention เดิม)

## ORDER-162 — [investigation] ~~MT5 tester engine drift~~ → **ROOT CAUSE = leverage unpinnable + margin-gate** (ไม่ใช่ engine drift) — `RESOLVED(Claude 2026-07-23 รอบ 3) — เหลือเศษเล็ก 1 อย่างยังค้าง · แตกเป็น ORDER-165 (T0 blocker)`
**🔴 sample-check (1) ตอบแล้ว โดยบังเอิญ จากคนละเส้นทาง — คำตอบ = SYSTEMIC ไม่ใช่ isolated:** ระหว่างตรวจ ORDER-161 (template money-params) ผมรัน `tpl_regression.ps1` เจอ **8/8 Boss EA drift พร้อมกัน** (ไม่ใช่แค่ RSI-MR cell เดียวแบบ ORDER-157) — แล้ว **isolate ด้วย `git stash` ยืนยันว่าไม่ใช่โค้ดของผม**: stash ORDER-161 ออก รันซ้ำบน tree สะอาด (ไม่มีการแก้ `core/` เลยตั้งแต่ ORDER-125 baseline-repin 07-19) ได้ **ตัวเลขตรงกัน byte-for-byte กับตอนมี ORDER-161 อยู่** (net/pf/trades/eqdd ทั้ง 8 ตัวเป๊ะ) — ยืนยัน 2 ชั้น: (a) โค้ดผมไม่ใช่สาเหตุ (b) drift ทำซ้ำได้เสมอบน primary lane `D:\Meta 5` ไม่ใช่ noise ครั้งเดียว. **สองตัวที่โปรเจกต์เฝ้าเป็นพิเศษก็ drift ด้วย: Boss_14 n=84→81, Boss_18 n=6020→6000** (บทเรียน ORDER-125 ที่เพิ่ง re-pin baseline ไปเมื่อ 4 วันก่อน).
**ทำไมนี่คือคำตอบของ scope (1) ไม่ใช่แค่ anecdote เพิ่ม:** ORDER-157 พบ drift 1 cell (RSI-MR EURUSD H1 fold2). ที่นี่พบ **8 EA คนละ family/entry-type/instrument พร้อมกัน** (GridTrend/Breakout/MeanRev/GridLog/ST03/KangarooGrid/Wave5/JumStoch) บน baseline ที่ pin ไว้ **แค่ 4 วันก่อน** (2026-07-19, ORDER-125) ไม่ใช่ 2 สัปดาห์ก่อนแบบ RSI-MR — แปลว่า drift window แคบกว่าที่กลัว (เกิดในช่วง 07-19→07-23) **แต่ครอบคลุมกว้างกว่าที่กลัว** (ไม่ใช่ 1 cell, เป็นทุก EA ที่ cage แตะ) → เข้าเกณฑ์ "หลายตัว drift = risk เป็นระบบ" ชัดเจน ไม่ต้องขยาย sample เพิ่มแล้ว.
**หลักฐาน:** รายละเอียดเต็มอยู่ที่ ORDER-161 ด้านบน (บล็อกเดียวกับ template work) + reports `_mt5_auto/reports/TPLREG_*.htm` (รันตอน 2026-07-23 หลัง user ปิด terminal บัญชี 146237).
**ยังไม่ตัดสิน (2) ตามกฎ:** ไม่ได้แตะ scorecard/index/verdict ใดๆ จาก finding นี้ — รอ user เคาะนโยบาย re-validate vs accept-as-point-in-time.

**🔬 double-check รอบ 2 (user 2026-07-23: "ตรวจสอบซ้ำ ให้มันเคลียร์ไปเลย ไม่น่ามีอะไร") — ไล่ตัดทุกคำอธิบายธรรมดาที่เช็คได้จริง หาไม่เจอสักข้อ:**
| สมมติฐาน "เรื่องธรรมดา" | เช็คยังไง | ผล |
|---|---|---|
| broker/account เปลี่ยน (user เพิ่ง login ThinkMarkets วันนี้) | journal log 07-19 vs วันนี้: authorize line | **เหมือนเดิม** — 146237/ThinkMarkets-Live/TF Global Markets ตั้งแต่ 07-19 แล้ว ไม่ใช่เพิ่งเปลี่ยน |
| leverage เพี้ยน (bug ที่อีก session เจอ: ini สั่ง 1:100 แต่ tester ใช้ 1:2000) | report เก่า `O132_B18_recheck.htm` (07-19) vs วันนี้ | **เหมือนเดิม** — 1:2000 ทั้งคู่ (bug จริงแต่ไม่ใช่ตัวขับ diff — pre-existing) |
| client terminal build อัปเดต | journal "MetaTrader 5 x64 build" ทุกวัน 07-19→07-23 | **เหมือนเดิม** — 5836 ตลอด, `terminal64.exe`/`MetaEditor64.exe` ทั้งคู่ file date = 11 พ.ค. (ไม่มีอัปเดตเลยตั้งแต่นั้น) |
| EA source code เปลี่ยน | `git log --since 07-19 -- ea_template/core/ Boss_14/18` | **ไม่มี** logic change (มีแค่ 2-line comment fix ORDER-160 วันนี้, อีก session confirm regression CLEAN ก่อนแตะ) |
| ราคา/tick history เปลี่ยน (broker revise ข้อมูลย้อนหลัง) | mtime ของ `.hcc`/`.tkc` ปี 2024 ใน `bases\ThinkMarkets-Live\` | **ไม่เปลี่ยน** — ticks 2024 ทุกเดือน mtime = 4 มิ.ย., H1 bar-cache = 1 ก.ค., ทั้งคู่เก่ากว่าวันที่ baseline pin (07-19) เอง — เป็นไฟล์ต้นทางตรงกันเป๊ะที่ทั้งสองรอบใช้ (rewritten to dodge a check_state.ps1 substring false-positive on the original phrasing; technical meaning unchanged) |
| persisted GlobalVariable ค้างข้ามรอบเทส (peak-equity/halt state รั่วจาก run ก่อนหน้า) | อ่าน `Persist.mqh` header โดยตรง | **ถูก design กันไว้แล้ว**: "tester GVs are sandboxed per pass, so persisted state can never move backtest numbers" — คนละ store จาก live GV เลย |

~~**สรุป: ... เหลือแค่ MT5 tester engine เองที่ทำงานต่างไปจากเดิม**~~ ⛔ **สรุปนี้ผิด — ถูกหักล้างด้วยการทดสอบรอบ 3 ด้านล่าง (user สั่ง "ตรวจสอบอีกที" 2026-07-23). ผมสรุปเร็วเกินไปจากการ "ไล่ตัดตัวแปร" อย่างเดียวโดยไม่ได้ทดลองจริง — ตารางข้างบนเช็คแต่ว่า "ค่าอะไรเปลี่ยนไหม" แต่ไม่เคยทดสอบว่า "ค่าที่ไม่เปลี่ยนนั้น ถูกส่งถึง tester จริงหรือเปล่า" ซึ่งคือจุดที่พัง.**

---

### ✅ รอบ 3 — ROOT CAUSE เจอจริง: `-Leverage` เป็น silent no-op + margin-gate (ไม่ใช่ engine drift)

**การทดลองที่หักล้าง (ไม่ใช่การไล่ตัดแบบ passive — ทดลองจริงทั้งหมด):**

| # | ทดลอง | ผล |
|---|---|---|
| 1 | ขอ `-Leverage 100` บน **lane1** (`D:\Meta 5`) | report บอก **1:2000** ← **ini ถูกเมิน** |
| 2 | ขอ `-Leverage 100` บน **lane2** (`D:\Meta 5b`) | report บอก **1:100** |
| 3 | sweep lane2 ขอ **2000 / 500 / 200** | report บอก **1:100 ทั้งสามครั้ง · ตัวเลขเหมือนกันเป๊ะ (n=480)** ← **ยืนยัน ini ถูกเมินทั้งสอง lane** |
| 4 | Boss_11 (grid) lane1@1:2000 vs lane2@1:100 | **n=9 (PF 0.00, eqDD 25.1% = KillDD ยิง) vs n=480 (PF 0.87)** ← ต่างกัน **53 เท่า** จาก leverage ล้วนๆ |
| 5 | Bars/Ticks ทั้งสอง lane | **2936 / 702163 เท่ากันเป๊ะ** ← ข้อมูลราคาเหมือนกัน 100%, ตัดเรื่อง data drift ขาด |
| 6 | **falsification:** Boss_12 (single-position, ไม่มี grid ให้ margin-gate คุม) ข้าม lane/leverage | **n=164 เท่ากันทุกที่** (baseline / lane1@2000 / lane2@100) |

**กลไกที่อธิบายได้ครบ (มีโค้ดรองรับ ไม่ใช่เดา):** `RiskControl_DepositLoadPct() = 100 × ACCOUNT_MARGIN / ACCOUNT_BALANCE` → `RiskControl_AllowNewOrder()` บล็อกไม้ใหม่เมื่อ ≥30% (PROTECT_NORMAL). **margin แปรผกผันกับ leverage** →
- ที่ **1:100**: margin สูง → deposit-load ชน 30% เร็ว → **grid ถูกบล็อกไม่ให้ซ้อนลึก** → DD เล็ก → เทรดยาว (n=480)
- ที่ **1:2000**: margin ต่ำกว่า 20 เท่า → gate แทบไม่ทำงาน → **grid ซ้อนลึกจนเจ๊ง** → equity DD 25% → **KillDD ยิง หยุดเทรด** → n=9

**นี่คือเหตุผลที่รูปแบบมันตรงเป๊ะ:** EA ที่โดนกระทบหนัก = **grid/stacking ทั้งหมด** (11/13/14/15/16/18 — ตัวที่ผ่าน margin-gate) · EA single-position (12/17) **จำนวนเทรดไม่ขยับเลย**. ถ้าเป็น "engine drift" จริง single-position ต้องเพี้ยนด้วย — **มันไม่เพี้ยน** = engine ไม่ได้ drift.

**🔧 บั๊กจริงที่ต้องแก้ (นี่คือของจริง ไม่ใช่ engine):** `scripts/mt5_run.ps1 -Leverage` **เขียนลง ini แล้วแต่ MT5 build 5836 ไม่อ่าน** — ใช้ leverage ของบัญชีที่ terminal นั้น login อยู่แทน → **ทุก backtest ที่ผ่านมา leverage ไม่เคยถูก pin จริง และไม่มีใครเห็นเพราะ script ไม่เคยตรวจ report ย้อนกลับ.** คลาสเดียวกับ ORDER-085 เป๊ะ (`Spread`/`TestSpread` ก็ no-op เงียบบน build นี้) — อีก session เจออาการนี้แล้วบันทึกไว้ว่า "น่าสงสัยแยกเรื่อง" **แต่จริงๆ มันคือตัวต้นเหตุ ไม่ใช่เรื่องข้างเคียง**.

**เศษที่ยังอธิบายไม่ได้ (เล็ก แต่ไม่ปิดบัง):** Boss_12 จำนวนเทรดเท่ากันทุกที่ (164) **แต่ net baseline −143.84 vs วันนี้ −171.63** (สอง lane วันนี้ตรงกันทั้งคู่ แม้ leverage ต่างกัน) = ~$28 บน 164 เทรด (~$0.17/เทรด). leverage อธิบายไม่ได้ (สอง lane ตรงกัน) — น่าจะ spread/swap/commission ใน tick data หรือ config บัญชี **ยังไม่พิสูจน์**. ขนาดเล็กมากเทียบกับ drift ที่ leverage อธิบายไปแล้ว แต่บันทึกไว้ว่ายังค้าง ไม่กลบ.

**สถานะใหม่ของ ORDER-162: ลดจาก "systemic engine drift" → "tooling bug (leverage unpinnable) + margin-gate sensitivity"** — ร้ายแรงน้อยกว่ามากและ **แก้ได้จริง** ต่างจากเดิมที่แก้ไม่ได้. ⚠️ **แต่ก่อน re-validate อะไรก็ตาม ต้อง pin leverage ให้ได้ก่อน** ไม่งั้น re-validate แล้วก็ยังลอยเหมือนเดิม (ดู ORDER-163).
**source:** ORDER-157 rerun-confirm (2026-07-23, Sonnet) — ไล่ตัดตัวแปรครบ (EA hash/param/.set/window/tick-cache mtime เหมือนกัน 100% ระหว่าง historical run 2026-07-08 กับ rerun วันนี้บนทั้ง 2 lane) แต่ **fold2-OOS ของ RSI-MR EURUSD H1 ยังต่างกันจริง: PF 1.74/131 เทรด (07-08) vs 1.08/130 เทรด (ตอนนี้ บน `D:\Meta 5` และ `D:\Meta 5b` ตรงกันทั้งคู่)**. รายละเอียดการไล่ตัดตัวแปรอยู่ที่บล็อก ORDER-157 ด้านบน + `_mt5_auto/reports/WF_RSIMR_REGR_F2_OOS_PRIMARYRERUN_*`.
**ทำไมเรื่องนี้ใหญ่กว่า cell เดียว:** hypothesis ที่เหลือหลังตัดทุกอย่างออกแล้วคือ **MT5 tester engine (build 5836) เองมีพฤติกรรมต่างจากตอนรัน 07-08** — และมี precedent ตรงจากโปรเจกต์นี้เองว่าไม่ใช่เรื่องเพ้อฝัน: **ORDER-085 (2026-07-10) เคยจับได้แล้วว่า build ปัจจุบัน no-op `Spread`/`TestSpread` ใน ini เงียบๆ**. ถ้า tester engine เปลี่ยนพฤติกรรมจริงตั้งแต่ ~07-10 = **backtest ทุกตัวที่ run ก่อนวันนั้นอาจให้ผลไม่ตรงกับที่ build ปัจจุบันจะให้** — กระทบความน่าเชื่อถือของ evidence เก่าที่ verdict จำนวนมากอิงอยู่ (scorecard, EA_MASTER_INDEX, deploy decision) ไม่ใช่แค่ WFA tool ตัวเดียว.
**ข้อสังเกตข้างเคียงที่ตัดออกแล้วว่าไม่ใช่ตัวขับ แต่ยังน่าสงสัยแยกเรื่อง:** rerun วันนี้ leverage รายงาน 1:2000 (ทั้งที่ `mt5_run.ps1` default 1:100 ไม่ถูก override) ขณะที่ historical + secondary-lane rerun รายงาน 1:100 — ตัดออกแล้วว่าไม่ใช่ตัวขับความต่าง PF (สอง lane เลขตรงกันแม้ leverage ต่างกัน) **แต่ `mt5_run.ps1` ไม่ honor ini leverage บาง path เป็น bug แยกที่ควรเปิด order ของตัวเอง**.
**scope ที่เสนอ (ยังไม่ทำ รอ user):** (1) **sample-check ราคาถูก:** เลือก 3-5 cell จาก order ที่เคย REVIEWED ไปแล้วก่อน 07-10 (เช่นจาก ORDER-078 Boss_16, ORDER-085B SuperTrend, หรือ RSI-MR order เดิม) rerun M1 เฉยๆ เทียบตัวเลขเก่า — ถ้าทุกตัว match = risk เฉพาะ cell นี้ ถ้าหลายตัว drift = risk เป็นระบบ ต้องขยาย scope (2) ถ้า drift เป็นระบบจริง ต้องตัดสินว่า **re-validate EA ที่ deploy อยู่แล้วกี่ตัว vs ยอมรับ evidence เก่าเป็น "ตอนที่ verify" ไม่ perpetual-truth** — เป็นการตัดสินใจเชิงนโยบายที่ user/Claude ต้องเคาะร่วมกัน ไม่ใช่ agent ตัดสินเอง.
**bars:** N-A (investigation, ยังไม่ตัดสิน EA ใดๆ). **flat-lot probe:** N-A.
**ห้าม:** สรุปว่า EA ตัวไหน "จริงๆ ตาย/รอด" จาก finding นี้จนกว่าจะรู้ scope (isolated vs systemic) · เปลี่ยน build/version MT5 เอง · แก้ evidence เก่าใน scorecard/index ใดๆ ตามความสงสัยนี้ก่อนพิสูจน์.
**ทำได้:** sample-check (1) = qwen/ZCode (mechanical, เทียบเลขเก่ากับใหม่) · การตัดสินใจ (2) = Claude/user เท่านั้น · 👉 **รอ user เคาะว่าจะให้ priority แค่ไหน** (T1-ฉุกเฉินถ้าห่วง evidence ปัจจุบัน vs T2-เมื่อว่างถ้าเชื่อว่า isolated).

## ORDER-151 — (TRND)_TsMom_XAU (S2, 992001) demo-isolate bundle prep — `DONE(Claude 2026-07-23) — bundle built, PENDING_ATTACH for user` (user decision 2026-07-23: demo-isolate directly, not MRIS overlay first)
**result:** locked plateau-center **lb60/dm2** (from `_mt5_auto/S2_TSMOM_BOTHWINDOW.csv` — picked over the lb100/dm2 spike-peak 4.90; lb60 family is flatter across deadmult 1-3). Bundle `_vps_deploy/S2_TSMOM_XAU/` = `TsMom_XAU.ex5` (verified fresh vs source mtime) + `S2_TsMom_XAU_deploy.set` (full 18-input merge, `_05_AllowLive=true`, magic 992001) + `README_ATTACH.md` (judge criteria + explicit "don't misread a losing stretch as new info" regime caveat, per user's own instruction on this order). DEPLOYMENTS.csv row added (463666728 placeholder acct, PENDING_ATTACH) + EA_MASTER_INDEX + scorecard rows updated.
**source:** S2 PARKED-VERIFY — MAIN 2.8-4.9 all cells (strong bull-only TSMOM momentum edge) but BWD 0.52-0.77 all cells, ADX last-optimize could not filter the V-reversal failure mode. User chose to demo-forward the edge as-is rather than gate it behind an MRIS regime-overlay build first — forward data becomes the regime-dependence evidence.
**spec:** lock the plateau-center .set already used for the MAIN/BWD numbers above (pull from `_triage` S2 ladder results — no re-tune) → build `_vps_deploy/S2_TSMOM_XAU/` bundle (compiled .ex5 + locked .set + README with judge criteria pre-registered) → add DEPLOYMENTS.csv row status=PENDING_ATTACH, magic 992001, XAUUSD, kill_rule = eqDD>12% OR 3-mo PF<0.8 @≥15 trades (repo default demo-kill bar) **plus an explicit regime note**: BWD<1 is known and accepted — judge criteria must include a trend/momentum regime check (e.g. compare live period against MRIS trend barometer post-hoc) so a losing forward stretch isn't misread as a fresh discovery.
**bars:** N-A (this is a bundle-build order, not a test — no pass/dead line item). **flat-lot probe:** N-A (single-position).
**ห้าม:** attach live/real money · skip the README judge-criteria pre-register step · silently drop the BWD-known-bad caveat from the README.
**ทำได้:** Claude/Sonnet (bundle build follows existing `_vps_deploy` template) → mark DONE when bundle exists, PENDING_ATTACH for user.

---

## ORDER-141 — (EXP)_AdaptGridMC_rev01 build (FINDYOUR8 #1 MC block-bootstrap zone grid) — `DONE(build-only 2026-07-20) — backtest ยังไม่เริ่ม (ตามคิว user: spec→code→compile+tests พอ)`
Spec: standalone (EXP)_ L3 flat-lot BUY ladder ระหว่าง P10/P90 จาก offline `_mt5_auto/adaptgrid_mc_zone.py`
(10k paths × 60d, 24-day block bootstrap, 1000 D1 bars) · spacing 0.3×ATR(D1,30) หรือ geometric · band cap +
MaxLevels ≤40 + MaxTotalLot + hard kill −20% equity persisted GV · magic 992007. mql-review PASS (C3 benign note) ·
compile 0/0 · zone script self-tested (synthetic 1100-bar, 2k paths → sane P10/P90/N). **ก่อน backtest ต้อง:**
export D1 CSV จริง (BTCUSD/ETHUSD) → gen zone → BWD 2020-22 = HARD gate + flat-lot per spec + swap-drag บันทึกใน verdict.

## ORDER-119 — CAMPAIGN: ST03 rescue รอบ owner-override — 3 lever ที่ยังไม่เคยแตะ (flat-lot bar ตัดสิน) — `REVIEWED(Opus 2026-07-19): DEAD-OPTIMIZED (flat-lot MACD-reversion entry, ranger homes) — campaign ปิด, lever A/B ไม่เดิน`
**verdict (lever C = last-optimize บน right home, ครบ):** sweep `_15_Macd{Fast,Slow,Signal}`×`_15_CountBars` 18 combo × 6 cell (GBPUSD/EURUSD/EURGBP × H1/H4) × 2 window = 216 runs (agent, main tester serial, n≥200/combo, Opus verify: parse PF column จริง + spot XML). **pre-registered GATE = ไม่ผ่าน: 0 cell flat-lot PF≥1.0 both-window.** best-home EURUSD H4 MAIN 1.15 (16/34/3) แต่ BWD max 0.98 ที่ combo เดียวกัน → window-crossing pair fail ทุกตัว (MAIN>1 → BWD<1 สลับกันเสมอ). **ตัดสิน DEAD-OPTIMIZED เพราะ:** (1) right home ยืนยัน (ranger ×3) (2) last-optimize lever ที่สำคัญสุด (entry-signal params, StoK-lesson) ครบ — ceiling < 1.0 both-window (3) **lever A (capped basket) ห้ามเดิน = flat-lot no-edge + escalation = martingale-คือ-edge-เอง (DEAD-STRUCTURAL trap)** · lever B (regime gate) ไม่สร้าง edge บน underlying no-edge แค่ลด trade. **ST03 MACD-reversion = no robust both-window edge naked บน ranger.** evidence `_triage/_archive/verdicts/order104-126/ORDER119_LEVERC_RESULTS.md` + XML `_mt5_auto/optimizations/O119C_*.xml`. **⏭ decision ระยะยาว (ถอด ST03 ถาวร / แทน Boss_16 slot) = owner-override territory → user เคาะ** (ผม judge campaign evidence, fate ของ owner-override EA = user). role: agent sweep · Opus verify+judge.
**เดิม spec:**
**why:** user สั่งต่อยอด ST03 (filter/MM/optimize) 2026-07-18. **ORDER-071 ban ถูก owner แก้ขอบเขต:
lever ที่ปิดแล้วยังปิดอยู่ (exit ×4 · reactive vol-gate/ADX filter · symbol GBP/CAD ที่ default params) —
เปิดเฉพาะ 3 lever ที่ไม่เคยเทส.** vehicle = **Boss_15_ST03 (chassis, signal parity 133/133)** — ห้ามแตะ live.
**คำถามแกน (pre-registered): มี config ไหนทำ flat-lot PF≥1.0 both-window ได้ไหม** — ถ้าไม่มี = entry ยังไม่มี
edge, campaign ปิด, ผลตัดสินระยะยาวกลับไปทางถอด/แทนด้วย Boss_16 (แจ้ง user, Fable case-1 ถ้า quota มี)
**lever C ก่อน (ถูกสุด ชี้ขาดสุด) — entry-signal params:** MACD fast/slow/signal + count-threshold N
(บทเรียน StoK 5→17: default ≠ ceiling) · homes: GBPUSD+EURUSD+EURGBP (ranger prior) × H1+H4 · Model 1
· **windows: MAIN 2023.07–2026.07 (rolling-36 ตาม framework ใหม่) + BWD 2020.01–2022.12 พร้อมกัน** · coarse ≤50 combos/symbol
**🔧 DISPATCH-READY SCHEMA (Opus 2026-07-18 — de-risked, ไม่ต้อง re-derive):**
- vehicle = `ea_template/Boss_15_ST03.ex5` (chassis) · **flat-lot = `LotProg=PROG_NONE` = chassis DEFAULT อยู่แล้ว** (ไม่ต้องยุ่ง LOT_Repeat — นั่นคือ param ตัว standalone `EA_RUNNER_ST03`, คนละตัว!) · escalation = `LotProg=PROG_LOG_POWER`+`_55_LogPowerFactor` (ไว้ lever A ทีหลัง)
- sweep params (ชื่อ chassis จริง จาก `core/Inputs.mqh` L229-232): `_15_MacdFast {8,12,16}` × `_15_MacdSlow {26,34}` × `_15_MacdSignal {9}` × `_15_CountBars {2,3,4}` = **18 combos** (default 12/26/9/2)
- runner: `scripts/mt5_optimize.ps1` complete-mode ต่อ cell (deterministic grid, XML out) — **ไม่ใช้** `robust_sweep_st03.ps1` (ตัวนั้น target standalone + exit-params ผิด lever). base .set = pin `LotProg=PROG_NONE` + FirstLotMode=FIRSTLOT_FIXED + base lot เล็ก ให้ DD อ่านได้ · **⚠️ Model-4 หมายเหตุ: lever C = flat-lot single-position → Model 1 พอ (ไม่ใช่ basket ยัง)**
- 12 optimize passes = 6 cell × 2 window · แต่ละ pass ≤18 combos → รวม ~216 config-runs
**GATE:** ไม่มี cell flat-lot ≥1.0 both-window (n≥100 ต่อ type intraday) → **STOP รายงาน ห้าม optimize ต่อ**
**lever A (เฉพาะเมื่อ C ผ่าน):** capped basket บน cell ที่ผ่าน — _9_MaxLevels {4,6,8} × emergency-DD
(RC_AcctDDLimitPct / kill-DD) — **ไม่ใช่ SL รายไม้** · Model 4 confirm (basket)
**lever B (เฉพาะเมื่อ C ผ่าน):** leading regime gate — `_MG_SelfGate` A/B (MRIS regime CSV — validated
ORDER-073 แล้ว) on/off บน config เดียวกัน · ชนะ = expectancy/trade ↑ AND DD ↓ both-window
**ห้าม:** Model-2 numbers · รันซ้ำ lever ที่ปิดแล้ว · แตะ 9397/9398/990010/บัญชีจริง · deploy (verdict =
Claude + user) · single-window ranking
**ทำได้:** Claude sets+judge · qwen/ea-screener batch M1 · M4 serial เลน 1 · 👉 แนะ: **Claude ออก .set →
qwen รัน C → Claude อ่าน surface → A/B เฉพาะเมื่อผ่าน GATE**

## ORDER-095 / #4 — Boss_14 GridLog EUR-cross symbol-expand — `CLOSED + REVIEWED(Claude 2026-07-17): EURCHF+EURGBP both-window Model-4 coarse = NO home (MAIN spikes only, BWD dead ทุก cell) → PARKED ทั้งคู่ ไม่ kill (Boss_14 live @GBPJPY leg-8). ยืนยัน grid=symbol-specific. GBPCHF/NZDCAD/AUDNZD/AUDCHF = BLOCKED-ON-DATA (ไม่มี history 2020-22 → user โหลดก่อนถึงเทสได้; user เคาะ stop-at-2). verdict = _triage/_archive/verdicts/order076-098/ORDER095_EURCROSS_EXPAND_VERDICT.md` (role: agent ea-validator ×2 · verdict = Claude)

## ORDER-098-K — stat-arb maker(pending-limit) build-on — `DONE/REVIEWED (Claude 2026-07-17) → NO LIFT, market baseline stays`
Built `PairSpread_StatArb_Maker.mq5` (magic 990985, limit entry + naked-leg guard). Funnel: maker 1.12/1.14/1.23 ≈ market 1.14/1.15/1.23 → cost-drag hypothesis REJECTED, edge thinness is signal-inherent. Keep deployed market ExitZ0.3. verdict `_triage/_archive/verdicts/order076-098/ORDER098F_PAIRSPREAD_STATARB_VERDICT.md` §098-K.

## 🗂️ ARCHIVED ORDERS — index ย้ายไป generated file (ORDER-102 Contract C1, 2026-07-13)

> orders ปิดแล้ว = `ARCHIVE_TASKBOARD_2026-07A.md` (verbatim) · **index = generated/read-only** `docs/memory_control/ARCHIVE_INDEX.md` (§20.7 — ห้าม hand-edit ในบอร์ดนี้) · integrity guard: `powershell -File scripts/check_taskboard_archive.ps1 -Strict` (raw/reviewed/unresolved · archive append-only + active conservation)
## ORDER-045 — MT4 demo experiment #2: UnNomGuai + RSI from pips (คู่, บัญชีใหม่) — `WAITING-USER (attach) → แล้วค่อยเป็น monitoring loop` · **เจ้าของ: user (attach) + Claude (judge)** _(ออก 2026-07-07 หลัง user อนุมัติ)_

**สถานะ:** ORDER-036 ปิดสมบูรณ์ (1,318 → 2 survivor: **UnNomGuaiV1.132 + RSI from pips_EA** ผ่านครบถึง
Model-0 bwd+fwd) · user อนุมัติ demo คู่บนบัญชีเดียว (2026-07-07) · **bundle พร้อม: `_demo_deploy\`**
(ex4 ×2 + `README_DEPLOY.md` มี MD5 lock, kill-switch, ค่าคาดหวัง) · แผนเต็ม: `DEMO_DEPLOYMENT_PLAN.md`
§MT4 demo experiment #2
**รอ user:** เปิดบัญชี demo ใหม่ ($10k, แนะ ThinkMarkets) → ลง MT4 portable `D:\Meta4demo` (ห้ามใช้เลนเทส)
→ attach ตาม checklist → **แจ้งวันที่ attach = demo-clock เริ่ม (judge +3 เดือน)**
**งาน agent หลัง attach (ทุก ~2 สัปดาห์ รอบเดียวกับ ClevrFX):** อ่าน statement ที่ user export → แยก P&L
ตาม magic (1/2 = UnNom · 5888 = RSI) → เทียบตารางคาดหวังใน README → เช็ค kill-switch (UnNom >12 ไม้ ·
RSI >0.06 lot · DD alert 20/25% kill 30/35%) → รายงาน · **ห้าม:** แก้ input EA · เพิ่ม EA อื่นในบัญชีนี้

**ผล:** _(รอ attach)_

---

## ORDER-055 — [NEXT SESSION START HERE] demo cohort 8 ตัว: attach + monitor — `🚀 ATTACHED 2026-07-09 คืนนี้ (โครงจริงต่างจากแผน — ทั้งหมดบน VPS, cohort MT5 ขึ้น REAL cent!) · judge ชุดนี้ = 2026-10-09 · รายละเอียด = section "DEPLOYMENT REALITY 2026-07-09" ใน DEMO_DEPLOYMENT_PLAN.md · เหลือ: user attach exporter ×5 บน VPS + เลือกท่อ CSV (OneDrive บน VPS หรือ RDP-copy รายสัปดาห์) + จับตา Boss-TrendSwing/Woodfire (มี EA ที่แล็บ REJECT ปน — Gold Reaper, LondonConso)`

**สรุป session 2026-07-08/09 (Opus): EA hunt รอบใหญ่จบ → 7 clean + 1 experimental candidate พร้อม attach.**
รายละเอียดเต็ม = `PROJECT_STATE.md` §7 "SESSION 2026-07-08" block · handoff doc = `handoff/SESSION_2026-07-09_HANDOFF.md`
bundle = `_demo_deploy\README_DEPLOY.md` (2 บัญชี MT4+MT5 · WILL-IT-TRADE checklist + kill-switch + corr + portfolio-sim ครบ).

**8 candidates (magic distinct):**
- MT4: UnNomGuai(EURUSD/1-2) · RSI-orig(EURUSD/5888) · swb(AUDCAD/990) — grid, validated
- MT5: RSI-MR(EURUSD/990103,**ROBUST**) · Zeus(XAU/990101,MARGINAL) · BRK-XAU(XAU/991001,MARGINAL) · SqueezeBRK(XAU/991004,**ROBUST**) · **Trendline(XAU/991002,EXPERIMENTAL PF-5th 0.986)**

**Claude-doable งานเสร็จหมดแล้ว (session นี้):** corr matrix 8-EA (ไม่มีคู่ >0.60, gold 3 ตัว uncorrelated) · portfolio-sim (รวม DD 1.2%, gold-pair 3.8%) · bundle verify + **AllowLive=true fix ทั้ง MT5 set (critical silent-stop catch)** · WILL-IT-TRADE checklist · tools ใหม่: corr_matrix/portfolio_sim/mt4_deals_to_csv/max_recovery_days.py

**แผนวันนี้ 2026-07-09 (user รวม session แล้ว — session นี้เป็น lead เดียว · เรียงตาม EV):**
1. **[user, ~20 นาที] attach 8 ตัว** (MT4 3 + MT5 5 ตาม `_demo_deploy\README_DEPLOY.md` WILL-IT-TRADE checklist) **+ attach DealsExporter.ex5 1 chart** (ค้างจาก ORDER-042) → บอกวันเริ่มให้ Claude · **EV สูงสุด — ทุกอย่างรอด่านนี้**

> **📋 USER CHECKLIST เย็นนี้ (2026-07-09) — ทำทีเดียวจบ:**
> ☐ 1. attach demo cohort 8 ตัว ตาม `_demo_deploy\README_DEPLOY.md` (เช็ค WILL-IT-TRADE ทุกข้อ: AllowLive=true, RSI-MR ต้องบัญชี Hedging, AutoTrading เปิด, magic ตรง)
> ☐ 2. attach `tools\DealsExporter\DealsExporter.ex5` 1 chart บน terminal demo MT5
> ☐ 3. **บัญชี VPS → ไม่ต้องแตะ VPS เลย:** เปิด MT5 instance สำรองบนเครื่องนี้ (D:\Meta 5b) → login บัญชี VPS ด้วย **investor password** (read-only) → แปะ DealsExporter 1 chart · ทำซ้ำต่อบัญชีที่อยาก track (รวม Boss-TrendSwing 159475669 ถ้าจะให้ track)
> ☐ 4. บอก Claude: วันที่ attach + รายชื่อบัญชี → Claude ลงทะเบียน DEMO_DEPLOYMENT_PLAN + ตั้ง judge date + scheduled task (collector + dashboard อัตโนมัติทุกเช้า)
> · ~~หมายเหตุ: บัญชี MT4 ใช้ DealsExporter ไม่ได้~~ **อัปเดตบ่าย: MT4 exporter มีแล้ว (ORDER-060)** —
> ☐ 5. attach `tools\DealsExporter\OrdersExporterMT4.ex4` 1 chart บน terminal demo MT4 ด้วย
> (**สำคัญ: คลิกขวา tab Account History → เลือก "All History" ก่อน** ไม่งั้น export ไม่ครบ)
2. **[Claude ทันทีที่รู้วัน attach]** บันทึก DEMO_DEPLOYMENT_PLAN + judge +3 เดือน + ตั้งรอบ /ea-monitor
3. **[Codex] ORDER-057 Stage A** — `Regime.mqh` (ADX trend/sideway + ATR storm, default OFF) → Claude review + `tpl_regression.ps1` ต้อง CLEAN → ค่อยปล่อย Stage B (ZCode, A/B both-windows)
4. **[qwen/Sonnet] ORDER-058** — live dashboard HTML per-magic (ต่อยอด DealsExporter · มีข้อมูลจริงหลัง user ทำข้อ 1)
5. [optional ถ้า quota เหลือ] COT/CME regime-data pull (ไอเดียจากโพส FB 07-09 — ยังไม่เป็น order, รอ user เคาะ) · ORDER-043 US30 probe (ZCode วันว่าง)
**หลัง attach:** statement ทุก ~2 สัปดาห์ → แยก P&L ตาม magic → เทียบค่าคาดหวัง README · จับตา (a) MT4 grid no-SL tail (b) combined gold exposure (Zeus+BRK+Squeeze+Trendline ทั้ง 4 = XAU) (c) Trendline #8 borderline → drop ถ้าไม่เข้าเป้า
**ปิดไปแล้ว:** hunt space สำรวจหมด (instrument/TF/กลไก/lot-law/re-opt/FX-travel = ตัน) — กลไกใหม่จริง (flag/pennant/order-flow) ค่อยว่ากัน · Boss V2 robustness track = parked
**ห้าม:** แก้ config ที่ validate แล้ว · เชื่อ hunt ว่า EV สูง (พิสูจน์แล้วว่าตัน)

**ผล:** bundle deploy-ready (8 EA, safety-checked). รอ user attach.

---

## ORDER-108 — break-and-retest split-entry (market + pending-limit) บน breakout winner (user idea 2026-07-16) — `DONE + REVIEWED(Claude 2026-07-16): 🟩 BUILD-ON SUCCESS — build (EXP)_BRK_SplitRetest + A/B Model-4 XAU H1 · retest fill-rate ~90% · adverse-selection จริง (pending-only แพ้ market ในเทรนด์ = ต้องมีขา market) · split robust ทั้ง 2 regime (1.93/1.97) · lever ใหม่เข้า EDGE_CATALOG · **followup: retrofit LIVE Bars55/TP8 = ไม่ยก (split 1.89<market 1.99, retest อ่อน BWD) → ห้าม retrofit ตัว live · lever = config-conditional (ช่วยเฉพาะ config สมดุล)** · verdict = _triage/_archive/verdicts/order104-126/ORDER108_SPLIT_RETEST_VERDICT.md` (role: Claude build → agent run · verdict = Claude)

**ที่มา (user 2026-07-16):** breakout ส่วนใหญ่กลับมา retest แนวที่ทะลุ → วาง **pending-limit ที่ retest** เก็บ pullback
ราคาถูก (ไม่จ่าย spread + SL แคบชิดแนว = RR ดีขึ้น). user เสนอ **split sizing: market 0.02 (จับ runner ที่ไม่ retest) +
pending 0.01 (เก็บ retest)** — แก้ปัญหา adverse-selection พอดี (ไม้ที่ไม่ retest มักแรงสุด → market leg กันพลาด).
**ต่างจาก Thread A (JUMSTOCH reversion pending):** นี่ = breakout+retest บน EA ที่มี edge อยู่แล้ว, entry-quality lever.

**Vehicle = EA_BREAKOUT_XAU** (deploy อยู่, edge ยืนยัน — ไม่ใช่ XAU_NY ที่ปัญหาคือ regime ไม่ใช่ราคาเข้า).
**คำสั่ง:** (1) variant ที่ breakout signal ยิง: ส่ง market leg (sizeA) ทันที + วาง pending buy/sell-limit (sizeB) ที่
**ระดับแนวที่ทะลุ** (retest level), expiry N bars · ห้ามแตะ signal/SL/exit logic เดิม (isolate entry-structure) ·
(2) compile 0/0 + mql-code-reviewer (3) A/B บน home cell (XAU H4/H1 both-window): **market-only baseline** vs
**split(A=0.02,B=0.01)** vs **pending-only** · sweep retest-offset + expiry.
**Acceptance (วัด adverse-selection ตรงๆ):** ต่อ variant รายงาน — pending-leg **fill-rate %** · **EV/signal** เทียบ
baseline · แยก EV ของไม้ที่ **2-leg fill (retest เกิด)** vs **market-only (วิ่งหนี)** = พิสูจน์ว่า runner คือกำไรใหญ่จริงไหม ·
net PF/DD. **บาร์:** split net-EV/signal > market-only ที่ spread จริง = ยืนยันคุณค่า.
**ห้าม:** เอา pending-limit ไปแปะ EA ที่ปัญหาไม่ใช่ entry-cost (เช่น XAU_NY = regime) · เปลี่ยน lever อื่นนอก
{entry-structure, retest-offset, expiry, split-ratio} · verdict (lead) · promote เงินจริง (probe/build-on เท่านั้น).

---

## เสนอ order ใหม่ (agent อื่นเขียนข้อเสนอได้ที่นี่ — Claude เป็นคนยกเป็น order จริง)

### 🟣 PROPOSAL-A (ZCode, 2026-07-04) — ✅ APPROVED → ยกเป็น ORDER-009 แล้ว (เก็บไว้เป็น reference)

**บริบท:** ตอนนี้ ORDER-005 (IS-opt) + ORDER-006 (fresh-start OOS) + ORDER-007 (probe 7) = DONE
ทั้งหมด รอ Claude review. แต่ ORDER-006 ผลิตแค่ผล OOS (PF/Net/EqDD จาก single equity path)
**ยังไม่มี Monte Carlo** — ขณะที่ ORDER-004 (GBPAUD) ใช้ MC เป็นหลักฐานประกอบ verdict
(DD 95th/worst/ruin). pipeline เดียวกันควรมี MC ครบทุก OOS-passing candidate ก่อน Claude
ตัดสิน ไม่งั้น Claude ต้องสั่งซ้ำรอบ review.

**OOS ผลที่ ORDER-006 รายงาน (จาก report ครบบน disk):**
AUDNZD 42t PF 3.02 ✅ · EURJPY 23t PF 2.15 ✅ · USDJPY 106t PF 2.77 ✅ ·
GBPJPY 23t PF 1.12 (borderline) · EURCAD 140t PF 0.67 (fail)

**งานที่ขอทำ (role ZCode แท้ — รัน `mt5_montecarlo.py` ที่มีอยู่ ไม่สร้าง/แก้ source):**
```powershell
. D:\EA_LAB\scripts\use_python.ps1
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_AUDNZD_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_GBPJPY_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_EURJPY_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_EURCAD_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_USDJPY_OOS_M1.htm  --deposit 10000 --iters 5000
```
**Acceptance (ถ้า Claude approve):** ต่อ symbol append ตาราง `trades_used / DD median / 95th /
worst / ruin% / P(loss)` · commit `[zcode] PROPOSAL-A done`
**ข้อห้าม (ตาม role):** ไม่ตีความผล, ไม่ให้ verdict, ไม่เลือก candidate — รายงานดิบเท่านั้น.
**caveat ที่จะรายงานควบ (จาก docstring ตัว script เอง):** trade-reshuffle MC = optimistic
lower bound (grid ขาขาด cluster → real adverse อาจแย่กว่า reshuffle ใดๆ) — treat 95th/worst
เป็น "at least this bad" ไม่ใช่ ceiling.

**⚠️ ข้อควรพิจารณาของ Claude ก่อน approve:**
- OOS report บางตัวมีเทรดน้อย (GBPJPY 23t / EURJPY 23t / AUDNZD 42t) — MC บน n<30 noise มาก
  (ORDER-004 เคยเลี่ยงปัญหานี้โดยรัน MC บน full report 88t แทน OOS 23t). ทางเลือกสำหรับ Claude:
  (a) approve ทั้ง 5 + flag ว่า thin, (b) ขอให้ ZCode รัน MC บน full-window report เพิ่มเทียบ,
  (c) รันเฉพาะ USDJPY(106t)/EURCAD(140t) ที่ n เพียงพอก่อน.
- หาก Claude ตั้งใจ review ORDER-005/006 เองโดยไม่ใช้ MC (ใช้แค่ PF+regime-read) ก็ปฏิเสธ
  proposal นี้ได้เลย — ZCode จะไม่ทำ.

---

## ORDER-073 — News-aware risk system (user directive 2026-07-10) — Phase 1 `DONE(Claude)` · Phase 2 `ATTACHED 2026-07-24 (user) on all 3 real accounts (141049900 MT4 / 159503454 MT5 / 159475669 MT5) — filename-mismatch finding below FIXED(user, 2026-07-24)` · Phase 2.5 MRIS `DONE(Claude 2026-07-18)` · Phase 3 MacroGate `DONE — ⚠️ ถอนสถานะแล้ว: ADVISORY-ONLY (ORDER-211, 2026-07-25) · เดิมเขียนว่า "VALIDATED deploy-candidate (Claude 2026-07-18)" → ATTACHED 2026-07-18 (demo carry-leg 990120, manual-weekly mode)`

**✅ 2026-07-24 finding RESOLVED(user) — NewsGuard "file missing/stale" root cause was a FILENAME mismatch:** `Common\Files` on the VPS had the file as `news_week.csv` but every NewsGuard instance's `NewsFile` input expects `EA_LAB_news_week.csv` (copy step ran but was never renamed). **User fixed the rename on the VPS 2026-07-24** — not independently re-verified by Claude via a fresh alert/log snapshot, logged here on user attestation. If the "missing/stale" alert reappears on 159503454/159475669/141049900, re-open this finding first before assuming a new cause. Still unresolved/deprioritized separately: MT4 `ServerToBkkOffsetHours` timezone input (should be 7, not default 4) on 141049900 — user call, low-priority (MT4 footprint being reduced anyway).

**✅ SESSION 2026-07-18 CLOSE (commits `7ee6bbd8`→`e219db8e`, branch `order073-macrogate-safe`):**
- **Phase 2.5 MRIS = SHIPPED, live daily.** web feeder (all 8 barometers from Yahoo — VIX/DXY/COPPER/US10Y-proxy + broker pairs, no stooq), thresholds LOCKED as user-sanctioned defaults + in-file `_tuning_guide` (`barometers.json` v1.0), whisper embedded top of `LIVE_DASHBOARD.html` + wired into `daily_monitor.ps1` (mris_run before dashboard). Codex-hardened (5 fixes: cache-poison, atomic write, effective-status, culture-parse, asof fail-open). Reads NEUTRAL RI 0.269 HIGH.
- ⚠️ **ถอนแล้ว 2026-07-25 (ORDER-211) — ย่อหน้านี้เก็บไว้เป็นประวัติ ห้ามอ้างเป็นหลักฐาน.** สถานะจริงตอนนี้ = **ADVISORY-ONLY** ไม่ใช่ deploy-candidate · หลักฐานข้างล่างถูกวัดใต้ MRIS classifier ที่พัง (`AUDJPY.user_pin=110` ทำให้ gate ปิดถี่เกินจริงตลอดปี) · รันใหม่บน classifier ที่แก้แล้ว PF ตกทั้ง 4 ช่อง · **ห้ามอ้างเลข "eqDD −54..−56%" ต่อ** (ORDER-211 สั่งห้ามไว้ตรงๆ)
- ~~**Phase 3 MacroGate = VALIDATED deploy-candidate (was STUB).**~~ Standalone watchdog + chassis GV bridge (`Execution.mqh` block+lot-mult, open-path only) + in-chassis `_MG_SelfGate` for single-EA A/B. Concept: MRIS flags Aug-2024 + Mar-2020 unwinds with lead time. **A/B (Boss_12_Breakout, full-year 2024, 2 symbols): eqDD −54..−56%, P&L flat→much better** (USDJPY −58→+2.8). Manage-only grid (Boss_14) = no-op (harmless). Cage: core edits inert (identical trade counts). Codex QA fix-then-ship → all 7 fixed. Verdict: `ea_projects\(Boss)_MacroGate\MACROGATE_AB_VERDICT.md`; review: `docs\memory_control\CODEX_MACROGATE_REVIEW.md`.
- **WAITING-USER:** (1) NewsGuard GuardConfig เคาะ + VPS attach (Phase 2, unchanged) (2) MacroGate live attach = user decision (deploy on breakout carry legs; use standalone watchdog or `_MG_SelfGate`; regime CSV → VPS via rclone; add `mris_export_regime` to daily chain) (3) refresh `tpl_regression` baseline for a formal GREEN (Jul-11 ticks stale). ⚠️ MacroGate evidence = 1 window (2024, in-sample); test a holdout year before sizing up.

**เป้า user:** เห็นข่าวแรงที่เกี่ยวกับพอร์ตทุกวัน + มีตัวคุมเหนือ EA ทั้งหมด (ลด lot / ปิดไม้ / block entry
ช่วงข่าวแรง ตาม policy ต่อ strategy)

**Phase 1 (เสร็จ 2026-07-10):** `scripts\news_calendar.ps1` — ดึง ForexFactory weekly feed → filter
High-impact 8 สกุลพอร์ต → (a) `portfolio\news_today.html` ฝังใน LIVE_DASHBOARD (มือถือเห็นทุกเช้า
ผ่าน gist) (b) `portfolio\news_week.csv` = machine-readable ให้ Phase 2 · cache กัน 429 · อยู่ใน
daily 07:30 chain แล้ว · **ข้อจำกัดที่ต้องรู้: กันได้เฉพาะข่าวตามนัด — Brexit/SNB-type (gap ไม่มีนัด)
กันด้วยปฏิทินไม่ได้ = เหตุผลที่ SL/cap ต้องมีเสมอ**

**Phase 2 — NewsGuard watchdog EA (OPEN, ต้องคุย design กับ user ก่อน build):**
- EA ตัวเดียว attach 1 chart/บัญชี อ่าน `news_week.csv` (คัดลอกไป Common\Files หรือ WebRequest ดึงเอง
  บน VPS — ต้อง whitelist URL ครั้งเดียว) · นาฬิกา event เทียบ server time
- policy ต่อ magic list (input): `BLOCK_NEW` (กันไม้ใหม่ N นาทีก่อน/หลัง event — ทำได้กับ EA เราเท่านั้น
  ผ่าน GlobalVariable flag ที่ chassis อ่าน) · `CLOSE_ALL` (ปิดไม้ magic นั้นก่อน event — ทำได้กับทุก EA
  รวม locked เพราะ watchdog มีสิทธิ์ระดับบัญชี) · `NONE`
- ค่าเริ่มแนะนำ: CLOSE_ALL เฉพาะ strategy ไร้ SL/recovery (Zeus 7777, gold grids) ก่อนข่าว USD แรง
  30 นาที · BLOCK_NEW สำหรับ breakout family (ข่าวคือ noise ไม่ใช่ signal ของมัน) · Boss_14 bench
  demo = NONE (เก็บ data ให้ judge เห็นพฤติกรรมจริง)
- **ห้าม build จนกว่า user เคาะ policy ต่อบัญชี/ต่อ magic** (มันจะไปปิดไม้เงินจริง — ต้อง explicit)
- **UPDATE 2026-07-17:** build เสร็จแล้วภายใต้ ORDER-083 (MT5+MT4, .ex5/.ex4 compile แล้ว) · draft policy
  ต่อ magic = `ea_projects\(Boss)_NewsGuard\GUARDCONFIG_2026-07-17.md` (รอ user เคาะ) · runbook transport
  แก้เป็น rclone แล้ว (VPS 2012 R2 ลง OneDrive client ไม่ได้) · เหลือ user attach ตาม
  `VPS_TRANSPORT_AND_ATTACH.md` เท่านั้น

**Phase 2.5 — MRIS macro-regime layer (PROTOTYPE BUILT 2026-07-17, Claude inline):** #073 reimagined
(user directive) = อ่านสัญญาณมหภาค→บอกทิศ+เฝ้าระวังล่วงหน้า สไตล์บทความ AUD/JPY carry. **รันได้จริง**
ที่ `scripts\mris\` (PowerShell, zero-token, sibling ของ news_calendar):
- `mris_classify.ps1` — barometer(AUDJPY/USDJPY/VIX/DXY/XAU/BTC)+tripwire relative(SMA200/ATR ไม่ hardcode)
  → state RISK_ON/NEUTRAL/RISK_OFF/STRESS + Risk Index + confidence(เส้นขนาน) · verified RISK_ON↔STRESS พลิกจริง
- `mris_exposure.ps1` — join DEPLOYMENTS → tag DIRECT_CARRY(8 JPY legs)/RISK_ON → action reduce-lot-not-cut
- `mris_brief.ps1` — Thai whisper brief (md+html embed dashboard) · `mris_run.ps1` = one-shot
- feed: MT5 exporter `_mt5_auto\mris\Export_Barometers.mq5` (broker symbols) · VIX/DXY/yields/copper = PENDING (web feeder TODO)
- seed snapshot 2026-07-16 อ่านได้ = **NEUTRAL แต่ 2 loaded lines** (AUDJPY ~3% เหนือ pin 110 · USDJPY 161 crowded)
- **รอ user:** เคาะ tripwire/threshold จริง (`_triage/MACRO_REGIME_SYSTEM_PROMPT.md`) + wire web feeder → แล้ว MacroGate (Phase 3) ยกเป็น order เต็ม

**Phase 3 — MacroGate watchdog (STUB 2026-07-17 — ห้ามหยิบไป build จนกว่า MRIS เคาะกติกา):**
- แนวคิด: watchdog ตัวที่สองแบบ NewsGuard (per-magic, 1 chart/บัญชี) แต่ trigger จากราคา in-terminal
  แทนไฟล์ข่าว — สภาวะ carry-unwind/risk-off (AUDJPY เป็นตัวนำ) → **ลด lot ×0.5 + BLOCK_NEW เฉพาะ
  magic กลุ่ม JPY-cross/risk-on** (Zeus AUDJPY 990110 · Boss_14 990208/201/203/205 · IchiADX 990066-67 ·
  BRK USDJPY 991003 · US30 991005) — **ไม่ปิด position** (user rule: reduce-lot-not-cut)
- กติกา trigger ต้องเป็น relative (เช่น D1 หลุด SMA200 + ร่วง >N×ATR ใน M วัน) — ห้าม hardcode level 110
  (เลขของรอบนี้ = input เสริมที่ user เคาะผ่าน MRIS)
- **บังคับ A/B backtest ก่อน attach:** window ครอบ 2024-08-05 carry unwind + 2020-03 บน leg ที่จะใส่จริง
  (คาดผลตาม Regime.mqh เดิม: ช่วย grid จริง · redundant กับ breakout — ถ้า A/B ไม่ต่าง = ไม่ใส่)
- blocked-on: user เปิด session MRIS (`_triage/MACRO_REGIME_SYSTEM_PROMPT.md` #073-reimagined) เคาะ
  tripwire/threshold ก่อน แล้ว Claude ค่อยยกเป็น order เต็ม (spec + acceptance + ห้าม)

## ORDER-080-orig (spec เดิม — superseded)

**สมมุติฐาน:** เข้าไม้ด้วย pending limit ที่ราคาดีกว่า signal price เล็กน้อย (แลกกับ fill ไม่ครบ)
ให้ EV ดีกว่า market entry — โลก crypto พิสูจน์ด้วย fee; โลก MT5 = ประหยัด spread/slippage แทน
**คำสั่ง:** เพิ่ม input `EntryMode` (0=market เดิม default · 1=limit offset) + `EntryLimitOffsetPips` +
`EntryExpiryBars` ให้ **Boss_16_KangarooGrid** (additive, default = พฤติกรรมเดิม, ผ่าน regression cage)
→ A/B บน config candidate 21/30 XAU H1: market vs limit offset {3, 6, 10 pips} expiry 1 bar ·
ทั้ง IS 2023-26 และ BWD 2020-22 · Model 1 (+Model 0 confirm คู่ที่ต่างกันสุด)
**Acceptance:** ตาราง market vs 3 offset × 2 window: PF/net/trades/**fill-rate** (นับไม้หาย) ·
commit `[tag] ORDER-080 done` · **ห้าม:** เปลี่ยน lever อื่น · verdict (Claude อ่าน — สนใจ EV ต่อไม้
หลังหัก opportunity cost ของไม้ที่ไม่ fill ไม่ใช่แค่ PF)

## ORDER-082 — Entry_Wave5: สัญญาณ Elliott ขา 5 ตาม rule ที่ user ถ่ายทอดเอง (2026-07-10) — `CLOSED — DEMO-ELIGIBLE (Claude 2026-07-14) · WAITING-USER attach · bundles = _vps_deploy/WAVE5_XAU (magic 990301) + WAVE5_XAG (990302)` (role: Claude spec → agent build/probe)

**Rule จากปาก user (บันทึกตรงคำ — นี่คือ ground truth ของ spec):**
- คนส่วนใหญ่พยายามเข้า wave 3 (เทรนด์ยาวสุด) แต่รู้ตัวก็ต่อเมื่อมัน confirm แล้ว (break S/R,
  break trendline) → เข้าไม่ทัน/RR ไม่คุ้ม
- **จุดได้เปรียบ: พอรู้ว่า wave 3 เกิดแล้ว → รอ pullback (wave 4) retrace ~23–38% ของ wave 3
  → เริ่มเข้าได้ เพื่อกิน wave 5**
- **SL = ยอด wave 1** (ตาม EW rule: wave 4 ห้าม overlap โซน wave 1)
- **ออก: break ยอด wave 3 / Fibonacci expansion 100%** — บริเวณนั้นมักเกิด **RSI divergence**
  ร่วม = สัญญาณเตรียมออก/เปิด trailing

**การแปลงเป็นกลไก (draft ให้ user ยืนยันก่อน build):**
1. Swing detection: ZigZag(H1/H4) label โครง 1-2-3: wave1 = impulse แรก, wave2 = retrace ไม่หลุดจุดเริ่ม,
   wave3-confirm = ราคา break ยอด wave1 แล้ววิ่งต่อ ≥ K×|wave1| (เช่น 1.0-1.618) — "รู้หลัง confirm" ตาม user
2. Arm entry เมื่อ: หลัง wave3-peak ราคา retrace เข้าโซน **23.6–38.2% ของ wave 3** (fib จาก zigzag) →
   entry ตามทิศ wave 3 (bar-open + optional confluence: RSI ยังไม่ divergence)
3. SL = ยอด wave 1 (± ATR buffer) — โครงสร้าง ไม่ใช่ระยะสุ่ม · invalid ทันทีถ้า retrace ลึกเกิน 50%
4. TP/exit: ลำดับ (ก) แตะ 100% expansion (wave5 = wave1 length จากจุดเข้า wave4) หรือ break ยอด wave3
   แล้วเปิด ATR trailing (ข) RSI divergence ที่ high ใหม่ = บังคับ trailing แน่น
5. Naked probe ตามมาตรฐาน (1 ไม้/สัญญาณ, no grid): symbol แรก = **XAUUSD H1** (trending home) +
   GBPUSD H1 · window 2023-26 + BWD 2020-22 · บาร์ผ่าน: naked PF ≥ 1.0 ทั้ง 2 window บน symbol ใดหนึ่ง
**หมายเหตุ:** มีไฟล์คอร์ส (Jobot) Elliott Wave 5 Zone v1/AAA ให้เทียบ rule (block labels) — ใช้ตรวจว่า
การตีความข้อ 1-4 ตรงกับที่คอร์สสอนไหม ก่อน build
**ห้าม:** build ก่อน user ยืนยัน draft ข้อ 1-4 · ข้าม naked probe ไป grid/recovery


---

## ORDER-082 — AMENDMENT (user ยืนยัน 2026-07-10 ค่ำ)

- ✅ ZigZag + Fibonacci = แนวที่ user ต้องการ (ตรงกับไฟล์คอร์สด้วย) · ข้อควรระวัง build:
  **ZigZag ขาสุดท้าย repaint — ใช้เฉพาะ pivot ที่ confirm แล้วเท่านั้น** + พิจารณา ATR-adaptive
  deviation แทน fixed (ให้ swing scale ตาม volatility)
- Entry level = **input เลือกได้ {23.6, 38.2, 50, 61.8}** (user: "จุดสำคัญ ... ประมาณนี้") — sweep เป็น lever
- Invalidation = **โครงสร้าง: wave 4 ห้าม overlap โซนยอด wave 1** (แทน fixed 50% เดิม — สอดคล้อง
  SL ที่ยอด wave 1 พอดี ราคาแตะ SL = โครงพังเอง)
- สถานะ: spec ครบ พร้อม build → คิวหลัง ORDER-078/083
- **Task 0 gates CLEARED (Opus, 2026-07-12, commit `fc31d0b`):** Jobot ref = misnomer (RSI+CCI martingale ไม่มี wave logic → ไม่มี ref impl, plan = spec of record) · **fable-advisor spec-check PASS** (arch A sound + guards G1-G4) · user เคาะ: both-direction · TP วัดจากราคาเข้า (entry±\|W1\|) · **trailing ตั้งแต่แรก + RSI-divergence tighten** · แผน build 6 tasks พร้อม = `docs/superpowers/plans/2026-07-12-entry-wave5.md` → รอปล่อย Task 1-4 build
- **Task 1-4 BUILT + Task 6 naked probe DONE (Opus, 2026-07-13):** build เสร็จ (commit `bfa048f`) — Opus verify เอง compile 0/0 + regression CLEAN (11-16 byte-identical) + **จับ+แก้บั๊กร้ายที่ subagent พลาด: labeling 3-pivot → wave1end/wave3peak ต่างประเภทเสมอ = Entry ยิงไม่ออก (zero-trade การันตี) → แก้เป็น 4-pivot + wave2-validity + fib วัดจาก wave3 จริง**
  - **probe 4 cell (default params, ExitMode=TRAIL, MaxLevels=1, structural SL):** XAU main(23-26) **PF 1.57**/174t/DD1.66% · XAU BWD(20-22) 0.95/148t · GBP main **PF 1.18**/164t/DD0.66% · GBP BWD 0.96/137t
  - **VERDICT (lead):** ✅ fix ยืนยัน (ยิงไม้ออกทั้ง 4 cell) · **deploy-gate (both-window≥1.0) ยังไม่ผ่าน** (ทั้ง 2 sym ตก BWD เฉียดๆ) · **แต่ ≠ ตาย** = PARAMETRIC-marginal · ALIVE · build-on (main>1 ทั้งคู่, BWD 0.95-0.96 เฉียดเส้น, DD จิ๋ว, 0 lever swept) · XAU main 1.57@win45% = mechanism มีของ
  - ~~**ค้าง = SWEEP (pace, ยังไม่รัน)**~~ → **SWEEP DONE + DEMO-ELIGIBLE (Opus 2026-07-14):** plateau ยืนยัน 2 symbol
    (XAU fib23.6→30 ต่อเนื่อง 1.11/1.11 · XAG 6/6 cell MAIN 1.30-1.45/BWD 1.28-1.35 แข็งกว่า XAU) · MC ruin 0.00% ·
    holdout XAU H4 MAIN 1.74/BWD 1.01 · corr gate vs 4 gold cohort max|corr|=0.415 << 0.8 · bundle staged
    `_vps_deploy/WAVE5_XAU|XAG` · ⚠️ template ไม่มี tester-gate — attach แล้วเทรดทันที · เหลือ: user attach บน VPS
    (commits `0b4acdbc`+`86151de9`, spec-of-record = `docs/superpowers/plans/2026-07-12-entry-wave5.md`)

## ~~ORDER-112E — corr check~~ (spec เดิม, ปิดแล้ว)
**ทำไม:** XAU Ichimoku (slowH1 20/60/120, both-window 1.66/1.39, 5/6 yr+) = edge จริง แต่ XAU portfolio แน่น (BRK/Kaufman/SuperTrend/Wave5/MacdDiv);
SuperTrend เคยโดน corr 0.724 block. ต้องรู้ก่อนว่าเป็น leg ใหม่จริงหรือซ้ำ.
**ขั้น:** (1) รัน (EXP)_IchiADX_Naked slowH1 (set `_mt5_auto/ab_sets/ichi_kumo/KUMO_slow_H1.set`) XAUUSD H1 full 2020-2026 Model-4 → report
(2) ดึง monthly P&L จาก deal list (pattern เหมือน `ichi_basket_merge_mc.ps1`) (3) เทียบ `_mt5_auto/corr_monthly.py` กับ monthly ของ XAU legs เดิม
(รัน full-window ของ EA_BREAKOUT_XAU Bars8 + KAUFMAN_ER buyonly เป็น reference — reports อาจมีแล้วใน `_mt5_auto/reports/`).
**Acceptance:** ตาราง Pearson monthly Ichimoku-XAU vs {BRK, Kaufman, SuperTrend ถ้ามี}. **verdict = Claude:** corr <0.6 ทุกตัว = additive leg ใหม่
(build bundle) · >0.8 ตัวใด = redundant (small-lot หรือ drop) · 0.6-0.8 = reduce-lot include. **ห้าม:** auto-drop (user rule: high-corr = ลด lot ไม่ตัด).

**✅ ORDER-114 PREVDAY+NR7 = DEAD (ปิด rescue queue สมบูรณ์, 2026-07-16B):** swept lever แกน (NR_Period{4,7,10,14} · buffer{0.1,0.3,0.5})
× both-window Model-4 บน XAU (28 runs, `_mt5_auto/PREVDAY_NR7_CLOSE.csv`). **NR7 = window-inversion 16/16 (BWD 0.62-0.92) + DD 27-83%
= structural dead** · **PREVDAY = ไม่มี config แตะ 1.2 both-window (marginal churn)** = dead. verdict `_triage/_archive/verdicts/order104-126/ORDER114_PREVDAY_NR7_CLOSE_VERDICT.md`.

**🏁 ORDER-084 RESCUE QUEUE = CLOSED (6/6 ยกจัดการครบ):** revive 2 (GBPJPY→leg#8 · ICHIMOKU→USDJPY+XAU basket) · dead 4 (ZSCORE·KELTNER·PREVDAY·NR7 —
swept จริงทุกใบ) · XAU_NY = regime-dependent build-on. **regime-parked (Zeus AUDUSD · Boss_14 NZDUSD-SELL/USDCAD) = full-funnel แล้ว ไม่ใช่ under-swept
→ ทางฟื้นเดียว = graft `_50_ Regime.mqh` (regime-rescue track, low-prior) — ไม่อยู่ใน rescue-ladder scope.** rescue archaeology จบ.


---

## ORDER-091 — MASTER PLAN: intake คลัง Forex 9 โฟลเดอร์ของ user (แผนแม่บท — ลูก 091A-D จ่ายตาม pacing) — `OPEN`

**ที่มา (user 2026-07-10 ค่ำ พร้อม annotation ต่อโฟลเดอร์ — เก็บคำต่อคำใน chat log):** คลังใหญ่กว่า
ที่ X-ray รอบแรกกวาดมาก — coverage เช็คแล้ว: `10_EA_PROJECTS` โดนแค่ 211 path · `04_FxDreema_Learner`
7 path · ขนาดจริง: ~1,100 src + ~9,600 binaries + **~1,100 report/set แนบ** (BOT MOGUL 713 + Final EA 389)

**กฎยืนพื้นทุก wave:** pacing 1-2 order/รอบ · vendor report = claim ไม่ใช่หลักฐาน (memory
wobr-botranking: BotMogul rank = adverse-selected overfit) · ทุกตัวจบ funnel ต้องได้ EA-SCORE ·
mechanism ที่เคยพิมพ์เงิน → จด IDEA_CATALOG เสมอ · DD สูง ≠ ปัดตก → diagnosis→lever (คำ user:
".Final EA อาจ DD เยอะแต่เอาไปทำต่อได้ เชื่อผม")

**Wave 0 — 091A: ขยาย X-ray+concept ให้ครบ 9 โฟลเดอร์ — `DONE(Claude-agent, 2026-07-11)`** (mechanical, dedupe hash vs 1,050 เดิม):
`wait_Fxdreema MT5` (151 src) · `3. ready to use` (38+102) · `review EA\Jobot` (1,556 bin) ·
`BOT MOGUL` (2,905 bin) · `AI_GEN` (168 src) · `Course jobot` (375 src) · `04_FxDreema_Learner`
(221 src) · `.Final EA` (189 src + 4,514 bin) → merged catalog + ตาราง "ใหม่จริง vs ซ้ำของเดิม"

**Wave 1 (ต่อจาก 085B/083B ที่ค้างคิว):**
- **091B — BOT MOGUL report sweep:** `BLOCKED(Codex, 2026-07-21 18:25 +07:00: required vendor-report inputs absent)` · parse 713 vendor reports → ตาราง claimed PF/DD/symbol/TF →
  คัด top ตาม claim × โครงผ่าน X-ray → **BWD-OOS spot-kill ทีละ 5** (1 รัน/ตัว ฆ่าถูกสุด) —
  ห้ามเชื่อ report แนบจนกว่า BWD เราเองผ่าน

**091B Codex check (2026-07-21):** `_intake_drop` contains source/binary files but no vendor report artifacts required by this sub-order (`.htm/.html/.xml/.set`); `_mt5_report_drop` and `_inbox` contain unrelated legacy artifacts only. No parse/spot-kill performed; no verdict.

---

## ORDER-091C-D1d — JUMSTOCH pending-limit entry variant (= ORDER-080 vehicle, user idea) — `REVIEWED(Claude 2026-07-16) — residual queue: TP-widen A/B + หา reversion base ที่ near-breakeven เป็น demonstrator`
**ที่มา:** user + ORDER-080 · mean-reversion เข้าหา LWMA → วาง **buy-limit ใต้ราคา / sell-limit เหนือ** ที่ระดับ
grid แทน market → fill maker ไม่จ่าย spread (grid 5-7k ไม้ = ประหยัด spread เยอะ อาจดัน PF ขึ้นชัด). **ทำไมเลือก
ตัวนี้เป็น vehicle แรก:** reversion (limit-compatible เป๊ะ) + grid เทรดเยอะ (spread saving ทวีคูณ) + source แก้ได้.
**คำสั่ง:** (1) สร้าง variant `(EXP)_JUMSTOCH_pending.mq4` (หรือ port entry เข้า Boss V2) — เปลี่ยน OrderSend market
เป็น pending limit ที่ราคา entry logic เดิม + จัดการ expire/re-place · ห้ามแตะ lot/SL/exit logic (isolate ตัวแปรเดียว)
(2) compile 0/0 (3) รันเทียบ market-vs-pending บน 2 home cell (EURUSD+AUDUSD H1) + spread จริง · **+ lever TP-widen
(user 2026-07-16): A/B `TP +0/+2/+5 pip` คู่กับ pending** (spread/TP ratio ลด แลก win% — ต้องวัด net) · ตาราง EV/ไม้
เทียบ (**fill-rate ของ pending ด้วย — limit ไม่ fill ทุกไม้ = ไม้ที่พลาด = โอกาสหาย · วัด EV/ไม้ + fill-rate ไม่ใช่ PF
เดี่ยว** เพราะ PF อาจสวยขึ้นเพราะเหลือแต่ไม้ดีแต่กำไรรวมหด) · **บาร์: pending net-EV > market net-EV ที่ spread จริง
(หลังหัก opportunity cost ของไม้ไม่ fill) = ยืนยันคุณค่า**
· **ห้าม:** เปลี่ยน lever อื่นนอก {entry-type, TP-widen} · verdict · commit `[tag] ORDER-091C-D1d done`
**หมายเหตุ:** นี่ตอบ ORDER-080 (limit vs market) + สมมติฐาน user 2026-07-16 ด้วย EA จริงตัวแรก → ปิด 080 ในตัวถ้าได้ผล

### ORDER-091C-D1d DONE + REVIEWED(Claude 2026-07-16): build MT5 `(EXP)_LwmaRev_Pending` + A/B Model-4
pending fill-rate ~70-73% · pending PF ≥ market 3/4 cell (+0.03-0.06 = spread/entry save) **แต่ base LWMA reversion
ติดลบทุก cell (0.55-0.93)** → วัด spread-save delta ได้ (~+0.05 PF/ไม้) แต่พลิก loser→winner ไม่ได้ (reversion no-edge).
**สรุป pending รวม 2 ฝั่ง = `_triage/_archive/one_off_analyses/PENDING_LIMIT_SYNTHESIS.md`:** pending = refinement (~+0.05 PF) ไม่ใช่ resurrector ·
ไม่ free (พลาด ~28% fill, adverse-selected ได้) · **split structure (Thread B break-retest) = form ที่ adoptable** ·
spread-death revival คุ้มเฉพาะตัวที่ post-spread PF ≥ ~0.95 (gap เล็กพอให้ +0.05 ดันข้าม) — ตัดตัวที่ collapse 0.5-0.7 ทิ้ง.
**next (queue):** TP-widen A/B บน reversion vehicle · หา reversion base ที่ near-breakeven มาเป็น demonstrator ที่ดีกว่า.

---

## ORDER-117 — CAMPAIGN: รีด EA ที่ validated แล้ว — coverage (symbol×TF) + precision-filter (user 2026-07-18: "symbol×TF ยังไม่หมด + เพิ่ม Sto/RSI/CCI/volume/PA/MTF จับจังหวะแม่นขึ้นได้") — `CORE DONE(Claude 2026-07-18) = low yield · 1 PARKED-VERIFY (GBPUSD MacdDiv D1) · filters=decoration · Phase C/other-EAs = optional`

**สรุป core (2 track เทสครบ, ส่วนใหญ่ negative แต่ rigorous + กฎ last-optimize คุ้ม):** (A) coverage: MacdDiv XAU-specific (GBPUSD H4 reject → **D1 pulse 1.45/1.23 PARKED-VERIFY** ด้วยกฎ last-opt) · breakout ไม่ travel FX + TF-expand ไม่ได้ (hardcode H1) · SuperTrend trend-specific(BWD 0.88) · **= ไม่มี leg ใหม่สะอาด**. (B) filter: candle(breakout)+RSI(raw MacdDiv) = **decoration ทั้งคู่** (ตัดไม้ไม่ selective). **บทเรียน portfolio: EA ที่ validated = tune แน่นที่บ้านแล้ว, cheap expand/filter ไม่ยกทั้ง both-window** → pipeline mature, EV จริงอยู่ที่ operate→judge. residual optional: funnel GBPUSD D1 · expand IchiADX · Sto/CCI/volume filter (low prior).

**ที่มา (user จับถูก, lead ยอมรับ):** "corpus-mining exhausted" ≠ "improvement exhausted". lane ที่ตันจริง = split-lever + .Final-EA corpus + naked-signal hunt. **ที่ยังเปิดกว้าง + EV สูง + เสี่ยงต่ำ (ต่อยอด edge ที่พิสูจน์แล้ว) = 3 อย่าง:** (A) ขยาย symbol×TF ของ EA ที่ validated (ORDER-095 ทำแค่ 1/6 EA) (B) เพิ่ม entry-quality filter (Sto/RSI/CCI/volume/candle-PA) ให้ "ออกไม้น้อยแต่แม่นขึ้น" (C) MTF: ออกไม้ดีแล้วดู higher-TF (เลือกมากขึ้น) / lower-TF (ไม้เยอะขึ้น). **doctrine ต่อยอด: ต้อง base ที่มี flat-lot edge จริงก่อน (เหมือน split/pending — filter เติม precision ไม่สร้าง edge).**

**Phase A — coverage (symbol×TF ของ validated EAs):**
- **batch 1 MacdDiv DONE(Claude 2026-07-18) = ❌ ไม่ travel (0 new legs) · `_mt5_auto/MDX_EXPAND.csv`:** smoke พบ GBPUSD H4 1.08/1.05 (config XAU) ดูน่าสน → validator funnel = REJECT-as-tested (GBPUSD H4 fixed-RR, holdout 0.55) → **last-optimize TF lever (กฎใหม่) = 🅿️ PARKED-VERIFY(user): GBPUSD D1 = 1.45/1.23 both-window (pulse จริง!) thin 25t · H2 1.09/0.96 marginal · H1 reject** (`MDXTF_GBP.csv`). **กฎ last-optimize คุ้มทันที — กัน GBPUSD ตาย final ทั้งที่ D1 มี edge (แค่ thin, ซึ่ง D1 ปกติไม้น้อย)** → flag user: D1 น่าลอง funnel เบาๆ (optimize D1 + holdout) ถ้าอยากได้ leg reversion GBP. XAU H2 marginal+redundant · USDJPY H4 0.97 WATCH · rest dead. **บทเรียน: MacdDiv edge = XAU-H4-specific ไม่ travel** (ไม่ใช่ทุก validated EA ขยาย symbol ได้ — ต้องผ่าน holdout ไม่ใช่แค่ smoke both-window). set `_mt5_auto/ab_sets/order117_gbp/` · raw `MDX_GBP_H4_VALIDATE.csv`. **process win: holdout ทำงาน.**
- **batch 2 SuperTrend RUNNING(Claude 2026-07-18):** flat-lot PF 2.93 (edge แข็งกว่า MacdDiv → prior travel ดีกว่า) home XAU H4 → expand symbol×TF. bar เดิม (both-window + ต้องผ่าน holdout ตอน funnel ไม่ใช่แค่ smoke). next: IchiADX · (BRK) family.

**Phase B — precision-filter A/B (per validated EA, toggle default OFF = byte-identical):** เพิ่ม filter ทีละตัวแล้ว A/B on/off both-window. **bar: filter ต้องยก PF **และ** win% ทั้ง both-window — ถ้าตัดไม้เฉยๆ PF ไม่ขึ้น = decoration, park** (แพทเทิร์น 098-J OB-gate).
- **B5 candle/PA bar-strength DONE(Claude 2026-07-18) = ❌ REJECT (decoration/harmful) · `_mt5_auto/O117_FILTER.csv`:** เพิ่ม `_08_UseBarStrength` (breakout bar body≥MinBodyAtr×ATR) A/B บน XAU H1 breakout 40/5. barstr0.3 = REC 2.49→2.72 (win 45→47 ขึ้น) **แต่ BWD 1.75→1.18 (win 39→34 ลง)** = ยก trend แต่พัง chop = **regime-fragile ขึ้น** (ตรงข้ามที่ต้องการ) · 0.5/0.7 พังทั้งคู่. nofilter สมดุลกว่า. **บทเรียน: breakout มี ATR-expansion+EMA200 filter อยู่แล้ว → candle-gate = over-filter.** filter น่าจะได้ผลกับ EA ที่ยัง**ไม่มี**filter (raw signal) มากกว่า breakout ที่ filter แน่นแล้ว.
- **B2 RSI-timing บน raw base (MacdDiv XAU H4) DONE(Claude 2026-07-18) = ❌ REJECT · `_mt5_auto/O117_RSI.csv`:** ใส่ `_07_UseRsiGate` (เข้า divergence เฉพาะตอน RSI ยืนยัน) A/B gate{45/55,40/60,50/50}. nofilter 1.56/1.04 → gate ดีสุด(40/60) 1.16/1.09 = **BWD ขึ้นนิดแต่ MAIN ร่วง 1.56→1.16** ไม่ยก both-window. **บทเรียนใหญ่: filter (candle+RSI) = decoration ทั้งคู่ แม้บน raw base — signal รีด edge หมดแล้ว, filter ตัดไม้ตามสัดส่วน (edge+noise พร้อมกัน) ไม่ selective.** filter-track = low-yield, park.
- **⚠️ caveat (subagent จับได้): `(EXP)_BRK_SplitRetest` hardcode PERIOD_H1/D1 ใน signal → chart-TF ไม่มีผล** = breakout EA นี้ **TF-expand ไม่ได้** ถ้าไม่แก้ code (D1 rows = duplicate ของ H4). breakout symbol-expand: FX majors (EURUSD/EURJPY/AUDUSD) reject, XAU/US30 = legs เดิม → **ไม่มี leg breakout ใหม่.**

**Phase C — TF re-home:** ต่อจาก Phase A — ตัวที่ผ่าน ลอง lower-TF (ไม้เยอะ, เช็ค precision ไม่หลุด) + higher-TF (เลือก, ไม้น้อยแต่ PF สูง) หา sweet spot.

**ห้าม:** filter/expand บน base ที่ flat-lot ไม่มี edge (สร้าง edge ไม่ได้ — บทเรียน split/pending) · verdict ก่อน both-window + (filter: win%↑ ด้วย) · deploy ก่อน holdout+corr · burst หลาย EA รอบเดียว (pace) · Model-2 เป็นเลขรายงาน · commit path-limited.

---

## ORDER-116 — CAMPAIGN: split-entry breakout — รีด lever (ORDER-108 validated) ให้ครบ portfolio (user 2026-07-18 "รีดออกมาทำยาวๆ") — `CORE DONE(Claude 2026-07-18) = split narrow lever, no new legs · conclusion _triage/_archive/verdicts/order104-126/ORDER116_CAMPAIGN_CONCLUSION.md · Phase 3 (London retrofit) = optional low-prior residual`

**สรุป (conclusion เต็ม `_triage/_archive/verdicts/order104-126/ORDER116_CAMPAIGN_CONCLUSION.md`):** split = **narrow config-refinement ไม่ใช่ portfolio-wide upgrade / leg-generator.** ✅ Phase 1: XAU 40/5-split regime-robust (2.40/1.96 · full PF 2.26/149t/DD3.9% · **MC PF_5th 1.71 ruin0%**) = chop-robust กว่า live Bars55 (1.99/1.12) **แต่ corr 0.861 vs XAU-BRK leg = same-slot redundant** → replacement candidate ตอน XAU re-opt ไม่ใช่ leg เพิ่ม. ❌ Phase 2: ไม่เปิด leg ใหม่ (US30=ORDER-095 leg+spike · XAG/GBP/NAS dead). **doctrine: pending/split = weak-window-filler บน base ที่มี both-window edge + asymmetric weak window เท่านั้น — เช็ค base edge ก่อน.** residual: Phase 3 retrofit London/CB_GBP (build task, low-prior — GBP generic-Donchian ไม่มี edge แล้ว, value อยู่ที่ session-logic ของ London เอง) · Phase 4 (Bars55 TP) ORDER-108 ปิดแล้ว.

### ORDER-116 Phase 1 RESULT (Claude 2026-07-18) — verdict `_triage/_archive/verdicts/order104-126/ORDER116_PHASE1_VERDICT.md` · raw `_mt5_auto/O116_P1.csv`
offset sweep XAU H1 Bars40/TP5 both-window Model-4 (D:\Meta 5). **split ยกหน้าต่างอ่อน (BWD chop) 1.75→~1.96** แลก REC นิด (2.49→2.33-2.40) = regime-robust (คอนเฟิร์ม ORDER-108 บน tick ใหม่). **plateau offset ∈ {−0.30,−0.15,0.00}** · +0.15 ตก (retest ตื้นไป BWD 1.67) → edge อยู่ฝั่ง retest ลึก. bar ผ่าน (≥1.80 both). **LOCKED RECIPE = split 0.02mkt/0.01pend · RetestOffset −0.15 · Expiry 5** (`BRK40_split_offm0p15.set`). → Phase 2: พก recipe ไป GBPUSD/EURUSD/US30/XAG both-window หา leg ใหม่ (≥1.4 both + corr<0.8).

**ที่มา:** ORDER-108 พิสูจน์ split-entry (market leg เก็บ runner + pending retest leg fill maker ~90%) = **lever จริงเพิ่ม regime-robustness** แต่ **config-conditional**: ยก Bars40/TP5 (1.93/1.97 both-window) · ไม่ยก Bars55/TP8 live (retest leg อ่อน BWD). กติกา: **split ช่วยก็ต่อเมื่อ retest leg มี edge ในหน้าต่างที่ market อ่อน** (ขึ้นกับ TP-width × lookback). EA `(EXP)_BRK_SplitRetest` = generic Donchian breakout, input ATR-relative → รันข้าม symbol ได้. ห้าม: แปะ EA ที่ปัญหา = regime ไม่ใช่ entry-cost/timing (XAU_NY).

**เป้า campaign:** map envelope ของ lever + หา **breakout leg ใหม่ที่ split ทำให้ regime-robust** (diversification) + retrofit demo config ที่ยกได้. Model-4 บังคับ (pending fill = tick-sensitive) → **รันบน D:\Meta 5 non-portable** (Meta5b portable เขียน report M4 ไม่ออก — บทเรียน D1g). ทุก phase = 1 experiment ใน event log (adoption guide RE-fixes ทำให้ลื่นแล้ว).

**Phase 1 (batch 1, this session): retest-param sweep บน working config (XAU H1 Bars40/TP5)** — หา "retest recipe" ที่ดีที่สุดก่อนพก symbol อื่น. sweep `_07_RetestOffsetAtr {−0.3,−0.15,0,+0.15}` @ `_07_ExpiryBars=5`, split 0.02mkt+0.01pend, both-window Model-4. reference = market-only (2.07/1.75 จาก ORDER-108). **pre-registered bar:** offset ที่ให้ split ≥1.80 **both-window** (ไม่มี weak window) + retest fill-rate ≥80% = recipe ผ่าน → พก Phase 2 · ถ้าไม่มี offset ไหนยก BWD เหนือ market-weak = lever แค่ robustness-neutral, ปรับแผน Phase 2 เป็น config-rebalance · negative offset (retest ลึก=ราคาดีขึ้นแต่ fill น้อย) = สมมติฐานหลักว่าจะยก retest edge.

**Phase 2 DONE(Claude 2026-07-18) = ❌ CLOSED NEGATIVE (split เปิด leg ใหม่ไม่ได้) · verdict `_triage/_archive/verdicts/order104-126/ORDER116_PHASE2_VERDICT.md` · raw `_mt5_auto/O116_P2.csv`+`O116_P2B_PLATEAU.csv`:** พก recipe ไป US30/NAS100/XAG/GBPUSD both-window Model-4. **US30 ≠ leg ใหม่** — ORDER-095 validate ไปแล้ว (H4 1.46/1.39, **corr vs XAU −0.249 additive PASSED**, staged 991005 WATCH-thin) · my plateau check เผย **US30 40/5 = SPIKE ไม่ใช่ plateau** (neighbor ตก <1.2 both / tp4-tp6 invert, thin 24-39t) → **991005 คง WATCH spike-fragile (feed back ORDER-095)** · split บน US30 = 1.54/1.38 ไม่ยก (market-only ไม่มี weak window ให้เติม). XAG (BWD 0.56, split DD 17%) + GBPUSD (<1) = dead · NAS100 no data. **doctrine sharpened: split เติม weak window เฉพาะ base ที่มี both-window edge + asymmetric weak window (XAU 40/5 trend2.49/chop1.75) — base สมดุลอยู่แล้ว/ไม่มี edge = ไม่ช่วย.** → **Phase 3 (pivot): validate Phase-1 XAU 40/5-split (2.40/1.96 regime-robust) เป็น demo config** — corr vs XAU legs เดิม + MC + holdout (additive หรือ replacement ของ Bars55 chop-weak 1.99/1.12?).
**Phase 3:** retrofit LondonConso (GBP) + CB_GBP — build split เข้า code, A/B ว่ายก demo config ไหม.
**Phase 4:** config-rebalance — config ที่ split ไม่ช่วย (Bars55/TP8) ลอง TP แคบลง + split เทียบ market-only live.
**Phase 5:** EDGE_CATALOG + demo-config upgrade ที่ผ่าน holdout.

**ห้าม:** verdict ก่อนครบ both-window + fill-rate · retrofit ตัว live โดยไม่ผ่าน holdout · burst หลาย phase รอบเดียว (pace 1 batch) · Model-2 เป็นตัวเลขรายงาน · commit path-limited ผ่าน hook.

---

## ORDER-091C-D1g — JUMSTOCH pending-limit + TP-widen A/B บน confirmed-edge base (closes ORDER-080 + user 2026-07-16 full hypothesis) — `DONE + REVIEWED (Claude 2026-07-17) = NULL (keep config) · ORDER-080 CLOSED · event-log dogfood #1 complete`

### D1g RESULT + VERDICT (Claude 2026-07-17) — verdict เต็ม `_triage/ORDER091C_D1G_VERDICT.md` · raw `_mt5_auto/D1G_AB_RESULTS.csv`
**regression cage PASS** (EntryMode=0 = original byte-behavior: PF 1.34/869t เป๊ะ + ตรง 07-11 baseline). ทั้ง 2 lever ทำงานจริง (เปลี่ยน trade count ได้) → null = ผลจริงไม่ใช่ toggle ตาย. **Model-4 เขียน report ไม่ออกบนกล่องนี้ → Model-1 (amended, pre-result, logged AMENDMENT_ADDED).**
- **Pending-limit = NULL:** EURGBP H1 มาร์เก็ต 1.48/1.03 → pending 1.49/1.00 (Δ +0.01/−0.03) · NZDUSD H4 **identical ทั้ง 2 window**. กลไก: JUMSTOCH grid-add เข้าเมื่อ `ask≤trigger` อยู่แล้ว = ไม่จ่าย spread เกิน trigger → แปลงเป็น limit ที่ระดับเดิม = ไม่ประหยัดอะไร (แย่กว่านิดตอน gap). **premise "grid จ่าย spread เยอะ" ไม่ใช้กับ EA ที่ entry เป็น trigger-touch อยู่แล้ว.**
- **TP-widen = inert/noise:** +2 identical, +5 = +0.01-0.02 both-window (ผ่านบาร์ ≥baseline แต่ noise-level, DD เท่าเดิม). กลไก: JUMSTOCH exit ด้วย BEP+trailing ไม่ใช่ raw TP.
- **DECISION (config only):** คง demo config JUMSTOCH เดิม (market entry, TP เดิม) — ไม่มี lever คุ้มให้เปลี่ยน validated config. JUMSTOCH ยัง demo-eligible ตาม 07-11 (order นี้ไม่แตะ).
- **doctrine banked:** pending-limit rescue = ใช้กับ EA ที่ entry **market-on-signal** (จ่าย spread) เท่านั้น — **ห้ามใช้กับ grid ที่เข้าที่ trigger-touch** (ไม่มี spread ให้ประหยัด). รวมกับ D1d → **pending doctrine characterized ครบ · ORDER-080 CLOSED.**


**ที่มา:** D1d (07-16) วัด pending-save บน LWMA proxy ที่ **ไม่มี edge** → พิสูจน์ได้แค่ magnitude (~+0.05 PF/ไม้) ไม่ใช่คุณค่าจริง + TP-widen ครึ่งหลังของ user ยังไม่รัน. `_triage/_archive/one_off_analyses/PENDING_LIMIT_SYNTHESIS.md` สั่งชัด: "หา reversion base ที่ near-breakeven มาเป็น demonstrator". **JUMSTOCH = demonstrator นั้น** — thread D1→D1f REVIEWED = demo-ready, **flat-lot PF 1.18 (edge จริง ไม่ใช่ martingale artifact)**, capped-SL'd reversion grid เทรด 869-3272 ไม้/window = จ่าย spread เยอะ = ตรงเป้า maker-save. นี่คือที่เดียวที่ +0.05 PF/ไม้ × ไม้เป็นพันจะเห็นผลจริง บน base ที่ candidate อยู่แล้ว.

**scope (สำคัญ — VERDICT GATE):** นี่เป็น **refinement-lever test บน EA ที่ผ่าน full funnel แล้ว** (D1-D1f) ไม่ใช่ EA-life verdict → ตัดสินแค่ **demo CONFIG** (market vs pending entry · TP setting) ของ JUMSTOCH ที่ demo-eligible อยู่แล้ว. ไม่ใช่ตัดสินว่า JUMSTOCH ตาย/รอด.

**คำสั่ง:**
1. build `(EXP)_JUMSTOCH_Pending.mq5` = copy MT5 baseline + เพิ่ม **2 lever inputs เท่านั้น**: `EntryMode` (0=market baseline / 1=pending-limit) + `TP_Widen_Pips` (บวกเข้าทั้ง g_TP + Tp_from_Bep). **market path (EntryMode=0) = byte-identical original** (= regression cage). pending: grid-add → BuyLimit/SellLimit ที่ trigger price เดิม (fill ~100% ประหยัด spread ล้วน) · initial entry → limit-at-touch · จัดการ cancel/expire pending + magic-scope. **ห้ามแตะ** lot/SL/Range/Level_Max/signal/exit.
2. compile 0/0 + mql-code-reviewer (pending-order mgmt = bug surface).
3. **regression cage ก่อน A/B:** EntryMode=0/TP+0 บน EURGBP H1 both-window Model-4 → ต้อง reproduce 07-11 baseline (±tolerance) มิฉะนั้น refactor drift = หยุดแก้.
4. A/B Model-4 (mandatory — pending fill = tick-path-sensitive, **ห้าม Model-2**): market vs pending บน EURGBP H1 (primary) + NZDUSD H4 (secondary), both-window continuous span (recent 2023.01-2026.07 + BWD 2020.01-2022.12).
   **🔧 AMENDMENT 2026-07-17 (ก่อนเห็น A/B PF ใดๆ — tooling constraint ไม่ใช่ peak-hunt):** Model-4 บนกล่องนี้ **รันไม่ออก report** (test รันจบจริง—journal เห็น trade—แต่ terminal+local-agent ไม่เขียน .htm; Model-1 เขียนปกติ). ตรงกับ 07-11 D1f ที่ JUMSTOCH ทั้งสายใช้ Model-1. → **ลด Model-4 → Model-1** (M1-OHLC จับ "ราคาแตะ limit level ในบาร์ไหม" ได้ = พอสำหรับคำถาม pending-fill; residual caveat = tick-ordering ภายในนาที ไม่ถูกจำลอง). **ห้าม Model-2 ยังคงอยู่.** บันทึกเป็น AMENDMENT_ADDED event (target = BAR_PREREGISTERED).
5. ถ้า pending มี lift → เพิ่ม TP-widen arm {+0,+2,+5 pip}.
6. วัด **PF + net-EV/ไม้ + fill-rate** (ไม่ใช่ net$ เดี่ยว — pending เทรดน้อยลง = exposure น้อยลง หลอกได้; ไม่ใช่ PF เดี่ยว) + basket-continuous MC.

**pre-registered bar (ล็อกก่อนเห็นผล):**
- **CONFIRM (pending adopted):** pending net-EV/ไม้ > market net-EV/ไม้ ที่ spread จริง บน ≥1 home **both-window** (หลังหัก opportunity cost ของไม้ที่ไม่ fill) AND basket PF ไม่แย่ลง → ปรับ demo config JUMSTOCH เป็น pending entry, จด delta.
- **NULL (no lift):** pending net-EV/ไม้ ≤ market ในกรอบ noise หรือ fill-loss หักล้าง spread-save → คง market entry, จดว่า JUMSTOCH ไม่ได้อะไรจาก pending (สอดคล้อง D1d generic +0.05 = immaterial ที่นี่).
- **TP-widen:** ปรับได้ก็ต่อเมื่อ PF และ net-EV **ทั้งคู่** ≥ baseline ที่ +2 หรือ +5 both-window; ไม่งั้นคง TP เดิม.
- **middle:** lift window เดียว = regime-fit → park lever ไม่ adopt.

**ห้าม:** เปลี่ยน lever อื่นนอก {EntryMode, TP_Widen_Pips} · Model-2 เป็นตัวเลขรายงาน · เชื่อ A/B ก่อน regression cage ผ่าน · ตัดสิน JUMSTOCH ตาย/รอดจาก order นี้ (scope = config เท่านั้น) · commit tag `[claude] D1g ...` path-limited ผ่าน production hook.

**event-log dogfood:** เดิน chain IDEA→HYPOTHESIS→BAR(pre-reg)→RUN→RESULT→REVIEW→DECISION ตาม `docs/memory_control/EVENT_LOG_ADOPTION.md` (experiment แรกที่ใช้จริง — เจอ rough edge = แก้ adoption guide). exp id + evt ids จด inline ตอนปิด.

---

## ORDER-095 — CAMPAIGN: ขยาย symbol ให้ EA ที่ deploy อยู่แล้ว (user 2026-07-11: "ขยายผลไปตัวที่ demo อยู่ ได้อีกเยอะ") — `OPEN (multi-session, pace 1 EA/batch) · batch 1 DONE(Claude 2026-07-14): EA_BREAKOUT_XAU → USDJPY (PF 1.28/1.25) + US30 (1.46/1.39 WATCH-thin) demo-eligible · bundles staged _vps_deploy/EA_BREAKOUT_USDJPY (991003) + EA_BREAKOUT_US30 (991005) · verdict = _triage/ORDER095_BREAKOUT_XAU_EXPAND_VERDICT.md` ⚠️ **US30 991005 UPDATE (ORDER-116, 2026-07-18): plateau check เผยว่าเป็น SPIKE ไม่ใช่ plateau** (b30/b50 ตก <1.2 both · tp4/tp6 invert · thin 24-39t) → **คง WATCH/small, ห้าม graduate จาก single-cell evidence** (ดู `_triage/_archive/verdicts/order104-126/ORDER116_PHASE2_VERDICT.md`)

**หลักการ (build-on doctrine + multi-symbol reuse):** EA ที่ deploy แล้ว = validated ที่ home เดียว · ขยายไป
symbol อื่นที่ผ่านเกณฑ์ (corr < 0.8 ระหว่างกัน) = เพิ่มไม้โดยไม่ต้องหา EA ใหม่.

**⛔ CAVEAT ชี้ขาด (lead judgment — ขยายผิดตัว = กระจายทางแพ้):** ขยายได้เฉพาะ EA ที่ **entry มี edge จริง
(flat-lot PF>1)** เท่านั้น. EA ที่ entry ไม่มี edge = ขยาย symbol ยิ่งเพิ่มวิธีเสียเงิน:
- ✅ **ขยายได้ (source + flat-lot edge ยืนยัน):** EA_BREAKOUT_XAU (breakout, real, travels) · Boss_14_GridLog
  (demo flagship, 7 symbol แล้ว) · EA_SUPERTREND (flat-lot PF 2.93 — pending demo) · CB_GBP ConsoBreakout ·
  NuiIndy Dynamic RSI+ADX (source อยู่ .Final EA)
- ❌ **ห้ามขยาย (entry ไม่มี edge — กำลังถอดอยู่แล้ว):** RSI-MR (flat-lot 0.78) · ST_EA03 family (0.68/0.40) ·
  ST03 replica — พวกนี้ถอดเพราะ entry ไม่มี edge → ขยายยิ่งผิดหลัก
- ⚠️ **compiled-only (.ex4 รันได้แก้ไม่ได้):** UnNomGuai/swb/RSI-orig (MT4 demo) = ขยายแบบ run-as-is บน symbol
  อื่น + corr check (flat-lot check = ปิด escalation input ถ้ามี) · Zeus/Kangaroo = martingale locked, Zeus เปราะ
  (stop-out gold) → ไม่ขยาย

**Methodology ต่อ EA (เหมือน JUMSTOCH D1c):** (1) flat-lot smoke บน symbol candidate ที่ยังไม่ deploy → เอาที่
entry PF>1 (2) full-config IS/OOS บนตัวที่ผ่าน (3) corr equity-curve vs leg เดิม → เก็บ corr<0.8, คู่ >0.8 บอก user
(4) เพิ่มเข้า demo config. **pace 1 EA/batch** · Boss_14 = ตัวแรก (D1c-สไตล์)

## ORDER-097 — build "(HEX)_HexaGrid" (user สั่งเขียนจากสเปคเอง 2026-07-11) — build `DONE(Claude, 2026-07-11)` · baseline `DONE(Claude, 2026-07-11)` · funnel `CLOSED (Claude 2026-07-14 — STRUCTURAL DEAD: sweep spacing×SL ไม่ช่วย + flat-lot isolate S1-S6 ไม่มีระบบไหนมี edge เดี่ยว (ดีสุด 0.80/0.76) · ปัญหาอยู่ที่ entry ทั้ง 6 ไม่ใช่ chassis · verdict = _triage/_archive/verdicts/order076-098/ORDER097_HEX_FUNNEL_VERDICT.md) + REVIEWED(Claude/Opus 2026-07-26)` _(renumbered 096→097: ชนกับ CAMPAIGN ORDER-096 WOBR)_

**ที่มา:** user ส่งสเปค HexaGrid เต็ม (6 ระบบอิสระ magic-scoped แชร์ grid engine ×1.33 cap 10 + SL จริงทุกไม้,
regime EMA224-slope+ADX, 7 ชั้นจัดการ+global cap) แล้วสั่ง "เขียน EA ตัวนี้ + รอรันเลย" (optimize เองไม่ได้ — คอมเต็ม).
brainstorm → standalone-port (core เดิม single-magic global-state #include ตรงไม่ได้) → user เคาะ standalone.

**สถานะ build (DONE):**
- source: `ea_projects\(HEX)_HexaGrid\(HEX)_HexaGrid_rev01.mq5` · compiled: `(HEX)_HexaGrid_rev01.ex5`
  (อยู่ในโปรเจกต์ + deploy แล้วที่ `D:\Meta 5\MQL5\Experts\HEX_HexaGrid_rev01.ex5`)
- **compile 0 errors / 0 warnings** (MetaEditor64, X64 Regular)
- ผ่าน mql-code-reviewer: ไม่มี BLOCKER · แก้ 2 HIGH (sys4 ADX-only ไม่โดน slope-gate · g_suppress_log optimize)
- **RISK CLASS L4** (capped-martingale+grid, ไม่มี rescue-hedge) — user รับทราบ (เลือก global cap 18% เอง)
- default = conservative UNOPTIMIZED (spacing ATR-adaptive multi-symbol, risk 2%/basket, mult 1.33, maxLevels 10)

**⚠️ GOTCHA ก่อนรัน (บันทึกไว้กันเสียเวลา):**
1. **ต้องบัญชี HEDGING เท่านั้น** — OnInit มี guard: ถ้า `ACCOUNT_MARGIN_MODE != RETAIL_HEDGING` = INIT_FAILED
   (netting จะ merge 6 ตะกร้าทับกัน). **เช็ค log หา `[HEX][FATAL]` ก่อนสรุป 0 trades = code bug** — ต้องมั่นใจ
   server ของ terminal ที่รัน tester เป็น hedging ก่อน
2. `_06_AllowLive=false` default แต่ tester-gate เปิดอัตโนมัติ (รัน Strategy Tester ได้เลย)
3. weekend-cut `_G_CutHourServer=12` เป็น proxy 19:30 ไทย — ปรับตาม GMT offset ของ feed ที่เทสถ้าจะเอาชั้นนี้

**คำสั่ง (baseline ก้อนแรก — both-regime, coarse Model 1 ก่อน, 1 symbol × 2 window ตาม pacing):**
```powershell
# ยืนยัน hedging ก่อน แล้วรัน 2 window (trend BWD + recent). แทน window ทีละรอบ:
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'HEX_HexaGrid_rev01' -Symbol XAUUSD -Period H1 -FromDate 2020.01.01 -ToDate 2022.12.31 -Model 1 -Deposit 10000 -Leverage 100 -ReportName HEX_BASE_XAU_BWD -Portable -Terminal 'D:\Meta 5\terminal64.exe'
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'HEX_HexaGrid_rev01' -Symbol XAUUSD -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -Deposit 10000 -Leverage 100 -ReportName HEX_BASE_XAU_REC -Portable -Terminal 'D:\Meta 5\terminal64.exe'
```
**Acceptance (raw เท่านั้น — ห้าม verdict, lead ตัดสิน):** 2 report เข้า `_mt5_auto\reports\` · ต่อ window append:
PF · net profit · trades · maxEqDD% · maxBalDD% · + **ยืนยันว่า OnInit ไม่ FATAL (มี trade เกิดจริง)** ·
สังเกตว่าระบบไหน (magic 20260707-13) มี trade บ้างจาก comment/journal · commit `[tag] ORDER-097 baseline done`

### ORDER-097 BASELINE RESULT (Claude, 2026-07-11) — raw + lead note (NOT a kill-verdict)
Runner `scripts\mt5_run.ps1 -Portable` บน `D:\Meta 5` (account 146237 = **hedging ✅**, guard ผ่าน — EA รันจริง
ไม่ FATAL). **Model 1 coarse** (control-points, optimistic สำหรับ grid), default compiled inputs (no .set),
deposit 10000, leverage 1:100, XAUUSD H1. report เขียนลง `D:\Meta 5\HEX_BASE_XAU_{REC,BWD}.htm` (portable
เขียน root — mt5_run แจ้ง "NO REPORT" เพราะหาผิดที่ แต่ไฟล์มีจริง + test "successfully finished").

| window | PF | Net$ | Trades | Bal-DD | Eq-DD | Sharpe |
|---|---:|---:|---:|---:|---:|---:|
| recent 2023.01–2026.07 | 0.97 | -2,224 | 12,403 | 56.80% | 57.95% | -0.31 |
| BWD trend 2020.01–2022.12 | 0.88 | -5,937 | 9,099 | 65.04% | 65.44% | -1.38 |

**Lead note (ยังไม่ใช่ verdict — VERDICT GATE ยังไม่ครบ: sweep 0 lever, 1 symbol, 1 TF):**
- **default config = NO EDGE ทั้งสอง regime** (PF 0.88–0.97 แม้ Model-1 optimistic → real-tick น่าจะแย่กว่า) → **ยังไม่ผ่านบาร์เข้ารอบ Model-4**
- **DD 57–65% = ตรงกับ worst-case ~60% ที่ flag ตอน build เป๊ะ** · global cap 18% คุมได้แค่ floating ชั่วขณะ ไม่กัน cumulative bleed เมื่อ edge ติดลบ
- **12k/9k trades = spacing แน่นเกิน / 6 ระบบยิงพร้อมกันถี่มาก** — สมมติฐานแรกที่ควร sweep: ขยาย `_G_SpacingATRmult`/`_G_SL_ATRmult` + ลดจำนวนระบบที่เปิดพร้อมกัน
- **ไม่ตีตาย (PARAMETRIC):** unoptimized/1-symbol/coarse → tag **build-on / PARKED-VERIFY(user)** ไม่ใช่ DEAD · แต่ห่างบาร์พอควร ไม่ใช่เฉียด
- **บล็อกจริง:** user optimize ไม่ได้ (คอมเต็ม) → funnel ที่เหลือรอพื้นที่ว่าง. ถ้าเปิดได้: sweep spacing×SL×system-count → both-regime → ถ้าโผล่ PF>1 ค่อย Model-4 real-tick → OOS → MC

**ห้าม:**
- **ห้ามตัดสิน edge จาก Model-1 pass** — grid fill-sensitive, Model-1 optimistic; ผ่าน M1 = แค่ "ผ่านเข้ารอบ Model-4"
  ไม่ใช่ candidate (VERDICT GATE #6 + doctrine grid-EA ต้อง real-tick confirm)
- ห้าม tune ก่อนเห็น baseline both-regime (VERDICT GATE #3)
- ห้ามขยาย symbol×TF เต็มก่อน baseline โชว์ชีพจร (ถ้า XAU both-window PF>1 coarse → ค่อยเปิด funnel: Model-4 real-tick
  → OOS split → MC ตาม robustness-validator · ถ้าติดลบทั้ง 2 window = กลับมาดู logic/default ก่อน ไม่ใช่ tune หนี)
- ถ้า INIT FATAL (ไม่ใช่ hedging) = **หยุด แจ้ง user** ว่าต้องเทสบนบัญชี/เทอร์มินอล hedging ห้ามแก้ guard ออก

---

## ORDER-098 — CAMPAIGN: fxDreema YouTube corpus build-on — `OPEN` (multi-session · user prioritizes ใน session เดียวก่อนลงมือหนัก)

**ที่มา (2026-07-12):** แกะช่อง @fxdreemalearner ครบ 320 คลิป → catalog กลไก 272 EA. ผล + shortlist เต็ม =
`_triage/fxdreema_youtube/BUILDON_SHORTLIST.md` (+ `CATALOG.jsonl` · `DIGEST.txt`). pipeline/สถานะ = memory
`fxdreema-youtube-corpus`. toolchain แกะคลิปเพิ่ม = `scripts/yt2text.ps1` (memory `yt-whisper-toolchain`).

**Doctrine ที่บังคับทุก sub-order (paid rules):**
- เกือบทุก EA = chassis ST03 (entry→grid→trailing→no-SL). **flat-lot probe = ด่านแรกบังคับทุก entry** —
  ปิด escalation (single order, fixed lot, SL/TP) แล้ว PF ยัง >1 ไหม. ST03-dead vs Kangaroo-edge แยกตรงนี้.
- **ห้ามตัด grid/martingale ทิ้ง** (user doctrine [[feedback-buildon-pf-gt-1]]) — ขุด entry + MM part มาแปะ
  chassis ที่ validated แล้ว (MatchaGrid bounded+SL · Kangaroo DD-release · JUMSTOCH capped-SL'd reversion grid).
- ตัวเลข % ในการ์ด = คำอ้างคนสอน **ยังไม่ verify** — guilty until flat-lot + funnel proves.
- VERDICT GATE เต็มใช้ตามปกติ (≥3 lever × ≥2 TF ก่อน reject · both-regime · holdout+MC ก่อน deploy).

**Sub-orders (A/B พร้อมรัน · C = library · user เลือกลำดับ):** 098-A FVG-fill entry · 098-B MACD-divergence entry ·
098-C reusable MM-parts. **ห้ามเริ่ม build campaign เต็มจนกว่า user เคาะลำดับใน session ที่นัดไว้** — sub-orders
ด้านล่าง stock ไว้ให้พร้อมเฉยๆ.

---

## ORDER-098-A — FVG-fill entry (EX009 algo) flat-lot smoke — `CLOSED — REJECT (Claude 2026-07-16): naked FVG-fill ไม่มี edge — 22 runs ครบ BWD both-regime (0.79-0.88) + RR sweep TP{15,20,25,30,40,60}: PF ไต่ถึง 0.97-0.98 แล้วหักลงที่ TP40/60 = cost-dilution ไม่ใช่ edge, ไม่เคย PF>1 สักครั้งใน 26 cells → ไม่เข้า build-on doctrine · ปิดเฉพาะ naked-entry บน EUR/XAU H1/H4 — FVG-as-filter ยังเปิดใน EDGE_CATALOG · verdict เต็ม = _triage/_archive/verdicts/order076-098/ORDER098A_FVGFILL_SMOKE_VERDICT.md · ดิบ = _mt5_auto/order098a_bwd_rr.csv` (role: Claude/Sonnet build → agent smoke)

**ทำไม:** FVG/ICT-zone (24 การ์ด) = angle ใหม่จริงที่ยังไม่มีใน landscape (มีแค่ PARKED-CONCEPT จาก FB reel ไม่มีตัวเลข).
ทดสอบว่า **entry เปล่าๆ มี edge ไหม ก่อนแตะ grid/MM** (flat-lot probe).

**สเปค entry (จาก EX009 + EX196):**
- FVG bullish = `Low[1] > High[3]` (ช่องว่าง 3 แท่ง) · เข้าเมื่อ `Close[0]` ย้อนกลับมาปิด *ใน* ช่อง (ระหว่าง High[3]..Low[1])
  + ยืนยัน bullish engulfing (body[0] > body[1]) · mirror สำหรับ SELL (`High[1] < Low[3]`)
- **flat-lot บังคับ: single order, fixed 0.01, SL 20 pip / TP 15 pip** (ตาม EX009) — **ไม่มี grid ไม่มี martingale**
- bar-open gate + digit-aware pip + magic-scoped (ผ่าน `mql-code-reviewer` ก่อน compile)

**คำสั่ง:** build `ea_projects/(EXP)_FVGFill_Naked/` → compile headless → smoke Model 1, 2023.01-2026.01:
EURUSD H1 · EURUSD H4 · XAUUSD H1 · XAUUSD H4 (4 cells).

**Acceptance:** ตาราง 4 แถว (PF · Trades · EqDD% · Win%) append ใต้ order นี้ + path report ดิบ. commit `[tag] ORDER-098-A done`.
**ห้าม:** ใส่ grid/martingale ก่อน flat-lot PF ผ่าน · ตัดสิน dead ก่อนครบ VERDICT GATE (≥3 lever × ≥2 TF) ·
เขียน verdict (นั่นงาน lead) · Model-2 tight-TP (TP 15pip อาจ < spread บน XAU → ใช้ Model 1 + ตรวจ spread-artifact).

---

## ORDER-098-B — MACD-divergence entry (EX154/EX010 algo) flat-lot smoke — `CLOSED — DEMO-ELIGIBLE (Claude 2026-07-16): 🥇 XAU H4 ผ่านครบทุกด่าน funnel — MAIN plateau 1.91 (9 neighbor ไม่มีตัวขาดทุน) · BWD 1.04 · HOLDOUT 1.30 · Model-4 real-tick 1.89/0.97/1.28 (edge จริงไม่ใช่ fill artifact) · MC ruin 0% · corr gate max|corr|0.555<0.8 (additive) · bundle staged _vps_deploy/MACDDIV_XAU magic 999094 (tester-gate จริง set AllowLive=true) → WAITING-USER attach · EUR H4 HOLDOUT FAIL 0.35 → PARK · H1 ปิด cell · verdict = _triage/_archive/verdicts/order076-098/ORDER098B_MACDDIV_VERDICT.md` (build+opt = Codex 2026-07-15 · funnel+M4+corr+bundle = agent/Claude 2026-07-16)

**ทำไม:** MACD *divergence* (price LL / MACD HL) ≠ naked MACD-cross ที่ตายไปแล้ว = reversion signal ที่ยังไม่เคย smoke.
EX120 เสริม volume-confirm + low-freq (RR 1:3-1:5).

**สเปค entry:** bullish divergence = price ทำ lower-low แต่ MACD main ทำ higher-low (lookback N swing) · เข้า BUY ·
mirror SELL · **flat-lot single order fixed 0.01, SL = 3-bar extremum, TP = 200% SL** (จาก EX113/EX013 RR 1:2).

**คำสั่ง:** build `ea_projects/(EXP)_MacdDiv_Naked/` → compile → smoke Model 1 2023.01-2026.01:
EURUSD H1/H4 · XAUUSD H1/H4 (4 cells).

**Acceptance:** ตาราง 4 แถว (PF/Trades/EqDD%/Win%) + report path. commit `[tag] ORDER-098-B done`.
**ห้าม:** grid ก่อน flat-lot ผ่าน · verdict · reject ก่อนครบ gate.

---

## ✅ MANDATORY REVIEW GATE — order ที่ 4 ครบ + C1-ENFORCE ปิด (gate ปลดล็อก 2026-07-14, §20.2 #5)
ทบทวนต่อ component (ผ่าน Codex blind review รวม ~15 รอบตลอด build — จับ defect จริงทุกใบที่ Opus self-verify พลาด):
| component | verdict | หมายเหตุ |
|---|---|---|
| **A** ORDER-099 (B0 baseline + owner map) | **ACCEPT** | 3 Codex rounds · cohort/evidence/reproducibility ปิด |
| **B** ORDER-100 (execution harness) | **ACCEPT (MVP-0)** | 3 rounds · 22/22 · 1 documented alias-limit (fix ก่อน deploy harness ขับ MT5 จริง) |
| **C0** ORDER-101 (read-only reconcile + validator) | **ACCEPT** | 3 rounds · validator ถาวร (review-linkage + living-log) |
| **C1** ORDER-102 (migration) | **DATA ACCEPT · ENFORCEMENT REWORK** | migration ถูก 0 history lost · แต่ append-tamper hole + no fail-closed hook + Source-A broad + atomicity (ดู block บน) |
| **C1-ENFORCE** ORDER-103 (write-path hardening) | **ACCEPT (Claude 2026-07-14)** | 6 rework + 6 blind Codex round (round 5 แรกที่ 0-blocker · round 6 = ACCEPT) · append-chain + fail-closed hook + Source-A exact-binding ปิดครบ · 41/41 negTest · commit `c0f7b0d` — **C1 enforcement REWORK ปิดสมบูรณ์** |

**§20.4 review-gate checks:** critical money/live incidents = **0** · source-of-truth conflicts = **0** (index → generated read-only, §20.7 compliant) · missing evidence = **0** · rollback ทำได้ไม่เสีย canonical evidence (git history intact) · incomplete work named honestly = **C1 enforcement** (append-chain + fail-closed hook + Source-A binding + hash-object) แตกเป็น bounded order ถัดไป.

**§20.2 #5 — ✅ GATE ปลดล็อกแล้ว (2026-07-14):** C1 enforcement REWORK ปิดสมบูรณ์ผ่าน ORDER-103 (C1-ENFORCE) — commit `c0f7b0d`, blind Codex review round 6 = ACCEPT. write path tamper-safe เต็มแล้ว (append-chain integrity + fail-closed hook + Source-A exact-binding). → **Contract D (MVP-1-lite event-log) เปิดทางได้แล้ว**. _(ประวัติ: order ถัดไป = C1-ENFORCE, routing subagent build → Opus verify → blind Codex review; HANDOFF ที่ใช้ = `docs/memory_control/C1_ENFORCE_HANDOFF.md`; ประวัติ rework/review เต็ม = `docs/memory_control/CODEX_ORDER103_REWORK_RESULT.md`.)**
**บทเรียน:** self-verify ที่รันใน HEAD/session เดียว มองไม่เห็น non-determinism (#2) + ไม่ได้ทดสอบ corrupt-input path (#1) — Codex คนละ run/มุมจับได้. เพิ่ม negTests ครอบแล้ว.

---

## CR-TRACK — Control Room (ROADMAP Phase 4.5) — `CR-001 CLOSED + CR-002 first pass DONE (Claude 2026-07-19F)` · role: Claude lead (ops/evidence — no verdict authority touched)

> ไม่ mint เลข ORDER ใหม่ (กัน collision 135/136/137/138 ข้าม session) — track นี้อ้างเป็น CR-001..007 ตาม ROADMAP Phase 4.5.
> Records เต็ม: `_triage/_archive/attestations/CR002_ATTESTATION_REPORT_2026-07-19.md` + `_triage/_archive/attestations/CR002_EVIDENCE_RECONSTRUCTION_999094.md` · commits `50f9ff7b` `deead551` `e8d653a1`

- **CR-001 CLOSED:** `$cohort` hardcode ออกจาก `live_dashboard.ps1` → generate จาก `DEPLOYMENTS.csv` · checker 4/5 = generation-link guard · ทดสอบ `daily_monitor.ps1 -Force` เต็ม chain ผ่าน (auto-commit `5ef41b98`)
- **CR-002 first pass DONE:** owner ใหม่ `portfolio/ATTESTATION_MAP.csv` + snapshot v2 (attestation/unknown_magics/judge_cohorts) · 18/40 hashed · 20 NO_BUNDLE · promotion-evidence reconstruction 999094 พิสูจน์แล้ว (+6 evidence-manifest, Scan valid)
- **WAITING-USER (จาก report §2-3):** (1) จับคู่ชื่อ EA ให้ 9 unknown magics บน 159475669 แล้วเพิ่มแถว CSV (2) ยืนยัน set จริงของ 991001 (v2/v3/defaults) (3) judge_date 11 แถว user-lane (ข้อเสนอ: 990005 → 2026-10-09, ที่เหลือ mark USER-LANE ใน notes) (4) sensor 463666728 (สร้าง `D:\Monitor\MT5 - 463666728` + login) — ตัวบล็อกใหญ่สุดของ judge ต.ค. (5) 146237 DealsExporter ส่งไฟล์ header-only ต้องเช็ค terminal
- **OPEN (agent-able รอบหน้า):** lock bundle ให้ 990101/991004/991002 + Boss_14 bench ×7 (ต้องได้ .set จริงจาก user ก่อน) · VPS-side hash compare step (design ใน CR-002 gate) · CR-003 health engine ยังไม่เริ่ม

---

### CR-TRACK Phase-1 tranche (เขียน 2026-07-24, Opus/Fable-seat — หลัง review ข้อเสนอ monitoring ของ Codex)

> **ที่มา:** user ส่ง review ของ Codex เรื่อง Control Room/monitoring. Claude trace โค้ดจริงทุก claim → ยืนยัน 5 ข้อหลัก (false-green จริง · floating-risk บอด 0/6 แต่ **ท่อสร้างเสร็จแล้ว ขาดแค่ attach** · expectations.csv ไม่มีใครอ่าน · unknown-magic แยก historical ได้ทันที · git race จริง) · **ตัดออก 3 ข้อที่ over-build:** 6-หน้าจอแยก (operator คนเดียว — ขยาย snapshot+TODAY พอ) · รื้อ dashboard ทั้งก้อนรอบเดียว (ย้ายทีละ section) · Boss V2 heartbeat roll ทั้ง fleet กลาง demo (= ปน evidence ก่อน judge → เลื่อนเป็น deployment ใหม่ก่อน) · **จุดที่ Codex พลาด:** collector วิ่งวันละครั้ง → floating-risk ใน repo เก่า 24h เสมอ, การเฝ้า risk จริงต้องอ่าน `Common\Files` ตรง (CR-007 lane) ไม่ใช่รอสำเนา repo.
> ลำดับ = อะไร block การมองเห็น/เสียข้อมูลก่อน. **แตะ core EA = 0 ใบในชุดนี้** (infra/ps1/csv ล้วน) → routing = Sonnet lane เขียน + Claude review; ไม่ต้อง Codex blind-audit (ไม่ใช่ money/live code).

**⏸ CR-P0 (มือ user — ไม่มีโค้ด, ทำก่อนทุกอย่าง):** (1) กู้ sensor `463666728` — login/restart `D:\Monitor\MT5 - 463666728` (ถือ candidate 13-14 ตัว = จุดบอดใหญ่สุด) · (2) สร้าง sensor `69424711` (terminal + attach DealsExporter) · (3) attach **AccountSnapshotExporter.ex5/.ex4** (compile พร้อมใน `tools\AccountSnapshot\`) เข้าทุก monitor terminal → floating-risk panel ขึ้นเองไม่ต้องแก้โค้ด. **CR-002c/CR-002 unknown-split รันได้เต็มผลก็ต่อเมื่อ P0 เสร็จ** (ก่อนหน้านั้นทำ code path ไว้รอได้ แต่ output ยังบอด).

### ✅ Phase-1 ปิดครบ 6/6 (Claude/Fable 2026-07-24, commits `fb24adf` orders · `2539d11` code · `2875d0b` CR-005-lite-b)
> Sonnet lane เขียน script edits (CR-003a/b·002c/d·TOOL-01) · Claude review+verify+owner files+CR-005-lite-b. **Regression cage: 13 ตัวเลข summary byte-identical ทุก commit.** snapshot schema v2→v3 (additive). ผลจริงวันนี้: chain **แดงถูกต้อง** (463666728 STALE + 69424711 NO_SENSOR ทั้งคู่ LAB_MANAGED) · unknown 6 = HISTORICAL หมด (0 ghost สด) · floating 6/6 BLIND (รอ P0 attach) · rate_flag เจอ 6 UNDER_RATE (991004/991002 บนบัญชี judge = ของจริง · Kangaroo L1-4 = น่าจะ expectation-basis mismatch, advisory). **เหลือ P0 (มือ user) เท่านั้น** → attach เสร็จ floating หายบอดเอง.

## CR-003a — false-green fix: daily_monitor fail เมื่อบัญชี governance=LAB_MANAGED ไม่ FRESH — `DONE(Claude/Fable 2026-07-24) — verified exit 1 + "4/6 LAB_MANAGED fresh; missing: 463666728, 69424711"`
**problem (trace ยืนยัน):** `daily_monitor.ps1:76-82` เช็คแค่ "ไฟล์ใหม่สุด **1 ไฟล์รวมทุกบัญชี** อายุ <26h" → 4/6 fresh + 463666728 stale 30.2h = chain จบ **เขียว** ทั้งที่ตาบอด 1 บัญชี. วันนี้เกิดจริง (snapshot=STALE, task=green).
**spec:** หลัง step `snapshot` (line 57) อ่าน `portfolio\control_room_snapshot.json` ที่เพิ่ง gen → เดินทุกบัญชีที่ `governance_scope=LAB_MANAGED` (จาก CR-003b) → ถ้าตัวใด `state≠FRESH` เพิ่มเข้า `$failed` เป็น `sensor-<acct>` + เขียน `MONITOR_ALERT.txt` ที่ระบุ "N/M LAB_MANAGED fresh, missing: <accts>". `USER_OBSERVED`/`ARCHIVED` ไม่ทำ chain แดง (เตือนใน log เฉยๆ). แยกข้อความ `chain ran` ออกจาก `coverage healthy` ให้ชัด.
**acceptance:** (1) inject 1 บัญชี LAB_MANAGED ให้ stale (mtime เก่า) → `daily_monitor.ps1 -Force` exit **1** + alert ระบุบัญชีถูกตัว · (2) ทุกบัญชี LAB_MANAGED fresh → exit **0** · (3) บัญชี USER_OBSERVED stale → exit **0** (ไม่แดง) · (4) รันจริงวันนี้ (463666728 stale) → exit 1.
**ห้าม:** ลบ/อ่อน stale guard เดิม (line 76-82) — เพิ่มชั้น per-account ทับ ไม่ใช่แทน · ทำ snapshot เป็น owner (มัน read-only projection) · ให้ chain แดงเพราะ USER_OBSERVED.

## CR-003b — `portfolio\ACCOUNTS.csv` registry + snapshot อ่าน account list จากไฟล์นี้ — `DONE(Claude/Fable 2026-07-24) — 6 acct LAB_MANAGED, registered PROJECT_STATE §0.5, fallback verified`
**problem:** ตอนนี้รายชื่อบัญชี derive จาก `DEPLOYMENTS.csv` (`control_room_snapshot.ps1:71`) → บัญชีที่ควรมี sensor แต่ยังไม่มี deployment (เช่น 69424711) หายจากเรดาร์ + governance policy ฝังในหัวคน.
**spec:** สร้าง `portfolio\ACCOUNTS.csv` columns: `account,account_name,platform,environment,governance_scope,expected_sensor,monitor_sla_minutes,base_equity,currency,start_date,alert_policy,notes`. `governance_scope ∈ {LAB_MANAGED,USER_OBSERVED,ARCHIVED}`. เติม 6 บัญชีปัจจุบัน (159503454/159475669/141049900/415573666=LAB_MANAGED · 463666728=LAB_MANAGED · 69424711=ตาม user ว่า observed/managed). `control_room_snapshot.ps1` อ่าน account universe จากไฟล์นี้ (fallback = DEPLOYMENTS ถ้าไฟล์ไม่มี, กัน regression) + ใส่ `governance_scope` ลง `system_health[]` แต่ละ entry.
**acceptance:** (1) snapshot `system_health` มี field `governance_scope` ทุก entry · (2) 69424711 โผล่ใน system_health เป็น NO_SENSOR (ก่อนหน้านี้โผล่จาก DEPLOYMENTS อยู่แล้ว — verify ไม่หาย) · (3) ไฟล์หาย → snapshot ยังรันได้ด้วย fallback · (4) `governance_scope` ผิดค่า → warn ไม่ crash.
**ห้าม:** ยัด per-account data ซ้ำลง DEPLOYMENTS (คงเป็น per-EA) · ทำ ACCOUNTS.csv เป็น generated (มันคือ owner ใหม่ระดับบัญชี — เพิ่มใน PROJECT_STATE §0.5 owner map ด้วย).

## CR-002c — section `floating_risk` ใน snapshot (wire ท่อ AccountSnapshotExporter ที่สร้างเสร็จแล้ว) — `DONE(Claude/Fable 2026-07-24) — 6/6 BLIND ก่อน P0 (ถูกต้อง), column names ตรง exporter header เป๊ะ`
**problem:** exporter + collector + dashboard panel สร้างครบ (`collect_live_deals.ps1:37` · `live_dashboard.ps1:358`) แต่ snapshot JSON ไม่มี floating-risk เลย → AI advisor/TODAY มองไม่เห็น open exposure.
**spec:** อ่าน `EA_LAB_snapshot_<acct>.csv` ใหม่สุดต่อบัญชีจาก `portfolio\live_deals` → เพิ่ม section `floating_risk` ต่อบัญชี: equity/balance/margin_level/floating_pl (ACCOUNT row) + per-magic floating_pl/open_lots/pos_count/oldest_age_h (MAGIC rows). ใส่ `age_hours` + flag `BLIND` ถ้าไม่มีไฟล์. summary เพิ่ม `accounts_floating_blind` count.
**acceptance:** (1) ก่อน CR-P0 attach: ทุกบัญชี `floating_risk.state=BLIND`, summary `accounts_floating_blind=6`, snapshot ไม่ crash · (2) หลัง attach ≥1 บัญชี: floating_pl/lots โผล่ตรงกับ dashboard panel เลขเดียวกัน · (3) ไฟล์เก่า >26h → flag stale ไม่ใช้เป็นสด.
**ห้าม:** อ่าน `Common\Files` ตรงใน snapshot (นั่น CR-007 fast-lane; snapshot อ่านจาก repo copy เท่านั้นเพื่อ reproducible) · ให้ floating section ทำ snapshot crash เมื่อไม่มีข้อมูล (บอดต้อง degrade ไม่ตาย).

## CR-002d — แยก unknown-magic เป็น HISTORICAL vs ACTIVE — `DONE(Claude/Fable 2026-07-24) — 6/6 HISTORICAL วันนี้ (0 active ghost, ยืนยันข้อสังเกต Codex)`
**problem:** `unknown_magics` (`control_room_snapshot.ps1:181`) รวม ghost ที่เลิกเทรดไปนานกับที่กำลังเทรดสดเป็นก้อนเดียว → 6 ตัววันนี้ทำให้ตกใจเกินจริง (Codex เองก็ตั้งข้อสังเกตว่า "น่าจะเป็น historical").
**spec:** ใช้ `last_seen` (มีอยู่แล้ว) เทียบ now: `ACTIVE` ถ้า last_seen ≤ 14 วัน, `HISTORICAL` ถ้าเก่ากว่า. summary แยก `unknown_magics_active` / `unknown_magics_historical`. เฉพาะ ACTIVE เข้า alert/TODAY; HISTORICAL เก็บไว้ใน section เฉยๆ.
**acceptance:** (1) 6 unknown วันนี้ถูกจำแนกครบ (ตรวจ last_seen แต่ละตัว) · (2) summary มี 2 count ใหม่ · (3) magic ที่ last_seen วันนี้ = ACTIVE.
**ห้าม:** ลบ historical ทิ้ง (ต้องเห็นได้ตอน audit) · ใช้ first_seen ตัดสิน (ต้องใช้ last_seen).

## CR-TOOL-01 — pathspec commit ใน daily_monitor กัน index race — `DONE(Claude/Fable 2026-07-24) — $monitorPaths ใช้ร่วม add+commit, พิสูจน์เอง commit นี้ pathspec แล้ว`
**problem:** `daily_monitor.ps1:72` `git commit` (ไม่มี pathspec) จะกวาดของที่ **session อื่น stage ค้าง** เข้า auto-commit ด้วย (2 Claude share worktree — บทเรียน ORDER-170 + memory `shared-worktree-concurrent-writers`). วันนี้มี session ORDER-136 commit คู่ขนานอยู่จริง.
**spec:** เปลี่ยน line 72 เป็น `git commit <same pathspec list as line 69> -m ...` (pathspec commit ผูกเฉพาะไฟล์ monitoring ชุดเดิม) → auto-commit แตะเฉพาะ 11 path นั้น ไม่แตะ staged ของ session อื่น.
**acceptance:** (1) stage ไฟล์ปลอมนอกชุด monitoring ไว้ + รัน chain → ไฟล์นั้น **ไม่** เข้า auto-commit · (2) ไฟล์ monitoring เปลี่ยนจริง → commit ปกติ · (3) ไม่มีอะไรเปลี่ยน → quiet เหมือนเดิม.
**ห้าม:** ใช้ `git add -A`/broad commit · เพิ่ม path นอกชุด 11 ไฟล์เดิมโดยไม่ตั้งใจ.

## CR-005-lite-b — expected-vs-actual ต่อ magic (เชื่อม expectations.csv) — `DONE(Claude/Fable 2026-07-24) — rate_flag เจอ 6 UNDER_RATE; scope rate-only, PF/DD-vs-band เลื่อน CR-005 เต็ม`
**problem:** `expectations.csv` มี `pf_expected/trades_per_month_expected/dd95_expected` ครบ 61 แถว แต่ snapshot forecast ใช้แค่ observed rate → ตอบไม่ได้ว่า "EA เงียบผิดปกติ" หรือ "sample ยังน้อยตามคาด".
**spec (ทำหลัง CR-003 นิ่ง):** join expectations เข้า `judge_readiness[]` → เทียบ observed trades/week กับ `trades_per_month_expected/4.33` (flag `UNDER_RATE` เมื่อ observed < 50% ของคาด ที่ days_active≥14) + PF live เทียบ band + DD เทียบ dd95. **บทบาท = เตือน/probation เท่านั้น ไม่แตะ promotion bar (CLAUDE.md VERDICT GATE คงเดิม PF≥1.40/≥30t/≥3เดือน).**
**ห้าม:** ให้ expected-vs-actual เขียน verdict หรือเลื่อน judge bar · delegate (นี่ judgment work).

**ที่ไม่เปิดเป็นงานในชุดนี้ (มี owner/trigger แล้ว):** attestation gap 40/56 = ORDER-184 lane คุมอยู่ · Boss V2 heartbeat = CR-003 เต็มรูป/หลัง judge (deployment ใหม่ก่อน ห้าม roll fleet) · fast risk monitor อ่าน Common\Files ตรง = CR-007 (ปี 2, dependency credential-alarm ยังไม่ปิด).
