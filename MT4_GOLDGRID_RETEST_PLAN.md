# MT4 GOLD-GRID RE-TEST PLAN — sizing-adjusted re-examination
**Created 2026-06-23.** User-directed: the DD>40% hard-cap was too crude (DD is partly tunable via
lot/spacing). Re-test the high-PF gold grids killed on DD/grid BEFORE final verdict. User wants ALL
levers tried: lower lot · widen grid spacing · stretch SL/TP/filter · let optimizer find DD-budget sizing.

> ## ✅ CLOSED 2026-07-02 (Claude Fable) — ALL 3 TARGETS FAIL, gold-grid concept confirmed dead
> **Elephant/Mammoth:** Phase 2 artifact gate — PF collapsed **85.14 (Model 2, 06-29) → 1.41 (Model 1,
> 07-02)** + DD 53.65%/yr even at capped MaxOrder=4. Artifact confirmed, not deployable.
> **Gold Stuff V7:** Phase 1 mechanism gate alone DQs it (`iMO=100` practically uncapped + `SL=0` +
> `MM=1.5` martingale) — Phase 2 confirms with DD=77.11%/yr blowup. DQ stands.
> **KRAPOOK:** not re-tested this round — EXPIRED license makes it un-deployable regardless of test
> outcome; remains "technique reference only" per its existing verdict.
> **Environment limitation hit:** ThinkMarkets-Live 4 has **no M1/tick history cached for XAUUSDMINI
> before ~2026-03** (Model 0 and Model 1 both returned NO_DATA for 2023-2025 windows) — true Model-0
> every-tick could not be run for the full 3.5yr window as originally planned. Substituted **Model 1
> (control points) on the most recent 1-year window with real cached data (2025.06-2026.06)** as the
> best-available decisive test — this is a materially better simulation than Model 2 (open-price-only,
> which is what created the PF-85/PF-0.25 artifacts) and was sufficient to give an unambiguous verdict.
> To get true Model-0 coverage of the full history later, sync History Center for XAUUSDMINI M1 via
> the MT4 GUI first (headless runs can't trigger this download).
> **Result matches the plan's own "if ALL fail" expected outcome** (§EXPECTED OUTCOMES below) — Phase 3
> sizing/spacing sweep is NOT justified for any of the 3 targets. This plan is DONE, do not re-open
> without a genuinely different gold-grid EA (not a Elephant/Mammoth/GoldStuffV7 re-test).
> Full evidence → `EA_SCORECARD_AND_REGISTRY.md` MT4 section · reports → `_mt4_auto/reports/PHASE2_*`.

## TARGETS (user-selected: "MT4 gold grids, PF สูง")
| EA (tester name) | prior verdict | prior result | caveat |
|---|---|---|---|
| `EA_Golden_Elephant` | DEAD | XAU 4.08 / 207t / 2.6%DD (sel) → 0.09 unseen | **tight-TP artifact**: TP200→2000 collapsed PF 7.77→0.06. Re-test MUST use realistic TP + Model 0 |
| `EA_Golden_Mammoth` | DEAD | identical MD5 to Elephant | skip if Elephant verdict holds (same binary) |
| `Gold Stuff EA V7.0` | DISQUALIFIED | XAU 5.09 / 4655t / 39%DD; pip×10 still churns 53%DD | suspected real martingale grid — Phase 1 decides |
| `KRAPOOK BLUE ANT GOAL KEEPER 1.00` | DISQUALIFIED | XAU 2.65 / best profile of pool | **EA EXPIRED** → backtest only as TECHNIQUE ref, cannot deploy |

## ENVIRONMENT (confirm before running)
- MT4: `D:\Meta4\terminal.exe`, data dir `...\208874223073CBC8F9A8DE40460E6DD0`. EAs present in MQL4\Experts (66 .ex4).
- **Last login = ThinkMarkets-Live 4** (deep data, XAU 2-digit). XAU symbol there = **`XAUUSDMINI`** (NOT XAUUSD/XAUUSDc). CONFIRM exact symbol string with a 1-bar test before sweeping.
- ThinkMarkets = validation engine (deep history + M1 ticks for Model 0). Exness cent = final deploy-validation (3-digit XAUUSDc). Do the "is-it-real" work on ThinkMarkets; re-confirm survivors on Exness cent.
- ⚠️ XAU digits differ: ThinkMarkets 2-digit vs Exness 3-digit → point params (Grid_Distance/SL/TP) ÷10 when porting.
- Close MT4 GUI before headless (`mt4_run.ps1` aborts if running). MT4 ≠ MT5 process → safe to run parallel to MT5 sweeps (watch CPU).
- Tools: `scripts\mt4_run.ps1` (single), `scripts\mt4_grid_sweep.ps1` (grid → CSV), `scripts\mt4_montecarlo.py`, parser `scripts\parse_mt4_report.py`.

## 3-PHASE GATED PROCEDURE (each phase gates the next)

### Phase 1 — MECHANISM GATE (decides if sizing can even help)
For each EA: run ONE backtest, open the trade log, check **does lot size escalate on losing trades?**
- **Uncapped martingale** (lot doubles, no step cap) OR **no hard SL + uncapped stacking** → DQ STANDS. Sizing can't fix structural ruin. Record + stop.
- **Bounded** (capped steps + SL, OR flat lot) → proceed to Phase 2.
Method: `mt4_run.ps1 -Expert "<name>" -Symbol XAUUSDMINI -Period H1 -FromDate 2024.01.01 -ToDate 2025.06.01 -ReportName MECH_<ea>` then inspect report's order list for lot progression (memory did this for EURUSD Forex Robot: "Lots flat 0.01, no escalation").

### Phase 2 — ARTIFACT GATE (is the edge real or a fill fiction?)
Re-run survivors with **realistic wide TP** AND **Model 0 every-tick** (ThinkMarkets M1 ticks).
- PF holds with wide TP on real ticks → real edge → Phase 3.
- PF collapses (like Elephant TP→2000 = 0.06) → artifact DQ. Record + stop.
This is THE decisive test for Elephant — Model 2 created the artifact; Model 0 exposes it.

### Phase 3 — SIZING/SPACING SWEEP (the user's ask)
For real-edge survivors: sweep to bring DD into a **10–15% budget** at proper sizing.
`mt4_grid_sweep.ps1` over: LotSize {↓ steps}, Grid_Distance/spacing {↑ steps}, SL/TP mult, any session/trend filter.
For each combo record PF, trades, **DD%**, MAR (=return÷DD), worst-streak. Then:
- Pick combo where DD ≤ budget AND MAR ≥ 0.5 AND net meaningful.
- **Stress it:** Monte Carlo (`mt4_montecarlo.py`) + a trend-stress regime (ThinkMarkets 2011-13 gold crash / 2020 / 2022) — closed-trade DD understates a grid's floating DD; historical worst-streak ≠ worst-possible.
- Pass all → CANDIDATE (deploy small, Exness-cent re-confirm). Fail → DEAD/DQ with evidence.

## EXPECTED OUTCOMES (honest priors)
- **Elephant/Mammoth**: prior decisive test already showed wide-TP collapse → likely artifact-DQ at Phase 2. Re-test gives it a fair, documented shot rather than a guess.
- **Gold Stuff V7**: churn + DD53% after pip-fix → likely uncapped-martingale DQ at Phase 1.
- **KRAPOOK**: even if it passes all phases, EXPIRED = cannot deploy; value is the distance-scaling technique to port onto a non-expired EA.
- If ALL fail → the gold-grid concept is confirmed dead WITH per-EA evidence (not a crude DD cap). If any survives → genuine new CANDIDATE.

## RUN ORDER
Run AFTER (or parallel-to, separate terminal) the MT5 Q1/Q2/R1/R2 queue. Phase 1 is cheap (~3 tests,
~5 min) — do it first to kill the no-hope ones before investing in slow Model-0 runs.
Results → append to `D:\EA_LAB\EA_SCORECARD_AND_REGISTRY.md` Part 2 + the DD RE-TEST batch table.
