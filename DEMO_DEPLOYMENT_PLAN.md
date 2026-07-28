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
| **415573666** Demo Mt5-2 (Exness Trial14) | DEMO MT5 | **Boss_14_GridLog ×7** (990201-207) **+ Zeus AUDJPY(990110) + GBPJPY leg8(990208) + TrendRider_XAU/W2 S1(992004)** · AccountSnapshotExporter | ✅ Boss V2 bench + 2 grid legs (attached 2026-07-16, judge 2026-10-16) · TrendRider_XAU attached 2026-07-23, judge 2026-10-23 (ORDER-139; attached here per user override, not the originally-planned 463666728 bundle account) |
| **463666728** Demo bundle 10 (Exness Trial17) | DEMO MT5 | **11 single-position (attached 2026-07-16, judge 2026-10-16):** Wave5 XAU/XAG(990301-2) · BRK USDJPY/US30(991003/5) · MacdDiv(999094) · SMCSTO/EmaStoRev(991070) · IchiADX USDJPY×2(990066-7) · IchiADX XAU×2(990068-9) · SuperTrend(990020) · **➕ RSI-MR(990103) EURUSDm attached 2026-07-24, judge 2026-10-24** (demo-isolate re-attach after real-account removal 2026-07-18 for DD25% kill; re-validated ORDER-182→186, both-window strong but holdout 2026H1 fails outright — accepted as BUILD-ON exception per user) · **➕ Boss_16_KangarooGrid(990016) XAUUSDm H1 attached 2026-07-26, judge 2027-01-11** (flat preset, lot 0.01 คงที่; +5.5 เดือนไม่ใช่ +3 เพราะ 5.7 เทรด/เดือน) | 🆕 **มี exporter แล้ว** — `AccountSnapshotExporter - GBPJPYm,H1` เห็นใน Navigator 2026-07-26 (ข้อความเดิม "ยังไม่มี exporter" ล้าสมัย; ถ้า sensor ยัง STALE แปลว่าปัญหาอยู่ฝั่งรับไฟล์ ไม่ใช่ฝั่ง attach) |
| **69424711** Demo EA3 | DEMO MT4 | UnNomGuai(1/2) · RSI-orig(5888) · swb(990) · ClevrFX(unverified) | monitor deferred (Trial8 login) |
| **146237** Exness demo (user) | DEMO MT5 | user's own pool ~10 EA — magic ยังไม่ enumerate (บัญชีนี้เคยโผล่ใน live_deals) | 🆕 registered 2026-07-18 (user ยืนยัน: demo Exness, ขอให้เฝ้า) → enumerate magics จาก live_deals รอบ `/ea-monitor` ถัดไป |

### 🔴 CRYPTO LEGS — นาฬิกาตัดสินรีเซ็ตเป็น **2027-01-26** (2026-07-26)

ขา crypto ทั้งคู่บน **415573666** — BTC `EA_SUPERTREND`(990025) และ ETH `EA_DONCHIAN`(990030) — attach
ไปเมื่อ 2026-07-23 แต่ `.set` ที่แถมมาตั้ง **`_06_AllowLive=false`** ทั้งสองไฟล์ ⇒ EA รันแต่ไม่ยิงไม้เลย
3 วัน (ศูนย์ดีล). user เปิดแท็บ Inputs อ่านเจอเองแล้วแก้เป็น `true` ทั้งคู่ **2026-07-26**.

- **start_date + judge_date re-base ไปที่ 2026-07-26 → judge 2027-01-26** (+3 เดือนของจริง; ช่วง 07-23→07-26 ไม่นับเป็นหลักฐาน)
- บทเรียนกลับเข้า bundle: `README_ATTACH.md` ต้องมีบรรทัด "verify `_06_AllowLive=true` หลัง load .set"
  เป็น step บังคับ ไม่ใช่หมายเหตุ — แท็บ Common ติ๊ก Allow live trading แล้วยัง**ไม่พอ** เพราะ EA กั้นสองชั้น

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

