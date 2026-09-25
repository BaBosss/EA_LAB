# FB-G01 OPT01 — Cycle Geometry / Turnover Optimization Contract

Status: **PREREGISTERED / RESEARCH_ONLY / NOT_EXECUTED**
Date: 2026-09-25
Lane: `ct-fb-g01-opt01-prereg-20260925`
Family: FB-G01 Persistent Adaptive Donchian Grid
Expert: `Boss_25_PersistentAdaptiveGrid`
Build identity: `LAB_ENTRY_25`

## 1. Direct consumer

Determine whether the accepted FB-G01 XAUUSD/H1 V0 can produce a **full-window, participation-qualified, locally stable MAIN plateau inside the existing safety cage** by tuning only strategy-owned cycle geometry / turnover inputs.

This contract is designed to answer that question without changing risk defaults, lot sizing, rung-cap policy, shared hard-risk behavior, spread/data guards, HOLDOUT, or execution semantics.

The optimizer maps a stable region. It does not promote a top-PF row.

## 2. Accepted parent evidence — reuse, do not rerun

Accepted source head:
`8da04fc789ca55e6c673d41899e9136cfa72a75e`

Canonical fixed Model1 evidence entered at:
`1ff86cb8fd8fca6eae747ea7a9457dfde4653624`

Current state-sync canonical at preregistration:
`069e2f34f543456a00da9b2f6ba775f111aceafc`

Home:
- Symbol: XAUUSD
- Chart TF: H1
- Model: MT5 Model 1 / 1 Minute OHLC
- Deposit: USD 10,000
- Leverage: 1:100
- HOLDOUT: UNSPENT

Parent V0 identity:
- full surface: 160/160
- parent set SHA256: `a9d434bf37ddc3a4ed8a906a6b1e640ef71e7abde286fcd9f9b194eb95bc5a57`
- parent config fingerprint: `c9a9f95094d8d92e059ec7c894de76f57dce5d25a9b97792e3acd3ea3927d6d8`

Parent MAIN 2023-2025:
- PF 0.23
- net -2188.86
- 46 trades
- EqDD 25.05%
- 16 cycles
- explicit shared hard-risk kill at 25.05% >= 25.00%
- classification: `SAFETY_HALT`

Parent BWD 2020-2022:
- PF 5.54
- net +571.73
- 57 trades
- EqDD 16.01%
- 24 cycles
- no hard kill
- final live 3-position cycle liquidated by tester at end of window

Observed parent max exposure: 3 positions / 0.03 lots.

## 3. Causal claim

The MAIN safety halt is not an implementation or identity failure. It is a valid path in which V0 cycle geometry reaches the existing safety boundary.

The prospective claim is:

> A semantics-preserving combination of wider/narrower physical grid spacing, basket turnover target, and Donchian memory can reduce adverse inventory accumulation while increasing cycle participation enough to reveal a positive, non-boundary MAIN plateau **without changing the safety cage or position sizing**.

The contract therefore separates causal knobs into stages instead of optimizing all exposed inputs together.

## 4. Frozen architecture / forbidden tuning

The following remain frozen to the accepted V0 defaults for every OPT01 cell:

- `_25_ATRPeriod = 14`
- `_25_MaxRungsPerSide = 5`
- `_25_FixedLot = 0.01`
- `_25_SpreadSamples = 50`
- `_25_SpreadMedianMult = 2.5`
- `_25_SpreadATRCap = 0.10`
- `_25_OpenCooldownSec = 1`
- `ProtectLevel = 2`
- `RC_MaxLevelsOverride = 0`
- all other shared/chassis/runtime inputs exactly as the accepted V0 full-surface set

No generic Stack, Recovery, Hedge, martingale, lot escalation, additional rung depth, new exit, new filter, new risk/default, or safety-threshold change is allowed.

Shared hard RiskControl remains authoritative. A safety kill is strategy evidence, not a mechanical failure.

## 5. Tunable dimensions and preregistered ranges

Only four strategy-owned inputs may vary, and only in the staged sequence below.

| Parameter | Baseline | Preregistered lattice | Role |
|---|---:|---|---|
| `_25_GridPct` | 0.25 | 0.10..0.50 step 0.05 | percent-of-anchor spacing floor |
| `_25_GridATRMult` | 0.75 | 0.25..1.50 step 0.25 | volatility-scaled spacing |
| `_25_BasketTargetBalancePct` | 0.25 | 0.10..0.40 step 0.05 | cycle turnover / basket target |
| `_25_DonchianBars` | 20 | 10..40 step 5 | regime-memory horizon |

All values preserve the accepted formulas:
- `Spacing = max(Anchor * GridPct / 100, ATR14[1] * GridATRMult)`;
- basket target remains cycle-start-balance percentage;
- Donchian remains the same strict closed-bar breakout director.

