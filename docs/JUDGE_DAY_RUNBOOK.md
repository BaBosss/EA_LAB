# JUDGE DAY RUNBOOK — คู่มือวันตัดสิน (เขียนล่วงหน้าโดย Fable, 2026-07-06)

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **ขั้นตอน+เกณฑ์การ judge พอร์ต live/demo
> ทุกตัวเท่านั้น** — เขียนล่วงหน้าเพื่อให้ seat ใดก็ตาม (Opus/อนาคต) execute ได้ระดับ mechanical
> โดยไม่ต้องคิดเกณฑ์ใหม่วันงาน · เกณฑ์ทุกข้อตรึงจาก decision log ที่จ่ายราคาแล้ว — **แก้เกณฑ์ = ต้องมี
> ใบเสร็จใหม่ + user อนุมัติ** (แก้กลางทางเพราะ "ผลกำลังสวย/แย่" = การโกงที่ระบบนี้สร้างมากัน)

## 0. ปฏิทิน judge — **GENERATED, ห้ามเขียนวันด้วยมือในไฟล์นี้**

```bash
powershell -File scripts/control_room_snapshot.ps1
```
→ `portfolio/control_room_snapshot.json` section `judge_cohorts` = ปฏิทินจริง (derive จาก
`portfolio/DEPLOYMENTS.csv` ซึ่งเป็นเจ้าของข้อมูล deployment ตาม `PROJECT_STATE.md` §0.5)

> 🔴 **แก้ 2026-08-01 (`ORDER-940`) — ตารางเดิมในหัวข้อนี้ผิดทั้งแถวแรก.** มันเขียนว่า
> *"Live 9 EA · judge 2026-09-22"* แต่ **ไม่มีสักแถวใน `DEPLOYMENTS.csv` ที่ถือวันนั้น** และ cohort นั้น
> สลายไปแล้ว: `9397` ไม่มีในทะเบียน · `9398`/`990010` = `REMOVED` · ที่เหลืออยู่บัญชี `159475669`
> ซึ่ง annotate ว่า *"user mix - lab does not certify this account"* ⇒ `judge_date` **ว่างโดยตั้งใจ**
> ⇒ วัน judge แรกจริง = **2026-10-09**
> **ทำไมถึงลบตารางทิ้งแทนที่จะแก้วัน:** ตารางมือแบบนี้คือ cache ของ generated fact ที่ถูกอ่าน
> ตอนที่มันสำคัญที่สุดพอดี — ตระกูลเดียวกับ `BACKLOG-D29` ที่ซ่อมด้วยมือมาแล้ว 7 ครั้ง
> **เกณฑ์ขั้นต่ำก่อนตัดสิน (อันนี้เป็นกฎ ไม่ใช่ข้อมูล จึงอยู่ที่นี่ได้):** ≥3 เดือน **และ** ≥30 ไม้ปิด ·
> EA ที่บาง (<0.5 ไม้/สัปดาห์) ใช้กติกา `ORDER-235` แทน (≥12 เดือน + net บวก + ไม่มี kill ทริป +
> lot เล็กถาวร) **โดยต้อง pre-register ตอน attach ไม่ใช่มาเลือกตอนถึงวัน**

## 1. ข้อมูลที่ต้องมีก่อนเริ่ม (ถ้าขาด = เลื่อน ไม่ใช่เดา)

1. **Live/Demo MT5:** CSV จาก DealsExporter (`collect_live_deals.ps1`) ครอบทั้ง window — แตกต่อ EA
   ด้วย `(magic, symbol)` ผ่าน `/ea-monitor` · magic map ตรึงใน PROJECT_STATE §0.5
2. **ClevrFX:** MT4 account statement ล่าสุด
3. **Expectation ต่อ EA** (ตัวเทียบ): OOS PF จากตาราง PROJECT_STATE §4 (live 9) + DEMO_DEPLOYMENT_PLAN
   (demo 7: full-confirm PF + ธง sensitivity) — ⚠️ ST03 replica ใช้ **baseline 0.86** ไม่ใช่ 3.93 (verified 07-02)
4. เช็ค `SYSTEM_METRICS.md` + Decision log ว่าไม่มีกฎใหม่ที่กระทบเกณฑ์

## 2. เกณฑ์ตัดสินต่อ EA (ตรึงแล้ว — ที่มา: ROADMAP Phase 3 + kill-switch เดิม)

ประเมินทีละตัวตามลำดับ — ข้อแรกที่เข้าเงื่อนไข = verdict:

1. **KILL ทันที:** live PF < 0.7 ที่ ≥20 trades · หรือ DD จริงทะลุ worst-year backtest ของตัวเอง ·
   หรือพฤติกรรมผิด spec (เทรด symbol/ทิศ/ขนาดที่ไม่ได้ validate — เช็คจาก deals)
