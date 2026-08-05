# HANDOFF — ST03 optimize (user-driven) · 2026-07-19

**For:** user (manual optimize round). **From:** Opus lead. **Why this note:** the chassis rescue rounds
(ORDER-119 + ORDER-135) came back dead, but they tested the **chassis-default MM**, NOT the tuned
standalone config the user has gotten to work before. Verdict corrected below — ST03 concept is NOT
closed permanently; the standalone lane is the user's to optimize.

## The one thing that matters: chassis ≠ standalone

- **Boss_15_ST03 (chassis)** has **signal parity 133/133** with the standalone — the MACD-state entry
  trigger is identical.
- **But the MONEY MANAGEMENT is NOT parity.** Chassis uses its generic block (default ATR-grid step,
  StackMode/LotProg/ProtectLevel). The standalone `EA_RUNNER_ST03` / `ST_EA03` has its own tuned
  machine: `LOT_Repeat`, `tp3`/`near` targets, exit-mode, per-symbol TP, fixed vs progressive spacing,
  vol-gate — none of which the chassis sweep reproduced.
- So the chassis result answers "does the MACD signal + a *generic* grid work?" (no). It does **not**
  answer "does the user's tuned ST03 machine work?" — that's still open, and that's your lane.

## What the chassis rounds actually proved (bounded)

- **ORDER-119 (lever C, flat-lot signal):** MACD Fast/Slow/Signal × CountBars, 6 cells × 2 window =
  0/6 both-window. → the naked MACD-state trigger has no flat-lot edge on rangers. Best near-miss
  EURUSD H4 MAIN 1.15 / BWD 0.98. Evidence: `_triage/ORDER119_LEVERC_RESULTS.md`.
- **ORDER-135 (lever A, chassis-default DCA):** StackMode=92 × MaxLevels{4,6,8} × LotProg{NONE,LIN,LOG}
  on the 2 best cells = 0/9 both-window. The generic DCA engaged (n +2.2×) but only leveraged the
  signal's regime-dependence (winner-window won bigger, loser-window lost bigger). Evidence:
  `_triage/ORDER135_ENGINE_RESULTS.md` + XML `_mt5_auto/optimizations/O133_*.xml`.
- **Net:** the *generic* chassis MM cannot rescue the MACD signal. Your tuned standalone MM is a
  different (and historically better) machine — untested this round.

## Your tuned artifacts (starting points — sets live in the worktree)

Path: `.claude/worktrees/great-mendeleev-a35c44/_mt5_auto/` (30+ ST03 sets). Highest-value:
- `ST03_optimized_v2.set` — the "NEW WINNER LotRepeat=2 (tp3=50/near=50)" from 2026-06-26 (scorecard:
  beats v1 LR3 on all windows with ~half the crisis tail).
- `ST03_lr2_v1.set` / `ST03_lr2_sized_v1.set` — LR2 base + sized variant.
- `ST03_volgate_v1.set` — ATR>1.5×ATR_MA(300) gap-insurance (saves Brexit −218→+94 at ~0 calm cost).
- `ST03_EURUSD_tp30.set` / `_tp50.set` — per-symbol TP experiments (EURUSD collapsed at M4 last time —
  spread eats the 3-5pip target; GBPUSD-only was the re-confirmed home).
- `ST03_edge` / `_grid` / `_pyramid` / `_rearm{3,5,12}` — spacing/re-arm axis you were exploring.

## What was NEVER swept (the open levers — where "better than this" probably lives)

From the scorecard, these are recorded as unfinished / not fully explored on the standalone:
1. **Spacing UNSWEPT** (P1 backlog item): fixed vs ATR vs progressive grid step on GBP trail-exit —
   3 Model-1 runs would close it. This is the cleanest open lever.
2. **Per-symbol TP × exit-mode** re-tune (GBPUSD-only confirmed; EURUSD needs a wider target to survive M4).
3. **LOT_Repeat depth × vol-gate** interaction (vol-gate saves gaps but not sustained-trend crises —
   an open question whether a deeper LR under vol-gate changes the crisis math).

## Corrected verdict (records updated)

- **chassis Boss_15 ST03 cell = DEAD-OPTIMIZED** (generic MM, both signal+engine) — this stays.
- **standalone ST03 concept = PARKED-VERIFY(user)** — NOT "family DEAD permanent". Reopens the moment
  your manual optimize produces a both-window (MAIN 2023.07–2026.07 + BWD 2020-22) result; then it
  re-enters the funnel (M4 → MC → holdout).
- The ENGINE-EDGE cage (5 points) still applies if your winning config is escalation-dependent:
  worst-case ≤15% equity, BWD hard, M4 mandatory, MC ruin ≤2%, engine-edge label = small sizing.

## How to run (standalone, your lane)

- Standalone EA + tuned sets are in the worktree `_mt5_auto/`. Optimize with your usual MT5 GUI or
  `scripts/mt5_optimize.ps1` — but keep windows to the pinned MAIN/BWD so results are comparable and
  a winner drops straight into the funnel.
- ⚠️ Do NOT touch any live/demo account (ST03 is off live — ORDER-118). Lab copy only.
- When you get a both-window winner: ping the lead → M4 confirm → verdict. Don't self-promote.
