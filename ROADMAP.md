# ROADMAP — จากวันนี้ถึง "ระบบหมุนเอง" (เขียน 2026-07-03, Claude Fable ก่อนส่งไม้ Opus ·
# ครึ่งหลัง 5 ปี + Control Room + Prop/Monetize เพิ่ม 2026-07-19 โดย Opus+Codex, user approve)

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **ภาพสุดท้าย + เฟสงานระยะยาว + เงื่อนไขเลื่อนเฟส
> เท่านั้น** — สถานะปัจจุบัน/แผนรายสัปดาห์อยู่ PROJECT_STATE §7 · คิวงานจริงอยู่ AGENT_TASKBOARD.md
> อัปเดตไฟล์นี้เฉพาะเมื่อ "เฟสเปลี่ยน/เป้าเปลี่ยน" (Claude/user เท่านั้น)

**พารามิเตอร์จาก user (2026-07-03):** จบ = ระบบหมุนเอง user operate เบาๆ · 10 พอร์ต = 10 account
แยกจริง (10,000 cent/account) · ผ่าน judge แล้ว **live micro ทันที** · เวลา user 2–4 วัน/สัปดาห์

---

## 1. ภาพสุดท้าย (END STATE — นิยาม "จบ")

| ชิ้น | สภาพสุดท้าย |
|---|---|
| **Live** | 10 account × 2–3 EA ที่ corr ≤0.40 ระหว่างกัน × 10,000 cent → passive income · ทุก EA มี kill-switch + judge date ของตัวเอง |
| **EA_LAB** | โรงงานหมุนเป็น loop มาตรฐาน: ไอเดีย → mold → smoke+probe → IS/OOS+MC → demo ≥3 เดือน → live → monitor รายเดือน → kill/promote · ทุกขั้นมี script+cage, งานรันทั้งหมดอยู่บน taskboard ให้ Codex/ZCode |
| **EA_Template (Boss V2)** | แม่พิมพ์เดียวของโรงงาน: entry library โตเรื่อยๆ (14, 15, ...) · mechanics ครบและ**ผ่าน backtest แล้ว** (grid/DCA/LOG/hedge/recovery) · ทุกการแก้ core ผ่าน tpl_regression |
| **EA_CORE** | คลังอะไหล่ถาวร — หยิบ module เมื่อต้องการ (ตัวแรกที่คาดว่าจะถูกหยิบ: ScaleExecutor_v2 → Stack mode "pyramid") · ไม่พัฒนาเป็น chassis แข่ง |
| **EA_Project\TEMPLATE** | ที่อยู่ standalone legacy — ของใหม่ทุกตัวเกิดในแม่พิมพ์ ไม่มี standalone ใหม่ถาวร |
| **User** | operate: อ่านรายงาน monitor + ตัดสิน kill/promote + เติม order ใหญ่ — เป้าช่วง cruise ≤ 1 วัน/สัปดาห์ |

**ตัวชี้วัดว่า "ถึงแล้ว":** เปิดพอร์ตใหม่ 1 พอร์ตใช้แรง user แค่ "อนุมัติ + โอนเงิน" — ที่เหลือระบบ+AI ทำ

### 1.5 ภาพ 5 ปี (2031) — Final product เหนือ END STATE (เคาะ 2026-07-19: user + Opus + Codex)

**Final product ≠ คลัง EA — คือ "EA Portfolio OS + track record ที่ตรวจสอบได้"** โรงงาน/แม่พิมพ์เป็นแค่
ห้องเครื่อง เงินเข้า 3 ท่อตาม North Star ใน VISION.md:

| ท่อ | เพดาน | เงื่อนไขเปิด |
|---|---|---|
| 1. พอร์ตทุนตัวเอง (END STATE ข้างบน) | ทุนตัวเอง — เล็กสุด | กำลังทำ = ปีแรกของแผน |
| 2. **Prop firm** (edge เดิม ทุน ×50–100) | กติกา firm + จำนวน account | **gate: พอร์ต #1 live รอด 3 เดือน (~ม.ค. 2027)** → Phase 5 |
| 3. Copy-trading / signals | distribution | verified track ≥2 ปี → Phase 6 |

