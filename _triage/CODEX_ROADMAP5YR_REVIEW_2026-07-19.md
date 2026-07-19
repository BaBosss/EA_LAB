# Codex blind review — ROADMAP back-half 5yr (commit `d49843fe`) — 2026-07-19

> ผู้รีวิว: Codex (sandbox read-only — เขียนไฟล์เองไม่ได้ Opus บันทึกแทนจาก stdout เต็ม) ·
> ผู้ triage/แก้: Opus-seat · disposition ต่อข้อ = **FIXED** (แก้ใน ROADMAP.md commit ถัดจาก d49843fe) /
> **DEFERRED** (ไปอยู่ใน order ตอนแตกงาน) / **REJECTED** (พร้อมเหตุผล)

## 1. Internal contradictions

| Sev | Finding | Disposition |
|---|---|---|
| MAJOR | Phase 5 research Q4 2026 ขัด VISION "ห้ามเบี่ยงงานก่อน gate" | **FIXED** — ระบุเป็น bounded exception: ≤4 ชม./เดือน · delegate เท่านั้น · ห้ามจ่ายเงิน (user approve 2026-07-19) |
| MAJOR | CR-000 "blocker ปลด" กำกวม — ORDER-138 ปลดแค่ code, rollout ต้องรอ user เดิน PERSIST_MIGRATION_ORDER132 | **FIXED** — แยก gate เป็น code-ready vs rollout-ready |
| MAJOR | CR-005 "ไม่ต้องรอ 3 เดือน" อ่านได้ว่าลด promotion bar | **FIXED** — ระบุ CR-005 = เตือน/เลื่อน/probation เท่านั้น, bar VERDICT GATE ไม่เปลี่ยน |
| MAJOR | CR-006 ไม่ carry เงื่อนไข "หลัง judge + พอร์ต #1 live" จาก decision 2026-07-06 | **FIXED** — เพิ่มทั้งสองเงื่อนไขเข้า gate CR-006 |

## 2. Sequencing/dependency

| Sev | Finding | Disposition |
|---|---|---|
| **BLOCKER** | account #2 / prop challenge เปิดได้โดยไม่ผ่าน CR-002 attestation → FIX-THEN-SCALE ไม่ถูกบังคับจริง | **FIXED** — hard prerequisite: account ใหม่ทุกใบต้องผ่าน CR-002 + restore drill + telemetry ก่อนเติมเงิน · prop challenge ต้อง CR-002 ผ่าน + telemetry ≥30 วัน |
| MAJOR | ไม่มี immutable promotion-evidence ก่อน CR-005 locked profile | **FIXED** — เพิ่มเข้า gate CR-002: promotion-evidence reconstruction 1 candidate (reuse Contract D manifest) |
| MAJOR | SQLite/Snapshot เสี่ยงชน owner เดิม (anti-drift §0.5) | **FIXED** — SQLite = rebuildable read-model · Snapshot = read-only projection + source-hash/as-of · ห้าม write-back |
| MAJOR | CR-003 จับ behavioral drift ก่อนมี expected profile (CR-005) = ลำดับกลับ | **FIXED** — CR-003 จำกัด system/config/stale drift + injected/replay fixtures · behavioral → CR-005 |
| MINOR | ไม่มี crosswalk deflated gate ↔ CR ขั้นไหน | **FIXED** — crosswalk ใน gate CR-006: bands→CR-005 · portfolio risk→CR-006 · deflated→CR-005 |

## 3. Gates non-numeric

| Sev | Finding | Disposition |
|---|---|---|
| MAJOR | CR-003..007 เกณฑ์ไม่ falsifiable | **FIXED บางส่วน** — CR-003: fixture 100% + false-alarm ≤1/สัปดาห์ shadow 30 วัน · CR-007: 14-day soak + zero unapproved money action · **DEFERRED**: ตัวเลขละเอียดต่อขั้น = ใส่ตอนแตก order (convention: order คือที่อยู่ acceptance criteria) |
| MAJOR | Phase 5 gate "รอด 3 เดือน" ไม่มีนิยาม | **FIXED** — live+90 วัน · ≥30 trades · no kill trip · CR-002 evidence ครบ · re-check firm rules ก่อนจ่าย |
| MAJOR | Phase 6 "verified ≥2 ปี" ไม่มีนิยาม | **FIXED** — ต่อเนื่อง gap ≤2 สัปดาห์ · live เท่านั้น · ≥300 trades · external verification (เกณฑ์ตั้งต้น ปรับได้ตอนเปิดเฟส) |
| MAJOR | payoff-shape ถูกอ่านเป็น replacement ของ evidence bar | **FIXED** — ระบุ = ranking ซ้อนบน bar VERDICT GATE ไม่ใช่แทน |

## 4. Realism

| Sev | Finding | Disposition |
|---|---|---|
| MAJOR | CR-001..005 serial 12–22 สัปดาห์ ชน judge 2026-10-09/16 | **FIXED** — vertical slice: CR-001 → CR-002 (cohort ที่จะ judge) → minimal judge-readiness ให้ทัน ต.ค. |
| MAJOR | CR-007 unattended ยังติด dependency (gh token, interactive MT) | **FIXED** — credential-expiry alarm + reboot recovery + expired-token sim เข้าเงื่อนไข CR-007 |

## 5. Hunt-rule v2

| Sev | Finding | Disposition |
|---|---|---|
| **BLOCKER** | เลน agent 100% ชน AGENTS.md §3.9 (external input ต้องผ่าน filter) | **FIXED** — agent ทำได้เฉพาะ artifact ที่ผ่าน filter แล้ว · ของใหม่จากภายนอกผ่าน Claude/Codex ก่อนเสมอ |
| MAJOR | "ห้ามกินเวลา lead แม้นาทีเดียว" ขัด workflow จริง (lead เขียน order/review) | **FIXED** — zero *discretionary* time ระหว่างรัน · order+review อยู่ในโควตา 10% |
| MAJOR | "กวาดไม่จำกัด" ไม่มี backpressure | **FIXED** — backlog ไม่จำกัด / execution cap ตาม pacing rule เดิม (1–2 order/รอบ) + tester ว่าง |
| MAJOR | "เข้า bench อัตโนมัติ" ปน smoke กับ validated + เสี่ยง automation ออก verdict | **FIXED** — บันได INTAKE_RAW→SMOKE_SURVIVOR→VALIDATION_WIP→VALIDATED_BENCH · automation หยุดที่ SMOKE_SURVIVOR · verdict = Claude/user เท่านั้น |
| MAJOR | 50/25/15/10 ไม่มี denominator | **FIXED** — lead-attention hours rolling 4 สัปดาห์ · compute ไม่นับ |

**สรุป:** 2 BLOCKER + 14 MAJOR + 1 MINOR → FIXED 16 · FIXED-บางส่วน/DEFERRED-to-order 1 · REJECTED 0.
ทุกแก้อยู่ใน ROADMAP.md commit ถัดจาก `d49843fe`.
