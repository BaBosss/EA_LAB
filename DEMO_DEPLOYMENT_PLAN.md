# Demo Deployment Plan — Portfolio

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · machine-readable ownership ของ live portfolio =
> **`portfolio/DEPLOYMENTS.csv`** (check_state บังคับความถูกต้องทุก commit) · ไฟล์ .md นี้ = human view +
> monitor/kill-rule detail. **ถ้าตัวเลขในไฟล์นี้ขัดกับ DEPLOYMENTS.csv → เชื่อ CSV เสมอ.**
>
> 📖 อ่าน **§ CURRENT LIVE STATE** ข้างล่างก่อน (ของจริงวันนี้) · ทุกอย่างใต้ **🗂️ ARCHIVE** =
> ประวัติแผน/experiment ก่อน 2026-07-09 เก็บไว้เป็น provenance (บางส่วน superseded — มีธงกำกับ)

---

## 📊 CURRENT LIVE STATE (2026-07-09 reality · judge ชุดนี้ = 2026-10-09) — canonical = `DEPLOYMENTS.csv`

**โครงจริง = 5 บัญชีบน VPS 66.212.22.7** (ต่างจากแผน bundle เดิมที่คิดเป็น account เดียว — ดู detail §DEPLOYMENT REALITY ใน archive).
Monitor: exporter 1 chart/บัญชี → dashboard ผ่านเครื่องแล็บ `D:\Monitor` (4/5 ไหลอัตโนมัติ) · `/ea-monitor` ทุก ~2 สัปดาห์.

| บัญชี | ประเภท | รันอะไร (magic) | สถานะแล็บ |
|---|---|---|---|
| **159503454** Blazing Arrow | REAL cent MT5 | **กองหลัก validated 5 ตัว:** Zeus(990101) · BRK-XAU(991001) · Squeeze(991004) · Trendline(991002 exp) · RSI-MR(990103→**REMOVED 2026-07-18**) | ✅ monitor เข้ม · **991001 อ่าน Inputs สด 2026-07-26 ยืนยัน v2 (Bars40/Sl1.5/Tp5.0/Ema200/AllowLive=true) = ตรงตามที่ต้องคง ไม่ต้องแตะ** |
| **159475669** Boss-Trend Swing | REAL cent MT5 | user mix: NuiIndy(1524) · CB_GBP(990005) + **ST03 family 9398/939721/990010 = REMOVED 2026-07-18** (uncapped-ruin/no-edge; rescue ต่อใน backtest = ORDER-119) + unenumerated · **BRK-XAU ×2 อ่านสด 2026-07-26: 991001 = v2 Bars40 (ACTIVE) · 991002 = Bars8 ซึ่ง bundle ระบุ DEMO แต่ไปอยู่บนเงินจริง + ถูกเลือกบนหน้าต่างที่กิน holdout 2026H1 (โรคเดียวกับ Bars55/v3) → user ถอดออก 2026-07-26** | ⚠️ user mix — แล็บไม่รับรอง |
| **141049900** Celestial Woodfire | REAL cent MT4 | user exp: Zeus Gold Hedge(7777, no-SL) · Gold_Kangaroo L1-4(1112-1115) | ⚠️ user exp · kill floating DD 40% |
| **415573666** Demo Mt5-2 (Exness Trial14) | DEMO MT5 | **Boss_14_GridLog ×7** (990201-207) **+ Zeus AUDJPY(990110) + GBPJPY leg8(990208) + TrendRider_XAU/W2 S1(992004)** · AccountSnapshotExporter | ✅ Boss V2 bench + 2 grid legs (attached 2026-07-16, judge 2026-10-16) · TrendRider_XAU attached 2026-07-23, judge 2026-10-23 (ORDER-139; attached here per user override, not the originally-planned 463666728 bundle account) · 990208 clock started from genuine first trade 2026-08-10, judge 2027-08-10 · 992004 clock started from genuine first trade 2026-08-10, judge 2027-08-10 · both awaiting valid forward period and not decision-capable |
| **463666728** Demo bundle 10 (Exness Trial17) | DEMO MT5 | **11 single-position (attached 2026-07-16, judge 2026-10-16):** Wave5 XAU/XAG(990301-2) · BRK USDJPY/US30(991003/5) · MacdDiv(999094) · SMCSTO/EmaStoRev(991070) · IchiADX USDJPY×2(990066-7) · IchiADX XAU×2(990068-9) · SuperTrend(990020) · **➕ RSI-MR(990103) EURUSDm attached 2026-07-24, judge 2026-10-24** (demo-isolate re-attach after real-account removal 2026-07-18 for DD25% kill; re-validated ORDER-182→186, both-window strong but holdout 2026H1 fails outright — accepted as BUILD-ON exception per user) · **➕ Boss_16_KangarooGrid(990016) XAUUSDm H1 attached 2026-07-26, judge 2027-01-11** (flat preset, lot 0.01 คงที่; +5.5 เดือนไม่ใช่ +3 เพราะ 5.7 เทรด/เดือน) | 🆕 **มี exporter แล้ว** — `AccountSnapshotExporter - GBPJPYm,H1` เห็นใน Navigator 2026-07-26 (ข้อความเดิม "ยังไม่มี exporter" ล้าสมัย; ถ้า sensor ยัง STALE แปลว่าปัญหาอยู่ฝั่งรับไฟล์ ไม่ใช่ฝั่ง attach) |
| **69424711** Demo EA3 | DEMO MT4 | UnNomGuai(1/2) · RSI-orig(5888) · swb(990) · ClevrFX historical/observational attribution (magic 9244; current attachment NOT PROVEN) | **CLOSED** — no current executable identity |
| **146237** Exness demo (user) | DEMO MT5 | user's own pool ~10 EA — magic ยังไม่ enumerate (บัญชีนี้เคยโผล่ใน live_deals) | 🆕 registered 2026-07-18 (user ยืนยัน: demo Exness, ขอให้เฝ้า) → enumerate magics จาก live_deals รอบ `/ea-monitor` ถัดไป |

### 🔴 CRYPTO LEGS — นาฬิกาตัดสินรีเซ็ตเป็น **2027-01-26** (2026-07-26)

ขา crypto ทั้งคู่บน **415573666** — BTC `EA_SUPERTREND`(990025) และ ETH `EA_DONCHIAN`(990030) — attach
ไปเมื่อ 2026-07-23 แต่ `.set` ที่แถมมาตั้ง **`_06_AllowLive=false`** ทั้งสองไฟล์ ⇒ EA รันแต่ไม่ยิงไม้เลย
3 วัน (ศูนย์ดีล). user เปิดแท็บ Inputs อ่านเจอเองแล้วแก้เป็น `true` ทั้งคู่ **2026-07-26**.

- **start_date + judge_date re-base ไปที่ 2026-07-26 → judge 2027-01-26** (+3 เดือนของจริง; ช่วง 07-23→07-26 ไม่นับเป็นหลักฐาน)
- บทเรียนกลับเข้า bundle: `README_ATTACH.md` ต้องมีบรรทัด "verify `_06_AllowLive=true` หลัง load .set"
  เป็น step บังคับ ไม่ใช่หมายเหตุ — แท็บ Common ติ๊ก Allow live trading แล้วยัง**ไม่พอ** เพราะ EA กั้นสองชั้น

### 🧪 A/B PAIR — `990026` จับคู่กับ `990025` · judge **2027-01-28** (ชั่วคราว) · เปิด 2026-07-28 (ORDER-353)

`990026` = `(TRD)_SuperTrendFlip_rev05` config ที่ optimize แล้ว (pyramid 1→**7 ชั้นที่ 1.0 ATR** + **ER gate 0.25**)
symbol **BTCUSDm H4** lot **0.01** · bundle = `_vps_deploy/STF_BTC_H4_ORDER353/`

**🔴 attach จริงลงบัญชี `463666728` (Demo bundle 10 / Trial17) — ไม่ใช่ `415573666` ที่แผนเขียนไว้**
ยืนยันจากภาพหน้าจอ VPS 2026-07-28: title bar `463666728 - Exness-MT5Trial17` · Navigator แสดง
`(TRD)_SuperTrendFlip_rev05 - BTCUSDm,H4` ใต้ **463666728: Demo - bundle 10** · แก้ `DEPLOYMENTS.csv` ตามจริงแล้ว
<sub>บันทึกไว้เป็นข้อเท็จจริง ไม่ใช่ข้อผิดพลาดของใคร — แต่ **แผนกับของจริงต่างกันได้เสมอ ⇒ record ต้องตามของจริง
ไม่ใช่ให้ของจริงตามแผน** (เคสเดียวกับ TrendRider_XAU ที่ user override บัญชีปลายทางเมื่อ 07-23)</sub>

**⚠️ ไม่ใช่ขาที่สองของพอร์ต — เป็นคู่ A/B ของ `990025`** สัญญาณเดียวกัน สินค้าเดียวกัน ⇒ corr เกือบ 1
⇒ **ตัดสินเป็นการทดลองเดียว ห้ามนับกำไรรวมกันเป็นการกระจายความเสี่ยง**

