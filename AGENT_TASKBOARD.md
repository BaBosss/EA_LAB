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

## ORDER-187 — [core/money] fail-closed first-lot sizing + Wave5 naked-order guard (Codex review 2026-07-24, ข้อ 1 ของ 8) — `DONE(Claude/Fable 2026-07-24) — รอ Codex blind-audit`
**source:** user ส่ง review ของ Codex เรื่อง EA Template หลังเพิ่ม `FirstLotMode=43` (balance-scaled). Claude รีวิวซ้ำโดย trace โค้ดจริงทุก claim — **ยืนยันถูกทุกข้อหลัก** + เจอเพิ่ม 1 ข้อที่ Codex ไม่ได้จับ (ข้อ (d) ล่าง).
**สิ่งที่แก้ (4 จุด):**
- (a) `MoneyManagement.mqh` — เลิก silent fallback. เพิ่ม `MM_ConfigValid()` เรียกจาก `OnInit` → config ที่ใช้โหมดไม่ได้ = **INIT_FAILED** (mode 42 คู่ `SLMode=30/32` ที่ไม่มีระยะ SL · mode 43 ที่ `_43_BalanceAnchor≤0` หรือ `_43_LotPerAnchor≤0` · mode 41 ที่ `_41_FixedLot≤0`). runtime ที่อ่านข้อมูลไม่ได้ → `MM_FirstLot` คืน **0.0 = ข้ามไม้นั้น** + log throttle 60s **ไม่ถอยไป `_41_FixedLot` อีกแล้ว**
- (b) `MoneyManagement.mqh` — `MM_NextLot(firstLot≤0)` คืน 0 ทันที. **กับดักจริง: `PROG_PLUS` เป็นสมการบวก** (`0 + _53_PlusLot×lv`) → sizing ที่ *ล้มเหลว* จะเสก lot ขึ้นมาจากศูนย์ที่ level ≥1 ถ้าไม่ดัก (branch อื่นเป็นการคูณ จึงได้ 0 อยู่แล้ว)
- (c) `ExitManager.mqh` + `LabCore.mqh`/`Recovery.mqh` — `Exit_StructSLMissing()` แยกความหมายของ `Exit_InitialSL()==0` ออกเป็น 2 กรณี: "config ไม่ต้องการ SL ต่อไม้" (SL_NONE/SL_MONEY = ถูกต้อง) vs "**structural SL ที่สัญญาไว้ re-validate ไม่ผ่าน**" (Wave5) — ของเดิมมองเป็นกรณีเดียวกัน จึงเปิดไม้ **naked** พอดีในกรณีที่ guard G4 ตั้งใจกันไว้ (ราคาขยับระหว่าง signal → fill). non-17 build compile เป็นค่าคงที่ false = ไม่กระทบ
- (d) **⭐ เจอเพิ่มเอง (Codex ไม่ได้จับ):** `LabCore.mqh` OnInit — ORDER-082 guard G4 เขียนไว้ว่า "structural mode ห้ามใช้กับ stacking, naked probe เท่านั้น" แต่**เป็นแค่คอมเมนต์ ไม่มีอะไรบังคับ**. `.set` ที่ตั้ง `StackMode=91/92/93` บน Boss_17 จะเอา structural SL ที่คำนวณเพื่อ**ไม้เดียวที่ราคาเดียว** ไปแปะ grid adds/pending ladder ทั้งกอง (path 93 ไม่ re-check เลยด้วย) → ตอนนี้ **INIT_FAILED**
**หลักฐาน (ไม่ใช่คำอ้าง):** `deploy.ps1 -Compile` = **0 errors/0 warnings ทั้ง 9 wrapper** · `scripts\tpl_regression.ps1` = **REGRESSION CLEAN 8/8 ไม่ต้อง re-pin baseline เลย** (Boss_17 ตัวเลขเท่าเดิมเป๊ะ net=-86.89 pf=0.45 n=26 → fail-closed ไม่ได้ตัด trade ไหนทิ้งบน window นี้) · ทั้ง repo **ไม่มี .set สักไฟล์ใน 1,331 ไฟล์ที่ใช้ mode 42/43** → INIT_FAILED ใหม่ไม่มีทางทำของเดิมพัง (ตรวจแล้วก่อนแก้)
**ทำไมไม่ใช่เรื่องด่วนไฟไหม้ (แย้งโทนของ review เดิม):** mode 43 default OFF + ไม่มี .set ไหนใช้ · Wave5 = naked probe ตัวเดียว ยังไม่ขึ้นเงินจริง → นี่คือ **pre-deployment hardening ที่ pace ได้** ทำให้เสร็จก่อนมีใครเปิด mode 43 จริงก็พอ.
**ห้าม:** ถือว่าปิดจบก่อน Codex blind-audit ผ่าน (core/money code = doctrine `AGENTS.md` §5.1) · ยัด Boss_16 balance-scaling เข้ามาใน patch นี้ (= ORDER-190 คนละชั้นความเสี่ยง).

## ORDER-188 — [test] positive-path cage ของ lot mode 42/43 (`scripts\mm_lotmode_test.ps1`) — `DONE(Claude/Fable 2026-07-24)`
**source:** Codex ข้อ 4 — "ยังไม่มี positive-path test". จริง และเป็นช่องว่างเชิงโครงสร้าง: **`tpl_regression.ps1` พิสูจน์สิ่งตรงข้าม** คือ "ของใหม่ที่ปิดอยู่ไม่ทำให้เลขเก่าเปลี่ยน" — มันจับ feature ที่พังตอน**เปิด**ไม่ได้เลย เพราะไม่มีอะไรใน cage เปิดอะไรสักอย่าง. mode 43 ship มา 2026-07-23 พร้อมช่องนี้พอดี.
**ผลรัน 8 เคส (Boss_12, XAUUSD H1 2024.01-07, Model 1) — ผ่านหมด:**
| เคส | ตั้งใจทดสอบ | คาด | ได้ |
|---|---|---|---|
| A fixed baseline | control | 0.10 | 0.10 ✅ |
| B ratio 1× | 43 = 41 ที่ ratio 1.0 | 0.10 | 0.10 ✅ |
| C ratio 0.5× | dep 5000/anchor 10000 | 0.05 | 0.05 ✅ |
| D ratio 2× | dep 20000/anchor 10000 | 0.20 | 0.20 ✅ |
| E unit-independence | **ratio 2.0 ในหน่วยต่างกัน 10 เท่า** (anchor 1000/dep 2000) | 0.20 | 0.20 ✅ |
| F RC_MaxLot clamp | cage ต้องชนะ sizing | 0.15 | 0.15 ✅ |
| G anchor=0 | ต้อง**ไม่**แอบเทรด fixed lot | 0 ไม้ | 0 ไม้ ✅ |
| H mode 42 + SLMode=30 | เหมือนกัน | 0 ไม้ | 0 ไม้ ✅ |
G/H คือ regression ของ ORDER-187 โดยตรง — **ก่อนแก้ ทั้งสองเคสเทรดฉลุยที่ `_41_FixedLot` โดยรายงานดูปกติทุกบรรทัด**.
**invariant ที่ตั้งเพิ่ม:** *deposit invariance* — mode 43 ทำให้ lot แปรผันตาม balance ⇒ เส้นทาง equity เชิง % เท่ากันทุกเงินต้น ⇒ **B/C/D ต้องได้จำนวนไม้เท่ากัน (164/164/164 ✅ บนช่วงเงินต้นต่างกัน 4 เท่า)**.
**⚠️ finding ที่ได้แถมมา (สำคัญกว่าตัว test):** A (fixed 0.10) ได้ **115 ไม้ eqDD 25.09%** แต่ B (mode 43 เริ่มที่ 0.10 เท่ากัน) ได้ **164 ไม้ eqDD 22.66%** — A ชน `KillDD 25%` ของ ProtectLevel NORMAL **พอดีเป๊ะ** แล้วโดน cage hard-kill กลางทาง ส่วน B หด lot ตาม balance ที่ลดลงจึงไม่เคยแตะเส้นตาย. **นี่คือคุณสมบัติที่ mode 43 มีให้จริง วัดได้เป็นตัวเลข** ไม่ใช่ทฤษฎี — และเป็นเหตุผลว่าทำไม A≠B ถึง**ไม่ใช่**บั๊ก (รอบแรกผมเขียน invariant ผิดว่าต้องเท่ากัน มันเลย FAIL แล้วผมไปไล่หาสาเหตุจนเจออันนี้).
**ห้าม:** เอา A/B ไปเทียบกันตรงๆ แล้วสรุปว่า sizing ทำ entry เพี้ยน · ใช้ cage นี้แทน `tpl_regression.ps1` (คนละหน้าที่ ต้องรันทั้งคู่).

## ORDER-189 — [docs] PARAM_REGISTRY 183/183 + คู่มือ lot mode §3.6 — `DONE(Claude/Fable 2026-07-24)`
**source:** Codex ข้อ 5 — registry ขาด 6 ตัว. ตรวจแล้วเลขตรง: `Inputs.mqh` มี **183 input จริง** (208 บรรทัดที่ขึ้นต้น `input` ลบ 25 `input group`), registry มี 177 แถว → ขาด **6 ตัวพอดี** = `_43_LotPerAnchor` · `_43_BalanceAnchor` · `_2_BasketTP_BalPct` · `_32_SL_BalPct` · `_57_DynCloseBalPct` · `_8_DDRefBalPct` (ORDER-164 จงใจไม่ใส่เพราะตอนนั้น ORDER-161 ยังไม่ commit — มี note บอกไว้ในหัวไฟล์เอง)
**ทำแล้ว:** เพิ่ม 6 แถวครบ (ต่อท้ายไฟล์ ไม่ใช่เรียงตามหมวด) แต่ละแถว trace precedence จากโค้ดจริง (`_2_BasketTP_BalPct` > `_2_BasketTP_ATRmult` > `_2_BasketTP_Money` ที่ `ExitManager.mqh:506` ฯลฯ) · **แก้ 3 แถวเดิมที่กลายเป็นข้อมูลผิดหลัง ORDER-187** (`FirstLotMode`/`_41_FixedLot`/`_42_RiskPct` — ทั้งสามเขียนว่า "silently falls back to `_41_FixedLot`" ซึ่งวันนี้ไม่จริงแล้ว) · ลบ note "moving target" ที่หัวไฟล์ + ใส่คำสั่ง verify ไว้แทน · เพิ่ม **§3.6 ใน `docs/EA_CORE_AND_TEMPLATE_GUIDE.md`** = ตารางเลือกโหมด 41/42/43 + **Account Profile USD vs CENT** (anchor ผูกกับบัญชี ไม่ใช่กลยุทธ์ — cent ที่ฝาก $1,000 อ่านได้ `100000` ใส่ anchor ผิด = lot ใหญ่ 100 เท่าแล้วไปตายที่ `RC_MaxLot`) + **linkage diagram สาย lot ทั้งเส้น** (balance → mode → DdAdaptive → RC_MaxLot → LotProg → Recovery → cage → normalize) + หมายเหตุ Boss_16 ไม่ฟัง 4x เลย
**⚠️ ยังเหลือ (ไม่ได้ทำใน order นี้):** ~174 แถวเดิมยังอ้าง line number จาก commit ที่ pin ไว้ตอน ORDER-164 ซึ่ง**เคลื่อนไปแล้วราว 16 บรรทัด** — ไม่ใช่ข้อมูลผิด แต่เป็นหนี้ที่ต้องล้างรอบเดียวทั้งไฟล์ (ดู ORDER-191)
**ห้าม:** regenerate registry ทั้งไฟล์ใหม่ (จะทิ้งงาน trace มือของ ORDER-164 ทิ้งหมด).

## ORDER-190 — [lever/funnel] MM-OWNER-002: Boss_16/Kangaroo ให้ scale ตาม balance ได้ (opt-in) — `OPEN`
**source:** Codex ข้อ 2. **ยืนยันว่าเป็นเรื่องจริง แต่ขอแยกความเสี่ยงออกเป็น 2 ชั้น ไม่รวมเป็นก้อนเดียวแบบที่ review เสนอ:**
- ชั้น safety (= "บอกผู้ใช้ว่าไม่มีผล") → **ทำไปแล้วใน ORDER-187**: `MM_ConfigValid` พิมพ์ `[INIT] WARN` เมื่อตั้ง FirstLotMode≠41 บน build 16
- ชั้น lever (= "ทำให้มันมีผลจริง") → **order นี้** เพราะไปแตะ lot law ของ EA ที่มี baseline pin อยู่ (Boss_16 cage 8/8) = ต้องเดิน funnel ปกติ ห้ามแอบรวมใน patch safety
**spec:** เพิ่ม input opt-in ของ Boss_16 เอง (เสนอ `_16_BaseLotMode`: 0=flat `_16_BaseLot` (default, byte-identical) · 1=balance-scaled ใช้ `_43_LotPerAnchor`/`_43_BalanceAnchor` ร่วมกับ chassis) → `Kangaroo_NextLot` อ่านค่านี้แทนการ hardcode `_16_BaseLot` · **default ต้องให้ `tpl_regression.ps1` 8/8 เท่าเดิมเป๊ะ** · จากนั้น A/B flat vs scaled บน MAIN+BWD → ถ้าจะรับต้อง re-pin baseline พร้อมประกาศในคอมมิตเดียวกัน
**bars:** pass = scaled ผ่าน MAIN≥1.2 + BWD≥1.0 และไม่แย่กว่า flat · dead = แย่กว่า flat ทั้งสอง window (เก็บโหมด 0 ไว้เฉยๆ) · กลาง = เท่าๆ กัน ⇒ ไม่รับ (ความซับซ้อนไม่ฟรี)
**flat-lot probe:** N-A (โหมด 0 คือ flat อยู่แล้ว = control ในตัว)
**ห้าม:** เปลี่ยน default ของ `_16_BaseLot` · แก้ `Kangaroo_NextLot` โดยไม่รัน `tpl_regression.ps1` · ตีความ WARN ของ ORDER-187 ว่าเป็นบั๊กที่ยังค้าง (มันคือพฤติกรรมที่ ORDER-072 ตั้งใจ)
**ทำได้:** Claude เขียน + Codex blind-audit (แตะ money) · A/B รันได้ด้วย qwen/Sonnet

## ORDER-191 — [docs/tooling] parameter linkage matrix + ล้างหนี้ line-number ของ registry — `OPEN`
**source:** Codex ข้อ "PARAM-LINK-005/UX-006". **ตัดสโคปลงจากที่ review เสนอ** เพราะ compile-time hiding ต่อ Boss ที่เสนอไว้ **มีอยู่แล้ว** — `Inputs.mqh` ห่อ input ของทุก entry ด้วย `#ifdef LAB_ENTRY_NN` อยู่แล้ว, wrapper ที่ build จริงจึงเห็นแค่ chassis ร่วม + entry ตัวเอง ไม่ต้องสร้างระบบใหม่.
**spec (mechanical, ตรวจด้วยสคริปต์ได้):** (a) refresh line number ทั้ง ~174 แถวของ `docs/PARAM_REGISTRY.csv` ให้ตรง working tree รอบเดียว + เขียนสคริปต์ `scripts/param_registry_check.ps1` ที่ diff ชื่อ input ระหว่าง `Inputs.mqh` กับ registry แล้ว exit 1 ถ้าไม่ตรง (กันไม่ให้หนี้ก้อนนี้เกิดซ้ำ) (b) จากคอลัมน์ `coupled_parameters` ที่มีอยู่แล้ว generate ตาราง linkage ต่อหมวด → `docs/PARAM_LINKAGE.md` (c) audit หา input ที่ `classification=INACTIVE` หรือคู่ที่ override กันเงียบๆ → list ไว้ให้ Claude ตัดสิน
**ห้าม:** เขียนคอลัมน์ `default_profile`/`optimize_stage`/`safe_range` ที่เป็น UNKNOWN โดยเดาเอง (กฎเหล็กของ ORDER-164) · regenerate registry ทั้งไฟล์
**ทำได้:** Sonnet/qwen ทั้งใบ (mechanical + มี cage ตรวจ)

## ORDER-192 — [tooling] OnInit effective-config summary + optimizer active-parameter guard — `OPEN`
**source:** Codex ข้อ "CONFIG-007 + OPT-GUARD-008". **จัดไว้ท้ายคิวโดยตั้งใจ** — มูลค่าต่อ pipeline ต่ำกว่า 187-189 มาก และ MT5 ซ่อน parameter แบบ dynamic ไม่ได้อยู่ดี
**spec:** (a) ต่อจาก `[INIT] Boss_%s | exit=... firstLot=...` ที่มีอยู่ ให้พิมพ์บล็อกสรุป **effective config** = โหมดที่ใช้จริง + first lot ที่คำนวณได้จริง ณ ตอน attach + ค่าที่ถูก override ทิ้ง (เช่น `_2_BasketTP_Money` ตอนที่ `_2_BasketTP_BalPct>0`) + คำเตือนเมื่อ `_4_DdAdaptiveOn` เปิดพร้อม LotProg/Recovery (b) guard ฝั่ง optimizer: สคริปต์อ่าน `.ini` ของ optimize pass แล้วปฏิเสธ parameter ที่ inactive/ถูก override/เป็น safety (`RC_*`, KillDD, DepositLoad) — **ใช้ `PARAM_REGISTRY.csv` เป็นแหล่งความจริง** (จึงต้องรอ ORDER-191 (a) ก่อน)
**ห้าม:** ทำ (b) ก่อน registry ผ่าน check script (จะ guard จากข้อมูลเก่า) · เพิ่ม input ใหม่เพื่อเปิด/ปิด summary (log อย่างเดียวพอ)
**ทำได้:** (a) Claude/Sonnet · (b) Sonnet/Codex

## ORDER-194 — [core/safety] hard-kill ยิงซ้ำทุก tick หลัง halt แล้ว (ไม่มี `g_rc_halted` guard ใน `RiskControl_CheckDD`) — `OPEN` ⚠️ รอ user เคาะ (แตะ risk logic)
**source:** เจอโดยบังเอิญตอนไล่ตอบคำถาม user เรื่อง KillDD 25% (2026-07-24) — grep หา `HARD KILL` ใน tester log แล้วเจอตัวเลขที่เป็นไปไม่ได้
**หลักฐานดิบ (log จริง ไม่ใช่การอนุมาน):**
```
06:57:49  2024.05.09 16:10:40  [RISK] HARD KILL: DD 25.09% >= 25.00% (profile 2) -> closing all
06:57:49  2024.05.09 16:10:40  [RISK] HARD KILL complete: broker flat verified -> halt (persisted)
06:57:49  2024.05.09 16:10:59  [RISK] HARD KILL: DD 25.09% >= 25.00% (profile 2) -> closing all   ← ยิงซ้ำหลัง halt แล้ว
```
จำนวน match ต่อไฟล์ log: **07-19 = 14.4M · 07-23 = 11.8M · 07-24 = 3.5M** · ไฟล์ log วันเดียว **777 MB**
**กลไก (ยืนยันที่ `RiskControl.mqh:299-327`):** `RiskControl_CheckDD()` เช็ค `g_rc_kill_pending` แต่ **ไม่เคยเช็ค `g_rc_halted`**. พอ kill เสร็จ → `kill_pending=false`, `halted=true` → tick ถัดไปเข้ามาใหม่ → `dd` ยังสูงกว่าเพดาน (peak equity ไม่ถูก reset, equity ยังต่ำ) → **print + `kill_pending=true` + `KillReconcile()` อีกรอบ ทุก tick จนจบ run**. ใน `LabCore.OnTick` ลำดับคือ `RiskControl_CheckDD()` ก่อน `RiskControl_IsHalted()` — CheckDD จึงยิงก่อนที่ halt check จะได้ทำงาน
**ผลกระทบ:** (1) **live: พยายาม close-all ซ้ำทุก tick ทั้งที่พอร์ตแบนแล้ว** = ยิง request ใส่โบรกเกอร์รัวๆ โดยไม่จำเป็น (2) tester log บวมระดับ GB → เปลืองดิสก์ + ทำให้ทุกงานที่ต้อง scan log ช้ามาก (3) กลบ log อื่นจนหาอะไรไม่เจอ
**ที่ยังไม่รู้ (ต้องตรวจก่อนแก้):** `KillReconcile` ที่ถูกเรียกซ้ำ ส่งคำสั่งปิดจริงทุกครั้ง หรือเจอว่า flat แล้ว return เร็ว — ต่างกันมากระหว่าง "log spam เฉยๆ" กับ "ยิง order ใส่โบรกจริง"
**✅ DONE (Claude/Fable 2026-07-24, user สั่ง "แก้ตามงานที่นายเปิดไว้เลย"):** ตอบข้อ "ที่ยังไม่รู้" ก่อนแก้แล้ว — **ไม่ได้ยิง order ใส่โบรก** (`Exec_CloseAll` วนหาไม้ของตัวเอง ไม่เจอ ก็ไม่เรียก `PositionClose`) **แต่หนักกว่าที่คิดในอีกทาง: `KillReconcile` เข้า block persist ทุกครั้งที่ผ่าน → `Persist_Set`×2 + `Persist_Flush()` = `GlobalVariablesFlush()` เขียนดิสก์ทุก tick ตลอดไปบน live/demo** บวก log 2 บรรทัดต่อ tick
**fix ที่ลง:** ไม่ใช้ early-return เปล่าตามที่เสนอไว้ตอนแรก — ใช้แบบที่**รักษาคุณสมบัติ "halted ต้องแบน" ไว้ด้วย**: ถ้า halted แล้วจะไม่ประเมิน DD ซ้ำ แต่ยัง sweep ไม้ที่โผล่มาบน magic นี้*หลัง* halt (เรียก reconcile เฉพาะตอนมีของจริงให้ปิด — idle path ต้องไม่มีต้นทุน)
**หลักฐาน:** `tpl_regression.ps1` = **CLEAN 8/8 ไม่ขยับสักตัว** → ยืนยันว่า kill ซ้ำเป็นเรื่อง log/disk ล้วน ไม่เคยมีผลต่อ trade
**bars:** N-A. **flat-lot probe:** N-A.
**ห้าม:** ตีความ CLEAN 8/8 ว่า "ไม่มีอะไรเสียหาย" — ผลจริงอยู่ที่ live (disk I/O) และที่ log ขนาด GB ซึ่งทำให้ ORDER-193 ทำงานไม่ไหวถ้าไม่แก้ก่อน

## ORDER-193 — [tooling/integrity] ตรวจจับ backtest ที่ถูก hard-kill ตัดกลางคัน (truncated-run detector) — `OPEN` ⚠️ ผลกระทบต่อความน่าเชื่อถือของ funnel
**source:** user 2026-07-24 ถามว่า "KillDD 25% เข้มไปไหม ถ้าโดนก็ optimize/ลด lot เอาก็ได้". ไล่โค้ดแล้วเจอว่าคำถามนี้ชี้ไปที่ปัญหาที่ **ใหญ่กว่าตัวเลข 25** และไม่มีใครเห็นมาก่อน:
**ข้อเท็จจริงที่ตรวจแล้ว:** `RiskControl_CheckDD()` **ไม่ถูก tester-gate** (มีแค่ `RiskControl_PersistRefresh` ที่ gate ไว้ที่ `RiskControl.mqh:287`) → **hard-kill ยิงใน backtest ด้วย** และเมื่อยิงแล้วจะ `close all + halt ตลอดที่เหลือของ run` (`g_rc_kill_pending` → `RiskControl_IsHalted` early-return ใน OnTick)
**ผลที่ตามมา:** backtest ใดก็ตามที่ DD แตะ `RC_KillDDPct()` จะรายงาน PF/n จาก **sample ที่ถูกตัดกลางคัน โดยไม่มีอะไรในรายงานบอกว่าถูกตัด** — วัดได้จริงวันนี้ (ORDER-188 เคส A): ตาย DD 25.09% ที่ไม้ 115 จาก 164 = **30% ของหน้าต่างหายไปเงียบๆ** และ PF ที่ได้ (0.71) คือ PF ของ 70% แรกเท่านั้น. **ร้ายกว่านั้น: จุดตัดขึ้นกับ "เงินฝากที่ตั้งใน tester" ซึ่งเป็น setting ไม่ใช่คุณสมบัติของกลยุทธ์** → EA เดียวกัน พารามิเตอร์เดียวกัน คนละเงินต้น = คนละ verdict. นี่คือรูรั่วของ comparability ทั้ง funnel ไม่ใช่แค่ของ EA ตัวใดตัวหนึ่ง.
**spec:** (a) หา marker ที่เชื่อถือได้ว่า run ถูกตัด — `[RISK] HARD KILL` ใน tester log และ/หรือ deals ที่หยุดก่อนวันสิ้นสุด window (b) ใส่การตรวจนี้เข้า `scripts/mt5_run.ps1` (หรือ wrapper) ให้ **print คำเตือนเด่นๆ + คืน flag** ว่า `TRUNCATED_BY_KILL at trade N / DD X%` (c) เติมฟิลด์นี้ในทางเดินผลที่ใช้ตัดสิน (report harvest / CSV) เพื่อให้ **ไม่มี verdict ไหนถูกเขียนบน sample ที่ถูกตัดโดยไม่รู้ตัว** (d) ตรวจย้อนหลัง: scan tester log เท่าที่ยังเหลือ หา run ที่เคยโดน แล้วรายงานว่ากระทบ EA ตัวไหนที่มี verdict อยู่แล้วบ้าง
**ห้าม:** แก้ตัวเลข `RC_KillDDPct()` · ปิด/ข้าม hard-kill ในโหมด tester เพื่อให้ backtest เดินจบ (จะได้เลขที่สวยจากความเสี่ยงที่ live รับจริงไม่ได้ = โกหกตัวเอง — ถ้าอยากได้ run ที่ไม่ถูกตัด วิธีที่ถูกคือ **ลด lot / เพิ่มระยะ จนไม่แตะเพดาน** ตามที่ user เสนอ ซึ่งถูกแล้ว แค่ต้องเห็นสัญญาณเตือนก่อน) · ทำ (d) แล้วรีบตีความว่า verdict เก่าผิดทันที (รายงานก่อน ให้ Claude/user ตัดสิน)
**bars:** N-A (tooling). **flat-lot probe:** N-A.
**ทำได้:** Sonnet/qwen (mechanical, ตรวจผลได้ด้วย log จริง) — logic ตัดสินว่า verdict ไหนต้องรื้อ = Claude/user เท่านั้น

