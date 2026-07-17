# ORDER-073 Phase-3 MacroGate — VALIDATION phase (execute in a STABLE tree)

**Status at handoff (commit `bf09b72`):** mechanism BUILT + concept VALIDATED. NOT attached.
The GV bridge is inert-by-default, so nothing is live. This file is the remaining, mostly
mechanical validation gate that MUST pass before any live attach.

> Do this only when the shared worktree is quiet (no concurrent rebase). During this
> session another Claude reorganised master history mid-build, which is why the cage/
> backtest were deferred — those need a stable HEAD.

## What already exists
- `ea_template/core/Execution.mqh` — `Exec_MacroBlocked()` + `Exec_MacroLotMult()`; called in
  `Exec_Open` / `Exec_PlacePending` (open path only, NOT in `Exec_NormalizeLot` which also sizes
  partial closes). Reads `MACROGATE_BLOCK_<magic>` / `MACROGATE_LOTMULT_<magic>` GVs.
- `ea_projects/(Boss)_MacroGate/` — standalone watchdog EA (core + wrapper), NewsGuard-parallel.
- `scripts/mris/mris_backtest_timeline.ps1` — replays MRIS over 10y Yahoo history → dated regime
  CSV. Already produced `portfolio/mris/backtest/regime_{carry_unwind_2024,covid_crash_2020}.csv`.

## Step 1 — regression cage (core edit gate)  [BLOCKER]
`powershell -File scripts\tpl_regression.ps1`  (MT5 GUI closed; ~6 runs).
- ACCEPT: 0 drift vs `ea_template\regression_baseline.csv` (bridge is inert with no MacroGate
  running / no GVs set — PF/trades/net/eqdd must be byte-identical).
- If ANY number moves → the bridge is not inert; investigate before anything else.

## Step 2 — chassis self-gate hook (for single-EA A/B; the tester runs ONE EA)
The MT5 tester cannot run MacroGate + a carry EA together, so the carry EA must self-gate.
Add an INERT-BY-DEFAULT hook to the chassis:
- `Inputs.mqh`: `input bool _MG_SelfGate=false; input string _MG_RegimeFile="EA_LAB_mris_regime.csv";
  input bool _MG_InCommon=true; input double _MG_LotMult=0.5; input bool _MG_BlockNew=true;
  input bool _MG_TriggerRiskOff=true;`
- `LabCore.mqh`: `#include "../../ea_projects/(Boss)_MacroGate/MacroGate_Core.mqh"` (or copy the core
  beside the template like NewsGuard_Test does). In `OnInit`, if `_MG_SelfGate`: `MG_Setup(...)`,
  `MG_ParseMagics(IntegerToString(_0_Magic))`, `MG_LoadRegime(...)`. In `OnTick`, if `_MG_SelfGate`,
  throttle-call `MG_Tick(TimeCurrent())` (once per new bar is enough).
- Re-run Step 1 cage with `_MG_SelfGate=false` → must STILL be 0 drift (default off = inert).
- ห้าม: do not wire `_MG_SelfGate` on by default; live carry EAs use the standalone MacroGate.

## Step 3 — no-lookahead regime CSV for the tester
Regenerate the backtest timeline stamping each regime row at the NEXT day 00:00 (regime from
close[D] must only be visible from D+1 — the current concept CSV stamps D 00:00 = lookahead for
intraday entries). Add a `+1 day` shift to `mris_backtest_timeline.ps1`'s output datetime, or a
`-ShiftDays 1` param. Copy the resulting CSV to MT5 `Common\Files\EA_LAB_mris_regime.csv`.

## Step 4 — A/B backtest  [MANDATORY per #073]
Carry EA = `Boss_14_GridLog`. Windows: **2024-06-01..2024-09-20** (Aug-5 unwind) and
**2020-02-01..2020-04-30** (COVID). Symbols: USDJPY + AUDJPY (a real DIRECT_CARRY leg each).
Run each: A = `_MG_SelfGate=false`; B = `_MG_SelfGate=true` (LotMult 0.5, BlockNew true, this magic).
- ACCEPT (gate earns its place): B reduces max equity DD vs A on the unwind windows WITHOUT
  killing full-sample PF (B PF >= ~0.9 x A PF over a neutral control window, e.g. 2023 full year).
- If B does not reduce DD → PARK the auto-act gate; keep MRIS advisory-only (Phase 1-3 already
  shipped). Record the numbers either way (VERDICT GATE: no silent park).

## Step 5 — Codex review + package
- Codex review the money logic: `codex exec --skip-git-repo-check --cd /d/EA_LAB` with a neutral
  QA brief on `MacroGate_Core.mqh` + the Execution.mqh bridge + the self-gate hook. (The rescue
  plugin wrapper reports "not installed" on this box — call `codex exec` directly; it works.)
- Package `_vps_deploy` bundle like NewsGuard (ex5 + locked .set + README + rclone transport reuse
  `EA_LAB_mris_regime.csv`). Add a `mris_export_regime.ps1` step to the daily chain that appends
  today's state to the live regime CSV + rclone-pushes it (mirror NewsGuard's news_week.csv path).
- ห้าม attach live until Steps 1+4 pass. Live attach = user's manual gated step (like NewsGuard).

## Doctrine reminders
- reduce-lot ×0.5 + block-new only; NEVER close a position. Trigger is the MRIS regime (relative),
  never a hardcoded price. Fail-safe clears all GVs on stale/missing data.
