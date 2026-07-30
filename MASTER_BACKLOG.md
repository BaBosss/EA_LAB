# MASTER BACKLOG & COVERAGE

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · ไฟล์นี้ owns: **backlog · coverage matrix · hunt** เท่านั้น
**สร้าง 2026-06-27.** จุดประสงค์: รวม "สิ่งที่ต้องทำ" ที่กระจายอยู่ 5 ไฟล์มาไว้ที่เดียว + ตอบว่า
**EA ตัวไหนเทสกับ symbol/TF ไหนแล้ว, optimize รึยัง, ช่องว่างจริงอยู่ตรงไหน.**

> เปิดไฟล์นี้สำหรับ backlog. สถานะ/decision/แผนรวม → `PROJECT_STATE.md`. ที่เหลือ (`INTAKE_QUEUE`,
> `EA_SCORECARD`, `MT4_GOLDGRID_RETEST_PLAN`, `DEMO_DEPLOYMENT_PLAN`) = รายละเอียด/archive.

---

## 1. ความจริงสั้น ๆ (อ่านก่อน)

- **idea bank ไม่มีของซ่อน:** `strategy_idea_bank/` = EA ชุดเดียวกับ `INTAKE_QUEUE` Bucket C/D/E
  ซึ่ง smoke แล้ว = **0 survivors** (martingale/grid ล้วน). `STRATEGY_IDEA_BANK.xlsx` = template เปล่า.
  → **ไม่ใช่ขุมสมบัติ** ที่ยังไม่แตะ; มันคือกองที่พิสูจน์ DEAD ไปแล้ว.
- **แกน symbol = สำรวจแน่นมาก** — ทุก EA ที่ proven ถูก sweep ข้าม 6-12 symbol แล้ว ส่วนใหญ่ REJECT
  (ดูตารางข้อ 2). โอกาส "พลาดดี ๆ" บนแกน symbol เหลือน้อย.
- **แกน timeframe = นี่คือช่องว่างจริง** — เกือบทุกอย่างเทสที่ H1 เท่านั้น (54 H1 vs 6 M15 / 4 H4).
  ST03 reversion พิสูจน์แล้วว่า H1 ดีสุด (TF ต่ำ spread กิน) แต่ **breakout ยังไม่เคย sweep TF** → กำลัง smoke H4.
- **concept ใหม่จริง ๆ เหลือ 2 ตัวที่ยังไม่ smoke:** EURCHF bounded-range, London-breakout port→NY open.

สรุป: "ยังมี idea อีกเยอะ" = **จริงบางส่วน** แต่เป็นช่องว่างแคบ (TF + 2 concept) ไม่ใช่ทุ่งกว้าง.

---

## 2. COVERAGE MATRIX — EA × symbol × TF × optimize

| EA | Class | LIVE cell | TF เทส | Optimized? | symbol อื่นที่ลองแล้ว → ผล |
|---|---|---|---|---|---|
| Matchagrid MG_v1 | grid | **CHFJPY M15** | M15 | ✅ locked | (เฉพาะ CHFJPY) — JPY crosses อื่นยังไม่ลอง |
| NuiIndy RSI+ADX | reversion | **EURUSD H1** | H1 | ✅ locked | GBPUSD REJECT(DD37%) · USDJPY/AUDJPY REJECT(wipeout) |
| ST_EA03 MACD | rev-pyramid | **GBPUSD H1 · USDCAD H1** | H1✅(M30/M15 weaker) | default (GBPUSD/CAD-specific) | EUR/USDJPY/EURJPY/XAU/GBPJPY/EURGBP/AUD/NZD/GBPCAD/EURCAD/CADJPY = REJECT · GBPCHF pass-but-corr |
| Gold Reaper 4.3 | commercial | **XAUUSD H1** | H1 | ❌ default params | freshness re-confirm OK |
| EA_BREAKOUT_XAU | breakout | **XAUUSD H1** | H1 | ✅ plateau | US30/WTI/BRENT/XAGUSD/GBPJPY DEAD · USDJPY opt→REJECT · **H4 = smoke อยู่** |
| LondonConsoBreakout | breakout | **GBPUSD H1** | H1 | ✅ | EURUSD dropped · GBPJPY/GBPCAD/EURGBP/USDCAD DEAD · **H4 ยังไม่ลอง** |
| EA_RUNNER_ST03 (framework) | rev-pyramid | **GBPUSD H1** (deploy Mon) | H1 | ✅ | USDCAD/EUR/AUD/NZD fail = GBPUSD-only |

**อ่านจากตาราง:** ทุกตัว = H1 ยกเว้น MG (M15). ช่องที่ยังว่างจริง = (a) breakout @ H4, (b) MG บน JPY-cross อื่น, (c) Gold Reaper ยังไม่ optimize.

---

## 3. BACKLOG — งานที่เปิดอยู่จริง (เรียงตามความคุ้ม)

> ⚠️ **CORRECTION 2026-06-27:** "XAU H4 breakout / แกน TF คือช่องว่าง" = เข้าใจผิด. EA_BREAKOUT_XAU
> **hardcode PERIOD_H1** (channel+ATR) → `-Period` ไม่เปลี่ยน signal (H4=D1=H1 เลขเท่ากันเป๊ะ). ตัวแปรจริง
> = **BreakoutBars** (H1 bars). ของจริงที่เจอ = **re-tune BreakoutBars=55 ดีกว่า Bars40 ที่ deploy** (XAU,
> Model4: IS PF 2.85-3.19 / OOS 2.94-4.87) = param improvement ไม่ใช่ TF/instrument ใหม่.

### 🔴 ติดเวลา / ทำก่อน
- [x] ~~**EA #6 reload Bars55**~~ — ⛔ **ยกเลิกถาวร 2026-07-26 (ห้ามทำ).** v3 (Bars55) ถูกจูนบนหน้าต่างที่กิน
      holdout 2026H1 เข้าไป → วัดใหม่บน 3 หน้าต่างแยก v3 **แพ้ v2 ทั้ง BWD (1.01 vs 1.66) และ MAIN (1.86 vs 1.98)**
      ชนะเฉพาะช่องที่ไหม้ = selection-into-the-leak. ORDER-210 ค้นใหม่บนหน้าต่างสะอาดก็หา config ที่ชนะ v2 บน BWD
      ไม่เจอ. **คงเงินจริงไว้ที่ v2 (Bars40/Tp5.0/Ema200) ไม่ต้องแตะชาร์ต** — ดู header ใน `BRK_XAU_live_v3.set`
- [ ] **ST03 replica deploy → จันทร์ 2026-06-29** (DEMO, magic 990010). bundle staged แล้ว `_vps_deploy/ST03_GBPUSD/`. ดู `DEMO_DEPLOYMENT_PLAN.md`.
      Steps: DEMO MT5 → New GBPUSD H1 chart → attach EA_RUNNER_ST03 → load `ST03_GBPUSD_live_v1.set` → verify magic=990010 + AllowLiveOrders=true
- [ ] **EA #10 deploy (BRKXAU Bars8)** — DEMO MT5 → New XAUUSD H1 chart → attach EA_BREAKOUT_XAU → load `_vps_deploy\BRK_XAU_Bars8\BRKXAUH4_Bars8_demo_v1.set` → verify magic=991002
- [ ] **demo-monitor 8 EA → judge 2026-09-22** (รายสัปดาห์: Gold Reaper conditional, MG grid DD, ST03 replica 30 trades แรก)

### 📐 EA DEVELOPMENT PLAN (2026-06-27) — หลักการ + ลำดับ
**หลักการที่พิสูจน์รอบนี้:** โอกาสที่พลาด = **แกน TIMEFRAME** ไม่ใช่ strategy ใหม่. `strategy_idea_bank/` =
251 mq5 แต่เป็น version-churn ของ ~26 family ที่ตายแล้ว (martingale/grid/RSI) → screen เดี่ยว ๆ = เสียเวลา.
**ขุดเอา TECHNIQUE เท่านั้น ไม่เอา EA ทั้งตัว.**

- **Phase 1 — re-tune / param-improve EA ที่ proven (ROI สูงสุด):**
  - [x] **XAU breakout BreakoutBars=55 = ดีสุด** (ไม่ใช่ "H4" — EA เป็น H1-signal ตายตัว). IS PF 2.85-3.19 /
        OOS 2.94-4.87. Bars8 ผ่าน MC (PF-5th 1.73). corr Bars8 vs deployed Bars55 = 0.21 LOW = additive variant.
        → ⛔ **ผลนี้ถูกเพิกถอน 2026-07-25/26**: IS/OOS ข้างบนวัดบนหน้าต่างที่กิน holdout 2026H1 → v3 แพ้ v2 บน
        หน้าต่างสะอาดทั้งสอง (ORDER-201/210). `BRK_XAU_live_v3.set` = DO-NOT-DEPLOY, เงินจริงคง v2 (Bars40)
  - [x] **XAGUSD buy-only REJECT 2026-06-28**: smoke 1.45 ✅ / IS 1.47 ✅ / OOS 0.78 ❌ structural — Silver 2020-23 hostile (COVID crash, Reddit squeeze, bear). XAU≠XAGUSD buy-only. Do NOT revisit.
  - GBPUSD breakout (EA_BREAKOUT_XAU H1-signal) = ❌ DEAD (Bars8-20, Model4 PF 0.66-0.85). N-bar breakout = XAU-specific
  - EA_LNBREAK (London breakout) = ❌ DEAD 2026-06-28 — smoke PF 1.07-1.09 ทุก symbol ไม่ผ่าน gate
  - EA_GoldenEmber_Pivot = ❌ DEAD 2026-06-28 — IS PF=1.01, DD=24.66% (robust pass = best optimizer result ก็ยังแบน)
  - [x] **NuiIndy reversion H4 = 0 trades → reversion เพดานที่ H1** (H4 สัญญาณน้อยเกิน, M30/M15 spread กิน per ST03)
  - ⚠️ ของจริงที่ยังไม่ทำ: ทดสอบ **signal TF อื่น** ต้องแก้ EA ให้ internal TF เป็น input ก่อน (ตอนนี้ hardcode H1)
