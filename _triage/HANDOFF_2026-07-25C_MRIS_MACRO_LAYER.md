# HANDOFF 2026-07-25C — MRIS macro layer: crisis models, alert lane, fold (switch OFF)

> Session owner: Fable-seat. **13 commits ที่ขึ้นต้น `[claude]`** ระหว่าง `6e806b85` → `a721efd1`
> (ช่วงนั้นมี 33 commit รวมของ session อื่นที่แทรก — หาด้วย `git log --grep='\[claude\]' 6e806b85^..`).
> ⚠️ **commit ปิดงาน (PROJECT_STATE + taskboard + handoff นี้) ไม่ได้อยู่ในช่วงนั้น** — มันถูก index race
> กวาดเข้า commit ของ session คู่ขนาน **`0c967e9a`** (ตรวจแล้วเนื้อหาลงครบทั้ง 3 ไฟล์, attribution ปนกัน
> เท่านั้น). แถว B1 ของ ORDER-200/203 ตามมาทีหลังอีกก้อน.
> Order rows: **ORDER-200** (macro extension, REVIEWED) · **ORDER-203** (core pin defect — fix ลงโดย
> session คู่ขนาน `265de0e3`, ผม verify แล้ว).
> ⚠️ session คู่ขนาน active วันเดียวกัน (genetic policy `b9ba8c84`, ORDER-202 holdout leak,
> ORDER-204) — **เช็ค `git log` ก่อนต่อ** และ commit แบบ path-limited เสมอ (HEAD ขยับกลางการ commit
> ของผม 1 ครั้งจริง, retry ผ่าน).

## เริ่มมาจากอะไร
user ส่งเว็บ `bond-crisis-dashboard-v2.vercel.app` มาบอกว่าชอบไอเดีย (รวมข้อมูลมหภาคมาบอกว่าตลาดจะไปทางไหน
ลดล็อตตอนข่าวใหญ่) + กังวลว่าเว็บอาจหาย → อยากได้ของเราเองที่ใช้กำหนด strategy ได้ "user ดูนานๆ ที
แต่ AI ต้องใช้ประจำ".

## สิ่งที่มีตอนนี้ (ใช้งานได้จริง รันเองทุกวัน)
chain = `mris_run.ps1` 7 ขั้น (`daily_monitor.ps1` เรียกอยู่แล้ว):
`webfeed → macrofeed → classify → crisismodels → exposure → brief → alert`

| ชิ้น | ไฟล์ | สถานะ |
|---|---|---|
| 6 barometer ใหม่ (US2Y/WTI/SP500/MOVE/HY_OAS/YCURVE) + CREDITPX | `mris_macro_feeder.ps1` | 7/7 OK |
| 3 crisis model 0-100 (YIELD_SHOCK/CREDIT_STRESS/INFLATION_OIL) | `mris_crisis_models.ps1` + `crisis_models.json` | live, backtest 7/7 |
| replay + expectation check | `mris_crisis_backtest.ps1` | 7 passed / 0 failed / 0 skipped |
| delta-alert (เงียบจนมี transition จริง) | `mris_alert.ps1` | live |
| push เข้ามือถือ user (HIGH เท่านั้น) | `mris_notify.ps1` | **ตั้งค่าครบ ทดสอบส่งจริงผ่าน** |
| fold เข้า MacroGate | `mris_export_regime.ps1 -EnableCrisisFold` | **สวิตช์ปิด** |
| ตัววัดต้นทุนของ fold | `mris_fold_costcheck.ps1` | ใช้ได้ |

spec/หลักฐานเต็ม = `_triage/ORDER200_MRIS_MACRO_EXTENSION_SPEC.md` (อ่านไฟล์นั้นถ้าจะเดินต่อ)

## เลขที่ต้องรู้
- **backtest 7/7** — sensitivity (แต่ละโมเดลติดใน episode ของตัวเอง) **และ specificity** (เงียบใน
  episode ที่ไม่ใช่เรื่องของมัน). specificity คือด่านที่คุ้มค่าที่สุด: CREDIT_STRESS เคยติดผิด
  **67/125 วันใน inflation_2022** (rates event) → หลังเพิ่มแกน credit จริงเหลือ **0/125**.
- **ต้นทุนของ fold** (วัดบนหน้าต่างที่มี headroom เท่านั้น): calm_2017 **0/67** · precovid_2019q4
  **0/62** · calm_2021h1 8/59 (13.6%) · inflation_2022 27/106 · yield_spike_2023 19/63.
- **fold ไม่ช่วยตอนวิกฤตเต็มรูป** (core ยิงเองอยู่แล้ว) — คุณค่าอยู่ที่ **mid-regime** ที่ core มองไม่เห็น
  (yield_spike_2023: core บอก NEUTRAL ทั้ง 63 วัน) = ช่องว่างเดียวกับที่ user เห็นจากเว็บ.

