# ExpertMAPSAR — right-home naked-pulse comparison (XAU/GBP vs NZDUSD M3 home)

Candidate: ExpertMAPSAR · source SHA-256
`6c5e7b665a766e6e995b673d9b8cd1e4c40e4de885c4413ad8f7e4b8a9a45e62`
(re-verified via `certutil -hashfile` against `D:\Forex\20_Selected EA\Advisors\ExpertMAPSAR.mq5`
immediately before this task's runs — matches the value handed down in the task brief).

Purpose: a naked (untuned), MAIN-only, Model-1 pulse check of whether the MA/PSAR momentum-trend
family belongs on XAU/GBP trender pairs, before dispatching any real optimizer there. No
optimization, no BWD, no Model 4, no parameter search were performed. This is exactly the 4-cell
comparison described in the task brief — nothing else was run.

Lane: `D:\Meta 5` (`terminal64.exe`), DataDir `9CA16B8382AE4CF692710FB36B9DA355` — same install used
for all 4 cells, and the same lane as the M3 NZDUSD evidence, so numbers are comparable across
sessions. Compiled Expert: `M2W5C4_CANDIDATE_ExpertMAPSAR` (flat Experts-root binary — the bare
`-Expert ExpertMAPSAR` name does not resolve on this lane; same binary M2/M3 used, unchanged).

Set file: `sets\ExpertMAPSAR_naked_default.set` — byte-identical copy of
`_mt5_auto\M2_WAVE5_C4_MAPSAR\sets\ExpertMAPSAR_defaults.set` (MA period=12, shift=6, method=SMA(0),
applied=CLOSE(1), PSAR step=0.02, PSAR max=0.20, money=CMoneyNone). Not a single value altered.

**Note on the set-surface warning:** `mt5_run.ps1` printed `surface: UNDECLARED` for all 4 runs —
this `.set` predates the self-declaring-surface convention (`gen_default_preset.py`) and is the same
file M2/M3 already accepted as evidence; carried forward unchanged per task instruction ("reuse
as-is, do NOT build the NZDUSD-tuned set"). The stale-check also reported `NO_SOURCE` because no
`.mq5` named `M2W5C4_CANDIDATE_ExpertMAPSAR.mq5` exists under `D:\EA_LAB` (the binary is a renamed
flat copy) — staleness was instead confirmed the task-brief way, by hashing the real source file
directly (see above), matching the same limitation already on record in
`_mt5_auto/M3_WAVE5_C4_MAPSAR/MAIN_BWD_EVIDENCE.md`.

## Test contract

XAUUSD / GBPUSD × H1 / M30, MAIN window 2023.01.01–2025.12.31, Model 1, source-default set,
single test via `scripts\mt5_run.ps1` (not the optimizer). Exactly these 4 cells — nothing else.

## Per-cell results

| Cell | Trades | Deals | PF | Net | Exp. payoff | Bal DD% | Eq DD% | Sharpe |
|---|---|---|---|---|---|---|---|---|
| XAUUSD H1  | 11 | 22  | 0.05 | -2077.05 | -188.82 | 21.69 | 24.33 | -0.34 |
| XAUUSD M30 | 54 | 108 | 0.22 | -1725.28 | -31.95  | 20.44 | 22.54 | -1.31 |
| GBPUSD H1  | 14 | 28  | 0.37 | -93.04   | -6.65   | 1.47  | 1.81  | -0.13 |
| GBPUSD M30 | 26 | 52  | 0.57 | -65.15   | -2.51   | 1.47  | 1.78  | -0.21 |

**Execution validity (all 4 cells):**
- `truncation_check`: none truncated — all 4 traded through to the window end (idle tail 0 days),
  last deal 2025.12.30 in every cell.
- `leverage_check`: all 4 `MATCH` at requested/actual 1:100.
- History quality: 98% (XAUUSD cells) / 99% (GBPUSD cells).
- Invalid stops / failed entries / invalid volume / runtime-init errors: **not directly
  observable from this pipeline** — `mt5_run.ps1` does not capture the tester Journal for
  single-test runs, only the `.htm` report + the truncation/leverage sidecars shown above. No
  report shows a rejected-order artifact (e.g. an implausible largest-loss outlier or a trade
  count far off the deals/2 expectation) — `total_deals` = `2 x total_trades` cleanly in all 4
  cells, which is consistent with clean open/close pairing and no orphaned or rejected orders.
  Stated explicitly per instruction: this is a clean read on the evidence available, not a
  Journal-level guarantee.
- Conclusion: **execution validity is clean on every cell** on all the evidence this pipeline
  produces; nothing here should be folded into (or blamed for) the weak performance read below.

## Pulse classification

Bars: PROCEED = PF>=1.20 AND trades>=100 · WATCH = PF 1.00-1.20 AND trades>=100 ·
THIN = trades<100 regardless of PF · NO_PULSE = PF<1.00 with trades>=100.

| Cell | Trades | PF | Classification |
|---|---|---|---|
| XAUUSD H1  | 11 | 0.05 | **THIN** |
| XAUUSD M30 | 54 | 0.22 | **THIN** |
| GBPUSD H1  | 14 | 0.37 | **THIN** |
| GBPUSD M30 | 26 | 0.57 | **THIN** |

All 4 cells fall under the 100-trade participation floor — none of them reach a number large
enough to be judged PROCEED, WATCH, or even NO_PULSE (NO_PULSE itself requires >=100 trades; these
cells don't get that far). Trade counts here (11-54) are an order of magnitude below the
NZDUSD MAIN-window coarse-grid cells that cleared the floor in M3 (100-127 trades) — on defaults,
XAU/GBP at H1/M30 simply doesn't generate enough MAPSAR-momentum signal-and-reversal activity in
this 3-year window to say anything about PF at all, favourable or not. This says nothing about
whether a full parametric ladder (different MA/PSAR sensitivity, different session/TF) would
produce a working signal on these symbols — a naked default-param smoke can only ever close one
cell, never a concept (VERDICT GATE, `feedback-course-files-extract-idea` precedent).

## Right-home result

**RIGHT-HOME CELLS CLEARING PULSE (PROCEED): NONE.**

**RIGHT_HOME_PARTICIPATION_BLOCKED** — all 4 cells are THIN (trades: 11, 54, 14, 26 — every one
under the 100-trade floor). Per task instruction, this result supersedes the
`RIGHT_HOME_OPTIMIZE_REQUIRED` branch: no cell is named as a PRIMARY dispatch target from this
task, because none reached adequate participation to select from. Windows/parameters were not
changed to try to force participation (per instruction).

This does **not** mean XAU/GBP is a dead home for ExpertMAPSAR — it means the naked-default
parameter set does not trade often enough on these symbol/TF combinations in the MAIN window to
be read at all. Whether a genuine optimize campaign (the same ladder NZDUSD already went through
in M3) would surface a plateau with adequate participation on XAU or GBP is still an open
question this task was not scoped to answer.

## Files changed

- `_mt5_auto/M3_RIGHTHOME_MAPSAR/sets/ExpertMAPSAR_naked_default.set` (new — byte-identical copy)
- `_mt5_auto/M3_RIGHTHOME_MAPSAR/reports/M3RH_MAPSAR_XAUUSD_H1.htm` (+ `.leverage_check.json`,
  `.truncation_check.json`)
- `_mt5_auto/M3_RIGHTHOME_MAPSAR/reports/M3RH_MAPSAR_XAUUSD_M30.htm` (+ sidecars)
- `_mt5_auto/M3_RIGHTHOME_MAPSAR/reports/M3RH_MAPSAR_GBPUSD_H1.htm` (+ sidecars)
- `_mt5_auto/M3_RIGHTHOME_MAPSAR/reports/M3RH_MAPSAR_GBPUSD_M30.htm` (+ sidecars)
- `_mt5_auto/M3_RIGHTHOME_MAPSAR/RIGHT_HOME_EVIDENCE.md` (this file)
