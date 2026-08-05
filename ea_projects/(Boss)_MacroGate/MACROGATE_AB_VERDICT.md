# MacroGate A/B verdict — ORDER-073 Phase-3 (2026-07-18)

> # 🔴 SUPERSEDED 2026-07-25 (ORDER-211) — the benefit table below was measured through a broken classifier
>
> Every number in this document was produced with a regime CSV from the MRIS core classifier
> **before** the `AUDJPY user_pin` bug was fixed (ORDER-203, commit `265de0e3`). That bug made the
> classifier call **82 days of 2024 risk-off; the corrected classifier calls 47** — the gate was
> shutting the door about 75% more often than it should, and in the wrong places (after the fix,
> the first risk-off day of 2024 is 17 July, so the whole first half of the year was falsely gated).
>
> **Re-run on the corrected timeline (gate liveness proven from the tester log: 262 rows loaded,
> 0 skipped, 25,105 block events; OFF runs never open the regime file at all):**
>
> | cell | recorded here (OFF→ON) | corrected (OFF→ON) |
> |---|---|---|
> | AUDJPY event net | +5.36 | **−30.24** |
> | USDJPY event net | +37.02 | **−18.40** |
> | AUDJPY full-2024 net | +0.40 (flat) | **−15.39** |
> | USDJPY full-2024 net | +61.16 (loss→breakeven) | **−20.75** |
> | **PF, all four cells** | **up or flat** | **DOWN in all four** (−0.20 / −0.24 / −0.05 / −0.07) |
> | USDJPY full-2024 eqDD | −55.7% | **−7.1%** |
>
> **Standing withdrawn: "VALIDATED deploy-candidate" → ADVISORY-ONLY.** The headline claim of this
> document — *P&L flat-to-much-better while DD halves* — does not survive. What is left is the
> ordinary cost of any filter: fewer trades, lower drawdown, worse profit factor.
>
> What *does* survive: drawdown control on **AUDJPY** is real timing, not just trading less —
> it blocked 19-32% of entries and cut eqDD 44-53%. **USDJPY is the opposite** (blocked 16-35%,
> eqDD down only 7-21%), and USDJPY is the symbol the live-attached leg 990120 runs.
>
> Full judgement + the numbers behind this: `AGENT_TASKBOARD.md` ORDER-211.

## Bottom line — ⛔ as recorded 2026-07-18, now superseded (read the banner above first)
**Mechanism VALIDATED + hardened. Benefit DEMONSTRATED and generalizing on breakout-style
carry legs (equity DD cut ~54-56% over a full year, 2 symbols, P&L flat-to-much-better).**
Verdict: **VALIDATED deploy-candidate** for carry EAs that ENTER during risk-off. Live attach
stays the user's gated decision. For manage-only grids it is a harmless no-op.

## Mechanism — VALIDATED (both bridge paths + fail-safe)
| test | result |
|---|---|
| default `_MG_SelfGate=false`, no GVs | A/B byte-identical -> inert by default |
| all-STRESS regime, block ON | 40 -> 0 trades (Exec_MacroBlocked veto works E2E) |
| all-STRESS, block OFF, LotMult 0.5 | net 38.33->16.69, 40->25 tr (lot-mult works) |
| regime row gap / stale / missing | fail-safe INACTIVE, GVs cleared (logged) |
| **tpl_regression cage** (6 EAs, defaults) | **identical trade counts on all 6** (168/164/107/56/216/73) -> core edits inert; the sub-2% net/eqdd move is pre-existing stale-baseline tick drift, not this change (refresh baseline for a formal GREEN) |

## A/B benefit — depends on the EA's entry timing
**Manage-only grid (Boss_14_GridLog, USDJPY+AUDJPY 2024):** gate ON == OFF, byte-identical.
Root cause (not a bug): it opens its basket in the early calm then only MANAGES through
risk-off - no NEW entries for the gate to touch.

**Breakout, enters during the crash (Boss_12_Breakout):** the gate blocks the risk-off
entries and materially improves risk:

| window / symbol | metric | GATE OFF | GATE ON |
|---|---|---|---|
| AUDJPY 2024-06..09 (Aug-5 unwind) | net / PF / eqDD | 24.62 / 1.14 / 72.61 | **29.98 / 1.54 / 20.08 (DD -72%)** |
| USDJPY 2024-06..09 | net / PF / eqDD | -41.78 / 0.84 / 86.70 | **-4.76 / 0.94 / 39.82 (DD -54%)** |
| **AUDJPY FULL YEAR 2024** (142 calm + 82 risk-off days) | net / PF / tr / eqDD | -8.82 / 0.98 / 326 / 74.63 | **-8.42 / 0.97 / 231 / 34.37 (DD -54%, P&L flat)** |
| **USDJPY FULL YEAR 2024** | net / PF / tr / eqDD | -58.36 / 0.91 / 333 / 130.43 | **+2.80 / 1.01 / 235 / 57.73 (DD -56%, loss -> breakeven)** |

Full-year (calm + crash) confirms the gate does **not** hurt during calm / false-alarm
risk-off stretches - net is flat or much better while DD is roughly halved. Blocked ~95-98
of ~330 entries per year (the risk-off ones). Robust across both carry symbols.

## Hardening applied (Codex independent QA 2026-07-18, all 7 findings)
`docs/memory_control/CODEX_MACROGATE_REVIEW.md`. Verdict was fix-then-ship; fixes landed:
1. (blocker) reader fails OPEN if a dead watchdog stranded a GV — `GlobalVariableTime` age
   check in Execution readers (LIVE only; tester-guarded so backtests are unaffected).
2. (blocker) ran the regression cage — core edits proven inert (identical trade counts).
3. per-pass file-freshness re-check in `MG_Tick` (live only) — stale/deleted file fails safe
   between reloads, not only at reload.
4. non-ascending regime CSV -> guard INACTIVE (was a warning) so it can't skip an as-of row.
5. lot-only mode (`BlockNew=false`) now deletes any stale block GV.
6. NaN / out-of-range lot multiplier -> no-op (`MathIsValidNumber`).
7. stricter CSV datetime shape check before `StringToTime`.
A/B re-run after hardening: identical numbers (tester-guards keep backtest behaviour stable).

## Deploy notes (when the user chooses to attach)
- Best fit: breakout / momentum carry legs (they enter during risk-off). Grids that open-early
  then manage get no benefit (harmless).
- Live: use the standalone `(Boss)_MacroGate` watchdog (configure the carry magics) OR the
  in-chassis `_MG_SelfGate`. Regime CSV reaches the VPS via the same rclone path as the news
  CSV; add an `mris_export_regime` step to the daily chain to append today's state.
- This is one window's evidence (2024, in-sample around a known event). A different holdout
  year would strengthen it further before sizing up.