2. **PROMOTE POOL:** live PF ≥ 1.40 ที่ ≥30 trades **และ** tracking-error ผ่าน (§2.1) → เข้า pool ประกอบพอร์ต #1
3. **PROBATION (ลด lot ครึ่ง + ต่อเวลา 6 สัปดาห์):** 0.9 ≤ PF < 1.4 ที่ ≥30 trades · หรือ PF ≥1.4 แต่
   tracking-error เพี้ยน (ดูดีผิดคาด = ระวังเท่าดูแย่ผิดคาด — regime ช่วย ไม่ใช่ edge)
4. **PF 0.7–0.9 ที่ ≥30 trades:** default = KILL · ยกเว้นมีเหตุ regime ชัดเจน+เขียนได้เป็นประโยคเดียว → probation
5. **trades < 10 หลัง 3 เดือน:** ไม่ตัดสิน — ต่อเวลาอีก 6 สัปดาห์ (ข้อมูลไม่พอไม่ใช่ผลงานแย่ —
   บทเรียน ORDER-004 "OOS เทรดบาง ≠ fail") · ยกเว้น EA ที่ spec ต้องเทรดถี่แล้วเงียบ = สัญญาณ silent-stop → ตรวจก่อน
6. **คาดการณ์ล่วงหน้า (อย่าตกใจวันงาน):** ST03 replica 990010 = ตัวเก็ง kill อันดับแรก (baseline 0.86) ·
   EURJPY 990203 + CADJPY 990205 = ธงสันเขา ถ้ารอดต้อง size เบากว่าเพื่อนตอน promote · XAU 990207 = จับตา DD พิเศษ

### 2.1 Tracking-error (นิยามตรึงล่วงหน้า — จะกลายเป็น PQ-03 หลัง judge)

ต่อ EA เทียบ live กับ backtest expectation:
- **PF ratio** = PF_live / PF_expected → ผ่าน = อยู่ใน [0.6, 1.8] · ต่ำกว่า 0.6 = แย่ผิดคาด ·
  สูงกว่า ~1.8 = ดีผิดคาด (regime หนุน — ห้ามเพิ่ม size จากผลนี้)
- **Trade-rate ratio** = (trades/เดือน live) / (trades/เดือน backtest) → ผ่าน = [0.5, 2.0] ·
  หลุดช่วง = พฤติกรรมเปลี่ยน (broker/regime/config) → สอบสวนก่อนใช้ PF ตัดสิน
- ห้ามใช้ net $ ตัดสิน (sizing demo = 0.25x วัดพฤติกรรมไม่ใช่ผลตอบแทน)

## 3. ประกอบพอร์ต #1 (หลัง verdict ครบ)

1. Pool = ตัว PROMOTE ทั้งหมด (live 9 + demo 7 ที่ครบเวลา) → รัน `corr_monthly.py` บน deals จริง
2. เลือก **2–3 ตัว corr ≤0.40** ผ่าน skill `portfolio-selector` — corr 0.40–0.60 = ใช้ได้แต่ลด lot
   (กฎ user: correlation → reduce-lot-not-cut) · ห้ามเลือกกลไก×symbol ซ้ำ
3. Sizing: กลับจาก 0.25x demo → เป้า risk จริงด้วยเกณฑ์ **MC worst-DD ที่ scale จริง ≤ 25%** ต่อพอร์ต ·
   EA ธงสันเขา (EURJPY/CADJPY) size 0.5x ของ slot ตัวเอง
4. Deploy live micro ทันทีตาม user decision (ROADMAP Phase 3): `live-deployment-controller` →
   `vps-deploy-ops` → **เช็ค GV persist บน live chart ครั้งแรก** (hard-kill restore — MERGE-05B จดไว้) →
   attach DealsExporter บน account ใหม่ → ตั้งปฏิทิน re-opt 6 เดือน/ตัว ลง MASTER_BACKLOG
5. Demo account เดิม = โรงเพาะ cohort ถัดไปต่อ

## 4. กติกากระบวนการ (ห้ามข้าม)

- **การ promote demo→live = การตัดสินแพง/ย้อนไม่ได้ → บังคับ second opinion จาก Codex แบบ blind**
  (กฎ AGENTS §5) — โจทย์ที่ส่ง: ข้อมูลดิบ + เกณฑ์ไฟล์นี้ ห้ามแนบ verdict ของ seat
- ทุก verdict ลง EA_SCORECARD + EA_MASTER_INDEX **ใน commit เดียวกัน** (กฎ AGENTS §3.8)
- kill แล้ว **ห้ามลบ chart ทิ้งเฉยๆ** — detach + จด "kill เพราะเกณฑ์ข้อไหน + เลขอะไร" ลง scorecard
  (กัน re-hunt + เป็น data ให้ verdict audit รายไตรมาส)
- ผล judge ทั้งหมด = ใบเสร็จชุดใหญ่ → วันเดียวกันให้เปิด **Phase 3.5 PQUANT board** (`AGENT_TASKBOARD_PQUANT.md`)
