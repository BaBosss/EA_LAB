# Facebook-derived strategy designs — EA Template V2

Status: **DESIGN_ONLY / NON_EXECUTABLE / NO_RUNTIME_AUTHORITY**
Owner approval date: 2026-09-22
Source basis: owner-supplied Facebook screenshots describing two EAs; no original source code was supplied in this lane.

This library records two new owner-approved **derived strategies**, not source-code clones:

- `FB-A01` — Adaptive Donchian Trend Flip: Donchian breakout + SuperTrend confirmation + ATR-percentile volatility gate + close/flat/reverse state machine.
- `FB-G01` — Persistent Adaptive Donchian Grid: physical multi-position grid + Donchian regime director + adaptive spacing + zone clamp + basket exit + persistent cycle state.

The screenshots support the broad concepts and named mechanisms, but not every formula, parameter or equality/finality rule. Any detail not visible in the supplied evidence is explicitly treated as a new owner-approved EA_LAB design choice or left unresolved for an executable contract.

## Relationship to existing families

`FB-A01` is not the existing `(TRD)_SuperTrendFlip` and not `Boss_12_Breakout`. It requires Donchian to own the breakout trigger, SuperTrend to confirm direction, an ATR-percentile regime gate, and an explicit close -> flat-verify -> reverse sequence.

`FB-G01` is not ZCAG. ZCAG keeps the adverse ladder virtual and compresses exposure into one later entry; FB-G01 intentionally uses **real sequential grid fills** while the cycle is active. It is also not an automatic mutation of B11/B14 or other current grid families.

## Authority ceiling

These cards create no FamilyID, LAB_ENTRY, PARAM_REGISTRY rows, `.set`, MT5 execution, optimizer, HOLDOUT use, DEMO/LIVE status, risk-default change or trading authority.
