# EA Template xx-00 Family Ratification V1

Status: `OWNER_RATIFIED / RESEARCH_REFERENCE_ONLY / NO_RUNTIME_AUTHORITY`
Date: 2026-09-09
Source decision support: `EA_TEMPLATE_XX00_NATIVE_MECHANIC_SOURCE_MAP_V1.md`

## Purpose

This file records the owner's explicit B11-B18 `xx-00` family-semantic ratification. It is a research/reference contract only. It does not create executable EA instances, resolve legacy H01 aliases, select optimized values, or authorize runtime/default/risk/deployment/trading changes.

## Generic owner-ratified baseline

- Stack reference: `GRID_AGAINST`.
- Stack distance reference: `ATR x 2.0`.
- ATR timeframe: `PERIOD_CURRENT`, meaning the timeframe of the current test/reference cell.
- ATR period: explicit per future family reference; no value is inferred here.
- Stack confirmation reference: `DISTANCE`.
- Generic Exit reference: `ATR_BASED` unless a family-native Exit concept is explicitly ratified below.
- Basket protection reference: `BASKET_BALANCE_STOP` at 10% of current account balance, scoped to the EA-owned basket.
- Native rule: a mechanic is native only when removing it changes the intended family strategy hypothesis.

## Owner-ratified family map
| Family | Ratified native semantics |
| --- | --- |
| B11 GridTrend | `NONE` |
| B12 Breakout | `NONE` |
| B13 MeanRev | `NONE` |
| B14 GridLog | `GRID_STACK` + `LOG_POWER_PROGRESSION` + `BASKET_TARGET_OWNERSHIP` |
| B15 ST03 | `NONE` |
| B16 Kangaroo | `ADVERSE_ATR_GRID` + `KANGAROO_LOT_LAW` + `OWNED_BASKET_OVERLAP_EXITS` |
| B17 Wave5 | `WAVE1_STRUCTURAL_INVALIDATION_SL` + `SINGLE_WHEN_STRUCTURAL` |
| B18 JumStoch | `NONE` |

## Family boundaries

### B14 GridLog

The native decision is concept-level. Grid, LOG-power progression, and basket-target ownership define the intended family reference. No H01 numeric multiplier, lot factor, basket-target value, `SL_NONE`, optimized center, ATR period, or historical account-risk value is inherited. Basket-target ownership is the ratified native Exit concept; its numeric target remains unresolved until separately specified.

### B16 Kangaroo

The native decision covers the adverse ATR-grid concept, Kangaroo-owned lot law, and Kangaroo-owned basket/overlap Exit pipeline. It does not ratify historical numeric spacing, lot factors, DD thresholds, or other risk/default values. Safety cages remain safety semantics, not family-native alpha mechanics.

### B17 Wave5
The native decision is limited to the Wave-1 structural invalidation SL concept plus the compatibility invariant `SINGLE_WHEN_STRUCTURAL`. Structural target/TP/Exit ownership is **not** ratified native in V1; the generic `ATR_BASED` Exit remains the research reference unless a later owner-visible contract changes that decision.

## Residual semantics that remain explicit

- `ATRPeriod` is still unresolved per family/reference and must be supplied prospectively.
- No custom/cross-timeframe ATR source is ratified; the current baseline is `PERIOD_CURRENT` only.
- Numeric native parameterization for B14/B16 is not inherited from H01/current defaults.
- No H01/Home/Package/config identity is promoted to `Bxx-00` by this decision.
- Stronger StackConfirm modes remain separate prospective experiment scope and are not family overrides here.

## Authority boundary

This ratification may be consumed by repository-only deterministic schema/tooling that records research/reference family semantics. It does **not** authorize EA source mutation, executable `Bxx-00` construction, MT5/backtest/optimization/HOLDOUT, Candidate/Grade/KINT, risk/default changes, runtime attachment, deployment, trading or LIVE.

The next authorized consumer is a fresh `ORDER-XX00-SCHEMA-V2` contract. V1 schema implementation remains blocked/unpushed and is not repaired in place.