No value may be added or removed after observing results under OPT01.

## 6. Search data / execution identity

Search surface:
- XAUUSD / H1
- MAIN only: 2023-01-01 .. 2025-12-31
- Model 1 / 1 Minute OHLC
- Optimization ForwardMode = 0
- HOLDOUT forbidden
- BWD forbidden until one final center is locked

Runtime target:
- `MT5-lane1 / D:\Meta 5`
- serial ownership required

Before execution:
- compile exact accepted source lineage on the selected installation;
- require 0 errors / 0 warnings;
- create one fresh build receipt;
- freeze one EX5 SHA256 for all OPT01 stages;
- derive all optimizer/fixed sets from the same accepted 160/160 parent surface;
- `optimize_guard.ps1` must ALLOW every swept dimension;
- `-SkipOptimizeGuard` is forbidden.

## 7. Stage A — COMPLETE spacing landscape

Purpose: determine whether physical spacing alone can remove the MAIN safety halt and expose a positive local region while target and regime memory remain at V0 defaults.

Swept:
- `_25_GridPct = {0.10,0.15,0.20,0.25,0.30,0.35,0.40,0.45,0.50}`
- `_25_GridATRMult = {0.25,0.50,0.75,1.00,1.25,1.50}`

Frozen:
- BasketTargetBalancePct = 0.25
- DonchianBars = 20

Execution:
- MT5 complete optimization (`Optimization=1`)
- exact 9 x 6 = **54 cells**
- criterion value is metadata only; it is not the selector

A mechanically valid Stage-A cell may be losing, may hit the safety kill, or may have low participation; those are strategy outcomes and must remain in the surface.

### Stage-A plateau eligibility

A center must be interior on both spacing axes:
- GridPct center ∈ {0.15,0.20,0.25,0.30,0.35,0.40,0.45}
- GridATRMult center ∈ {0.50,0.75,1.00,1.25}

The center plus its four orthogonal one-step neighbors must each:
- be mechanically accepted;
- reach the requested MAIN window end without a shared hard-risk halt;
- have finite metrics;
- have MAIN net profit > 0.

The canonical 100-trade floor is **recorded but not applied yet** at this spacing-only stage because basket target and Donchian memory are prospectively reserved later in this same contract to address turnover/participation. This is an interim region test, not performance-bar clearance.

If multiple spacing centers qualify, select deterministically:
1. maximize the minimum MAIN net profit across the five-cell cross;
2. higher minimum trade count across the cross;
3. lower maximum native EqDD% across the cross;
4. smaller Manhattan lattice distance from V0 0.25 / 0.75;
5. lower GridPct, then lower GridATRMult as final deterministic tie-break.

If no spacing center qualifies, OPT01 stops:
`SPACING_PLATEAU_NOT_ESTABLISHED`.

Do not proceed to target/Donchian tuning and do not widen ranges under this contract.

## 8. Stage B — basket-target turnover sweep

Runs only if Stage A selects one spacing center.

Freeze the selected GridPct / GridATRMult and DonchianBars=20.

Complete MAIN sweep:
`_25_BasketTargetBalancePct = {0.10,0.15,0.20,0.25,0.30,0.35,0.40}`
= **7 cells**.

An eligible target center must be interior:
`{0.15,0.20,0.25,0.30,0.35}`

The center and its ±0.05 neighbors must each:
- be mechanically accepted;
- reach MAIN window end without hard-risk halt;
- have finite metrics;
- have net > 0.

Select:
1. maximum minimum net across the three-cell line;
2. higher minimum trades;
3. lower maximum EqDD%;
4. smaller distance from V0 target 0.25;
5. lower target value final tie-break.

If none qualifies:
`TARGET_PLATEAU_NOT_ESTABLISHED` and OPT01 stops.

No target-range expansion is authorized.

## 9. Stage C — Donchian-memory sweep

Runs only if Stages A+B select spacing and target centers.

Complete MAIN sweep:
`_25_DonchianBars = {10,15,20,25,30,35,40}`
= **7 cells**.

Eligible center:
`{15,20,25,30,35}`.

Center and ±5 neighbors must each:
- be mechanically accepted;
- reach MAIN window end without hard-risk halt;
- have finite metrics;
- have net > 0.

Select:
1. maximum minimum net across the three-cell line;
2. higher minimum trades;
3. lower maximum EqDD%;
4. smaller distance from V0 DonchianBars 20;
5. lower DonchianBars final tie-break.

If none qualifies:
`DONCHIAN_PLATEAU_NOT_ESTABLISHED` and OPT01 stops.

No Donchian-range expansion is authorized.

## 10. Stage D — final four-dimensional neighbor stability