- **Control Room (Phase 4.5) ทำหน้าที่คู่:** ห้องควบคุมของเรา + **evidence pack ที่ prop/copier จ่ายเงินซื้อ**
  (attestation · วินัย kill ตรวจสอบได้ · drift log) — สร้างครั้งเดียวได้สองหน้าที่
- **North-star metric:** "จำนวนสัปดาห์ที่ระบบเดินถูกต้อง โดยใช้เวลา user น้อย และ risk รวมอยู่ในกรอบ"
  — ไม่ใช่จำนวน EA
- **สัดส่วนงาน (ยาแก้ตัน "ใส่ไอเดีย EA ไม่จบ"):** 50% operate/observe · 25% evidence/promotion integrity ·
  15% portfolio construction · 10% EA idea ใหม่ (เลน intake = งาน agent — ดูกติกากวาด v2 ใน §2.5) ·
  **denominator = lead-attention hours (rolling 4 สัปดาห์) — compute/agent runtime ไม่นับในสัดส่วนนี้**
- ที่มา: `_triage/_archive/codex_reviews/system_and_roadmap/CODEX_5YR_OS_VISION_2026-07-19.md` + `_triage/_archive/codex_reviews/system_and_roadmap/CODEX_CONTROLROOM_DESIGN_2026-07-19.md`
  (Opus สังเคราะห์ — ส่วนที่เพิ่มจาก Codex: ท่อ 2/3 ฝั่งรายได้ ซึ่งแผน Codex จบแค่ OS บนทุน cent)

---

## 2. เฟสงาน (เงื่อนไขเลื่อนเฟส = gate จริง ไม่ใช่วันที่)

> ⚠️ **HISTORICAL SNAPSHOT — superseded.** Phase 0/1 ด้านล่างเขียนไว้ 2026-07-03 และค้างสถานะ "operate 9 EA" — สถานะปัจจุบันจริงดู `PROJECT_STATE.md` (รวม decision log + forward plan §7).

### Phase 0 — ปิด Fable window (ตอนนี้ → 7 ก.ค.) ✅ เกือบครบ
- [x] VISION / AGENTS / TASKBOARD / regression cage / Boss_14 + candidates / กฎ verdict ครบ 3 ข้อ
- [ ] Codex/ZCode เคลียร์ ORDER-001..003 (GBPAUD IS-opt, probe 3 symbol, MC)
- [ ] Claude (Fable หรือ Opus) review + verdict รอบแรกจาก taskboard
- **Gate → Phase 1:** taskboard loop หมุนครบ 1 รอบ (order → done → reviewed) โดยไม่มีของพัง

### Phase 1 — Boss_14 family validation (ก.ค.)
- GBPAUD: plateau-center จาก IS-opt → OOS confirm → MC → `robustness-validator` → ถ้าผ่าน = **deploy demo** (magic ใหม่ 9902xx, WATCH tier)
- EURJPY / EURCAD / USDJPY / AUDNZD: ทางเดียวกันทีละตัว (ZCode รัน, Claude ตัดสิน)
- corr matrix ภายใน family (`_mt5_auto/corr_monthly.py`) — ระวัง AUD-heavy ซ้อน exposure กับ 9 EA เดิม
- probe ที่เหลือ 9 symbol PARKED (ถูกมาก ~15 นาที/ตัว) — ปิดทะเบียนให้ครบ
- **Gate → Phase 2:** ทุก candidate มี verdict สุดท้าย + ตัวที่ผ่านขึ้น demo แล้ว