- **Phase 2 — ขุด technique จาก strategy folder (เฉพาะเมื่อ EA ต้องการ):** ATR-nearby pyramid (= ST03 concept, validated แล้ว) ·
  PSAR trailing exit / session filter → graft ใส่ breakout ถ้า exit ต้องปรับ. ไม่ใช่ standalone screening.
- **Phase 3 — concept ใหม่ (ยังไม่ smoke):** EURCHF bounded-range · London→NY breakout.
  - **idea source จริง = `200 AI Prompt` PDF** (ไม่ใช่ folder EA ที่ตายแล้ว). วิเคราะห์ครบ 200 ตัวที่
    [STRATEGY_200_ANALYSIS.md](_archive_docs/STRATEGY_200_ANALYSIS.md). TOP 8/10 shortlist (trend-follower ที่พอร์ตยังไม่มี)
    **ปิดครบทั้ง 3 แล้ว (2026-07-02):** #68 SuperTrend → tested XAU H4, PARKED as reserve (corr 0.946 vs
    Kaufman ER ที่ดีกว่า, ดู `EA_SCORECARD_AND_REGISTRY.md`) · #94 Donchian/Turtle → DEAD (0 additive legs,
    line above) · #20 Trend+Pyramid → DEAD (line above, XAU gap closed today). **ไม่มี candidate เหลือจาก
    shortlist นี้** — signal hunt เข้าสู่โหมด "รอไอเดียใหม่" ไม่ใช่ "มีคิวให้ทำต่อ".

---

## NEXT SESSION RESEARCH PLAN (2026-06-27 update) — symbol+TF ครบ

> ⚠️ **SUPERSEDED (C5 hygiene 2026-07-20 — ห้ามใช้ตัดสิน):** กฎ block นี้เขียนยุค Model-2-smoke.
> **Model-2 ใช้ฆ่าได้อย่างเดียว ห้ามใช้ผ่าน** (doctrine 2026-07-11) + window ปัจจุบัน = MAIN 2023.01–2025.12 /
> BWD 2020-22 / holdout 2026H1 (CLAUDE.md VERDICT GATE). ผล DEAD ด้านล่างที่ตายด้วย Model-2 = ยังตายได้
> (kill-side valid) แต่ผล "ผ่าน/PROCEED" ยุคนั้นใช้ไม่ได้แล้ว.
> ~~**กฎ:** smoke = Model 2, 2023.01.01-2026.06.01, default params. IS = 2023.01-2025.01 / OOS = 2025.01-2026.06.~~
> ทุก concept ต้องเทสอย่างน้อย 3 symbol×TF เพื่อให้รู้ว่า dead จริงหรือแค่ wrong instrument.

### ~~TASK 1~~ — EA_NR7 ขยาย TF+Symbol ✅ DONE — DEAD 2026-06-28
ครบทุก cell ที่วางแผน: XAU H4 IS=1.08, XAU H1 IS=1.06, XAGUSD H4 IS=0.68, USDJPY H1 PF=0.88, GBPJPY H1 PF=0.65.
IS failure ทุก cell ที่ test = NR7 concept มี structural IS failure, ไม่ใช่ param ผิด.
**ปิด concept นี้ถาวร.**

---

### ~~TASK 2~~ — EA_ASIANRANGE ขยาย Symbol ✅ DONE — DEAD 2026-06-28
GBPUSD/EURUSD ทั้ง UTC default และ UTC+3 retry = PF 0.94-0.96. ครบ 4 cells = concept fully dead.
**ปิด concept นี้ถาวร.**

---

### ~~TASK 3~~ — EA_LNBREAK (London→NY breakout) ✅ DONE — DEAD 2026-06-28
EA built + 5 symbols smoked (GBPUSD/EURUSD/GBPJPY/USDJPY/XAUUSD H1): best = GBPUSD PF=1.07.
TP4 retry: PF=1.09 (win rate 40%→35%, no improvement). Concept dead, CB_GBP ดีกว่ามาก.
**ปิด concept นี้ถาวร.**

---

### TASK 4 — Gold Reaper optimize (1 session, เบา)
Default params ปัจจุบัน = conditional OK แต่ ยังไม่ optimize. เป้าหมาย: plateau check ว่า default params อยู่ที่ plateau หรือมี param ดีกว่า.

| # | Symbol | TF | params to sweep |
|---|---|---|---|
| 4a | XAUUSD | H1 | StartLots 0.01-0.05 step 0.01 + key params 2-3 ตัว (ดู EA settings ก่อน) |
| 4b | **IS/OOS check** | — | IS 2023-2025 / OOS 2025-2026 บน default + best plateau params |

---

### TASK 5 — MT4 goldgrid — ✅ DONE (Phase 1 06-29, Phase 2 07-02)
~~Phase 1 = run Elephant/Mammoth/Gold Stuff V7 บน MT4 simulator ดู equity curve artifact check~~ done 06-29.
~~Phase 2 = Model 0 artifact gate~~ done 07-02 (Model 1 substitute, no tick history cached) — **ALL 3 FAIL**,
gold-grid concept confirmed dead. เต็ม → `MT4_GOLDGRID_RETEST_PLAN.md` §CLOSED.

---

> **⚠️ ของด้านล่างนี้เป็น planning block เก่า (คอนเทนต์อ้าง "Deploy จันทร์" ที่ผ่านไปนานแล้ว + เลข TASK ไม่ตรงกับ
> TASK 1-5 ปัจจุบันในไฟล์นี้) — เก็บไว้เป็น archive ไม่ใช่คิวจริง. ดูสถานะปัจจุบันที่ PROJECT_STATE.md §7 แทน.**

### ~~ลำดับที่แนะนำสำหรับ session ถัดไป~~ (เก่า/archive)
1. Deploy จันทร์ก่อน (ST03 + Bars8) → 10 นาที
2. TASK 1 (NR7 ขยาย) — ใช้เวลา ~45 นาที (smoke 4 combo ด้วย 2 MT5 parallel)
3. TASK 3 (EA_LNBREAK code + smoke) — ใช้เวลา ~60 นาที
4. TASK 2 (AsianRange ขยาย) — ใช้เวลา ~20 นาที (EA มีแล้ว แค่ run)
5. TASK 4+5 (GR optimize + goldgrid) — ถ้าเวลาเหลือ

---

### 🟡 hunt ที่มีเหตุผล (ช่องว่างจริง — ทำได้เลย ไม่ติดเวลา)
- [x] **breakout @ H4 XAU = VALIDATED CANDIDATE (2026-06-27)** — TF-scaled BreakoutBars(8/12/20) ผ่าน
      IS+OOS ทั้ง 6-combo plateau (Model 4: IS PF 1.66-2.61 / OOS 2.38-3.92) + **MC bootstrap PASS**
      (PF-5th 1.73, ruin 0%, 61t). set `_mt5_auto/sweeps/_sets/BRKXAUH4_c0.set`. ผ่าน gate เท่ากับ EA ที่ deploy แล้ว.
      corr vs XAU H1 live = **0.21 LOW = additive** (2026-06-27). GBPUSD H4 = DEAD (ตัด). Gold Reaper corr ปิด:
      GR เป็นกลไกคนละแบบ (reversion scalper, anti-corr กับทุกตัว) + redundancy หลัก (vs H1 breakout) เคลียร์แล้ว.
      caveat: OOS forward-only (ไม่มี data 2020-22). **พร้อมเป็น candidate leg #8 (เล็ก) — รอ deploy หลัง ST03 จันทร์.**

- [x] **EA_SUPERTREND XAU H4 = FULLY VALIDATED แต่ CORR สูง (2026-06-27)**
      Pipeline ครบ: Smoke M2 (PF 3.32 H4 / 0.93 H1) → IS M4 PF 1.54 / OOS PF 4.49 → MC (PF_5th 1.57, DD_95th 3.26%, Ruin 0%)
      MTF modes ทดสอบ: Mode1 (H4-filter+H1) = DEAD PF 1.09; Mode2 pyramid ($30k) = PF 1.72 / MC PF_5th 1.35 / Ruin 0%
      **❌ PORTFOLIO BLOCK: corr vs EA_BREAKOUT_XAU = 0.724 HIGH → ไม่ additive เป็น XAU leg ที่ 2**
      ทั้งคู่เป็น directional XAU trend = exposure ซ้ำซ้อน. EA ดีพอแต่ต้องหา symbol ใหม่.
      → **ขั้นต่อ: smoke EA_SUPERTREND บน GBPJPY H4** (trender ที่ไม่มี coverage ในพอร์ต)
      Sources: `EA_SUPERTREND.mq5`, `EA_SUPERTREND_MTF.mq5` (D:\EA_Project\CURRENT_BUILD\TEMPLATE\)

- [x] **EA_SUPERTREND multi-symbol smoke (2026-06-27)** — 7 symbols naked H4 M2 tested:

  | Symbol  | PF   | Trades | DD%   | Verdict |
  |---------|------|--------|-------|---------|
  | GBPJPY  | 0.55 | 77     | 2.16% | DEAD |
  | XAGUSD  | 1.63 | 45     | 12.75%| PROCEED (borderline) |
  | EURUSD  | 0.67 | 70     | 1.22% | DEAD |
  | GBPUSD  | 0.96 | 67     | 1.05% | DEAD |
  | AUDJPY  | 0.58 | 72     | 1.48% | DEAD |
  | US30    | 1.56 | 45     | 0.77% | PROCEED → validating |

  Correlation vs EA_BREAKOUT_XAU (monthly Pearson, `_mt5_auto/corr_monthly.py`):
  - XAGUSD: 0.403 (WATCH — barely over 0.40 gate; DD 12.75% also concern)
  - US30: **-0.068 LOW/ADDITIVE** ✅ but OOS M4 PF=0.46 (regime fail in 2025.06-2026.06)

  **FINAL VERDICT: EA_SUPERTREND = XAU-specific edge. 12 symbols tested, 0 additive legs found.**
  Extended batch 2: USDJPY (IS 1.55/OOS 1.09 M2 FAIL), GBPCHF (0.40 DEAD), CHFJPY (0.93 DEAD), NZDUSD (0.68 DEAD).
  US30 IS/OOS M2: IS 3.31 / OOS 0.13 = pure regime artifact (2023-25 bull run carry).
  USDJPY IS/OOS M2: IS 1.55 / OOS 1.09 = below 1.40 gate. Corr -0.075 excellent but edge doesn't hold.
  **→ ปิด symbol hunt นี้. Next: ไปต่อที่ #94 Donchian/Turtle หรือ retune EA_BREAKOUT_XAU Bars55.**