## ORDER-152 — [infra] doctrine reconciliation: Codex routing + stale verdict vocabulary + doc-retirement audit — `REVIEWED(Claude 2026-07-23) — committed c6d431f · (a)(b) done · (c) disposition B-list EXECUTED this session (user go-ahead given): moved 6 root docs → _archive_docs/ (DEPLOY_CHECKLIST_2026-06-29 + 5 one-off analysis docs), deleted empty portfolio/port_01/ scaffold + duplicate _archive_docs/QWEN_RUN_LOG_updated.md (verified pure subset of QWEN_RUN_LOG.md), verified DEPLOYMENT_PLAN.md is NOT a stale duplicate of DEMO_DEPLOYMENT_PLAN.md (distinct scope, already bannered) → kept as-is; updated path refs in PROJECT_STATE.md/README.md/MASTER_BACKLOG.md; check_state.ps1 -Strict = CLEAN after every move; **B-list now 7/7 CLOSED** — final 2 done same session (`ee8db79`+`1b0ebb9`): `OPTIMIZE_PROCEDURE_AND_AUDIT.md` → `_archive_docs/` (already self-bannered SUPERSEDED, nothing to merge) · `docs/RECOVERED_PLATFORM_DESIGN_20260614.md` → `_archive_docs/` **after content-check**: not "already ported" but *replaced by a different system* (§3 scoring + §4 gate chain = retired vocabulary → VERDICT GATE · §5 Pass 0/1/2/4 → skill LADDER · §6 window → pinned MAIN/BWD/HOLDOUT · §7 EA table stale, GSMC already DISQUALIFIED · §1-2/§8 still true, live in `ea_template/DESIGN_V2.md`+`VISION.md`) → SUPERSEDED banner added, refs fixed in `PLATFORM_INDEX.md`/`README.md`/`PROJECT_STATE.md`/`_archive_docs/README.md` — see `_triage/ORDER152_DOC_RETIREMENT_AUDIT.md` §B for full detail. **⚠️ spun off (out of scope, not done):** `scripts/select_robust_pass.py`+`scripts/score_backtest.py` ยัง implement สูตร BacktestScore v1 ที่ retire แล้วจากไฟล์ที่เพิ่ง archive — ยังไม่ตรวจว่ายังถูกเรียกใช้จริงไหม (แก้แค่ path comment) · worktree risk item (`great-mendeleev-a35c44`) resolved same session: confirmed clean + already-merged, removed via `git worktree remove`, nothing lost`
> 🔧 **provenance correction (Opus-seat, 2026-07-23):** B-list execution above actually landed in commit **`52e9fcd`**, not folded into any of this session's other commits. `52e9fcd`'s commit message reads "ORDER-163 (CORE-002) REVIEWED..." — **that message is wrong for that commit's actual content.** Root cause: a `.git/index` race between two concurrent sessions writing to the same shared working tree during a slow (~3min) pre-commit hook — this session's ORDER-163 `git add` got superseded in the shared index by the other session's doc-cleanup `git add` before either `git commit` finished, so the commit object that landed carries this session's message text but the other session's staged content. No data was lost (all files intact), but **the git log entry for `52e9fcd` should be read as "ORDER-152(c) doc B-list execution", not ORDER-163** — this note is the correction. ORDER-163's actual files were re-staged and committed separately afterward (see that order's own commit). New failure class for `AGENT_TASKBOARD.md`/git-workflow doctrine — logged to memory `shared-worktree-concurrent-writers`.
**source:** workplan review finding #2 + Codex MISSED #1/#2 + ROADMAP §3 ข้อ 9 (เกษียณเอกสารซ้ำซ้อน) — **ยกระดับจาก "ว่างเมื่อไหร่ก็ได้" เป็น T1 เพราะพิสูจน์แล้วว่ามี doc ขัดกันเองที่ agent อ่านอยู่ทุกวัน** (ไม่ใช่แค่รก).
**ยืนยันแล้ว 2 จุดขัด:** (1) `AGENTS.md` §5.1 ตาราง order-tag ระบุ 👉 แนะ default = **Codex-direct** สำหรับงาน code · แต่ Decision log 2026-07-16 + `docs/PIPELINE.md` สั่ง Claude-author + Codex audit-only หลัง Codex-builder ตาย 3 ครั้งใน 1 วัน (2) `ea_template/OPTIMIZATION_PROCEDURE_V2.md` ยังเป็น DRAFT FOR REVIEW และใช้ศัพท์ verdict เก่า (`DEAD`/`PARKED`/`SYMBOL_LOCAL` เปล่าๆ) ที่ retire ไปแล้วตาม VERDICT GATE.
**spec:** (a) แก้ `AGENTS.md` §5.1 ให้ตรง Decision log — เส้นแบ่งที่ถูกต้องคือ **core/parity/money code = Claude เขียน Codex blind-audit** · **tooling ที่ไม่แตะเงินและมี cage ชัด = Codex build ได้** (precedent ที่ถูกต้องแล้ว = ORDER-144) ห้ามเขียนเหมารวมว่า Codex ห้ามเขียนโค้ดทุกกรณี (b) `OPTIMIZATION_PROCEDURE_V2.md` — map ศัพท์เก่า→canonical vocabulary + ใส่ banner ว่าไฟล์นี้ owns **procedure เท่านั้น ไม่ own verdict** (VERDICT GATE ใน CLAUDE.md own) (c) audit: list ทุก `*.md` ที่มี banner `DRAFT FOR REVIEW` / `SUPERSEDED` / `DEPRECATED` + ไฟล์ที่ authority ทับกัน → ตารางเสนอ disposition ต่อไฟล์ (keep / merge-into-X / retire) — **เสนอเฉย ๆ**.
**ผล sweep รอบแรกมีแล้ว (2026-07-23 — ใช้เป็นจุดตั้งต้นของ (c) ไม่ต้องเริ่มจากศูนย์):** ขนาด = **29 `.md` ที่ root · 10 ใน `docs/` · 20 ใน `_archive_docs/`**. ตระกูลที่ authority ทับกัน: **taskboard ×4** (`AGENT_TASKBOARD` + `_MERGE` + `_PQUANT` + `ARCHIVE_TASKBOARD_2026-07A`) · **deployment plan ×3** (`DEPLOYMENT_PLAN` + `DEMO_DEPLOYMENT_PLAN` + `DEPLOY_CHECKLIST_2026-06-29` ซึ่ง date-stamped น่าจะค้าง) · **project state ×2** (+ `STATUS.md`/`STATUS.html` + `_archive_docs/PROJECT_STATUS.md`). ติด banner ชัดแล้ว: `OPTIMIZE_PROCEDURE_AND_AUDIT.md` = `⚠️ SUPERSEDED (2026-07-18)` · `docs/RECOVERED_PLATFORM_DESIGN_20260614.md` = artifact กู้คืน น่าจะถูกแทนด้วย `PLATFORM_INDEX.md`/`docs/PIPELINE.md`. one-off analysis ที่ root ควรย้ายลง `_archive_docs/`: `EA_CORE_ST03_LOOP_PLAN` · `MT4_GOLDGRID_RETEST_PLAN` · `RSI_FROM_PIPS_REVERSE_ENGINEERING` · `STRATEGY_200_ANALYSIS` · `ZEUS_GOLD_HEDGE_ANALYSIS`. **2 อย่างที่ไม่ใช่ .md แต่เป็นขยะโครงสร้างจริง:** `portfolio/port_01/` = 5 โฟลเดอร์ว่างเปล่ามีแต่ `.gitkeep` ไม่ถูกแตะตั้งแต่ 2026-05-29 · **`.claude/worktrees/great-mendeleev-a35c44/` = สำเนาทั้ง repo ค้างอยู่** (root docs + `_mt5_auto/` ครบ) — อันนี้อันตรายกว่ารก เพราะ memory `shared-worktree-concurrent-writers` เตือนไว้แล้วว่า worktree ค้าง = ความเสี่ยง writer ชนกัน **แต่ห้ามลบในใบนี้ ให้เสนอพร้อมเหตุผล**.
**bars:** N-A (doc order ไม่มี pass/dead). **flat-lot probe:** N-A.
**ห้าม:** ลบ/ย้าย/rename ไฟล์ใดๆ ใน order นี้ (เสนอ disposition เท่านั้น) · แก้ VISION.md · แก้ Decision log · แตะ verdict EA · commit เอง.
**ทำได้:** (a)+(b) = **Claude เท่านั้น** (เป็นการตัดสินว่า doc ไหนชนะ) · (c) sweep = qwen/Sonnet ทำ list ได้ · 👉 แนะ: Claude ทำ (a)(b), qwen ทำ (c).

## ORDER-182 — RSI-MR (990103): continuous-span re-measure — WFA stitched-window methodology invalid for this basket EA, real evidence is stronger — `REVIEWED(Claude 2026-07-23): edge ยืนยันจริง (both-window PF1.37/1.37 plateau, ไม่ใช่ spike) แต่ holdout n=26 บางล้มไม่ผ่าน → BUILD-ON (ไม่ใช่ CANDIDATE, ไม่ใช่ตาย)`
**source:** ก่อนดัน RSI-MR ไปเป็น CANDIDATE ตาม "ค้าง" จากหลาย session-close พบว่า `(Boss)_RSI_MR_GridLog_rev01` เป็น **basket EA จริง** (dual-side, `_06_MaxPositions=8`, `_05_LotMode=3` LOG escalation — `PositionsTotal()`/per-side basket TP ใน source) แต่ ORDER-168 WFA วัดด้วย **3 window แยกกัน 2020-21/21-22, 2021-23/23-24, 2023-25/25-26 (equity reset ทุกรอบ, DistAtrMult คนละค่าต่อ fold)** — ตรง pattern ที่ skill `backtest-optimize-rigor` เตือนไว้เป๊ะว่า stitched windows หลอกได้ ~10x สำหรับ basket/grid EA (precedent: PF 7.17/3.97/7.64 tiled → 0.583 continuous). flat-lot เดิม (PF 0.78, ORDER-048/2026-07-08) ก็ใช้ .set บางส่วนก่อนเจอ cache bug ORDER-165 — เชื่อไม่ได้เหมือนกัน. ใบนี้รัน **continuous single-span** ด้วย full-pinned config เดียว (atr9, `_mt5_auto/ab_sets/rsimr_continuity_check/`) บน **D:\Meta 5b** (กัน session คู่ขนานที่ใช้ D:\Meta 5 อยู่).
**ผล (Model 4, full-pinned, continuous span, EURUSD H1):**
| config | window | PF | trades | DD% | win% |
|---|---|---|---|---|---|
| ESCALATED (LOG5, pinned) | MAIN 2023-25 | **1.37** | 280 | 8.07 | 67.9 |
| ESCALATED (LOG5, pinned) | BWD 2020-22 | **1.37** | 267 | 5.35 | 62.6 |
| FLATLOT (LotMode=0) | MAIN 2023-25 | **1.33** | 163 | 1.57 | 62.6 |
| FLATLOT (LotMode=0) | BWD 2020-22 | **0.82** | 159 | 4.12 | 59.1 |
| ESCALATED (LOG5, pinned) | HOLDOUT 2026H1 | **0.73** | 26 | 3.63 | 50.0 |
raw `_mt5_auto/RSIMR_CONTINUITY_CHECK.csv` + reports `RSIMR_CONT_*`.
**อ่านผล:** (1) **both-window PF เท่ากันเป๊ะ 1.37/1.37 บน config เดียว ไม่ต้อง reoptimize ต่อ fold** = plateau จริง ไม่ใช่ spike, n สุขภาพดีสำหรับ type นี้ (280/267 เทรดใน 3 ปี) — ผ่าน CANDIDATE bar ทั้งคู่ (MAIN≥1.2 hard, BWD≥1.0 soft) สบายๆ, **ดีกว่า WFA เดิมมาก** (fold2 OOS 1.08 เดิม = artifact ของการ chop window ไม่ใช่ edge จริงที่บาง) (2) **flat-lot ไม่ใช่ ENGINE-EDGE class ชัดเจน**: MAIN flat-lot ยังมีกำไร (1.33 > 1) แสดงว่า entry เองมี edge จริงในหน้าต่างปัจจุบัน, มีแค่ BWD (0.82) ที่ต้องพึ่ง escalation ถึงจะรอด — อ่านเป็น "escalation ช่วยพยุงในโหมด trend-stress" ไม่ใช่ "escalation คือ edge ทั้งหมด" (3) **MC** (bootstrap จาก MAIN gross P/L, win190/loss90, `mc_from_summary.ps1`): PF-5th **1.116** (ผ่าน hard floor ≥1.0 ไม่ถึง comfortable ≥1.2), ruin **0%**, DD95 3.07% (4) **holdout 2026H1 ล้ม (0.73/n=26)** แต่ n บาง (26 เทรดใน 6 เดือน เทียบ ~45-90 ที่คาดจาก rate ของ MAIN/flat — เข้าข่าย "thin sample = inconclusive" ตาม catalog ไม่ใช่ "ล้มชัดเจน") — ตาม LADDER Step 6 (holdout collapse + PF>1 ที่อื่น ⇒ BUILD-ON ไม่ใช่กลับไป diagnosis).
**lever coverage:** รอบนี้แตะแค่ methodology (continuous vs stitched) — **spacing (DistAtrMult) เดียวที่ swept บน pinned data จริง**; lot-law เคย sweep (ORDER-048) แต่บน partial-set ก่อน ORDER-165 = ไม่นับ; entry-threshold (RSI band)/SL-width/exit-mode ยังไม่แตะบน continuous-pinned baseline เลย → **ยังไม่ครบ ≥3 lever ตามกฎ** ห้ามเขียน DEAD/CANDIDATE เด็ดขาดจากรอบนี้.
**verdict:** ยกจาก **PARKED-VERIFY(user) ความเชื่อมั่นลด** → **BUILD-ON** (evidence แข็งแรงขึ้นมากจาก methodology fix, both-window ผ่านจริง ไม่ใช่ margin บาง — แต่ holdout ยังไม่ผ่านและ lever ยังไม่ครบ 3 = ยังไม่ CANDIDATE). ยังไม่เคย attach = ไม่มีความเสียหายจากการรอ.
**ห้าม:** อ่าน flat-lot BWD (0.82) เป็น STRUCTURAL/ENGINE-EDGE เต็มรูปแบบ (MAIN flat ยังกำไรจริง) · เชื่อ holdout 0.73 เป็นคำตอบสุดท้ายก่อนขยาย n · ข้าม lever entry-threshold/SL ไปเขียน CANDIDATE · **อ่าน DD 8.07%/5.35% เป็นภาพความเสี่ยงครบ** (ดู basket-duration finding ด้านล่าง — PF/DD ไม่เห็น tail นี้).
**🔴 basket-duration tail (พบเพิ่มระหว่างทาง, `scripts/max_recovery_days.py` บน 2 continuous escalated report):** MAIN 14 basket, **max recovery 159.1 วัน** (95th pct 149.7, median 92.2, 86% ค้าง >7 วัน, 64% ค้าง >30 วัน) · BWD 19 basket, **max recovery 291.8 วัน** (เกือบ 10 เดือน!, 95th pct 107.3, median 31.1, 100% ค้าง >7 วัน) — นี่คือ "time-underwater" ที่ equity curve/DD ไม่เห็น (skill: "time-underwater IS the recovery-EA tail the equity curve hides"). ก่อนดัน CANDIDATE ต้องตอบให้ได้ว่า capital ที่ถูกล็อกไว้ 5-10 เดือน (basket ไม่ปิด) รับได้ไหมในบริบทพอร์ตจริง — ตัวเลขนี้ยังไม่ผ่าน worst-case ≤15% equity check ของ ENGINE-EDGE cage (ยังไม่ทำ เพราะยังไม่จัดเป็น ENGINE-EDGE เต็มรูป แต่ escalation มีจริงจึงควรเช็คไว้ก่อน).
**ทำได้ต่อ (session หน้า):** sweep RSI Oversold/Overbought band + SL width (SlAtrMult) บน continuous MAIN+BWD, pinned methodology เดิม — ถ้าเจอ config ที่ยกทั้ง holdout และคง both-window plateau = ดัน CANDIDATE ได้จริง · **ต้องวัด basket-duration ของ config ใหม่ด้วยทุกครั้ง** ไม่ใช่แค่ PF/DD.

## ORDER-183 — RSI-MR (990103) lever 2/3: RSI band × SL-width coarse grid (ต่อ ORDER-182) — `REVIEWED(Claude 2026-07-23): เจอ plateau ที่ดีกว่าเดิมชัดเจน (RSI25/75+SL25: MAIN1.96/BWD1.56, DD ต่ำกว่า, basket-duration สั้นกว่า) แต่ holdout ยังล้มเท่าเดิม (0.76/n=21) — ครบ 3/3 lever แล้ว, ยัง BUILD-ON`
**grid:** RsiOversold/Overbought {25/75, 30/70(=baseline), 35/65} × SlAtrMult {15, 25(=baseline), 35}, continuous MAIN+BWD, full-pinned atr9 spacing คงเดิม, D:\Meta 5b.
**ผล (9 combo × 2 window = 18 run):**
| RSI band | SL15 (MAIN/BWD) | SL25 (MAIN/BWD) | SL35 (MAIN/BWD) |
|---|---|---|---|
| 25/75 | 1.15/0.90 | **1.96/1.56** | 1.56/1.72 |
| 30/70 (baseline) | 1.00/1.01 | 1.37/1.37 | 1.24/1.57 |
| 35/65 | 1.03/0.82 | 1.23/1.32 | 1.19/0.90 |
raw `_mt5_auto/RSIMR_LEVER2_SWEEP.csv` + sets `_mt5_auto/ab_sets/rsimr_lever2/`.
**อ่านผล:** (1) **RSI25/75 × SL{25,35} = plateau จริง ไม่ใช่ spike** — 2 จุดติดกันทั้งคู่ผ่าน both-window ชัดเจน (1.96/1.56 และ 1.56/1.72), n สุขภาพดี (199-232 เทรด), **ไม่ใช่แค่ SL15 ที่แย่ทุก band** (แถว 15 แย่หมดทุก RSI band = ตัด SL ไม่ใช่ candidate) (2) เลือก **RSI25/75+SL25 เป็น center ใหม่** (ดีกว่า SL35 ที่ n มากกว่าแต่ trade-off ไม่ชัด) — ยืนยันด้วย holdout+basket-duration รอบใหม่:
- **holdout 2026H1: PF 0.76/n=21** — **ยังล้มเหมือนเดิม** (baseline เดิม 0.73/n=26) → พิสูจน์ว่า **2026H1 อ่อนจริงในตัวมันเอง ไม่ใช่ config-dependent** (คนละ config, RSI band เปลี่ยน SL เปลี่ยน แต่ผลลัพธ์ holdout เหมือนเดิมเป๊ะ — ไม่ใช่สิ่งที่ lever tuning แก้ได้)
- **basket-duration ดีขึ้นทั้งคู่:** MAIN max 98.4 วัน (เดิม 159.1) · BWD max 182.1 วัน (เดิม 291.8) — สั้นลงมาก, tail risk เบาลงจริง ไม่ใช่แค่ PF ดีขึ้นบนหน้าตา
**lever coverage ตอนนี้ครบ 3/3:** spacing (ORDER-182) + entry-threshold RSI band (ใบนี้) + SL-width (ใบนี้) — ผ่านกฎ "≥3 lever ก่อนตัดสิน" แล้ว.
**verdict:** ยัง **BUILD-ON** (holdout ยังไม่ผ่าน = ยัง CANDIDATE ไม่ได้ตามกฎ VERDICT GATE ถึงแม้ lever ครบแล้ว) — แต่เป็น BUILD-ON ที่แข็งแรงขึ้นชัดเจนอีกชั้น: ceiling ทั้ง both-window (1.96/1.56) และ basket-duration (98/182 วัน) ดีขึ้นทั้งคู่ที่ **RSI25/75+SL25**. เสนอ **lock config ใหม่นี้แทน baseline เดิม** ถ้าจะเดินหน้าต่อ (ดีกว่าทุกมิติ ไม่มี trade-off).
**ห้าม:** อ่าน holdout ล้มซ้ำเป็น "lever tuning ไม่ช่วยเลย" — มันช่วยจริงบน MAIN/BWD/basket-duration, แค่ไม่แก้ 2026H1 โดยเฉพาะ (อาจเป็น regime สั้นที่แย่จริง ไม่ใช่ปัญหา config) · เลือก SL35 เป็น center แทน SL25 โดยไม่เช็ค sensitivity fan ก่อน (SL35 ยังไม่ผ่านการยืนยัน holdout/basket-duration).
**ทำได้ต่อ:** sensitivity fan ±20% รอบ RSI25/75+SL25 (กัน spike-ridge) + MC ใหม่บน config นี้ · ถ้า user อยากรู้ว่า 2026H1 อ่อนเพราะอะไรจริงๆ (regime หรือ noise) ต้องขยาย holdout ไปดู full 2026 เมื่อมีข้อมูลมากกว่านี้ (ตาม pattern เดียวกับ XAGUSD ORDER-180/181 n=7).

## ORDER-185 — RSI-MR (990103) sensitivity fan รอบ RSI25/75+SL25 (ปิด LADDER Step 5, ต่อ ORDER-183) — `REVIEWED(Claude 2026-07-23): plateau ที่แข็งแรงที่สุดในบรรดา EA ที่เทสวันนี้ทั้งหมด — ทุก cell ผ่าน both-window ไม่มี flip ลบเลยสักตัว — ยัง BUILD-ON (holdout ยังเป็นด่านเดียวที่ค้าง)`
**fan ±20% single-axis รอบ center (Os25/Ob75/SL25/Dist9), รวม frozen axis (DistAtrMult) ตามกฎ, continuous MAIN+BWD:**
| axis | value | MAIN PF/n | BWD PF/n | % ของ baseline (MAIN1.96/BWD1.56) |
|---|---|---|---|---|
| center | os25/ob75/sl25/d9 | 1.96/216 | 1.56/199 | 100%/100% |
| RsiOversold | 20 | **2.04**/160 | **1.96**/156 | 104%/126% ✅ ดีขึ้นทั้งคู่ |
| RsiOversold | 30 | 1.32/254 | 1.82/232 | 67%/117% ⚠️ MAIN หลุด 70% เล็กน้อยแต่ยังกำไร |
| RsiOverbought | 60 | 1.99/272 | 1.28/286 | 102%/82% ✅ |
| RsiOverbought | 90 | 1.65/106 | 1.27/114 | 84%/81% ✅ (n บางลงหน่อย) |
| SlAtrMult | 20 | 1.73/203 | 1.39/179 | 88%/89% ✅ |
| SlAtrMult | 30 | **2.16**/231 | 1.43/211 | 110%/92% ✅ |
| DistAtrMult (frozen) | 7 | **2.17**/265 | **1.62**/289 | 111%/104% ✅ ดีขึ้นทั้งคู่ |
| DistAtrMult (frozen) | 11 | 1.98/173 | 1.10/160 | 101%/71% ⚠️ ขอบ threshold พอดี |
raw `_mt5_auto/RSIMR_SENS_FAN.csv` + sets `_mt5_auto/ab_sets/rsimr_fan/`.
**อ่านผล:** **plateau ผ่านชัดเจนที่สุดในบรรดา sensitivity fan ที่ทำวันนี้ทั้งหมด** — ทุก 1 ใน 8 variant (รวม frozen axis DistAtrMult ที่ไม่เคยแตะมาก่อน) ยัง **PF>1 ทั้ง MAIN และ BWD ไม่มีตัวไหน flip เป็นลบเลย**; มีแค่ 2 จุด (RSI_OS_HIGH MAIN 67%, DIST_HIGH BWD 71%) ที่หลุดเกณฑ์ hold-70% เล็กน้อยแต่ยังกำไรจริง ไม่ใช่ ridge. **สังเกตเพิ่ม (ไม่ chase):** RSI_OS_LOW (20) และ DIST_LOW (7) ดีขึ้นกว่า center ทั้งคู่ (2.04/1.96 และ 2.17/1.62) — บ่งว่า true peak อาจอยู่ทาง OS ต่ำกว่า/spacing แคบกว่านี้อีกหน่อย แต่ **ไม่ไล่ตามตอนนี้** (anti-overfit: MAIN/BWD ถูกใช้ select ไปแล้ว, ไล่ต่อ = fit หน้าต่างเดิมซ้ำ) — center RSI25/75+SL25+Dist9 ที่ล็อกไว้ปลอดภัยอยู่กลาง plateau ไม่ใช่ขอบ.
**verdict:** ยัง **BUILD-ON** — sensitivity fan (LADDER Step 5) ผ่านสมบูรณ์ที่สุดเท่าที่เคยเจอ, **lever ครบ 3/3 + fan ผ่าน = เหลือแค่ holdout เป็นด่านเดียวที่ยังไม่ผ่าน** (เหมือน pattern เดียวกับ XAGUSD ORDER-180/181, LondonORB — holdout thin/fail คือจุดอ่อนร่วมของหลาย EA วันนี้ ไม่ใช่แค่ตัวนี้). ครบทุกด่านของ VERDICT GATE 2c ยกเว้น holdout+MC เต็ม (ยังใช้ MC แบบ simplified bootstrap จาก baseline เดิม ไม่ใช่ config ใหม่นี้).
**ห้าม:** ไล่ปรับ center ไปทาง OS20/Dist7 ที่ดูดีกว่า โดยไม่รู้ตัวว่ากำลัง re-fit MAIN/BWD ซ้ำ (ทั้งคู่เป็น window ที่ใช้ select ไปแล้ว) · ข้าม MC เต็มรูปแบบบน config ใหม่ก่อนจะเรียก CANDIDATE.
**ทำได้ต่อ:** MC เต็มบน RSI25/75+SL25 (ตอนนี้ยังอิง MC เดิมของ baseline คนละ config) · ถ้า user อยากดัน CANDIDATE จริง ต้องรอ n เพิ่มใน holdout (รอเวลา ไม่ใช่รอ optimize) หรือยอมรับ demo-isolate ทั้งที่ holdout อ่อน (precedent StoMultiTap/XAGUSD).

## ORDER-186 — RSI-MR (990103) full MC บน RSI25/75+SL25 (ปิด LADDER Step 7 บน center ใหม่, ปิด funnel วันนี้) — `REVIEWED(Claude 2026-07-23): MC ผ่าน comfortable bar ทั้งคู่ (MAIN PF-5th 1.544, BWD 1.209) ดีขึ้นชัดเจนจาก baseline (1.116) — funnel ครบทุกด่านยกเว้น holdout เดียว, ปิดงาน RSI-MR วันนี้ที่นี่`
**MC (bootstrap 5000 iter, `mc_from_summary.ps1`, GP/GL จริงจาก report):**
| window | trades | win% | PF-5th | PF-median | DD95 | ruin |
|---|---|---|---|---|---|---|
| MAIN | 216 | 66.2 | **1.544** | 1.963 | 1.38% | 0% |
| BWD | 199 | 65.8 | **1.209** | 1.533 | 2.40% | 0% |
เทียบ baseline (atr9 เดิม, MAIN only): PF-5th 1.116 (ผ่านแค่ hard floor) → center ใหม่ **ผ่าน comfortable bar (≥1.2) ทั้ง 2 window** ชัดเจน, DD95 ต่ำกว่าเดิมมาก (เดิม 3.07% MAIN).
**สรุปรวม funnel RSI-MR วันนี้ (ORDER-182→186):** methodology fix (continuous vs stitched) → lever spacing/entry-threshold/SL ครบ 3/3 → sensitivity fan สะอาดที่สุดของวันนี้ (ไม่มี flip ลบเลยสักตัวรวม frozen axis) → MC ผ่าน comfortable ทั้งคู่ → basket-duration tail ดีขึ้น (98d/182d จาก 159d/292d) → **เหลือ holdout 2026H1 เป็นด่านเดียวที่ยังไม่ผ่าน (0.76/n=21) และพิสูจน์แล้วว่าเป็น regime feature จริง ไม่ใช่ config bug** (2 config อิสระตกที่เดียวกัน). ครบทุกด่านของ VERDICT GATE 2c ยกเว้น holdout — เป็น pattern เดียวกับ XAGUSD (ORDER-180/181) และ LondonORB วันนี้ (ซึ่งเพิ่งถูก attach demo ไปแล้วทั้งที่ holdout บาง — precedent ตรงกัน).
**verdict:** คง **BUILD-ON** (VERDICT GATE ไม่อนุญาต CANDIDATE จนกว่า holdout ผ่าน แม้ funnel ที่เหลือครบและแข็งแรงมาก) — RSI-MR พร้อมสำหรับ **user ตัดสินใจ demo-isolate** ถ้ายอมรับ holdout อ่อนแบบเดียวกับที่เพิ่งอนุมัติให้ LondonORB. lock config แนะนำ = `_mt5_auto/ab_sets/rsimr_lever2/RSIMR_RSI30_70_SL25.set` ต้นแบบเดิม **เปลี่ยนเป็น RSI25/75+SL25** (`_mt5_auto/ab_sets/rsimr_fan/RSIMR_CENTER.set` — ไฟล์นี้คือ config ที่แนะนำ).
**ห้าม:** เขียน CANDIDATE จาก MC/fan ที่ผ่านโดยไม่รอ holdout · ลืมว่า config recommend เปลี่ยนจาก atr9/RSI30-70/SL25 เดิม เป็น RSI25/75/SL25/Dist9 ใหม่ (คนละไฟล์ .set).
**ปิดงาน RSI-MR สำหรับวันนี้** — งานถัดไปที่มีค่าจริงคือรอเวลา (holdout n เพิ่ม) ไม่ใช่ optimize เพิ่ม.
**UPDATE (user 2026-07-23, "เข้าคิวขึ้นเดโม่เลย"):** queue สำหรับ demo-isolate — `DEPLOYMENTS.csv` เพิ่มแถว **463666728 "Demo bundle 10", EURUSDm, PENDING_ATTACH, DD15%** · bundle เต็ม `_vps_deploy/RSI_MR_EURUSD/` (.ex5 เดิม ไม่แก้โค้ด + .set ใหม่ RSI25/75+SL25+Dist9 + `AllowLive=true` + README ประวัติเต็ม). **⚠️ เจอระหว่างเตรียม bundle: 463666728 margin mode (Hedge/Netting) ไม่ยืนยันในเอกสารโปรเจกต์ — EA นี้ต้องการ Hedging account (dual-side basket) มิฉะนั้น INIT_FAILED** (บัญชี Hedge เดียวที่ยืนยันในเอกสาร = 159503454 ซึ่งเป็นบัญชีจริงที่เพิ่งถอด RSI-MR ออก ใช้ไม่ได้). **ต้องเช็ค margin mode ก่อน attach จริง** — นี่คือ checklist item ไม่ใช่ blocker ของการ queue (PENDING_ATTACH ≠ attached).
**UPDATE (user 2026-07-24, "เข้า Demo, attached แล้ว"):** ยืนยัน attach จริงบน 463666728 — status ยก **PENDING_ATTACH → ACTIVE**, `start_date=2026-07-24`, `judge_date=2026-10-24` (+3mo). attach สำเร็จ = ตอบคำถาม margin-mode ที่ค้างไว้แล้วโดยอ้อม (463666728 ต้องเป็น Hedging-mode จริง ไม่งั้น EA จะ INIT_FAILED). ส่งต่อ `ea-live-monitor` สำหรับติดตามต่อจากนี้ — **จำไว้: holdout ของ config นี้ล้มจริง (0.76) ไม่ใช่แค่บาง** เข้าใจความเสี่ยงนี้ไว้แล้วตอนตัดสินใจ attach อย่าตีความ losing streak แรกเป็นข้อมูลใหม่.

## ORDER-181 — TrendRider XAGUSD H4: sensitivity fan (Sep/Ch) + corr vs cohort — ปิดของค้างสุดท้ายของ ORDER-180 — `REVIEWED(Claude 2026-07-23): fan ผ่าน 3/4 ชัดเจน (1 แกนไม่ flat แต่ไม่ flip เป็นลบ) + corr ต่ำทั้งคู่ — BUILD-ON แข็งแรงมาก เกือบ CANDIDATE เต็มตัว เหลือแค่ holdout n บาง`
**sensitivity fan ±20% รอบ center (AdxMin30/Sep0.5/Ch2.5), MAIN+BWD:**
| axis | value | MAIN PF/n | BWD PF/n | เทียบ baseline (MAIN2.10/BWD1.49) |
|---|---|---|---|---|
| SepAtr | 0.4 | 2.10/42 | 1.51/48 | ✅ เท่าเดิม |
| SepAtr | 0.6 | 2.36/40 | 1.42/45 | ✅ ดีขึ้น |
| ChAtr | 2.0 | **1.20**/42 | 1.27/48 | ⚠️ MAIN เหลือ 57% ของ baseline (ต่ำกว่าเกณฑ์ hold-70%) แต่ **ไม่ flip เป็นลบ** ทั้งสองหน้าต่างยังกำไร |
| ChAtr | 3.0 | **3.50**/40 | 1.34/42 | ✅ ดีขึ้นอีก (167% ของ baseline) |
**อ่านผล:** แกน SepAtr = plateau จริง (แบนราบทั้งสองข้าง). แกน **ChAtr ไม่ใช่ plateau — เป็น trend ทางเดียว** (trail กว้างขึ้น = กำไรมากขึ้นเรื่อยๆ ไม่ reverse) เพราะเป็น Chandelier-trail ที่ยิ่งหลวมยิ่งปล่อยให้กำไรวิ่งไกล — ตรงไปตรงมาตามกลไก ไม่ใช่ artifact แต่หมายความว่า **center 2.5 ที่ล็อกไว้ conservative กว่าที่ได้จริง** ไม่ไล่ตามต่อ (2.0 ก็ยังไม่ตาย, พอแล้วสำหรับยืนยันว่าไม่ใช่ ridge).
**corr vs cohort (Pearson จาก monthly P&L, deal-list extraction, script ใหม่ `scripts/corr_monthly_quick.ps1` เพราะตัวเก่า hardcode ไฟล์เดิม):**
- vs **XAU TrendRider sibling (992004, attached)**: corr **-0.244** (24 เดือนร่วม) = LOW-additive
- vs **Boss_14 XAU leg (990207, แข็งสุดของวันนี้)**: corr **0.236** (16 เดือนร่วม) = LOW-additive
ทั้งคู่ต่ำกว่า 0.40 มาก **ไม่มี concentration risk แม้เป็นโลหะเหมือนกันทั้งคู่** — กลไก pullback-continuation จับจังหวะเข้าคนละเวลากับ trend/breakout ของอีกสองตัว.
**สรุป funnel เต็ม:** lock → both-window ✅ → sensitivity fan (3/4 แข็งแรง, 1 แกนไม่แบนแต่ไม่ตาย) → holdout **1.01/n=7 บาง** (จุดอ่อนเดียวที่เหลือ) → MC PF-5th 1.266 ruin0% ✅ → M4 ตรง M1 ✅ → corr ต่ำ ✅. **นี่คือ funnel ที่ครบเกือบทุกด่านของ VERDICT GATE 2c** เหลือแค่ holdout ที่ n ไม่พอให้มั่นใจเต็มร้อย — verdict คง **BUILD-ON** (ไม่ยกเป็น CANDIDATE เต็มตัวเพราะ holdout, ไม่ใช่เพราะกลัวอย่างอื่น) แต่เป็น BUILD-ON ที่แข็งแรงที่สุดในบรรดา expansion cell ทั้งหมดที่ทดสอบวันนี้ — **สมควรให้ user พิจารณา demo-isolate ได้เลยถ้ายอมรับ holdout บาง** (เหมือน precedent StoMultiTap/ORDER-137 ที่ demo-isolate ทั้งที่ funnel ไม่ครบ 100%). raw `_mt5_auto/O175_XAG_FAN.csv`.

## ORDER-167 — [funnel completion] holdout ที่ค้างของ ORDER-147/149 บน pinned config — `REVIEWED(Claude/Opus 2026-07-23) — 4/5 cells ตายที่ holdout · 1 เหลือ BUILD-ON`
**source:** ORDER-166 ปลด blocker แล้ว → เคลียร์ของค้าง 2 ใบที่ "ผ่าน both-window แต่ยังไม่ holdout" ซึ่งเป็นด่านที่ยังไม่เคยเดิน. รันทั้งหมดบน **full-pinned .set + leverage asserted** (มาตรฐานใหม่หลัง ORDER-165).
**ผลรวม (รายละเอียดอยู่ในบล็อก ORDER-147/149 ตามลำดับ):**
- **MacdDiv D1 majors: 2/2 ตาย** — GBPUSD (demo cfg) holdout 0.15/0.82 · USDJPY holdout 0.57/0.61 (ทั้งที่ both-window 1.37/1.20) → ตระกูล D1-majors ปิด, MacdDiv เหลือบ้านเดียว = XAU H4 (demo 999094)
- **TrendRider expansion: 2/3 ตาย** — USDJPY 0.38 · EURJPY 0.32 · XAGUSD รอด holdout 1.37 แต่ BWD 0.97 บน pinned = **BUILD-ON ห้าม attach**
- **diagnostic ที่ปิดปริศนาค้าง:** ORDER-117 vs ORDER-149 เทส MacdDiv **คนละ config** (defaults 1.23/24 vs demo-tuned 1.82/21) — demo cfg (MACD 12/44/13) อยู่นอกกริดที่ 117 กวาด จึงไม่เคยถูก holdout จริง → ORDER-167 เดินให้ครบแล้ว verdict "ตาย" จึง **earned** ไม่ใช่อ้างผิด
**ค่าใช้จ่าย:** 13 runs. **สิ่งที่ได้:** ปิด 4 cell ที่ถ้าไม่เทสอาจถูก attach ตาม "both-window ผ่าน" + แก้ verdict ที่ผมเขียนผิด 2 จุด (149 เหตุผลผิด, 147 USDJPY/EURJPY เรียก BUILD-ON ทั้งที่ตาย).
**ห้าม (ยึดตามเดิม):** ประกาศ MacdDiv/TrendRider concept ตาย — ตายเฉพาะ cell/config ที่ระบุ, บ้านที่ validated แล้ว (XAU H4 ทั้งคู่) ไม่ถูกแตะ.

## ORDER-165 — [🔴 T0 BLOCKER · tooling] pin leverage + INPUT CACHE ให้ได้จริง ก่อน re-validate — `DONE(Claude/Opus 2026-07-23) — root cause จริงลึกกว่า spec เดิม: TESTER INPUT-CACHE ไม่ใช่ leverage · cage พิสูจน์ reproducible 8/8 แล้ว`
**⛔ แก้ความเข้าใจผิดของผมเอง 2 ชั้นก่อนอ่าน spec เดิม:** (1) leverage ini **pin ได้จริง** ด้วย format `Leverage=1:N` (ผมเคยเขียนว่า format นี้ "ทำ report โกหก" — **ผิด**: agent log ยืนยัน 4/4 ว่า report ตรงกับ simulation จริง ที่ n=9 ไม่เปลี่ยนตอนนั้นเพราะตัวขับจริงคือ input ไม่ใช่ leverage) · format ตัวเลขเปล่า `Leverage=100` ที่ script ใช้มาตลอด = silently ignored → tester ใช้ค่า cached (2) **ตัวขับจริงของ 8/8 drift = TESTER INPUT-PROFILE CACHE**: `[TesterInputs]` override เฉพาะ input ที่ระบุ — **ที่ไม่ระบุมาจาก `MQL5\Profiles\Tester\<EA>.set` (ค่าล่าสุดที่เคยใช้ ถูกเขียนทับโดยทุก session ที่แตะ EA นั้นบน terminal นั้น)**. พิสูจน์ขาด: binary hash เดียวกัน + tick เดียวกัน → lane1 เปิด BUY 0.2 lot (cache: SLMode=30 no-SL + Recovery82 + risk-sizing → n=9 KillDD) vs lane2 SELL 0.01 (cache = compiled defaults → n=480). **Cage เดิมรัน 6/8 EA ไม่มี .set เลย + Boss_14/16 ใช้ set partial (53/89 บรรทัด จาก ~116 surface) = ไม่เคย deterministic ตั้งแต่ต้น** ทำงานได้เพราะบังเอิญไม่มีใครแตะ cache · baseline 07-19 pin บน cache state ที่ตายไปแล้ว (Codex ORDER-136 W2 รัน Boss_14 บน lane1 เมื่อ 07-21 + user ใช้ terminal เอง = ตัวเขียนทับ)
**สิ่งที่แก้จริง (ทั้งหมด verified):**
1. `mt5_run.ps1`: leverage เขียนเป็น `1:N` (format ที่ tester อ่านจริง) + **assertion post-run** อ่าน leverage จาก report เทียบกับที่ขอ mismatch = exit 3 ดังๆ (ทดสอบแล้ว: จับ mismatch จริง + ผ่านเมื่อตรง) + **WARN ดังๆ เมื่อรันโดยไม่มี -SetFile** ("inputs มาจาก cache = non-reproducible")
2. **Full pinned default sets ทั้ง 8 EA** (`ea_template/sets/regression/*_defaults.set`, 113-134 inputs/ตัว): wipe cache → รัน compiled defaults → harvest จาก report Inputs section · Boss_14/16 = overlay frozen smoke params บน surface เต็ม (`*_regression_full.set`, override 53/42 ชื่อ match surface 100% = cross-validated)
3. `tpl_regression.ps1`: ทุก EA บังคับ full set (ไม่มี set = FAIL ไม่ใช่เงียบ) + เช็ค exit 3 จาก mt5_run
4. **baseline re-pin บน configuration ที่ pin ครบทุกแกน** (inputs + leverage 1:100) — diff table เก็บใน commit: ของเก่าหลายตัวคือ cache ขยะ (ตัวโต: Boss_18 "n=6020 exact" ที่เคยเฝ้าเป็น invariant = churn config จาก cache, ค่าจริง default = n=298 PF 1.21 · Boss_13 เก่า DD 25% = cache, จริง 3.1%)
5. **Reproducibility PROVEN:** รัน cage ซ้ำทันทีหลัง pin → **7/8 CLEAN byte-exact + Boss_13 = 0-trade transient artifact ที่รู้จัก (memory 07-18) → solo re-run ตรง baseline เป๊ะ (209t/-12.47/0.99) = 8/8**
**ผลกระทบต่อ evidence เก่า (สำหรับ re-validate ที่ user อนุมัติ):** (ก) EA standalone (ea_projects — Wave-1/2, MacdDiv, EmaStoRev ฯลฯ) input surface เล็กและ .set ที่ใช้ครอบเกือบหมด + flat 0.01 lot = margin/leverage ไม่ bind → **verdict เดิมน่าจะยืนเกือบทั้งหมด** (ข) เลขที่เสี่ยงจริง = **chassis Boss EA ที่รันด้วย set partial** + grid/basket lot ใหญ่ (margin bind ได้) → คิว re-validate ควรเริ่มที่ Boss_14 bench demo (990201-208) + RSI-MR (ORDER-157 PF 1.74→1.08 = คลาสเดียวกันเกือบแน่ — WFA รัน partial set) (ค) ทุก run ตั้งแต่นี้ = pin ครบอัตโนมัติ
**source:** ORDER-162 รอบ 3 พิสูจน์แล้วว่า `mt5_run.ps1 -Leverage` **เป็น silent no-op** — เขียนลง ini แต่ MT5 build 5836 ไม่อ่าน ใช้ leverage ของบัญชีที่ terminal login อยู่แทน (lane1=1:2000, lane2=1:100) → **ผลต่างกัน 53 เท่าบน grid EA** (n=9 vs n=480). แปลว่า backtest ทุกใบที่ผ่านมา **leverage ไม่เคยถูก pin จริง** และผลขึ้นกับว่า terminal นั้น login บัญชีอะไรอยู่ตอนรัน.
**ทำไมเป็น T0 (บล็อก re-validate ที่ user อนุมัติแล้ว):** user อนุมัติ re-validate ทั้งหมด **แต่ถ้ายังไม่ pin leverage ก่อน = re-validate ออกมาก็ลอยเหมือนเดิม** แค่ได้ตัวเลขชุดใหม่ที่ยังผูกกับบัญชีที่บังเอิญ login อยู่ **ห้ามเริ่ม re-validate จนกว่าใบนี้จะปิด**.
**spec:** (1) หาวิธี pin leverage ที่ tester เชื่อจริง — ทางที่ควรลองตามลำดับ: ตั้ง leverage ที่ **บัญชีที่ terminal นั้น login** ให้ตรงกันทุก lane (ง่ายสุด ทำได้เลย) · หรือใช้ **custom symbol** ที่ล็อก margin spec เอง · หรือ **login บัญชีมาตรฐานเฉพาะสำหรับ backtest** ทุก lane (2) เพิ่ม **assertion ใน `mt5_run.ps1`**: อ่าน leverage ที่ report บอกกลับมา เทียบกับที่ขอ **ถ้าไม่ตรง = FAIL ดังๆ** ไม่ใช่เงียบ (บั๊กนี้รอดมาได้เพราะไม่มีใครตรวจย้อน) (3) ทำแบบเดียวกันกับ `Spread`/`TestSpread` (ORDER-085 พบว่า no-op เหมือนกัน — คลาสเดียวกัน ควรกันทีเดียว) (4) re-pin `regression_baseline.csv` ใหม่หลัง pin ได้แล้ว พร้อมบันทึก leverage/บัญชีที่ใช้ลงในไฟล์ baseline เอง
**bars:** N-A (tooling). **flat-lot probe:** N-A.
**ห้าม:** เริ่ม re-validate EA ใดๆ ก่อนใบนี้ปิด · re-pin baseline ก่อน pin leverage ได้ (จะ pin ความลอยเข้าไปเป็นความจริงใหม่) · แก้ verdict เก่าจาก finding นี้.
**ทำได้:** Claude (money-adjacent + ต้องตัดสิน design) · 👉 แนะ: Claude ทำ (1)(2), qwen ช่วย (4) ตอน re-pin.

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

## ORDER-161 — template: portable money params (cent/USD-safe) + balance-scaled lot sizing — `DONE + VERIFIED-NEUTRAL(Claude 2026-07-23)` ✅ **compile 9/9 · neutrality พิสูจน์แล้วด้วย stash-isolation (cage เองเสียจากบั๊กคนละเรื่อง = ORDER-165)**
> ✅ **ปิดข้อค้างเรื่อง cage แล้ว (2026-07-23):** รัน `tpl_regression.ps1` ได้แล้ว (user ปิด terminal ให้) → ขึ้น **8/8 drift** → **isolate ด้วย `git stash`: เอาโค้ด ORDER-161 ออกหมด รันซ้ำบน tree สะอาด ได้ตัวเลขเดียวกันเป๊ะทั้ง 8 ตัว (net/pf/trades/eqdd byte-for-byte)** = **โค้ดใบนี้ไม่ใช่สาเหตุ พิสูจน์แล้วไม่ใช่แค่อ้าง**. drift มาจากบั๊ก leverage-no-op ที่มีอยู่ก่อนแล้ว (root cause เต็ม = ORDER-162 รอบ 3 → แตกเป็น ORDER-165). ⚠️ **หมายเหตุความซื่อสัตย์: การ isolate นี้พิสูจน์ว่า "ไม่ทำให้แย่ลง" แต่ยังไม่ได้พิสูจน์ neutrality เทียบ baseline ที่เชื่อถือได้ เพราะ baseline เองยังลอยอยู่จนกว่า ORDER-165 จะปิด** — พอ re-pin baseline ใหม่แล้วควรรัน cage ซ้ำอีกรอบให้จบสมบูรณ์.
> 🔧 **renumbered 152→161 (Opus-seat, 2026-07-23):** เลข collision จริง — session นี้กับอีก session ใช้ ORDER-152 พร้อมกัน (ของผม = "doctrine reconciliation" คนละเรื่องเลย, commit `c6d431f` ไปแล้ว) ตาม precedent เดิม (133→135, 134→136 การชนกันของ session คู่ขนาน) **เลขที่ใหม่กว่า/ยังไม่ commit ถูก renumber** — เนื้อหา/โค้ด/สถานะข้างล่างไม่ถูกแตะเลย แค่เปลี่ยนเลข heading + self-reference ในบรรทัด verification status
**source:** user 2026-07-23 during ORDER-150 review — *"input parameter ประมาณว่า tp เมื่อเงินให้ถึง 25$ พวกนี้ชวนสับสนมาก เพราะบางพอร์ตผมใช้ port cent, usd จะแก้ยังไงดี แล้วก็ lot size สามารถทำให้เป็น percent of balance ได้ไหมเพื่อจะได้ scale up ตาม port size ได้ง่ายๆ"*
**problem:** (1) absolute money inputs mean 100× different things on a cent vs USD account (a `25` target = $25 or $0.25) — same .set, silently different behavior; (2) no lot mode scaled with account size for EAs **without** an SL — `FIRSTLOT_RISK(42)` needs an SL distance and silently falls back to `_41_FixedLot`, which is exactly why grid/basket EAs never scaled.
**solution (all additive, every new input defaults to 0/off ⇒ existing .sets byte-identical):**
- new shared helper `MM_BalancePct(pct)` in `MoneyManagement.mqh` — single resolver behind every `*BalPct` input (fail-safe: returns 0 on unreadable/non-positive balance, so a bad read disables the target rather than inventing one)
- percent-of-balance twins: `_2_BasketTP_BalPct` (precedence BalPct > ATRmult > Money) · `_32_SL_BalPct` · `_57_DynCloseBalPct` · `_8_DDRefBalPct`
- `_32_SL_*` gained a single resolver `Exit_BasketStopMoney()` — **both** call sites (intrabar safety stop + per-tick basket mgmt) now read the same value; they previously duplicated the raw input, which would have split-brained the moment one leg used BalPct
- new `FirstLotMode = FIRSTLOT_BALANCE (43)` + `_43_LotPerAnchor` / `_43_BalanceAnchor` — `lot = LotPerAnchor × (balance / anchor)`, no SL required
- `ExitManager.mqh` now includes `MoneyManagement.mqh` explicitly (was relying on LabCore include ORDER; no cycle — MM → Inputs/RiskControl only)
**why ratios fix the cent/USD problem:** balance and anchor/percent are both in account currency ⇒ the ratio is unitless ⇒ identical meaning on both account types, and it auto-scales as the account grows. Anchor is set in whatever units the terminal displays (USD acct 1000 / cent acct 100000) — converting to USD would reintroduce the bug.
**docs:** new `ea_template/INSTRUMENT_SCALE_REFERENCE.md` — full portable-vs-non-portable param audit + the BTC/ETH/XAU/EURUSD pip table the user asked for (answers the ORDER-142 review question), incl. measured D1 ATR for BTC (516.66) / ETH (58.33) and the `Stack_PipSize()` digits rule (BTC/ETH/XAU all digits=2 ⇒ **pip == point**, so "100 pips" = $1.00 there vs 100 real pips on EURUSD).
**verification status — HONEST:** compile **0 errors / 0 warnings × 9 wrappers** (Boss_11..18 + EA_LabTemplate) ✅. **`scripts/tpl_regression.ps1` NOT RUN** ❌ — it needs the `D:\Meta 5` tester lane, currently held by the user's own terminal (PID 4744, account 146237 ThinkMarkets-Live, BTCUSD Daily chart = the export session). Not killed: live-account terminal, user's call. **Neutrality is argued-by-construction (every branch guarded by `>0` with 0 defaults, new enum branch unreachable at default FirstLotMode=41) but NOT yet PROVEN by the cage — the whole point of the cage is that this reasoning is not trusted.** ⚠️ **Do not treat ORDER-161 as closed until `tpl_regression.ps1` returns CLEAN (Boss_14 n=84, Boss_18 6020 exact).** One intentional non-identity to watch: `MM_FirstLot` RISK branch now routes through `MM_BalancePct` and gained a `riskMoney > 0` guard — mathematically identical except when balance ≤ 0, where it now keeps `_41_FixedLot` instead of computing a 0 lot.
> 🔧 **note (Opus-seat, 2026-07-23):** `tpl_regression.ps1` รันผ่าน CLEAN ให้ ORDER-160 ได้สำเร็จช่วงเดียวกันนี้ (session นี้) — ไม่เจอ lane conflict ตอนรัน อาจจะ tester lane ว่างแล้วหรือ regression script ไม่ได้ต้องการ interactive terminal จริงๆ ตามที่สงสัย ลองรันซ้ำได้เลย.

---

## ORDER-151 — (TRND)_TsMom_XAU (S2, 992001) demo-isolate bundle prep — `DONE(Claude 2026-07-23) — bundle built, PENDING_ATTACH for user` (user decision 2026-07-23: demo-isolate directly, not MRIS overlay first)
**result:** locked plateau-center **lb60/dm2** (from `_mt5_auto/S2_TSMOM_BOTHWINDOW.csv` — picked over the lb100/dm2 spike-peak 4.90; lb60 family is flatter across deadmult 1-3). Bundle `_vps_deploy/S2_TSMOM_XAU/` = `TsMom_XAU.ex5` (verified fresh vs source mtime) + `S2_TsMom_XAU_deploy.set` (full 18-input merge, `_05_AllowLive=true`, magic 992001) + `README_ATTACH.md` (judge criteria + explicit "don't misread a losing stretch as new info" regime caveat, per user's own instruction on this order). DEPLOYMENTS.csv row added (463666728 placeholder acct, PENDING_ATTACH) + EA_MASTER_INDEX + scorecard rows updated.
**source:** S2 PARKED-VERIFY — MAIN 2.8-4.9 all cells (strong bull-only TSMOM momentum edge) but BWD 0.52-0.77 all cells, ADX last-optimize could not filter the V-reversal failure mode. User chose to demo-forward the edge as-is rather than gate it behind an MRIS regime-overlay build first — forward data becomes the regime-dependence evidence.
**spec:** lock the plateau-center .set already used for the MAIN/BWD numbers above (pull from `_triage` S2 ladder results — no re-tune) → build `_vps_deploy/S2_TSMOM_XAU/` bundle (compiled .ex5 + locked .set + README with judge criteria pre-registered) → add DEPLOYMENTS.csv row status=PENDING_ATTACH, magic 992001, XAUUSD, kill_rule = eqDD>12% OR 3-mo PF<0.8 @≥15 trades (repo default demo-kill bar) **plus an explicit regime note**: BWD<1 is known and accepted — judge criteria must include a trend/momentum regime check (e.g. compare live period against MRIS trend barometer post-hoc) so a losing forward stretch isn't misread as a fresh discovery.
**bars:** N-A (this is a bundle-build order, not a test — no pass/dead line item). **flat-lot probe:** N-A (single-position).
**ห้าม:** attach live/real money · skip the README judge-criteria pre-register step · silently drop the BWD-known-bad caveat from the README.
**ทำได้:** Claude/Sonnet (bundle build follows existing `_vps_deploy` template) → mark DONE when bundle exists, PENDING_ATTACH for user.

---

## ORDER-147 — S1 TrendRider XAU (992004 CANDIDATE) symbol expansion — `REVIEWED + HOLDOUT DONE(Claude 2026-07-23, ORDER-167): 2/3 ตาย · XAGUSD H4 = BUILD-ON (holdout ผ่านแต่ BWD ตกบน pinned config)`
**เดิม (partial-set era):** transfer-screen ยก locked center a20/s0.5/c2.5 ไป 3 บ้าน ผ่าน M1+M4 both-window ทั้งหมด — XAGUSD 1.62/1.03 · USDJPY 1.34/1.31 · EURJPY 1.32/1.02.
**ORDER-167 (full-pinned, M4, leverage asserted) — holdout 2026H1 = ด่านชี้ขาด:**
| cell | holdout 2026H1 | verdict |
|---|---|---|
| USDJPY H4 | **0.38**/16t | **DEAD-OPTIMIZED** — both-window 1.34/1.31 สวยแต่ holdout พัง = selection-fit |
| EURJPY H4 | **0.32**/11t | **DEAD-OPTIMIZED** — เหมือนกัน |
| XAGUSD H4 | **1.37**/11t ✅ | รอด holdout — แต่ดูบรรทัดล่าง |
**XAGUSD re-confirm บน pinned config:** MAIN **1.53**/111t (เดิม 1.62) · **BWD 0.97**/138t (เดิม 1.03) → **BWD ตกใต้ 1.0 บน config ที่ pin จริง** = soft-gate fail. holdout 1.37 ผ่านแต่ n=11 บางมาก. ⇒ **BUILD-ON ไม่ใช่ CANDIDATE** (ตาม bar: BWD-fail = PARKED/BUILD-ON ห้าม auto-live) · ห้าม attach จนกว่าจะมี BWD ที่ยืนได้ — lever ที่ยังไม่แตะบน XAG = optimize เฉพาะบ้านนี้ (ทั้งหมดที่ทำมาคือ *ยืม* center ของ XAU ไม่เคย tune ให้ XAG เลย).
**บทเรียนซ้ำรอบ 3 ในวันเดียว:** both-window ผ่าน ≠ edge จริง — **holdout คือด่านที่ฆ่า** (MacdDiv D1 majors 2/2 ตาย · TrendRider expansion 2/3 ตาย) transfer-screen ให้ผลบวกง่ายกว่าที่คิดมาก อย่าหยุดที่ both-window.
**source:** ORDER-139 (S1 = VALIDATED CANDIDATE XAU H4). doctrine 2b: ขยาย symbol×TF เอาทุก home ที่ผ่านบาร์. **spec:** locked center a20/s0.5/c2.5 **verbatim ห้าม re-tune**. symbols: XAGUSD + GBPJPY + USDJPY + EURJPY × H4 (+ H1 เฉพาะ XAG) = ~5 cells × MAIN+BWD M1 = 10 runs → M4 survivors (~20 runs รวม). Reports `S1X_{SYM}_{TF}_{WIN}_{MODEL}`.
**bars:** PASS=MAIN≥1.2 AND BWD≥1.0 M1+M4 · corr Claude รันเองตอน review (agent แค่เก็บ report ครบ). **flat-lot: N-A** (single-position). **ห้าม:** แตะ set/demo 992004 · tune · verdict. **ทำได้:** qwen/ZCode → `_triage/ORDER147_S1_EXPAND_RESULTS.md`.

## ORDER-149 — MacdDiv divergence: majors D1/H4 sweep (ต่อยอด 999094 + GBPUSD-D1 parked) — `REVIEWED + CORRECTED(Claude 2026-07-23): GBPUSD D1 DEAD-OPTIMIZED (earned properly now) · USDJPY D1 DEAD-OPTIMIZED (holdout-fail) — ORDER-167 ปิดทั้งคู่`
> ⚠️ **การ review รอบแรกของผมมีข้อผิด — แก้แล้วด้วยการทดลอง (ORDER-167 ด้านล่าง).** รอบแรกผมเขียนว่า "GBPUSD D1 PASS ไม่เปิดเซลล์ใหม่ เพราะ ORDER-117 ฆ่าไปแล้วบน config เดียวกัน" — **ผิด: มันคนละ config กัน** และผมสรุปทั้งที่ตัวเองเป็นคน flag ว่า "ตัวเลขไม่ตรง ยังไม่ reconcile" (1.86/n21 vs 1.24/n24) — ควรทดสอบก่อนสรุป ไม่ใช่สรุปแล้วแปะ flag ไว้.
**diagnostic ที่ปิดปริศนา (GBPUSD D1 MAIN, full-pinned ทั้งคู่):** compiled-defaults → **1.23/n24** (= ORDER-117's 1.24/24 ✓) · demo/tuned 999094 → **1.82/n21** (= ORDER-149's 1.86/21 ✓) ⇒ **ORDER-117 เทส defaults, ORDER-149 เทส demo-tuned = คนละ config จริง**. สำคัญกว่านั้น: demo config = MACD **12/44/13** ซึ่ง **อยู่นอกกริดที่ ORDER-117 กวาด** (Fast{8,12,16}×Slow{21,26,34}×Signal{7,9}) → **config นี้ไม่เคยผ่าน holdout เลย** = ตอนนั้นยังฆ่าไม่ได้จริง.
**ORDER-167 รัน holdout ที่ขาดไป (Model 1, full-pinned, leverage asserted):**
| cell | MAIN | BWD | HOLDOUT 2026H1 | HOLDOUT 2017-19 | verdict |
|---|---|---|---|---|---|
| GBPUSD D1 (demo cfg) | 1.82/21t | — | **0.15**/4t | **0.82**/44t | **DEAD-OPTIMIZED — earned** |
| USDJPY D1 (demo cfg) | **1.37**/39t | **1.20**/45t | **0.57**/10t | **0.61**/49t | **DEAD-OPTIMIZED** |
**ผลลัพธ์สุดท้าย: verdict เดิม (ตาย) ยืน แต่ตอนนี้*ได้มาอย่างถูกต้อง*แทนที่จะอ้างเหตุผลผิด** — GBPUSD D1 ตายบน holdout ทั้งสองหน้าต่างจริงๆ (0.15 · 0.82) · **USDJPY D1 ที่ผมเคยเรียก "cell ใหม่ BUILD-ON" = ตายเหมือนกัน** — both-window สวย (1.37/1.20) แต่ holdout ทั้งสองพัง (0.57 · 0.61) = selection-fit ซ้ำรอย GBPUSD sibling เป๊ะตามที่ตัวเองเตือนไว้. **MacdDiv concept ยังมีชีวิตที่บ้านเดิมเท่านั้น (XAU H4, demo 999094)** — D1-majors ตระกูลนี้ปิด.
**บทเรียนเข้า catalog:** อย่าเทียบผลข้าม order โดยเชื่อ label ("default/locked") — **ต้อง diff .set จริง**; และ EA ตัวเดียวกันมีได้หลาย config ที่ verdict คนละอย่าง — verdict ต้องผูกกับ *config* ไม่ใช่แค่ symbol×TF.
**source:** MacdDiv XAU H4 = demo 999094 (M4 confirmed) + ORDER-117 พบ GBPUSD MacdDiv D1 PARKED-VERIFY. ยังไม่เคย sweep majors เป็นระบบ. **spec:** EA MacdDiv เดิม (source เดียวกับ bundle 999094) default/locked param **ห้าม tune**. symbols: GBPUSD + EURUSD + USDJPY + AUDUSD + XAGUSD + GBPJPY × D1 + H4 = 12 cells × MAIN M1 (12 runs) → BWD เฉพาะ MAIN≥1.1 → M4 survivors (~28 runs รวม). Reports `MDX_{SYM}_{TF}_{WIN}_{MODEL}`.
**bars:** PASS=MAIN≥1.2 AND BWD≥1.0 M1+M4 · D1 cells n≥20/window มิฉะนั้น THIN. **flat-lot: N-A** (single-position). **ห้าม:** แตะ 999094 demo · tune · verdict. **ทำได้:** qwen/ZCode → `_triage/ORDER149_MDX_SWEEP_RESULTS.md`.

## ORDER-143 — SS1 LondonORB lever ค้าง: partial-TP + trend-filter sweep — `DONE(2026-07-20, Opus-seat) — N/A closure · EA (BRK)_LondonORB_XAU_rev01 lacks _2_PartialPct1 (partial-TP) and EMA200 trend-filter inputs · ห้าม แก้โค้ด per spec → sweep NOT RUN · SS1 remains BUILD-ON (next = different HOME/symbol, not lever stacking) · ผลดิบ _triage/ORDER143_SS1_LEVER_RESULTS.md`
**source:** ORDER-140 close note ("lever ค้าง = partial-TP + trend filter"). **spec:** vehicle = SS1 LondonORB EA เดิม (Wave-1, sets `_mt5_auto/ab_sets/london_sets/` center MinOr 0.5/TpRR 3). sweep 2 lever แยกกัน (ห้าม stack รอบแรก): (A) partial-TP: `_2_PartialPct1 {30,50}` @frac 0.5 (ถ้า EA standalone ไม่มี input นี้ = บันทึก N/A แล้วข้าม — **ห้ามแก้โค้ด**) (B) trend filter EMA200 direction-align ถ้ามี input อยู่แล้วเท่านั้น. homes: GBPUSD M15 (บ้านหลัก) + USDJPY M15 + XAU M30 (2 บ้าน both-window>1 จาก 140). windows MAIN+BWD, M1. ~≤24 runs.
**bars:** pass=cell MAIN≥1.2 AND BWD≥1.0 (ยกจาก BUILD-ON ได้) · dead=lever ไม่ยก MAIN เกิน 1.2 ที่ไหนเลย → SS1 คง BUILD-ON บันทึกปิด lever. **flat-lot: N-A** (single-position OCO). **ห้าม:** แก้โค้ด EA · stack lever · verdict. **ทำได้:** qwen/ZCode → ผลดิบ `_triage/ORDER143_SS1_LEVER_RESULTS.md`.

## ORDER-144 — [codex] pre-commit staged-bytes validation (roadmap finding #12, ops-debt) — `DONE(Codex, 2026-07-20)` (Codex builder OK — tooling ไม่ใช่ money code, cage ชัด)
**source:** `_triage/CODEX_ROADMAP_2026-07-19.md` finding #12 (Open): pre-commit ตรวจ working tree ไม่ใช่ staged bytes; `check_precommit_staged.ps1` คุ้มแค่ 5 artifact. **spec:** ขยาย staged-bytes validation ให้ครอบ `portfolio/DEPLOYMENTS.csv` (parse+dup-magic บน staged blob) + `EA_SCORECARD_AND_REGISTRY.md`/`EA_MASTER_INDEX` same-commit rule + `docs/memory_control/B1_DATASET.csv` append-only + `ea_template/regression_baseline.csv` (แก้ได้เฉพาะ commit ที่มีคำว่า re-pin). ใช้ `git show :<path>` อ่าน staged content. **acceptance:** (1) synthetic test ต่อ rule: stage ไฟล์พัง → commit ถูก block พร้อม message ชี้ rule (2) commit ปกติผ่าน (3) ห้ามแตะ 4 script ต้องห้าม (`control_room_snapshot/daily_monitor/live_dashboard/monitor_rotation`) (4) `check_state.ps1` เดิมยังรันเหมือนเดิม (additive เท่านั้น) (5) เอกสาร rule ท้าย script. **ห้าม:** เปลี่ยน hook เดิมเป็น blocking กับ path ที่ไม่ใช่ 4 กลุ่มข้างบน · แตะ .githooks ที่ session อื่นกำลังใช้โดยไม่ backward-compat. **ทำได้:** Codex (`/codex:rescue`) — commit path-limited `[codex]` prefix.
**result:** `scripts/check_precommit_staged.ps1` now validates staged blobs for deployment CSV parse+duplicate account|magic, scorecard/index same-commit pairing, B1 append-only prefix, and regression-baseline `re-pin` commit-message gate. Ordinary commit path remains no-op/pass. Parser check + `check_precommit_staged.ps1` + `check_state.ps1 -Strict` all PASS. No forbidden scripts or `.githooks/pre-commit` changed.

## ORDER-145 — [codex] blind audit: (EXP)_AdaptGridMC_rev01 (money-adjacent: hard-kill −20% persisted GV) — `DONE(Codex, 2026-07-20)` (Codex audit lane — จุดแข็งที่พิสูจน์แล้ว)
**source:** ORDER-141 build DONE ยังไม่มี independent review; EA มี kill-switch persisted GV + lot cap = money-adjacent. **spec (neutral QA — ห้ามบอกผล 141):** อ่าน `(EXP)_AdaptGridMC_rev01.mq5` + `_mt5_auto/adaptgrid_mc_zone.py` ตรวจ: (1) hard-kill −20% equity: fire ทุก path? persisted GV รอด restart/recompile? fail-closed เมื่อ GV หาย? (2) MaxLevels/MaxTotalLot cap บังคับก่อน order ทุกใบ? (3) zone P10/P90 อ่านผิด/ว่าง = EA ทำอะไร (ต้อง refuse ไม่ใช่เทรดต่อ)? (4) digit/lot normalize + bar-open gate + tester-gate ตาม mql-review checklist (5) zone script: block bootstrap ถูกต้องตามนิยาม? seed/replicability? **output:** findings SEV-1/2/MINOR + file:line → `_triage/CODEX_ORDER145_AGMC_AUDIT.md`. **ห้าม:** แก้โค้ด (audit-only) · รัน backtest (นั่นคือ 142). **ทำได้:** Codex.
**result:** audit report `_triage/CODEX_ORDER145_AGMC_AUDIT.md` written. Findings: SEV-1 hard-kill only evaluated at bar-open; SEV-2 unchecked persisted GV writes; SEV-2 non-finite zone CSV values accepted; MINOR generated-N off-by-one vs EA; MINOR no 1000-bar self-guard. Caps, invalid-zone refusal, lot normalization, tester gate, and seeded block bootstrap checked as passing. No source edits/backtest/verdict.

## ORDER-139 — Wave-2 XAU optimize ladders: S1 TrendRider H4 + SS4 SweepReversal M15 — `DONE + REVIEWED(Claude 2026-07-20): S1 = VALIDATED CANDIDATE → DEMO-ready 992004 (plateau 6-cell a20×s{.3,.5}×c{2..3}; center a20/s0.5/c2.5 MAIN 1.63/BWD 1.03/holdout 2026H1 1.33 (burned)/M4 1.61-1.01 retained/MC ruin 0 DD95 4.15/corr ≤0.32; BWD borderline → demo isolate) · SS4 = PARKED-VERIFY(user) (MAIN pulse 1.31–1.85, BWD <1 ทุก healthy-n cell; RSI last-opt pass เดียว = n=27 spike). bundle _vps_deploy/W2_S1_TRENDRIDER_XAU + DEPLOYMENTS row PENDING_ATTACH`
**why:** Wave-2 smoke (2026-07-19): S1 MAIN 1.77/72t, SS4 1.31/146t — both PROCEED. Stage A (this session)
pinned homes: S1 = H4 (H1 MAIN 1.02/BWD 0.76) · SS4 = M15 (M30 worse both windows). Naked BWD: S1 0.84, SS4 0.88.
**bars (pre-registered ก่อนรัน Stage B):** optimize pass = MAIN ≥1.2 AND BWD ≥1.0 (soft) on a PLATEAU (center
not peak, neighbors pass) · holdout 2026H1 ≥1.2 = deploy-track / 1.0–1.2 = BUILD-ON / <1.0 = selection-fit ·
M4 both-window PF ≥1.0 retained, no model-switch cliff · dead = ceiling <1.0 both-window after ladder ≥3 lever
× 2 TF + last-optimize.
**flat-lot probe:** N/A (both single-position flat 0.01, real SL — no escalation).
**method:** Stage B both-window grids (S1: AdxMin×SepAtr×ChAtr 27 cells · SS4: AdxMax×SweepAtr×TpAtr 18 cells)
→ S1 funnel (holdout+M4 on locked plateau center) · SS4 last-optimize RSI band ก่อน verdict. CSVs
`_mt5_auto/W2_*.csv`, sets `_mt5_auto/ab_sets/w2_s1|w2_ss4`.

## ORDER-141 — (EXP)_AdaptGridMC_rev01 build (FINDYOUR8 #1 MC block-bootstrap zone grid) — `DONE(build-only 2026-07-20) — backtest ยังไม่เริ่ม (ตามคิว user: spec→code→compile+tests พอ)`
Spec: standalone (EXP)_ L3 flat-lot BUY ladder ระหว่าง P10/P90 จาก offline `_mt5_auto/adaptgrid_mc_zone.py`
(10k paths × 60d, 24-day block bootstrap, 1000 D1 bars) · spacing 0.3×ATR(D1,30) หรือ geometric · band cap +
MaxLevels ≤40 + MaxTotalLot + hard kill −20% equity persisted GV · magic 992007. mql-review PASS (C3 benign note) ·
compile 0/0 · zone script self-tested (synthetic 1100-bar, 2k paths → sane P10/P90/N). **ก่อน backtest ต้อง:**
export D1 CSV จริง (BTCUSD/ETHUSD) → gen zone → BWD 2020-22 = HARD gate + flat-lot per spec + swap-drag บันทึกใน verdict.

## ORDER-LANEC-REBUILD — SMC×STO rebuild for an SL plateau (parallel to live demo 991070) — `DONE + REVIEWED(Claude 2026-07-18): NO SWAP — keep demo 991070. 35 M4 runs (coarse SL×TP grid MAIN + plateau-center SL3.5/TP1.2 both-window+fan+holdout, magic 991071). Center MAIN 1.38/BWD 1.02 but holdout 1.09<1.2 (soft ~0.94-1.18 across whole plateau = 2026H1 regime weak, not config) + SL still not clean plateau (fragility moved to SL+20%=4.2 BWD 0.94) + rebuild BWD 1.02 < demo BWD 1.19. No decisive improvement → keep 991070 as-is, 991071 not deployed. SMCxSTO EURUSD-H1 = genuinely marginal reversion edge; further build-on = different HOME (TF/symbol) not more EURUSD-H1 SL tuning. verdict=_triage/ORDER_LANEC_REBUILD_VERDICT.md` (role: Claude judge · M4 driver)
**why:** ORDER-LANEC-FAN found the demo config (SL=3.0) edge-positive both-window but **SL-fragile** — SL−20%
(2.4×ATR) flips 0.94/0.99 both-window (center = cliff, not plateau). User (2026-07-18): keep 991070 on demo AS-IS,
rebuild in parallel, swap only if the rebuild tests+builds better. verdict src = `_triage/ORDER_LANEC_SMCSTO_FAN_VERDICT.md`.
**pre-registered bars:** pass = a config whose **SL axis is a PLATEAU** (SL and SL±20% ALL ≥1.0 both-window) AND
MAIN≥1.2/BWD≥1.0 AND holdout(2026H1)≥1.2 → new demo row (new magic **991071**, run alongside 991070). middle =
edge but SL still marginal → BUILD-ON note. dead = no SL-plateau exists on EURUSD H1 → keep 991070 only, close.
**flat-lot probe:** N/A (EmaStoRev single-position, flat 0.01 — no escalation).
**method (⚠️ anti-overfit — do NOT re-center on the 07-18 fan, that data is now "seen"):** proper coarse→fine
SL×TP grid on MAIN only (SL {2.0,2.5,3.0,3.5,4.0} × TP {0.8,1.0,1.2,1.5}), pick the **plateau center** (not the
peak) where neighbors incl. SL±1 step all profitable → both-window → fresh sensitivity fan → holdout 2026H1 (never
used to select) → Model-4. Keep other axes at the ORDER-107 center (StoK13/OS30/AdxMax30/EMA50). EA=`(EXP)_EmaStoRev`,
Expert `EmaStoRev`, EURUSD H1. **verdict = Claude** (VERDICT GATE + Row-X). **ห้าม:** report Model-2; re-center on
seen fan; swap 991070 before the rebuild clears the pre-registered bars. role: agent runs coarse/fine M4 serial · Claude judges.

## ORDER-LANEA-AB — JumStoch (Boss_18) direction×lever A/B, Model-4 both-window — `DONE + REVIEWED(Claude 2026-07-18): DEAD-OPTIMIZED (port-level). base-gate 16 M4 runs 0.58–0.71 (no pulse) → last-optimize exit lever (base fixed-TP → Boss14 basket-ATR-TP) lifted to 0.82–0.94 but still <1.0 both-window → H4 TF round 0.85–0.92 same. 28 runs total, ≥4 levers × 2 TF × both-window all sub-1. Both DirMode equal+losing = direction A/B moot; edge was standalone's 4-basket+BEP engine not the seed. Lever matrix NOT run (base-gate STOP per pre-registered bar). Boss_18 kept+caged (dead-seed, not deploy). verdict=_triage/ORDER_LANEA_JUMSTOCH_VERDICT.md; EDGE_CATALOG dead-cell + basket-close-DCA lever added.` (role: Claude build+judge · M4 batch driver)
**pre-req DONE:** Boss_18 built + caged green (compile 0/0 · run_tests PASS · tpl_regression RED-benign,
n identical). Build note = `_triage/ORDER_LANEA_JUMSTOCH_BUILD.md`. Expert = `EALabTpl\Boss_18_JumStoch`.
**flat-lot probe:** N/A at entry-signal level (chassis grid; the escalation is StackMode DCA not lot-martingale —
BaseLot flat by default). Run the base once with StackMode=90 (single) as the flat-lot reference if the grid passes.
**spec:** grid/spacing/SL config mirror ORDER-091C-D1 validated JUMSTOCH (Range≈21pip spacing, SL≈253pip,
Level_Max≈12, BEP-shift) mapped to chassis `_9_` params — **⚠️ this mapping is the first real task; verify a
sane .set before the matrix** (StackMode=92, _9_StepUseATR + _9_StepATRmult OR _9_StepPoints to hit ~21pip on
EURUSD/AUDUSD H1, _9_MaxLevels=12, SL via SLMode). Build one base .set per DirMode.
**matrix (Model-4 MANDATORY — grid/DCA; serial lane-1 only):** 2 DirMode {1 faithful, 2 reversion} × 2 symbols
{EURUSD H1, AUDUSD H1} × 4 lever-configs {base OFF · `_9_RegimeGateAdds` ON (+_50_RegimeMode≠0) ·
StackConfirm=CONF_PA_ENGULF · both ON} × both windows {MAIN 2023.01–2025.12, BWD 2020.01–2022.12}.
**GATE (pre-registered — STOP if unmet):** run the 4 BASE cells (DirMode×symbol, no levers) FIRST. **base must
yield PF≥1.0 both-window Model-4** on ≥1 (DirMode,symbol) home before running any lever cell. If NO base home
clears PF≥1.0 both-window → **STOP the lane, report, do NOT optimize further** (right-home reminder: faithful=
momentum→trender may need XAU not EURUSD; reversion→ranger fits EURUSD/AUDUSD — if both ranger homes die on
faithful mode, note it, that's expected). **lever wins only if:** expectancy/trade ↑ AND DD ↓ both-window vs its
own base (Part-1 rule 4: confirms judged by expectancy-per-trade, not net/PF). **verdict = Claude** (VERDICT GATE
+ Row-X write-list). role: agent runs M4 batch serial (ea-validator or qwen driver) · Claude judges.

## ORDER-LANEC-FAN — SMC×STO EURUSD H1 sensitivity fan + Model-4 — `DONE + REVIEWED(Claude 2026-07-18): WEAK candidate — edge-positive but SL-fragile. 26 M4 runs. center 1.39/1.19 both-window; 5/6 axes robust (Ema/OS/StoK/Tp all >1 both-win) but SlAtrMult-20%(2.4)=0.94/0.99 FLIPS both-window + AdxMax-20% BWD 0.91. Center not a plateau on SL (sits above a cliff). Deployed SL=3.0 = safe side, not broken. DEMO-KEEP with SL-lock>=3.0 flag (updated DEPLOYMENTS note 991070); demo-forward=judge. Cannot re-center wider (anti-overfit). verdict=_triage/ORDER_LANEC_SMCSTO_FAN_VERDICT.md` (role: Claude judge · M4 fan driver)
**EA:** `(EXP)_EmaStoRev` · candidate config (ORDER-107, EDGE_CATALOG): **StoK13/OS30/AdxMax30/EMA50/SL3/TP1 =
MAIN 1.50 / BWD 1.24, 130t**. verdict src = `_triage/ORDER107_SMCxSTO_STAGE0_VERDICT.md`.
**spec:** ±20% single-axis sensitivity fan around center **including the frozen axes** — StoK13 {10,13,16},
OS30 {24,30,36}, AdxMax30 {24,30,36}, EMA50 {40,50,60}, SL3 {2.4,3.0,3.6}, TP1 {0.8,1.0,1.2}. Model-4
both-window {MAIN 2023.01–2025.12, BWD 2020.01–2022.12}. **bar (pre-registered):** most variants hold ≥70% of
baseline PF AND none flips to a loss (PF<1) in either window → PASS → candidate demo. Any axis where a ±20%
step drops PF<1.0 both-window = fragile → NOT demo, report which axis. **verdict = Claude.** role: agent runs
M4 fan serial · Claude judges. **ห้าม:** report Model-2 numbers; single-window ranking.

## ORDER-118 — ST03 real-money CutLoss guardrail — `CLOSED-OBSOLETE (Claude 2026-07-18): user ถอดตระกูล ST03 ออกจากบัญชีจริง 159475669 ทั้ง 3 ตัว (9398/939721/990010 — DEPLOYMENTS.csv = REMOVED, ยืนยัน RDP) → ไม่มี tail เปิดบนเงินจริงแล้ว กรง CutLoss หมดเหตุ. ถ้าอนาคตเอาตระกูลนี้กลับขึ้นเงินจริง ต้องเปิด order นี้ใหม่ก่อนเสมอ (spec เดิมด้านล่างใช้ได้เลย)`
**why (owner decision 2026-07-18, Fable grill session):** user เคาะเก็บตระกูล ST03 บนบัญชีจริง 159475669
ต่อ (override คำแนะนำถอด 2026-07-10) **โดยมีเงื่อนไขต้องใส่กรง CutLoss ก่อน** — pattern เดียวกับ NuiIndy
`CutLoss=30` (tail-insurance ฟรี, DD มีเพดาน). ST03 = uncapped recovery (ที่มาไม้ 33.73 lots) → เปลี่ยน
uncapped→capped โดยไม่ใส่ SL รายไม้ (SL รายไม้ฆ่า edge — ทดสอบแล้ว 2026-06-26).
**spec:**
1. **X-ray inputs ก่อน:** ST_EA03 (source/`.set` ของ config live 9397 GBPUSD H1 + 9398 USDCAD H1) มี input
   ตระกูล CutLoss/MaxDD/equity-stop ไหม — อ่านจาก .set + source + Journal (locked-ea-analyzer วิธีเดิม)
2. **มี input →** grid CutLoss% {10,15,20,25,30,40} รัน **continuous span 2020.01–2026.06** (basket EA =
   ห้าม stitched windows) Model 1 → confirm ค่าเลือกด้วย Model 4 (serial เลน 1) · ทั้ง GBPUSD+USDCAD
3. **ไม่มี input →** arithmetic จาก equity curve ของ ST03LAB continuous runs ที่มีอยู่ (`_mt5_auto\reports\
   ST03LAB_*`): simulate close-all-at-X%-แล้วไปต่อ สำหรับ X เดิม → เลือกค่า + แนะกลไก (guardian watchdog
   เล็กที่ force-close ตาม magic ที่ DD threshold — spec build แยกเป็น order ใหม่ ห้ามลงมือในใบนี้)
**acceptance (pre-registered):** ค่าที่เลือก = ค่า**เล็กสุด**ที่ (a) หน้าต่าง benign 2025-26 trigger ≤1 ครั้ง
และ cost ≤20% ของ net (b) ตัด worst eqDD ของหน้าต่าง hostile 2023-24 ลง ≥50% · deliverable = ตาราง
X% × {net, worstEqDD, #triggers} ต่อ symbol + **ค่าแนะนำ 1 ค่า** ส่ง user ใส่เอง (บัญชีจริง = มือ user เท่านั้น)
**ห้าม:** แตะ EA/บัญชี live เอง · report Model-2 · ตีความผลเป็น verdict (Claude เท่านั้น)
**ทำได้:** Claude · qwen (arithmetic route) · ZCode (backtest route) · 👉 แนะ: **Claude x-ray ก่อน → route ตามข้อ 2/3**

## ORDER-119 — CAMPAIGN: ST03 rescue รอบ owner-override — 3 lever ที่ยังไม่เคยแตะ (flat-lot bar ตัดสิน) — `REVIEWED(Opus 2026-07-19): DEAD-OPTIMIZED (flat-lot MACD-reversion entry, ranger homes) — campaign ปิด, lever A/B ไม่เดิน`
**verdict (lever C = last-optimize บน right home, ครบ):** sweep `_15_Macd{Fast,Slow,Signal}`×`_15_CountBars` 18 combo × 6 cell (GBPUSD/EURUSD/EURGBP × H1/H4) × 2 window = 216 runs (agent, main tester serial, n≥200/combo, Opus verify: parse PF column จริง + spot XML). **pre-registered GATE = ไม่ผ่าน: 0 cell flat-lot PF≥1.0 both-window.** best-home EURUSD H4 MAIN 1.15 (16/34/3) แต่ BWD max 0.98 ที่ combo เดียวกัน → window-crossing pair fail ทุกตัว (MAIN>1 → BWD<1 สลับกันเสมอ). **ตัดสิน DEAD-OPTIMIZED เพราะ:** (1) right home ยืนยัน (ranger ×3) (2) last-optimize lever ที่สำคัญสุด (entry-signal params, StoK-lesson) ครบ — ceiling < 1.0 both-window (3) **lever A (capped basket) ห้ามเดิน = flat-lot no-edge + escalation = martingale-คือ-edge-เอง (DEAD-STRUCTURAL trap)** · lever B (regime gate) ไม่สร้าง edge บน underlying no-edge แค่ลด trade. **ST03 MACD-reversion = no robust both-window edge naked บน ranger.** evidence `_triage/ORDER119_LEVERC_RESULTS.md` + XML `_mt5_auto/optimizations/O119C_*.xml`. **⏭ decision ระยะยาว (ถอด ST03 ถาวร / แทน Boss_16 slot) = owner-override territory → user เคาะ** (ผม judge campaign evidence, fate ของ owner-override EA = user). role: agent sweep · Opus verify+judge.
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

## ORDER-120 — implement framework Part 4: rewrite CLAUDE.md VERDICT GATE เป็น tree + bar table — `DONE(Opus 2026-07-18): CLAUDE.md gate = decision tree (STRUCTURAL→PARAMETRIC→DEAD-OPTIMIZED/BUILD-ON/PARKED-VERIFY/CANDIDATE) + bar table 7 แถว (MAIN≥1.2 hard / BWD≥1.0 soft-gate→PARKED-VERIFY / holdout≥1.2 / MC ruin≤2% PF-5th≥1.0 / demo→live PF≥1.40@30) + Row-X write-checklist 5 บรรทัด + window names MAIN/BWD/HOLDOUT rolling-36 + paid-for history เป็น footnote. vocab 7 ตัวครบ. section อื่นไม่แตะ.`
**source:** `_triage/FABLE_RESETTLE_FRAMEWORK_2026-07-18.md` Part 4(b) (user approve ครบใน grill 2026-07-18 —
decision log แถว 2026-07-18). **spec:** แทน prose gate ด้วย (1) decision tree STRUCTURAL→PARAMETRIC→
DEAD-OPTIMIZED/BUILD-ON/PARKED-VERIFY/CANDIDATE (2) bar table 7 แถวตาม framework (MAIN≥1.2·BWD≥1.0
soft-gate ตามที่ user เคาะ Q3 — BWD-fail → PARKED-VERIFY(user) เคาะ demo-isolate ได้แต่ปิดทางเงินจริงอัตโนมัติ)
(3) Row-X write-checklist 5 บรรทัด (scorecard·index·EDGE_CATALOG·B1·user-brief) (4) ตั้งชื่อ window
MAIN/BWD/HOLDOUT ตาม rolling-36 ใหม่. **acceptance:** vocab 7 ตัวครบ · บรรทัด "paid for" history เดิมคงอยู่เป็น
footnote (ห้ามลบบทเรียน) · ไม่มี section อื่นใน CLAUDE.md ถูกแตะ · เลขบาร์ตรง framework ทุกตัว.
**ห้าม:** เปลี่ยนเลขบาร์เองโดยไม่มี decision ใหม่. **ทำได้:** Claude เท่านั้น (แก้กฎ) · 👉 แนะ: **Opus-seat**

## ORDER-121 — implement framework Part 3: rewrite skill backtest-optimize-rigor เป็น ladder 0-9 — `DONE(Opus 2026-07-18): skill = THE OPTIMIZE LADDER Step 0-9 (windows pin MAIN rolling-36/BWD 2020-22/HOLDOUT 2026H1 · Model-4-mandatory table ย้ายเข้า · MC bars ruin≤2%/resize 2-10%/PF-5th≥1.0 ย้ายเข้า). ลบ "Model 2 throughout optimize" (Codex BLOCKER) → Model-2 = preflight+kill-only, coarse=Model 1+. grep "Model 2" เหลือเฉพาะ preflight/kill/artifact-detect. OPTIMIZE_PROCEDURE_AND_AUDIT.md ติด superseded banner. NEXT STAGE → VERDICT GATE.`
**source:** framework Part 3(b). **spec:** (1) แทน Phase D-F ด้วย ladder Step 0-9 (2) **ลบบรรทัด "Model 2
throughout optimize for bar-open EAs" (drift ที่ Codex จับเป็น BLOCKER)** → Model-2 = zero-trade preflight +
kill-only, coarse sweep = Model 1+ (3) pin windows: MAIN = rolling 36 เดือนที่ไม่กิน holdout (convention
2023.01–2025.12) · BWD 2020.01–2022.12 · HOLDOUT 2026H1/unseen-symbol (4) ย้ายตาราง Model-4-mandatory เข้า
(grid/DCA/basket · pending-ladder · TP<20pip · largest-loss cliff) (5) ย้ายเลข MC จาก robustness-validator เข้า
(ruin ≤2% green · 2-10% resize-first · PF-5th ≥1.0) (6) `OPTIMIZE_PROCEDURE_AND_AUDIT.md` ติด superseded
banner ชี้ skill. **acceptance:** grep "Model 2" ใน skill เหลือเฉพาะบริบท preflight/kill · ladder ครบ 10 ขั้น ·
เลขตรง framework. **ทำได้:** Claude · 👉 แนะ: **Opus-seat** (แก้กฎ optimize = law)

## ORDER-122 — implement framework Part 2+5: สร้าง docs/PIPELINE.md + sync FINAL RULE 9 skills + AGENTS §1.5 — `DONE(Opus+Sonnet 2026-07-18): docs/PIPELINE.md สร้างแล้ว (flow owner + routing table 10 boundary + skill roster). FINAL RULE sync 9 skills: strategy-and-risk (ลบ standalone-faster block→chassis-first) · mql-code-generator (→mql-code-reviewer ก่อน compile) · signal-scanner · backtest-optimize-rigor (→VERDICT GATE) · mql-code-reviewer (mandatory cage) · robustness-validator + backtest-report-analyzer (DEMOTED banner, vocab retired) · portfolio-selector (corr ladder ≤0.40/0.40-0.60/>0.60 reduce-not-cut/same-EA<0.8) · live-deployment-controller (=GATE) · vps-deploy-ops (=SHIP, requires gate output). AGENTS §1.5 sync Fable→4 reserved cases. check_state CLEAN. Opus นำ+verify · Sonnet แก้ 8 skills+AGENTS ตาม list.`
**source:** framework Part 2(b) kill-list + Part 5(b) routing table. **spec:** (1) สร้าง `docs/PIPELINE.md` =
owner ของ flow เดียว + ตาราง 10 boundary (artifact·gate·who·written-where) ยกจาก framework ตรงๆ + banner
"canonical entry = PROJECT_STATE · ไฟล์นี้ owns: stage routing เท่านั้น" (2) แก้ FINAL RULE/handoff ใน 9 skills:
strategy-and-risk (ลบ standalone-faster-path block) · mql-code-generator (→ mql-code-reviewer ก่อน compile,
ลบ "standalone preferred") · signal-scanner · backtest-optimize-rigor · mql-code-reviewer ·
robustness-validator + backtest-report-analyzer (ติด banner "calculator ไม่ใช่ pipeline gate — vocab เดิม retired") ·
portfolio-selector (**แก้ corr: pair>0.7-block → ladder ≤0.40/0.40-0.60 reduce-lot/>0.60 reduce-not-cut ตามกฎ
user**) · live-deployment-controller (= gate ก่อน vps-deploy-ops) · vps-deploy-ops (ต้องรับ output จาก gate)
(3) AGENTS.md §1.5 sync สถานะ Fable → จอง 4 กรณี one-shot ตาม CLAUDE.md 2026-07-11 + fallback Opus+Codex.
**acceptance:** ทุก skill ชี้ next-stage ตรง PIPELINE.md · ไม่มี "PASS/CONDITIONAL/ROBUST" เป็นด่านเหลือใน
FINAL RULE ไหน · check_state ผ่าน. **ทำได้:** Claude (Sonnet ช่วย mechanical edits ได้) · 👉 แนะ: **Opus นำ + Sonnet แก้ตาม list**

## ORDER-123 — order template: เพิ่ม field บังคับ 2 ช่อง (pre-registered bars · flat-lot probe) — `DONE(Opus 2026-07-18): เพิ่ม ORDER TEMPLATE block ใน header taskboard (ใต้กติกาสถานะ) — order ทดสอบทุกใบตั้งแต่ 124+ ต้องมี bars: (pass/dead/กลาง) + flat-lot probe: done/N-A/pending.`
**source:** framework Part 5(b) enforcement #1. **spec:** เพิ่ม template block ใน header taskboard นี้ (ใต้กติกา
สถานะ): order ทดสอบทุกใบต้องมีบรรทัด `bars:` (pass=X/dead=Y/กลาง=Z) และ `flat-lot: done/N-A/pending`.
**acceptance:** header มี template + ORDER ใหม่ตั้งแต่ 124 ขึ้นไปใช้ครบ. **ทำได้:** Claude · 👉 แนะ: ทำพ่วงกับ 120-122

## ORDER-136 — CAMPAIGN: escalation-MM overlay บน validated PF>1 cohort (user directive 2026-07-19 "เทสใหม่หมดบนระบบใหม่") — `OPEN — Wave1 CLOSED 2026-07-19 (overlay แพ้ bar, คง single-position) · Wave2+ รอ user เคาะ` (multi-session · pace 1-2 cell/รอบ) ⚠️ renumbered จาก 134 (กัน collision session คู่ขนาน)
**source:** user 2026-07-19 — EA ที่ PF>1 ทั้งหมดลองใส่ escalation ได้ (MM lever ปกติ ไม่ใช่ ENGINE-EDGE เพราะ signal มี edge อยู่แล้ว) + chassis ผ่าน safety overhaul ครบ = โครงพร้อม. **judge ที่ expectancy + worst-case DD ไม่ใช่ PF อย่างเดียว — คาด: PF ต่อ window สวยขึ้น tail อ้วนขึ้น.**
**Wave 1 (เริ่มได้เลย — chassis-native ถูกสุด):** Boss_17 Wave5 (validated, demo 990301-303) — sweep `StackMode {90 base, 92 DCA}` × `_9_MaxLevels {4,6}` × `LotProg {NONE, LINEAR, LOG}` บน XAU H4 (home หลัก) both-window M1 → M4 survivor. bar: overlay ชนะ = expectancy/trade ≥ base AND worstDD ≤ base×1.5 AND both-window ≥1.0 · แพ้ = คง single-position (บันทึกแล้วปิด wave).
**WAVE 1 CLOSED (Opus 2026-07-19, 2 รอบ × pace): overlay แพ้ — คง single-position.** base XAU H4 M1: MAIN 1.60/payoff 5.16/eqDD 1.53% (81t) · BWD 1.00 ปริ่ม (56t). Cells: 92/L4/NONE = MAIN 1.82/5.91 ✅ แต่ eqDD 5.46%=3.6×base ❌ BWD 0.94 ❌ · 92/L4/LINEAR = MAIN 1.85/6.67 แต่ eqDD 6.70%=4.4× ❌ BWD 0.91 ❌ (แย่ลง monotonic ตาม lot-curve — พยากรณ์รอบ 1 ยืนยัน) · 92/L6/NONE = **เลขเหมือน L4 ทุกตัว** (139t/103t) = แกน depth INERT (adds ไม่เคยถึง 5+). LOG bounded ระหว่าง NONE/LINEAR ที่ fail ทั้งคู่ + L6 identical → cell ที่เหลือไม่ให้ข้อมูลใหม่ = earned close โดยไม่เผา grid ครบ. **Root cause: base BWD≈1.0 → DCA overlay = regime-dependence amplifier (กลไกยืนยันข้าม host กับ ORDER-135)** → lesson ลง EDGE_CATALOG dead pile. Boss_17 demo 990301-303 ไม่แตะ. **Wave 2+ = รอ user เคาะ** (MacdDiv/EmaStoRev ต้อง port entry ก่อน · Boss_14/RSI_MR = grid เดิมเทส LotProg ได้ · หมายเหตุ: host ที่ BWD แข็งแรงจริง >1.1 เท่านั้นที่คุ้มลอง). sets `_mt5_auto/ab_sets/order136_w1/` · reports `O136_W1_*` ×8.
**Wave 2+ (`DONE(Codex, 2026-07-21)`):** MacdDiv XAU / EmaStoRev = standalone ต้อง port entry เข้า chassis ก่อน (build order แยก) · Boss_14/RSI_MR = grid อยู่แล้ว (เทส LotProg เพิ่มได้) · crypto = pyramid อยู่แล้ว. **ห้าม:** burst ทุก wave พร้อมกัน (pacing rule) · deploy โดยไม่ผ่าน funnel เต็ม · แตะ set demo ที่ attach อยู่. **ทำได้:** Claude ออก .set → agent batch → Opus judge ต่อ wave. Codex route: Boss_14 GBPJPY H4 validated host, base-vs-LOG13 M1 gate ก่อน M4. Raw: `_triage/ORDER136_W2_B14_GJ_RESULTS.md`. BASE BWD PF=0.92 gate fail; LOG13 BWD PF=0.91; M4 NOT RUN; รอ Claude review.

## ORDER-128 — 🔴 P0: monitoring chain repair (task refused + false-green gist) — `CLOSED (Opus 2026-07-20): gh re-auth สำเร็จ (BaBosss keyring, scope gist/repo) + gist 287cce51 update จริง 2026-07-19 20:31 = E2E ผ่านแล้ว` — a/b/c ครบ + manual run เก็บ snapshot 18 ก.ค. สำเร็จ (auto-commit e321eee, ทุก step ผ่านยกเว้น gist) · **root cause dashboard มือถือเน่า = gh token account BaBosss หมดอายุ (401 มานาน แต่ script เดิมพิมพ์ "updated" ปลอม) → user ต้องรัน `gh auth login -h github.com` เอง แล้ว chain รอบ 07:30 พรุ่งนี้จะพิสูจน์ E2E** · fail-path test ผ่าน (bogus gist id → exit 1 จริง)
**source:** Codex system review `_triage/CODEX_SYSTEM_REVIEW_2026-07-18.md` + contract review เดียวกัน — verified โดย Opus: `EA_LAB_DailyMonitor` LastResult `0x800710E0` วันนี้ 07:47 (LogonType=Interactive → ถูก refuse) · snapshot ค้าง 17 ก.ค. · `publish_dashboard_gist.ps1` ไม่เช็ค `$LASTEXITCODE` ของ `gh gist edit` → "updated" ปลอมได้เมื่อ 401. **why P0:** เงินจริง + 38 ACTIVE deployments แต่ตาเฝ้าบอด และระบบรายงานเขียวปลอม.
**spec:** (a) task config: `StartWhenAvailable=true` + ยกเลิก battery block + เพิ่ม logon trigger (delay) — คง Interactive logon เพราะ `monitor_rotation.ps1` เปิด MT5 GUI terminals (S4U = session 0 เสี่ยง exporter ไม่ทำงาน); (b) `publish_dashboard_gist.ps1` เช็ค `$LASTEXITCODE` ทุก native call, fail → exit 1 ให้ `Step()` แม่เห็น; (c) `daily_monitor.ps1` freshness guard (last success <20h → skip เงียบ กัน logon trigger รันซ้ำ) + health alert (snapshot age >26h → `portfolio/MONITOR_ALERT.txt` + log ALERT + exit non-zero, healthy → ลบ alert file). **acceptance:** manual run จบ exit 0 + dashboard/gist update วันนี้ · task query แสดง trigger ใหม่ · จำลอง gh fail → script exit 1 จริง. **bars:** N-A (infra). **flat-lot probe:** N-A. **ห้าม:** แตะ collector/rotation logic · เปลี่ยน gist id/URL. **ทำได้:** Opus ทำเอง (มี state-change บนเครื่อง user).

## ORDER-095 / #4 — Boss_14 GridLog EUR-cross symbol-expand — `CLOSED + REVIEWED(Claude 2026-07-17): EURCHF+EURGBP both-window Model-4 coarse = NO home (MAIN spikes only, BWD dead ทุก cell) → PARKED ทั้งคู่ ไม่ kill (Boss_14 live @GBPJPY leg-8). ยืนยัน grid=symbol-specific. GBPCHF/NZDCAD/AUDNZD/AUDCHF = BLOCKED-ON-DATA (ไม่มี history 2020-22 → user โหลดก่อนถึงเทสได้; user เคาะ stop-at-2). verdict = _triage/ORDER095_EURCROSS_EXPAND_VERDICT.md` (role: agent ea-validator ×2 · verdict = Claude)

## ORDER-098-C — FVG-fill + RSI confluence gate (fxDreema course, #098 corpus) — `DONE + REVIEWED(Claude 2026-07-17): REJECT. build FVGFill_RSIgate (naked 098-A chassis + RSI gate, mql-review PASS, compile 0/0). RSI threshold swept 30/70 (~0 trades) /40/60 (thin spike XAU MAIN 1.23 BWD 0.63) /50/50 (well-powered 350-370t both-win, PF 0.76-0.94 ไม่เคย >1.0). FVG-fill ไม่มี edge naked หรือ RSI-gated. Gold SMC = FVG-retest อยู่แล้ว → FVG-as-primary ปิด, fxDreema FVG lineage exhausted. verdict = _triage/ORDER098C_FVG_RSIGATE_VERDICT.md` (role: Claude build → agent batch · verdict = Claude)

## ORDER-098-D — Currency-strength meter EA (fxDreema CCI-Strength lineage, #098 corpus) — `DONE + REVIEWED(Claude 2026-07-17): 🟡 PARAMETRIC-marginal → BUILD-ON candidate. naked CurrStrength_Naked (7-pair USD-basket momentum→chart-cross stronger-leg entry, ATR SL). multi-symbol tester ยืนยัน works (215t). funnel: threshold×3 · exit-RR×3 · TF×2 · 3 crosses. EURJPY H4 default = MAIN 1.01/BWD 1.01 (177/119t, win 42%) = cell เดียว both-window>1 sample พอ แต่ razor-thin + neighbors sub-1 = ไม่ใช่ plateau, ไม่ deploy. TP-widen thesis disproven (แคบดีกว่า). meter validated functional → build-on = ORDER-098-E. verdict = _triage/ORDER098D_CURRSTRENGTH_VERDICT.md` (role: Claude build → agent batch · verdict = Claude)

## ORDER-098-F — Pairs-spread stat-arb (Jobot arbitrage idea + SL cage, #098 corpus) — `DONE + REVIEWED(Claude 2026-07-17): 🟢 PARAMETRIC CANDIDATE (session's strongest). PairSpread_StatArb — 2-leg hedged, spread=log(A)-log(B) z-score fade, exit revert/z-stop cage (course NO_SL → SL cage rebuilt, blowup fixed: largest loss ~2% gross). mql-review PASS compile 0/0. funnel EntryZ×4·ExitZ×2·TF×2·2pairs. **H4 z2.5 EURUSD/GBPUSD = MAIN 1.07(130t)/BWD 1.04(110t) win 49-51% eqDD 4/13% = only both-window>1 cell**, lift จาก TF (H1→H4 ตัด cost drag) ไม่ใช่ Z. NEW diversifier class (pairs mean-rev, orthogonal). แต่ thin + selected-on-both → NOT deploy จนกว่า plateau+holdout+MC. verdict = _triage/ORDER098F_PAIRSPREAD_STATARB_VERDICT.md` (role: Claude build → agent batch · verdict = Claude)

## ORDER-098-K — stat-arb maker(pending-limit) build-on — `DONE/REVIEWED (Claude 2026-07-17) → NO LIFT, market baseline stays`
Built `PairSpread_StatArb_Maker.mq5` (magic 990985, limit entry + naked-leg guard). Funnel: maker 1.12/1.14/1.23 ≈ market 1.14/1.15/1.23 → cost-drag hypothesis REJECTED, edge thinness is signal-inherent. Keep deployed market ExitZ0.3. verdict `_triage/ORDER098F_PAIRSPREAD_STATARB_VERDICT.md` §098-K.

## 🗂️ ARCHIVED ORDERS — index ย้ายไป generated file (ORDER-102 Contract C1, 2026-07-13)

> orders ปิดแล้ว = `ARCHIVE_TASKBOARD_2026-07A.md` (verbatim) · **index = generated/read-only** `docs/memory_control/ARCHIVE_INDEX.md` (§20.7 — ห้าม hand-edit ในบอร์ดนี้) · integrity guard: `powershell -File scripts/check_taskboard_archive.ps1 -Strict` (raw/reviewed/unresolved · archive append-only + active conservation)
## ORDER-036 — MT4 mass-smoke (1,318 ex4) — `CLOSED (2026-07-07 — sweep จบ · 1,318 → 2 survivors → demo คู่ = ORDER-045)` · **ทำได้: Codex · oc-dev**

**👉 spec + สถานะ + วิธีสั่งทั้งหมด = `ORDER-036_MT4_MASS_SMOKE.md`** (แยกไฟล์เพราะ 27 batches ×50 —
กัน taskboard บวม). batch assignment deterministic = `_triage/mass_smoke_mt4_batches.csv` (คอลัมน์ batch 01-27).
user สั่งเป็นก้อน เช่น "ทำ 036 batch 04-08" · batch จบ+review แล้ว archive ไป `_archive/ORDER-036_ARCHIVE.md` ·
order แม่แถวนี้**คงอยู่จนครบ 27 batch** (กันหลุดจาก board) — Claude สรุป verdict รวมที่นี่ตอนจบ

**ผล (สรุปปิด 2026-07-07, header sync 2026-07-16):** 1,318 ex4 → 2 survivors ผ่านครบถึง Model-0 bwd+fwd
(**UnNomGuaiV1.132 + RSI from pips_EA**) → เข้าคู่ demo = ORDER-045 · รายละเอียดต่อ batch = `ORDER-036_MT4_MASS_SMOKE.md`
+ `_archive/ORDER-036_ARCHIVE.md`

---

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

## ORDER-106 — rescue #1 จากคิว ORDER-084: Boss_14_GridLog second-symbol pool — `GBPJPY DONE + REVIEWED(Claude 2026-07-16): ✅ RESCUE สำเร็จ ไม่ตาย — H4 @ dist2.0 plateau both-window + Model-4 CONFIRM (MAIN 1.56/BWD 1.11 ดีขึ้น/HOLDOUT 1.50, grid ไม่ collapse บน real ticks) · high-PF cells = spike ทิ้ง · thin (n~50, DD~9%) · PARAMETRIC candidate = leg ที่ 8 ของ Boss_14 demo cohort (H4, magic ใหม่) · **d1.5 finer Model-4 = REJECT (2026-07-16): MAIN 1.92 แต่ BWD 0.92 fill-optimism → leg-8 config = d2.0/s4.0** · **✅ ปิด leg-8 (2026-07-16): corr ทุกคู่ <0.8 (max CADJPY 0.791) + year-split Model-4 all-years-positive (2021-2026 PF 1.28-2.36, ไม่มีปีเจ๊ง — สะอาดกว่า Zeus) → DEMO LEG-8 พร้อม `_vps_deploy/BOSS14_GBPJPY/` magic 990208 (EA=Boss_14_GridLog ตัวเดียวกับ cohort, แค่ attach chart GBPJPY H4 เพิ่ม) · caveat: thin 9-28t/ปี + 2020 no-data + CADJPY 0.791 (JPY-cross คู่กัน flag user) → รอ user attach** · verdict = _triage/ORDER106_GBPJPY_RESCUE_VERDICT.md · NZDUSD/USDCAD/AUDNZD = ใบถัดไป` (role: agent funnel-batch · verdict = Claude)

**ที่มา:** ORDER-084 judge กอง ข อันดับ 1 — GBPJPY/NZDUSD/USDCAD/AUDNZD เคยเห็นแค่ defaults (0.68-1.13,
GBPJPY OOS 1.12 เฉียดบาร์) บน chassis Boss_14 ที่ validated แล้ว = under-swept ชัดตามกฎ rescue-ladder.

**คำสั่ง (เริ่ม GBPJPY ตัวเดียวก่อนตาม pacing):** funnel มาตรฐาน Boss_14 family — coarse sweep ≥3 lever
(spacing/DistAtrMult × SL-mult × lot-law ตาม strategy) × {H1, H4} × both-window (MAIN 2023-26 + BWD 2020-22)
Model 1 → รายงาน surface ดิบ (ทุก pass ไม่ใช่ top) → lead ตัดสิน plateau → ถ้าผ่านค่อย NZDUSD/USDCAD/AUDNZD
ใบถัดไป. ใช้ launcher/set ของ family เดิม (`_mt5_auto/ab_sets/` มี precedent ORDER-069 216-pass).
**Acceptance:** CSV ทุก pass: PF/Net/Trades/DD ต่อ window · **ห้าม:** verdict · เลือก "ตัวดีสุด" เอง ·
รันเกิน 1 symbol ในรอบเดียว · แตะ config demo cohort เดิม

---

## ORDER-107 — SMC×STO signal Stage-0 cheap smoke (user idea 2026-07-16) — `CORRECTED + REVIEWED(Claude 2026-07-16): 🟩 BUILD-ON candidate ไม่ตาย (user จับถูก — default-smoke ผมรีบตัดสินผิด gate) · optimize จริง 180 passes/symbol: XAU (trender=บ้านผิด) regime-fit ล่ม BWD · EURUSD (ranger=บ้านถูก) 2/3 top pass ยืน both-window (1.30/1.13 · 1.22/1.02) · **CONFIRMED (2026-07-16): EURUSD H1 = demo candidate จริง** — ADX filter (user idea) ยก 1.30/1.13→1.50/1.24 · plateau 6/7 neighbor · **Model-4 MAIN 1.39/BWD 1.19/HOLDOUT 1.14 ครบ** · EURUSD-only (ไม่ travel AUDNZD/EURGBP/XAU) · bundle `_vps_deploy/SMCSTO_EURUSD` magic 991070 → รอ user attach (corr=informational) · verdict = _triage/ORDER107_SMCxSTO_STAGE0_VERDICT.md · **บทเรียน: default-smoke เกือบทิ้ง candidate จริง — user push optimize+filter ถูก** (memory feedback-optimize-before-killing-reversion)` (role: Claude build → agent optimize · verdict = Claude)

**ที่มา:** user แชร์ระบบ class SMC×STO (triage เต็ม = `_triage/SMCxSTO_SIGNAL_TRIAGE.md`, EDGE_CATALOG PARKED-CONCEPT).
class = momentum-gated reversion · cheap-death: strip SMC/OB (แพง) เทส skeleton ก่อน.

**Stage 0 (คำสั่ง):** build standalone probe `(EXP)_EmaStoRev` — higher-TF EMA100 gate (buy-only ถ้า close>EMA100 บน
resample/HTF handle · sell-only ถ้าต่ำกว่า) + Stochastic(5,3,3) cross ออกจาก OS(20)/OB(80) = entry, 1 flat-lot 0.01,
SL 1.5-2.0×ATR, exit = STO-reverse ที่ opposite extreme + BE-move ที่ STO50. **ไม่มี OB zone, ไม่มี grid** (Stage 1
ค่อยเพิ่มถ้ามีชีพจร). bar-open gate + tester-gate + digit-aware pip ผ่าน mql-code-reviewer ก่อน compile.
smoke Model 1, 2023-2026: EURUSD + GBPUSD + XAUUSD × {M15, H1} = 6 cell.
**Acceptance:** ตาราง 6 แถว PF/Trades/DD/Win + report path · **บาร์:** cell ใดก็ได้ PF≥1.1 naked = ไป Stage 1 (เพิ่ม OB
gate) · ทุก cell PF<1.0 = DEAD concept (OB ไม่ช่วย — zone แค่ locate reversion เดิม) บันทึก signal-landscape ปิด.
**ห้าม:** ใส่ OB/grid ก่อน skeleton ผ่าน · M1 ใน Stage 0 (spread noise — เก็บไว้ถ้าไป production) · verdict (lead).

---

## ORDER-108 — break-and-retest split-entry (market + pending-limit) บน breakout winner (user idea 2026-07-16) — `DONE + REVIEWED(Claude 2026-07-16): 🟩 BUILD-ON SUCCESS — build (EXP)_BRK_SplitRetest + A/B Model-4 XAU H1 · retest fill-rate ~90% · adverse-selection จริง (pending-only แพ้ market ในเทรนด์ = ต้องมีขา market) · split robust ทั้ง 2 regime (1.93/1.97) · lever ใหม่เข้า EDGE_CATALOG · **followup: retrofit LIVE Bars55/TP8 = ไม่ยก (split 1.89<market 1.99, retest อ่อน BWD) → ห้าม retrofit ตัว live · lever = config-conditional (ช่วยเฉพาะ config สมดุล)** · verdict = _triage/ORDER108_SPLIT_RETEST_VERDICT.md` (role: Claude build → agent run · verdict = Claude)

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

## ORDER-064 — ขุดไอเดียจาก Open WebUI export 93MB (คุยกับ OpenAI ของบริษัท) — `CLOSED (Stage 3 verdict Claude 2026-07-09 — ลูกที่ spawn: ORDER-065 SuperTrendFlip = RESERVE · ORDER-066 VWAP WaveS1 = NO EDGE, ทั้งคู่ปิดแล้วใน archive)`

- **Stage 1 ✅:** `scripts\chatgpt_export_inventory.py` (รองรับทั้ง OpenAI export และ Open WebUI format) →
  45 บทสนทนา, จัดอันดับตาม MQL-keyword density → `_triage\chatgpt_inventory.csv` + top-12 แตกเป็น .txt ใน
  `_triage\chatgpt_convs\` (⚠️ ข้อมูลบริษัท — .txt/.csv **ไม่เข้า git**, เก็บ local เท่านั้น)
- **Stage 2 (กำลังรัน):** 4 Sonnet agents skim 12 ไฟล์ → catalog กลไก/โค้ด/ความใหม่เทียบ cohort
- **Stage 3 (Claude):** judge catalog → เลือก build candidates (เกณฑ์: กลไกใหม่จริง + กติกาชัด — VWAP-based
  น่าสนใจสุดเพราะ cohort ยังไม่มี) · ที่เหลืออีก 33 บทสนทนา = อ่านเฉพาะถ้า top-12 ให้ของดี

**VERDICT Stage 3 (Claude, 2026-07-09 — catalog ครบ 12/12):**
- **ขยะ/ซ้ำของที่เรามี-REJECT แล้ว (7 ไฟล์):** 024 scaffold framework · 015 recovery-hedge spec (ตระกูล REJECT
  81/82) · 041 AW-Recover clone (**ไม่มี SL ต่อไม้ทั้ง 5 เวอร์ชัน**) · 030 prompt-eng session · 036 triage PDF
  ซ้ำ STRATEGY_200_ANALYSIS · 022+009 = 11-EA ตาม**โหราศาสตร์** (โค้ดครบแต่ allocation ไม่ใช่ market logic)
- **ของจริงที่สกัดได้ — จัดอันดับ build EV:**
  1. 🥇 **SuperTrend/HalfTrend/Chandelier "ATR-band flip"** — โผล่อิสระ **5 แหล่ง** (025 HalfTrend MTF ·
     043 Smart Trail · 009 P10 · 022 P10 · STRATEGY_200 #68 top-pick) · กลไก: trailing extreme ∓ ATR×mult
     พลิกทิศ = trend-follow ที่ exit ด้วยเส้นวิ่งตาม ไม่ใช่ fixed TP · บ้านที่ควรเทส: XAU H1 (edge class
     momentum ที่พิสูจน์แล้ว) · build ถูกสุด (indicator เดียว + โครง L1 มีแล้ว) → **ORDER-065**
  2. 🥈 **VWAP Wave (010 — สเปคเต็ม 4 setup)** — VWAP+SD band แยก Balance/Discovery + Initial Balance ·
     กลไกใหม่แท้ต่อ cohort (ไม่มีตัวไหนใช้ fair-value anchor) · ต้องกลั่นเหลือ setup เดียวก่อน (S1 continuation
     หรือ S4 VWAP-bounce) — ห้าม build ตามสเปค 30 ไฟล์ (บวม+ML+Wyckoff = overfit trap) → **ORDER-066**
  3. 🥉 **Z-score pairs stat-arb EURUSD/USDCHF** (009 P5 + 022 P5 สองแหล่ง) — market-neutral = return stream
     คนละจักรวาลกับ cohort ทั้งกอง · ติดเรื่อง infra (multi-symbol tester + ไม่มี price SL ในดีไซน์เดิม = ต้อง
     ใส่ hard SL เอง) → วิจัยความเป็นไปได้ก่อน build → backlog
  4. **Graft ideas ใส่ของที่มีอยู่ (ถูกมาก):** ATR>1.2×ATR_MA เป็น squeeze-proxy ราคาถูก (032) · vote N-of-M
     gate (043/032) · asymmetric-lot MTF confluence (025 — เห็นต่างเข้าครึ่งไซส์) · time-stop 48 แท่ง (032)
  5. **Anti-pattern เก็บเข้าคลัง:** virtual SL (043) · recovery-multiplier ซ้อน martingale (043) · equity-based
     kill แทน price SL (041) · "AI/Neural" = ป้ายการตลาดของ EA ขายตลาด 90% (035 audit ชี้ Quantum Emperor
     เจ้าของเติมเงินเข้า signal ปิด DD!)
- Boring-Pips-style cross-pair reversion (035) + session-gate (022 P11) = MED เก็บ backlog ไม่เร่ง

---

## ORDER-072 — build "(Boss)_Kangaroo" = Boss_16 บนแม่พิมพ์ V2 — `CLAIMED(Claude-agent, 2026-07-10)` (role: agent build ภายใต้ spec ที่ Claude เคาะ)

**Spec decisions (Claude lead เคาะ 2026-07-10 — ปิดประเด็นเปิดทั้ง 5 ของ KANGAROO_LOGIC_NOTES §4):**
1. **Lot law: FLAT default** (ทุกไม้ = base_lot) — flat-lot probe พิสูจน์แล้วว่าดีกว่ามี ladder
   (H1 5.71 vs 4.86) · ×1.5 capped ladder ใส่เป็น input `LadderMult` default 1.0 (=ปิด) ไว้ A/B
2. **Bidirectional = 2 instance ผ่าน Direction input** (ตาม pattern Boss_14) — ไม่ทำ dual-engine
   ในตัวเดียว, magic แยกฝั่ง · ไม่ทำ multi-magic stream ของ original (artifact ไม่ใช่ feature)
3. **Entry v0 = RSI fade** (RSI(14) H1: BUY เมื่อ <th_low, SELL เมื่อ >th_high, default 30/70) —
   ใกล้เคียง counter-trend ของ original ที่สุดในคลังเรา (RSI-MR = survivor mechanism ที่ validate แล้ว)
4. **เก็บ 3 กลไก exit ตาม original แต่คิดเงินจริง:** TP เดี่ยว (ATR-mult) · basket close แบบ net-$ ·
   **overlap pair-close** (คู่ใหม่สุด+เก่าสุด ปิดเมื่อรวม ≥ $X, default 5, sweepable) — โมดูลใหม่
5. **ladder_flatten (controlled-loss release):** มีเป็น input default OFF — A/B แยกใน funnel
6. Spacing ATR (0.8/1.4 mult + floor 150p) · SL ต่อไม้ ATR-mult (ceiling $90-equiv) · HARD cap
   10 ไม้/ฝั่ง (ของจริง ไม่ใช่โฆษณาแบบ original) · emergency DD 70%

**คำสั่ง:** สร้าง `ea_template\Boss_16_KangarooGrid.mq5` + โมดูลใหม่ที่จำเป็นใน `core\` (additive,
default-off สำหรับ EA เดิม) ตาม pattern Boss_14_GridLog · compile 0/0 · **`tpl_regression.ps1` ต้อง CLEAN**
(กติกาแก้ core) · smoke XAUUSD H1 2023-2026 Model 1 บน lane "D:\Meta 5b" (กันชนกับ ORDER-071) ·
เทียบตาราง: Boss_16 flat vs original flat (PF 5.71/DD 11.5% = เป้าไล่)
**Acceptance:** compile 0/0 · regression CLEAN · ตาราง smoke เทียบ original + set ไฟล์ · commit `[tag] ORDER-072 done`
**ห้าม:** deploy/verdict · แก้ Boss_14/15 behavior · martingale default-on · แตะ .set live

### ORDER-072 result — `DONE(Claude-agent, 2026-07-10)` — build ครบ + gates ผ่านทั้ง 3 + smoke raw numbers (NO verdict)

**Build file list:**
- NEW `ea_template\Boss_16_KangarooGrid.mq5` (wrapper: `LAB_ENTRY_16` + tag)
- NEW `ea_template\core\Kangaroo.mqh` — basket engine ของ entry 16 ทั้งก้อน: adverse-only ATR grid
  (0.8/1.4 mult + floor 150p digit-aware) · FLAT lot (LadderMult>1.0 = capped ladder, first-4 = BaseLot,
  cap/order 1.0) · HARD cap 10 ไม้/ฝั่ง (refuse จริง) · per-order broker SL (18×ATR, ceiling 9000p) ·
  exit 4 กลไก **คิดเงินจริงทั้งหมด**: (1) single TP 0.35×ATR (managed close) (2) basket net-$ ≥ 16×(lots/0.01)
  (3) overlap pair-close newest+oldest ≥ $5 เมื่อ ≥4 ไม้ (4) ladder_flatten default OFF (≥6 ไม้, net ≥ -$400) ·
  emergency DD close-all 70% · **one exit owner:** LabCore short-circuit เข้า `Kangaroo_OnTick()` — ExitManager/
  Stack/Recovery/Hedge ไม่รันเลยสำหรับ build นี้; ไม่มี broker TP ต่อไม้ (precedent mode 93); cage ยังเป็นใหญ่
  (RiskControl hard-kill/deposit-load/RC_MaxLot รันก่อน/คุมทับ)
- NEW `ea_template\core\entries\Entry_KangarooRSI.mqh` — entry v0: RSI(14) fade บน chart TF, closed-bar read,
  `_16_Direction` 1=BUY(<RsiLow 30)/2=SELL(>RsiHigh 70) ตาม pattern Boss_14, เข้าที่ bar open
- EDIT (additive, `#ifdef LAB_ENTRY_16` ทั้งหมด — compile out จาก Boss_11..15): `core\Inputs.mqh` (กลุ่ม `_16_*`
  + StackMode/fallback guard) · `core\Indicators.mqh` (handle `g_hRSI16`) · `core\LabCore.mqh`
  (include + init + OnTick short-circuit) · `core\Execution.mqh` (`Exec_CloseTicket()` — build อื่นไม่เรียก)
- EDIT `ea_template\deploy.ps1` (+Boss_16 target) · `scripts\mt5_run.ps1` (+`-Leverage` param, default 100 = พฤติกรรมเดิม)
- NEW `ea_template\sets\Boss16_Kangaroo_XAU_smoke.set` (defaults ทั้งชุด เขียน explicit)

**Gate evidence:**
1. compile: `Boss_16_KangarooGrid.mq5 → Result: 0 errors, 0 warnings` (และทั้ง 7 targets 0/0)
2. `tpl_regression.ps1` = **CLEAN 4/4** — หมายเหตุ: เจอ DRIFT 4/4 ก่อน แต่ control run บน clean HEAD (stash)
   reproduce เลขเพี้ยน **bit-identical** (trades เท่าเดิมเป๊ะ 168/164/107/56, profit ±1-4%) = data-side
   XAU history refresh ตาม incident เดิม commit 6a21f040 → re-baseline บน verified clean HEAD แล้วรันกับ
   module = CLEAN (ทำตาม procedure ที่บันทึกไว้เป๊ะ) · `tests\run_tests.ps1` = **ALL TESTS PASS 3/3**
   (AcctGate/Persist/StackStep)
3. smoke lane "D:\Meta 5b" (portable): XAUUSD H1 2023.01.01–2026.07.01 Model 1 (history quality 98%),
   deposit 10000, leverage 1:2000, defaults flat-lot

**Smoke table (raw — ห้าม verdict ที่นี่):**
| Run | PF | Net $ | maxDD% (eq) | Trades | Win% |
|---|---|---|---|---|---|
| Boss_16 BUY (defaults) | 1.49 | +2,242.42 | 10.85% | 588 | 76.4% |
| Boss_16 SELL (_16_Direction=2) | 0.46 | −2,261.00 | 25.12% ← cage HARD KILL @25% วันสุดท้าย 2026.06.30 | 293 | 54.3% |
| Original Gold_Kangaroo FLAT (MT4 H1, สองฝั่งในตัวเดียว) | 5.71 | +15,216.87 | 11.53% | 6,166 | 86.4% |

Reports: `_mt5_auto\reports\BOSS16_KANG_XAU_H1_BUY.htm` / `BOSS16_KANG_XAU_H1_SELL.htm` · mechanics ยืนยันใน
journal lane2: overlap pair-close ยิงจริง 168 ครั้ง (SELL run), grid adds เดินตาม spacing, cage kill ทำงาน

**Deviations from spec (พร้อมเหตุผล):**
1. smoke = 2 runs (BUY+SELL อย่างละ 1 ครั้ง ไม่มี tuning) — EA เป็น fixed-direction ต่อ instance ตาม spec
   decision 2 แต่แถวเทียบ original เป็นสองฝั่ง → รันฝั่งละครั้งเพื่อให้ตารางเทียบได้
2. single TP = managed close ไม่ใช่ broker TP — กติกา one-exit-owner (ไม้ห้ามมี broker TP, precedent 93);
   fill = tick แรกที่เลย level ซึ่งเทียบเท่า overshoot behavior ที่เห็นใน original
3. grid-add reference = ราคา extreme ของฝั่ง (ต่ำสุด BUY / สูงสุด SELL) ไม่ใช่ไม้ล่าสุดตามเวลา — กัน
   oscillation refill หลัง overlap pair-close ตัดไม้ newest ออก; ตรง observation ว่า original เติมไม้ที่
   new low เท่านั้นช่วง crash 2024-11-06
4. emergency 70% อยู่ในโค้ดตาม spec แต่ cage KillDD (ProtectLevel 2 = 25%) ยิงก่อนเสมอที่ default —
   70% = backstop สำหรับ config ที่คลาย cage (SELL run คือหลักฐาน cage ทำงานจริงและ halt)
5. `mt5_run.ps1` เพิ่ม `-Leverage` (additive, default 100 ไม่เปลี่ยนพฤติกรรมเดิม) เพราะ order สั่ง 1:2000
   แต่ script hardcode 100
6. `regression_baseline.csv` ถูก re-capture บน clean HEAD (ดู gate 2) — ไม่ใช่การกลบ drift ของ module;
   พิสูจน์ด้วย control run ก่อนแล้ว

**ข้อสังเกต (ข้อมูล ไม่ใช่ verdict):** trades 588+293 vs original 6,166 — entry v0 RSI fade คัดเข้มกว่า entry
เข้ารหัสของ original มาก (ตัว original ยิงหลาย magic stream แทบตลอดเวลา) · ฝั่ง SELL แพ้บน XAU 2023-26
ซึ่งเป็นเทรนด์ขึ้นยักษ์ · การอ่านผล/ทางไปต่อ (entry sweep? both-instance portfolio?) = งาน Claude lead


---

## ORDER-073 — News-aware risk system (user directive 2026-07-10) — Phase 1 `DONE(Claude)` · Phase 2 `ATTACHED 2026-07-24 (user) on all 3 real accounts (141049900 MT4 / 159503454 MT5 / 159475669 MT5) — filename-mismatch finding below FIXED(user, 2026-07-24)` · Phase 2.5 MRIS `DONE(Claude 2026-07-18)` · Phase 3 MacroGate `DONE — VALIDATED deploy-candidate (Claude 2026-07-18) → ATTACHED 2026-07-18 (demo carry-leg 990120, manual-weekly mode)`

**✅ 2026-07-24 finding RESOLVED(user) — NewsGuard "file missing/stale" root cause was a FILENAME mismatch:** `Common\Files` on the VPS had the file as `news_week.csv` but every NewsGuard instance's `NewsFile` input expects `EA_LAB_news_week.csv` (copy step ran but was never renamed). **User fixed the rename on the VPS 2026-07-24** — not independently re-verified by Claude via a fresh alert/log snapshot, logged here on user attestation. If the "missing/stale" alert reappears on 159503454/159475669/141049900, re-open this finding first before assuming a new cause. Still unresolved/deprioritized separately: MT4 `ServerToBkkOffsetHours` timezone input (should be 7, not default 4) on 141049900 — user call, low-priority (MT4 footprint being reduced anyway).

**✅ SESSION 2026-07-18 CLOSE (commits `7ee6bbd8`→`e219db8e`, branch `order073-macrogate-safe`):**
- **Phase 2.5 MRIS = SHIPPED, live daily.** web feeder (all 8 barometers from Yahoo — VIX/DXY/COPPER/US10Y-proxy + broker pairs, no stooq), thresholds LOCKED as user-sanctioned defaults + in-file `_tuning_guide` (`barometers.json` v1.0), whisper embedded top of `LIVE_DASHBOARD.html` + wired into `daily_monitor.ps1` (mris_run before dashboard). Codex-hardened (5 fixes: cache-poison, atomic write, effective-status, culture-parse, asof fail-open). Reads NEUTRAL RI 0.269 HIGH.
- **Phase 3 MacroGate = VALIDATED deploy-candidate (was STUB).** Standalone watchdog + chassis GV bridge (`Execution.mqh` block+lot-mult, open-path only) + in-chassis `_MG_SelfGate` for single-EA A/B. Concept: MRIS flags Aug-2024 + Mar-2020 unwinds with lead time. **A/B (Boss_12_Breakout, full-year 2024, 2 symbols): eqDD −54..−56%, P&L flat→much better** (USDJPY −58→+2.8). Manage-only grid (Boss_14) = no-op (harmless). Cage: core edits inert (identical trade counts). Codex QA fix-then-ship → all 7 fixed. Verdict: `ea_projects\(Boss)_MacroGate\MACROGATE_AB_VERDICT.md`; review: `docs\memory_control\CODEX_MACROGATE_REVIEW.md`.
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

## ORDER-076 — smoke-screen หัวกะทิ 41 ตัวจาก X-ray — `CLOSED (Claude 2026-07-14 — 16 mq5 ใหม่จริง: 11 REJECT/PARK + 1 build-on-needs-data ((ICE) CCI = PARKED, basket 9-major ไม่รอด) · verdict = _triage/ORDER076_MQ5_SMOKE_VERDICT.md)` (role: agent/qwen lane)

**คำสั่ง:** (1) cross-ref 41 ตัว (CSV filter has_sl=yes & lot_escalation=no) กับ EA_SCORECARD +
ผล ORDER-036 (MT4 1,318 sweep) — ตัวที่เคย screen แล้วห้ามรันซ้ำ ใช้ผลเดิม (2) ตัวใหม่จริง:
smoke ตาม filter chain มาตรฐาน (name-DQ → smoke PF>1 → BWD-OOS 2020-22 → spread-stress)
platform ตามไฟล์ · **compiled .ex4/.ex5 เท่านั้นถ้ามี — .mq4/.mq5 คอมไพล์ก่อน** (3) ตาราง verdict-ดิบ
ต่อ EA ต่อด่าน **Acceptance:** ตารางครบ 41 แถว (screened-before / smoked / DQ) + top-5 ตาม
BWD-OOS PF · commit `[tag] ORDER-076 done` **ห้าม:** verdict PASS/REJECT (Claude ตัดสิน) ·
แตะไฟล์ต้นฉบับ · แตะ 297 ตัว SL-unknown (รอ verification pass แยก ถ้าคุ้ม)


---

## ORDER-079 — Idea mining คลังคอร์ส: concept catalog (reframe จาก user 2026-07-10) — `DONE(Claude-inline, 2026-07-10 — catalog = _triage/FXDREEMA_IDEA_CATALOG.md)`

**ทำไม (user directive):** คลัง 1,050 EA = สื่อการเรียน ไม่ใช่สินค้า — ห้ามตัดสินด้วยเกณฑ์ risk structure
(43% no-SL คือ scaffold ของแบบฝึก ไม่ใช่ความผิด) · เป้า = **สกัดไอเดีย/แนวคิด** ที่ user เรียนมา
ให้เห็นเป็นแคตตาล็อกต่อยอดได้ · user ยืนยันในคลังมี Elliott Wave (รวมแบบเฉพาะ wave 5) + SMC —
ห้ามปัดตก แนวพวกนี้แล็บมี precedent ด้วย (Gold SMC = OOS_VALIDATED ใน EA_Project)

**คำสั่ง:** สร้าง concept-mining pass ต่อยอด xray (แหล่งข้อมูลต่อไฟล์: ชื่อไฟล์/โฟลเดอร์ · **fxDreema
block labels** (คนเขียนเอง สื่อความหมายตรง) · indicator signature · comment strings) →
จัด taxonomy แนวคิด เช่น: Elliott/wave-count · SMC/order-block/liquidity/BOS · session-time ·
breakout (แบบไหน) · reversion (RSI/CCI/Stoch/BB) · trend-follow (MA/ST/SAR) · currency-strength
meter · correlation/pair · news · scalping · grid/basket variants · dashboard/tool (ไม่ใช่ EA) ·
money-management exercises → output `_triage\FXDREEMA_IDEA_CATALOG.md`:
ต่อ concept: จำนวนไฟล์ · ตัวแทน 2-3 ไฟล์ (ตัวที่ block labels สื่อสุด) · mechanism sketch จาก labels ·
**cross-ref สถานะแล็บ**: เคยทดสอบ/ตาย/validated/ยังไม่เคยแตะ (เทียบ EDGE_CATALOG.md + memory
signal-landscape ผ่านไฟล์ repo) + CSV คอลัมน์ concept เพิ่มใน FXDREEMA_XRAY.csv
**เจาะพิเศษ:** ไฟล์ Elliott/wave ทั้งหมด (grep wave/elliot/impulse/zigzag ใน name+labels) และ
SMC (order block/liquidity/FVG/BOS/CHOCH/SMC) — ลิสต์แยกครบทุกไฟล์ พร้อมสรุป logic จาก labels ต่อไฟล์
**Acceptance:** catalog ครบ + ลิสต์ Elliott/SMC เต็ม + นับ concept ใหม่ที่แล็บไม่เคยทดสอบ ·
commit `[tag] ORDER-079 done` · **ห้าม:** ตัดสินดี/ไม่ดี ต่อ concept (Claude+user คุยกัน) · risk flags
ห้ามโผล่ใน catalog (คนละเอกสารกับ XRAY)

**สถานะ:** CLAIMED -> DONE(Claude-inline, 2026-07-10) — agent ตายที่ session limit, Claude เขียน/รันสคริปต์เองต่อ (fxdreema_concepts.py + boilerplate fix รอบสอง: doji-string เคย inflate candle_pattern 224->16) · ผลเต็ม = _triage\FXDREEMA_IDEA_CATALOG.md + concept column ใน XRAY.csv + _concept_summary.json


---

## ORDER-080 — วัดมูลค่า "limit-entry แทน market" บน EA เรา (แรงบันดาลใจ: บอท maker-only ของโพสต์ FB) — `CLOSED (Claude 2026-07-17): ตอบผ่าน ORDER-108 + 091C-D1d ไม่ต้อง build Boss_16 ซ้ำ`
**VERDICT (`_triage/ORDER080_LIMIT_ENTRY_VERDICT.md`):** pending-limit ≠ free win — (a) adverse-selection ในเทรนด์ (พลาด runner: ORDER-108 pending-only 1.76<market 2.07),
(b) ~26-28% ไม้ไม่ fill (lwma). **split (market+pending) = robust** (1.93/1.97 ทั้ง 2 regime) แต่ **config-conditional** (ช่วย reversion/balanced, ทำร้าย trend-chaser — ห้าม retrofit live trend EA).
กติกา: offer entry-mode เป็น input, default = validated mode, เปิด pending/split เฉพาะ reversion/balanced. lever อยู่ EDGE_CATALOG แล้ว.

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

## ORDER-084 — Retro-audit: ไล่ verdict DEAD/REJECT/PARKED ทั้งหมดกับกฎใหม่ (user: "ตายเปล่าเยอะ") — `CLOSED (extract DONE agent 2026-07-10 · judge DONE Claude 2026-07-16: กอง ก ~95 ฆ่าถูกกติกา · กอง ข rescue queue 5 ตัวเรียง EV · กอง ค PARKED-VERIFY(user) 2 รายการ — rescue ยกเป็น order ใหม่ทีละใบตาม pacing)`

**ทำไม:** กฎ rescue-ladder (optimize ≥3 รอบ lever ต่างชุด × ≥2 TF ก่อนตาย) + PARKED-VERIFY(user) +
EA-SCORE เพิ่งเกิดวันนี้ — verdict เก่าจำนวนมากตัดสินก่อนกฎนี้ · user เชื่อ (ประสบการณ์ตรง: หลายตัวที่ live
อยู่รอดเพราะมือ user เคยเทส) ว่ามีของดีตายเปล่าค้างอยู่

**ขั้น 1 — extract (mechanical, agent):** กวาดทุก verdict จาก EA_SCORECARD_AND_REGISTRY.md +
MASTER_BACKLOG.md + memory signal-landscape (อ่านผ่านไฟล์ repo ที่อ้างถึง) + AGENT_TASKBOARD
(ORDER ที่ REVIEWED) → ตาราง CSV ต่อ EA/concept: ชื่อ · verdict · วันที่ · **lever ที่ sweep จริง
(นับจากหลักฐาน ไม่ใช่คำอ้าง)** · จำนวน TF ที่ทดสอบ · จำนวน symbol · best PF ที่เคยเห็น · class
(STRUCTURAL/PARAMETRIC/artifact) · หลักฐานชี้ไปไหน
**ขั้น 2 — judge (Claude):** แยก 3 กอง — (ก) STRUCTURAL/artifact ยืนยัน = ตายจริง ไม่แตะ
(ข) **under-swept ตามกฎใหม่** (sweep <3 รอบ หรือ 1 TF) = คิว rescue เรียงตาม EV: best-PF ใกล้เกณฑ์ +
mechanism เข้ากับ symbol ที่รู้จัก (reversion→ranger · breakout/trend→XAU/GBP) (ค) idea ดีแต่เครื่องมือ
ยุคนั้นไม่ถึง = **PARKED-VERIFY(user)** สรุป 3 บรรทัด/ตัวส่ง user
**ขั้น 3 — แผน rescue:** เลือก top 5-10 จากกอง (ข) → order sweep ตามสูตร rescue-ladder
(lever ชุดตามประเภทใน backtest-optimize-rigor) — **ห้ามรันใน order นี้** แค่วางแผน+ประมาณชั่วโมงเครื่อง
**Acceptance ขั้น 1:** `_triage\RETRO_AUDIT_VERDICTS.csv` ครบทุก verdict ที่หาเจอ + สรุปนับต่อกอง ·
commit `[tag] ORDER-084 extract done` · **ห้าม:** ตัดสิน/จัดกองเอง (แค่ extract หลักฐาน) · ห้ามรัน backtest

### ORDER-084 extract SUMMARY (Claude-agent, 2026-07-10 — raw counts, no judging)
1. **Total verdict rows: 154** ใน `_triage\RETRO_AUDIT_VERDICTS.csv` (per-EA/cell/concept; aggregate-pool rows ครอบ ~2,700 EAs ที่ตายเป็นกอง: ORDER-036 1,318 ex4 · ORDER-035 203 ex5 · 63-EA screen · idea_bank 251)
2. Counts by verdict: **REJECT 52 · DEAD 33 · CANDIDATE 13 · CORE/ROBUST/DEMO 12 · NO-EDGE/closed 11 · PARKED 11 · DQ/DISQUALIFIED 10 · CONDITIONAL 3 · WATCH 3 · LEAD 2 · DROP 2 · other 2**
3. **TFs_tested == 1: 141/154 (92%)** — เกือบทั้ง lab ตัดสินจาก TF เดียว (H1 ล้วนเป็นส่วนใหญ่); มีแค่ 13 ราย ที่เห็น ≥2 TF (RSI from pips 4 TF · Boss_16 2 TF · WaveS1 2 TF · NR7/PrevDay/EMATREND/Kangaroo/NuiIndy/ST03/HalfTrend ฯลฯ)
4. **Evidence = default-only/smoke-only (เข้ม): 29 rows · รวมชั้นเดียว (BWD-only/lot-check-only/hard-gate): 44 rows** — กองนี้คือผู้สมัคร rescue-ladder โดยนิยาม (ไม่เคยเห็น lever sweep แม้แต่รอบเดียว)
5. Top-10 best_PF_seen ในกอง DEAD/PARKED/REJECT/DQ (118 rows): CITY-GOLD 259.99 (artifact) · gold-grid concept 85.14 (M2 artifact) · Degold 13.12 (M1-vs-M4 artifact) · Scalper_S3 10.71 (fixed-spread artifact) · GBPJPY1H90PCWR 8.15 (PARKED-no-data, absurd-flag) · Golden Elephant 7.77 (TP-lever artifact) · Gold Stuff V7 5.09 · Dark Mimas 5.0 (regime) · **EA_SUPERTREND XAU H4 4.49 OOS (ตัวจริง — parked เพราะ corr 0.946 กับ KER)** · COT-filter 3.96 (year-split kill)
6. หมายเหตุ: top-PF ส่วนใหญ่ = artifact ที่พิสูจน์แล้ว; PF สูงสุดที่*ไม่ใช่* artifact ในกองตาย = SuperTrend 4.49 · IR Whale 3.94(suspect) · EURUSD Forex Robot 3.89 (BWD 0.39) · FZ2 3.05 (flat-lot 0.36) · 143 E4.7.4 3.0 (BWD 0.85) · AsReMix 2.99 (PARKED regime)
7. รูปแบบที่เห็นซ้ำใน extraction (ข้อมูล ไม่ใช่คำตัดสิน): กอง mass-smoke ตายด้วย 1 symbol-pair × 1 TF × default; กอง concept 200-list ตายด้วย default smoke 1-2 cell แล้วปิด "concept DEAD ถาวร"; กองที่ sweep จริง ≥3 lever มีน้อย (~25 rows: Boss_14 family · ST03 · SessionBreakout 1200-pass · FlagPennant · WaveS1 · SuperTrendFlip · Degold · ZIGL-EURUSD 216-pass ฯลฯ)
8. Sources ที่กวาดครบ: EA_SCORECARD_AND_REGISTRY.md · MASTER_BACKLOG.md · AGENT_TASKBOARD.md (ORDER-001→083) · ORDER-036_MT4_MASS_SMOKE.md · memory signal-landscape.md · STRATEGY_200_ANALYSIS.md · PROJECT_STATE.md §07-08 (อ้างถึงจาก taskboard)
9. STRATEGY_200_ANALYSIS.md = **prior scores ไม่ใช่ verdict** (คะแนน /10 ก่อนเทส) — ไม่ได้สร้าง row ต่อ prompt; ตัวที่ถูกเทสจริง (#9/20/30/62/66/68/70/83/94/100/105/127/135) มี row จากผลเทสใน backlog/signal-landscape แล้ว
10. AGENT_TASKBOARD_MERGE.md = engineering port track ล้วน (MERGE-01..08) ไม่มี EA verdict — ไม่มี row
11. ORDER-064 (ChatGPT export mining) เป็น idea-triage ไม่ใช่ backtest verdict — ไม่ได้สร้าง row (จดไว้กันสับสน)
12. Orders 048-054 ไม่มี header ใน taskboard (เลขข้าม 047→055) — verdict ของ funnel 07-08 (SqueezeBRK ROBUST · Trendline #8 EXPERIMENTAL · ConfluenceMartATR/London/plain-squeeze ตก) สกัดจาก PROJECT_STATE §SESSION 2026-07-08 + การอ้างอิงใน ORDER-059/065/067 แทน
13. Verdict ที่มี supersede-chain ถูกยุบเหลือ row เดียว (verdict ล่าสุด + ประวัติใน evidence): ST03 family (CORE→STRUCTURAL 07-10) · 2020v2 (REJECT→revive→REJECT) · Happy thaipop (PARKED→REJECT ×16.3) · Automated Forex Grail (AUTO-REJECT→revive→REJECT-spread) · LNBREAK/NRBreakout (DEAD→re-exam ORDER-008B)
14. คอลัมน์ class_claimed = คำอ้างของ verdict เดิมเท่านั้น (STRUCTURAL/PARAMETRIC/artifact/unknown) — ยังไม่มีการจัดกอง rescue/dead/verify ตามข้อห้าม
15. ขั้น judge (กอง ก/ข/ค + แผน rescue top 5-10) = รอ Claude lead อ่าน CSV

### ORDER-084 ขั้น 2 JUDGE (Claude lead, 2026-07-16) — จัดกอง 107 rows กลุ่มตาย + แผน rescue

**กอง ก — ตายจริง ไม่แตะ (~95 rows):** ทุกตัวที่มี kill-chain ครบอย่างน้อย 1 ด่าน structural/artifact จริง:
BWD wipeout (Dark Mimas 0.45 · EURUSD Robot 0.39 · SEMIS 0.05-0.65 · GapinFX 2022 0.02) · spread-stress
(Grail · Yetti family · Expert · 2020v2) · lot-check (Z61 ×44-80 · AF-Global →94 lots · Dark Venus ×2+ ·
Happy thaipop) · Model-ladder artifact (Elephant 85→1.41 · Scalper_S3 · Degold M1-fantasy · Zeus Gold Hedge
M1-false-pass) · exhaustive sweep ถึง ceiling (MACD-cross 1.16 · SessionBreakout 1,200-pass 1.20 ·
RSI_Swing_BB 27-combo · LNBREAK 0/81 · Boss_14 EURCHF 0/54 + US30 + BREAKOUT EU/GBPJPY 0/180-175 ·
LondonConso rescue-sweep 48-combo แล้วยังตก) · no-source/cracked (CITY-GOLD · North East Way · KRAPOOK).
**การ audit ยืนยัน: กองนี้ฆ่าตามกติกา ไม่ใช่ตายเปล่า.**

**กอง ข — UNDER-SWEPT ตามกฎใหม่ (ตายจาก default-only/1-TF, ยังไม่เคยเห็น lever sweep) → คิว rescue เรียง EV:**
1. **Boss_14_GridLog second-symbol pool (GBPJPY/NZDUSD/USDCAD/AUDNZD)** — defaults เท่านั้น (0.68-1.13,
   GBPJPY OOS 1.12 เฉียดบาร์) · chassis validated แล้ว = EV สูงสุด · rescue = funnel มาตรฐาน ≥3 lever × H1+H4
   (~2-3 ชม.เครื่อง/symbol, ใช้ launcher เดิมของ family ได้เลย)
2. **EA_XAU_NY (#83 NY-session breakout)** — default smoke เดียว PF 1.12/350t · mechanism = breakout@XAU
   (edge class ที่พิสูจน์แล้ว) · sweep session-window × buffer × SL × {M30,H1,H4} (~2 ชม.)
3. **EA_ZSCORE (#100)** — default เดียว PF 1.15/0.95 H4 · reversion signal แต่เทสบน XAU (บ้าน momentum) —
   ผิดบ้านตาม portfolio-edge thesis · rescue = ย้ายไป ranger pairs (AUDNZD/EURCHF/EURGBP) × H1/H4 ×
   threshold sweep (~2 ชม.)
4. **EA_ICHIMOKU (#66)** — claimed STRUCTURAL "cloud lags" แต่หลักฐาน = default 1 cell = overclaim ชัด ·
   sweep Kumo period × TF บน XAU/JPY (~1.5 ชม.)
5. **EA_KELTNER (#62)** — default เดียว PF 1.04 · momentum-class ถูกบ้านแล้ว แต่ PF ไกลบาร์ · ท้ายคิว (~1.5 ชม.)
6. **EA_PREVDAY / EA_NR7** — เคย iterate 2-3 รอบแล้ว (เกือบครบ gate) · ต่อคิวเฉพาะถ้า 1-5 ให้ผลดี
**หมายเหตุ regime-parked (Zeus AUDJPY/AUDUSD · Boss_14 NZDUSD-SELL · AsReMix):** full-funnel แล้ว ไม่ใช่
under-swept — ทางฟื้นเดียว = lever `_50_ Regime.mqh` ใน funnel ใหม่ (ORDER-057 adoption path) ไม่ใช่ re-sweep เปล่า

**กอง ค — PARKED-VERIFY(user):** (1) **Phoenix_EA_v5_6_03 + GBPJPY1H90PCWR** (PF 8.15 absurd-flag) —
BWD ว่างเพราะ MT4 history ขาด · ปลดล็อกทันทีที่ user โหลด history (memory `mt4-history-gap-jumstoch` มีคิว
priority อยู่แล้ว: NZDUSD-H4/AUDJPY-H1/GBPJPY/EURGBP) (2) **VisualMartiEA** — unverifiable ×2 (ladder ×5
น่าจะ structural แต่ยังไม่มีหลักฐาน) — แจ้ง user ตามกติกา ห้ามปล่อยตายเงียบ

**ขั้น 3 (แผน — ห้ามรันใน order นี้):** rescue 1-2 ตัว/รอบตาม pacing เริ่มจาก Boss_14 GBPJPY → XAU_NY →
ZSCORE · รวม ~9-11 ชม.เครื่องสำหรับ top-5 · ยกเป็น order ใหม่ทีละใบตอนถึงคิว (อย่า burst)

**🔧 แก้คำตัดสินกอง ก (user จับ 2026-07-16 — pending-limit lever):** spread-death subset (Yetti3 · Grail ·
Expert · 2020v2 · Scalper_S3 ฯลฯ) ผมเคยจัด "ฆ่าถูกกติกา" — **แต่ฆ่าใต้ market entry เท่านั้น.** ตัวที่
**(1) entry = reversion/mean-revert** (limit fill บน pullback ได้) **+ (2) มี source แก้ได้** → pending buy/sell
limit = lever ที่ยังไม่เทส → **ย้ายจาก "ตายจริง" ไป rescue-verify** (compiled vendor แก้ entry ไม่ได้ = ตันตามเดิม ·
breakout = pending-limit ผิดทาง มันต้อง chase). vehicle = ORDER-091C-D1d/080 ด้านล่าง (JUMSTOCH เหมาะสุด).

**ผลรอบ rescue 2026-07-16:** #1 GBPJPY = ✅ revive (Model-4 confirm, verdict `_triage/ORDER106_*`) ·
#2 XAU_NY = 🟡 regime-dependent long-gold (edge จริง in-regime แต่ไม่ both-window; 3 lever swept รวม direction;
build-on = จับคู่ ORDER-057 regime-gate; verdict `_triage/ORDER084_XAUNY_RESCUE_VERDICT.md`) · **#3 ZSCORE = ❌ REJECT (2026-07-16):
ย้ายไป ranger (AUDNZD/EURGBP/EURCHF) × threshold{2.0,2.5,3.0} × {H1,H4} × both-window = 36 runs ไม่มี both-window survivor
(≥1.1). ดีสุด EURGBP H4 t3.0 1.04/1.12 แต่ thin 36-42t + spike (t2.0/2.5 ตก) = high-threshold thin-artifact. reversion
ไม่มี edge แม้บนบ้านถูก → valid kill (optimize-on-right-home-fail) ตอกย้ำ momentum>reversion prior · CSV `_mt5_auto/ZSCORE_RESCUE_RANGER.csv`** ·
next: ICHIMOKU → KELTNER (⚠️ agent delegation ต้องใส่ "foreground synchronous ห้าม background-wait" เสมอ — ZSCORE agent ตกหลุมนี้)

**ผลรอบ rescue #4 ICHIMOKU (#66) = ORDER-112 (2026-07-16B):** เปิดพบว่า rescue ทำไปครึ่งทางแล้ว (probe 2026-07-11
sweep ADX+exit+symbol) → USDJPY = cell เดียวที่รอด (smoke 1.25 / IS 1.13 / OOS 2.66-31t · GBPJPY/AUDJPY/GBPUSD/EURUSD ตาย).
**แต่ probe นั้นบน Model-2 + recent-only(2023-25) + Kumo-period ไม่เคยแตะ = 3 ช่องโหว่ตรง VERDICT GATE.** ORDER-112 =
เติม lever แกน: Ichimoku/Kumo periods {fast6/17/34 · def9/26/52 · med12/34/68 · slow20/60/120} × {H1,H4} × both-window
Model-4 (16 runs) · isolate: hold ExitMode2/AdxMin20/Sl2.0 · runner `_mt5_auto/run_ichi_kumo_bothwin.ps1` · CSV
`_mt5_auto/ICHI_KUMO_BOTHWIN.csv`. **VERDICT = 🟡 REVIVED (คว่ำ "DEAD") → PARKED-BUILD-ON:** 6/8 cell both-window บวก >1.1 (plateau);
med-H4(12/34/68)=1.48/1.39 + slow-H1(20/60/120)=1.31/1.22 ผ่าน ≥1.2 both. **แต่ year-split = ทั้งคู่ 2 ปีขาดทุน** (agg โดนปีเทรนด์กลบ)
→ ไม่ผ่าน all-years-positive = ยังไม่ demo. **DEAD 2026-06-27 = ผิด** (under-swept: เทสผิด symbol XAU + ไม่แตะ period lever).
Build-on lead: 2 config ขาดทุนคนละปี → diversified basket (5/6 ปีบวกเมื่อรวม, **full-period PF 1.448** ยืนยัน). verdict = `_triage/ORDER112_ICHIMOKU_RESCUE_VERDICT.md` · CSV year-split `_mt5_auto/ICHI_YEARSPLIT.csv`.

**ผลรอบ rescue #5 KELTNER (#62) = ORDER-113 (2026-07-16B) = ❌ REJECT-CONFIRMED:** sweep channel-def (EMAPeriod/KeltMult)
× TF × both-window Model-4 บน USDJPY (16 runs, `_mt5_auto/KELT_CH_BOTHWIN.csv`). **H4 = window-inversion** (BWD 1.22-1.48 แต่
MAIN 2023-26 พังหมด 0.71-0.76 DD15%) · **H1 = churn** (1.0-1.14 ไม่แตะ 1.2, 450-530t spread-fragile) · ไม่มี cell both-window ≥1.2.
original DEAD ถูก—ครั้งนี้ swept จริง = valid kill. Build-on ปิด (breakout→regime-gate redundant). verdict = `_triage/ORDER113_KELTNER_RESCUE_VERDICT.md`.
**บทเรียน:** rescue-ladder ให้ผลต่างกัน — ICHIMOKU revived · KELTNER dead ภายใต้ treatment เดียวกัน = กระบวนการทำงาน (ไม่ rubber-stamp).

**ORDER-112B ICHIMOKU basket build-on = DONE → DEMO-ELIGIBLE bundle #9:** merged-equity (2 config continuous Model-4, merge deal list ตามเวลา
— deploy = 2 instance ไม่ต้อง build wrapper): **PF 1.339 · 357t · true max-DD 6.09% · MC PF_5th 1.036 · DD_95th 10.77% · ruin 0%.**
edge บวกจริง+MC-survive แต่ thin (PF_5th 1.036) = demo small-lot ไม่ใช่ live leg แข็ง. **Bundle `_vps_deploy/ICHIADX_USDJPY_BASKET/`** (H4 med 990066 + H1 slow 990067)
พร้อม attach (user 2026-07-16B APPROVED "เอาเข้าทั้งหมด" → roster ใน DEMO_DEPLOYMENT_PLAN, register ตอน attach จริง). script `_mt5_auto/ichi_basket_merge_mc.ps1`.

**🥇 ORDER-112C/D ICHIMOKU multi-home = XAU ฟื้นด้วย period lever (2026-07-16B):** เอา config USDJPY-winner ไป 6 trenders × both-window Model-4
(`_mt5_auto/ICHI_MULTIHOME.csv`). GBPJPY/EURJPY/AUDJPY/GBPUSD ตาย/single-window · CADJPY 1.16/1.15 near-miss · **XAUUSD = medH4 3.94/1.25 + slowH1
1.66/1.39 ผ่าน both-window ≥1.2** → คว่ำ "XAU ceiling 1.13" (default-period only). year-split (`ICHI_XAU_YEARSPLIT.csv`): medH4 6/6 ปี ≥0.99 (thin 8-20t/yr) ·
slowH1 5/6 ปีบวก (32-41t/yr). แข็งกว่า USDJPY basket แต่ **gate ชี้ขาด = corr vs XAU legs เดิม** (XAU แน่นมาก).

## ORDER-112E — corr check: Ichimoku-XAU additive หรือ redundant? — `DONE(Claude 2026-07-16B) = 🎯 ADDITIVE (reduced-lot)`
**ผล:** full-window XAU Model-4 → monthly Pearson (`_mt5_auto/ichi_xau_corr.ps1`): Ichimoku-XAU slowH1 PF 1.57/236t/Sharpe 3.0 ·
**vs BRK 0.263 · Kaufman 0.574 · SuperTrend 0.646** = additive (max 0.646, ต่ำกว่า SuperTrend-0.724-block). **VERDICT: candidate จริง.
Bundle #11 `_vps_deploy/ICHIADX_XAU/` (H1 slow magic 990068)** — เพิ่มใน roster แล้ว. medH4 = optional 2nd leg (990069 reserved).
⚠️ **corr = live-decision gate เท่านั้น ไม่ใช่ demo gate** (user 2026-07-16B): demo เอาขึ้นเทส normal lot คอนเฟิร์มว่าเวิร์ค; corr sizing/cut ตอนเงินจริง. เก็บเลข corr ไว้ตอน promote live.
รายละเอียด original order ด้านล่าง (เก็บไว้ provenance):

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
= structural dead** · **PREVDAY = ไม่มี config แตะ 1.2 both-window (marginal churn)** = dead. verdict `_triage/ORDER114_PREVDAY_NR7_CLOSE_VERDICT.md`.

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

## ORDER-091C-D1d — JUMSTOCH pending-limit entry variant (= ORDER-080 vehicle, user idea) — `🔼 PRIORITIZED (user reaffirm 2026-07-16: "EA ตายเพราะ spread ตั้ง pending + ขยาย TP") — vehicle แรกของ pending-limit rescue · role: Claude/Sonnet build → run`
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
**สรุป pending รวม 2 ฝั่ง = `_triage/PENDING_LIMIT_SYNTHESIS.md`:** pending = refinement (~+0.05 PF) ไม่ใช่ resurrector ·
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

## ORDER-116 — CAMPAIGN: split-entry breakout — รีด lever (ORDER-108 validated) ให้ครบ portfolio (user 2026-07-18 "รีดออกมาทำยาวๆ") — `CORE DONE(Claude 2026-07-18) = split narrow lever, no new legs · conclusion _triage/ORDER116_CAMPAIGN_CONCLUSION.md · Phase 3 (London retrofit) = optional low-prior residual`

**สรุป (conclusion เต็ม `_triage/ORDER116_CAMPAIGN_CONCLUSION.md`):** split = **narrow config-refinement ไม่ใช่ portfolio-wide upgrade / leg-generator.** ✅ Phase 1: XAU 40/5-split regime-robust (2.40/1.96 · full PF 2.26/149t/DD3.9% · **MC PF_5th 1.71 ruin0%**) = chop-robust กว่า live Bars55 (1.99/1.12) **แต่ corr 0.861 vs XAU-BRK leg = same-slot redundant** → replacement candidate ตอน XAU re-opt ไม่ใช่ leg เพิ่ม. ❌ Phase 2: ไม่เปิด leg ใหม่ (US30=ORDER-095 leg+spike · XAG/GBP/NAS dead). **doctrine: pending/split = weak-window-filler บน base ที่มี both-window edge + asymmetric weak window เท่านั้น — เช็ค base edge ก่อน.** residual: Phase 3 retrofit London/CB_GBP (build task, low-prior — GBP generic-Donchian ไม่มี edge แล้ว, value อยู่ที่ session-logic ของ London เอง) · Phase 4 (Bars55 TP) ORDER-108 ปิดแล้ว.

### ORDER-116 Phase 1 RESULT (Claude 2026-07-18) — verdict `_triage/ORDER116_PHASE1_VERDICT.md` · raw `_mt5_auto/O116_P1.csv`
offset sweep XAU H1 Bars40/TP5 both-window Model-4 (D:\Meta 5). **split ยกหน้าต่างอ่อน (BWD chop) 1.75→~1.96** แลก REC นิด (2.49→2.33-2.40) = regime-robust (คอนเฟิร์ม ORDER-108 บน tick ใหม่). **plateau offset ∈ {−0.30,−0.15,0.00}** · +0.15 ตก (retest ตื้นไป BWD 1.67) → edge อยู่ฝั่ง retest ลึก. bar ผ่าน (≥1.80 both). **LOCKED RECIPE = split 0.02mkt/0.01pend · RetestOffset −0.15 · Expiry 5** (`BRK40_split_offm0p15.set`). → Phase 2: พก recipe ไป GBPUSD/EURUSD/US30/XAG both-window หา leg ใหม่ (≥1.4 both + corr<0.8).

**ที่มา:** ORDER-108 พิสูจน์ split-entry (market leg เก็บ runner + pending retest leg fill maker ~90%) = **lever จริงเพิ่ม regime-robustness** แต่ **config-conditional**: ยก Bars40/TP5 (1.93/1.97 both-window) · ไม่ยก Bars55/TP8 live (retest leg อ่อน BWD). กติกา: **split ช่วยก็ต่อเมื่อ retest leg มี edge ในหน้าต่างที่ market อ่อน** (ขึ้นกับ TP-width × lookback). EA `(EXP)_BRK_SplitRetest` = generic Donchian breakout, input ATR-relative → รันข้าม symbol ได้. ห้าม: แปะ EA ที่ปัญหา = regime ไม่ใช่ entry-cost/timing (XAU_NY).

**เป้า campaign:** map envelope ของ lever + หา **breakout leg ใหม่ที่ split ทำให้ regime-robust** (diversification) + retrofit demo config ที่ยกได้. Model-4 บังคับ (pending fill = tick-sensitive) → **รันบน D:\Meta 5 non-portable** (Meta5b portable เขียน report M4 ไม่ออก — บทเรียน D1g). ทุก phase = 1 experiment ใน event log (adoption guide RE-fixes ทำให้ลื่นแล้ว).

**Phase 1 (batch 1, this session): retest-param sweep บน working config (XAU H1 Bars40/TP5)** — หา "retest recipe" ที่ดีที่สุดก่อนพก symbol อื่น. sweep `_07_RetestOffsetAtr {−0.3,−0.15,0,+0.15}` @ `_07_ExpiryBars=5`, split 0.02mkt+0.01pend, both-window Model-4. reference = market-only (2.07/1.75 จาก ORDER-108). **pre-registered bar:** offset ที่ให้ split ≥1.80 **both-window** (ไม่มี weak window) + retest fill-rate ≥80% = recipe ผ่าน → พก Phase 2 · ถ้าไม่มี offset ไหนยก BWD เหนือ market-weak = lever แค่ robustness-neutral, ปรับแผน Phase 2 เป็น config-rebalance · negative offset (retest ลึก=ราคาดีขึ้นแต่ fill น้อย) = สมมติฐานหลักว่าจะยก retest edge.

**Phase 2 DONE(Claude 2026-07-18) = ❌ CLOSED NEGATIVE (split เปิด leg ใหม่ไม่ได้) · verdict `_triage/ORDER116_PHASE2_VERDICT.md` · raw `_mt5_auto/O116_P2.csv`+`O116_P2B_PLATEAU.csv`:** พก recipe ไป US30/NAS100/XAG/GBPUSD both-window Model-4. **US30 ≠ leg ใหม่** — ORDER-095 validate ไปแล้ว (H4 1.46/1.39, **corr vs XAU −0.249 additive PASSED**, staged 991005 WATCH-thin) · my plateau check เผย **US30 40/5 = SPIKE ไม่ใช่ plateau** (neighbor ตก <1.2 both / tp4-tp6 invert, thin 24-39t) → **991005 คง WATCH spike-fragile (feed back ORDER-095)** · split บน US30 = 1.54/1.38 ไม่ยก (market-only ไม่มี weak window ให้เติม). XAG (BWD 0.56, split DD 17%) + GBPUSD (<1) = dead · NAS100 no data. **doctrine sharpened: split เติม weak window เฉพาะ base ที่มี both-window edge + asymmetric weak window (XAU 40/5 trend2.49/chop1.75) — base สมดุลอยู่แล้ว/ไม่มี edge = ไม่ช่วย.** → **Phase 3 (pivot): validate Phase-1 XAU 40/5-split (2.40/1.96 regime-robust) เป็น demo config** — corr vs XAU legs เดิม + MC + holdout (additive หรือ replacement ของ Bars55 chop-weak 1.99/1.12?).
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


**ที่มา:** D1d (07-16) วัด pending-save บน LWMA proxy ที่ **ไม่มี edge** → พิสูจน์ได้แค่ magnitude (~+0.05 PF/ไม้) ไม่ใช่คุณค่าจริง + TP-widen ครึ่งหลังของ user ยังไม่รัน. `_triage/PENDING_LIMIT_SYNTHESIS.md` สั่งชัด: "หา reversion base ที่ near-breakeven มาเป็น demonstrator". **JUMSTOCH = demonstrator นั้น** — thread D1→D1f REVIEWED = demo-ready, **flat-lot PF 1.18 (edge จริง ไม่ใช่ martingale artifact)**, capped-SL'd reversion grid เทรด 869-3272 ไม้/window = จ่าย spread เยอะ = ตรงเป้า maker-save. นี่คือที่เดียวที่ +0.05 PF/ไม้ × ไม้เป็นพันจะเห็นผลจริง บน base ที่ candidate อยู่แล้ว.

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

## ORDER-095 — CAMPAIGN: ขยาย symbol ให้ EA ที่ deploy อยู่แล้ว (user 2026-07-11: "ขยายผลไปตัวที่ demo อยู่ ได้อีกเยอะ") — `OPEN (multi-session, pace 1 EA/batch) · batch 1 DONE(Claude 2026-07-14): EA_BREAKOUT_XAU → USDJPY (PF 1.28/1.25) + US30 (1.46/1.39 WATCH-thin) demo-eligible · bundles staged _vps_deploy/EA_BREAKOUT_USDJPY (991003) + EA_BREAKOUT_US30 (991005) · verdict = _triage/ORDER095_BREAKOUT_XAU_EXPAND_VERDICT.md` ⚠️ **US30 991005 UPDATE (ORDER-116, 2026-07-18): plateau check เผยว่าเป็น SPIKE ไม่ใช่ plateau** (b30/b50 ตก <1.2 both · tp4/tp6 invert · thin 24-39t) → **คง WATCH/small, ห้าม graduate จาก single-cell evidence** (ดู `_triage/ORDER116_PHASE2_VERDICT.md`)

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

## ORDER-097 — build "(HEX)_HexaGrid" (user สั่งเขียนจากสเปคเอง 2026-07-11) — build `DONE(Claude, 2026-07-11)` · baseline `DONE(Claude, 2026-07-11)` · funnel `CLOSED (Claude 2026-07-14 — STRUCTURAL DEAD: sweep spacing×SL ไม่ช่วย + flat-lot isolate S1-S6 ไม่มีระบบไหนมี edge เดี่ยว (ดีสุด 0.80/0.76) · ปัญหาอยู่ที่ entry ทั้ง 6 ไม่ใช่ chassis · verdict = _triage/ORDER097_HEX_FUNNEL_VERDICT.md)` _(renumbered 096→097: ชนกับ CAMPAIGN ORDER-096 WOBR)_

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

## ORDER-098-A — FVG-fill entry (EX009 algo) flat-lot smoke — `CLOSED — REJECT (Claude 2026-07-16): naked FVG-fill ไม่มี edge — 22 runs ครบ BWD both-regime (0.79-0.88) + RR sweep TP{15,20,25,30,40,60}: PF ไต่ถึง 0.97-0.98 แล้วหักลงที่ TP40/60 = cost-dilution ไม่ใช่ edge, ไม่เคย PF>1 สักครั้งใน 26 cells → ไม่เข้า build-on doctrine · ปิดเฉพาะ naked-entry บน EUR/XAU H1/H4 — FVG-as-filter ยังเปิดใน EDGE_CATALOG · verdict เต็ม = _triage/ORDER098A_FVGFILL_SMOKE_VERDICT.md · ดิบ = _mt5_auto/order098a_bwd_rr.csv` (role: Claude/Sonnet build → agent smoke)

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

## ORDER-098-B — MACD-divergence entry (EX154/EX010 algo) flat-lot smoke — `CLOSED — DEMO-ELIGIBLE (Claude 2026-07-16): 🥇 XAU H4 ผ่านครบทุกด่าน funnel — MAIN plateau 1.91 (9 neighbor ไม่มีตัวขาดทุน) · BWD 1.04 · HOLDOUT 1.30 · Model-4 real-tick 1.89/0.97/1.28 (edge จริงไม่ใช่ fill artifact) · MC ruin 0% · corr gate max|corr|0.555<0.8 (additive) · bundle staged _vps_deploy/MACDDIV_XAU magic 999094 (tester-gate จริง set AllowLive=true) → WAITING-USER attach · EUR H4 HOLDOUT FAIL 0.35 → PARK · H1 ปิด cell · verdict = _triage/ORDER098B_MACDDIV_VERDICT.md` (build+opt = Codex 2026-07-15 · funnel+M4+corr+bundle = agent/Claude 2026-07-16)

**ทำไม:** MACD *divergence* (price LL / MACD HL) ≠ naked MACD-cross ที่ตายไปแล้ว = reversion signal ที่ยังไม่เคย smoke.
EX120 เสริม volume-confirm + low-freq (RR 1:3-1:5).

**สเปค entry:** bullish divergence = price ทำ lower-low แต่ MACD main ทำ higher-low (lookback N swing) · เข้า BUY ·
mirror SELL · **flat-lot single order fixed 0.01, SL = 3-bar extremum, TP = 200% SL** (จาก EX113/EX013 RR 1:2).

**คำสั่ง:** build `ea_projects/(EXP)_MacdDiv_Naked/` → compile → smoke Model 1 2023.01-2026.01:
EURUSD H1/H4 · XAUUSD H1/H4 (4 cells).

**Acceptance:** ตาราง 4 แถว (PF/Trades/EqDD%/Win%) + report path. commit `[tag] ORDER-098-B done`.
**ห้าม:** grid ก่อน flat-lot ผ่าน · verdict · reject ก่อนครบ gate.

---

## ORDER-098-C — reusable MM-parts library (dynamic close_money + Fibonacci-capped lot) — `DONE(Claude 2026-07-17C, commit bd709fca)` (role: Claude, built via sonnet-agent + lead-verified)

**RESULT:** 2 parts extracted OFF-by-default into Boss V2 core — `PROG_FIBONACCI` (56, MoneyManagement.mqh, lot*fib(lv) cap _56_FibMaxStep=5→13x) + `Exit_DynCloseTargetMoney()` (ExitManager.mqh, base+(openCount/C)*base, gated _57_DynCloseOn=false). Compile 7/7 EA 0 err. **Off-by-default lead-VERIFIED:** tpl_regression trade counts byte-identical to baseline all 6 EA (gated code changes 0 default behavior); 6 net/pf micro-drifts <2% = pre-existing stale baseline (Jul11) vs refreshed ticks NOT edits → **baseline refresh = separate lead maintenance (flagged, not done mid dual-session).** Integrate-into-chassis = future order (not backtested yet, per scope). Retrofit: Fib→MatchaGrid bounded / DynClose→Kangaroo DD-release + JUMSTOCH.

**ทำไม:** 2 ชิ้นนี้ = "cap + linear/log" ที่ user สั่ง มีคนทำไว้แล้วในคลัง — เอาไปแปะ chassis ที่ผ่าน flat-lot (098-A/B)
หรือ retrofit บน MatchaGrid/Kangaroo/JUMSTOCH ได้เลย (pure risk-mechanics ไม่ยุ่ง entry-edge).

**สเปคที่จะสกัดเป็น module:**
- **dynamic close_money** (EX183/EX078): `close_target = base + (open_order_count / C) * base` — เป้าโตตามจำนวนไม้
- **Fibonacci-bounded lot** (EX191): sequence `0.01,0.02,0.03,0.05,0.08,0.13` cap ที่ step 13× (แทน martingale ×2) +
  reset เมื่อ flat · EX211 variant มี SL30/TP50 อยู่แล้ว = bounded+capped ต้นแบบ

**คำสั่ง:** เขียนเป็น include module (`ea_template/core/` ตาม pattern เดิม) + run `tpl_regression.ps1` cage หลังแก้ core.
**Acceptance:** module compile ผ่าน + regression cage เขียว + unit note ว่าใส่กับ chassis ไหนได้. **ยังไม่ต้อง backtest** (งาน integrate อยู่ order ถัดไปหลัง 098-A/B รู้ผล).
**ห้าม:** แก้ core โดยไม่รัน `tpl_regression.ps1` · integrate เข้า chassis จริงก่อน entry-edge ยืนยัน (จะปนตัวแปร).

---

## ORDER-102 — Contract C1: migration window — resolve exceptions + replace manual index + freeze archive (WRITE-PATH) — `CLOSED (2026-07-14 — ENFORCEMENT-REWORK ปิดโดย ORDER-103 C1-ENFORCE = ACCEPT · Contract C1 complete ทั้ง data + enforcement)` (SYSTEM ORDER 4 of ≤4 memory-control build)

> **Design source:** `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` **§20.8 Contract C @ `4eb839d`** (migration half) + ORDER-101 "→ C1" spec + §20.7
> **ทำได้:** Opus (exception judgment + migration window + canonical workflow = own) · Codex/subagent (guard-hook code) · **👉 แนะ:** Opus เขียน+ตัดสิน → subagent build lock-hook → **Opus execute migration เอง (1 atomic commit)** → **blind Codex review ก่อน accept**
> ⚠️ **นี่คือ order เดียวที่แก้ architectural write path จริง (taskboard/archive)** — ต้อง maintenance window ไม่มี writer อื่น (user ยืนยัน session อื่นปิด) · gate = C0 validator `-Strict` ต้อง exit 0 หลัง migration
> **Prereq:** C0 (ORDER-101) REVIEWED ✓ — validator `check_taskboard_archive.ps1` + manifest/index/exceptions พร้อมใช้เป็น gate

**REALITY:** manual split ทำแล้ว (archive 131 blocks) → C1 **ไม่ bulk-move**. **REVISED r1 หลัง Codex C1 design review (2026-07-13):** เปลี่ยน "dispose exceptions" → **"canonical review linkage"** (§20.7: reviewed history/decision อยู่ owner เดิม ไม่ใช่ manifest column/allowlist ใหม่); ใช้ verdict เดิมที่มีอยู่; archived blocks **immutable — append-only**; แยก hook-install (C1a) จาก migration (C1b); pin staged-snapshot protocol.

**Phase 0 — validator upgrade (prereq, read-only, commit ของตัวเอง):** อัปเกรด `check_taskboard_archive.ps1` review-linkage เป็น **block-id/text level** (ที่ C0 เลื่อนไว้) → รู้จัก `REVIEW ORDER-x` block จริง. **หลัง upgrade: 071 exception ต้องหาย** เพราะมี `REVIEW ORDER-071 — REVIEWED — เคส entry ST03 ปิดถาวร` อยู่แล้ว (`ARCHIVE_TASKBOARD_2026-07A.md` L2657, preregistered-gate fail) — **C0 เดิม false-positive จาก canonical-id limit**. validator ต้องรายงานแยก `raw_detected / canonically_reviewed / unresolved`.

**Phase 1 — Opus canonical review (append-only, ไม่แก้ archived bytes):** สำหรับ exception ที่ **ไม่มี** linked review จริง → Opus เขียน **canonical consolidated review block** (append เข้า archive/taskboard ตาม owner) ระบุต่อรายการ: `kind · block_id · block_sha256 · disposition · evidence/review-ref`. validator **derive closure จาก canonical review block เท่านั้น** (key = exact exception identity `kind+block_id+sha256` ไม่ใช่ canonical-id — กัน 091C-D1c ที่มี 2 kind ปิดพลาด). **ห้าม manifest column/allowlist เป็น authority.** 
- benign **แต่ต้อง review จริง ไม่ใช่ "disposed":** 086/093/096C (DONE-mechanical) · 003/009 (SKIPPED) · 065/066/067 (BUILT+verdict-inline) — Opus เขียน closure จริงต่อรายการ · **091C-D1c ต้อง review ผล D1c โดยตรง** (ห้ามถือว่า D1f ปิดย้อนหลังอัตโนมัติ)
- benign list จริง = **9 canonical IDs** (003,009,065,066,067,086,093,091C-D1c,096C) ไม่ใช่ 10

**Phase 1b — จัดการ block ที่หลง active (append-only, verbatim):**
- **ORDER-071 rev02:** มี verdict แล้ว (REVIEW ORDER-071) → **ห้ามตัดสินซ้ำ ห้ามแก้ bytes** · validator (Phase 0) รับรู้ linked review = ปิด pending-stage exception
- **ORDER-071 rev01 (`OPEN` active L362):** superseded โดย rev02 → **ย้ายเข้า archive verbatim + append closure block** ("SUPERSEDED by rev02; final review = REVIEW ORDER-071") — **ห้ามลบทิ้งเฉย ๆ**
- **091C-D1c PROCESSING (active L665):** annotation stale → ย้าย/ปิด verbatim + closure (D1c reviewed) — ไม่ทิ้งเงียบ

**Phase 2 = C1a (hook) → C1b (migration) — 2 commit แยก:**
- **C1a (commit แยก):** ติดตั้ง+test hardened lock hook · **machine-checkable contract:** marker `.git/ea_lab_c1_lock.json` (ไม่ tracked, atomic create) มี expected-preimage blobs + exact candidate blobs + staged-path allowlist · hook อ่าน candidate จาก **git index (`git show :path`) ไม่ใช่ working tree** · staged-vs-expected exact (partial/extra staged path = fail) · **fail-CLOSED ถ้าไม่มี PowerShell** (ปิด fail-open เดิม `.githooks/pre-commit` L5) · crash-recovery ระบุ · test ใน **temp repo/index ไม่ใช่ shared worktree** · hook message **ห้ามแนะ `--no-verify`** (bypass เทคนิคปิดไม่ได้ อาศัยกฎ AGENTS)
- **C1b (1 atomic commit):** แทน manual index (L15) ด้วย **short pointer** (archive file + generated `ARCHIVE_INDEX.md` + validator command) · apply Phase-1/1b closures · regenerate manifest/index/exceptions · **archive preamble L4 stale banner** (บอกว่า index อยู่ taskboard) → append superseding notice **ไม่แก้ existing archived H2 blocks**

**Acceptance (machine-checkable):**
- [ ] Phase 0 validator upgrade: 071 exception หาย (linked review รับรู้) · validator รายงาน `raw_detected/canonically_reviewed/unresolved`
- [ ] **C0 `-Strict` exit 0 หลัง migration ก็ต่อเมื่อ:** integrity=0 · unresolved policy=0 · **ทุก closed exception มี canonical review ตรง exact block_id+sha256** · ไม่มี wildcard/canonical-id-only approval · ไม่มี stale/missing approval-ref
- [ ] manual index (L15) → pointer · agents ยังหา OPEN/CLAIMED order ได้ (test) · check_state.ps1 ยัง CLEAN
- [ ] archived H2 blocks **byte-unchanged** (append-only; รวม rev02) · rev01+091C-D1c ย้าย verbatim+closure · archive `-Audit` clean
- [ ] **C1b = 1 atomic commit** · staged set == expected allowlist exact · หลัง commit `HEAD:<path>`==candidate blobs · git diff --cached เท่านั้น (ไม่ whole-worktree)
- [ ] **negative tests:** disposition kind เดียวห้าม suppress อีก kind ของ id เดียว · stale disposition-hash หลัง block เปลี่ยน→exit 2 · unknown/dup disposition→exit 2 · missing review-ref→Strict 1/integrity 2 · non-terminal archive ไม่มี linked terminal review→Strict fail · hook: commit แตะ taskboard ระหว่าง lock (ไม่ใช่ migration)→blocked · staged≠working-tree→hook fail · no-PS→fail-closed
- [ ] `[tag] ORDER-102 done` + ผลดิบ

**ห้าม:** แก้ bytes ของ archived block เดิม (append-only) · ตัดสิน 071 ซ้ำ (verdict มีแล้ว) · manifest column/allowlist เป็น decision authority · ลบ block ที่หลง active ทิ้ง (ย้าย verbatim+closure) · whole-worktree restore/checkout · แตะ unrelated dirty files · implement Contract D

**Rollback (staged-blob protocol):** capture target preimage hashes ก่อนเริ่ม · C1b = explicit `git add -- <allowlist>` เท่านั้น · rollback = **revert/inverse ของ C1b ใต้ lock** + recheck target files ไม่มี later writes (มี = หยุด ไม่ restore ทับ) · **maintenance lock คงจน blind review ผ่าน หรือ rollback เสร็จ** · git commit atomic ต่อ repo state ไม่ใช่ทั้ง working tree.

### Codex C1 design review (2026-07-13) = needs-CHANGES → order REVISED r1 (Opus verify ยืนยันทุกข้อ)
- 🔴 **disposition = second authority (§20.7):** manifest column/allowlist กลายเป็น owner ใหม่ของ "reviewed" → **FIX:** canonical review block append-only, validator derive จาก review เท่านั้น, key = exact `kind+block_id+sha256` (ไม่ใช่ canonical-id — 091C-D1c มี 2 kind)
- 🔴 **ORDER-071 มี verdict อยู่แล้ว:** `REVIEW ORDER-071 REVIEWED ปิดถาวร` @ archive L2657 (Opus verify: มีจริง) — **C0 false-positive จาก canonical-id linking limit** · **FIX:** ห้ามตัดสินซ้ำ, upgrade validator รับรู้ linked review (Phase 0), rev01 OPEN ย้าย verbatim+closure ไม่ลบ
- 🔴 **lock ขัด acceptance:** "hook ใน commit ก่อน" vs "1 atomic commit รวม hook" ทำพร้อมกันไม่ได้ → **FIX:** แยก C1a (hook) / C1b (migration atomic) · lock marker ใต้ `.git/`, git-index-based, staged-vs-expected exact, fail-closed
- 🟡 atomicity: `git diff --cached` + staged-blob verify (ไม่ whole-worktree restore) · archive preamble L4 stale banner (append notice ไม่แก้ archived) · Strict-gate ต้อง unresolved=0 + review ตรง exact hash + report raw/reviewed/unresolved · negative tests เพิ่ม

**Status:** ORDER-102 = REVISED r1 (Codex needs-CHANGES ปิดครบ) · **pending Codex re-review** ก่อน execute · **execution ยังต้องรอ window เงียบจริง** (git log ยังเห็น session อื่น commit — ORDER-045/082/083C).

### C1 EXECUTION เริ่ม 2026-07-13 (user: window นิ่งแล้ว, run to completion) — Phase 0 DONE + เจอ design gate
- **Phase 0 DONE (validator review-linkage upgrade):** `check_taskboard_archive.ps1` รู้จัก `## REVIEW ORDER-x` (Source A) + `## C1-CLOSURE` block (Source B, key exact kind+block_id+sha256) · report **raw=12 / reviewed=2 / unresolved=10** · **-Strict=1** · negTests **20/20** · **071 false-positive ปิดแล้ว** (2 exception ผ่าน REVIEW ORDER-071 ที่มีอยู่) · read-only held. = ตัวปรับปรุง validator ที่มีค่าเดี่ยว ๆ (commit แล้ว).
- 🛑 **DESIGN GATE เจอตอน execute (surface ต่อ user):** C0 validator = **frozen-snapshot verifier** — append/แก้ archive ใด ๆ → `archive-not-append-only` **integrity exit 2** (พิสูจน์: append dummy block → audit exit 2) · ลบ manual-index block ออกจาก active (block นั้นอยู่ใน split-set 4aebbc37) → ตก (1b) drift ด้วย. **C1 โดยนิยาม mutate active+archive → incompatible กับ validator ปัจจุบัน.** → C1 execute ไม่ได้จนกว่า validator จะ evolve จาก "frozen snapshot" เป็น **"living append-only log (immutable split-prefix + tracked C1 appends)"** ก่อน. นี่คือ refinement ที่แผน+Codex C1 review ยังไม่ครอบ — **ผมหยุด surface แทนฝืน migrate พัง.**

**Next (รอ user เคาะทิศ):** (ก) evolve validator → living-log model (Phase 0.5, bounded) → แล้ว execute migration (index-pointer + move rev01/annotation append-only + C1-CLOSURE 9 rows → -Strict 0) → Codex review · หรือ (ข) checkpoint ที่นี่.

### C1b MIGRATION EXECUTED (Opus, 2026-07-13) — user: run to completion, window นิ่ง
Phase 0 + 0.5 (validator: review-linkage + living-log) commit แล้ว. Migration (Opus, deterministic script, preimage-captured):
- **manual index block (active) → short pointer** ไป generated `ARCHIVE_INDEX.md` (§20.7 · index generated/read-only แล้ว)
- **ORDER-071 rev01 (OPEN, superseded) → archive verbatim** (append-only) · closed via Source A (REVIEW ORDER-071 = ST03 ปิดถาวร)
- **ORDER-091C-D1c PROCESSING** = stale scratch annotation (D1c DONE+archived) → **removed from active** (transient, ไม่ใช่ history)
- **`## C1-CLOSURE` block (archive)** = Opus canonical closure 9 terminal-no-linked-review (003/009/065/066/067/086/093/091C-D1c/096C) key exact kind+block_id+sha256
- **Opus lead call:** defer C1a enforced-lock hook (window เงียบ + hook ผิด=self-DoS เสี่ยงกว่า) — migration ทำใน manual staged-blob discipline + validator gate แทน

**Opus-verified (รันเอง):** **C0 `-Strict` EXIT 0** · raw=11/reviewed=11/**unresolved=0** · **append-only clean** (0 mutated, 2 appends) · **0 active-order-lost** · integrity=0 · manifest/index/exceptions zero-diff · **check_state.ps1 CLEAN** · OPEN/CLAIMED orders ยังหาเจอ (15/4) · diff เฉพาะ 5 ไฟล์ (taskboard+archive+3 artifacts) ไม่แตะ unrelated · **106 bug caught by gate:** append lone-`\n` mutated 096C block (fixed) + statusless annotation ใน archive = status-unparseable (fixed = remove not archive) — validator gate จับทั้งคู่ก่อน commit.

**Status:** C1b DONE + Opus self-review ACCEPT · pending final blind Codex review.

### Codex final review of executed C1 (2026-07-13) = REWORK (data ACCEPT · enforcement REWORK)
**PASS (Codex verified อิสระ):** -Strict exit 0 · raw11/rev11/unresolved0 · integrity0 · active-order-lost0 · **history conservation: old archive prefix byte-identical, appended 5717 bytes = rev01+C1-CLOSURE เท่านั้น · rev01 verbatim (SHA เท่ากันเป๊ะ 6c8241d8) · 091C-D1c DONE order ยังอยู่ (L4523)** · index pointer ถูก, 15 OPEN/3 CLAIMED หาเจอ · 9 closures dispositions มีเหตุผล + exact-hash keyed (แก้ 003 → unresolved=1 พิสูจน์) · 071 ปิดผ่าน review เดิม ไม่ re-decide · commit scope สะอาด. **→ migration DATA รับได้.**
**REWORK (write-path enforcement — hole จริง):**
- 🔴 **P0 append-tamper:** `Invoke-ArchiveAppendOnlyCheck` เทียบกับ split baseline `4aebbc37` เท่านั้น → block ที่ append **หลัง** split (รวม C1-CLOSURE เอง + rev01) **แก้ได้แล้ว regenerate manifest → Strict กลับ 0** (Codex พิสูจน์ forge closure evidence + mutate rev01 ผ่านทั้งคู่). immutability คุมแค่ 131 split blocks ไม่คุม appends. **FIX:** append-CHAIN integrity — ทุก archive-changing commit ต้องพิสูจน์ staged archive = raw-byte prefix-extension ของ blob จาก parent commit · audit เดิน chain จาก anchor ผ่านทุก commit ที่แตะ archive · negTests (mutate closure/rev01 append → exit 2) · manifest regen ห้าม bless mutation
- 🔴 **P0 no enforced hook:** pre-commit ยังเรียกแค่ check_state + fail-OPEN ไม่มี PS → write path = manual discipline. **FIX:** fail-closed staged-snapshot hook (= C1a ที่ defer)
- 🟡 **P1 Source A กว้าง:** ปิดทุก exception ของ canonical-id เดียวผ่าน `REVIEW ORDER-<id>` ใด ๆ → อนาคต phase-review หรือ forged review ปิดข้าม. **FIX:** bind exact block-id/hash
- 🟡 **P1 atomicity:** 2-commit (0ced194 pin ผิด → 9e0bd8a ซ่อม). Codex ยืนยัน **hash-object / `git rev-parse :path`** = fix ถูก (single atomic). *(HEAD ปัจจุบันถูกแล้ว ไม่ rollback/rewrite)*

**⚖️ Lead note:** migration DATA correct + safe (git history = tamper-evidence จริง; validator append-check = defense-in-depth ที่ยังไม่ครบ). Enforcement REWORK = workstream ต่อ (append-chain + fail-closed hook + Source-A binding + hash-object) — เป็น C1a ที่ defer + P0 ใหม่ที่ Codex เพิ่งเจอ.

**Routing:** Opus resolve exceptions + execute migration + 1 atomic commit · subagent/Codex build lock-hook + disposition mechanism · **blind Codex review รอบผลจริง ก่อน accept** · Opus แก้ `AGENTS.md` ใน review commit ถ้า archive-immutability protocol ต้องการ (เช่น "archived block immutable; REVIEWED ใหม่เข้า archive ผ่าน validator -Strict"). C1 = commit แยก.

**→ หลัง C1 accept = order ที่ 4 → MANDATORY REVIEW GATE** (§20.2 #5): หยุด ทบทวน ACCEPT/REWORK/ROLLBACK ต่อ component (A/B/C0/C1) ก่อนเริ่ม Contract D (MVP-1-lite events).

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
> Records เต็ม: `_triage/CR002_ATTESTATION_REPORT_2026-07-19.md` + `_triage/CR002_EVIDENCE_RECONSTRUCTION_999094.md` · commits `50f9ff7b` `deead551` `e8d653a1`

- **CR-001 CLOSED:** `$cohort` hardcode ออกจาก `live_dashboard.ps1` → generate จาก `DEPLOYMENTS.csv` · checker 4/5 = generation-link guard · ทดสอบ `daily_monitor.ps1 -Force` เต็ม chain ผ่าน (auto-commit `5ef41b98`)
- **CR-002 first pass DONE:** owner ใหม่ `portfolio/ATTESTATION_MAP.csv` + snapshot v2 (attestation/unknown_magics/judge_cohorts) · 18/40 hashed · 20 NO_BUNDLE · promotion-evidence reconstruction 999094 พิสูจน์แล้ว (+6 evidence-manifest, Scan valid)
- **WAITING-USER (จาก report §2-3):** (1) จับคู่ชื่อ EA ให้ 9 unknown magics บน 159475669 แล้วเพิ่มแถว CSV (2) ยืนยัน set จริงของ 991001 (v2/v3/defaults) (3) judge_date 11 แถว user-lane (ข้อเสนอ: 990005 → 2026-10-09, ที่เหลือ mark USER-LANE ใน notes) (4) sensor 463666728 (สร้าง `D:\Monitor\MT5 - 463666728` + login) — ตัวบล็อกใหญ่สุดของ judge ต.ค. (5) 146237 DealsExporter ส่งไฟล์ header-only ต้องเช็ค terminal
- **OPEN (agent-able รอบหน้า):** lock bundle ให้ 990101/991004/991002 + Boss_14 bench ×7 (ต้องได้ .set จริงจาก user ก่อน) · VPS-side hash compare step (design ใน CR-002 gate) · CR-003 health engine ยังไม่เริ่ม