### Phase 2 — Mechanism expansion + operate (ส.ค. → judge)
- **Validate Hedge/Recovery ที่ยังไม่เคย backtest:** A/B order — EA เดิม + เปิดโหมดทีละตัว (81/82/83, HEDGE_LOCK) เทียบ PF/DD กับ baseline → โหมดไหนช่วยจริงถึงเข้า production set ได้
- **Sweep แกนใหม่:** SELL-side GridLog (optimizer เห็นสัญญาณ PF สูงแต่บาง) · Boss_11/12/13 entries × mechanics ใหม่ × symbol ที่ยังไม่แตะ — ทุกรอบใช้สูตร: set 0.25x + year-split + probe-before-kill
- ~~port `ScaleExecutor_v2` จาก EA_CORE เป็น Stack mode~~ ✅ **ทำแล้ว 2026-07-06 (MERGE-03: `STACK_PYRAMID(93)`)** — เหลือแค่ "ใช้เมื่อมี signal ที่ต้องการ pyramid จริง" (โหมดปิดอยู่ default)
- **Operate 9 EA:** `/ea-monitor` ทุก 2 สัปดาห์ (user ส่ง live_deals.csv) — จับตา ST03 replica (คาด kill), MG grid DD, Gold Reaper
- **Gate → Phase 3:** ถึงวัน judge + มี candidate bench ≥3 ตัวที่ demo อยู่

### Phase 3 — Judge + พอร์ตจริงแรก (22 ก.ย. → ต.ค.)
- attribution per (magic,symbol) → kill/keep 9 EA เดิม · ตัวผ่าน (PF≥1.40, ≥30 trades) = promote pool
- **ประกอบพอร์ต #1:** 2–3 EA ดีสุดที่ corr ≤0.40 (`portfolio-selector`) → **live micro account จริงทันที** (ตาม user decision) → `live-deployment-controller` + `vps-deploy-ops` เต็มรูป
- demo account เดิม = โรงเพาะ cohort ถัดไป (EA ใหม่ทุกตัวยังต้อง demo ≥3 เดือนก่อน live — กฎเหล็กไม่เปลี่ยน)
- ตั้ง **ปฏิทิน re-opt ทุก 6 เดือน** ของทุก EA live (เริ่มนับจากวัน live ของแต่ละตัว) — ใส่ MASTER_BACKLOG
- **Gate → Phase 4:** พอร์ต #1 live ครบเดือนแรกโดย monitor loop ทำงานจริง

### Phase 3.5 — PORTFOLIO-QUANT track (หลัง judge — user เคาะทิศ 2026-07-06)

> **ทิศที่ตกลง: ไม่ไล่เป็น "quant firm" (tick infra / low-latency / ML alpha = ไม่คุ้มที่สเกลทุนเรา) —
> ไล่เป็น "quant method": พอร์ตที่บริหาร risk เชิงระบบ.**
> **✅ design เสร็จล่วงหน้าแล้ว (Fable 2026-07-06): บอร์ด `AGENT_TASKBOARD_PQUANT.md` (🔒 LOCKED
> ถึงหลัง judge — สูตร/เกณฑ์/acceptance ตรึงครบ เหลือ execute) · วันตัดสิน → `docs/JUDGE_DAY_RUNBOOK.md`**

1. 🥇 **Portfolio risk layer** — vol-target sizing ต่อ EA + DD budget ระดับพอร์ต (ต่อยอดอิฐที่มีแล้ว:
   `RC_AcctDDLimitPct` + `Persist.mqh` + `corr_monthly.py`) — เปลี่ยนจาก "มี EA หลายตัว" เป็น
   "บริหารพอร์ตเชิงระบบ"
2. 🥈 **Deflated gate (multiple-testing discipline)** — จดจำนวน hypothesis ที่ทดสอบต่อรอบ (mass-smoke
   1,521 ตัว = ตัวอย่างจริง) → ปรับเกณฑ์ผ่านให้โหดขึ้นตามจำนวนที่ลอง · เข้า `SYSTEM_METRICS.md`
3. 🥈 **Live tracking-error bands** — ต่อ EA: live เพี้ยนจาก backtest expectation เกินเกณฑ์ตัวเลข =
   probation/kill (เสริม `/ea-monitor` ที่มีอยู่ ให้เกณฑ์เป็นเลขไม่ใช่ดุลยพินิจ)
- **เงื่อนไขเริ่ม:** หลัง judge 2026-09-22 + พอร์ต #1 live แล้ว (อย่าแทรกก่อน — demo 3 เดือน =
  experiment ที่แพงสุดที่กำลังรัน ห้ามรบกวน)

### Phase 4.5 — CONTROL ROOM (เลนขนาน · CR-001+ เริ่มได้ก่อน judge — เป็นงาน ops/evidence ตรงกับ FIX-THEN-SCALE)