- [x] **EA_DONCHIAN #94 Turtle 55-bar (2026-06-27) — DEAD, ปิดแล้ว**
      Multi-symbol smoke (M2, 2023-2026, default Donch55+EMA200+ADX20):
      USDJPY full-period PF 1.34 (pass gate) → IS/OOS M2: IS 1.53 / OOS 0.81 ❌ (regime artifact = JPY mega-trend carry)
      XAU DonchPeriod sweep d8/d20/d40 (main MT5, M2, 2023-2026):
      d8 PF=1.17 / d20 PF=0.95 / d40 PF=0.93 — ไม่มีรอบไหนผ่าน 1.30 gate
      XAU channel-breakout edge ถูก capture ดีกว่ามากโดย EA_BREAKOUT_XAU (Bars55, H1-signal, OOS 2.94-4.87)
      **VERDICT: DEAD. Donchian concept ไม่มี additive leg ใหม่. อย่าสร้าง Donchian EA ใหม่อีก.**

- [x] **EA_PREVDAY (#9/#30 Prev-Day H/L breakout) = DEAD 2026-06-27 → RE-CONFIRMED (ORDER-114, 2026-07-16B)**
      XAU H1 PF=1.19/T=877. Rescue-close: buffer{0.1,0.3,0.5}×{H1,H4}×both-window Model-4 (12 runs) — ไม่มี config
      แตะ 1.2 both-window (ดีสุด b0.1-H4 1.07/1.06 = marginal churn, DD 22-72%). buffer lever swept = valid kill.
      Do not re-test Prev-Day H/L on any FX or XAU. verdict `_triage/_archive/verdicts/order104-126/ORDER114_PREVDAY_NR7_CLOSE_VERDICT.md`.

- [x] **EA_KELTNER (#62 Keltner Channel breakout) = DEAD 2026-06-27 → REJECT-CONFIRMED (ORDER-113, 2026-07-16B)**
      Rescue swept channel-def lever (EMAPeriod/KeltMult) × TF × both-window Model-4 บน USDJPY (16 runs) → ยืนยันตาย:
      **H4 = window-inversion** (BWD 1.22-1.48 แต่ MAIN 2023-26 พังหมด 0.71-0.76, DD 15%) = deploy ไม่ได้ ·
      **H1 = churn** (both-window 1.0-1.14 ไม่แตะ 1.2, 450-530t = spread-fragile). ไม่มี cell both-window ≥1.2.
      Build-on ปิด (breakout → regime-gate redundant · pending-limit ผิดทาง). original DEAD ถูก, ครั้งนี้ swept จริง.
      verdict = `_triage/_archive/verdicts/order104-126/ORDER113_KELTNER_RESCUE_VERDICT.md`. (contrast: ICHIMOKU revived under same treatment → กระบวนการทำงาน ไม่ใช่ rubber-stamp)

- [~] **EA_ICHIMOKU (#66 Kumo TK-cross + ADX) = ~~DEAD 2026-06-27~~ → REVIVED-PARKED (ORDER-112, 2026-07-16B)**
      ⚠️ "DEAD" ผิด — under-swept: เทสผิด symbol (XAU capped) + default periods เท่านั้น + ไม่เคยแตะ Kumo-period lever.
      **USDJPY (momentum→JPY-trender = บ้านถูก) + period sweep = both-window Model-4 บวก + plateau กว้าง (6/8 cell >1.1):**
      med-H4(12/34/68) 1.48/1.39 · slow-H1(20/60/120) 1.31/1.22 (ผ่าน ≥1.2 both). แต่ year-split = ทั้งคู่ 2 ปีขาดทุน
      (agg โดนปีเทรนด์กลบ) → ไม่ผ่าน all-years-positive = **PARKED-BUILD-ON ไม่ demo.** build-on lead: med-H4+slow-H1 ขาดทุนคนละปี
      → diversified basket (5/6 ปีบวก). verdict = `_triage/_archive/verdicts/order104-126/ORDER112_ICHIMOKU_RESCUE_VERDICT.md`.
      (เดิม: XAU H4 1.13/DD9.96 default — ceiling XAU breakout ~1.13-1.19 ยังจริงสำหรับ XAU; แต่ concept ไม่ตาย มันแค่คนละบ้าน.)

- [x] **concept A: EA_NR7 (#105 NR7 volatility breakout) = FULLY DEAD 2026-06-28**
      All smoked cells (M2, 2023-2026): XAU H4 PF=1.31, XAU H1 PF=1.30, XAGUSD H4 PF=1.40, USDJPY H1 PF=0.88, GBPJPY H1 PF=0.65, H4 GBPJPY/GBPUSD/USDJPY PF=0.90-1.16.
      IS/OOS on XAU H4: IS PF=1.08 FAIL / OOS PF=1.43 — regime artifact.
      IS/OOS on XAU H1: IS PF=1.06 FAIL / OOS PF=1.43 — identical artifact.
      XAGUSD H4 smoke PF=1.40 (161t) is the highest result — IS/OOS pending but structural pattern predicts IS failure.
      VERDICT: concept FULLY DEAD. 100% of NR7 "proceeds" exposed as 2025-26 bull run artifacts. Do not re-test NR7 on any instrument.
      **RE-CONFIRMED STRUCTURAL (ORDER-114, 2026-07-16B):** NR_Period{4,7,10,14}×{H1,H4}×both-window Model-4 (16 runs) =
      window-inversion 16/16 (MAIN 1.15-1.64 rides gold-bull, BWD 0.62-0.92 all-losing) + **DD 27-83% (blowup-level even
      flat-lot)**. Not just no-edge — structurally dangerous. period lever swept = definitively dead. `_triage/ORDER114_*`.

- [x] **concept B: EA_ASIANRANGE (#70 Asia→London range breakout) = FULLY DEAD 2026-06-28**
      Smoke (M2, 2023-2026): GBPJPY H1 PF=0.82/T=543, USDJPY H1 PF=0.96/T=501 → dead.
      Extended UTC+3 retry (2026-06-28): GBPUSD H1 PF=0.94/T=580, EURUSD H1 PF=0.96/T=572 → dead.
      All 4 tested cells across both session offsets = no edge. High T confirms signal fires often but is worthless.
      VERDICT: concept FULLY DEAD. Do not re-test Asia range breakout on any pair or session offset.

- [x] **concept C: EA_EURCHF bounded-range (BB+RSI mean reversion) = DEAD 2026-06-27**
      Smoke (M2, 2023-2026): EURCHF H4 PF=0.74/T=507/Win%=43.2% — worst of the batch.
      BB+RSI reversion on EURCHF: signal fires often (507 trades) but no edge. SNB management ≠ reliable mean-reversion.
      VERDICT: concept DEAD. Do not build EURCHF reversion EA.

- [x] **concept ใหม่ #2: EA_LNBREAK (London session range → NY open breakout) = DEAD 2026-06-28**
      Smoke (M2, 2023-2026): GBPUSD 1.07/476t, EURUSD 1.02, XAUUSD 1.07, USDJPY 0.87, GBPJPY 0.78.
      GBPUSD TP4×retry: PF=1.09 (win rate dropped 40%→35%, RR gain cancelled).
      Root cause: 40% WR × 1.5 RR = math breakeven. London→NY continuation has no directional edge.
      Deployed CB_GBP (LondonConsoBreakout, GBPUSD H1 OOS 2.08) already captures the better session concept.
      VERDICT: DEAD. Do not rebuild London→NY breakout on any pair.

### 🟢 re-examine ที่ค้างจากแผนเก่า (ยังไม่ได้ทำจริง)
- [ ] **R3: EURUSD Forex Robot (MT4)** — WATCH/PARKED (thin 48t). deep 30-mo IS/OOS multi-symbol ยังไม่ทำ. (`EA_SCORECARD` Part 3)

### ⚪ ปิดแล้ว / อย่าเสียเวลาซ้ำ
- Bucket D (martingale ports) = 0 survivors · CB new-symbol 4/4 DEAD · CB_EUR rescue DROP · R1 RSI_Swing / R2 TrendRegression = DEAD ·
  USDJPY breakout opt→REJECT · ST03 multi-symbol/SL/rearm = DEAD · MACD all-symbols exhaustive REJECT.
- **EA_SUPERTREND** = XAU-specific edge, 12-symbol hunt 0 additive legs · **EA_DONCHIAN** = 0 additive legs (USDJPY regime artifact, XAU below 1.30 all periods).
- ✅ **MT4 gold-grid re-test = DONE 2026-07-02** (`_archive_docs/MT4_GOLDGRID_RETEST_PLAN.md` §CLOSED) — Elephant/Mammoth
  artifact confirmed (PF 85→1.41 at Model 1, DD 53.65%/yr) · Gold Stuff V7 DQ confirmed (uncapped
  martingale + DD 77%/yr) · KRAPOOK not re-tested (expired, technique-only regardless). All 3 fail —
  gold-grid concept dead. Do not re-open without a different gold-grid EA.
- ✅ **Gold Reaper optimize = DONE 2026-07-02** — StartLots sweep was a null result (Risk=1234 internal
  variable mode ignores it); live set unchanged. See `EA_SCORECARD_AND_REGISTRY.md`.
- ✅ **#20 Trend+Pyramid = DONE 2026-07-02** — XAU H4 DEAD closes the last gap (full detail in the
  EA_EMATREND entry above in this section).
- **EA_EMATREND** (#20 EMA-cross trend follower) = **concept DEAD. 4 smoke PROCEEDs were all regime artifacts.**
  2015-2026 11-year checks: USDJPY PF 1.21 / GBPUSD PF 0.76 / GBPJPY PF 0.61. All three deeply negative in 2015-2022 era.
  The EMA20/50 cross H4 only worked in the 2022-2026 high-volatility post-COVID/BOJ/Brexit regime.
  Do not re-test any FX pair with EMA-cross H4 concept.
  **XAU gap closed 2026-07-02** (was "not fully tested"): /signal-scan via Boss_11_GridTrend chassis
  (MA20/50 cross, ATR-expand trend filter), IS-era 2023-2026 (the era EMA-cross performed BEST elsewhere),
  Model 2 ⚠️(SUPERSEDED-method note C5 2026-07-20: Model-2 = kill-only — ผล dead นี้ยังใช้ได้ แต่ถ้าจะ REVIVE ต้องวัดใหม่ M1/M4) — XAU H4 naked PF 0.87 (138t) → pyramid (StackMode 91) PF 0.99 (201t, DD 18→20%): **still dead,
  pyramiding does not rescue it** (more trades + more DD, no real PF gain — the "pyramid edge" the concept
  hoped for doesn't exist). GBP H4 same test: PF 1.02 single / 1.00 pyramid — breakeven noise, not an edge.
  **#20 Trend+Pyramid = fully closed, DEAD across the shortlisted symbols.** Do not revisit without a
  genuinely different entry mechanism (not MA-cross).

---

## 4. EA_TEMPLATE (Boss V2 chassis) — ต้องทำอะไรต่อ?

- **chassis เสร็จแล้ว** (Boss_11_GridTrend / Boss_12_Breakout / Boss_13_MeanRev compile 0/0). job ของ template (รันถูก+วัดเชื่อถือได้) = DONE.
- **optimize 0/7 ผ่าน** — Boss_11 MA-cross ไม่มี edge (suspend), Boss_12/13 thin.
- **คำแนะนำ:** อย่าสร้าง signal ใหม่ใน template เพิ่ม (เพดานเดียวกับทุกตัว). ใช้ template เป็น **เครื่องมือ** ทดสอบ
  hunt ข้อ 3 แทน — Boss_12_Breakout มีอยู่แล้วใช้ smoke EURCHF/NY-breakout ได้เลย ไม่ต้องเขียน EA ใหม่.

---

## 5. ที่มาของ to-do เดิม (รวมมาที่นี่แล้ว — ไม่ต้องไล่หา)
| ไฟล์ | สถานะ |
|---|---|
| ~~`_RESUME_HERE.md`~~ | archived → `_archive_docs/` (resume context รวมเข้าข้อ 3 + PROJECT_STATE) |
| `INTAKE_QUEUE.md` | Bucket D CLOSED · C/E = martingale skip |
| ~~`QWEN_WORK_PLAN.md`~~ | archived → `_archive_docs/` (Q1/Q2/R1/R2 DONE) |
| `EA_SCORECARD_AND_REGISTRY.md` | rubric + audit trail · Part 3 RE-EXAM → ข้อ 3 |
| ~~`MT4_GOLDGRID_RETEST_PLAN.md`~~ | archived → `_archive_docs/` (✅ CLOSED 2026-07-02, all 3 targets fail) → ข้อ 3 |
| `DEMO_DEPLOYMENT_PLAN.md` | live portfolio source of truth → ข้อ 3 |
</content>
</invoke>

<!-- sync test 2026-06-28 -->


---

## §CODEX-AUDIT missing controls (P1/P2) — ตบเข้าจาก `_triage\_archive\codex_reviews\system_and_roadmap\CODEX_AUDIT_FULL_2026-07-10.md` Layer E (REVIEW = taskboard §REVIEW CODEX-AUDIT 2026-07-11 · P0 ทั้ง 5 ข้อเป็น ORDER-092/093/083C แล้ว ไม่อยู่ในนี้)

### P1 — ต้องมีก่อน promotion รอบถัดไป / ระหว่าง operate
- [ ] **Live-vs-backtest drift monitor ต่อเนื่อง:** trade-rate interval, win/PF uncertainty, spread/slippage จริง, holding time, layer depth, MAE/MFE — ไม่ใช่รอ judge date อย่างเดียว (ต่อยอด ORDER-092 หลัง snapshot data ไหลแล้ว)
- [ ] **Promotion statistics:** min effective sample (ข้อเสนอ ≥100 trades/window — รอ user เคาะเข้า rubric), untouched holdout บังคับ, multiple-testing correction สำหรับ sweep ใหญ่, PBO/WFA ตัวที่เข้าเงินจริง
- [ ] **Evidence lineage:** hash source/binary/set/report/tester-build/history-range ของทุก verdict ที่เข้าเงินจริง · เลิก gitignore report ชี้ขาด (เคส Bars55 report โดนเขียนทับ = ตัวอย่างจริง)
- [ ] **Cage hardening = ORDER-094** (เปิดแล้ว — อยู่ taskboard)
- [ ] **Backup/restore drill:** VPS terminals · `D:\Monitor` · Common\Files · reports ที่ gitignore · sets · scheduler config — ซ้อม restore จริง 1 ครั้ง
- [x] **Credential inventory:** ✅ skeleton `docs/CREDENTIAL_INVENTORY.md` (2026-07-19, ORDER-119-wave ops) — ตาราง 12 แถว pre-populated (gist token + 7 บัญชี + investor-pw REAL 3 + VPS RDP) ช่อง Owner/Rotation/Recovery เว้นให้ user กรอก · ไม่มี secret ใน git
- [x] **Gist privacy:** ✅ redact เลขบัญชีใน published copy (2026-07-19) — `publish_dashboard_gist.ps1` mask ทุกบัญชีเป็น `...<last4>` บน `$tmp` ก่อน upload (local dashboard ยังเต็ม) · verified: 0 leftover, magic/dollar ไม่โดน clip, 21 masked tokens · ⏸ ยังเหลือ option "ย้ายช่องทาง private จริง" ถ้าต้องการมากกว่า mask
- [ ] **Judge date ต่อ cohort:** generate จาก DEPLOYMENTS.csv (ORDER-093) — ห้ามนาฬิกาเดียวทั้งระบบ (ชุด 07-09 judge = 2026-10-09, ชุดเก่า = ตามวัน attach จริง)
- [ ] **C5 hygiene:** ใส่ SUPERSEDED marker บน Model-2 conclusion เก่าในไฟล์นี้ (ห้ามลบ — mark ว่าใช้ตัดสินไม่ได้แล้ว)
- [x] **ST03 spacing probe:** ✅ ปิดแกน 2026-07-20 — 3 รัน M1 GBPUSD H1 (cell near-miss 12/26/9 cnt3, DCA L4, trail 23): FIXED 300pts PF 0.90 (986t) · ATR×1.0 PF 1.03 (2213t) · ATR×2.0 PF 0.94 (1254t) — เพดาน 1.03 = breakeven noise, **spacing ไม่ rescue, verdict ไม่เปลี่ยน**. หมายเหตุวิธี: chassis ไม่มี progressive-per-level step input → แกนปิดเป็น fixed/ATR1.0/ATR2.0 (standalone ST03 มี spacing กลไกต่างออกไป = ยังเป็น user lane ตาม `_triage/_archive/handoffs_closed/HANDOFF_ST03_OPTIMIZE_2026-07-19.md`). reports `ST03SP_*` · sets `_mt5_auto/ab_sets/st03_spacing_probe/`

### P2 — resilience/governance (ทำเมื่อ P0+P1 จบ)
- [ ] Attach/config/build attestation อัตโนมัติจากทุก terminal (รวม magic collision + hedging/netting mode)
- [ ] Broker reconciliation อิสระ: เทียบ statement + server-side SL presence
- [ ] Runbook มนุษย์ + backup operator (ตอนนี้ single-observer = user คนเดียว)
- [ ] Quarterly blind verdict audit + monthly control metrics (ตาม VISION เดิม)
- [ ] Schema validation/link check สำหรับ canonical docs (กัน drift แบบ C1 เกิดซ้ำ)


---

## §BUILD-ON ideas (lead thinking 2026-07-11 — เสนอ user เคาะทิศ, ยังไม่ commit เป็น order)

**1. 🏭 LLM-entry × Boss-V2-chassis = generation pipeline (ceiling สูงสุด, ตรงปรัชญาโรงงาน)**
user มี AI-LLM EA 10 ตัว (Scalper/Trend/Swing/Combine/News/Pending/Hedging/Martingale/Trailing/BO).
AI-gen EA มักมี **entry idea ที่พอใช้ได้ แต่ MM ห่วย/อันตราย** (AI-5 = martingale ตรง ๆ). → อย่า funnel
ทั้งตัว, **สกัดเฉพาะ entry signal → เสียบบน Boss V2 chassis** (ที่มี MM/SL/cap พิสูจน์แล้ว). ถ้า entry 2-3/10
มี edge = ได้ EA ใหม่ MM ปลอดภัยเกือบฟรี. scale ได้: "LLM เสนอ entry → chassis + funnel" = pipeline ผลิต
สัญญาณใหม่แบบทำซ้ำได้ = เหตุผลที่โรงงานมีแม่พิมพ์เดียว (edge=if สลับได้, MM=โครงคงที่). **ข้อเดียวที่ควรลอง
เป็น order จริงถ้า smoke AI-batch โชว์ entry ดี**

**2. 🔺 Triangular arbitrage = ตัว diversify พอร์ต (คุณค่าอยู่ที่ correlation ไม่ใช่ PF)**
NuiIndy Tri-Arb = กลไกที่ landscape ว่างสนิท. ตามหลัก 10 พอร์ต × EA ไม่ correlate: arb leg ที่ทำงานได้
= near-zero corr กับทุก trend/reversion/breakout ที่มี → **มีค่าเกินตัวต่อการประกอบพอร์ต แม้ PF ไม่หวือหวา**
→ ให้ priority funnel สูงเพราะ correlation value ไม่ใช่เพราะ PF (ถ้ารอด = ชิ้นส่วนพอร์ตที่หายาก)

**3. 🧰 read_text_robust() shared util (cheap infra win — queue ได้เลย)**
วันนี้เจอ encoding silent-failure 3 ครั้ง (PROJECT_STATE mojibake · 091A UTF-16 · 091B UTF-16). สร้าง
utility อ่านไฟล์ตัวเดียว (BOM sniff + NUL-density + cp1252-reverse detect) ให้ทุก script ใน repo เรียกใช้ →
ฆ่า bug class นี้ถาวร. เล็ก ทำเมื่อ lane ว่าง (ให้ qwen/agent) — เพราะจะแตะ intake scripts อีกหลายรอบใน 091

**4. 📉 fundability index เหนือ catalog 1,592 (เลิก triage มือ)**
มี flag เชิงโครงครบแล้ว (has_sl/escalation/cap/concept/crack) → เขียน score = (ความปลอดภัยโครง × ความ
หลากหลาย concept × ยังไม่มี verdict) จัดอันดับทั้ง 1,592 อัตโนมัติ → คิว funnel gen เองไม่ต้องเดา tier
(บทเรียนวันนี้: parser จัด non-fxDreema ไม่ได้ → ต้อง flag ให้ครบก่อน score)

**5. 📡 live drift-monitor (ต่อยอด 092 หลัง VPS attach)** — อยู่ P1 อยู่แล้ว · framing: เปลี่ยน "judge 3 เดือน"
เป็น early-warning ต่อเนื่อง (จับ EA ที่เริ่มตายตั้งแต่สัปดาห์ 2 ไม่ใช่เดือน 3) = โครงสร้างที่ทำให้เงินจริงปลอดภัยจริง


---

## §BUILD-ON #3 SHIPPED (2026-07-11): scripts\lib\robust_text.py
`read_text_robust(path)` = ตัวอ่านไฟล์ hardened ตัวเดียวของ intake pipeline. self-test ผ่าน 3 เคสจริงที่กัดวันนี้:
utf-8 ปกติ · UTF-16 มี BOM (BOT MOGUL html) · **UTF-16 ไม่มี BOM (ตัวที่ทำ 091A พลาด 374 ไฟล์) — roundtrip ตรง**
+ double-encoded mojibake reverse. **TODO adoption (qwen/agent ตอน lane ว่าง):** retrofit `fxdreema_xray.py`,
`order091a_intake.py`, `botmogul_parse.py` ให้ import ตัวนี้แทน read_text() เดิม → ปิด bug class ถาวร
(ตอนนี้แต่ละ script มี BOM-sniff ของตัวเอง กระจาย — รวมเป็นตัวเดียว)

---

## 9. DORMANT BACKLOG — งานที่มีเงื่อนไขปลุก (เก็บกู้จาก handoff 2026-07-26)

> **ที่มา:** 2026-07-26 กวาด `_triage/HANDOFF_*` 17 ใบ เจอ **27 รายการที่ไม่เคยเข้า `AGENT_TASKBOARD.md` เลย**
> 6 ใบเร่ง → ORDER-230..235 · 4 ใบพร้อมทำ → ORDER-236..239 · **ที่เหลือ 16 ใบอยู่ตารางนี้**
>
> ตารางนี้ไม่ใช่ที่ทิ้งขยะ — มันคือ **order ที่ยังไม่เกิดเพราะเงื่อนไขยังไม่มา**. ทุกแถวต้องมี `ปลุกเมื่อ` ที่เช็คได้จริง
> ถ้าเขียน `ปลุกเมื่อ` ไม่ได้ = มันไม่ใช่งาน dormant มันคืองานที่ตัดสินใจไม่ทิ้งไม่ได้ → ต้องเปิด order หรือปิดทิ้งไปเลย

| # | งาน | ปลุกเมื่อ | หลักฐานที่มีแล้ว |
|---|---|---|---|
| D1 | Boss_16 ก่อนสลับ binary ต้องเช็ค F3 หา GV `k16_pair_a/b` (มี = pair liquidation ค้าง ต้องเคลียร์ก่อน) | **มีคนจะ attach/สลับ binary Boss_16** — เร็วๆ นี้จริง (ORDER-213 bundle รออยู่) | ORDER-138 pair-persist · `_vps_deploy/BOSS16_KANGAROO_XAU/` |
| D2 | X1 milestone persist ข้าม restart · S1/S2 ladder restart-cancel reconcile · S3 margin re-budget ต่อเนื่อง | **EA ที่ใช้ StackMode=93 หรือ partial-close ขึ้น live จริง** | `_triage/_archive/codex_reviews/order129_132_138/CODEX_ORDER132_AUDIT.md` (defer pack ของ ORDER-132b) |
| D3 | ขุด QuantCorner FB ย้อนหลัง | **user ส่ง permalink มา** (feed อ่านอัตโนมัติไม่ได้ — scrollHeight ค้างที่ 2406 เห็นแค่โพสต์ปักหมุด) | memory `quantcorner-findyour8-idea-catalog` |
| D4 | แกะ PDF ทฤษฎี 11 ใบที่เหลือ (Vanguard / Risk-Parity / Mudley) | **คิว build ว่าง** หรือ **จะเคลียร์ `findyour8_pdfs/`** (โฟลเดอร์ gitignore — เคลียร์แล้วของหาย) | `_triage/FINDYOUR8_STRATEGY_PDF_CATALOG.md` · EDGE_CATALOG IDEA SEEDS #9 |
| D5 | Wave-3 XAU 3 ดีไซน์ที่ไม่เคยสร้าง: S6/SS5 squeeze-micro · SS3 VWAP reversion · S3 Asian fade | **เปิดรอบออกแบบ XAU ใหม่** | `_triage/_archive/frameworks_superseded/XAU_STRATEGY_WAVE12_2026-07-19.md` บรรทัด 34 (ช่องว่างในโรสเตอร์) — ⚠️ VwapSnapback_EUR / AsianDriftCarry_XAU ที่มีอยู่ **คนละเซลล์** ไม่ใช่ตัวนี้ |
| D6 | สมมติฐาน: ความกว้าง SL เทียบ noise floor เป็นตัวทำนายว่ารอด M1→M4 ไหม | **ทำได้เลยเมื่อว่าง** — falsify ถูกจาก corpus ที่มีอยู่ ไม่ต้องรันใหม่ | PivotBreakout + SS1 (SL กว้างตาม ATR = รอด) vs MomentumBurst (SL 40pt = พังบน real tick) |
| D7 | ยัด `Exit_DynCloseTargetMoney()` เข้า Kangaroo | **หลัง review เจ้าของ exit ก่อน** (Kangaroo มี `Kangaroo_NextLot()` + exit path ของตัวเอง — ชนแน่ถ้าไม่ดูก่อน) | ORDER-098-C build ไว้แล้ว (`bd709fca`) · ORDER-197 body |
| D8 | พอร์ตเกินงบ 25% — จะ resize / ถอด / ยอมรับ | **ORDER-233 audit ผ่าน** (ตัวเลขจะขยับจาก 73% เป็น 38% ถ้า flag เปิด — ตัดสินก่อน audit = ตัดสินบนเลขที่ยังไม่รู้ว่าใช้ได้ไหม) | `scripts/portfolio_risk_admission.py` · `6f49e0b7` |
| D9 | ยืนยัน MT5 local agent = 18 ตัว (Core 02/03 ปิด) | **ทำได้เลย 30 วินาที** หรือ Claude ใส่ assert ใน `mt5_optimize.ps1` | genetic policy `b9ba8c84` |
| D10 | เช็คว่า bundle ที่ staged อยู่ ถูกลากขึ้นชาร์ตจริงกี่ตัว | **CR-P0 sensor กลับมา** (2 บัญชีตอนนี้ไม่มี sensor จะเช็คด้วยซ้ำ) | `portfolio/DEPLOYMENTS.csv` · 24 bundle ใน `_vps_deploy/` · sweep `85b55fd9` ตอบคนละคำถาม (evidence ไม่ใช่ attachment) |
| D11 | re-pin `$mainEnd` ในกรง holdout ตอน MAIN เลื่อน | **MAIN เลื่อน (ราว 6 เดือน = ~2027-01)** — ต้อง**ประกาศ holdout ใหม่ก่อน** แล้วค่อยขยับ | `scripts/check_state.ps1` §9 · กฎเหล็ก MAIN ∩ HOLDOUT = ∅ |
| D12 | MRIS core ยังไวเกิน — 2019 อ่านได้ 48% risk-off (จาก 88%) หลังแก้ pin | **ก่อนตัดสิน crisis-fold (ORDER-200 Phase D)** เพราะ fold กิน classifier ตัวเดียวกัน | ORDER-203 verify (`1cc84314`) · memory `absolute-price-constant-poisons-backtests` |
| D13 | ST03 lever 2: TP ต่อ symbol × exit-mode | **user เปิดเลน optimize มือ** — ⚠️ worktree `great-mendeleev-a35c44` **หายแล้ว** เหลือแค่ `ST03_optimized_v2.set`/`v1.set` และ **ไม่มี .mq5 ของ `EA_RUNNER_ST03` มีแต่ .ex5** · ห้ามใช้ `st03_spacing_probe/` (นั่นยิงใส่ `Boss_15_ST03` คนละตัว) | ORDER-201 (ปิด lever 1 = spacing, ไม่ช่วย) |
| D14 | ST03 lever 3: ความลึก LOT_Repeat × vol-gate | เหมือน D13 · ถ้าตัวชนะพึ่ง escalation ⇒ เข้ากรง ENGINE-EDGE 5 ข้อ | `ST03_volgate_v1.set` · `ST03_lr2_v1.set` |
| D15 | PA_LotMult ตาม tier ของ Bulkowski (Step 3 ของสแตก PA/MM) | **หลังพิสูจน์ว่า PA ยก expectancy ได้จริงก่อน** — ตอนนี้ยังไม่มีหลักฐานนั้น | `ea_projects/(TRD)_PA_Probe/FINDINGS.md` = PA ช่วยตอน "เติมไม้" ไม่ใช่ตอน entry |
| D16 | SMC / S-R เป็นชั้น confluence (ห้ามใช้เปล่า) | เหมือน D15 | naked FVG ตายแล้ว (098-A) · SMC×STO ได้แค่ candidate (LANEC-FAN, SL เปราะ) |
| D17 | Wave5 3 ขา (990301/302/303): รัน MAIN สะอาด `2023.01.01→2025.12.31` Model-4 full pinned .set | **ก่อน judge 2026-10-16** — ตอนนี้เลข MAIN ของ config ที่ deploy ไม่เคยวัดบนข้อมูลที่มันไม่เคยเห็น (ranked grid ทุก cell จบ `2026.07.01`) | `ORDER202_..._RETROSCAN.md` Part 4 · `AUDIT_BUNDLE_EVIDENCE_G2.md` §1-3 · banner ติดใน bundle แล้ว · ⚠️ XAU ต้องเขียน `_17_UseStructLevels` ลง ini ด้วย (re-validation เดิมไม่เขียน = cache risk) |
| D18 | ติด banner กล่องกลุ่ม 1 ที่เหลือ 6 ใบ: `ZEUS_AUDJPY_REGIME` · `ICHIADX_XAU` · `ICHIADX_USDJPY_BASKET` · `SMCSTO_EURUSD` · `CB_GBP` · `RSI_MR_EURUSD` | **ทำได้เลยเมื่อว่าง** — เป็น HOLDOUT-SPENT/contaminated จริง แต่ไม่มีคำสั่งค้างให้ใครหยิบไปทำ จึงไม่เร่ง | `AUDIT_BUNDLE_EVIDENCE_G1.md` (ตาราง label ครบแล้ว) · ⚠️ ICHIADX 2 กล่อง ACTIVE 4 magic **ไม่มีแถวในทะเบียนเลย** — ข้อนั้นเร่งกว่าเพื่อน |
| D19 | NuiIndy `CutLoss=30` (เงินจริง): รัน base control ที่ขาด — `CutLoss_Percent=100` EURUSD H1 `2022.01.01→2023.01.01` | ✅ **ปลดล็อกแล้ว — user เคาะกฎ guard 2026-07-26 (เข้า CLAUDE.md แล้ว) ⇒ ทำได้เลย** | run เดียว เทียบกับ `NUI_EURUSD_cut30only_2022` ที่มีอยู่ · ที่มา = retro-scan Part 3 · ตอนนี้**ไม่มีหน้าต่างไหนเลย**ที่ cut30 ถูกวัดเทียบ control |
| D21 | 🔴 **เงินจริง** `(BRK)_TrendlineBreakout` 991002: live รัน `_02_TpAtrMult=8.0` แต่ default ของ `rev01` = 4.0 — ใครเลือก 8.0 บนหน้าต่างอะไร | **ทำได้เลย (อ่านอย่างเดียว ห้ามแตะบัญชี/ห้ามรัน tester)** — ไล่ `_mt5_auto/ini` + CSV หา run ของ `rev01` ที่มี `_02_TpAtrMult`; เจอการเทียบหลายค่า + หน้าต่างเลย `2025.12.31` = contaminated selection บนเงินจริง; ไม่เจอ 8.0 เลย = ค่านี้ไม่มีหลักฐานรองรับ (รายงานตรงๆ) | ⚠️ ใช้**นิยาม selection ที่แก้แล้ว** ไม่ใช่ flag (`RETROSCAN` Part 4) · **ปิดไปแล้วในใบนี้:** live = `rev01` **ไม่มี ADX gate** ⇒ `_04_UseAdxGate` ไม่ applicable (A/B `TL2*` รันบน `_rev02` คนละไฟล์) และผลนั้นแปลว่า **ห้ามอัปเกรดเป็น rev02** (gate แพ้หน้าต่างล่าสุด 0.99 vs 1.23) |
| D22 | ตรวจ 3 clearance ของ ORDER-202 ใหม่: `EmaStoRev` 991070 · `MacdDiv_Naked` 999094 · `EA_DONCHIAN` 990030 | **ทำได้เลย** — ทั้งสามถูกเคลียร์ด้วยประโยค "optimize passes จบที่ 2026.01.01" = ใช้ flag เป็นตัวกรอง จึงรับ blind spot มาเต็ม | หา `*_results.csv`/`*_OPT.csv`/`run_*.ps1`/กลุ่ม `.ini` family เดียวกันที่เอาหลาย cell มาเรียง · ป้ายที่ต้องได้: `CLEARED (traced)` / `CONTAMINATED-SELECTION` / `UNCERTAIN` — **ห้ามสรุป clean เพราะไม่เจอ** |
| D23 | รีวิว grandfather allowlist ใน `scripts/check_order_collision.ps1` — `098-C` **ไม่ซ้ำแล้ว** (ทั้ง 2 บล็อกเข้าคลัง 2026-07-26) และ `200` ก็เข้าคลังไปแล้ว เหลือ `095`/`082` ที่ยังซ้ำจริง | **ทำได้เลย** — allowlist ที่กว้างเกินความจริงคือ guard ที่อ่อนลงเงียบๆ ไม่มีใครรู้ | ตั้ง allowlist ตอน `ad470945` ตอนนั้น 4 ตัวซ้ำจริง · หลัง `247ed9c4` เหลือ 2 · ผล `[order-collision] NOTE:` ในทุก commit บอกสถานะปัจจุบันอยู่แล้ว |
| D24 | `run_order101_negative_tests.ps1` + `run_order103_negative_tests.ps1` **รันต่อกันใน process เดียวไม่ได้** — วัด 2026-07-27: รันแยก = 25/1 และ 41/0 · รัน 101 แล้ว 103 ต่อใน `foreach` เดียว = 103 พังหลายเคสด้วย `archive path 'ARCHIVE.md' not readable at <sha>` (น่าจะชน temp fixture dir / leftover git state) | **ก่อนจะมีใครเขียน "รันเทสทั้งหมด" เป็นสคริปต์เดียว** หรือใส่ทั้งคู่ลง CI/hook | ผลข้างเคียงที่แพง: คนรันทั้งชุดจะเห็นกำแพง FAIL ปลอม แล้ว**เรียนรู้ที่จะไม่เชื่อกรง** = anti-pattern เดียวกับกรงที่ไม่เคยรัน (ORDER-270) · ทางแก้น่าจะแค่ให้ fixture dir unique ต่อ run หรือ cleanup ให้สุดใน `finally` · **⚠️ UPDATE 2026-07-27 (SYSTEMS): อาการนี้เลิก reproduce แล้วหลังแก้ ORDER-411** — รัน 101→103 ต่อกันใน process เดียว (881 วินาที) ได้ **103 = ALL CASES PASSED · `not readable` = 0 ครั้ง** · 101 เหลือ FAIL เดิมตัวเดียว (`cross-HEAD-zero-diff`, documented) · **error string ที่ D24 บันทึกไว้ = ของ ORDER-411 เป๊ะ** (BOM บน stdin ⇒ request แรกของ `cat-file --batch-check` เสีย) และกลไก "พังเฉพาะเมื่อรันต่อจาก 101" เข้ากับ **session-dependence** ของบั๊กนั้น (ถ้าชุด 101 ทิ้ง `[Console]::InputEncoding` ที่มี preamble ไว้ ชุด 103 จะรับเคราะห์) · **แต่ผมไม่ได้ reproduce ก่อนแก้** ⇒ **สาเหตุ = อนุมาน ไม่ใช่พิสูจน์** · ยังไม่ปิดแถวนี้: ถ้าใครเจอซ้ำ ให้ดู `[Console]::InputEncoding` ก่อน fixture dir |
| D28 | **กรงช้า 4 ชุดยังไม่มีตัวปลุก** — `run_chainwalk_tests` (74s) · `run_order101_negative_tests` (~120s) · `run_order103_negative_tests` (~760s) · `run_order105_negative_tests` (521s) · ORDER-420 เสียบเฉพาะ **fast tier** (3.8s) เข้า pre-commit เพราะ hook 10 นาที = hook ที่โดน `--no-verify` | **ปลุกเมื่อ:** ก่อน promote เงินจริงครั้งถัดไป · หรือเมื่อแตะ `check_taskboard_archive.ps1` / `check_experiment_events.ps1` แรงๆ · หรือถ้ามีวันที่เครื่องว่างยาว | ทางเลือกที่ยังไม่เคาะ: (a) scheduled task กลางคืน (b) `pre-push` แทน `pre-commit` (c) สคริปต์ `run_slow_cages.ps1` ที่คนเรียกเอง — **ห้ามยัดเข้า pre-commit** ประเด็นทั้งหมดของ ORDER-420 คือ hook ที่ช้าจะถูก bypass · **ORDER-421 ต้องปิดก่อน** ไม่งั้น 105 จะแดงค้างในทุกการรัน |
| D27 | **`TASKBOARD_DIGEST.md` แสดง order ที่ REVIEWED แล้วว่าเป็น `DONE`** — วัดจริง: header ทรง `DONE + REVIEWED(attr)` (ของ ORDER-390) → digest แสดง `DONE + REVIEWED` ✅ แต่ทรง `DONE(attr) + REVIEWED(attr)` (ของ **341 · 370 · 411 · 412**) → digest แสดง **`DONE`** ❌ | **ทำได้เลย — แต่ต้องรอจังหวะที่ไม่มีเลนอื่นถือ `AGENT_TASKBOARD.md`** (2026-07-27 SLBUFFER ถืออยู่ ⇒ ใบนี้เลยลงเป็นแถว backlog แทนที่จะเป็น order · **ปลุกเมื่อ:** บอร์ดว่าง แล้วยกเป็น order ทันที) | digest ประกาศตัวเองว่าเป็น **"ชั้นที่มนุษย์อ่าน"** ⇒ 4 ใบที่ review แล้วโผล่เป็น `DONE` · ใครกวาดหางานที่ยังไม่ review จะหยิบผิดทั้ง 4 · **คลาสเดียวกับ ORDER-260 (substring) · 390 (nested backtick) · `($pipeline).Count` (370) = ครั้งที่ 5 ใน 8 วัน: parser อ่านสถานะไม่ตรงกับที่คนเขียน แล้วพังเงียบ** · **ห้ามแก้ด้วยการไล่แก้ข้อความ 4 ใบ** (คนถัดไปจะเขียนทรงเดิมอีก — ใส่ attribution ให้ทั้งสองกริยาเป็นเรื่องปกติ) → แก้ที่ `scripts/make_taskboard_digest.ps1` ให้เก็บกริยา terminal ที่**แรงสุด** ไม่ใช่ตัวแรกที่เจอ (precedent = ORDER-341 ranking) · **กรงมาก่อนแก้ + ต้องกิน header จริงจากบอร์ด/คลัง ห้ามประดิษฐ์** (ORDER-260 พิสูจน์ว่าบั๊กตระกูลนี้มองไม่เห็นด้วย input สังเคราะห์) · **ห้ามแตะ `Get-StatusClass`** — มันอ่านถูกอยู่แล้ว ใบถึงย้ายเข้าคลังได้ |
| D25 | คลังดิบก้อนใหญ่ยังนั่งในเรโป — `_triage/findyour8_pdfs/` **888MB** (gitignored) + corpus 8 โฟลเดอร์ (`*_youtube/`, `chatgpt_convs/`) · `fxdreema_youtube/` **tracked ครึ่งเดียว** จึงต้องแยกทีละไฟล์ ย้ายรวดเดียวไม่ได้ | **รอ user เคาะ** ว่าจะย้ายออกนอกเรโปไหม — ไม่ใช่งานที่ Claude ตัดสินเองได้ เพราะกระทบที่เก็บของ user | ลอยข้าม handoff มา 2 ใบแล้ว (`WORK_LIFECYCLE` 2026-07-26 → SYSTEMS 07-27) โดยไม่มีที่อยู่ · ลงแถวนี้เพื่อให้เลิกลอย ไม่ใช่เพื่อเร่ง · **ห้ามลบอะไรเอง** — gitignored ไม่ได้แปลว่าทิ้งได้ |
| D28 | citation ค้างชี้ `PROJECT_STATE.md §7 "SESSION 2026-07-08" block` ที่ถูกย้ายเข้า `PROJECT_STATE_SESSIONLOG_ARCHIVE.md` ไปนานแล้ว — 2 จุด: `AGENT_TASKBOARD.md:1106` (แถว order ของ session อื่น ห้ามแก้ตรงๆ) + `handoff/SESSION_2026-07-09_HANDOFF.md:4` · **stale มาก่อนการแปลเอกสาร 2026-07-27 ไม่ใช่ของใหม่** | **เมื่อแตะ 2 ไฟล์นั้นด้วยเหตุอื่น** (แก้ตอนนี้ = แตะแถวของ session อื่นโดยไม่จำเป็น) | grep 2026-07-27: `PROJECT_STATE §7 "SESSION 2026-07-08"` ไม่มีอยู่ใน `PROJECT_STATE.md` แล้ว |
| D20 | `live_deals` ไม่มีคอลัมน์บันทึกไม้ที่ถูกบล็อก / kill ที่ทำงาน | **เมื่อแตะ exporter รอบหน้า** (CR-P0 กำลังทำ exporter อยู่ = จังหวะดี) | ผลข้างเคียง: ไม่มีอะไรในบันทึกจริงยืนยันได้ว่า guard ตัวไหนเคยทำงาน ⇒ ความเชื่อ "เดี๋ยว guard รับ" ทุกข้อพิสูจน์ผิดไม่ได้ · `AUDIT_GUARDS_NEVER_FIRED.md` |
| D26 | 🎯 **แยกบัญชี NuiIndy (magic 1524) ออกจาก 159475669** — เปิดบัญชี cent ใหม่ ใส่เงินเท่าที่ยอมเสียหมดได้ แล้วย้าย 1524 ไปอยู่ตัวเดียว | **user เคาะแล้ว 2026-07-27 = plan of record** · งานโบรกเกอร์ ทำแทนไม่ได้ · หลังย้ายเสร็จต้อง: อัปเดต `portfolio/DEPLOYMENTS.csv` + `portfolio/ACCOUNTS.csv` · แก้ `BG_PINNED_ACCOUNT` ใน `(Boss)_BasketGuard.mq5` แล้ว**คอมไพล์ใหม่** (มัน pin บัญชีไว้ตอน compile จะไม่ยอมรันบนบัญชีใหม่) · ตั้ง kill_rule ของบัญชีใหม่ | เหตุผลเต็ม = `ea_projects/(Boss)_BasketGuard/AUDIT_2026-07-27_CODEX.md` · **กรงแบบ EA มัดความเสียหายทั้งรอบไม่ได้**: นับเฉพาะ floating ณ วินาทีนั้น ⇒ loss ที่ถูก realize ระหว่าง poll หายจากสมการ + stop-out ของโบรก**ไม่สนใจ magic** จึงฟัน EA ตัวอื่นอยู่ดี ⇒ เพดานต้องมาจากโครงสร้างบัญชี ไม่ใช่ซอฟต์แวร์ |
| D29 | **Hand-maintained IDs and summaries in the control docs drift and collide, and both live instances were found on the same day.** (1) `docs/SESSION_LEDGER.md` "numbers used" block still read *max = 280, next free = 420-429* while the rows immediately above it showed **412 · 420 · 421** in use — a session trusting the two lines that exist precisely to be trusted would have reserved a taken block and collided on its first commit (corrected in-place 2026-07-27 by `S-2026-07-27-QUEUE`, but only the values, not the mechanism). (2) **`MASTER_BACKLOG.md` has two different rows both numbered `D28`** — the slow-cages row (CAGERUN) and the stale-citation row (DOCS-EN), written hours apart into the same table. | **Wake when:** the next session opens a lane, or anyone adds a backlog row — whichever comes first. Cheap either way; the D28 rename is a two-minute edit that needs no lane to own it. | Fix (1) by **deriving the summary from the tables** instead of restating them, so it cannot disagree with them; fix (2) by renumbering one D28 and adding a duplicate-ID check wherever the backlog is parsed. **Same family as ORDER-260 / 341 / 390 / 411 / D27** — the artifact keeps being produced and quietly stops being true — with one difference worth naming: those were parsers misreading correct data, this is **correct parsers reading data a human forgot to update**. A guard that only checks format would pass both of these. |

<sub>**ของแถมที่เจอตอนกวาด (ไม่ใช่ backlog แต่คือความจริงที่บันทึกผิด):** SS2 NyIgnition optimize **รันไปแล้วจริง**
(`a88db4c6`, 2026-07-23 — `_mt5_auto/SS2_NYIG_BOTHWINDOW.csv` 6 เซลล์ ดีสุด 1.05/1.16 `candidate=no` ทุกเซลล์)
แต่ `EA_SCORECARD_AND_REGISTRY.md:252` + `EA_MASTER_INDEX.csv:142` ยังเขียน "ยังไม่ optimize — คิว Wave-3" อยู่ —
งานเกิดแล้วแต่ verdict ไม่เคยถูกเขียนลง. ต้องแก้ 2 แถวนี้ (session คู่ขนานถือไฟล์อยู่ 2026-07-26 → ทำตอน lane ว่าง)</sub>
| D30 | **Factory OS design failed three blind audits; the fourth pass is preparatory orders only.** Design = `_triage/EA_LAB_FACTORY_OS_DESIGN.md`, audits = `_triage/factory_os/CODEX_{BLIND_AUDIT,REAUDIT,AUDIT3}_2026-07-30.md`. Verdict after audit 3: **S2a** (ownership proposal + migration table) and **S3a** (validator + regression fixtures) may be written as orders; **S2 canonical transfer is blocked on `MASTER_BACKLOG`'s owner approving the Coverage ownership move**, and **S4 is blocked** because `ControlRoomSnapshotV5` does not carry the meta/source fields the real v4 snapshot has. | ✅ **Orders written 2026-07-30, rev 2 after Codex audit 5** — `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md` holds **ORDER-600 (S2a)** and **ORDER-601 (S3a)**, pasteable verbatim; numbers reserved to lane `S-2026-07-30-CONTRACTGEN`, block 600-609. **They are NOT on `AGENT_TASKBOARD.md`** — a concurrent lane held that file for the whole session (ledger rule 4), so pasting them is the next session's first act once the board is free. **ORDER-601 part 1 is already built** (`c8d03d4b`: evidence/verdict split, 28 ajv fixtures). ✅ **Part 2 is built too — `4a4d6003`, lane `S-2026-07-30-CONTRACTGEN2`:** `_triage/factory_os/snapshot_validator.py` (13 predicates, one per closed reason code; `verify_snapshot` **recomputes the verdict on read** and refuses audit 5's hand-authored `sources=[]`+`all_clear=true` instance; freshness derived from the supplied `stale_bar_hours`, no hardcoded threshold) · `run_snapshot_validator_tests.py` (**27 fixtures, one-field minimal pairs asserting exact `(code,detail)`, paired repairs, 2 independent positives**) · `SNAPSHOT_VALIDATOR_MUTATION_TABLE.md` (**13 mutations, only the named fixture may go red**; `--prove-harness` plants an unexercised predicate and asserts the analysis names it). The V5 root is now closed and the source row carries the real v4 `{path,sha256,mtime}`; ajv 28 → 35. <br>🔎 **Blind-audited by Codex the same day** (`_triage/factory_os/CODEX_AUDIT6_2026-07-30.md`, verdict **ORDER-601 NOT DONE**) — and the finding was the NAME, not the arithmetic: a snapshot with a `NO_SENSOR` fleet sensor, a `BLIND` floating-risk sensor, missing kill/judge controls, an `UNCLASSIFIED` unknown magic and missing attestation verified **`all_clear=true`**, because `facts_of()` reads `meta.reconciliation` and the source rows and nothing else. Acted on in `161d2033`: renamed to **`reconciliation_clear`** with the exclusions stated in schema, module and design §3 (making it global needs health contracts for 7 domains that are `array of arbitrary object` today ⇒ **S4**, not a rename) · the schema gate accepted **any callable** so "skipping is greppable" was false ⇒ two legal values + `load_verified()` takes none · `duplicates:-1` computed clear (`>0` test, no lower bound in code) ⇒ refusal · `all_clear:"yes"` verified via `bool()` coercion ⇒ type refusal · a **count-based** membership predicate passed the whole suite AND a perfect mutation table ⇒ identity-swap fixture · all 30 design links hidden in one HTML comment returned CLEAN ⇒ visible-markdown only. `--prove-harness` now sabotages the 3 non-predicate mechanisms too. ajv suite batched **11.5s → 1.8s** (still unwired: the tier has no headroom, median **14.8s**/15.0s with one run at 15.5s — the budget is **advisory**, it warns and exits 0). ⚠️ **Still weaker than it sounds:** `verify_snapshot` proves **internal consistency, not authenticity** — every source row pointed at a nonexistent drive with `mtime 2099` was accepted, because the evidence being recomputed is itself supplied. Deriving/hashing it = S4. <br>🔻 **The open work this row still owns: pasting ORDER-600/601 onto the board** (SENSFAN has held `AGENT_TASKBOARD.md` since 2026-07-30 05:5x under a user instruction to hold all commits) **and ORDER-600 / S2a itself, which is untouched.** <br>**S4's blocker is now partly cleared and precisely measured** (2026-07-30): the three meta fields audit 3 found dropped are carried, and the row metadata is expressible. What remains is identity and evidence — root missing `entity`,`verdict` · meta missing `build_id`,`mandatory_sources`,`reconciliation` · row missing `name`,`mandatory`,`read_ok`,`fresh` (the real rows are `{path,sha256,mtime,age_hours}` and carry no name at all). **Reconciling `path` with `name` as the identity is a decision that belongs with the readers, which is why it is S4 and not this row.** Audit 5 verdict = GO WITH AMENDMENTS; every amendment is folded into rev 2. | *(original wake condition:)* a session opens with enough context to write orders — not at the end of one. The three user decisions in `PROJECT_STATE.md` §7 block different slices and can be answered independently. | Real validation now exists: `_triage/factory_os/run_schema_fixtures.py` (ajv draft-2020-12, 17 cases, one per audit finding, both directions). Its last line prints whether the **real** `control_room_snapshot.json` validates — **it does not, and S4 is not done until it does.** |
| D31 | **Normative contracts are hand-maintained in two places — the design prose and the schema — and nothing binds them.** Every regression across three audits came through that seam, including one that recurred *inside the commit that installed the checker meant to prevent it*, which reported `STRUCTURE OK`. Audit 3 measured the checker against its own 7 REGRESSED findings: it would have caught **0 of 7** semantically. | ✅ **MECHANISM BUILT 2026-07-30** (`8cbb44e6`, lane `S-2026-07-30-CONTRACTGEN`) — `_triage/factory_os/gen_design_contracts.py` generates **30 blocks** (27 entities + storage/ownership table + 2 non-entity contracts) from `schemas.json`; `--check` exits 1 on drift and **refuses if any `$defs` entity has no block anywhere**. <br>📦 **Relocated 2026-07-30 (`87af43fd`), which was this row's last open item:** the blocks no longer sit in the design — they are generated into **`_triage/factory_os/CONTRACTS.md`** (786 lines, 100% generated, each block opening with its own `### <key>` heading) and the design **links** to them: **1807 → 1166 lines**, against a §7.4 that is about reading the design without exhausting context. Recommended independently by this seat and Codex audit 5 Q4. Moving them cost the one property that held by construction — *the design states this contract* — so `validate_links` now refuses a missing link, a dangling link, and a link whose name and destination disagree, **with a negative fixture for each** (binding suite 18 → **22 cases, still 7/7**). The marker protocol was deliberately KEPT: dropping it was available, but its two historical defects each have a passing negative fixture, and trading three specific guards for one general one is not obviously an improvement — what moved out is the hand-written narrative that made those defects reachable. `run_contract_binding_tests.py` re-applies all **7 REGRESSED findings as schema mutations: 7/7 caught (was 0/7)**, with 3 controls green (no-op · rationale-only · deleted block). Cage `scripts/_test/run_contract_binding_tests.ps1` is in the pre-commit fast tier (12.9-13.3s of 15s, 11/11) and was **mutation-tested** — typing `attempts[]` back into the run table by hand turns it red naming the line. <br>🔎 **Audited blind by Codex the same day** (`_triage/factory_os/CODEX_AUDIT4_2026-07-30.md`) — **4 code defects found in the binding itself, all reproduced then fixed in `1ad7b17d`**: nullable nested objects (`lease` · `process_observed` · `safe_range` = `["object","null"]`) were never walked so their required sets vanished from the design while the schema still carried them; conditionals with a bare `required` in the `if` were skipped, which is exactly the shape of WorkReceipt's anti-copy ownership rule — Codex deleted that rule and the document did not move; the deleted-block control was **tautological** (asserted the deleted key was absent, never called the coverage path); unpaired BEGIN/END markers passed everything. Two of Codex's own failing cases are now fixtures. 15/15 binding · 17/17 ajv · tier 11/11 at 13.4s. <br>🔻 **Still open, and this is the honest limit — do not read "D31 built" as "the design can be hand-revised freely":** (1) **the fixtures are synchronization checks, not behavioural oracles** — they prove the design states what the schema states, never that either is right (Codex Q1; the non-tautological versions it specifies are per-defect *validator* tests, e.g. "an ExecutionKey with no deposit must be rejected", not "the table changed"). (2) **Normative prose outside generated blocks still drifts freely** — Codex flipped §6.4 from "every A/B on one lane" to "may cross lanes" and every cage stayed green. (3) **`x-enforced-by` still names validators that do not exist** — but **not `snapshot_validator` any more**: it exists as of `4a4d6003`, and the `sources=[]` + `all_clear=true` snapshot that used to validate is now refused by recomputation on read (ORDER-601 part 2, under D30). The other names remain aspirational, and each one is a claim the document makes that nothing enforces. (4) **`_why` can hold normative text unrendered.** §3 state machines · §5.3–5.5 · §6 · §7 remain unbound prose. | Fix per audit 3: generate the design's contract tables from one machine-readable manifest, let prose carry only rationale, and **never call a finding fixed until a negative fixture for that specific defect fails before the fix and passes after** — the discipline Stage 0B used the same morning, where every guard was mutation-tested before it was believed. |
| D32 | **The pre-commit fast-tier trigger is a hand-enumerated path glob, and it has silently missed the guarded files four times in four days.** `.githooks/pre-commit:115` lists directories that *happen to* hold guarded files (`scripts/check_*.ps1` · `scripts/_test/*` · `scripts/mris/*` · `scripts/lib/*` · `scripts/*.ps1` · now `_triage/factory_os/*`). Each new cage guarding a file outside that list is **enforced only when something unrelated is staged alongside it** — it looks enforced and is not. ORDER-434 · ORDER-500 · ORDER-372 each widened it, and the ORDER-500 comment predicted the recurrence in writing. **BACKLOG-D31 is the fourth**, found by staging a design-only edit and counting the hook output: **zero lines, cage never ran, four commits deep.** | ✅ **CLOSED 2026-07-30** (`2df6e074`, lane `S-2026-07-30-CONTRACTGEN`) — the glob is gone. `run_fast_cages.ps1` owns `$SUITE_GUARDS` (one declaration per suite, beside the entry you already must edit); `scripts/gen_fast_tier_pathspec.ps1` generates `.githooks/fast_tier_pathspec`; the hook reads that. Cage = `scripts/_test/run_guard_trigger_tests.ps1`, 4 parts: key-set equality (cannot add a suite without declaring inputs) · every declared path tracked in git · pathspec current **and every declared input measured with git to be selected by it** · **undeclared-reference sweep** (part 1 cannot see a declaration listing 3 of 4 inputs). <br>**The sweep earned itself on its first run** — it named `docs/memory_control/B1_DATASET.csv` as referenced-but-undeclared by `run_b1_guard_tests.ps1`, which was my own 3-of-4 declaration; part 2 then caught the generator being untracked. Fail-closed both ways (missing/empty pathspec ⇒ tier runs unconditionally); generator writes **without BOM** on purpose — PS 5.1 `Set-Content -Encoding utf8` emits one and the first line is a bash-read pathspec. 1.4s (from 2.1s), tier 12 suites 13.9s of 15s, nothing displaced. <br>🔻 **Still hand-written:** the declarations themselves. The sweep catches an undeclared path a suite *mentions in its source*; it cannot catch a dependency reached only at runtime through a variable. | *(original wake condition, kept:)* the next cage is added to `run_fast_cages.ps1`, whichever lane does it — the widening is two minutes and the miss is invisible. | Fix = derive the trigger from what the suites actually depend on (a declared `guards:` list per suite, or a manifest the hook reads), so adding a cage cannot leave the trigger behind. **The fix needs its own cage** — the hook comment has said so since ORDER-500 and that is exactly why it keeps not happening. Same family as ORDER-260 · 341 · 390 · 411 · D27 · D29: the artifact keeps being produced and quietly stops being true; here the artifact is the word "enforced". |
