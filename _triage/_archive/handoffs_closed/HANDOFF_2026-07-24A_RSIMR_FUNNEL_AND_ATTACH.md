# HANDOFF — 2026-07-24A (session close)

## จบแล้ววันนี้ (commits `3242a91` → `05b0f3b`, 10 ก้อน — session ทั้งเซสชันไปกับ RSI-MR ตัวเดียวตามคำขอ user)

**เรื่องใหญ่: RSI-MR (990103) full re-optimize funnel (ORDER-182→186) + demo-isolate attach**

### 1. Methodology finding (สำคัญสุด, generalizable ไปที่ basket/grid EA อื่นด้วย)

ORDER-168 WFA เดิม (2026-07-23) วัด RSI-MR ด้วย 3 window แยกกัน (equity reset ทุก fold) — แต่ RSI-MR เป็น
**basket EA จริง** (dual-side, `MaxPositions=8`, LOG-lot escalation, `PositionsTotal()`/per-side basket TP
ใน source). Skill `backtest-optimize-rigor` เตือนไว้เป๊ะว่า stitched windows หลอกได้ ~10x สำหรับ
basket/grid EA (precedent เดิม: Zeus GridLog confluence-breakout 2026-07-08, PF 7.17/3.97/7.64 tiled →
0.583 continuous) — นี่คือ**เคสที่ 2** ยืนยัน pattern เดียวกัน, เข้า Decision Log เป็น rule ใหม่แล้ว
(`PROJECT_STATE.md` §3, 2026-07-24).

รัน continuous single-span ใหม่ (D:\Meta 5b กัน session คู่ขนานที่ใช้ D:\Meta 5) → **both-window PF เท่ากันเป๊ะ
1.37/1.37** — plateau จริง ดีกว่า WFA เดิมมาก (fold2-OOS 1.08 ของเดิม = artifact ของการ chop window ไม่ใช่
edge บาง).

### 2. Full funnel ผลลัพธ์

| step | ผล | order |
|---|---|---|
| continuity fix | MAIN 1.37/280t · BWD 1.37/267t (continuous, was 3-fold WFA) | ORDER-182 |
| flat-lot probe | MAIN 1.33 (entry มี edge จริง) · BWD 0.82 (ต้อง escalation ช่วยโหมด trend) — ไม่ใช่ ENGINE-EDGE เต็มรูป | ORDER-182 |
| basket-duration (v1) | max MAIN 159d / BWD 292d (~10 เดือน!) — DD% ไม่เห็น tail นี้ | ORDER-182 |
| lever 2/3: RSI band × SL width | plateau ใหม่ **RSI25/75+SL25+Dist9**: MAIN **1.96**/216t · BWD **1.56**/199t (ดีกว่าทุกมิติ) | ORDER-183 |
| sensitivity fan (±20%, รวม frozen DistAtrMult) | **8/8 variant ยัง PF>1 ทั้งคู่ ไม่มี flip ลบเลย** — สะอาดที่สุดของ session | ORDER-185 |
| full MC (5000 iter) | PF-5th **MAIN 1.544 / BWD 1.209** — ผ่าน comfortable ≥1.2 ทั้งคู่ (เดิม 1.116) | ORDER-186 |
| basket-duration (v2, config ใหม่) | max MAIN 98.4d / BWD 182.1d — ดีขึ้นเกือบครึ่ง | ORDER-183/186 |
| holdout 2026H1 | **0.76/n=21 — ล้มจริง** (baseline เดิม 0.73/n=26 ล้มเหมือนกัน — 2 config อิสระตกที่เดียวกัน = regime feature จริง ไม่ใช่ tuning bug) | ORDER-182/183 |

**lever ครบ 3/3** (spacing/entry-threshold/SL) + fan สะอาดที่สุด + MC ผ่าน comfortable — funnel ครบทุกด่านของ
VERDICT GATE 2c **ยกเว้น holdout เดียว**. Config แนะนำ = `_mt5_auto/ab_sets/rsimr_fan/RSIMR_CENTER.set`
(RSI25/75+SL25+Dist9) **แทนที่** baseline เดิม atr9/RSI30-70.

### 3. เจอระหว่างเตรียม deploy bundle — ประวัติ real-money ที่พลาดไปตอนแรก

RSI-MR **เคย live จริงบนบัญชี real 159503454** (Blazing Arrow) มาก่อน แล้ว**ถูกถอด 2026-07-18 เพราะโดน
DD25% kill trigger**. คำแนะนำแรกของผม (เทียบ RSI-MR กับ XAGUSD/LondonORB ที่ demo-isolate ไปแล้ววันเดียวกัน)
**ผิด** — XAGUSD/LondonORB holdout แค่บาง (≥1.0) แต่ RSI-MR holdout ล้มจริง (<1.0) คนละสถานการณ์ แก้ไขให้
user ทราบก่อนตัดสินใจ attach จริง.

### 4. Demo-isolate attach — เสร็จสมบูรณ์