> design เต็ม = `_triage/_archive/codex_reviews/system_and_roadmap/CODEX_CONTROLROOM_DESIGN_2026-07-19.md` (Codex เขียน · Opus adopt · user approve
> 2026-07-19) · หลักการ: **EA = เซนเซอร์/ผู้ปฏิบัติ · Control Room = ความจริงกลาง (`ControlRoomSnapshot`
> ก้อนเดียว) · AI = ที่ปรึกษา · user = ผู้อนุมัติเงิน** · อำนาจ AI ไต่ทีละขั้น L0 observe → L1 recommend →
> L2 safe-ops → L3 pre-approved risk-reduction · **L4 (money decision) = human approval เสมอ แม้ปีที่ 5**

| ขั้น | ของ | ระยะ | gate ผ่าน |
|---|---|---|---|
| **CR-000** | ปิด ORDER-138 #1–3 ก่อนทุกอย่าง (= blocker เดิมที่มีอยู่แล้ว) | — | **code-ready** (blocker ฝั่ง code ปลด) — rollout จริงยังต้องรอ user เดิน `ea_template/PERSIST_MIGRATION_ORDER132.md` แยกอีกขั้น |
| **CR-001** | `ControlRoomSnapshot` schema + generate cohort map จาก `DEPLOYMENTS.csv` (ถอด `$cohort` hardcode ใน live_dashboard.ps1) — ยังไม่มี AI | 1–2 สัปดาห์ | คำสั่งเดียวได้ภาพระบบครบก้อนเดียว + โชว์ field ที่ missing/UNVERIFIED |
| **CR-002** | Attestation + sensor coverage: exporter ครบทุก account · binary/set hash · hedging/netting mode · server-side SL จริงไหม · unknown-magic detection · judge rule/date ครบทุก deployment · backup/restore drill จริง 1 รอบ | 2–4 สัปดาห์ | ของที่รันจริงตรงทะเบียน 100% · UNVERIFIED = 0 · กู้ระบบกลับได้ · **+ promotion-evidence reconstruction พิสูจน์จริง 1 candidate** (reuse evidence-manifest จาก Contract D: source/report/window/hypothesis lineage) |
| **CR-003** | Deterministic health engine: สถานะ NORMAL/WATCH/PROBATION/QUARANTINE/DATA_INSUFFICIENT/CONFIG_DRIFT (**แยกจาก verdict** — DEMO ที่ health=WATCH ได้โดยไม่แตะ verdict) + action queue + replay test จาก snapshot เก่า — กฎล้วน ยังไม่ใช้ AI ตัดสิน · **ขอบเขต = system/config/stale drift เท่านั้น** (behavioral drift → CR-005) | 3–5 สัปดาห์ | จับ injected/replay fixture ได้ 100% · จับ drift จริง ≥1 เคส · false-alarm ≤1 ครั้ง/สัปดาห์ ช่วง shadow 30 วัน |
| **CR-004** | TODAY screen + AI advisor V1: อ่าน Snapshot+Findings เท่านั้น (เลิกให้ AI ประกอบภาพจากไฟล์กระจัดกระจายเอง) · ทุกคำแนะนำ format เดียว FACT/INTERPRET/ACTION/EVIDENCE/CONFIDENCE/APPROVAL · AI ร่าง order ได้ ห้ามเขียน verdict | 2–3 สัปดาห์ | user เปิดใช้เป็นผู้ช่วยงานเช้าจริง |
| **CR-005** | Drift & judge-readiness engine: locked expected profile ต่อ EA (trade-rate/PF band/holding/slippage/MAE-MFE) + **decision-capable vs data-collection forecast** — ปิด blind spot "judge-date ≠ sample พอตัดสิน" (Codex จับ 2026-07-19) · shadow alert 30 วัน · **บทบาท = เตือน/เลื่อน/probation เท่านั้น — promotion bar ใน CLAUDE.md VERDICT GATE (demo ≥3 เดือน · PF≥1.40 · ≥30 trades) ไม่เปลี่ยน** | 1–2 เดือน | รู้ก่อนครบ 3 เดือนว่า EA ไหนกำลังเพี้ยน (แต่ตัดสิน promote ตาม bar เดิมเสมอ) |
| **CR-006** | Portfolio control (**ควบ Phase 3.5 เดิม** — ไม่ทำซ้ำ): risk contribution · DD-overlap ช่วง stress · currency/mechanism exposure · what-if shock sim · allocation recommendation · circuit breaker แบบ shadow | หลัง CR-001–005 นิ่ง **AND หลัง judge + พอร์ต #1 live** (คง lock ตาม decision 2026-07-06 — ห้ามแทรกก่อน) | จาก "กอง EA" เป็นพอร์ตจริง · crosswalk Phase 3.5: tracking bands→CR-005 · portfolio risk→CR-006 · deflated gate→CR-005 |
| **CR-007** | Semi-autonomous ops (ปี 2+): retry/repair exporter · incident timeline อัตโนมัติ · Telegram action queue · pre-approved risk-reduction (L3) · governance report ราย เดือน/ไตรมาส · **dependency จริงต้องปิดก่อน:** credential-expiry alarm (บทเรียน gh token ORDER-128) · reboot/restore recovery · expired-token simulation | ปี 2 | **14-day unattended soak test ผ่าน** (ไม่มี manual intervention + zero unapproved money action) |