**✅ 4 ตัวที่เลื่อนไม่ช่วย — RATIFIED (user 2026-07-28, ORDER-235) = ทางเลือก (ก):**
ที่อัตราไม้ของมัน กว่าจะครบ 30 ไม้ต้องรอถึงปี 2028-2029 การเลื่อนวันจึงไม่ใช่คำตอบ —
บาร์ 30 ไม้ต่างหากที่ผิดกับ EA ที่เทรดปีละไม่กี่ครั้ง:

| magic | EA | คาด/สัปดาห์ | ต้องรอถึง |
|---|---|---|---|
| 991001 | EA_BREAKOUT_XAU XAUUSD (**เงินจริง**) | 0.2 | 2029-05 |
| 991004 | (BRK)_SqueezeBreakout XAUUSD | 0.3 | 2028-06 |
| 990205 | Boss_14_GridLog size-light thin CADJPYm | 0.3 | 2028-06 |
| 990303 | Boss_17_Wave5 USDJPYm | 0.3 | 2028-06 |

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

## 🆕 ClevrFX_EA — MT4 demo experiment — 🟢 **ATTACHED แล้ว (user ยืนยัน 2026-07-06)**

> **demo-clock เริ่ม 2026-07-06 → judge เร็วสุด ~2026-10-06** (≥3 เดือน + ≥30 trades) ·
> monitor: ทุก ~2 สัปดาห์ user export MT4 account statement ส่ง Claude (รอบแรก ~2026-07-20)

> **ตัวแรกจาก treasure hunt (222 EA) ที่ผ่านครบทุกด่าน** — BWD-OOS ทุกปีบวก (1.76/1.51/2.37) + 2026=2.04 ·
> spread-stress 3x ไม่สะเทือน (sp45=1.93) · ไม่ระเบิดปี hostile · **compiled กลไกดำ → สถานะ demo-experiment
> เท่านั้น** (Fxcore100 คู่กัน = DQ pirated — ตัวเลขเก็บเป็น prior ถ้าซื้อ official ในอนาคต)

**Deploy checklist (user, บน MT4 demo ที่มีอยู่):**
1. **บัญชี:** แนะนำ ClevrFX **ตัวเดียวบนบัญชี** (attribution ตรง + วัด kill-DD ระดับบัญชีได้) · balance
   ใกล้ $10k = เทียบ validation ตรงสุด (ต่างได้ — ดู DD% ไม่ใช่ $)
2. ก็อป `D:\Forex\10_EA_PROJECTS\2. wait for test\.EA OK\ClevrFX\ClevrFX_EA.ex4` → `MQL4\Experts\` → refresh Navigator
3. **Chart: EURUSD H1 · attach ด้วย compiled defaults (ห้ามโหลด .set!)** — เรา validate ที่ default/H1
   (vendor preset = M5-cap500 ≠ config ที่ validate)
4. เปิด AutoTrading → **จดวันที่ attach → แจ้ง Claude** (demo-clock ≥3 เดือน)
5. ⚠️ **no hard SL บนไม้ — เครื่อง/VPS ต้องออนไลน์ตลอด** (disconnect = ไม้เปลือยไม่มี SL บน server)

**Kill-switch:** equity DD บัญชี >40% (= worst year backtest) → detach ทันที · **Monitor:** ~2 สัปดาห์/ครั้ง
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
**จดวันที่ attach → แจ้ง Claude = demo-clock เริ่ม (judge +3 เดือน)** · monitor รอบเดียวกับ ClevrFX
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
สถานะ = bench tier 5-6 / กรง premium-track ตาม `VISION.md` · monitor รอบเดียวกับ ClevrFX (statement ~2 สัปดาห์, แยกตาม magic)

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
| 2026-09-22 | ครบ 3 เดือน → judge ทุก EA พร้อมกัน |
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
| **69424711** | Demo EA3 | MT4 (Trial8) | **MT4 cohort**: UnNomGuai(1/2) · RSI-orig(5888) · swb(990) + ClevrFX_EA (ORDER-041 ผ่าน spread-stress) |

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