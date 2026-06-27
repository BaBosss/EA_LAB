# MASTER BACKLOG & COVERAGE — single source of truth
**สร้าง 2026-06-27.** จุดประสงค์: รวม "สิ่งที่ต้องทำ" ที่กระจายอยู่ 5 ไฟล์มาไว้ที่เดียว + ตอบว่า
**EA ตัวไหนเทสกับ symbol/TF ไหนแล้ว, optimize รึยัง, ช่องว่างจริงอยู่ตรงไหน.**

> เปิดไฟล์นี้ไฟล์เดียวพอ. ที่เหลือ (`_RESUME_HERE`, `INTAKE_QUEUE`, `QWEN_WORK_PLAN`,
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
        OOS 2.94-4.87. Bars8 ผ่าน MC (PF-5th 1.73). corr Bars8 vs deployed Bars40 = 0.21 LOW = additive variant.
        → ขั้นต่อ: deploy เล็ก เป็น re-tuned variant ของ EA_BREAKOUT_XAU (Bars55) หลัง ST03 จันทร์
  - GBPUSD breakout (EA_BREAKOUT_XAU H1-signal) = ❌ DEAD (Bars8-20, Model4 PF 0.66-0.85). N-bar breakout = XAU-specific
  - [x] **NuiIndy reversion H4 = 0 trades → reversion เพดานที่ H1** (H4 สัญญาณน้อยเกิน, M30/M15 spread กิน per ST03)
  - ⚠️ ของจริงที่ยังไม่ทำ: ทดสอบ **signal TF อื่น** ต้องแก้ EA ให้ internal TF เป็น input ก่อน (ตอนนี้ hardcode H1)
- **Phase 2 — ขุด technique จาก strategy folder (เฉพาะเมื่อ EA ต้องการ):** ATR-nearby pyramid (= ST03 concept, validated แล้ว) ·
  PSAR trailing exit / session filter → graft ใส่ breakout ถ้า exit ต้องปรับ. ไม่ใช่ standalone screening.
- **Phase 3 — concept ใหม่ (ยังไม่ smoke):** EURCHF bounded-range · London→NY breakout.
  - **idea source จริง = `200 AI Prompt` PDF** (ไม่ใช่ folder EA ที่ตายแล้ว). วิเคราะห์ครบ 200 ตัวที่
    [STRATEGY_200_ANALYSIS.md](STRATEGY_200_ANALYSIS.md). TOP 8/10 (trend-follower ที่พอร์ตยังไม่มี):
    **#68 SuperTrend · #94 Donchian/Turtle · #20 Trend+Pyramid** → generate → /signal-scan → funnel.

---

## NEXT SESSION RESEARCH PLAN (2026-06-27 update) — symbol+TF ครบ

> **กฎ:** smoke = Model 2, 2023.01.01-2026.06.01, default params. IS = 2023.01-2025.01 / OOS = 2025.01-2026.06.
> ทุก concept ต้องเทสอย่างน้อย 3 symbol×TF เพื่อให้รู้ว่า dead จริงหรือแค่ wrong instrument.

### TASK 1 — EA_NR7 ขยาย TF+Symbol (ยัง 1 session work)
NR7 XAU H4 = IS PF 1.08 (fail) แต่ OOS 1.43 (bull run). ยังไม่ทดสอบ H1 (trade count สูงกว่า 4×).
EAs ที่มีแล้ว: `EA_NR7.mq5` (Magic 990080) — ใช้เดิม ไม่ต้องเขียนใหม่.

| # | Symbol | TF | เหตุผล |
|---|---|---|---|
| 1a | XAUUSD | **H1** | บน H4 OOS ผ่าน — H1 ให้ trades ~4× มากกว่า (IS~350/OOS~175t) → IS gate อาจผ่าน |
| 1b | XAGUSD | H4 | แร่เงิน = corr ต่ำ vs XAU, SuperTrend smoke PF 1.63 แสดงว่ามี edge คล้ายกัน |
| 1c | GBPJPY | H1 | H4 dead (PF 0.92) แต่ H1 trade count ≥4× — EMAtrend ได้ 60% WR บน H1 แสดง GBPJPY H1 มี TF-specific edge |
| 1d | USDJPY | H1 | H4 PF 1.16 — H1 อาจดีกว่าถ้า NR7 ใน H1 = volatility contraction ที่แม่นกว่า |

**ถ้า 1a ผ่าน smoke ≥1.30:** ทำ IS/OOS + corr check vs EA_BREAKOUT_XAU ก่อน decide

---

### TASK 2 — EA_ASIANRANGE ขยาย Symbol (ยัง 1 session work)
GBPJPY/USDJPY H1 dead. ยังไม่ทดสอบ London-FX pairs ที่ London open effect แรงกว่า.
EAs ที่มีแล้ว: `EA_ASIANRANGE.mq5` (Magic 990090) — ใช้เดิม.
⚠️ ต้องตรวจ broker server time offset ก่อน: ถ้า ThinkMarkets UTC+3 ต้องปรับ AsiaStartHr=3, AsiaEndHr=11, TradeStartHr=11.

| # | Symbol | TF | เหตุผล |
|---|---|---|---|
| 2a | GBPUSD | **H1** | GBP มี London open effect แรงสุด — Asia range + London breakout ใช้ได้ดีกับ GBP historically |
| 2b | EURUSD | H1 | สอง liquid FX ที่ London open มักเกิด momentum |
| 2c | GBPUSD | H4 | ตรวจว่า H4 ให้ trade count เพียงพอ + session time ยังถูกอยู่ไหม |
| 2d | GBPJPY | H1 | Retry หลังปรับ AsiaStartHr ให้ถูก (session hours เดิม อาจไม่ match broker UTC) |
| **Params to test:** | AsiaStartHr | = 0 (default) AND = 3 (UTC+3 broker) | Smoke ทั้ง 2 ค่าบน GBPUSD H1 |

---

### TASK 3 — EA_LNBREAK (London→NY breakout — NEW concept, 1 coding + smoke session)
สร้าง EA ใหม่: define London session range (08:00-12:00 server) → enter breakout at NY open (12:00+).
Logic: เก็บ London_High/Low ระหว่าง 08:00-12:00 → ที่ bar 12:00+ ถ้า close > London_High = BUY (NY momentum continuation).
ต่างจาก AsianRange ตรงที่: Asia range = quiet period → London breakout. London range = ช่วงที่ EUR/GBP active → NY มา amplify.

| # | Symbol | TF | เหตุผล |
|---|---|---|---|
| 3a | GBPUSD | **H1** | GBP/USD มี NY-open continuation effect แรง |
| 3b | EURUSD | H1 | ECB/USD flow — high volume ตอน NY open |
| 3c | GBPJPY | H1 | JPY carry + GBP = volatile ตอน NY overlap |
| 3d | USDJPY | H1 | High volume at NY open, JPY crosses |
| 3e | XAUUSD | H1 | XAU มักทำ trend ต่อเมื่อ NY เปิด (US economic data) |

Magic: 990110 (ถัดจาก EURCHF 990100)

---

### TASK 4 — Gold Reaper optimize (1 session, เบา)
Default params ปัจจุบัน = conditional OK แต่ ยังไม่ optimize. เป้าหมาย: plateau check ว่า default params อยู่ที่ plateau หรือมี param ดีกว่า.

| # | Symbol | TF | params to sweep |
|---|---|---|---|
| 4a | XAUUSD | H1 | StartLots 0.01-0.05 step 0.01 + key params 2-3 ตัว (ดู EA settings ก่อน) |
| 4b | **IS/OOS check** | — | IS 2023-2025 / OOS 2025-2026 บน default + best plateau params |

---

### TASK 5 — MT4 goldgrid Phase 1 (cheap, ~10 min)
Phase 1 = run Elephant/Mammoth/Gold Stuff V7 บน MT4 simulator ดู equity curve artifact check ตาม `MT4_GOLDGRID_RETEST_PLAN.md`.
ถ้า equity = step-function (spike then flat) = martingale artifact → ปิดทิ้ง.
ถ้า equity = smooth uptrend = ลองต่อ Phase 2.

---

### ลำดับที่แนะนำสำหรับ session ถัดไป:
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

- [x] **EA_PREVDAY (#9/#30 Prev-Day H/L breakout) = DEAD 2026-06-27**
      XAU H1 PF=1.19/T=877/Win%=37.3%. GBPUSD/GBPJPY/USDJPY H1: PF=0.85-0.91.
      buf=0.5 WORSE (PF 1.15), H4 WORSE (PF 1.06, DD 8.85%). High false-breakout rate across all configs.
      Do not re-test Prev-Day H/L on any FX or XAU.

- [x] **EA_KELTNER (#62 Keltner Channel breakout) = DEAD 2026-06-27**
      XAU H4 PF=1.04. GBPJPY/USDJPY/GBPUSD H4: PF=0.68-0.70. All dead.
      Same root cause as PrevDay: entering AFTER move has already happened (chasing).
      EA_BREAKOUT_XAU (rolling H1 N-bar Donchian) is superior — not replicable by band-breakout variants.

- [x] **EA_ICHIMOKU (#66 Kumo breakout + ADX) = DEAD 2026-06-27**
      XAU H4 PF=1.13/T=265/Win%=40.75%/DD=9.96%. GBPJPY PF=0.80.
      Best Win% of all tested (cloud regime-adaptive) but DD=9.96% unacceptable and PF<1.30.
      Cloud lags price (Senkou spans are 26-bar delayed) → late entry → high false-reversal rate.
      XAU breakout ceiling ~1.13-1.19 confirmed across 3 concepts (PrevDay/Keltner/Ichimoku).
      EA_BREAKOUT_XAU (hardcoded H1 rolling Donchian) edge is unique. Do NOT build more XAU breakout variants.

- [x] **concept A: EA_NR7 (#105 NR7 volatility breakout) = DEAD 2026-06-27**
      Smoke (M2, 2023-2026): XAU H4 PF=1.31/T=145 (PROCEED), GBPJPY/GBPUSD/USDJPY H4 PF=0.90-1.16 (DEAD).
      IS/OOS on XAU H4: IS(2023-25) PF=1.08 FAIL / OOS(2025-26) PF=1.43 — OOS better = regime artifact.
      Full-period 1.31 is driven entirely by 2025-2026 XAU bull run. Same regime-dependency pattern as USDJPY EMAtrend.
      Trade count thin (87 IS / 58 OOS). Hard to confirm edge below 100 trades per window.
      VERDICT: concept DEAD. Do not re-test NR7 on any FX. XAU NR7 = no stable edge across full window.

- [x] **concept B: EA_ASIANRANGE (#70 Asia→London range breakout) = DEAD 2026-06-27**
      Smoke (M2, 2023-2026): GBPJPY H1 PF=0.82/T=543, USDJPY H1 PF=0.96/T=501 — both dead.
      High trade count confirms the signal fires often but has no edge. Asia range breakout on JPY pairs = no advantage.
      VERDICT: concept DEAD. Do not re-test Asia→London breakout on JPY pairs.

- [x] **concept C: EA_EURCHF bounded-range (BB+RSI mean reversion) = DEAD 2026-06-27**
      Smoke (M2, 2023-2026): EURCHF H4 PF=0.74/T=507/Win%=43.2% — worst of the batch.
      BB+RSI reversion on EURCHF: signal fires often (507 trades) but no edge. SNB management ≠ reliable mean-reversion.
      VERDICT: concept DEAD. Do not build EURCHF reversion EA.

- [ ] **concept ใหม่ #2: London-breakout → NY open** — port CB structure ไป session NY. ยังไม่ smoke.

### 🟢 re-examine ที่ค้างจากแผนเก่า (ยังไม่ได้ทำจริง)
- [ ] **MT4 gold-grid re-test** (`MT4_GOLDGRID_RETEST_PLAN.md`) — 3-phase plan เขียนไว้ **แต่ยังไม่รัน**:
      Elephant/Mammoth (artifact?), Gold Stuff V7 (martingale?), KRAPOOK (expired=technique only). Phase 1 ถูกมาก (~5 นาที).
- [ ] **R3: EURUSD Forex Robot (MT4)** — WATCH/PARKED (thin 48t). deep 30-mo IS/OOS multi-symbol ยังไม่ทำ. (`EA_SCORECARD` Part 3)
- [ ] **Gold Reaper optimize** — ตอนนี้ default params; ลอง plateau/sizing เพื่อยืนยันไม่ใช่ lone spike (เป็น conditional leg).

### ⚪ ปิดแล้ว / อย่าเสียเวลาซ้ำ
- Bucket D (martingale ports) = 0 survivors · CB new-symbol 4/4 DEAD · CB_EUR rescue DROP · R1 RSI_Swing / R2 TrendRegression = DEAD ·
  USDJPY breakout opt→REJECT · ST03 multi-symbol/SL/rearm = DEAD · MACD all-symbols exhaustive REJECT.
- **EA_SUPERTREND** = XAU-specific edge, 12-symbol hunt 0 additive legs · **EA_DONCHIAN** = 0 additive legs (USDJPY regime artifact, XAU below 1.30 all periods).
- **EA_EMATREND** (#20 EMA-cross trend follower) = **concept DEAD. 4 smoke PROCEEDs were all regime artifacts.**
  2015-2026 11-year checks: USDJPY PF 1.21 / GBPUSD PF 0.76 / GBPJPY PF 0.61. All three deeply negative in 2015-2022 era.
  The EMA20/50 cross H4 only worked in the 2022-2026 high-volatility post-COVID/BOJ/Brexit regime.
  Do not re-test any FX pair with EMA-cross H4 concept. XAU not fully tested (but XAU breakout already captures directional edge).

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
| `_RESUME_HERE.md` | resume context — section "ถัดไปทันที" รวมเข้าข้อ 3 แล้ว |
| `INTAKE_QUEUE.md` | Bucket D CLOSED · C/E = martingale skip |
| `QWEN_WORK_PLAN.md` | Q1/Q2/R1/R2 = DONE (playbook reference) |
| `EA_SCORECARD_AND_REGISTRY.md` | rubric + audit trail · Part 3 RE-EXAM → ข้อ 3 |
| `MT4_GOLDGRID_RETEST_PLAN.md` | **ยังไม่รัน** → ข้อ 3 |
| `DEMO_DEPLOYMENT_PLAN.md` | live portfolio source of truth → ข้อ 3 |
</content>
</invoke>