**tech (local-first — ห้ามสร้าง cloud platform):** CSV เดิม = raw evidence · SQLite 1 ไฟล์ =
**rebuildable read-model/cache** (สร้างใหม่จาก raw ได้เสมอ — ไม่ใช่ owner ใหม่) · Snapshot JSON =
**read-only projection** (มี source-hash + as-of timestamp) · **ห้าม write-back เข้า owner จริง** —
`DEPLOYMENTS.csv`/scorecard/PROJECT_STATE/event-log ยังเป็น owner ตาม anti-drift PROJECT_STATE §0.5 ·
**ห้ามสร้าง script สิบตัวต่างคนต่างอ่าน CSV — ทุกอย่างเรียก `Control Room Core` interface เดียว**
(`Refresh→Evaluate→Propose→Execute(approved)`)

**จังหวะจริง (Codex จับ: CR-001..005 serial = 12–22 สัปดาห์ → เสร็จ ~ต.ค.–ธ.ค. 2026 ชน judge
2026-10-09/16 พอดี):** ทำ **vertical slice ก่อน** — CR-001 → CR-002 เฉพาะ cohort ที่จะ judge →
minimal judge-readiness (ชิ้นเล็กของ CR-005: trade-count forecast + decision-capable flag) ให้ทัน
judge ต.ค. · CR-003/004 เต็มรูปตามหลัง — ห้ามไล่ทำ CR ครบสวยงามแล้วพลาดวัน judge

### Phase 4 — Scale ทีละพอร์ต (Q4 2026 → 2027+)
- **กฎเปิดพอร์ตใหม่:** เปิดได้เมื่อ bench มี 2–3 EA validated + demo-proven + corr ≤0.40 กับ*ทุกพอร์ตที่ live อยู่* — ห้ามเปิดเพราะ "อยากครบ 10" (พอร์ตคุณภาพต่ำ = ลาก DD รวม) · **hard prerequisite เพิ่ม 2026-07-19 (Codex BLOCKER — บังคับ FIX-THEN-SCALE จริง): account ใหม่ทุกใบต้องผ่าน CR-002 attestation + restore drill + telemetry ครบก่อนเติมเงิน**
- จังหวะที่คาดหวัง: พอร์ตใหม่ ~ทุก 1–2 เดือนถ้าโรงงานผลิต candidate ทัน → 10 พอร์ตราว กลาง–ปลาย 2027 (ขึ้นกับ edge จริง ไม่ใช่ความขยัน — อย่า force)
- ทุนต่อพอร์ต = user เติม 10,000 cent ต่อ account ตอนเปิด · risk รวมทุกพอร์ต = ไม่มี EA ซ้ำ symbol+กลไกข้ามพอร์ตแบบ corr สูง
- automation เพิ่มตามจำเป็น: monthly report รวมทุก account, MT5 instance ที่ 2 (D:\Meta 5b) เมื่อคิว backtest แน่น