Construct one final center from the Stage A+B+C selections.

Run exactly the **9-cell orthogonal cross**:
- center;
- GridPct ±0.05;
- GridATRMult ±0.25;
- BasketTargetBalancePct ±0.05;
- DonchianBars ±5;
with all other values frozen.

Every one of the nine cells must:
- be mechanically accepted;
- complete the entire MAIN window without hard-risk halt;
- have finite PF/net/DD/trades;
- have MAIN net > 0;
- have **>=100 closed trades**.

The center itself must additionally have:
- MAIN PF >= 1.20.

If any of the nine cells fails the neighbor rule:
`FINAL_NEIGHBOR_STABILITY_FAIL` and OPT01 stops.

There is no fallback center, no second-best replay, no range widening, and no extra parameter dimension under OPT01.

If all nine pass:
`MAIN_PLATEAU_LOCKED`.

## 11. Fixed center reproduction and BWD validation

Only after `MAIN_PLATEAU_LOCKED`:

1. create one full-surface fixed set at the locked center;
2. run one fixed MAIN Model1 reproduction;
3. require optimizer-center reproduction within normal report rounding and:
   - full window;
   - no hard-risk halt;
   - PF >= 1.20;
   - >=100 closed trades;
4. only then run one fixed BWD 2020-01-01..2022-12-31 validation using the **same EX5 and exact set**.

BWD is validation only. It may not choose another cell or trigger retuning.

For BWD to clear the current research bar:
- mechanically valid;
- full requested window;
- no source/config drift;
- PF >= 1.00;
- >=100 closed trades.

If BWD fails the research bar, preserve the result and stop:
`CENTER_REJECTED_BWD / NO_RETUNING`.

Do not search another OPT01 cell using BWD evidence.

If BWD clears:
`FROZEN_FINALIST_NOT_CANDIDATE`.

That status still does not authorize Candidate. Model-4 MAIN+BWD on the mandatory acceptance-critical lineage remains a later separate gate.

## 12. Required evidence

Each stage must preserve:
- exact source/build receipt/EX5/set/config identity;
- optimizer or fixed-run raw artifact;
- all cells including losses, safety halts and low-participation rows;
- PF finite/nonfinite status, net, native EqDD, trades;
- cycle count;
- max concurrent owned positions;
- max aggregate lots;
- max filled rungs per side;
- safety-halt count/time;
- persistence/account-baseline diagnostics;
- tester end-of-window liquidation count;
- decision-specific surface/neighbor visual.

Do not describe basket target trigger money as realized net profit.

Grid span must be reported when derivable. If exact normalized grid span is not exported, state `UNAVAILABLE_NOT_EXPORTED`; do not fabricate it.

## 13. Loop breaker

OPT01 ends immediately on the first applicable stop:
- no Stage-A spacing plateau;
- no Stage-B target plateau;
- no Stage-C Donchian plateau;
- final 9-cell stability failure;
- fixed MAIN reproduction failure;
- BWD validation failure;
- mechanical identity failure that cannot be repaired within a separately authorized mechanical recovery.

Under this contract:
- no range expansion;
- no additional parameter dimension;
- no post-result retuning;
- no BWD search;
- no HOLDOUT;
- no Model4;
- no Candidate/Grade/KINT;
- no deployment/runtime attachment/trading;
- no risk/default change.

A later experiment must be a new prospective hypothesis with its own direct consumer.

## 14. Execution count ceiling

If every stage is reached:
- Stage A: 54 MAIN optimization cells
- Stage B: 7 MAIN optimization cells
- Stage C: 7 MAIN optimization cells
- Stage D: 9 MAIN fixed neighbor cells
- fixed center MAIN: 1 cell
- fixed BWD: 1 cell

Maximum contract exposure: **79 Model1 cells**.

No cell outside these preregistered surfaces is authorized.

## 15. Current preregistration disposition

This document freezes the design only.

`OPTIMIZER_EXECUTION_AUTHORIZED = false`

The next action is an explicit owner/Control-Tower execution approval for this exact contract, followed by runtime-lane admission and deterministic generation of the Stage-A full-surface optimization set.

HOLDOUT remains **UNSPENT**.

## 16. Preregistration optimize-guard preflight

Before any optimizer execution, the canonical optimize guard was run directly against build 25 for the four proposed swept dimensions.

Result: **ALLOW 4 / REFUSE 0**.

Allowed:
- `_25_GridPct`
- `_25_GridATRMult`
- `_25_BasketTargetBalancePct`
- `_25_DonchianBars`

All four are currently classified ACTIVE for build 25 with no build-inert, override, or safety conflict. No `-SkipOptimizeGuard` was used.

This is a binding/preflight result only. It does not authorize MT5 optimizer execution.
