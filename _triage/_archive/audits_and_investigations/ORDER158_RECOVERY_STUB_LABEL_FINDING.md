# ORDER-158 part (1) — Recovery 82/83 "(stub)" label vs actual code

> เขียน 2026-07-23 (Opus-seat) · รายงานหลักฐานเท่านั้นตามที่ order สั่ง — **ไม่แก้โค้ด/ป้ายในไฟล์นี้**

## ข้อเท็จจริง

`ea_template/core/Inputs.mqh:86-87`:
```
REC_ADAPTIVE   = 82,  // 82 Adaptive (stub)
REC_AGGRESSIVE = 83   // 83 Aggressive (stub, gated)
```

`ea_template/core/Recovery.mqh` — `Recovery_AddLot()`:
- **82 REC_ADAPTIVE** (บรรทัด 46-64): `mult = 1.0 + (basketDD / ddRef)` clamp ด้วย `RC_RecMultMax` → lot ปรับตาม basket DD จริง ไม่ใช่ค่าคงที่
- **83 REC_AGGRESSIVE** (บรรทัด 66-75): `lot = baseLot * MathPow(m, rstep)` clamp ด้วย `RC_RecMultMax` → **นี่คือ geometric escalation ตัวจริง** (รูปแบบเดียวกับ martingale progression แต่มี cap)

ทั้งคู่ถูกเรียกจริงใน `Recovery_OnTick()` (บรรทัด 95-144) เมื่อ `RecoveryMode != REC_NONE` — ไม่มี early-return/TODO/`NotImplemented` ใดๆ กั้นไว้ ต่างจาก 80 (REC_NONE) ที่ early-return จริงตามคอมเมนต์ "(80: OFF path, identical to stub)"

## ข้อสรุป

**ป้าย "(stub)" / "(stub, gated)" ผิดข้อเท็จจริง — 82/83 ทำงานจริง ไม่ใช่โค้ดตาย** cage มีจริง (`RiskControl_MaxLevels`, `RC_RecMultMax`, `RiskControl_AllowNewOrder`, `RiskControl_ClampLot`) แต่การมี cage ≠ การไม่ทำงาน — นี่คือ **escalation engine ตามนิยาม ENGINE-EDGE class ใน VERDICT GATE** (`CLAUDE.md`) ที่ต้องผ่านกรง 5 ข้อก่อนใช้ตัดสินอะไร ไม่ใช่ปล่อยผ่านเพราะเข้าใจผิดว่าเป็น stub

**ความเสี่ยงที่เกิดจากป้ายผิด:** คนอ่าน dropdown ใน tester เห็น "(stub)" จะตั้ง `RecoveryMode=83` โดยเข้าใจว่าไม่มีผล ทั้งที่จริงเปิด geometric lot escalation ที่คูณด้วย `MathPow` — ถ้าทดสอบ/deploy โดยไม่รู้ตัว = เจอ risk จริงที่ไม่ได้ตั้งใจ

## เสนอ (ตัดสินใจแล้ว — แยกเป็น order ใหม่ให้แก้)

ป้ายต้องแก้จาก "(stub)"/"(stub, gated)" เป็นคำที่สื่อว่า **ทำงานจริง + มี cage** เช่น:
```
REC_ADAPTIVE   = 82,  // 82 Adaptive (DD-scaled lot, capped by RC_RecMultMax)
REC_AGGRESSIVE = 83   // 83 Aggressive (geometric MathPow escalation, capped by RC_RecMultMax)
```
เป็น **label/comment-only change** ไม่แตะ logic — safe additive แต่ยังต้องรัน `tpl_regression.ps1` ตามกฎ "แก้ core/ ต้องรัน regression" (แม้เป็น comment ก็อยู่ใน core/) → ติดตามที่ **ORDER-160**