### Phase 5 — PROP TRACK: ตัวคูณทุน (gate เปิด: พอร์ต #1 live รอด 3 เดือน ~ม.ค. 2027 — VISION North Star ข้อ 2)

- **นิยาม gate (ตัวเลข — Codex จับว่า "รอด 3 เดือน" เดิมกำกวม):** นับจากวัน live จริงของพอร์ต #1
  +90 วัน · ≥30 trades รวมพอร์ต · ไม่มี pre-registered kill trip · CR-002 evidence bundle ครบ —
  ครบทั้ง 4 ข้อ = gate เปิด
- **ก่อน gate (Q4 2026):** research prop firm ที่กติกาเข้ากับ DD profile ของ EA เรา (daily-DD/max-DD
  limit · news rule · EA/grid อนุญาตไหม · payout structure) — **ข้อยกเว้นแบบจำกัดต่อ VISION
  "ห้ามเบี่ยงงานก่อน gate": ≤4 ชม./เดือน · delegate ให้ agent/skill `skeptical-research` ทำ ไม่ใช่งานมือ
  user · ห้ามจ่ายเงินทุกกรณี — เกินกรอบนี้ = รอ gate** (user approve exception 2026-07-19)
- **หลัง gate:** เลือก 1 firm → เช็คกติกา firm รอบสุดท้ายก่อนจ่ายเงินเสมอ (กติกา prop เปลี่ยนบ่อย) →
  challenge ด้วย cohort ที่**พิสูจน์บนเงินจริงแล้ว + telemetry CR ≥30 วันเท่านั้น** (ห้ามเอา demo-tier
  ไปเสี่ยงค่า challenge) → payout แรก = พิสูจน์ท่อ 2 → ขยายทีละ firm แบบเดียวกับขยายพอร์ต (bench-gated
  ไม่ใช่ตามวันที่/ความอยาก)
- **Control Room evidence pack = ใบเบิกทาง** — สิ่งที่ prop challenge ต้องการ (คุม DD เชิงโครงสร้าง +
  วินัยพิสูจน์ได้) คือสิ่งที่ระบบนี้สร้างอยู่แล้ว · CR-002 attestation + CR-005 drift log = หลักฐานพร้อมโชว์

### Phase 6 — MONETIZE TRACK RECORD (2028+ · เงื่อนไข: verified track ≥2 ปี)

- **นิยาม "verified track ≥2 ปี" (เกณฑ์ตั้งต้น — ปรับได้ตอนเปิดเฟสโดย user):** ต่อเนื่อง ไม่มี gap
  >2 สัปดาห์ · บัญชี live จริง (demo ไม่นับ) · ≥300 trades รวม · verified โดย platform ภายนอก
  (Myfxbook/MQL5) ไม่ใช่ report ตัวเอง
- Myfxbook/MQL5 signal สะสมต่อเนื่อง (เริ่มแล้ว 2026-07) → เปิด copy-trading/signal เมื่อ track ครบเงื่อนไข
- ของที่ขายจริงคือ **วินัย + หลักฐานตรวจสอบได้** ไม่ใช่คำโฆษณา PF — governance report จาก CR-007 = ของโชว์
- ห้ามเบี่ยงเวลา operate ไปทำ marketing ก่อนเงื่อนไขครบ — ท่อ 3 เป็นผลพลอยได้ของการทำท่อ 1–2 ให้ดี ไม่ใช่โปรเจกต์แยก

### Cruise state (ตลอดไป)
รอบเดือน: monitor ทุกพอร์ต → kill/promote → re-opt ตามปฏิทิน → โรงงานหา edge เติม bench ต่อเนื่อง (dual-track ตาม VISION) · user ≤1 วัน/สัปดาห์

---

## 2.5) HUNT QUEUE ถาวร — แหล่งไอเดีย EA ใหม่ เรียงตามลำดับขุด (ยืนยันโดย user 2026-07-04:
"หาไอเดียใหม่ทำเพิ่มเรื่อยๆ = แผนยาวของเรา" — ตรง dual-track ใน VISION)

