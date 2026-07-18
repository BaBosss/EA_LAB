# SESSION HANDOFF — 2026-07-18 — ORDER-073 news/macro risk system CLOSED

**Seat:** Claude Opus 4.8 · **Focus:** ORDER-073 end-to-end (continued from 2026-07-17C)
**Commits:** `7ee6bbd8` → `e219db8e` on master · **safety branch:** `order073-macrogate-safe`
(points at the full chain — use if master rebases away; another session was actively
rebasing master through this whole session, HEAD moved 5+ times, no work lost)

## What shipped (usable NOW)

### Phase 2.5 — MRIS macro-regime advisory layer = LIVE on the morning dashboard
- **Web feeder owns ALL 8 barometers** (`scripts/mris/mris_web_feeder.ps1`): VIX `^VIX`,
  DXY `DX-Y.NYB`, COPPER `HG=F`, US10Y_JP10Y via `^TNX` proxy, + AUDJPY/USDJPY/XAU/BTC —
  all free no-key Yahoo chart API (stooq is dead behind a JS bot-wall). Merges in-place,
  `asof` column, per-symbol cache + STALE fallback. Wired into `mris_run.ps1`.
- **Thresholds LOCKED** as user-sanctioned defaults (`barometers.json` v1.0) with an in-file
  `_tuning_guide` (every knob's effect + sweep alternatives, visible when you open to tune).
- **Whisper embedded top of `LIVE_DASHBOARD.html`** + `daily_monitor.ps1` runs `mris_run`
  before the dashboard (mobile sees it every morning via gist).
- Codex-hardened: cache-poison, atomic write, effective-status age-gate, InvariantCulture
  parse, malformed-asof fail-closed. Reads NEUTRAL RI 0.269 HIGH today.
- Classifier freshness: age-gates OK rows older than `-MaxAgeHours` (120), VIX STRESS
  override only on ACTIVE VIX, gold co-move needs meaningful+fresh VIX rise.

### Phase 3 — MacroGate watchdog = VALIDATED deploy-candidate (was a STUB)
- **Standalone** `ea_projects/(Boss)_MacroGate/` + **chassis GV bridge** in
  `ea_template/core/Execution.mqh` (`Exec_MacroBlocked` + `Exec_MacroLotMult`, OPEN path
  only — the multiplier is NOT in `Exec_NormalizeLot` which sizes partial closes) +
  **in-chassis `_MG_SelfGate`** (LabCore, inert-by-default) for single-EA tester A/B.
- Core lives at `ea_template/core/MacroGate_Core.mqh` (single source; standalone includes it).
- **Concept** (`scripts/mris/mris_backtest_timeline.ps1`): MRIS flags Aug-2024 + Mar-2020
  unwinds with weeks of lead time.
- **A/B result — the money finding:** on a carry EA that ENTERS during risk-off
  (`Boss_12_Breakout`), full-year 2024, 2 symbols: **eqDD −54..−56%, P&L flat→much better**
  (USDJPY net −58→+2.8). Manage-only grid (`Boss_14_GridLog`) = no-op (harmless — it opens
  early then only manages). Cage: 6 EAs identical trade counts (core edits inert).
- Codex QA fix-then-ship → all 7 findings fixed (GV fail-open on dead watchdog, per-pass
  freshness, non-ascending→INACTIVE, lot-only stale-block delete, NaN guard, datetime shape).
- Verdict: `ea_projects/(Boss)_MacroGate/MACROGATE_AB_VERDICT.md` · review:
  `docs/memory_control/CODEX_MACROGATE_REVIEW.md`.

## WAITING-USER (nothing blocked on Claude)
1. **NewsGuard (Phase 2)** — approve `GUARDCONFIG_2026-07-17.md` + VPS attach per
   `ea_projects/(Boss)_NewsGuard/VPS_TRANSPORT_AND_ATTACH.md` (unchanged from 2026-07-17C).
2. **MacroGate live attach** — user decision. Deploy on breakout-style carry legs. Use the
   standalone `(Boss)_MacroGate` (configure carry magics) OR per-EA `_MG_SelfGate=true`.
   Regime CSV → VPS via the same rclone path as the news CSV; add an `mris_export_regime`
   step to `daily_monitor.ps1` that appends today's MRIS state to `EA_LAB_mris_regime.csv`.
3. **Refresh the regression baseline** (`scripts/tpl_regression.ps1 -UpdateBaseline
   -ConfirmBaseline`) when the broker ticks settle → then the cage reads a formal GREEN
   (today it's RED-benign from Jul-11 stale ticks; the edits are proven inert by identical
   trade counts).

## Caveats to carry forward
- MacroGate evidence = **1 window (2024, in-sample around a known event)**. Run a holdout
  year A/B before sizing up on live money.
- MacroGate helps EAs that ENTER during risk-off (breakout/momentum). It is a harmless
  no-op for grids that open early and only manage.
- **Shared worktree:** two Claude sessions were live on this repo all day. Commit
  path-limited (`git commit -m ... -- <paths>`, NOT `git add`+bare-commit which sweeps the
  shared index). Check HEAD before staging; if it moved, the safety branch has the work.

## Pointers
- Tunable regime knobs: `scripts/mris/barometers.json` `_tuning_guide`.
- Backtest timeline regen: `scripts/mris/mris_backtest_timeline.ps1 -Windows "label:start:end"`.
- Codex direct (rescue plugin wrapper is broken on this box): `codex exec --skip-git-repo-check --cd /d/EA_LAB < prompt.txt`.