## ORDER-203: บั๊กที่ทำให้ backtest ย้อนหลังของ core เพี้ยนทั้งชุด (แก้แล้ว)
`AUDJPY.user_pin = 110` เป็นราคาปี 2026 แต่ AUDJPY อยู่**ใต้ 110 มาตลอด 10 ปี** → เงื่อนไข
`spot < pin` จริงเสมอ → branch `-2` ทำงานแทน `-1` ทุกครั้งที่อยู่ใต้ SMA200 → weight 3 ⇒ −0.46 RI
เกินเส้น RISK_OFF ด้วยตัวเดียว. ปี 2019 risk-off **88% → 48%** เมื่อปิด pin (ขณะ VIX = +0.47 สงบ).
**fix ลงแล้ว** (`265de0e3`, session คู่ขนาน): pin = advisory (คุมแค่ flag), `-2` ต้องมี 2 เงื่อนไข
relative (below SMA200 **AND** fast drop). **ผม verify ครบ 3 ด่าน:**
1. live ไม่เปลี่ยน (NEUTRAL RI 0.308 ก่อน/หลัง)
2. core parity ตรง (live vs backtest port = NEUTRAL/0.308)
3. **concept check ของ ORDER-073 รอด และรอดด้วยเหตุผลถูกต้องแล้ว** — covid 55/65 วัน ·
   carry_unwind_2024 เริ่มเตือน **2024-07-17 = ก่อน**เหตุการณ์ต้น ส.ค. (MacroGate ยืนบนหลักฐานจริงแล้ว)

## สองข้อสรุปที่ "ตรวจแล้วไม่แก้" (อย่ารื้อโดยไม่มีหลักฐานใหม่)
1. **`USDJPY.extreme_weak_level = 158` เป็นบั๊กสายพันธุ์เดียวกัน แต่ปล่อยไว้** — เหนือ 158 แค่
   121/2603 วัน (ข้ามครั้งแรก 2024-04-28) → replay ก่อนปี 2024 ตาบอดต่อ crowded carry.
   **วัดทางเลือกแล้วไม่ช่วย**: relative +3% vs SMA200 ก็ยังติด streak ยาว **190 วัน** เพราะ carry
   แออัดเป็น**สภาวะยาว ไม่ใช่เหตุการณ์**. อาการจริง (ธงติดค้างแล้วเตือนซ้ำทุกวัน) แก้ที่ alert dedup แล้ว.
   **VALID ไม่ต้องแตะ:** VIX 15/20/30 · MOVE 70/140 · US10Y 3.5/5.0 · HY_OAS 3.0/6.0 (series พวกนี้
   bounded/mean-reverting ⇒ เลขระดับใช้ได้; บั๊กสายนี้กัดเฉพาะ**ราคาที่ไม่มีค่ากลาง** = คู่เงิน)
2. **"ยุบ crisis models เข้า core RI แล้วลบ fold" = ทดลองแล้วแย่ลง อย่าทำ** — เพิ่ม CREDITPX(w2)+
   MOVE(w1) เป็น barometer 9-10: yield_spike_2023 RISK_OFF **1 → 0** (แย่ลง), calm_2017 RISK_ON 25→18.
   เหตุ: ส.ค.-พ.ย. 2023 credit *ขึ้น* (rates event) → เกจใหม่ส่งสัญญาณบวกไป**เจือจาง**คำเตือน.
   **ค่าเฉลี่ยถ่วงน้ำหนักตรวจ "เงื่อนไขร่วม" ไม่ได้** ⇒ สองชั้นถูกต้องด้วยเหตุผลเชิงโครงสร้าง.

## ค้างไว้ (เรียงตามที่ควรทำ)
1. 🔴 **ห้าม flip `-EnableCrisisFold` ขึ้นบัญชีจริงจนกว่า Codex audit ผ่าน** — doctrine `AGENTS.md`
   §5.1. ส่งไป 2 ครั้งไม่สำเร็จ: (a) background job ดึงผลไม่ได้ (registry อยู่คนละ process —
   `status`/`result` ตอบ "No job found") (b) **user แจ้ง Codex quota = 0%**. ⇒ **ครั้งหน้ารัน
   synchronous** (`run_in_background: false`) ห้ามยิง background แล้วเดินจากไป. ตอนนี้ปลอดภัยเพราะ
   สวิตช์ปิด. คำสั่งเปิดเมื่อพร้อม = เติม `-EnableCrisisFold` ที่บรรทัด export-regime ใน
   `daily_monitor.ps1` (ที่เดียว)