**🔴 ผลของการอยู่คนละบัญชี — ต้องอ่านก่อนเทียบตัวเลขทั้งสองขา:**
`990025` อยู่ **415573666 (Trial14)** · `990026` อยู่ **463666728 (Trial17)** ⇒ **คนละ terminal คนละ server**
· กฎที่ ratify วันนี้เอง (ORDER-371 → `AGENTS.md` §3) **ห้ามเทียบตัวเลขข้าม install**
⇒ **เทียบ PF/net ระหว่างสองขานี้ตรงๆ ไม่ได้** feed/spread ต่างกันได้
⇒ **แต่คำถามที่ขานี้มีไว้ตอบยังตอบได้** เพราะมันเป็นสัญญาณเชิงพฤติกรรมหยาบๆ ไม่ใช่การเทียบ PF ละเอียด:
**"ระบอบสับมาถึงแล้ว `990026` หยุดเทรดขณะที่ `990025` ยังเทรดอยู่ไหม"** — จำนวนไม้ต่างกันเป็นเท่าตัว
ไม่ใช่สิ่งที่ spread อธิบายได้ · **สิ่งที่ห้ามทำคือสรุปว่า "config ไหนกำไรดีกว่า" จากสองบัญชีนี้**

**คำถามที่ขานี้มีไว้ตอบ (backtest ตอบไม่ได้):** **ER gate ยืนหยัดถูกไหมเมื่อระบอบไม่ใช่เทรนด์**
หลักฐานว่า gate ช่วยได้ **อยู่ในหน้าต่างที่ใช้จูนค่าของมันเองทั้งหมด** — ตัด 6-9 ไม้บน BWD (ที่เลือก `ErMin`),
2 จาก 91 บน MAIN, และ **0 ไม้บน holdout 2026H1**
⇒ เมื่อระบอบสับมาถึงจริง **`990026` ควรเงียบ ขณะที่ `990025` ยังเทรด** · **ถ้าทั้งคู่เทรดเหมือนกัน = gate เฉื่อย
และธีสิส regime-conditional ไม่มีหลักฐานรองรับ ไม่ว่ากำไรจะออกมาเท่าไหร่**

**หลักฐาน (Model 4 tick จริงทั้งหมด):** BWD 121 ไม้ PF 1.89 · MAIN 89 ไม้ PF 3.99 · holdout 2026H1 16 ไม้ PF 4.02
· MC bootstrap 2,000 รอบ PF-5th **2.12** ruin **0.00%** · M1 vs M4 ต่างกัน <1% ไม้เท่ากันเป๊ะ = ไม่มี model-switch cliff

**สิ่งที่ตัวเลขพาดหัวกลบไว้ — ต้องอ่านก่อน size up:**
- **ปีขาดทุน 2 ใน 6 (2021, 2025)** ขณะที่ host เดิมมีปีเดียว · กำไรกระจุกใน 2022 + 2024
- **นี่คือ leverage บน edge เดิม ไม่ใช่ edge ใหม่** — บน holdout กำไร ~2 เท่าของ host เดิม (+406 vs +219)
  แต่ **DD 3 เท่า (7.61% vs 2.53%)** ⇒ ที่ความเสี่ยงเท่ากัน host เดิมชนะหน้าต่างนั้น (user รับ DD แล้ว บันทึกไว้กันลืม)
- **ใช้ DD = 7.61% ที่วัดได้จริง ไม่ใช่ 2.89% จาก MC** — order-resampling ทำลาย serial correlation
  ที่เป็นตัวสร้าง drawdown จริง ⇒ MC ประเมินต่ำกว่าความจริงในทิศนี้
- **`ErMin` ถูกเลือกโดยดู BWD** ⇒ BWD ไม่ใช่หลักฐาน out-of-sample ของค่านี้อีกต่อไป

**judge_date = ชั่วคราว** — นาฬิกาเริ่มที่ **ไม้แรกที่เทรดจริง** ไม่ใช่วัน attach (บทเรียนจาก `990025` ที่ต้อง re-base)
**lot เล็กถาวร ห้าม size up ตาม PF**

**⏳ ยังค้าง 2 ข้อ — สถานะใน CSV = `ACTIVE-PENDING-VERIFY` จนกว่าจะเคลียร์:**
1. **อ่านแท็บ Inputs ของชาร์ตแล้วยืนยัน 2 ค่า: `_06_AllowLive = true` และ `_06_Magic = 990026`**
   · ภาพหน้าจอที่ได้มาแสดง Navigator + ชาร์ตเท่านั้น **มองไม่เห็นค่า input** ⇒ **ยังไม่ถือว่าตรวจแล้ว**
   · ทำไมต้องยืนยันทั้งที่ bundle แก้ให้แล้ว: `990025` เคย attach สำเร็จ ดูปกติทุกอย่าง แล้วนิ่ง 3 วัน
   เพราะค่านี้ค่าเดียว · และถ้า `.set` ไม่ได้ถูกโหลด magic จะเป็น **991006** (ค่าทดสอบ) ⇒ ดีลจะไป
   ผูกกับ magic ที่ไม่มีใครเฝ้า **และ `DEPLOYMENTS.csv` จะชี้ไปที่ magic ที่ไม่มีไม้ตลอดกาลโดยไม่มีอะไรฟ้อง**
2. **บันทึกวันที่ของไม้แรกจริง** แล้ว re-base `start_date`/`judge_date` (2027-01-28 ตอนนี้คือค่าชั่วคราว)

### ⏳ JUDGE DATE EXTENDED (user decision 2026-07-25: "เลื่อนวัน")

เดิม EA ชุดนี้ถูกตั้ง judge ที่ +3 เดือน แต่ **ไม่มีทางเก็บครบ 30 ไม้ทัน** — บาร์ promote คือ
PF ≥ 1.40 ที่ **≥ 30 trades** ตัดสินตอนไม้ยังไม่ถึงคือตัดสินบน noise.

**ฐานที่ใช้คำนวณ:** อัตราไม้ที่**คาดจาก backtest** (`expectations.csv` → `trades_per_month_expected`)
ไม่ใช่อัตราที่สังเกตได้ตอนนี้ — ตอนคำนวณ EA พวกนี้เพิ่ง active 7-19 วัน ซึ่งสั้นเกินกว่าจะ forecast
(ORDER-198 เคยสรุปแล้วว่าเลข "18 ตัวขาด" ส่วนใหญ่เป็น artifact ของสูตร ไม่ใช่ EA พัง).
สูตร: `judge = start_date + (30 ÷ อัตราคาดต่อสัปดาห์) × 7 วัน`

| magic | EA | คาด/สัปดาห์ | judge เดิม | **judge ใหม่** |
|---|---|---|---|---|
| 999094 | MacdDiv_Naked XAUUSDm | 1.8 | 2026-10-16 | **2026-11-10** |
| 991002 | (BRK)_TrendlineBreakout XAUUSD | 1.1 | 2026-10-09 | **2027-01-16** |
| 990066 · 990067 | IchiADX USDJPYm (basket) | 1.1 | 2026-10-16 | **2027-01-23** |
| 990068 · 990069 | IchiADX XAUUSDm (basket) | 1.0 | 2026-10-16 | **2027-02-11** |
| 990202 | Boss_14_GridLog AUDNZDm | 0.9 | 2026-10-09 | **2027-02-24** |
| 991070 | EmaStoRev EURUSDm | 0.9 | 2026-10-16 | **2027-03-06** |
| 990203 | Boss_14_GridLog size-light EURJPYm | 0.8 | 2026-10-09 | **2027-03-25** |
| 992017 | PivotBreakout_XAU XAUUSDm | 1.5 | 2026-10-24 | **2026-12-17** |
| 990016 | Boss_16_KangarooGrid XAUUSDm | 1.3 | 2027-01-11 | **2027-01-13** |

> ➕ **2 แถวล่างเพิ่ม 2026-07-28 (ORDER-530)** — ไม่ใช่การเลื่อนเพราะอัตราไม้ แต่เพราะ **start_date ย้าย**:
> `992017` เพิ่ง attach จริงวันที่ **2026-07-28** (ก่อนหน้านั้นชาร์ตนั้นเป็น EA คนละตัวสวม magic อยู่) และ
> `990016` ถูก attach ใหม่วันเดียวกันหลังหายไปจาก terminal · วันใหม่คำนวณด้วยสูตรเดิมของตาราง
> (`992017` = start + 142 วัน ที่ 6.42 ไม้/เดือน) และกฎที่แถวนั้น pre-register ไว้เอง
> (`990016` = attach + 5.5 เดือน) · ทั้งคู่เป็น demo — user override ได้

**✅ 4 ตัวที่เลื่อนไม่ช่วย — RATIFIED (user 2026-07-28, ORDER-235) = ทางเลือก (ก):**
ที่อัตราไม้ของมัน กว่าจะครบ 30 ไม้ต้องรอถึงปี 2028-2029 การเลื่อนวันจึงไม่ใช่คำตอบ —
บาร์ 30 ไม้ต่างหากที่ผิดกับ EA ที่เทรดปีละไม่กี่ครั้ง:

