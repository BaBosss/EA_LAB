# ORDER-169 — เกณฑ์ตัดสิน EA: แผนที่ 4 แหล่ง + จุดที่ขัดกันจริง

> เขียน 2026-07-23 (Opus-seat) · ต่อจากที่ ORDER-153 บันทึกไว้ว่า "band มี 2 สูตร" — **ตรวจจริงแล้วมี 4 แหล่ง**
> เอกสารนี้ = แผนที่ + แก้เฉพาะจุดที่ผิดชัดเจน · จุดที่เป็น policy จริงยกให้ user เคาะ ไม่ตัดสินแทน

## แหล่งทั้งหมดที่มีเกณฑ์ตัดสิน EA

| # | แหล่ง | สถานะ | เกณฑ์ที่มี |
|---|---|---|---|
| 1 | `CLAUDE.md` VERDICT GATE bar table | user ratified | demo→LIVE: PF ≥ **1.40** @ ≥**30** trades · demo kill (default, override ต่อ-EA ได้): eqDD > **12%** · 3-mo PF < **0.8** @ ≥**15** trades |
| 2 | `docs/JUDGE_DAY_RUNBOOK.md` §2 | "ตรึงแล้ว" | KILL ทันที: **absolute** live PF < **0.7** @ ≥**20** t · PROMOTE: PF ≥ **1.40** @ ≥**30** t · PROBATION: 0.9 ≤ PF < 1.4 @ ≥30 t · PF **0.7–0.9** @ ≥30 t = default KILL |
| 3 | `docs/JUDGE_DAY_RUNBOOK.md` §2.1 | "ตรึงแล้ว" | **ratio** PF_live/PF_expected ผ่าน = **[0.6, 1.8]** · trade-rate ratio **[0.5, 2.0]** |
| 4 | skill `ea-live-monitor` SKILL.md | live ใช้งานจริง | `ALERT_PF = BT_PF × 0.7` · KEEP ≥0.7× BT · PAUSE @ ≥**25** t · KILL: net ลบ @ ≥**40** t AND PF < **0.5×** BT |
| (5) | `AGENT_TASKBOARD_PQUANT.md` PQ-03 | 🔒 LOCKED | ratio [0.6, 1.8] · rate [0.5, 2.0] · 🔴 @ ratio <0.6 ที่ ≥20 t |

## ✅ ที่ไม่ขัดกัน (เข้าใจผิดกันไปเอง)

**PQ-03 ตรงกับ runbook §2.1 เป๊ะ** ([0.6, 1.8] / [0.5, 2.0]) — ORDER-153 บันทึกว่า "PQ-03 ขัดกับ skill" ซึ่งถูก
แต่สรุปไม่ครบ: **PQ-03 ไม่ได้เป็นฝ่ายผิด มันลอกมาจาก runbook ถูกต้องแล้วตามที่มันเขียนกำกับตัวเองไว้**
("นิยามเดียวกับ runbook §2.1 เพื่อไม่ให้มีสองสูตร"). ตัวที่หลุดคือ **skill**.

## 🔴 ที่ขัดกันจริง — และร้ายแรงกว่าเรื่องตัวเลข

### (ก) skill ขาด **absolute-PF ladder ทั้งชุด** ← ปัญหาใหญ่สุด ไม่ใช่แค่เลขต่าง

runbook §2 ให้ absolute PF เป็น**กลไกตัดสินหลัก** (0.7 / 0.9 / 1.4 ที่ 20/30 ไม้) — **skill ไม่มีเลยสักข้อ**
มีแต่ ratio เทียบ backtest อย่างเดียว.

**ผลที่เกิดได้จริง:** EA ที่ live PF = 0.75 (absolute) — runbook §2 ข้อ 4 บอก **default KILL** ที่ ≥30 ไม้ —
แต่ถ้า backtest PF ของมันคือ 1.0 → ratio = 0.75 ซึ่ง > 0.7 → **skill ตอบ KEEP**. เกณฑ์หลักถูกข้ามเงียบ
เพราะ skill วัดคนละแกน. judge day (2026-09-22) จะรันด้วย skill นี้ = ตัดสินด้วยเกณฑ์ที่ไม่ใช่ของจริง.

### (ข) ratio threshold: skill 0.7 vs canonical 0.6

น่าจะเกิดจาก**หยิบเลขผิดแกน** — runbook มี `0.7` อยู่จริงแต่เป็น **absolute** PF (§2 ข้อ 1)
ส่วน ratio ของ runbook คือ `0.6` (§2.1). skill เอา 0.7 ไปใช้เป็น ratio = ปนสองแกนเข้าด้วยกัน.

