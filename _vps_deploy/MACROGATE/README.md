# MACROGATE watchdog — deploy bundle (ORDER-073 Phase-3)

**What it is:** a standalone MT5 EA that reads the daily MRIS macro-regime CSV and, while the
regime is RISK_OFF/STRESS, writes two GlobalVariables per configured carry magic:

- `MACROGATE_BLOCK_<magic>   = 1`   → the chassis EA vetoes NEW orders
- `MACROGATE_LOTMULT_<magic> = 0.5` → the chassis EA shrinks NEW-order lot

**CRITICAL — it only affects EA_LAB LabCore-chassis EAs that were recompiled with the GV
bridge (Execution.mqh).** Standalone/commercial EAs (EA_BREAKOUT_XAU, Gold Reaper, NuiIndy,
LondonConso, MatchaGrid) **do NOT read these GVs → gating them is a silent no-op.** Point
`InpMagicsCsv` only at chassis carry-legs that ENTER during risk-off (breakout/momentum).
The validated vehicle is **Boss_12_Breakout** (see the MACROGATE_DEMOLEG bundle).

## Files
- `(Boss)_MacroGate.ex5` — compiled 2026-07-18, 0 errors / 0 warnings (Meta 5 MetaEditor64)

## Prerequisite (must be true BEFORE attach)
`EA_LAB_mris_regime.csv` must exist in the terminal's **Common\Files** and be < 48 h old.
On the dev box the daily chain (`daily_monitor.ps1` → `mris_export_regime.ps1`) writes it;
you transport it to the VPS via rclone (see the runbook). If the file is missing/stale the
guard prints `guard INACTIVE` and does nothing (fail-safe — it never blocks blindly).

## Inputs (set at attach)
| input | value | note |
|---|---|---|
| `InpRegimeFile` | `EA_LAB_mris_regime.csv` | default, in Common\Files |
| `InpRegimeInCommon` | `true` | rclone target = Common\Files |
| `InpMagicsCsv` | e.g. `990120` | carry magics to gate; comma-separated. **chassis EAs only** |
| `InpLotMult` | `0.5` | new-order lot ×0.5 while gated (0<..<1) |
| `InpBlockNew` | `true` | also veto new orders while gated |
| `InpTriggerRiskOff` | `true` | gate on RISK_OFF too (false = STRESS-only) |
| `InpOffsetHours` | `0` | CSV time is UTC; daily granularity → 0 is fine |
| `InpStaleMaxHours` | `48` | file older than this → guard INACTIVE |
| `InpRowStaleMaxHours` | `48` | newest row older than this → guard INACTIVE |
| `InpTimerSeconds` | `300` | watchdog cadence |
| `InpReloadMinutes` | `240` | re-read the file every N minutes |

Attach on ONE chart only (any symbol/TF — it trades nothing, it only writes GVs). "Allow
Algo Trading" must be ON so it can set GlobalVariables.

## Verify it works (Experts log)
On attach it prints one of:
- `regime loaded: N row(s) ... server = CSV +0 h` → CSV read OK
- `guard carry magic=990120` → magic registered
- when RISK_OFF/STRESS as-of now: `[MACROGATE] gate ON magic=990120 state=STRESS lotMult=0.50 block=1`
- when RISK_ON/NEUTRAL: no gate; any stale block GV is cleared

If you see `regime file ... NOT FOUND` or `STALE` → the CSV transport (rclone) isn't landing
the file in Common\Files. Fix that first.

## Caveats
- Evidence = **1 window (2024, in-sample around the Aug-5 unwind).** Demo-validate first;
  run a holdout year before sizing up on live money.
- Helps EAs that ENTER during risk-off. No-op (harmless) for grids that open early then
  only manage.
- Verdict: `ea_projects/(Boss)_MacroGate/MACROGATE_AB_VERDICT.md`.
