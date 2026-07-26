# Evidence sweep — 36 order ที่ terminal แต่ยังไม่ review (2026-07-26)

> ⚠️ canonical entry = `PROJECT_STATE.md` · ไฟล์นี้ owns: **หลักฐานดิบของการตรวจ 36 บล็อกนั้น** เท่านั้น — ไม่ใช่ verdict
> · verdict จริงต้องเขียนลง `AGENT_TASKBOARD.md` · วงจรชีวิต → `docs/WORK_LIFECYCLE.md`

**ทำไมมีไฟล์นี้:** บอร์ดมี 36 บล็อกที่สถานะเป็น `DONE(...)`/`CLOSED(...)` เปล่า — ย้ายเข้าคลังไม่ได้เพราะ
`check_taskboard_archive.ps1` จะจุด `terminal-no-linked-review`. ก่อนจะเขียน `REVIEWED` ให้ทั้ง 36 ใบ
ต้องรู้ก่อนว่า**ข้ออ้างในแต่ละใบยังจริงอยู่ไหม** — ไม่ใช่ประทับตราเพราะ header บอกว่าเสร็จแล้ว
ทุกใบถูกตรวจโดย resolve path จริง · resolve commit hash จริง · grep หา section/banner ที่มันอ้าง

---

## สรุป

| ผล | จำนวน | แปลว่า |
|---|---|---|
| **CONFIRMED** | 27 | ข้ออ้างที่เป็นรูปธรรมทุกข้อ resolve ได้ → เขียน `REVIEWED` แล้วย้ายได้เลย |
| **UNVERIFIABLE (ไม่มีพิษ)** | 1 | `080-orig` = spec เก่าที่ถูกแทน ไม่มี deliverable ให้ตรวจโดยธรรมชาติ |
| **PARTIAL** | 3 | บาง claim resolve ไม่ได้ / เป้าหมายไม่บรรลุจริงตอนใช้งาน |
| **CONTRADICTED** | 3 | **หลักฐานบอกว่าข้ออ้างผิด หรือถูกกลับไปแล้ว** |

**⚠️ เลขบรรทัดในรายงานรอบนี้เคลื่อนตลอด** — บอร์ดถูกเขียนโดย session คู่ขนานระหว่างตรวจ
(ORDER-222 เปลี่ยน `OPEN` → `DONE + REVIEWED` กลางทาง) **ห้ามใช้เลขบรรทัดจากไฟล์นี้ ให้ grep ด้วยเลข order เสมอ**

---

## 🔴 CONTRADICTED 3 ใบ — pattern เดียวกันทั้งหมด

**ทั้ง 3 ใบเป็นบั๊กเดียวกัน ไม่ใช่ 3 เรื่อง:** หลักฐานปลายน้ำขยับ แต่บล็อกที่ปิดไปแล้วไม่ขยับตาม —
และ**ทุกครั้งคำแก้ถูกเขียนไว้จริง แค่ไปอยู่ที่อื่น** (banner บนไฟล์ verdict · ช่อง `notes` ใน `DEPLOYMENTS.csv` ·
เนื้อของ order ใบใหม่กว่า) → นี่คือเหตุผลของ **ORDER-252** (staleness linter)

### ORDER-073 — ✅ แก้แล้ว commit `e2098c9e`
บอร์ดคือ**พื้นผิวสุดท้าย**ที่ยังอ้าง `eqDD −54..−56%` ซึ่ง ORDER-211 สั่งห้ามไว้ตรงๆ
(`MACROGATE_AB_VERDICT.md` · bundle README · PROJECT_STATE ติด banner กันหมดแล้ว บอร์ดไม่ติด)
เป็น magic ที่ **attach อยู่จริง** ⇒ ความเสี่ยงจริง ไม่ใช่แค่เอกสารเพี้ยน

### ORDER-143 — ❌ ยังไม่แก้ → **ORDER-250**
ปิดเมื่อ 07-20 ว่า *"EA ไม่มี `_2_PartialPct1`/EMA200 ⇒ sweep ไม่ได้รัน · next = หา HOME ใหม่ ไม่ใช่ stack lever"*
ข้อความนั้น**จริง ณ วันนั้น** (`git log -S'_07_UseTrendFilter'` ยืนยันว่า input ยังไม่มี)
**แต่ commit `a88db4c6` (07-23) เพิ่ม input เข้าไปจริง รัน funnel และดัน SS1 เป็น VALIDATED CANDIDATE → demo 992003**
(M4 1.16/1.06 · holdout 1.21@n=86 · MC ruin 0.00%) ⇒ ข้อสรุป "next = different HOME" **เป็นโมฆะ**
ต้องแก้ที่ `STATUS.md` ด้วย

### ORDER-188 — ❌ ยังไม่แก้
อ้าง cage lot mode 42/43 "8 เคส A–H ผ่านหมด" — **แต่ ORDER-220 (REVIEWED 07-26) รันเคส E ใหม่แล้วพบว่า
✅ เดิมคือ run 6 ไม้ที่โดน DD-25% ฆ่าตั้งแต่วันที่ 8** ตอนนี้ cage เป็น 13 เคสแล้ว (`E2_unit_indep_hi`, `K0/K1_scaled_*`)

