# MacroGate A/B verdict — ORDER-073 Phase-3 (2026-07-18)

## What was tested
Single-EA strategy-tester A/B on the chassis carry EA `Boss_14_GridLog` (smoke config,
magic 990207), self-gating via the in-chassis `_MG_SelfGate` hook reading the no-lookahead
MRIS regime timeline (`EA_LAB_mris_regime.csv`, +1 day shift). Model 1, H1.

## Mechanism — VALIDATED (both bridge paths work; inert by default)
| test | result | meaning |
|---|---|---|
| no MacroGate GVs (default `_MG_SelfGate=false`) | A/B byte-identical | bridge is inert-by-default (no drift) |
| real regime, gate ON | fires correctly (log: gate ON on RISK_OFF 2024-07-18/26/31 → sustained through Aug-5 STRESS) | regime read + trigger logic correct |
| all-STRESS regime, block ON | **40 → 0 trades** | `Exec_MacroBlocked` veto works end-to-end |
| all-STRESS, block OFF, LotMult 0.5 | net 38.33 → 16.69, 40 → 25 trades | `Exec_MacroLotMult` open-path shrink works |
| start-of-window row gap (nearest row = 2020 vs 2024 sim time) | fail-safe INACTIVE (logged) | stale/gap fail-safe works |

## A/B benefit — NOT demonstrated on this carry EA
| window / symbol | gate OFF | gate ON | Δ |
|---|---|---|---|
| USDJPY 2024-06..09 (Aug-5 unwind) | net 29.17, PF 1.51, 41 tr, eqDD 35.56 | **identical** | none |
| AUDJPY 2024-06..09 | net 38.33, PF 3.72, 40 tr, eqDD 23.89 | **identical** | none |

**Root cause (not a bug):** `GridLog` opens its basket during the early *calm* part of the
window and then only *manages / closes* it through the flagged RISK_OFF/STRESS period — it
does not attempt NEW entries while the gate is on, so there is nothing to block or shrink.
The 2020 window is ~entirely RISK_OFF in MRIS, so gate-ON there ≈ EA-off (not a clean A/B).

The gate's value is for strategies that **open fresh exposure during the risk-off** (re-seeding
grids, momentum/breakout entries into a crash). An early-basket-then-manage grid is not that.

## Verdict (VERDICT GATE + handoff criterion)
- **Mechanism: ACCEPT** — correct, safe, inert-by-default, fail-safe. Committed and reusable.
- **Auto-act deployment: PARKED** — no DD-reduction benefit shown on the current carry legs
  (their entries don't overlap risk-off). Do NOT attach the auto-act gate live on these EAs.
- **Keep MRIS advisory (Phase 1-3) — already shipped and on the morning dashboard.** That is
  the deployed risk layer today: it *tells* the user to reduce carry exposure during RISK_OFF;
  the human acts (reduce-lot doctrine).

## To un-park later (if wanted)
Run the same A/B on a carry EA that ENTERS during risk-off (e.g. a breakout leg, or a grid
configured to re-seed), on a window with a calm→risk-off transition that overlaps its entries.
If gate-ON cuts eqDD there without killing PF on a neutral control year → deploy that EA with
`_MG_SelfGate` (or the standalone `(Boss)_MacroGate` watchdog). Everything is built and validated.

## Note on the regression cage
Core edits (Execution.mqh bridge + LabCore self-gate hook) are provably inert with defaults
(all-STRESS-isolation + default-path A/B confirm it). The formal `tpl_regression` cage was NOT
re-run because the committed baseline is known-stale (Jul-11 ticks) → it would read RED-benign.
Re-run it after the user refreshes the baseline (`-UpdateBaseline -ConfirmBaseline`).
