---
name: corpus-intake
description: >-
  Mass-intake triage of an EA/strategy corpus (course libraries, downloaded EA folders,
  YouTube-channel strategy collections, TradingView Pine scripts) WITHOUT burning tokens
  reading raw files — deterministic parser first, concept catalog second, shortlist third.
  Use when the user drops a folder of many EAs/scripts, says "แกะ logic คลังนี้",
  "เรียนมาได้ไอเดียอะไรบ้าง", or wants a new corpus (YouTube/TradingView) mined for ideas.
  Do NOT use for analyzing a single EA (that is locked-ea-analyzer or plain code reading).
---

# Corpus intake — ขุดไอเดียจากคลังไฟล์เป็นร้อย/พันโดยไม่เปลือง token

หลักคิด (พิสูจน์ 2026-07-10 กับคลังคอร์ส fxDreema 3,513 ไฟล์ → 1,050 unique):
**parser กำหนดเอง (deterministic) อ่านทุกไฟล์ · Claude อ่านเฉพาะการ์ดสรุป/แคตตาล็อก** —
ต้นทุน token ต่อไฟล์ ≈ ศูนย์ · และ**สองมุมมองแยกเอกสารกัน เด็ดขาด**:
1. **X-RAY** (risk structure) — ตอบ "ตัวไหน attach ได้เลย": SL/cap/escalation/DLL/WebRequest/timelock
2. **IDEA CATALOG** (concepts) — ตอบ "เรียนมาได้ไอเดียอะไร": ห้ามมีธง risk โผล่ในเอกสารนี้
   (คลังเรียน = เมล็ดไอเดีย แบบฝึกย่อมไม่มี SL — user rule: อย่าตัดสินสื่อการเรียนด้วยเกณฑ์ production)

## Workflow

1. **Locate + dedupe**: กวาดหาไฟล์ (mq4/mq5: grep signature เช่น "fxDreema") → dedupe ด้วย
   content hash → 1 แถว = 1 unique EA (คลังจริงซ้ำกัน ~3 เท่า)
2. **X-ray pass**: `D:\EA_LAB\scripts\fxdreema_xray.py` (ปรับ regex ตาม builder ของ corpus) →
   `_triage\<CORPUS>_XRAY.md` + `.csv` — ต้อง **spot-check กับไฟล์ที่รู้คำตอบแล้ว** ก่อนเชื่อ
3. **Concept pass**: `D:\EA_LAB\scripts\fxdreema_concepts.py` — แหล่ง evidence เรียงคุณค่า:
   block labels ที่คนเขียนเอง > ชื่อไฟล์/โฟลเดอร์ > string constants > indicator set (fallback)
   → taxonomy + **cross-ref สถานะแล็บ** (memory signal-landscape + EDGE_CATALOG): VALIDATED /
   TESTED-DEAD / PARTIAL / **NEVER-TOUCHED** (ก้อนหลังคือขุมทรัพย์)
4. **Shortlist สองแกน**: (ก) attach-ready (X-ray: has_sl + no escalation) → คิว smoke ผ่าน filter chain
   ปกติ — cross-ref กับของที่เคย screen แล้วก่อน ห้ามรันซ้ำ (ข) idea-worthy (catalog: NEVER-TOUCHED
   ที่เข้า edge thesis) → คุยกับ user ก่อน build (user มักมีความรู้จากคอร์ส/ประสบการณ์ที่ไฟล์ไม่มี)

## กับดักที่จ่ายจริงแล้ว

- **Boilerplate poisoning**: string template ที่โผล่ทุกไฟล์ (เช่น "Unable to set chart doji candle
  color") ทำหมวดโป่งผิด 14 เท่า (224→16 หลัง filter) — ทุก corpus ต้องหา boilerplate ของมันก่อน
- fxDreema: template defaults มี `(string)` cast แต่ block overrides ไม่มี — ใช้แยกค่า default จริง
- ผลลัพธ์ = จุดเริ่มคุยกับ user ไม่ใช่ verdict — เกณฑ์ rescue-ladder + PARKED-VERIFY(user) ใน
  `backtest-optimize-rigor` คุมตอนทดสอบต่อ

## Corpus ใหม่ที่รอ (ณ 2026-07-10)

- YouTube strategy pages ของ user → ไม่มีไฟล์โค้ด: catalog หัวข้อจากชื่อคลิป/คำอธิบายก่อน แล้วเลือก
  ทำ spec เฉพาะที่ user ชี้ (ถอดเสียง = ไพ่ใบสุดท้าย)
- TradingView Pine scripts → ต้องเขียน `pine_xray.py` variant (โครงเดียวกัน: inputs / indicator calls /
  strategy.entry-exit / risk keywords)