---

## 🟡 PARTIAL 3 ใบ

| order | เรื่อง |
|---|---|
| **187** | header ยังเขียน `— รอ Codex blind-audit` ทั้งที่ audit นั้น**รันไปแล้ว**และ**ผลไม่สะอาด** (2 high/1 med/1 low → ORDER-194b) แล้ว 194c ยังเจอ fix ที่ทำไม่ครบอีก 2 + บั๊กใหม่ 1 · และประโยค "ไม่มี .set สักไฟล์ที่พัง" ถูก ORDER-194b หักล้างแล้วแต่ 187 ไม่เคยถูก annotate · path `deploy.ps1` ที่อ้างจริงอยู่ `ea_template/deploy.ps1` |
| **193** | wiring truncated-run detector มีจริง **แต่ ORDER-219 พบว่าช่อง `detail` ว่างเปล่าทั้ง 182 sidecar** (Write-Host ลง stream 6, `2>&1` จับไม่ได้ — แก้ด้วย `6>&1` แล้ว) ⇒ เป้าหมายข้อ (c) "ไม่มี verdict ที่เขียนจาก sample ที่ถูกตัดเงียบ" **ไม่เป็นจริงในทางปฏิบัติ**สำหรับ run ก่อนวันแก้ |
| **161** | ของครบทุกชิ้น ✓ แต่ follow-up ที่ตัวมันเองสั่งไว้ ("re-run cage หลัง ORDER-165 re-pin baseline") **ไม่มีผลบันทึกไว้** |

---

## ✅ CONFIRMED 27 + UNVERIFIABLE 1 — เขียน REVIEWED แล้วย้ายได้

`189 · 194c · 192(b) · 196 · 195 · 194b · 191 · 192 · 194 · 165 · 161* · 144 · 145 · 118 · 120 · 121 · 122 · 123 ·
128 · 064 · 076 · 079 · 080 · 080-orig · 084 · 097 · 098-C(MM-parts) · 102`

<sub>`161` อยู่ในกองนี้แต่มี follow-up ค้าง (ดูตาราง PARTIAL) · `128` code ตรวจได้ครบ แต่ครึ่ง E2E (gist id เก็บที่
`D:\Monitor\` นอก repo + สถานะ gh keyring) **ตรวจจาก repo ไม่ได้โดยธรรมชาติ** ไม่ใช่เพราะดูน่าสงสัย</sub>

## 🔧 ต้องแก้ header/body ก่อนย้าย 9 ใบ

| order | แก้อะไร |
|---|---|
| **073** | ✅ ทำแล้ว (`e2098c9e`) |
| **143** | เติม: กลับด้านโดย `a88db4c6` → SS1 = VALIDATED CANDIDATE demo 992003 · แก้ `STATUS.md:42` ด้วย |
| **188** | เติม: เคส E เดิม = run 6 ไม้ที่ DD ฆ่า (ORDER-220) · cage เป็น 13 เคสแล้ว |
| **193** | เติม: `detail` ว่างทั้ง 182 ใบจนถึง ORDER-219 |
| **187** | (i) `— รอ Codex blind-audit` → `— Codex blind-audit DONE (ORDER-194b/194c)` (ii) เติม pointer ว่าประโยค ".set ไม่พัง" ถูกหักล้าง |
| **072** | path: `core\Kangaroo.mqh` → `core\entries\Kangaroo.mqh` · `tests\run_tests.ps1` → `ea_template\tests\run_tests.ps1` |
| **036** | path: `ORDER-036_MT4_MASS_SMOKE.md` → `_archive_docs/ORDER-036_MT4_MASS_SMOKE.md` |
| **112E** | "990069 reserved" → 990069 **attach แล้วและ ACTIVE** บน 463666728 |
| **189** | (เล็ก) banner ในไฟล์ registry "183 real inputs = 183/183" → **184/184** (ตรวจแล้วสองฝั่งตรงกัน) |

## 🆕 ที่กลายเป็น order ใหม่แล้ว

- **ORDER-250** ← SS1 LondonORB ไม่มี order-of-record + corr ยังไม่วัด (judge 2026-10-23)
- **ORDER-251** ← คลัง skill อยู่นอก repo ไม่มี version control ทั้งที่เป็นเจ้าของบาร์ตัดสินทุกใบ
- **ORDER-252** ← staleness linter (จับ pattern ของ 073/143/188 อัตโนมัติ)

## หมายเหตุอื่น

- **`ORDER-098-C` เป็น id ซ้ำจริง** — บรรทัดหนึ่ง = FVG-fill + RSI gate (REVIEWED แล้ว) อีกบรรทัด = MM-parts library
  repo เคย renumber หนี collision มาแล้วหลายรอบ (133→135 · 134→136 · 152→161 · 096→097) ใบนี้หลุด
  ตอนนี้ `check_order_collision.ps1` grandfather ไว้ ยังเป็นหนี้ที่ต้องแก้
- **archive มี id ซ้ำอีก 2** (`071`, `091B`) — validator ปัจจุบันไม่ตรวจ duplicate ภายใน archive