| magic | EA | คาด/สัปดาห์ | ต้องรอถึง (บาร์ 30 ไม้เดิม) | **judge ใหม่ = start + 12 เดือน** |
|---|---|---|---|---|
| 991001 | EA_BREAKOUT_XAU XAUUSD (**เงินจริง** 159503454) | 0.2 | 2029-05 | ✅ **2027-07-09** (ORDER-520, user เคาะ 2026-07-28) |
| 991004 | (BRK)_SqueezeBreakout XAUUSD (**เงินจริง** 159503454 REAL_CENT) | 0.3 | 2028-06 | ✅ **2027-07-09** (ORDER-520, user เคาะ 2026-07-28) |
| 990205 | Boss_14_GridLog size-light thin CADJPYm (DEMO 415573666) | 0.3 | 2028-06 | ✅ **2027-07-06** (ORDER-520, แก้แล้ว 2026-07-28) |
| 990303 | Boss_17_Wave5 USDJPYm (DEMO 463666728) | 0.3 | 2028-06 | ✅ **2027-07-28** (ORDER-511, แก้แล้ว 2026-07-28) |

### ✅ ORDER-943 — RATIFIED 2026-08-02: ทั้งฟลีตถูกตัดสินทีเดียว หลัง `ORDER-942` เติม expected rate ครบ 36 แถว

**ทำไมรอบนี้ต่างจากรอบก่อน:** ตารางข้างบนเลื่อนวันได้เฉพาะแถวที่**บังเอิญมี** `trades_per_month_expected`
· `ORDER-942` (2026-08-02) ปิดช่องว่าง **17 → 0** ⇒ ครั้งนี้ทุกแถวที่มี judge date ถูกฉายภาพด้วยสูตรเดียวกัน
`projected = ไม้ที่ได้ + คาด/สัปดาห์ × สัปดาห์ที่เหลือ` เทียบบาร์ 30 ไม้ · ผลคือ **14 thin · 12 เลื่อนวัน ·
7 ตามแผน · 3 กันออก**

**① 14 แถว = thin → `ORDER-235`** (judge = `start_date` + 12 เดือน · net บวก · ไม่มี kill ทริป ·
**lot เล็กถาวร ห้าม size-up ตาม PF**) — pre-register **ตอนนี้ ก่อนวันตัดสินตัวแรกมาถึง** ซึ่งเป็นเงื่อนไข
ของ `ORDER-235` เอง:
🔴 **แก้ 2026-08-02 (`/scrutinize` รอบ 1) — ครั้งแรกคำนวณจาก `start_date` + 365 ซึ่ง*ขัดกับกฎที่เขียนอยู่ในเอกสารฉบับนี้เอง*
(บรรทัด "นาฬิกาเริ่มที่ **ไม้แรกที่เทรดจริง** ไม่ใช่วัน attach" — บทเรียนที่จ่ายไปแล้วกับ `990025` และ `990303`).
วัดแล้ว **13 จาก 14 แถวผิด**: 8 แถวตัดสิน**เร็วไป 1-13 วัน** (รวม `991001` ที่เป็น**เงินจริง** เร็วไป 13 วัน) และ
5 แถว**ยังไม่มีไม้แรกเลย** ⇒ นาฬิกายังไม่เริ่ม วันของมันจึงเป็น *placeholder* ไม่ใช่กำหนดการ · ตารางข้างล่างคือค่าที่แก้แล้ว**

| magic | EA | คาด/สัปดาห์ | ไม้แรกจริง | **judge = ไม้แรก + 12 เดือน** |
|---|---|---|---|---|
| `991001`🔴 | EA_BREAKOUT_XAU XAUUSD (**เงินจริง**) | 0.25 | 2026-07-22 | **2027-07-22** (เดิม 07-09 = เร็วไป 13 วัน) |
| `990205` | Boss_14_GridLog size-light CADJPYm | 0.29 | 2026-07-14 | **2027-07-14** (เร็วไป 8 วัน) |
| `990303` | Boss_17_Wave5 USDJPYm | 0.27 | 2026-07-31 | **2027-07-31** (เร็วไป 3 วัน) |
| `991003` | EA_BREAKOUT_XAU USDJPYm | 0.42 | 2026-07-23 | **2027-07-23** (เร็วไป 7 วัน) |
| `990020` | EA_SUPERTREND XAUUSDm | 0.31 | 2026-07-27 | **2027-07-27** (เร็วไป 11 วัน) |
| **`990984`** | PairSpread_StatArb EURUSDm | 0.64 | 2026-07-31 | **2027-07-31** (เร็วไป 13 วัน) |
| `992001` | TsMom_XAU (S2) XAUUSDm | 0.17 | 2026-07-24 | **2027-07-24** (เร็วไป 1 วัน) |
| ~~`990204`~~ | Boss_14_GridLog AUDCADm | 0.60 | — | 🔻 **ออกจากถัง thin 2026-08-02** → judge **2027-05-10** |
| ~~`990206`~~ | Boss_14_GridLog SELL EURUSDm | 0.51 | — | 🔻 **ออกจากถัง thin 2026-08-02** → judge **2027-05-31** |
| `991005` | EA_BREAKOUT_XAU US30m | 0.21 | **ยังไม่มี** | 2027-07-16 = **PROVISIONAL** |
| **`990208`** | Boss_14_GridLog GBPJPYm | 0.51 | **2026-08-10** | **2027-08-10 = CLOCK STARTED / AWAITING VALID FORWARD PERIOD** |
| `992004` | TrendRider_XAU (W2 S1) XAUUSD | 0.46 | **2026-08-10** | **2027-08-10 = CLOCK STARTED / AWAITING VALID FORWARD PERIOD** |
| `990025` | EA_SUPERTREND crypto ST-BTC BTCUSDm | 0.49 | **ยังไม่มี** | 2027-07-26 = **PROVISIONAL** |
| `990026` | (TRD)_SuperTrendFlip_rev05 BTCUSDm | 0.45 | **ยังไม่มี** | 2027-07-28 = **PROVISIONAL** |

> 🔻 **`990204` · `990206` ถูกดึงออกจากถัง thin 2026-08-02 (user เคาะ หลัง `/scrutinize` รอบ 2).**
> ทั้งคู่วิ่งจริงที่ **2.61× / 4.05×** ของอัตราคาด ⇒ สมมติฐานของ `ORDER-235` ("30 ไม้เอื้อมไม่ถึง") **ผิด**
> สำหรับสองตัวนี้ — ที่อัตราจริง ณ วัน thin เดิมมันจะมี ~81 และ ~107 ไม้ คือ **~3.5 เท่า**ของบาร์ที่กฎมีไว้แทน
> ⇒ กลับไปใช้**บาร์จริง (PF ≥ 1.40 @ ≥30 ไม้)** และ **ไม่มี lot cap ถาวร** · วันใหม่คำนวณจากอัตรา **คาด**
> ไม่ใช่อัตราจริง โดยตั้งใจ: หน้าต่างสังเกตแค่ 3.9 สัปดาห์ จึงไม่เดิมพันกับมัน (ที่อัตราจริงจะครบ 30 ไม้
> ราว ต.ค.-พ.ย. 2026 คือก่อนวันตัดสิน ~6 เดือน) · ⚠️ **ประตูทางเดียว:** `ORDER-235` ห้ามเลือก thin
> หลังเห็นตัวเลข ⇒ ถ้ามันช้าลงต่ำกว่าอัตรา*คาด* จะถึงวันตัดสินโดยไม่มีคำตัดสิน และใส่ thin กลับไม่ได้

> 🎯 **ทิศทางของ owner สำหรับ thin ทั้งคลาส (2026-08-02) → `ORDER-1170`.**
> *"พวก thin ทั้งหมดผมจะเอามารวมๆ กันแล้ว trade แบบ multi symbol ใน EA ตัวเดียว ไม่ก็ optimize ให้ถี่ขึ้น
> หรือเอาอะไรมาช่วยให้ออกถี่ขึ้น หรือเอาไปรวมกับพวกไม้ถี่ที่มัน corr ต่ำ"* — กรอบนี้ถูก: `ORDER-235`
> **บริหาร**ตัวอย่างที่บาง มัน**ไม่ได้ซ่อม** · การรอ 12 เดือนเพื่อตัดสินขาที่เทรดปีละ 13 ไม้ คือการจ่าย
> wall-clock หนึ่งปีเพื่อสถิติที่ซื้อได้ใน 3 เดือนถ้าเปลี่ยนวิธี deploy · **บาร์ไม่ขยับ สิ่งที่เปลี่ยนคือสิ่งที่เอาไป attach**
> · roster 12 ขา + ต้นทุนของแต่ละเส้นทาง อยู่ในแถว `ORDER-1170`

> 🔴 **5 แถว PROVISIONAL ไม่ใช่ "กำหนดการ" — มันคือ placeholder.** นาฬิกา 12 เดือนยังไม่เริ่ม เพราะยังไม่มีไม้แรก
> ⇒ ต้อง re-base เป็น *ไม้แรก + 12 เดือน* ทันทีที่ดีลแรกลง · และระหว่างนี้มันคือคำถามของ `ORDER-941` ย่อส่วน:
> ขาที่ไม่มีไม้เลย **ไม่ได้อยู่ในตาราง มันคือเรื่องที่ยังอธิบายไม่ได้**