user สั่ง "เข้าคิวขึ้นเดโม่เลย" → เพิ่มแถว `DEPLOYMENTS.csv` (463666728 "Demo bundle 10", EURUSDm,
PENDING_ATTACH) + bundle เต็ม `_vps_deploy/RSI_MR_EURUSD/` (.ex5 เดิมไม่แก้โค้ด + .set ใหม่ + README
ประวัติเต็ม + pre-attach checklist). **เจอ open item ระหว่างเตรียม: 463666728 margin mode (Hedge/Netting)
ไม่ยืนยันในเอกสาร — EA ต้องการ Hedging account มิฉะนั้น INIT_FAILED.**

user attach จริงสำเร็จ 2026-07-24 (ตอบคำถาม margin-mode โดยอ้อม — attach สำเร็จ = ต้องเป็น Hedging-mode
จริง) → status ยก **PENDING_ATTACH → ACTIVE**, `judge_date=2026-10-24` (+3mo).

## Decision Log ใหม่ (`PROJECT_STATE.md` §3, 2026-07-24)

1. **stitched-window WFA ห้ามใช้กับ basket/grid/multi-position EA** — ต้อง continuous single-span เสมอ
2. **RSI-MR demo-isolate = accepted แม้ holdout ล้มจริง** — user ตัดสินใจหลังรับทราบความเสี่ยงครบ (ไม่ใช่
   precedent อัตโนมัติให้ EA อื่นที่ holdout ล้ม — แต่ละเคสยังต้อง user เคาะเอง)

## บทเรียนกระบวนการ

- **pre-commit hook ช้าจริงเมื่อแตะ `AGENT_TASKBOARD.md` ใหญ่** — เจอ 2 ครั้งดูเหมือน hang (2-7 นาที) แต่
  พิสูจน์ด้วย process inspection ว่าเป็น hook ทำงานจริง (spawning `git show`/`git diff` ต่อเนื่อง) ไม่ใช่ stuck
  → **เช็ค `Get-CimInstance Win32_Process -Filter git.exe` ก่อนลบ `.git/index.lock` ทุกครั้ง** อย่ารีบ force
- **session คู่ขนานหนาแน่นมากตลอดวัน** (SS2 NyIgnition/LondonORB CANDIDATE/cent-scalp strategies ×5/
  portfolio_risk_admission ORDER-170 round 9-10 ปิดสำเร็จ/correlation backfill ORDER-184/magic
  enumeration 159475669) — commit หนึ่งของผม (DEPLOYMENTS.csv RSI-MR ACTIVE row) ถูก sweep เข้า commit
  ของ session อื่นไปเฉยๆ ผ่าน shared working tree (ไม่มีข้อมูลหาย, ตรวจด้วย `git show HEAD:<file>` ยืนยัน
  เนื้อหาถูกต้องเสมอก่อนสรุปว่า "หาย")
- **แก้คำแนะนำตัวเองต่อหน้า user เมื่อเจอข้อมูลใหม่** (RSI-MR real-money history) — ดีกว่าเดินหน้าตาม
  คำแนะนำเดิมที่อิงข้อมูลไม่ครบ

## ค้าง (ไม่เร่งด่วน)

1. **RSI-MR ไม่มีงาน optimize ค้าง** — funnel ครบทุกด่านแล้ว (lever 3/3 + fan + MC) จุดเดียวที่เหลือคือรอเวลา
   (holdout n เพิ่มเมื่อมีข้อมูล 2026H2) ไม่ใช่งาน optimize เพิ่ม → **hand off ให้ `ea-live-monitor`** ติดตาม
   ต่อจากนี้ (จำ: holdout ล้มจริงไม่ใช่แค่บาง อย่าตีความ losing streak แรกเป็นสัญญาณใหม่ — เข้าใจความเสี่ยงนี้
   ไว้แล้วตอนตัดสินใจ attach)
2. **basket-duration tail (98-182 วัน)** ควร monitor จริงผ่าน live tracking ไม่ใช่แค่ backtest — ยังไม่เคย
   เห็น worst-case จริงบน live data
3. **ORDER-170/174** (correlation/risk-admission) — เห็นจาก commit log ว่ามี session อื่นเดินต่อจนปิดแล้ว
   ระหว่างวัน (ORDER-170 CLOSED หลัง audit รอบ 10, ORDER-184 corr backfill 27/28 magic) — **ยังไม่ได้ตรวจ
   verdict/รายละเอียดเอง** ควรอ่านก่อนอ้างอิงในงานถัดไป
4. งานอื่นในคิว (ORDER-091 intake, ORDER-098 corpus) — ไม่ได้แตะเลยวันนี้ (เวลาไปกับ RSI-MR ทั้งหมดตาม
   คำขอ user)

## Gotcha สำหรับ session ถัดไป

- Config ที่ถูกต้องของ RSI-MR ตอนนี้คือ **RSI25/75+SL25+Dist9** (`RSIMR_CENTER.set`) — **ไม่ใช่** baseline
  เดิม atr9/RSI30-70 ที่เอกสารเก่าอ้างถึง อย่าสับสน 2 config นี้
- account 463666728 มี EA จำนวนมาก (12+ ตัวหลังใบนี้) — เช็ค portfolio DD budget รวม (ORDER-154/170 tool)
  ก่อน attach ตัวใหม่เพิ่ม ถ้าจะทำต่อ
