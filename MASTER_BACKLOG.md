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
- [ ] **demo-monitor 7 EA → judge 2026-09-22** (รายสัปดาห์: Gold Reaper conditional, MG grid DD, ST03 replica 30 trades แรก).

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

- [ ] **EA_SUPERTREND บน GBPJPY H4** — smoke naked default ดู PF และ corr vs portfolio:
      ถ้าผ่าน PF ≥ 1.3 + corr ≤ 0.40 vs XAU legs → IS/OOS + MC + deploy candidate
      EA compile แล้ว ใช้ same .ex5 เปลี่ยนแค่ Symbol=GBPJPY, Period=H4

- [ ] **concept ใหม่ #1: EURCHF bounded-range harvester** — ยังไม่ smoke (low-vol cross). ใช้ `/signal-scan`.
- [ ] **concept ใหม่ #2: London-breakout → NY open** — port CB structure ไป session NY. ยังไม่ smoke.

### 🟢 re-examine ที่ค้างจากแผนเก่า (ยังไม่ได้ทำจริง)
- [ ] **MT4 gold-grid re-test** (`MT4_GOLDGRID_RETEST_PLAN.md`) — 3-phase plan เขียนไว้ **แต่ยังไม่รัน**:
      Elephant/Mammoth (artifact?), Gold Stuff V7 (martingale?), KRAPOOK (expired=technique only). Phase 1 ถูกมาก (~5 นาที).
- [ ] **R3: EURUSD Forex Robot (MT4)** — WATCH/PARKED (thin 48t). deep 30-mo IS/OOS multi-symbol ยังไม่ทำ. (`EA_SCORECARD` Part 3)
- [ ] **Gold Reaper optimize** — ตอนนี้ default params; ลอง plateau/sizing เพื่อยืนยันไม่ใช่ lone spike (เป็น conditional leg).

### ⚪ ปิดแล้ว / อย่าเสียเวลาซ้ำ
- Bucket D (martingale ports) = 0 survivors · CB new-symbol 4/4 DEAD · CB_EUR rescue DROP · R1 RSI_Swing / R2 TrendRegression = DEAD ·
  USDJPY breakout opt→REJECT · ST03 multi-symbol/SL/rearm = DEAD · MACD all-symbols exhaustive REJECT.

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