> 🔴 **4 แถวตัวหนาถูก user ย้ายเข้ากลุ่ม thin 2026-08-02 ทั้งที่คาด 0.51-0.64 ไม้/สัปดาห์ = *เหนือ* เส้น 0.5.**
> เหตุผลคือเส้นนั้นคาบเกินไป: ที่อัตราของมัน วันตัดสินที่คำนวณได้อยู่ห่างออกไป **215-341 วัน** —
> คือการรอ 12 เดือนเท่ากับกลุ่ม thin อยู่แล้ว แต่มาทางที่**ไม่มี lot cap ติดมาด้วย** ⇒ รอเท่ากัน
> และคราวนี้กรงมาด้วย · เส้น 0.5 ยังไม่ถูกแก้ใน `CLAUDE.md` — ถ้าจะแก้ ต้องเป็น order ของตัวเอง

**② 12 แถวเลื่อนวันตามเลข** (`(30 − ไม้ที่ได้) ÷ คาด/สัปดาห์`) — วันเดิมถูกตั้งไว้ตอนที่**ยังไม่มี**
อัตราคาด นี่คือการ *บังคับใช้* บาร์ ไม่ใช่การเลื่อนให้ cohort ดูพร้อม · เลขคณิตต่อแถวอยู่ในช่อง `notes`
ของ `DEPLOYMENTS.csv` แถวนั้นเอง ไม่ได้ทำสำเนามาไว้ที่นี่:
`991070` **2027-03-07** · `999094` **2026-11-20** · `990068` **2027-02-22** · `990069` **2027-03-01** ·
`990201` **2026-11-02** · `990066`/`990067` **2027-02-17** · `990103` **2026-11-20** · `990030`
**2027-03-01** · `990301` **2026-12-12** · `990302` **2026-12-28** · `990110` **2027-02-20**

**③ 3 แถวกันออก → `ORDER-941`, `judge_date` ไม่ถูกแตะ:** `991004`🔴 · `991002`🔴 · `990202`
> 🔴 ทั้งสามอยู่ใต้อัตราคาดจริง (`ORDER-942` B3) และ **2 ใน 3 เป็นเงินจริง** · การฉายภาพด้วยอัตรา*คาด*
> จึงมองโลกสวยเกินไปสำหรับกลุ่มนี้: ที่อัตรา*ที่สังเกตได้* `991002` ต้องรอ **100 สัปดาห์** และ `991004`
> ซึ่งยังไม่มีไม้เลย **ไม่มีวันถึง** · การให้ `991004` วันตัดสิน 2027-07-09 จะทำให้ขาที่ไม่ได้เทรดดูเหมือน
> "มีกำหนดการ" 11 เดือน — คำถามว่า *เงียบหรือบาง* ต้อง instrument ก่อน แล้วค่อยตัดสิน

> 🔴 **ORDER-520 2026-07-28 — `991004` เป็นเงินจริงด้วย ไม่ใช่แค่ `991001`.** handoff ของเลน MAGIC511
> เขียนกลุ่มนี้ว่า "`991001` (real money) · `991004` · `990205`" ซึ่งอ่านได้เหมือนว่ามีแถวเงินจริงใบเดียว
> แต่ `991004` อยู่บนบัญชี **159503454 ซึ่ง `DEPLOYMENTS.csv` ระบุ type = `REAL_CENT`** — บัญชีเดียวกับ
> `991001` เป๊ะ ⇒ **2 ใน 3 แถวที่เหลือเป็นเงินจริง** จึงแก้ให้ไม่ได้โดยไม่มี user เคาะ
> ✅ **user เคาะแล้ว 2026-07-28 ("แก้เลย") ⇒ ทั้ง 4 แถวของกลุ่ม thin เข้าที่ครบ · ORDER-520 ปิด**
> แก้ **ช่อง `judge_date` ช่องเดียวต่อแถว** — `kill_rule` (`closedDD 10%`) · `status` · `start_date` ·
> `magic` · lot และทุกอย่างบน VPS **ไม่ถูกแตะ** · แถว 22 (`159475669` ใช้ magic `991001` ซ้ำ,
> `judge_date` ว่าง, lab ไม่รับรอง) ไม่ถูกแตะเช่นกัน

> 🔴 **990303 clock re-based 2026-07-28 → judge_date `2027-07-28` (ORDER-511 option A, user ratified).**
> That chart had been running since 07-18 **without its `.set` ever being loaded** — unpinned on the
> compiled default magic `990001`, with a looser entry and a much tighter trail than the config its
> evidence came from. `start_date` moved to the re-pin date (2026-07-28) and `judge_date` is start
> **+12 months** per the ORDER-235 thin-EA bar.
> 🔴 **CORRECTION (ORDER-530, 2026-07-28): "the leg opened zero trades, confirmed by the deals export"
> was wrong, and the deals export is the file that refutes it.**
> `portfolio/live_deals/EA_LAB_deals_463666728_20260728.csv` holds **two** deals on magic `990001`:
> a sell 0.01 `USDJPYm` @163.535 on 2026.07.27 10:00 (`17_Wave5 L0`) closed on the stop @163.696 at
> 12:16 for **−0.98**. So the re-base discarded **one closed trade worth −0.98**, not nothing. The
> option-A decision is unchanged — one trade against a 12-month horizon is immaterial, and the leg was
> flat from 07-27 12:16 so the re-pin was still safe — but **"zero" must not be re-quoted**, and the
> leg is now confirmed to have been *actively trading* on the un-validated looser entry.
> ⚠️ **`990205` re-based to `2027-07-06` (ORDER-520). `991001` and `991004` still carry the old +3mo
> `judge_date` and are BOTH on REAL_CENT 159503454 → they need the user, see the table above.**

ทางเลือกที่เสนอไว้ = (ก) ลดบาร์จำนวนไม้เฉพาะกลุ่ม thin แล้วชดเชยด้วยหลักฐาน backtest
both-window + ขนาด lot เล็กถาวร · (ข) ตัดสินเป็น "ยังไม่พอตัดสิน" ไปเรื่อยๆ แล้วปล่อยรัน
· (ค) ถอดออกเพราะไม่คุ้มช่องพอร์ต

**เคาะแล้ว = (ก)** — บาร์ใหม่ของกลุ่ม thin (คาด **< 0.5 ไม้/สัปดาห์**) เขียนลง `CLAUDE.md` VERDICT GATE
bar table แล้ว **แทนที่**การนับ 30 ไม้ ไม่ใช่การยกเว้น:

| เงื่อนไข | ค่า |
|---|---|
| ระยะเวลา live | **≥ 12 เดือน** |
| ผลลัพธ์ | **net บวก** ตลอดหน้าต่างนั้น |
| kill | **ไม่มี pre-registered kill ทริป** |
| หลักฐานก่อน attach | backtest both-window ต้องผ่านชัดอยู่แล้ว |
| ราคาที่จ่าย | **lot เล็กถาวร · ห้าม size-up ตาม PF ไม่ว่าผลจะดีแค่ไหน** (ท่าเดียวกับ NuiIndy `engine-edge`) |

**เหตุผลที่ต้องตัดที่บาร์ ไม่ใช่ที่วันที่:** ที่ 0.2-0.3 ไม้/สัปดาห์ การเลื่อน judge date ออกไป
แปลว่า 4 ตัวนี้ — **หนึ่งในนั้นอยู่บนเงินจริง** — จะไม่มีเกณฑ์ตัดสินเลยจนถึงปี 2029 ซึ่งไม่ใช่บาร์
แต่คือการไม่มีบาร์ · **สถิติที่อ่อนลงถูกชดเชยด้วยขนาด ไม่ใช่ด้วยการหลับตา**

⚠️ **ตัวที่ต้องดูเป็นพิเศษ: `991001` อยู่บนเงินจริง** — บาร์นี้เปิดทางให้ *ตัดสิน* ได้ ไม่ได้เปิดทางให้
*เพิ่มขนาด* · เส้น "ห้าม size-up ตาม PF" ผูกกับตัวนี้แน่นที่สุดเพราะเป็นตัวเดียวที่เพิ่มขนาดแล้วเจ็บจริง

