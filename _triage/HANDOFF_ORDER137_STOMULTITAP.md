# HANDOFF — ORDER-137 (EXP)_StoMultiTap · PARKED-VERIFY(user)

**Status 2026-07-19 (Opus, commits `a1a36f40` build → `de5f3cab` reversed-verdict):**
`DONE + REVIEWED = PARKED-VERIFY(user)`. Source of truth = AGENT_TASKBOARD.md **ORDER-137**.
Renumbered 133→135→137 (concurrent-session collisions w/ ST03-leverA which owns 135).

## What this is
Multi-tap S/R + Stochastic cycle fade — reverse-engineered from FB Miissterkiiss Weerarak
(16 screenshots) + Bitnefit book "กราฟเทคนิคอลไม่ง้อเซียน 3". Reversion fade at a swing-pivot
S/R zone, armed only after the Stoch has cycled OB/OS **≥ MinTaps rounds** at the zone (never
first-touch). Novel lever for the portfolio = `_03_MinTaps` (round counter).

- Source: `ea_projects/(EXP)_StoMultiTap/(EXP)_StoMultiTap.mq5` (compile 0/0, mql-review PASS, magic 991075 lab-only)
- Standalone EXP probe; naked L1 flat-lot; ATR SL / RR TP; bar-open; tester-gate; digit-aware.

## What is PROVEN (3 batch rounds, ea-screener, Model 2)
1. **Multi-tap lever WORKS on XAU M15 — NOT dead.** Earlier "tap2 dead" was frequency-starvation
   from MTF+ADX filters (tap2 → 0-3 trades), not no-edge. Naked, high StoK:
   - XAU-M15-K17-tap2 = MAIN PF **1.45 / 27t** (vs tap1 0.91 / 1039t)
   - **frequency-tune ZoneTol 0.40 (zt40) = MAIN PF 1.51 / 64t** ← best config, real structure not spike
2. **NOT redundant with SMCxSTO 991070.** Measured monthly-PnL Pearson corr on EURGBP H1 = **−0.10**
   (LOW-additive). Genuinely different return stream.
3. **Why PARKED not CANDIDATE = BWD-fail on every variant** (2020-2022):
   zt40 MAIN 1.51 → BWD 0.58 · zt60 MAIN 1.02 → BWD 0.90 · base 1.45 → BWD 0.35.
   No variant clears MAIN≥1.2 AND BWD≥1.0. MAIN edge = XAU 2023-25 chop-regime; fade dies in the
   2020-22 gold trend. reversion-fade on a TRENDER = regime-bound, not both-window robust
   (same family as XAU regime-artifact traps in signal-landscape).

Ladder is FULL: StoK{5-21} · MinTaps{1-3} · ZoneTol{0.25/0.40/0.60} · SwingStrength{3/5} · MTF on/off
· ADX on/off × homes EURUSD/EURGBP/AUDNZD/XAU (M15–H1).

## OPEN — user decision (this is the fork to control from the other session)
- **(a) demo-isolate** XAU-M15 **zt40** (magic 991075) to collect forward data, AND try the ONE
  untouched lever = **ADX-regime-gate ON** (`_08_UseAdxFilter=true`, AdxMax~25) to see if it isolates
  the chop and lifts BWD. If ADX-gate makes BWD ≥1.0 while MAIN stays ≥1.2 → re-graduate to CANDIDATE.
- **(b) shelve.** Holdout 2026H1 deliberately NOT burned (BWD already gates it) — can open later.

## Evidence paths
- Best config set: `_mt5_auto/ab_sets/order133_buildon/STMT_XAU_K17_tap2_zt40.set`
- All sets: `_mt5_auto/ab_sets/order133_{smoke,opt,tapfair,buildon}/`
- Reports: `_mt5_auto/reports/STMT_*.htm` + `EMASTOREV_EURGBP_H1_MAIN.htm` (the 991070-family corr run)
- Corr tool: `_mt5_auto/corr_monthly.py` (extract_monthly + pearson); python at
  `C:\Users\patip\tools\python\cpython-3.12.13-windows-x86_64-none\python.exe`
- Runner: `scripts/mt5_run.ps1 -Expert "(EXP)_StoMultiTap" -Model 2` (ex5 already in tester Experts roaming)

## Lesson recorded (do not re-learn)
memory [[feedback-discretionary-showtrade-not-mechanical]] — before killing a novel filter-lever:
prove it lost on **edge** not **frequency-starvation** (test naked + widen frequency levers), and
**measure corr** when the spec requires it. This verdict was reversed DEAD→PARKED after user caught
both shortcuts.

---

<!-- HANDOFF-ROUTING -->
_Routing added 2026-08-06 (merge into EA_LAB_MAP branch surfaced this pre-guard handoff)._

| item | destination |
|---|---|
| user fork (a) demo-isolate XAU-M15 zt40 + ADX-gate probe / (b) shelve | ORDER-137 — PARKED-VERIFY(user) recorded on the archived board; decision still with the user |
