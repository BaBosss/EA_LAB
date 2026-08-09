# HANDOFF → next session (2026-07-16B, Opus, EA-lane) — regime-rescue + GBPJPY leg-8 marathon

> อ่าน `VISION.md` → `PROJECT_STATE.md` → this file. ขัดกันเชื่อ repo + `check_state.ps1`.
> ต่อจาก `SESSION_2026-07-16_HANDOFF.md` (SMC×STO + anti-recurrence + death-review). HEAD chain: `8f51b905` → +10 commits ([claude], ผ่าน hook ทุกอัน).

## ✅ ปิดใน session นี้ (10 commits)

1. **🥇 regime-rescue pipeline (START-HERE #1) — reframe สำคัญ:** "29 EA" **ไม่มีจริง** — addressable แค่ 4 cells (ที่เหลือ MT4 black-box graft ไม่ได้ / Boss_14 ผ่าน ORDER-062 แล้ว). regime-rescue = **งาน build ไม่ใช่ batch.**
2. **ORDER-109 Zeus AUDJPY = 🟡 PARTIAL RESCUE → DEMO** — graft `_50_ Regime.mqh` เข้า Zeus standalone chassis (`Regime_Standalone.mqh`, no-op proven bit-identical). range-only gate (m1rng25+storm1.5) = Model-4 both-window plateau thr20-30 (MAIN 1.24-1.63/BWD 1.28-1.52) **แต่ year-split 2023 เจ๊ง (-900)** → **demo bundle `_vps_deploy/ZEUS_AUDJPY_REGIME/` magic 990110** (user เคาะ demo, deploy small). AUDUSD = fragile park. verdict = `_triage/_archive/verdicts/order104-126/ORDER109_ZEUS_REGIME_VERDICT.md`
3. **ORDER-110 XAU_NY = 🟡 regime ไม่กู้** — rebuild = config บน Boss_12 Donchian (Entry-12 + session filter + `_50_` ครบ ไม่ต้องเขียนโค้ด). 48-run: regime gate redundant กับ breakout. verdict = `_triage/_archive/verdicts/order104-126/ORDER110_XAUNY_REGIME_VERDICT.md`
4. **🥇 ORDER-106 GBPJPY leg-8 = ปิดสมบูรณ์ → DEMO LEG #8 (clean)** — d1.5 finer = Model-4 fill-optimism (REJECT) → leg = **d2.0/s4.0**. corr ทุกคู่ <0.8 (max CADJPY 0.791) + **year-split all-years-positive** (2021-2026 PF 1.28-2.36, ไม่มีปีเจ๊ง — สะอาดกว่า Zeus). **bundle `_vps_deploy/BOSS14_GBPJPY/` magic 990208** (EA=Boss_14_GridLog ตัวเดียวกับ cohort, attach GBPJPY H4 เพิ่ม). caveat: thin 9-28t/ปี · 2020 no-data · CADJPY 0.791.
5. **Model 0-4 อธิบาย + verify (user ห่วง open-price kill)** — ยืนยัน: ทุก verdict บน Model 4 (real ticks), ไม่เคยฆ่าด้วย open-price/math-cal. MT4/MT5 เลข Model ต่างกัน (MT4 1=control-points, MT5 1=1-min-OHLC).
6. **ORDER-111 re-audit + source-catalog:** re-audit 6 marginal every-tick = **0 wrongly-parked** (cheap-model แฟร์/ใจดีเกิน, 2 ตัวโผล่ DD 99% ที่ control-points บัง). .mq5 catalog 599 families → ~5 external build-lead (Breakout Retest Pro/FVG/POW BANKER/TEMPO/Pivot). `_triage/ORDER111_mq5_source_catalog.csv`
7. **ORDER-084 rescue #3 ZSCORE = ❌ REJECT** — ย้ายไป ranger 36-run ไม่มี both-window survivor (reversion ไม่มี edge แม้บนบ้านถูก). `_mt5_auto/ZSCORE_RESCUE_RANGER.csv`

## 🧠 Meta-lessons banked (memory + verdicts)
1. **[[regime-gate-grids-not-breakouts]]** — `_50_` gate = orthogonal สำหรับ GRID (Zeus/XAU-grid กู้ได้) · redundant กับ BREAKOUT (ADX ซ้ำ momentum)
2. **Model-1 finer-sweep หลอกบ่อย** — tighter grid spacing = fill-optimism (Zeus m2 dir-lock BWD 1.39→1.01 · GBPJPY d1.5 BWD 1.32→0.92) → **grid ต้อง Model-4 เสมอ; control-points/1-min-OHLC บัง grid/basket blowup**
3. reversion < momentum บนพอร์ตนี้ (ZSCORE ยืนยันอีกครั้ง)

## ⚠️ Gotchas ยืนยัน session นี้
- **compile ea_projects EA ต้องใช้ `D:\Meta 5\MetaEditor64.exe`** — Meta5b MetaEditor resolve `<Trade\...>` include ไม่ได้ (roaming B084 ไม่มี Include tree). ยืนยันด้วย probe.
- **delegate agent = ต้องใส่ "foreground synchronous, ห้าม background-wait" ทุกครั้ง** — ZSCORE agent ตกหลุมนี้ (memory `subagent-no-background-wait`), รันเองแทน. deterministic script รันเอง = ชัวร์กว่า agent สำหรับ batch ที่ scripted ครบ.
- Meta5 (9CA16B, primary) + Meta5b (B084, portable `-Portable -DataDir 'D:\Meta 5b'`) รัน Model-1 คู่ขนานทั้ง session ไม่ freeze.
- protected-set commit: stage `AGENT_TASKBOARD.md` + `docs/memory_control/RECONCILE_EXCEPTIONS.md` คู่กัน (hook ผ่านทุกครั้ง session นี้).

## 🚀 START HERE — คิว session หน้า (เรียง EV, user เคาะให้ทำต่อเนื่อง)
1. **[user attach ก่อน = EV สูงสุด] รอวัน attach 8 bundle** → register DEPLOYMENTS.csv + judge +3 เดือน + monitor. **2 leg ใหม่ที่ต้องเพิ่ม: Zeus AUDJPY 990110 + GBPJPY 990208** (+ 6 เดิม: Wave5×2/Breakout×2/MacdDiv/SMCSTO).
2. **rescue queue ต่อ (ORDER-084):** ICHIMOKU (#66, claimed structural แต่ default 1-cell = overclaim) → KELTNER (#62). pace 1-2.
3. **regime-rescue ที่เหลือ:** Boss_14 NZDUSD-SELL/USDCAD (ยังไม่ผ่าน `_50_` — low-prior แต่ปิดให้ครบ).
4. **source catalog batch 2:** .mq4 (5,187 ไฟล์) + eyeball 195 "other" .mq5 families. delegate (foreground!).
5. gap death-review: flat-lot-probe sweep กองมาร์ติงเกล · walk-forward re-opt cadence.

## รอ user (mobile-answerable)
- **วัน attach 8 bundle** (บอกวัน → Claude register + judge date) · Zeus AUDJPY = deploy small (2023 caveat) · GBPJPY = ดู CADJPY corr 0.791
- MacdDiv cent-test (Exness XAUUSDc set พร้อม) · โหลด MT4 history (ปลด PARKED-VERIFY Phoenix/GBPJPY1H90PCWR + re-run NZDUSD-H4/AUDJPY-H1/GBPJPY/EURGBP)
