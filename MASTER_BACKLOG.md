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
- [ ] **EA #6 reload Bars55** — MT5 GUI → XAUUSD H1 chart → EA_BREAKOUT_XAU → F7 → load `_vps_deploy\BRK_XAU_live_v3.set` → OK (แค่ 2 นาที)
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
        → ✅ **v3.set done 2026-06-28** (`_vps_deploy/BRK_XAU_live_v3.set`, Bars=55, TP×8, EMA150) — ต้อง reload EA #6 ใน MT5 GUI (F7 → load v3.set → OK)
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
    [STRATEGY_200_ANALYSIS.md](STRATEGY_200_ANALYSIS.md). TOP 8/10 shortlist (trend-follower ที่พอร์ตยังไม่มี)
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
      Do not re-test Prev-Day H/L on any FX or XAU. verdict `_triage/ORDER114_PREVDAY_NR7_CLOSE_VERDICT.md`.

- [x] **EA_KELTNER (#62 Keltner Channel breakout) = DEAD 2026-06-27 → REJECT-CONFIRMED (ORDER-113, 2026-07-16B)**
      Rescue swept channel-def lever (EMAPeriod/KeltMult) × TF × both-window Model-4 บน USDJPY (16 runs) → ยืนยันตาย:
      **H4 = window-inversion** (BWD 1.22-1.48 แต่ MAIN 2023-26 พังหมด 0.71-0.76, DD 15%) = deploy ไม่ได้ ·
      **H1 = churn** (both-window 1.0-1.14 ไม่แตะ 1.2, 450-530t = spread-fragile). ไม่มี cell both-window ≥1.2.
      Build-on ปิด (breakout → regime-gate redundant · pending-limit ผิดทาง). original DEAD ถูก, ครั้งนี้ swept จริง.
      verdict = `_triage/ORDER113_KELTNER_RESCUE_VERDICT.md`. (contrast: ICHIMOKU revived under same treatment → กระบวนการทำงาน ไม่ใช่ rubber-stamp)

- [~] **EA_ICHIMOKU (#66 Kumo TK-cross + ADX) = ~~DEAD 2026-06-27~~ → REVIVED-PARKED (ORDER-112, 2026-07-16B)**
      ⚠️ "DEAD" ผิด — under-swept: เทสผิด symbol (XAU capped) + default periods เท่านั้น + ไม่เคยแตะ Kumo-period lever.
      **USDJPY (momentum→JPY-trender = บ้านถูก) + period sweep = both-window Model-4 บวก + plateau กว้าง (6/8 cell >1.1):**
      med-H4(12/34/68) 1.48/1.39 · slow-H1(20/60/120) 1.31/1.22 (ผ่าน ≥1.2 both). แต่ year-split = ทั้งคู่ 2 ปีขาดทุน
      (agg โดนปีเทรนด์กลบ) → ไม่ผ่าน all-years-positive = **PARKED-BUILD-ON ไม่ demo.** build-on lead: med-H4+slow-H1 ขาดทุนคนละปี
      → diversified basket (5/6 ปีบวก). verdict = `_triage/ORDER112_ICHIMOKU_RESCUE_VERDICT.md`.
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
- ✅ **MT4 gold-grid re-test = DONE 2026-07-02** (`MT4_GOLDGRID_RETEST_PLAN.md` §CLOSED) — Elephant/Mammoth
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
| `MT4_GOLDGRID_RETEST_PLAN.md` | ✅ CLOSED 2026-07-02 (all 3 targets fail) → ข้อ 3 |
| `DEMO_DEPLOYMENT_PLAN.md` | live portfolio source of truth → ข้อ 3 |
</content>
</invoke>

<!-- sync test 2026-06-28 -->


---

## §CODEX-AUDIT missing controls (P1/P2) — ตบเข้าจาก `_triage\CODEX_AUDIT_FULL_2026-07-10.md` Layer E (REVIEW = taskboard §REVIEW CODEX-AUDIT 2026-07-11 · P0 ทั้ง 5 ข้อเป็น ORDER-092/093/083C แล้ว ไม่อยู่ในนี้)

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
- [x] **ST03 spacing probe:** ✅ ปิดแกน 2026-07-20 — 3 รัน M1 GBPUSD H1 (cell near-miss 12/26/9 cnt3, DCA L4, trail 23): FIXED 300pts PF 0.90 (986t) · ATR×1.0 PF 1.03 (2213t) · ATR×2.0 PF 0.94 (1254t) — เพดาน 1.03 = breakeven noise, **spacing ไม่ rescue, verdict ไม่เปลี่ยน**. หมายเหตุวิธี: chassis ไม่มี progressive-per-level step input → แกนปิดเป็น fixed/ATR1.0/ATR2.0 (standalone ST03 มี spacing กลไกต่างออกไป = ยังเป็น user lane ตาม `_triage/HANDOFF_ST03_OPTIMIZE_2026-07-19.md`). reports `ST03SP_*` · sets `_mt5_auto/ab_sets/st03_spacing_probe/`

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