**🟢 APPROVED (user 2026-07-16B "เอาเข้าทั้งหมด") — bundle พร้อม, user จะ attach ตอนว่าง (ยังไม่อยู่ใน DEPLOYMENTS.csv จนกว่า attach จริง):**
| EA | Symbol/TF | Magic | Bundle | หลักฐาน |
|---|---|---|---|---|
| Boss_17_Wave5 | XAUUSD H1 | 990301 | `_vps_deploy/WAVE5_XAU/` | plateau both-window, MC ruin 0%, corr 0.415 |
| Boss_17_Wave5 | XAGUSD H1 | 990302 | `_vps_deploy/WAVE5_XAG/` | 6/6 cell both-window (แข็งกว่า XAU) |
| EA_BREAKOUT_XAU | USDJPY H4 | 991003 | `_vps_deploy/EA_BREAKOUT_USDJPY/` | flat-lot both-window 1.28/1.25 |
| EA_BREAKOUT_XAU | US30 H4 | 991005 | `_vps_deploy/EA_BREAKOUT_US30/` | 1.46/1.39 (WATCH-thin) |
| MacdDiv_Naked | XAUUSD H4 | 999094 | `_vps_deploy/MACDDIV_XAU/` | Model-4 confirm 1.89/0.97/1.28, corr 0.555 |
| Zeus (regime) | AUDJPY | 990110 | `_vps_deploy/ZEUS_AUDJPY_REGIME/` | range-gate Model-4 both-window; ⚠️ 2023 year down → deploy small |
| Boss_14 GridLog | GBPJPY H4 | 990208 | `_vps_deploy/BOSS14_GBPJPY/` | all-years-positive; corr max 0.791 (CADJPY) |
| SMC×STO | EURUSD H1 | 991070 | `_vps_deploy/SMCSTO_EURUSD/` | ADX-filter candidate (user push revived) |
| IchiADX (basket A) | USDJPY H4 | 990066 | `_vps_deploy/ICHIADX_USDJPY_BASKET/` | basket PF 1.339/DD 6.09%/MC PF_5th 1.036; ⚠️ thin → small lot |
| IchiADX (basket B) | USDJPY H1 | 990067 | `_vps_deploy/ICHIADX_USDJPY_BASKET/` | leg B ของ basket เดียวกัน (ต้องรันคู่ A) |
| **IchiADX XAU basket A** | XAUUSD H1 | 990068 | `_vps_deploy/ICHIADX_XAU/` | slow 20/60/120, PF 1.57/Sharpe 3.0 |
| **IchiADX XAU basket B** | XAUUSD H4 | 990069 | `_vps_deploy/ICHIADX_XAU/` | med 12/34/68, PF 2.85. **basket 2-leg = 6/6 ปีบวก · PF 2.14 · MC PF_5th 1.544 · DD 10.5%** = find แข็งสุด session; demo normal lot |

