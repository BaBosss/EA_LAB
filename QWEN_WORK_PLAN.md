# QWEN UNATTENDED WORK PLAN — 2026-06-23 / 06-24

> **STATUS 2026-06-25 — ส่วนใหญ่จบแล้ว (เก็บไว้เป็น playbook reference):**
> - **Q1 CB new-symbol** → ✅ DONE: 4/4 DEAD (GBPJPY/GBPCAD/EURGBP/USDCAD ไม่ผ่าน) — CB = GBPUSD-only.
> - **Q2 CB_EUR rescue** → ✅ DONE: no durable edge, **CB_EUR DROPPED**. (sweep `_mt5_auto/sweeps/CB_EUR_rescue.csv`)
> - **R1/R2 re-examine** → ✅ DONE: RSI_Swing + TrendRegression ยืนยัน DEAD.
> - ผลทั้งหมดสรุปใน memory `signal-landscape` + `EA_SCORECARD_AND_REGISTRY.md`.
> - ⚠️ บทเรียน: qwen gateway throw Cloudflare 524 บน long run — ใช้ **background PowerShell** แทน (ดู memory).
> ด้านล่าง = แผนเดิม เก็บไว้เป็น sweep playbook (constraints + tooling ยังใช้ได้).

**Purpose:** Sonnet token budget is nearly spent this week. Offload all mechanical
backtest sweeps to Qwen (`claude-9arm`). Qwen RUNS the sweeps and COLLECTS results to
CSV. Sonnet reviews the CSVs later and makes the keep/drop/deploy decisions.

## Hard constraints (bake into every Qwen prompt)
1. **MT5 runs ONE tester at a time.** Sweeps are strictly SEQUENTIAL. Never launch two
   `grid_sweep.ps1` / `mt5_run.ps1` at once — the 2nd aborts.
2. **The .ex5 must be compiled into the terminal Experts folder**, not just the source
   folder: `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts`.
   (A stale .ex5 there silently runs OLD code — this exact bug cost a full ST03 cycle.)
3. **SANITY CHECK first (step 0 of every session):** run the leader set once and confirm
   it reproduces the known **trade count** (more robust than PF — Model-4 real-ticks runs
   ~0.2 PF lower than the Model-2 numbers quoted in memory, but trade COUNT is identical
   when params load correctly). If trade count does NOT match, STOP — wrong/stale binary.
   (Verified 2026-06-23: CB GBPUSD IS Model-4 = PF 1.76 / 41 trades vs memory 1.96/41t —
   trades exact, PF lower as expected. .ex5 confirmed correct.)
4. **Param names must match the compiled .ex5** (`_NN_` naming). The base sets below already
   use the correct names. Do not invent params.
5. Model=4 (real ticks) for all final numbers. Per-test timeout 600s (already default).
6. Qwen does NOT judge pass/fail or pick winners — it only runs + records. Sonnet judges.

## Tooling
- Sweep runner: `D:\EA_LAB\scripts\grid_sweep.ps1` (cartesian grid → serial backtests → CSV).
- Single run: `D:\EA_LAB\scripts\mt5_run.ps1`.
- Results land in `D:\EA_LAB\_mt5_auto\sweeps\*.csv` (rewritten each step = crash-safe).

---

## SESSION Q1 — CB new-symbol screen  (today, ~2h)
**Goal:** the only confirmed momentum winner is LondonConsoBreakout (CB) on GBPUSD (3/3 OOS).
Find if the SAME structure has edge on other London-active symbols.
**Symbols:** GBPJPY, GBPCAD, EURGBP, USDCAD.
**Expert:** `(Boss)_LondonConsoBreakout_rev01`   **Base set:** `D:\EA_LAB\_mt5_auto\CB_GBP_H1_IS_leader.set`
**Grid:** `_01_ConsoAtrMult=1.0,1.5,2.0 ; _02_TpAtrMult=2.0,3.0,4.0 ; _02_SlAtrMult=2.0,2.5`  (18 combos)
**Windows:** `IS:2023.01.01:2025.06.01 ; OOS2:2020.01.01:2022.12.31`  (the two go/no-go windows)