2. ~~MacroGate demo baseline ก่อน judge~~ → **session คู่ขนานทำแล้ว = ORDER-211 (`fbfc0fbd`) และผลใหญ่
   กว่าที่ผมคาด: ถอด MacroGate จาก "VALIDATED deploy-candidate" → ADVISORY-ONLY** เพราะหลักฐานเดิม
   สร้างบน classifier ที่พัง. วัดใหม่ด้วย classifier ที่แก้แล้ว **PF แย่ลงทั้ง 4 ช่อง** (คำอ้างเดิม
   "P&L เสมอถึงดีขึ้น + DD ลดครึ่ง" ไม่เหลือ) · แต่แยกตาม symbol: **AUDJPY จับจังหวะจริง** (บล็อกไม้
   19-32% แต่ eqDD ลง 44-53% = ลดมากกว่าสัดส่วนที่บล็อก) ส่วน USDJPY แค่เทรดน้อยลง.
   **⚠️ ผลกระทบต่องานผม:** ปลายทางของ fold (MacroGate) **ตอนนี้ไม่ใช่ gate ที่ validated แล้ว** ⇒
   การเปิด fold ไม่ใช่แค่รอ Codex audit อีกต่อไป — ต้องรอให้ **ตัว gate เองมีหลักฐานใหม่ก่อน**
   ลำดับความสำคัญของการเปิดสวิตช์จึง **ลดลง** ไม่ใช่เพิ่ม. อ่าน ORDER-211 ให้ครบก่อนตัดสินใจอะไรกับ fold
3. **core layer ยังไวกว่าที่ควร** แม้แก้ pin แล้ว (2019 ยัง risk-off 48%) — ยังไม่ได้สอบว่าเป็นของจริง
   หรือมีอะไรอื่น = งานแยก ไม่เร่ง

## gotchas ที่เสียเวลาที่สุดใน session นี้
- **FRED ต้องใช้ `curl.exe`** — `Invoke-WebRequest` ไป `fred.stlouisfed.org` timeout (TLS proxy).
  และ `fredgraph.csv` cap ~3 ปีแม้ใส่ `&cosd=` ⇒ อยาก history ลึกให้ใช้ Yahoo-ETF proxy แทน
  (นี่คือที่มาของ CREDITPX = HYG/IEF)
- **ส่ง array เข้า `.ps1` ผ่าน `powershell -File -Windows a,b` จะแบนเป็นสตริงเดียว** ⇒ ใช้
  `-Command "& script -Windows @('a','b')"`
- **`$W` กับ `$w` คือตัวแปรเดียวกัน** (PowerShell ไม่แยกตัวพิมพ์) — ผมตั้ง hashtable น้ำหนักเป็น `$W`
  แล้ววนลูป `foreach($w in ...)` ลูปทับ hashtable ทิ้ง ได้ผลว่างทั้งชุด. repo เตือนกับดักนี้ไว้เองใน
  `mris_web_feeder.ps1` แล้ว
- **git commit heredoc (`git commit -F - <<'EOF'`) โดน guard สกัด** → เขียน message ลงไฟล์แล้ว `-F <file>`
- pre-commit hook กิน 2-5 นาที ⇒ ตั้ง timeout ≥5 นาทีทุก commit ที่แตะ `AGENT_TASKBOARD.md`

## บทเรียนกระบวนการ (สำคัญพอกับตัวงาน)
วันนี้ผม**เกือบสรุปผิด 2 ครั้ง จากบั๊กในเครื่องมือวิเคราะห์ของตัวเอง** ไม่ใช่ในระบบ: (1) พิมพ์ตาราง
attribution ก่อนหัวข้อ ทำให้อ่านสลับปี → เกือบสรุปว่า barometer ตัวผิดเป็นต้นเหตุ (2) กับดัก `$W`/`$w`
ด้านบน. **จับได้ทั้งสองครั้งเพราะตัวเลขขัดแย้งกันเอง** แล้วไปทดสอบ expression แยกทีละส่วน ไม่ใช่เพราะ
อ่านโค้ดเจอ ⇒ เวลาเลข 2 ทางไม่ตรงกัน ให้หยุดแล้วพิสูจน์ อย่าเลือกทางที่ดูเข้าท่ากว่า.
และ scrutinize pass ของตัวเองก็ผิดได้: ข้อเสนอ "ยุบสองชั้น" ของผมถูกหักล้างด้วยการวัด.

## memory ใหม่จาก session นี้
`bond-crisis-dashboard-replication` (อัปเดต) · `gate-specificity-not-just-sensitivity` ·
`absolute-price-constant-poisons-backtests` · `weighted-mean-cannot-express-conjunction` ·
`telegram-alert-lane-user-decisions`