| ลำดับ | เหมือง | ของที่มีรอแล้ว | วิธีเข้า pipeline |
|---|---|---|---|
| 1 | **แกนกลไกที่ยังไม่ sweep ในแม่พิมพ์เอง** | SELL-side GridLog เต็มรูป (EURUSD SELL ผ่านแล้ว = มีสัญญาณ!) · Boss_11/12/13 entries × mechanics ใหม่ · Hedge/Recovery A/B บน config ที่ชนะ | ถูกสุด — sweep สูตรเดิม (probe→OOS→M4) |
| 2 | **Treasure trove (คัดแล้ว)** | source 20 ตัว (momentum 13 + breakout 7 จาก `_triage/ea_src_triage.csv`) + novelty list | Claude อ่าน → กลไกน่าสนใจ = เข้าแม่พิมพ์แบบ Zeus→Boss_14 |
| 3 | **PDF strategy books** | 49 เล่ม (worth_deep_read 67 จาก `_triage/pdf_catalog.csv`) + STRATEGY_200 ที่เหลือ (#94 Turtle ฯลฯ) | อ่านสกัดกฎ → เขียน entry ใหม่ในแม่พิมพ์ |
| 4 | **ของใหม่จากกลุ่ม LINE/Telegram** | user โยนไฟล์ลง `D:\Forex\10_EA_PROJECTS\2. wait for test` ได้เรื่อยๆ | รัน `ea_inventory.py` ซ้ำ → เข้าคิว triage อัตโนมัติ |

**กติกากวาด v2 (2026-07-19 — user ยืนยัน "กวาดไปก่อน ยิ่งเยอะยิ่งมีเวลาพิสูจน์" + Opus/Codex reconcile —
supersede กติกา ~1 concept/สัปดาห์เดิม):**
- **backlog ไม่จำกัด แต่ execution มี cap:** ขนาดคิว/คลังไอเดีย = ไม่จำกัด · การรันจริงเคารพ pacing rule
  เดิม (**1–2 order/รอบ กระจายหลายวัน** — memory `feedback-pacing-batch-small`) + tester ต้องว่าง
  (กัน 0-trade artifact จาก sweep ชนกัน) · เลนรัน = agent ถูก (qwen / corpus-intake / ea-screener)
- **ขอบเขตเลน agent (กฎ AGENTS.md §3.9 external-input ยังคุม):** agent ทำได้เฉพาะ mechanical
  screening ของ artifact ที่เข้าคลัง/ผ่าน filter แล้ว — **ของใหม่จากแหล่งภายนอก (ไฟล์กลุ่ม LINE/TG ·
  PDF · EA แปลกหน้า) ต้องผ่าน Claude/Codex filter ก่อนเข้าเลน agent เสมอ**
- **เวลา lead:** จ่ายเฉพาะตอนเขียน order + review ผลตามรอบ (อยู่ในโควตา 10% ของสัดส่วนงาน §1.5) —
  ระหว่างรันไม่มี discretionary lead time
- **บันไดสถานะ (automation ห้ามออก verdict):** `INTAKE_RAW → SMOKE_SURVIVOR → VALIDATION_WIP →
  VALIDATED_BENCH` — automation เลื่อนได้ถึง SMOKE_SURVIVOR เท่านั้น · verdict ทุกชนิด (รวม DEAD)
  = Claude/user ตาม VERDICT GATE ใน CLAUDE.md เสมอ
- **WIP limit ย้ายไปคุมชั้นแพงแทน:** validate พร้อมกัน ≤3 concept · เข้า validation ≤1 concept/สัปดาห์ ·
  demo slot จำกัดตามปฏิทิน judge (คอขวดจริง = ปฏิทิน ไม่ใช่ไอเดีย — demo 3 เดือน/ตัว เร่งไม่ได้)
- **บัตรผ่านเข้า validation:** ต้องตอบก่อนว่า "เติม payoff shape อะไรที่พอร์ตยังไม่มี" — ตอบได้แค่
  "PF อาจสูง" = อยู่ bench ต่อ · **payoff-shape = เกณฑ์จัดลำดับที่ซ้อนบน bar ปกติของ VERDICT GATE
  (smoke PF≥1.2 ฯลฯ) ไม่ใช่แทน** · หลัง bench แน่น (≥2 validated ต่อ slot-type) เปลี่ยนเป็นกวาดตาม
  ช่องว่างพอร์ต (เช่น พอร์ต XAU-trend หนัก ขาด relative-value → pairs/stat-arb มาก่อน breakout ตัวใหม่)
- funnel จริงจากข้อมูลเรา: 21 symbols → 6 demo · 50 MT4 EA → 0 · 1,318 sweep → 1 finding —
  คาดหวังจากเหมือง = "กลไก" ไม่ใช่ "EA สำเร็จรูป" · ทุก concept ตายบันทึกใน scorecard เสมอ (กัน re-hunt)

## 3. Development backlog ของระบบ (delegate ได้ — Claude เขียนเป็น order เมื่อถึงคิว)

| งาน | เฟส | มอบใคร |
|---|---|---|
| **`_2_BasketTP_ATRmult`** — basket TP แบบ ATR-scaled (additive, default 0=$ เดิม) — จาก self-review 2026-07-04: $-TP ไม่ scale ข้าม instrument class · **ทำก่อน sweep non-FX ครั้งแรกเสมอ** · validate ด้วย ab_mode_test เทียบ $TP vs ATR-TP · lot% มีแล้ว (mode 42) ไม่ต้องสร้าง | ก่อน sweep metals/index | oc-dev + regression cage |
| Walk-forward automation (script รัน rolling window + สรุป) | 1 | Codex |
| Hedge/Recovery A/B validation harness | 2 | Codex ออกแบบ order, ZCode รัน |
| Portfolio equity combiner หลาย account (ต่อยอด zigl_correlation) | 3 | Codex |
| **Portfolio risk layer** (vol-target sizing + พอร์ต DD budget — Phase 3.5 ข้อ 1) | 3.5 | Claude ออกแบบ (risk logic ใหม่) + Codex review |
| **Deflated gate** — เกณฑ์ผ่านปรับตามจำนวน hypothesis ที่ทดสอบ (Phase 3.5 ข้อ 2) | 3.5 | Claude (rule) — แทบไม่มีโค้ด |
| **Tracking-error bands ใน /ea-monitor** (Phase 3.5 ข้อ 3) | 3.5 | Codex |
| Monthly monitor report รวมทุกพอร์ต (อ่าน live_deals หลายไฟล์) | 3–4 | Codex |
| MT5 instance 2 (D:\Meta 5b) เข้า pipeline เมื่อคิวแน่น | 4 | ZCode ตาม guide memory |
| เกษียณเอกสารซ้ำซ้อน (audit ตาม anti-drift) | ว่างเมื่อไหร่ก็ได้ | Claude |

## 4. ความเสี่ยงหลัก + กันไว้แล้วยังไง

- **Edge ผลิตไม่ทันความอยากขยาย** → gate เปิดพอร์ตผูกกับ bench ไม่ใช่วันที่
- **AUD-heavy concentration** (Boss_14 family เกิดจาก AUD) → corr gate ข้ามพอร์ต + บังคับกระจายกลไก/สกุล
- **Agent อื่นทำพัง** → single-writer + cage + review-before-build (AGENTS.md)
- **Model เปลี่ยน (Fable→Opus ✅ ACTIVE 2026-07-04, เร็วกว่าแผน 07-07)** → ความรู้ทั้งหมดอยู่ในไฟล์+memory ไม่อยู่ในหัว model · seat=Opus · workflow ทีมรื้อใหม่ (Codex=สมองอิสระตัวเดียวที่เหลือ, batch เลี่ยง ChatGPT quota) · ดู `AGENTS.md` §1.5+§5 · `CLAUDE.md` §Model transition
- **ChatGPT quota หมดเร็ว (Codex+oc-dev+oc-btest แชร์ก้อนเดียว)** → batch run โยนไป qwen/ZCode(GLM แยก) · oc-btest model ถูกสุด · ห้ามรัน Codex Desktop + OpenClaw หนักพร้อมกัน
- **Regime เปลี่ยนหลัง validate** → backward-OOS บังคับ + re-opt 6 เดือน + demo ≥3 เดือนทุกตัว