Step 0 sanity: run base set on **GBPUSD** IS → expect PF≈1.96, ~41 trades. Must match within
±0.1 PF before sweeping. Command:
```
pwsh D:\EA_LAB\scripts\mt5_run.ps1 -Expert "(Boss)_LondonConsoBreakout_rev01" -Symbol GBPUSD -Period H1 -Model 4 -FromDate 2023.01.01 -ToDate 2025.06.01 -SetFile "D:\EA_LAB\_mt5_auto\CB_GBP_H1_IS_leader.set" -ReportName CB_SANITY_Q1 -TimeoutSec 600
```
Then per symbol:
```
pwsh D:\EA_LAB\scripts\grid_sweep.ps1 -Expert "(Boss)_LondonConsoBreakout_rev01" -Symbol <SYM> -Period H1 -BaseSet "D:\EA_LAB\_mt5_auto\CB_GBP_H1_IS_leader.set" -Overrides "_01_ConsoAtrMult=1.0,1.5,2.0;_02_TpAtrMult=2.0,3.0,4.0;_02_SlAtrMult=2.0,2.5" -Windows "IS:2023.01.01:2025.06.01;OOS2:2020.01.01:2022.12.31" -OutCsv "D:\EA_LAB\_mt5_auto\sweeps\CB_<SYM>.csv" -ReportPrefix "CB_<SYM>"
```
**Deliverable:** 4 CSVs `CB_GBPJPY.csv CB_GBPCAD.csv CB_EURGBP.csv CB_USDCAD.csv`.
Sonnet looks for any combo with IS PF≥1.5 AND OOS2 PF≥1.2 (a survivor → full 3-window validation later).

---

## SESSION Q2 — CB_EUR rescue  (today/overnight, ~2.5h)
**Goal:** CB on EURUSD is in the portfolio but CONDITIONAL — it fails OOS2 2020-22 (PF 0.86,
EUR historic bear). Find params robust across ALL THREE windows, or confirm none exist (→ drop it).
**Symbol:** EURUSD   **Expert:** `(Boss)_LondonConsoBreakout_rev01`
**Base set:** `D:\EA_LAB\_mt5_auto\CB_EUR_H1_IS_leader.set`
**Grid:** `_01_ConsoAtrMult=1.0,1.5,2.0,2.5 ; _02_TpAtrMult=2.0,3.0,4.0,5.0 ; _02_SlAtrMult=1.5,2.0,2.5`  (48 combos)
**Windows:** `IS:2023.01.01:2025.06.01 ; OOS1:2025.06.01:2026.06.01 ; OOS2:2020.01.01:2022.12.31`

Step 0 sanity: base set EURUSD IS → expect PF≈2.09, ~66 trades.
```
pwsh D:\EA_LAB\scripts\grid_sweep.ps1 -Expert "(Boss)_LondonConsoBreakout_rev01" -Symbol EURUSD -Period H1 -BaseSet "D:\EA_LAB\_mt5_auto\CB_EUR_H1_IS_leader.set" -Overrides "_01_ConsoAtrMult=1.0,1.5,2.0,2.5;_02_TpAtrMult=2.0,3.0,4.0,5.0;_02_SlAtrMult=1.5,2.0,2.5" -Windows "IS:2023.01.01:2025.06.01;OOS1:2025.06.01:2026.06.01;OOS2:2020.01.01:2022.12.31" -OutCsv "D:\EA_LAB\_mt5_auto\sweeps\CB_EUR_rescue.csv" -ReportPrefix "CBEURX"
```
**Deliverable:** `CB_EUR_rescue.csv`. Sonnet looks for a combo with all 3 windows PF≥1.2
(esp OOS2≥1.2) and ≥30 trades/window. If none → CB_EUR is undeployable standalone.

---

## SESSION Q3 — EA_BREAKOUT_XAU plateau confirm  (tomorrow, OPTIONAL, ~1.5h)
**Lower priority** — this EA already passed (OOS M4 1.77, MC PF-5th 1.43). This only
confirms the param plateau is real (robustness gravy, not a gap).
**⚠️ RISK:** the v2 set uses `_NN_` names that need the RENAMED .ex5. Step-0 sanity is
MANDATORY here — if the leader set does not reproduce PF≈2.27 (full 2020-2026), the compiled
.ex5 does not match the set; STOP and report (do NOT trust sweep numbers).
**Symbol:** XAUUSD   **Expert:** `EA_BREAKOUT_XAU`   **Base set:** `D:\EA_LAB\_vps_deploy\BRK_XAU_live_v2.set`
**Grid:** `_01_BreakoutBars=30,40,50,60 ; _02_TpAtrMult=4.0,5.0,6.0 ; _02_SlAtrMult=1.5,2.0`  (24 combos)
**Windows:** `FULL:2020.01.01:2026.06.01 ; OOS:2023.01.01:2026.06.01`