### (ค) trade-count gate ไม่ตรง: skill 25/40 vs canonical 20/30

## 🟡 ที่เป็น policy จริง — ไม่แก้เอง ยกให้ user

**`CLAUDE.md` demo-kill (3-mo PF < 0.8 @ ≥15 t) vs runbook §2 (PF < 0.7 @ ≥20 t)** — ต่างกันทั้งเลขและ
จำนวนไม้ **แต่ทั้งคู่ user ratified ทั้งคู่** และอาจตั้งใจให้ต่างกันเพราะคนละด่าน (demo-kill ระหว่างทาง
vs judge-day decision). **ผมไม่รวมสองอันนี้เอง** — ถ้าตั้งใจให้ต่างต้องเขียนกำกับว่าอันไหนใช้ตอนไหน
ถ้าไม่ตั้งใจต้องเลือกอันเดียว. **← ข้อนี้รอ user เคาะ**

## สิ่งที่แก้ในรอบนี้ (เฉพาะข้อ ก/ข/ค — ผิดชัดเจน ไม่ใช่ policy)

แก้ที่ **ต้นเหตุเชิงโครงสร้าง ไม่ใช่แก้เลขทีละจุด**: ปัญหารากคือ**เลขถูก copy ไปฝังไว้ 4 ที่**
แก้ที่เดียวที่อื่นไม่ตาม เลยเพี้ยนซ้ำได้เรื่อยๆ → เปลี่ยน skill ให้ **อ่านเกณฑ์จาก canonical source
ตอนรัน แทนการฝังเลขของตัวเอง** = ตัดคลาสปัญหานี้ทิ้ง ไม่ใช่แค่ปิดรอบนี้.

ดู diff จริงที่ `C:\Users\patip\.claude\skills\ea-live-monitor\SKILL.md`.

## 🔧 งานค้าง 1 จุด — stale path ใน scorecard (ถูก guard บล็อกโดยชอบธรรม ไม่ bypass)

`EA_SCORECARD_AND_REGISTRY.md` บรรทัด ~356 ยังชี้ไปที่ `docs\RECOVERED_PLATFORM_DESIGN_20260614.md`
ซึ่ง **ย้ายเข้า `_archive_docs/` ไปแล้ว** ตอน ORDER-152(c) → path ตายอยู่.

**ทำไมยังไม่แก้:** `check_precommit_staged.ps1` (ORDER-144) บังคับว่า `EA_SCORECARD_AND_REGISTRY.md`
กับ `EA_MASTER_INDEX.csv` ต้อง staged **คู่กันเสมอ** ("single registry transaction" — กันคนแก้ verdict
ที่หนึ่งแล้วลืม sync อีกที่). ผมเช็คแล้ว **index ไม่มี reference ถึงไฟล์นี้เลย** → ไม่มีการแก้คู่ที่ชอบธรรม
จะให้ commit ผ่านต้องปั้นการแก้ index ขึ้นมาเปล่าๆ ซึ่ง**ผิดเจตนา guard** · และ `--no-verify` ห้ามตาม
`AGENTS.md` ข้อ 5 → **จึงถอยการแก้ออก ไม่ฝืน**.

**ทางปิดที่ถูกต้อง (เลือกอันใดอันหนึ่ง — รอ user):**
1. รอ commit ถัดไปที่แตะ registry pair จริงอยู่แล้ว (มี verdict เปลี่ยน) แล้วพ่วง path fix ไปด้วย — ง่ายสุด ไม่ต้องแก้อะไร
2. ปรับ guard ให้แยกแยะ **doc-only edit** (comment/path/prose) ออกจาก **verdict/row edit** — แก้ที่ต้นเหตุ
   แต่ต้องระวังไม่ให้เปิดช่องให้ verdict หลุดผ่าน (guard นี้มีไว้กันเรื่องนั้นโดยตรง)

**ระหว่างนี้ path ยังตายอยู่จริง** — ใครตามลิงก์นี้จะไม่เจอไฟล์ (แต่ไฟล์ยังอยู่ที่ `_archive_docs/`
และ **เนื้อหา scoring ของมัน superseded ไปแล้ว** โดย `CLAUDE.md` VERDICT GATE + skill
`backtest-optimize-rigor` — ดังนั้นความเสียหายจริงต่ำ: คนที่ตามไปไม่ควรใช้มัน scoring อยู่แล้ว).
