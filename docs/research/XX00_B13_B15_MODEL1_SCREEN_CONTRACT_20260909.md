# XX00 B13/B15 Model1 Screen Contract - 2026-09-09

Status: `PREREGISTERED / OWNER_APPROVED / MODEL1_ONLY / NO_HOLDOUT / NO_OPTIMIZATION`
Canonical parent: `95238bb0c2b3f2b8c0689ad411a864f8b3e9cba5`
Direct consumer: determine whether the two owner-ratified fast-start references show a dual-window research pulse worth later continuation.

## Fixed cells

Exactly four new cells are authorized:

1. B13 MeanRev, XAUUSD/M15, MAIN `2023-01-01..2025-12-31`.
2. B13 MeanRev, XAUUSD/M15, BWD `2020-01-01..2022-12-31`.
3. B15 ST03, GBPUSD/H4, MAIN `2023-01-01..2025-12-31`.
4. B15 ST03, GBPUSD/H4, BWD `2020-01-01..2022-12-31`.

Tester contract: MT5 Model 1 / 1 Minute OHLC minimum, USD 10,000, leverage 1:100, `Optimization=0`, `Forward=0`, same installation lineage per family, runtime target `D:\Meta 5c` / MT5 lane3 unless Lane Registry blocks it.

## Exact source and config

- B13 wrapper: `ea_template/Boss_13_MeanRev.mq5`.
- B15 wrapper: `ea_template/Boss_15_ST03.mq5`.
- B13 derived set SHA256: `889ACCB0A703521C03B7526055F3D4EB97259F4DA25DC954A3DF859DD1C5FAFE`.
- B15 derived set SHA256: `405956B20848E1D346654C2EB67140A5BB5A1A71386EC44460C88187B84CAD52`.
- Derived set bytes are frozen before any outcome is observed and are generated from the exact regression baselines plus only the owner-ratified/test-control overrides recorded in `EA_TEMPLATE_XX00_WAVEA_FASTSTART_RATIFICATION_20260909.md`.
## Mechanical acceptance

Each cell must have: exact symbol/TF/window/model; full set-surface acceptance; current canonical source/build identity; fresh non-truncated report; history quality reported; optimization zero; exact set SHA; and no HOLDOUT date overlap.

Compile current B13/B15 wrappers before the screen if the accepted EX5 identity is not already source-bound to this exact canonical parent. Compile failures are mechanical/environment blockers, not strategy verdicts.

## Decision rule

For each family separately:

- `DUAL_WINDOW_SCREEN_PULSE` only if MAIN and BWD are mechanically valid and both have PF > 1.0 and net profit > 0.
- Otherwise `NO_DUAL_WINDOW_SCREEN_PULSE`.

Trade count and native EqDD must be reported, but this contract defines no universal trade floor, Grade threshold, KINT mapping, promotion bar or risk threshold.

BWD is validation only. It may reject the frozen reference but may not select another parameter value, Home, StackConfirm, Exit multiplier, depth or entry setting.

## Hard stops

No optimization, no parameter search, no HOLDOUT, no Model4 in this order, no Candidate/Grade/KINT, no DEMO/LIVE/runtime attachment, no risk/default change, no cross-install comparison and no automatic continuation after the four cells.

A later Candidate path still requires the canonical Model4 MAIN+BWD rule on one frozen accepted installation lineage.