| EA_SUPERTREND | XAUUSD H4 | 990020 | `_vps_deploy/EA_SUPERTREND_XAU/` | validated XAU: IS 1.54/OOS 4.49/MC PF_5th 1.57/ruin 0%; AllowLive gate; live-track leg (EA-SCORE #7) |

**เมื่อ user attach ตัวใด → แจ้งวัน → Claude เพิ่ม row ใน DEPLOYMENTS.csv + judge +3 เดือน + dashboard map.**
(EA_SUPERTREND 990020 = ตั้งใจ attach บนบัญชี demo 415573666 — bundle ครบแล้วที่ `_vps_deploy/EA_SUPERTREND_XAU/`)

---

## 🗂️ ARCHIVE — แผน/experiment log ก่อน 2026-07-09 (provenance; บางส่วน superseded โดย §CURRENT LIVE STATE)

> ⚠️ **section ด้านล่างนี้ทั้งหมดเป็นประวัติ** — แผน v3 เดิม (9-EA cent account เดียว judge 2026-09-22) ถูกแทนที่ด้วย
> โครง 5-บัญชี VPS ด้านบน. เก็บไว้เพราะมี monitor-rule/kill-switch/หลักฐานต่อ EA ที่ยังอ้างอิงได้. ตัวเลข judge date/
> account structure ที่ขัดกับ §CURRENT LIVE STATE = ยึดด้านบน.

---

## ภาพรวม EA ทั้งหมด (10,000 cent — account เดียว)

| # | EA | Symbol | TF | Set File | OOS PF | Status | หมายเหตุ |
|---|---|---|---|---|---|---|---|
| 1 | Matchagrid (MG_v1) | CHFJPY | M15 | `MG_CHFJPY_v1_locked.set` | 2.08 | 🟢 LIVE | fixed 0.01 lot ✅ |
| 2 | NuiIndy RSI+ADX | EURUSD | H1 | `NuiIndy_EURUSD_robust.set` | 2.00 | 🟢 LIVE | 10k/500k = 0.02 lot ✅ |
| 3 | ST_EA03 MACD | GBPUSD | H1 | `MACD_GBPUSD_locked.set` | 2.47 | 🟢 LIVE | Lots_divided แก้ → 100,000 (0.1 lot/leg) ✅ |
| 4 | ST_EA03 MACD | USDCAD | H1 | `MACD_USDCAD_locked.set` | 2.62 | 🟢 LIVE | เหมือน EA 3 ✅ |
| 5 | Gold Reaper 4.3 | XAUUSD | H1 | `GoldReaper_cent_v1.set` | 2.07 | 🟢 LIVE | StartLots=0.01 ✅ |
| 6 | EA_BREAKOUT_XAU | XAUUSD | H1 | `_vps_deploy\BRK_XAU_live_v2.set` | 1.98 MAIN / 1.66 BWD | 🟢 LIVE — ห้าม reload | ⛔ **v3 RELOAD ยกเลิกถาวร 2026-07-26**: v3 จูนบนหน้าต่างที่กิน holdout 2026H1, แพ้ v2 ทั้ง BWD (1.01 vs 1.66) และ MAIN (1.86 vs 1.98) — ชนะเฉพาะช่องที่ไหม้. เลข 2.94-4.87 เดิม = contaminated, ห้ามอ้าง. คง Bars40/Tp5.0/Ema200 |
| 7 | LondonConsoBreakout | GBPUSD | H1 | `_vps_deploy\CB_GBP\CB_GBP_H1_live_v1.set` | 2.08 | 🟢 LIVE | 0.01 lot ✅ |
| 8 | LondonConsoBreakout | EURUSD | H1 | `_vps_deploy\CB_EUR\CB_EUR_H1_live_v1.set` | 1.25 | ❌ DROP (2026-06-25) | Q2 rescue sweep พบ no durable edge (OOS ทั้งคู่ <1.0) → ถอดออกจาก demo. Portfolio จริง = 7 ตัว |
| 9 | EA_RUNNER_ST03 (LR2 replica) | GBPUSD | H1 | `_vps_deploy\ST03_GBPUSD\ST03_GBPUSD_live_v1.set` | 3.93 | 🟡 DEPLOY MON 2026-06-29 (DEMO) | bundle staged + verified 2026-06-26. magic 990010, AllowLiveOrders=true. corr −0.24 vs live ST_EA03 = LOW. |
| 10 | EA_BREAKOUT_XAU (Bars8) | XAUUSD | H1 | `_vps_deploy\BRK_XAU_Bars8\BRKXAUH4_Bars8_demo_v1.set` | 3.92 | 🟡 DEPLOY (DEMO) | Additive leg: corr 0.21 vs live Bars55 (#6). MC PASS (PF_5th 1.73, ruin 0%). Magic=991002. Same chart as #6 (different magic, coexist OK). |

**Promote conditions (กลุ่ม B → portfolio):**
- ≥30 real trades ผ่านไป
- PF ≥ 1.40 จาก live trades
- ไม่ถึง stop rule → promote เข้า Core พร้อมปรับขนาด

**Stop rules กลุ่ม B:**
- EA 6: ถ้า XAU กลับเป็น bear trend ยาว → review BUY-only bias
- EA 7: pause ถ้า DD > 1.5% หรือ 10 consecutive losses — เพิ่ม risk เป็น 1% หลัง 30 trades pass
- EA 8: pause ถ้า monthly DD > 1% หรือ 10 consecutive losses — **อย่าเพิ่ม lot**

---

## 🟢 Boss_14 GridLog cohort — Exness demo (60,000 USD, 7 EA) — ✅ LIVE 2026-07-05

> **บัญชีคนละก้อนกับ 9 EA ข้างบน** (Exness demo, 60,000 USD, 7 EA) · ทุกตัว = **EA เดียวกัน
> `EALabTpl\Boss_14_GridLog`** ต่างแค่ symbol/set/magic · TF = **H1 ทุกตัว**
> · ✅ **ATTACHED 2026-07-05 → demo clock เริ่มนับ → judge เร็วสุด 2026-10-05** (3 เดือน)
> · 📅 **/ea-monitor ครั้งแรก ~2026-07-19** (2 สัปดาห์ · ส่ง live_deals.csv ตาม §6)
> · ⚠️ **XAUUSD 3-digit (Exness) → ใช้ set `Boss14_GridLog_XAU_DEMO_exness3d.set`** (slippage 300, ต่างจาก
>   backtest 2-digit — core ATR-relative เหมือนเดิม) · 6 FX ใช้ `*_DEMO.set` เดิมได้ (ATR-relative)
> · ❓ **CONFIRM account type:** user บอก "60,000 USD" → ถ้า **Standard 60k USD** = ~$8.5k/EA ≈ validation
>   deposit $10k (sizing ตรง ✅) · ถ้าเป็น **cent account** lots (0.10 FX / 0.05 XAU) จะ oversize มาก → รีบแจ้ง Claude

| #   | Symbol           | Magic  | Set File (`ea_template\sets\`)                                     | full-confirm PF | หลักฐาน/ธง                                                                                                                                                                                                                                                                                                                                                                                                  |
| --- | ---------------- | ------ | ------------------------------------------------------------------ | --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | USDJPY           | 990201 | `Boss14_GridLog_USDJPY_DEMO.set`                                   | 1.51            | OOS 2.77/106t แน่นสุด · ⚠️ plateau มีรอยร้าว: **ห้าม tune step/TP ต่ำกว่าค่านี้** (พลิกขาดทุน)                                                                                                                                                                                                                                                                                                              |
| 2   | AUDNZD           | 990202 | `Boss14_GridLog_AUDNZD_DEMO.set`                                   | 1.56            | 🏆 ที่ราบสมบูรณ์ (sensitivity 8/8) + ทุกปีบวก = แข็งสุดในคอฮอร์ต                                                                                                                                                                                                                                                                                                                                            |
| 3   | EURJPY           | 990203 | `Boss14_GridLog_EURJPY_DEMO.set`                                   | 2.49            | 🔴 **สันเขา (sensitivity 1/8) + fill-sensitive** (M4 eqDD 10%) → **size เบากว่าเพื่อนตอน promote**                                                                                                                                                                                                                                                                                                          |
| 4   | AUDCAD           | 990204 | `Boss14_GridLog_AUDCAD_DEMO.set`                                   | 1.88            | OOS 4.30 ทุกปีบวก · ที่ราบ (sensitivity 5/8)                                                                                                                                                                                                                                                                                                                                                                |
| 5   | CADJPY           | 990205 | `Boss14_GridLog_CADJPY_DEMO.set`                                   | 1.89            | 🔴 **สันเขา (sensitivity 2/8) + thin 77t** → **size เบากว่าเพื่อน + จับตาพิเศษ**                                                                                                                                                                                                                                                                                                                            |
| 6   | EURUSD (SELL)    | 990206 | `Boss14_GridLog_EURUSD_DEMO.set`                                   | 1.97            | ฝั่ง SELL (diversity) · ที่ราบปานกลาง                                                                                                                                                                                                                                                                                                                                                                       |
| 7   | **XAUUSD (ทอง)** | 990207 | **`Boss14_GridLog_XAU_DEMO_exness3d.set`** (3-digit, slippage 300) | 1.42 (OOS 1.15) | 🆕 **non-FX diversifier** (2026-07-05) — ผ่านครบ pipeline (IS-opt→OOS ทุกปีบวก→MC ruin0%→**Model-4 +$5078 edge รอด real ticks**) · **lot 0.05 (de-scaled ครึ่ง เพราะ DD ~2x FX)** · ⚠️ **leg เสี่ยงสุด จับตา DD พิเศษ** · SL cap off (ATR-SL คุม) · **corr ยืนยัน diversifier: AUDNZD -0.59 / CADJPY -0.19 / AUDCAD +0.19 / EURJPY +0.32 = additive · USDJPY +0.53 watch (6mo บาง จับตา) · ไม่มีคู่ >0.60** |

**Config ร่วม:** ทุก set = 0.25x (0.10 lot base) · `_4_DdAdaptiveOn=false` (ปิดเพราะบัญชีแชร์ DD จะปน) ·
sizing นี้ = **วัดพฤติกรรม ไม่ใช่ผลตอบแทน** — ตัวเลข MC worst 6-9% เป็นที่ 0.25x เท่านั้น (live 3-4x → ~25-35%)

**Attach checklist (user ทำใน MT5 ของบัญชี 60k):**
1. เปิด **7 ชาร์ต** **H1** — USDJPY · AUDNZD · EURJPY · AUDCAD · CADJPY · EURUSD · **XAUUSD** (#7 ทอง, lot 0.05)
2. ลาก `Boss_14_GridLog` (จาก Navigator, expert = `EALabTpl\Boss_14_GridLog`) ลงแต่ละชาร์ต
3. แต่ละชาร์ต: F7 → Load → เลือก set ตามตาราง (symbol ให้ตรงชาร์ต!) → OK · เปิด AutoTrading
4. เช็ค magic ในแต่ละ set ไม่ซ้ำกัน (990201-206) + ต่างจาก 9 EA เดิม (คนละบัญชีอยู่แล้ว ปลอดภัย)
5. จดวันที่ attach จริง → แจ้ง Claude เพื่อ set demo-clock + นัด `/ea-monitor` ครั้งแรก ~2 สัปดาห์

**Promote conditions (หลัง demo ≥3 เดือน):** ≥30 real trades · PF ≥ 1.40 จาก live · ไม่ถึง stop rule ·
**ตอน promote ขึ้น lot: EURJPY + CADJPY size เบากว่าเพื่อน (สันเขา), USDJPY คงค่า step/TP เดิม** (จาก
plateau-sensitivity ORDER-022) · corr matrix (ORDER-019): ไม่มีคู่ >0.60, watch USDJPY-CADJPY 0.57 → ลด lot ตัวใดตัวหนึ่ง

**Stop rules:** ตัวไหน eqDD account-wide > 25% (PROTECT_NORMAL KillDD) EA จะ close+halt เอง ·
manual pause ถ้า EA ตัวใด DD ผิดปกติเทียบ backtest (ดูจาก /ea-monitor)

---

## ClevrFX_EA — MT4 demo experiment — **CLOSED (historical / observational attribution)**

> **Account:** `69424711 / Exness-Trial8` · **observed historical magic:** `9244` ·
> **historical/observational attribution:** ACCEPTED · **current executable attachment:** NOT PROVEN ·
> **historical executable identity:** UNRECOVERABLE FROM CURRENT EVIDENCE · **investigation:** CLOSED.

> **Historical validation context only; not current attachment evidence.** ตัวแรกจาก treasure hunt (222 EA) ที่ผ่านครบทุกด่าน — BWD-OOS ทุกปีบวก (1.76/1.51/2.37) + 2026=2.04 ·
> spread-stress 3x ไม่สะเทือน (sp45=1.93) · ไม่ระเบิดปี hostile · **compiled กลไกดำ → สถานะ demo-experiment
> เท่านั้น** (Fxcore100 คู่กัน = DQ pirated — ตัวเลขเก็บเป็น prior ถ้าซื้อ official ในอนาคต)

**Historical deployment checklist (superseded; preserved for provenance only):**
1. **บัญชี:** แนะนำ ClevrFX **ตัวเดียวบนบัญชี** (attribution ตรง + วัด kill-DD ระดับบัญชีได้) · balance
   ใกล้ $10k = เทียบ validation ตรงสุด (ต่างได้ — ดู DD% ไม่ใช่ $)
2. ก็อป `D:\Forex\10_EA_PROJECTS\2. wait for test\.EA OK\ClevrFX\ClevrFX_EA.ex4` → `MQL4\Experts\` → refresh Navigator
3. **Chart: EURUSD H1 · attach ด้วย compiled defaults (ห้ามโหลด .set!)** — เรา validate ที่ default/H1
   (vendor preset = M5-cap500 ≠ config ที่ validate)
4. เปิด AutoTrading → **จดวันที่ attach → แจ้ง Claude** (demo-clock ≥3 เดือน)
5. ⚠️ **no hard SL บนไม้ — เครื่อง/VPS ต้องออนไลน์ตลอด** (disconnect = ไม้เปลือยไม่มี SL บน server)

**Historical criteria (not current operational instructions):** Kill-switch: equity DD บัญชี >40% (= worst year backtest) → detach ทันที · Monitor: ~2 สัปดาห์/ครั้ง
export MT4 account statement ส่ง Claude (MT4 ไม่ใช้ /ea-monitor MT5 pipeline — ใช้ statement แทน) ·
**Judge:** ≥3 เดือน + ≥30 trades (ได้ในเดือนเดียว ~1 ไม้/วัน) → PF live ≥1.4 = คุยขั้นต่อ

---

## 🆕 MT4 demo experiment #2 — 3 treasure-hunt survivors — 🟡 **รอ user attach (อนุมัติ 2026-07-07)**

> **3 survivor จาก EA ~1,300 ตัว (ORDER-036/046/047)** ผ่าน funnel 5 ด่านครบ ·
> **checklist + kill-switch + ค่าคาดหวังเต็ม = `_demo_deploy\README_DEPLOY.md`** (รวมครบในที่เดียว อ่านง่าย)
> · bundle: ex4 ×3 + set ×2 + MD5 lock

| # | EA | Chart | Set | Magic |
|---|---|---|---|---|
| 1 | UnNomGuaiV1.132 | EURUSD H1 | `UnNomGuai_cap20.set` | 1/2 |
| 2 | RSI from pips_EA | EURUSD H1 | defaults | 5888 |
| 3 | swb grid 4.1.0.3_h | AUDCAD H1 | `swb_AUDCAD_demo.set` | 990 |

**1 บัญชี demo ใหม่ ($10k, ThinkMarkets) รันทั้ง 3** (คนละ chart/magic ไม่ชน) · ลง MT4 portable
`D:\Meta4demo` (ห้ามทับเลนเทส) · **ห้ามแก้ input · no hard SL ทุกตัว → online ตลอด** ·
**จดวันที่ attach → แจ้ง Claude = demo-clock เริ่ม (judge +3 เดือน)** · monitor รอบเดียวกับ MT4 statement process
(statement ทุก ~2 สัปดาห์, แยก P&L ตาม magic) — รายละเอียดทั้งหมดใน README

---

## 🆕 MT4 demo experiment #3 — swb grid flat-lot @ AUDCAD — 🟡 **รอ user attach บน 69424711 (อนุมัติ 2026-07-10, ORDER-086)**

> **candidate #3 จาก ORDER-036/046/047** — ฟื้นด้วย `lot_multiplier=0` + symbol ที่ใช่ (AUDCAD) ·
> BWD 2.40/DD8.6 → SPR30 2.23/DD9.0 → **Model-0 1.80/DD20.44** · ladder linear ×3-4 (ไม่ใช่ martingale) ·
> **bundle + checklist + kill-switch ครบ = `_demo_deploy\MT4\swb_experiment3\README.md`** (ex4 + locked set + MD5 lock)

| # | EA | Chart | Set | Magic | Kill |
|---|---|---|---|---|---|
| 1 | swb grid 4.1.0.3_h | AUDCAD H1 | `swb_experiment3\swb_AUDCAD_demo.set` | 990 | DD 30% (M0 ref 20.4%) หรือ ladder >1.0 lot/ไม้ |

**attach บนบัญชี demo MT4 69424711** (chart/magic ไม่ชน cohort เดิม UnNomGuai 1/2 · RSI-orig 5888) ·
**ห้ามแก้ input · no hard SL → online ตลอด** · **จดวันที่ attach → แจ้ง Claude = demo-clock เริ่ม (judge +3 เดือน)** ·
สถานะ = bench tier 5-6 / กรง premium-track ตาม `VISION.md` · monitor รอบเดียวกับ MT4 statement process (statement ~2 สัปดาห์, แยกตาม magic)

---

## Account Setup

- **Account: 10,000 cent** (= $100 USD equivalent) — deploy 2026-06-22
- EA 1–5: `.set` อยู่ใน `D:\EA_LAB\_mt5_auto\`
- EA 6–8: `.set` อยู่ใน `D:\EA_LAB\_vps_deploy\` (แต่ละ subfolder)
- Leverage: ตามที่ broker กำหนด, Account type: Hedge

---

## Lot Sizing

| EA | Lot บน 10,000 cent | สถานะ |
|---|---|---|
| MG_v1 CHFJPY | 0.01 (fixed) | ✅ |
| NuiIndy EURUSD | 10k ÷ 500k = **0.02** | ✅ |
| ST_EA03 GBPUSD | 10k ÷ 100k = **0.1/leg** × 3 = 0.3 | ✅ แก้แล้ว |
| ST_EA03 USDCAD | เหมือนกัน | ✅ แก้แล้ว |
| Gold Reaper | StartLots=0.01 | ✅ |
| EA_BREAKOUT_XAU | 0.01 (fixed) | ✅ |
| CB_GBP GBPUSD | 0.01 (fixed) | ✅ |
| CB_EUR EURUSD | 0.01 (fixed) | ✅ |

ST_EA03 แก้แล้ว 2026-06-22: `Lots_divided` 10,000,000 → **100,000** → 0.1 lot/leg × 3 legs = 0.3 total ✅

---

## Magic Numbers (ห้ามซ้ำ)

| Magic | EA |
|---|---|
| 1524 | NuiIndy EURUSD |
| 9397 | ST_EA03 GBPUSD |
| 9398 | ST_EA03 USDCAD |
| (default) | Gold Reaper — ตรวจจาก GUI ก่อน attach |
| 990005 | LondonConsoBreakout (ทั้ง GBPUSD + EURUSD — OK เพราะ filter by _Symbol) |
| 991001 | EA_BREAKOUT_XAU (Bars55, live — v3 set) |
| 991002 | EA_BREAKOUT_XAU (Bars8 additive, DEMO) |
| 990010 | EA_RUNNER_ST03 GBPUSD (LR2 replica — separate account from ST_EA03 EA3) |

---

## Expert Names (MT5 Navigator)

| EA | Expert name |
|---|---|
| Matchagrid | `Matchagrid` |
| NuiIndy | `(NuiIndy) Dynamic RSI+ADX Style (4)` |
| ST_EA03 | `(ST) EA03 Count MACD v1` |
| Gold Reaper | `The Gold Reaper MT5_4.3_fix_@FundedMillionAiress` |
| EA_BREAKOUT_XAU | `EA_BREAKOUT_XAU` |
| LondonConsoBreakout | `(Boss)_LondonConsoBreakout_rev01` |

---

## Monitoring Checklist (รายสัปดาห์)

### กลุ่ม A

| EA | หยุดถ้า | Action |
|---|---|---|
| MG_v1 | Live DD > 35% | Close all MG positions |
| NuiIndy | Live DD > 20% | Review params |
| MACD GBPUSD/USDCAD | PF < 1.0 ใน 30 วัน | Pause + review |
| Gold Reaper ⚠️ | DD > 25% **หรือ** PF < 1.2 ใน 30 วัน | Pause ทันที |
| ทุก EA | ไม่มี trade 2 สัปดาห์ | ตรวจ AutoTrading / connection |

### กลุ่ม B

| EA | หยุดถ้า | เพิ่ม risk ถ้า |
|---|---|---|
| EA_BREAKOUT_XAU (Bars55, #6) | XAU bear trend ยาว | 30 trades, PF ≥ 1.40 |
| EA_BREAKOUT_XAU (Bars8, #9) | XAU bear trend ยาว หรือ corr vs #6 > 0.60 live | 30 trades, PF ≥ 1.40 |
| CB_GBP GBPUSD | DD > 1.5% หรือ 10 consec loss | 30 trades, PF ≥ 1.40 → เพิ่มเป็น 1% |
| ~~CB_EUR EURUSD~~ | **DROPPED 2026-06-25** | Q2 rescue sweep (48 combo × 3 win) ไม่เจอ durable edge — OOS ทั้งคู่ <1.0. GBPUSD-only confirmed. ถอด EA ออกจาก EURUSD chart ใน MT5 GUI |

---

## Timeline

| วันที่ | Milestone |
|---|---|
| 2026-06-22 | **ทั้ง 8 EA deploy แล้ว** บน 10,000 cent account เดียว |
| 2026-06-22 | ST_EA03 lot fix — Lots_divided แก้ → 100,000 ✅ |
| 2026-06-28 | EA #6 v3 set ready — reload EA_BREAKOUT_XAU with BRK_XAU_live_v3.set (Bars=55, TP×8, EMA150) — ⛔ **เพิกถอน 2026-07-26 ไม่เคยทำและห้ามทำ** (v3 = selection-into-the-leak, ORDER-201/210) |
| ~~2026-09-22~~ | ~~ครบ 3 เดือน → judge ทุก EA พร้อมกัน~~ 🔴 **เพิกถอน 2026-08-01 (`ORDER-940`): ไม่มีแถวไหนใน `DEPLOYMENTS.csv` ถือวันนี้** — cohort สลายแล้ว (`9397` หายจากทะเบียน · `9398`/`990010` REMOVED · ที่เหลืออยู่บัญชีที่แล็บไม่รับรอง ⇒ judge_date ว่างโดยตั้งใจ) · วัน judge แรกจริง = **2026-10-09** · ปฏิทินจริง = generated (`scripts/control_room_snapshot.ps1` → `judge_cohorts`) ห้ามเขียนวันด้วยมืออีก |
| หลัง judge | EA ที่ผ่าน (PF ≥ 1.40, ≥30 trades) → เพิ่ม port หรือเพิ่ม lot |

---

## ต่อไปหลัง 3 เดือน

1. รัน per-EA attribution script (parse history by magic) → ดูว่า EA ไหนกำไร/ขาดทุน
2. ถ้ากลุ่ม A ผ่าน → live บน cent $100/port (ปรับ ST_EA03 Lots_divided ก่อน)
3. ถ้ากลุ่ม B ผ่านเงื่อนไข → merge เข้า Core portfolio
4. ถ้า MG_v1 DD สูงเกิน → พิจารณา drop + หา replacement correlation ต่ำ

---

## EA_CORE_V1 — งานต่อ

**Phases A–J: เสร็จแล้ว** (framework validated, signals v2-v4, LotSizer, ScaleExecutor v1)

**Part B ScaleExecutor (planned):** implement pending/limit order pyramid แบบ ST_EA03
- Phase I (simultaneous market open) = PF 0.84 LOSING → dead end
- Root cause: ST_EA03 ใช้ Nearby_PIP PENDING order stagger → legs fill เมื่อราคาเคลื่อน
- Next: เปลี่ยน `ScaleExecutor_v1` ให้ส่ง ORDER_TYPE_BUY_LIMIT/SELL_LIMIT แทน market
- Target: reproduce ST_EA03-level PF >> 1.11 บน GBPUSD/USDCAD H1
- ⚠️ Model 4 required (TP < 20 pip trigger)


---

## 🚀 DEPLOYMENT REALITY 2026-07-09 (user attach จริง — โครงสร้างต่างจากแผน bundle เดิม, ทุกอย่างรันบน VPS 66.212.22.7)

**5 บัญชี active · live-clock ชุดนี้เริ่ม 2026-07-09 · judge ชุดนี้ = 2026-10-09 (+3 เดือน)**

### REAL — Exness Standard Cent, 10,000 USC/บัญชี (×3)
| บัญชี         | ชื่อ                   | Platform           | รันอะไร                                                                                                                                                                      | สถานะ validate                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ------------- | ---------------------- | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **159503454** | 08. Blazing Arrow      | MT5 Hedge (Real20) | **MT5 cohort ทั้ง 5**: RSI-MR(990103) · Zeus(990101) · BRK-XAU(991001) · SqueezeBRK(991004) · Trendline(991002)                                                              | ✅ validated sets — นี่คือกองหลักที่ต้อง monitor เข้ม                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **159475669** | Boss - Trend Swing     | MT5 Hedge (Real20) | mix: EA_BREAKOUT_XAU + **LondonConso (แล็บ REJECT)** + **Gold Reaper (แล็บ REJECT, ประวัติ DD>50%)** + MACD/NuiIndy/ST03/MatchaGrid + **939721 = ST_EA03 config user (GBP)** | ⚠️ ทดลองของ user — แล็บไม่รับรอง ตัวแดง 2 ตัวมีสำนวน REJECT · **🔴 939721 = uncapped-ruin ยืนยันจาก source+backtest 2026-07-10** (no SL · no cap · flat-lot PF 0.68 = entry ไม่มี edge, กำไรทั้งหมดมาจาก recovery escalation ที่มี ratchet defect ทำ linear→doubling — ที่มาไม้ 33.73 lots · ทุกปี float DD 40-69% · GBP วิ่งทางเดียว ~180-340 pips = ล้างพอร์ต ซึ่งเกิดปีละหลายครั้ง) → **คำแนะนำแล็บ (อัปเดตหลัง ORDER-068): ถอดตระกูล ST03 ทั้งหมดจากบัญชีจริงนี้ — 939721 + 9398 + 990010** (config แล็บก็ no-edge เท่ากัน: flat-lot GBP 0.68 / CAD 0.40 ล้างพอร์ต — มันแชร์ equity กับทุก EA ในบัญชี) · หลักฐาน `_mt5_auto\reports\ST03LIVE_*` + `ST03LAB_*` |
| **141049900** | 01. Celestial Woodfire | MT4 (Real35)       | Zeus Gold Hedge V1.2_fix **บน EURUSDc** (magic 7777) + Gold_Kangaroo XAUUSDc (magics 1112-1115, MagicStart=1111)                                                             | ⚠️ ทดลองของ user · magic map ยืนยันจาก tester 2026-07-10 · **Kangaroo smoke 3ปี: PF 4.86 H1 / DD 11% (capped martingale + SL จริง — ดีเกินคาด, ยังไม่ validated)** · **Zeus บน XAU = stop-out ใน 2 วัน DD 84-86% ทั้ง H1/M15 — ห้ามย้าย Zeus ไปทองเด็ดขาด** · **Zeus EURUSD (เซลล์ที่รันจริง): H1 = เซลล์เดียวใน 4 ที่รอด 3.5ปี (PF 1.61) แต่ DD 47.8% + ตะกร้าลบลอย ≥$5k สี่ครั้ง (ครั้งแรง −$9k บนทุน 10k, 53 ไม้/43 lots, no SL) · M15 stop-out เดือนที่ 3** → โปรไฟล์ = รอดเพราะ mean-revert ทัน ไม่ใช่เพราะมีเบรก — ถ้าคงไว้: ถอนกำไรเป็นระยะ + kill มือถ้า floating DD แตะ 40% · รายงาน `_mt4_auto\reports\KANGAROO_*/ZEUSMT4_*`                            |

### DEMO — Exness Standard (×2)
| บัญชี | ชื่อ | Platform | รันอะไร |
|---|---|---|---|
| **415573666** | Demo Mt5-2 | MT5 (Trial14) | **Boss_14_GridLog ×7 symbols** (USDJPYm/AUDNZDm/EURJPYm/AUDCADm/CADJPYm/EURUSDm/XAUUSDm H1) = Boss V2 bench ขึ้น demo แล้ว · **➕ รอ attach (user approve 2026-07-11): EA_SUPERTREND XAUUSDm H4 magic 990020** set `_vps_deploy\ST_XAU_H4_live_v1.set` — เป้าหมาย = EA-SCORE criterion 7 (live tracking ≥2 เดือน) หลัง 085B: BWD ตกบาร์/plateau ผ่าน · ตลาดปิดวันที่อนุมัติ user จะ attach เมื่อว่าง |
| **69424711** | Demo EA3 | MT4 (Trial8) | **MT4 cohort**: UnNomGuai(1/2) · RSI-orig(5888) · swb(990) + ClevrFX historical/observational attribution (magic 9244; current attachment NOT PROVEN; CLOSED) |

**📌 การตัดสินใจ user 2026-07-11 (หลัง CODEX-AUDIT + REVIEW 085B) — สถานะ pending จนกว่า user ลงมือ (ตลาดปิด):**
1. **RSI-MR (990103) ถอดจาก real 159503454 → ย้ายไป demo isolate** (premium-track experiment เดี่ยว
   ตามข้อเสนอ audit A7 — user: "demo อะลองได้") — ตอน user ถอดจริงให้ update ตาราง REAL ข้างบน + dashboard map
2. **ST03 family (939721/9398/990010 บน 159475669): user จะถอด แต่ขอ optimize มือเองก่อน** แล้วเอาผลมาคุย —
   นี่คือ `PARKED-VERIFY(user)` ตามกติกาเป๊ะ · verdict แล็บ (STRUCTURAL no-edge) ยืนไว้ ห้าม re-litigate จนกว่า
   user มีผลใหม่มาเทียบ · ตอนคุยผล: เช็คด้วยบาร์เดิม (flat-lot PF>1 คือคำถามเดียวที่ชี้ขาด entry edge)
3. SuperTrend demo = แถวบน ✅ · 4. AccountSnapshotExporter บน VPS + OneDrive transport = user ทำเมื่อว่าง
   (checklist ใน taskboard ORDER-092 RESULT)

**หมายเหตุ scaling:** บัญชี cent 10,000 USC — money-param ใน set (เช่น TpUsd) กับ balance สเกลอัตราส่วนเดียวกับ
แผน $10,000 เป๊ะ → PF/DD%/เกณฑ์ kill-switch แบบ % ใช้ได้ตรง · เกณฑ์ $ ใน README อ่านเป็น USC แทน
**Exness cent symbols ห้อย c** (XAUUSDc/EURUSDc) / demo standard ห้อย m — DealsExporter/dashboard ไม่สนใจ suffix (group ตาม magic)

**Monitoring (คำตอบ "ต้อง attach อะไรเพิ่ม"): exporter 1 chart ต่อบัญชี รวม 5:**
- DealsExporter.ex5 → 159503454 · 159475669 · 415573666 (MT5)
- OrdersExporterMT4.ex4 → 141049900 · 69424711 (MT4, ตั้ง Account History = All History ก่อน)
- attach บน **VPS** (terminal อยู่ที่นั่น + ออนไลน์ตลอด = จุดที่ถูกของ exporter) → CSV ตกที่ Common\Files ของ VPS →
  ทางขน: (A) ติด OneDrive บน VPS + scheduled copy → เครื่องแล็บ sync อัตโนมัติ (เป้าหมาย) หรือ (B) ชั่วคราว: RDP
  ก๊อป EA_LAB_*.csv มาใส่ portfolio\live_deals\ สัปดาห์ละครั้ง
- ⚠️ ระวังชื่อไฟล์ export ชนกัน: exporter ตั้งชื่อตาม login → 5 บัญชี = 5 ไฟล์ ไม่ชน ✅
- **สถานะจริง 2026-07-09 กลางคืน (rotation v3 ทดสอบผ่าน): 4/5 บัญชีไหลเข้า dashboard อัตโนมัติแล้ว**
  (159503454 · 159475669 · 415573666 · 141049900 investor-mode) ผ่านเครื่องแล็บ `D:\Monitor` ไม่ใช่ VPS —
  แผน VPS ด้านบนไม่ต้องทำแล้ว · **69424711 = ไว้ก่อน (user 2026-07-09)** login Exness-Trial8 ไม่สำเร็จ
  (connect failed — server scan สดยังไม่ผ่าน) → rotation ยัง launch ให้ทุกคืนแต่ collector ข้าม login=0 เอง
  ไม่มีขยะ · จะเปิดใช้เมื่อไหร่ = login สำเร็จครั้งเดียวใน `D:\Monitor\MT4 - 69424711` (/portable) จบ

**จับตาพิเศษ (จากภาพหน้าบัญชี Real):** พอร์ต MT4 cent อีกหลายตัว (Abyssal/Ember Strike/Twin Flares/Golden
Ember/Iron Discipline) โชว์ **Free margin 0.00-0.35 USC** — ถ้าบัญชีพวกนี้มีเงิน+ไม้เปิดอยู่ = ชิด margin call
มาก / ถ้ายังไม่ funded = ไม่เป็นไร → user ยืนยันสถานะด้วย
## 2026-08-14 VPS manual-ops closeout

- `992001` TsMom_XAU: owner corrected discovered H1 drift to canonical D1; pre-correction H1 evidence is discarded, valid-forward reset is `2026-08-14`, and the next valid D1 first trade starts the judge clock.
- `990026` ORDER-353: full CONFIG PASS on `463666728/BTCUSDm/H4`; zero closed trades as of `2026-08-14`; first trade remains NONE and disposition is `MONITOR_FORWARD`.
