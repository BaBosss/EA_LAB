# AGENTS.md — กติกากลางสำหรับทุก AI agent ในเครื่องนี้ (Claude Code / Codex / ZCode)

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **บทบาท + ขอบเขตสิทธิ์ + protocol การทำงานร่วมกัน
> ของ agent ทุกตัวเท่านั้น** — สถานะ/แผน/verdict อยู่ที่ PROJECT_STATE.md · คิวงานอยู่ที่ AGENT_TASKBOARD.md

**อ่านก่อนเริ่มงานทุกครั้ง (ทุก agent):** `VISION.md` → `PROJECT_STATE.md` → `AGENT_TASKBOARD.md` → ไฟล์นี้

---

## 1. บทบาท (ตาม strength — อย่าสลับเอง)

| Agent           | บทบาท                                                                       | ทำได้                                                 | ห้ามเด็ดขาด                                                                                          |
| --------------- | --------------------------------------------------------------------------- | ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **Claude Code** | Lead engineer / judge — ทิศทาง, verdict, เขียน order, review งาน agent อื่น | ทุกอย่าง                                              | —                                                                                                    |
| **Codex**       | Peer engineer — execute order ที่ scope ชัด, second opinion เมื่อถูกถาม     | โค้ดตาม spec ของ order, รันทดสอบ, **รายงานตัวเลขดิบ** | ตัดสิน verdict · แก้ VISION.md · แก้ Decision log (§3) · แก้กฎใน skill/ไฟล์นี้ · เปลี่ยนทิศทางงานเอง |
| **ZCode**       | Batch runner — รัน backtest/optimize/parse ตาม order                        | รัน script ที่มีอยู่, เก็บผลเป็นตาราง/CSV             | เหมือน Codex + **ห้ามแก้ source code ทุกไฟล์**                                                       |

หลักเดียวที่ครอบทุกอย่าง: **agent อื่น "ผลิตหลักฐาน" — Claude/user เป็นคน "ตัดสิน"**
เจองานที่ต้องตัดสินใจนอก order → หยุด, เขียน BLOCKED ลง taskboard พร้อมคำถาม, ไปทำ order ถัดไป

## 2. สิทธิ์การเขียนไฟล์ (single-writer — กัน drift)

| ไฟล์                                                                                                             | ใครเขียนได้                                                                                                 |
| ---------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `VISION.md` · `PROJECT_STATE.md` §3 Decision log · verdict ใน `EA_SCORECARD_AND_REGISTRY.md` · `AGENTS.md` (นี่) | **Claude / user เท่านั้น**                                                                                  |
| `AGENT_TASKBOARD.md`                                                                                             | ทุก agent — แต่เขียนได้เฉพาะ **แถว order ของตัวเอง** (claim/ผล/BLOCKED) · การเพิ่ม order ใหม่ = Claude/user |
| `PROJECT_STATE.md` ส่วนอื่น (status one-liner, HANDOFF)                                                          | Claude เป็นหลัก · agent อื่นห้ามแก้ ให้เขียนผลลง taskboard แทน                                              |
| source code (`ea_template\`, `scripts\`, EA_Project)                                                             | Claude + Codex (ตาม order) · ZCode ห้าม                                                                     |
| reports/CSV/set files ใหม่                                                                                       | ทุก agent (ตาม order)                                                                                       |

## 3. กฎเหล็กทางเทคนิค (ทุก agent — ผิดข้อใดข้อหนึ่ง = งานนั้นใช้ไม่ได้)

1. **แก้ `ea_template\core\*` เมื่อไหร่ ต้องรัน `powershell -File scripts\tpl_regression.ps1` → ต้อง CLEAN** ก่อน commit
2. **MT5 มี instance หลักตัวเดียว** (`D:\Meta 5`) — ปิด GUI ก่อนรัน headless, รันทีละงาน (script abort เองถ้าชน) · ห้าม `-Force` · ห้าม kill process
3. **ตัวเลขที่รายงาน = Model 1 ขึ้นไป** (Model 2 ใช้กรอง zero-trade เท่านั้น) · ทุก full-window run แตกปีด้วย `scripts\report_year_split.py`
4. **Verdict rules (สรุปจาก decision log — อ่านฉบับเต็มใน PROJECT_STATE §3):**
   ห้าม DEAD/REJECT ก่อน optimize probe · cap breach (DD/margin/ruin) = resize-first ห้าม reject ตรง ·
   เลข optimizer = in-sample เสมอ · backward-OOS บังคับเมื่อ IS/OOS อยู่ regime เดียว
   — agent อื่นไม่ต้องใช้กฎพวกนี้ตัดสินเอง แค่**อย่ารายงานสรุปที่ขัดกับมัน** (รายงานตัวเลขดิบพอ)
5. **Git:** commit บ่อย, ข้อความ commit ขึ้นต้นด้วย tag ตัวเอง `[codex]` / `[zcode]` · ห้าม push/force/rebase/amend ·
   ห้าม `--no-verify` (pre-commit guard คือกันชนของทุกคน) · ทำงานบน branch ปัจจุบัน อย่าสร้าง/สลับ branch เอง
6. Python = portable: dot-source `scripts\use_python.ps1` ก่อน (ไม่มี system python)

## 4. วงจรการทำงาน (ต่อ 1 order)

```
Claude เขียน order ลง AGENT_TASKBOARD (มี: งาน · คำสั่ง/ไฟล์ · acceptance criteria · ข้อห้าม)
  → agent อื่นเปิดเครื่อง: อ่าน 4 ไฟล์บังคับ → เลือก order สถานะ OPEN ตัวบนสุดที่ตรง role
  → แก้สถานะเป็น CLAIMED(ชื่อ, เวลา) → ทำงาน → append ผลดิบใต้ order → สถานะ DONE → commit [tag]
  → Claude กลับมา: git log + taskboard → review → ตัดสิน → ย้าย verdict เข้า scorecard/PROJECT_STATE
  → สถานะ REVIEWED → เขียน order รอบถัดไป
```
- order ละ **1 งานจบในตัว** ผลตรวจได้ด้วยตัวเลข/ไฟล์ — ถ้างานใหญ่ Claude ต้องหั่นก่อน
- ไม่มี order OPEN เหลือ + Claude ไม่อยู่ → **หยุด อย่าคิดงานใหม่เอง** (บันทึกข้อเสนอเป็น comment ใน taskboard ได้)

## 5. เมื่อไหร่ใช้ตัวไหน (มุมมอง user)

- งานคิด/ทิศทาง/verdict/ออกแบบ order → **Claude** (ใช้ quota ที่นี่ให้คุ้ม — ชั่วโมงของ Claude ควรจบที่ "order ชุดใหม่ + verdict ของผลเก่า" ไม่ใช่รัน backtest เอง)
- Claude quota หมด + มี order ค้าง → **Codex** (งาน code/ผสม) หรือ **ZCode** (งานรันล้วน)
- อยากได้ second opinion เรื่องใหญ่ → ถาม Codex คำถามเดียวกับที่ถาม Claude **โดยไม่ให้ดูคำตอบของอีกฝ่าย** แล้ว user/Claude สังเคราะห์เอง
