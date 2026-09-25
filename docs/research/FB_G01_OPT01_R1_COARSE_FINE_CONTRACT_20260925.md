# FB-G01 OPT01-R1 — Coarse-to-Fine Optimization Contract

Status: PREREGISTERED / OWNER-APPROVED STAGE-A EXECUTION ONLY
Date: 2026-09-25
Parent contract: FB_G01_OPT01_CYCLE_GEOMETRY_CONTRACT_20260925.md
Supersedes its search lattice/counts only; causal thesis, risk ceiling, MAIN/BWD/HOLDOUT boundaries remain unchanged.

## Identity
- Family: FB-G01 Persistent Adaptive Donchian Grid
- Expert/build: Boss_25_PersistentAdaptiveGrid / LAB_ENTRY_25
- Accepted source: 8da04fc789ca55e6c673d41899e9136cfa72a75e
- R1 base canonical: 3d6941ab0f0edbacffbb60022cd84113d6a288b6
- Home: XAUUSD/H1
- Model: MT5 Model1 / 1 Minute OHLC
- MAIN: 2023-01-01..2025-12-31
- BWD: 2020-01-01..2022-12-31, validation only
- HOLDOUT: UNSPENT / FORBIDDEN
- Deposit: USD 10,000; leverage 1:100

## Frozen risk / chassis
Freeze V0 defaults for every cell:
ATRPeriod=14; MaxRungsPerSide=5; FixedLot=0.01; SpreadSamples=50; SpreadMedianMult=2.5; SpreadATRCap=0.10; OpenCooldownSec=1; ProtectLevel=2; RC_MaxLevelsOverride=0; all other shared inputs unchanged.
No lot/rung/risk/default/safety tuning.

## Tunables
Only:
- _25_GridPct
- _25_GridATRMult
- _25_BasketTargetBalancePct
- _25_DonchianBars

optimize_guard preflight must remain ALLOW 4 / REFUSE 0. SkipOptimizeGuard forbidden.

## Stage A1 — coarse grid geometry
MAIN only. COMPLETE 3x3 surface:
- GridPct = {0.10, 0.30, 0.50} (owner step 0.20)
- GridATRMult = {0.25, 0.75, 1.25} (owner step 0.50)
Freeze BasketTargetBalancePct=0.25 and DonchianBars=20.
Exactly 9 cells.

A1 mechanically valid cell must preserve exact build/set/config identity and requested window/model/leverage.
A1 strategy-qualified cell must:
- reach MAIN end without shared hard-risk halt;
- finite metrics;
- net > 0.

A1 region rule: inspect the four possible adjacent 2x2 blocks. A block is admissible only if all four cells are strategy-qualified.
Select block deterministically:
1) max minimum net across its 4 cells;
2) higher minimum trades;
3) lower maximum native EqDD%;
4) smaller aggregate lattice distance to V0 0.25/0.75;
5) lower GridPct lower bound, then lower ATR lower bound.

If no admissible 2x2 block: stop OPT01-R1 = COARSE_SPACING_REGION_NOT_ESTABLISHED.
No range widening or fallback single-cell winner.

## Stage A2 — fine grid geometry
Only after A1 selects a 2x2 coarse block.
Insert half coarse steps:
- GridPct fine step = 0.10
- GridATRMult fine step = 0.25
Use exactly the 3x3 lattice spanning the selected block endpoints plus midpoint = 9 cells.
Freeze target=0.25, Donchian=20.

Fine center plus four orthogonal neighbours must each be mechanically valid, full-window/no-hard-kill, finite and net>0.
Select spacing center by:
1) max minimum net of five-cell cross;
2) higher minimum trades;
3) lower maximum EqDD%;
4) distance to V0;
5) lower GridPct then lower ATR.
If none: stop = FINE_SPACING_PLATEAU_NOT_ESTABLISHED.

## Stage B1 — coarse basket target
Only after A2 lock.
Freeze selected spacing and Donchian=20.
Owner coarse lattice:
{0.10,0.30,0.50,0.70,0.90} plus 1.00 boundary probe = 6 cells.
The 1.00 cell is boundary evidence; it cannot trigger expansion above 1.00.

Eligible adjacent coarse interval among regular 0.20-step points requires both endpoints mechanically valid, full-window/no-hard-kill, finite, net>0.
Select interval by max minimum net -> min trades -> max DD -> distance to V0 target 0.25 -> lower interval.
If no interval: stop TARGET_COARSE_REGION_NOT_ESTABLISHED.
A lone best 1.00 boundary cell is not an admissible region.

## Stage B2 — fine basket target
Only after B1 selects interval [x,x+0.20].
Run {x, x+0.10, x+0.20} = 3 cells.
All three must be mechanically valid, full-window/no-hard-kill, finite, net>0.
Select center x+0.10 if all pass; otherwise stop TARGET_FINE_PLATEAU_NOT_ESTABLISHED.

## Stage C — Donchian
Keep prior approved design:
DonchianBars={10,15,20,25,30,35,40} = 7 MAIN cells.
Eligible center in {15,20,25,30,35}; center±5 all mechanically valid, full-window/no-hard-kill, finite, net>0.
Selector: max minimum net -> minimum trades -> maximum DD -> distance to V0 20 -> lower value.
If none: stop DONCHIAN_PLATEAU_NOT_ESTABLISHED.

## Stage D — final neighbour stability
Keep prior approved 9-cell orthogonal cross around assembled center:
- center
- GridPct ±0.05
- GridATRMult ±0.25
- BasketTargetBalancePct ±0.05
- DonchianBars ±5

Every cell: mechanical PASS, full MAIN, no hard kill, finite, net>0, >=100 closed trades.
Center additionally MAIN PF>=1.20.
Any failure => FINAL_NEIGHBOR_STABILITY_FAIL; no fallback center.

## Final fixed validation
If D passes:
- one fixed MAIN reproduction, same bars, PF>=1.20, >=100 trades, no hard kill;
- then exactly one fixed BWD same EX5/set.
BWD must be mechanical PASS, full window, PF>=1.00, >=100 trades.
BWD fail => CENTER_REJECTED_BWD / NO_RETUNING.
BWD pass => FROZEN_FINALIST_NOT_CANDIDATE.
BWD never selects parameters.

## Loop breaker / authority
No range expansion. No extra dimensions. No post-result retuning. No BWD search. No HOLDOUT. No Model4 under this contract. No Candidate/Grade/KINT. No deployment/trading.

Maximum cells if all stages reached:
A1 9 + A2 9 + B1 6 + B2 3 + C 7 + D 9 + fixed MAIN 1 + fixed BWD 1 = 45.

Owner approval in current chat authorizes execution of A1 only after this R1 contract is reviewed and canonical.
Later stages are mechanically eligible only if their predecessor's preregistered selector passes; they do not require new ranges.

Current execution ceiling:
STAGE_A1_EXECUTION_AUTHORIZED=true
STAGE_A2_PLUS_EXECUTION_AUTHORIZED=conditional_on_prior_stage