Step 0 sanity: base set FULL window → expect PF≈2.27, ~86 trades.
```
pwsh D:\EA_LAB\scripts\grid_sweep.ps1 -Expert "EA_BREAKOUT_XAU" -Symbol XAUUSD -Period H1 -BaseSet "D:\EA_LAB\_vps_deploy\BRK_XAU_live_v2.set" -Overrides "_01_BreakoutBars=30,40,50,60;_02_TpAtrMult=4.0,5.0,6.0;_02_SlAtrMult=1.5,2.0" -Windows "FULL:2020.01.01:2026.06.01;OOS:2023.01.01:2026.06.01" -OutCsv "D:\EA_LAB\_mt5_auto\sweeps\BRK_XAU_plateau.csv" -ReportPrefix "BRKXAUP"
```
**Deliverable:** `BRK_XAU_plateau.csv`. Sonnet checks the live params sit near a broad
high-PF plateau (not a lone spike = overfit).

---

## SESSION R1 — RSI_Swing_BB re-examine (PARKED ★ kill — was it premature?)
**Goal:** smoke-killed at EUR H1 PF 1.03 with DEFAULT params only. Sweep properly: does ANY
non-martingale config clear PF≥1.2 IS+OOS? If yes → REBUILD. If no → DEAD ★★★ (evidence, not guess).
**⚠️ Recompile first:** source `(Boss)_RSI_Swing_BB_rev01.mq5` is newer than the Experts `.ex5`.
Recompile + copy to Experts before sweeping (stale-.ex5 trap). Tester name: `Boss_RSI_Swing_BB_rev01`.
```
powershell -File D:\EA_LAB\scripts\grid_sweep.ps1 -Expert "Boss_RSI_Swing_BB_rev01" -Symbol EURUSD -Period H1 -BaseSet "D:\EA_LAB\_mt5_auto\R1_RSI_Swing_base.set" -Overrides "_01_ExtremeBars=12,24,36;_02_TpAtrMult=2.0,3.0,4.0;_02_SlAtrMult=1.5,2.0,2.5" -Windows "IS:2024.01.01:2025.06.01;OOS:2025.06.01:2026.06.01" -OutCsv "D:\EA_LAB\_mt5_auto\sweeps\R1_RSI_EURUSD.csv" -ReportPrefix "R1RSI"
```
27 combos × 2 windows = 54 runs.

## SESSION R2 — TrendRegression re-examine (PARKED ★ kill)
**Goal:** smoke-killed XAU 0.81 / EUR 0.85, default params only. Sweep: does reversion-in-trend
have ANY edge? Tester name: `Boss_TrendRegression_rev01`. Recompile first (same trap).
```
powershell -File D:\EA_LAB\scripts\grid_sweep.ps1 -Expert "Boss_TrendRegression_rev01" -Symbol XAUUSD -Period H1 -BaseSet "D:\EA_LAB\_mt5_auto\R2_TrendReg_base.set" -Overrides "_01_RegPeriod=50,100,150;_01_ChannelK=1.0,1.5,2.0;_02_TpAtrMult=2.0,3.0,4.0" -Windows "IS:2024.01.01:2025.06.01;OOS:2025.06.01:2026.06.01" -OutCsv "D:\EA_LAB\_mt5_auto\sweeps\R2_TrendReg_XAUUSD.csv" -ReportPrefix "R2TR"
```
Note XAU history on this terminal starts ~2023-12 → IS from 2024.01.01 is safe. 27 combos × 2 windows = 54 runs.

---
## DO-NOT-TOUCH (dead concepts — do NOT spend Qwen time here)
RSI_Swing_BB, TrendRegression, SessionBreakout, NRBreakout (all DEAD/forward-fail);
MACD crossover on any symbol except GBPUSD (REJECT); BB+RSI mean-reversion (ceiling ~1.1);
BREAKOUT LabTemplate on EURUSD/GBPJPY (no edge, XAU-only).

## RUN ORDER
Q1 → Q2 today (sequential, MT5 is single-instance). Q3 tomorrow if time/tokens allow.
Each session is ONE `claude-9arm -p "..."` background invocation pointed at this file's
section. Sonnet reviews the CSVs next session.
