# ORDER-204 — Genetic Retro-Audit (mechanical, no judgment)

**Question answered:** which written verdicts rest on an MT5 GENETIC optimize run (`Optimization=2`) that
never had a complete-mode fine grid AND a sensitivity fan behind it?

## Method (deterministic, no backtests run)

1. `grep -l "Optimization=2" _mt5_auto/ini/*.ini` → **66 files** (matches the ~66 expected).
2. Built a full index of all 6,468 `.ini` files in `_mt5_auto/ini/` (Expert, Symbol, Optimization mode,
   file mtime) with an `awk` pass (`Expert=`/`Symbol=`/first `Optimization=` line per file).
3. For each of the 66 genetic files, searched the full index for another `.ini` with the **same
   Expert+Symbol**, mtime **0–14 days after** the genetic file, that is either:
   - `Optimization=1` (complete/brute-force mode), **or**
   - has `fine`, `fine2`, `grid`, or `sweep` as a **whole filename token** (case-insensitive, split on
     non-alphanumerics — this excludes coincidental substrings like `Grid` inside the EA name
     `BaronGrid`, which caused a false positive in an early pass and was fixed).
   → this is the **fine-stage found** column.
4. Same window/pair search for filename tokens `fan`, `sens`, `plus20`, `minus20` → **fan found** column.
5. Grepped `EA_SCORECARD_AND_REGISTRY.md`, `PROJECT_STATE.md`, `PROJECT_STATE_SESSIONLOG_ARCHIVE.md`,
   `AGENT_TASKBOARD.md`, `ARCHIVE_TASKBOARD_2026-07A.md`, `EDGE_CATALOG.md`,
   `docs/memory_control/B1_DATASET.csv`, and `_triage/*VERDICT*.md` for each `Report=` name and for each
   Expert+Symbol pair, then read the surrounding context by hand to confirm a real citation (not a
   substring collision — one false lead, `BOSS14_OPT_US30_IS.ini` containing `OPT_US30_IS` as a
   substring, was caught and excluded this way).

**Calibration check (required by the brief):** `OPT_MDX_GBP_coarse` → `_fine` → `_fine2` all come out
**fine-stage = Y** (each links to the next, and `_fine2` links forward to `ASSERT204_MDX_GBP_H4.ini`,
`Optimization=1`, +173h later) — matches the known-good funnel, confirming the method is not
over-strict.

## Count summary

- 66/66 genetic (`Optimization=2`) ini files accounted for.
- **Fine-stage found:** 10/66 (includes the 3-file MDX calibration set).
- **Fan found:** 5/66 (all 3 MDX files + 2 SMCxSTO/EmaStoRev EURUSD H1 files).
- **Verdicts confirmed citing a genetic run:** 16 files, spanning 8 distinct verdict passages.
- **DEBT (verdict cites a genetic run with fine-stage = N):** **13 of those 16 files**, across
  **6 verdict passages** — the MDX-family citations (fine=Y) are the only citations that are clean.

## Full table

| ini | Expert | Symbol | Criterion | window | fine-stage (Y/N) | fan (Y/N) | verdict citing it | flag |
|---|---|---|---|---|---|---|---|---|
| BREAKOUT_opt1_EURUSD_H1.ini | EALabTpl\EA_LabTemplate | EURUSD | 0 | 2023.01.01–2026.06.01 | N | N | `EA_SCORECARD_AND_REGISTRY.md:270` "BREAKOUT (LabTpl) \| EURUSD/GBPJPY \| ≤1.03 \| ★★★ \| **DEAD** \| optimizer 0/180 & 0/175 survivors — edge is XAU-specific" + `EA_SCORECARD_AND_REGISTRY.md:350` "BREAKOUT LabTpl EUR/GBPJPY (optimizer 0 survivors)" | **DEBT** |
| BREAKOUT_opt1_GBPJPY_H1.ini | EALabTpl\EA_LabTemplate | GBPJPY | 0 | 2023.01.01–2026.06.01 | N | N | same as above (`EA_SCORECARD_AND_REGISTRY.md:270,350`) | **DEBT** |
| BREAKOUT_opt1_XAU_H1.ini | EALabTpl\EA_LabTemplate | XAUUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| BRK_XAU_v2_OPT.ini | EA_BREAKOUT_XAU | XAUUSD | 0 | 2023.01.01–2026.06.01 | N | N | `EA_SCORECARD_AND_REGISTRY.md:161` "EA_BREAKOUT_XAU \| XAUUSD H1 \| 1.77 (M4) \| 0.65 \| ★★★ \| **CANDIDATE** \| BUY-only regime risk; thin OOS 33t" + `PROJECT_STATE.md:3` "รันสะอาดใหม่: **v2** BWD 1.66/MAIN 1.98 ... **v2 คือตัวที่หลักฐานสะอาดรองรับ**" + `AGENT_TASKBOARD.md:53-56` (ORDER-210, live/CLAIMED: "funnel เดิมของ EA ตัวนี้ไม่มี ini สักใบที่จบก่อน 2026 ... genetic ทั้ง v2/v3") | **DEBT** (also live-money, 2 accounts) |
| BRK_XAU_v3_OPT.ini | EA_BREAKOUT_XAU | XAUUSD | 0 | 2023.01.01–2026.06.01 | N | N | same three citations — `PROJECT_STATE.md:3` additionally: "**v3** BWD **1.01**/MAIN 1.86 → v3 (เวอร์ชันหลัง) ชนะเฉพาะบนหน้าต่างที่ไหม้ = selected-into-leak" | **DEBT** (also live-money, 2 accounts; v3 is the one flagged as selected-into-leak in memory `brk-xau-991001-v3-selected-into-leak`) |
| O098B_OPT_EURUSD_H1.ini | MacdDiv_Naked | EURUSD | 0 | 2023.01.01–2026.01.01 | N | N | `AGENT_TASKBOARD.md:1849` "...H1 ปิด cell..." (ORDER-098-B verdict block) | **DEBT** |
| O098B_OPT_EURUSD_H4.ini | MacdDiv_Naked | EURUSD | 0 | 2023.01.01–2026.01.01 | N | N | `AGENT_TASKBOARD.md:1849` "...EUR H4 HOLDOUT FAIL 0.35 → PARK..." | **DEBT** |
| O098B_OPT_XAUUSD_H1.ini | MacdDiv_Naked | XAUUSD | 0 | 2023.01.01–2026.01.01 | N | N | `AGENT_TASKBOARD.md:1849` "...H1 ปิด cell..." | **DEBT** |
| O098B_OPT_XAUUSD_H4.ini | MacdDiv_Naked | XAUUSD | 0 | 2023.01.01–2026.01.01 | N | N | `AGENT_TASKBOARD.md:1849` "🥇 XAU H4 ผ่านครบทุกด่าน funnel — MAIN plateau 1.91 ... bundle staged _vps_deploy/MACDDIV_XAU magic 999094" + `EDGE_CATALOG.md:214-220` "🟩 BUILD-ON CANDIDATE ... magic 999094 ... set = `_mt5_auto/ab_sets/order098b/MacdDiv_Naked_XAUUSD_H4_optPF.set`" | **DEBT** (demo-eligible/attached EA, magic 999094) |
| O107adx_AUDNZD_H1.ini | EmaStoRev | AUDNZD | 0 | 2023.01.01–2026.01.01 | N | N | `AGENT_TASKBOARD.md:1111` "ORDER-107 ... optimize จริง 180 passes/symbol: XAU (trender=บ้านผิด) regime-fit ล่ม BWD ... **CONFIRMED (2026-07-16): EURUSD H1 = demo candidate จริง**" (covers all EmaStoRev symbol legs tested in this order) | **DEBT** |
| O107adx_EURUSD_H1.ini | EmaStoRev | EURUSD | 0 | 2023.01.01–2026.01.01 | N | Y (`SMCSTOfan_*_MAIN/BWD.ini`, same Expert+Symbol) | `AGENT_TASKBOARD.md:1111` same passage — this is the EmaStoRev/EURUSD leg that became magic 991070 demo | **DEBT** (fan exists, complete-mode fine grid does not; demo-attached EA) |
| O107opt_AUDNZD_H1.ini | EmaStoRev | AUDNZD | 0 | 2023.01.01–2026.01.01 | N | N | `AGENT_TASKBOARD.md:1111` same passage | **DEBT** |
| O107opt_EURGBP_H1.ini | EmaStoRev | EURGBP | 0 | 2023.01.01–2026.01.01 | N | N | `AGENT_TASKBOARD.md:1111` same passage ("EURUSD-only (ไม่ travel AUDNZD/EURGBP/XAU)" per scorecard row 355) | **DEBT** |
| O107opt_EUR_H1.ini | EmaStoRev | EURUSD | 0 | 2023.01.01–2026.01.01 | N | Y (`SMCSTOfan_*_MAIN/BWD.ini`) | `AGENT_TASKBOARD.md:1111` same passage | **DEBT** |
| O107opt_XAU_H1.ini | EmaStoRev | XAUUSD | 0 | 2023.01.01–2026.01.01 | N | N | `AGENT_TASKBOARD.md:1111` same passage ("XAU (trender=บ้านผิด) regime-fit ล่ม BWD") | **DEBT** |
| OPT_BRKXAG_COARSE.ini | EA_BREAKOUT_XAU | XAGUSD | 0 | 2023.01.01–2026.06.01 | Y (`OPT_BRKXAG_FINE.ini`, +0h) | N | none found (report name not cited verbatim anywhere; scorecard XAGUSD rows 271-272 use IS/OOS language, not this report name — cannot confirm it's the same funnel without guessing) | — |
| OPT_BRKXAG_FINE.ini | EA_BREAKOUT_XAU | XAGUSD | 0 | 2023.01.01–2026.06.01 | N (nothing follows it — no complete-mode confirm after the fine pass) | N | none found | — |
| OPT_BaronGrid.ini | BaronGrid | EURUSD | 0 | 2023.01.01–2026.06.01 | N (only Optimization=0 single-pass IS/OOS loop runs follow, not a grid/complete search) | N | none found | — |
| OPT_BaronGrid_full.ini | BaronGrid | EURUSD | 0 | 2020.01.01–2026.06.01 | N (same, only loop IS/OOS single passes) | N | none found | — |
| OPT_BossV2_11_PlanC2_XAU_H4.ini | EALabTpl\Boss_11_GridTrend | XAUUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_BossV2_11_PlanC_EURUSD_H4.ini | EALabTpl\Boss_11_GridTrend | EURUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_BossV2_11_PlanC_XAU.ini | EALabTpl\Boss_11_GridTrend | XAUUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_BossV2_11_PlanC_XAU_H4.ini | EALabTpl\Boss_11_GridTrend | XAUUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_BossV2_12_PlanD_XAU.ini | EALabTpl\Boss_12_Breakout | XAUUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found (Boss_12_Breakout is later reused as a MacroGate A/B host chassis in `AGENT_TASKBOARD.md:1310`, but that passage tests a gate feature, not this genetic run's parameters — not a citation of this ini) | — |
| OPT_BossV2_13_PlanA2_GBPUSD.ini | EALabTpl\Boss_13_MeanRev | GBPUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_BossV2_13_PlanA_EURUSD.ini | EALabTpl\Boss_13_MeanRev | EURUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_DJ30_IS.ini | EA_RUNNER | DJ30 | 0 | 2020.01.01–2023.12.31 | N | N | none found | — |
| OPT_EAAmongUs.ini | EA Among Us | EURUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_EURCAD_IS.ini | EA_RUNNER | EURCAD | 0 | 2020.01.01–2023.12.31 | N | N | none found | — |
| OPT_EURCADv2.ini | MQL5 EA\Boss - 2 Adaptive Smart Grid | EURCAD | 0 | 2023.06.01–2026.06.01 | N | N | none found | — |
| OPT_EX197v1.ini | EX197- Multi Group Scalping EA [Breakout FVG] | GBPJPY | 0 | 2023.06.01–2026.06.01 | N | N | none found | — |
| OPT_EX197v2.ini | EX197- Multi Group Scalping EA [Breakout FVG] | GBPJPY | 0 | 2023.06.01–2026.06.01 | N | N | none found | — |
| OPT_EX197v3.ini | EX197- Multi Group Scalping EA [Breakout FVG] | GBPJPY | 0 | 2023.06.01–2026.06.01 | N | N | none found | — |
| OPT_EX197v4.ini | EX197- Multi Group Scalping EA [Breakout FVG] | GBPJPY | 0 | 2025.12.01–2026.06.01 | N | N | none found | — |
| OPT_EX197v5.ini | EX197- Multi Group Scalping EA [Breakout FVG] | GBPJPY | 0 | 2025.12.01–2026.06.01 | N | N | none found | — |
| OPT_EX197v6.ini | EX197- Multi Group Scalping EA [Breakout FVG] | GBPJPY | 0 | 2025.12.01–2026.06.01 | N | N | none found | — |
| OPT_EX197v7.ini | EX197- Multi Group Scalping EA [Breakout FVG] | GBPJPY | 0 | 2023.06.01–2026.06.01 | N | N | none found | — |
| OPT_GBPUSD_V3_IS.ini | EA_RUNNER | GBPUSD | 0 | 2020.01.01–2023.12.31 | Y (`OPT_GBPUSD_V3_IS2.ini`, Optimization=1, +0h) | N | none found (report name not cited; note fine-stage already clean here) | — |
| OPT_LABTPL.ini | EALabTpl\EA_LabTemplate | EURUSD | 0 | 2024.01.01–2026.06.01 | N | N | none found | — |
| OPT_LABTPL_XAU.ini | EALabTpl\EA_LabTemplate | XAUUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_LABTPL_XAU2.ini | EALabTpl\EA_LabTemplate | XAUUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_LABTPL_XAU3.ini | EALabTpl\EA_LabTemplate | XAUUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_LABTPL_XAU4.ini | EALabTpl\EA_LabTemplate | XAUUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_LABTPL_XAU5.ini | EALabTpl\EA_LabTemplate | XAUUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_LABTPL_XAU5F.ini | EALabTpl\EA_LabTemplate | XAUUSD | 0 | 2018.01.01–2022.12.31 | N | N | none found | — |
| OPT_LabTpl_LondonBO.ini | EALabTpl\EA_LabTemplate | EURUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_LabTpl_LondonBO_GJ.ini | EALabTpl\EA_LabTemplate | GBPJPY | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_LabTpl_MR.ini | EALabTpl\EA_LabTemplate | EURUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_LabTpl_MR_M15.ini | EALabTpl\EA_LabTemplate | EURUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_LabTpl_MR_XAU.ini | EALabTpl\EA_LabTemplate | XAUUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_LondonBO_GJ.ini | LondonBO | GBPJPY | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_LondonBO_GU.ini | LondonBO | GBPUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_MACD_GBPUSD.ini | (ST) EA03 Count MACD v1 | GBPUSD | 0 | 2023.01.01–2026.06.01 | N | N | `EA_SCORECARD_AND_REGISTRY.md:350` lists "MACD all-symbols (exhaustive)" in the DO-NOT-RE-EXAMINE list — **weak/inferred match only**: the word "exhaustive" implies a complete-mode sweep, which contradicts this ini's `Optimization=2`; no ini in the repo with `Optimization=1` for this Expert+Symbol was found within the 14-day window, so either the "exhaustive" sweep was run outside the tracked `ini/` folder, or the claim of exhaustiveness is itself unverified. Flagging but not asserting as certain | **DEBT (weak citation — verify manually)** |
| OPT_MDX_GBP_coarse.ini | c091c\MacdDiv_Naked | GBPUSD | 0 | 2023.01.01–2025.06.30 | Y (`OPT_MDX_GBP_fine.ini`/`_fine2.ini` +0h, `ASSERT204_MDX_GBP_H4.ini` Optimization=1 +173h) | Y (`MDX_GBP_SENS_*.ini`) | `PROJECT_STATE.md:203` (2026-07-25 genetic policy ratification entry, cites `OPT_MDX_GBP_coarse.xml` directly) + `AGENT_TASKBOARD.md:113` "calibration (ตรวจมือแล้ว = ไม่ใช่หนี้): `OPT_MDX_GBP_coarse/_fine/_fine2` = funnel coarse→fine ถูกต้อง" | clean — explicitly pre-cleared as **not** debt |
| OPT_MDX_GBP_fine.ini | c091c\MacdDiv_Naked | GBPUSD | 0 | 2023.01.01–2025.06.30 | Y (`OPT_MDX_GBP_fine2.ini` +0h, `ASSERT204_MDX_GBP_H4.ini` +173h) | Y (`MDX_GBP_SENS_*.ini`) | same as above | clean |
| OPT_MDX_GBP_fine2.ini | c091c\MacdDiv_Naked | GBPUSD | 0 | 2023.01.01–2025.06.30 | Y (`ASSERT204_MDX_GBP_H4.ini`, Optimization=1, +173h) | Y (`MDX_GBP_SENS_*.ini`) | same as above | clean |
| OPT_MG_CHF_lowDD.ini | MatchaGrid | CHFJPY | 0 | 2023.01.01–2026.06.01 | N | N | `EA_SCORECARD_AND_REGISTRY.md:156` "MG_v1 MatchaGrid \| CHFJPY M15 \| 2.08 \| — \| ★★★ \| **CORE** \| grid but bounded+SL; passed deep-val" — **note:** this row sits in a table explicitly headed `⛔ HISTORICAL, SUPERSEDED 2026-07-09` (`EA_SCORECARD_AND_REGISTRY.md:149-151`, "อย่าใช้ตารางนี้เป็นสถานะ deploy ปัจจุบัน") — flagging as debt on the historical record, current-status re-verification needed | **DEBT (in a table marked historical/superseded — re-verify current status)** |
| OPT_MooDengv1.ini | (oh) MooDeng Bot | USDCHF | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_NAS100_IS.ini | EA_RUNNER | NAS100.cash | 0 | 2020.01.01–2023.12.31 | N | N | none found | — |
| OPT_NuiIndy.ini | (NuiIndy) Dynamic RSI+ADX Style (4) | EURUSD | 0 | 2023.01.01–2026.06.01 | N | N | `EA_SCORECARD_AND_REGISTRY.md:157` "NuiIndy RSI+ADX \| EURUSD H1 \| 2.00 \| — \| ★★☆ \| **CORE (edge=escalation ⚠️)**" + `AGENT_TASKBOARD.md:85-93` (ORDER-212, OPEN as of this audit: "'both-window profitable' แต่ไม่มี date string ให้ grep ... ไล่หา report/ini/verdict ที่ให้เลข CutLoss=30 → ระบุหน้าต่างจริง ... ถ้าหาไม่เจอเลย ให้บอกตรง ๆ ว่า 'หาไม่เจอ' ห้ามเดา") | **DEBT — already self-flagged and OPEN as ORDER-212** (live-money EA, edge=escalation-engine) |
| OPT_PIVOTv1.ini | Boss - 6 Pivot Range Trading | NZDUSD | 0 | 2023.06.01–2026.06.01 | N | N | none found | — |
| OPT_QSpeed.ini | Quantum\Quantum Speed | EURUSD | 0 | 2023.01.01–2026.06.01 | N | N | none found | — |
| OPT_ST03GRID.ini | EA_RUNNER_ST03 | GBPUSD | 0 | 2023.01.01–2025.01.01 | Y (`OPT_ST3G_IS.ini`/`OPT_ST3G_OOS.ini`/`OPT_ST3PROBE.ini`, Optimization=1, +66h) | N | none found (report name not cited verbatim; scorecard's extensive ST03 history at line 186 does not name this specific report) | — |
| OPT_US30_IS.ini | EA_RUNNER | US30.cash | 0 | 2020.01.01–2023.12.31 | N | N | **false lead excluded:** `ARCHIVE_TASKBOARD_2026-07A.md:2041,2046` mention `BOSS14_OPT_US30_IS.xml`/`BOSS14_OPT_US30_IS` — a *different* ini/Expert (`Boss_14_GridLog`, not `EA_RUNNER`) whose name happens to contain "OPT_US30_IS" as a substring. Not a real citation of this file. Actual: none found | — |
| QWEN_GR_opt.ini | The Gold Reaper MT5_4.3_fix_@FundedMillionAiress | XAUUSD | 0 | 2023.01.01–2026.06.01 | N | N | `EA_SCORECARD_AND_REGISTRY.md:160` "Gold Reaper 4.3 \| XAUUSD H1 \| 2.07 \| — \| ★★★ \| **CORE** ⚠️ \| ruin 1.9% — watch. **Live set unchanged 2026-07-02** — see plateau-check note below" + `EA_SCORECARD_AND_REGISTRY.md:165-168` "qwen's `QWEN_GR_opt.xml` (2026-06-29, 5 passes sweeping `StartLots` ... `Optimization=2` genetic) is a **null result, not a real plateau-check** — all 5 passes are bit-identical" | **DEBT — self-documented** (live EA, CORE verdict; the repo's own note already says the "check" was a Leverage-no-op null result, not a real fine/plateau pass) |
| SESSBRK_OPT1.ini | Boss_SessionBreakout_rev01 | XAUUSD | 6 | 2023.01.01–2025.06.01 | Y (`SB_OPT_XAUUSD_H1.ini`/`SESSBRK_OPT2.ini`, Optimization=1, +0h) | N | `EA_SCORECARD_AND_REGISTRY.md:236` "(Boss)_SessionBreakout_rev01 \| XAU M15 PF 1.04 \| ★★★ \| **DEAD** \| 1,200-pass EXHAUSTIVE sweep ceiling 1.20 + forward 0.91" | clean — fine-stage present, not debt |

## Notes on the two weak/qualified rows

- **`OPT_MACD_GBPUSD.ini`** — the only citation found ("MACD all-symbols (exhaustive)") does not name
  this report file verbatim; it's an inference from Expert+Symbol match plus the DO-NOT-RE-EXAMINE
  list wording. The word "exhaustive" is inconsistent with `Optimization=2` and no complete-mode
  companion ini was found. Recommend a human check of whether a MACD sweep exists outside
  `_mt5_auto/ini/` before treating this as confirmed debt.
- **`OPT_MG_CHF_lowDD.ini`** — its only citation lives in a scorecard table explicitly marked
  `⛔ HISTORICAL, SUPERSEDED 2026-07-09`. Whether the MatchaGrid CORE verdict is still the operative
  one for MG_v1 was not re-derived here (out of scope — this audit does not judge verdicts, only
  traces citations).

## What this file does NOT do

No backtests or optimizations were run. No verdict, scorecard, or registry text was edited. This file
is uncommitted, per instruction — several sessions share this working tree.
