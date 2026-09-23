# ZABgoldpending — prospective pretest freeze — 2026-09-23

Status: `OWNER_RISK_FROZEN / INPUT_SURFACE_QUALIFIED / MONEY_MODE_SEMANTICS_REQUIRED / READY_FOR_TEST=false`

Authority: `RESEARCH_ONLY_DOCUMENTARY`. This freezes source-grounded and current-governance pretest fields only. It does not authorize a performance backtest, optimization, HOLDOUT use, Candidate/Grade/KINT decision, deployment, runtime, DEMO/LIVE, or trading.

## Source identity

- Family: `ZABgoldpending`.
- Selected binary: `ZABgoldpending.ex5` — 53,368 bytes — SHA256 `f75e6d11f298765521d0bbcb7ce37c0e2fdacec3136315dd48047ee2249c9c90`.
- Exact source post: `725024260297268` / content SHA256 `9b818b646503247d7dda3a653c4d5a2301f95c944ff22d266b029c3acc5f96bb`.
- `SOURCE_CLAIM`: Gold M5 breakout bot; user chooses lot or risk-percent; source says remaining settings are prepared; demo is recommended first.
- Source code is unavailable and EX5 remains opaque. Static binary strings did not expose trustworthy inputs/defaults.

## Prospectively frozen

- Role: `EA`.
- Home mapping: `XAUUSD` on ThinkMarkets-Live is an **EA_LAB prospective experiment mapping** of source term Gold, not a claim that the Facebook source literally named `XAUUSD`.
- Timeframe: `M5` (`SOURCE_CLAIM`).
- Owner money choice: `RISK_PERCENT = 1%`, bound to the exposed input `Risk_Percent=1.0`.
- First numerical research model: `M1_M1_OHLC_RESEARCH`.
- MAIN: `2023-01-01..2025-12-31`.
- BWD: `2020-01-01..2022-12-31`.
- HOLDOUT: `2026H1 = UNSPENT_DO_NOT_DISCOVER`.
- Optimization: `NOT_AUTHORIZED`; fixed-config qualification must come first.
- Model-4 MAIN+BWD remains mandatory later before Candidate eligibility, with no M1→M4 retuning.

## Input-surface qualification

A separately bounded isolated metadata probe recovered the tester input surface without starting Strategy Tester performance execution. No account configuration was copied into the isolates. MT5 builds `6090` and `6182` generated the same 12 parameter lines with SHA256 `d518cdbf844b23d22ca2c8250fa9ad4af2a7b5f9d6a37df79f991118aa200a16`.

Both terminal logs state `tester not started because the account is not specified`. Performance report count is `0`; backtest started is `false`; tested performance is `NONE`.

Exact details are in `docs/research/ZABGOLDPENDING_INPUT_SURFACE_QUALIFICATION_20260923.md` and `portfolio/ZABGOLDPENDING_INPUT_SURFACE_QUALIFICATION_20260923.json`.

## Prospective tester lineage

- Acceptance-critical candidate install remains `D:\Meta 5\terminal64.exe`.
- Observed terminal product/file version: `5.0.0.6182`.
- Current governance role: MT5 lane 1 primary; Model-4 is serial and remains a later gate.
- The build observation is not standing identity. Exact terminal build, account identity, leverage, server, and effective economics must be captured immediately before a future run. Account identifiers remain private local data and must not be copied into Git.

## Cost/data policy

- Use tester-native broker economics from the exact accepted ThinkMarkets-Live installation.
- Capture effective spread/commission/swap evidence; unavailable required economics must fail closed rather than be invented.
- Do not rely on historical INI controls that current MT5 builds may silently ignore; verify effective report identity instead.
- Never compare acceptance numbers across MT5 installations as if they were one lineage.

## Unresolved — intentionally not invented

1. **Money-mode selection semantics:** the surface exposes both `Risk_Percent=1.0` and `Fixed_Lot_Size=0.1`, both non-zero, with no explicit money-mode selector. The source says the user can choose lot or risk-percent but does not state the precedence/disable rule. Do not infer it.
2. **Exact breakout mechanics:** trigger level/lookback/confirmation/pending-order logic remain unknown.
3. **Exit semantics:** TP/SL/trailing/time exit/basket exit remain unknown.
4. **MM mechanics:** risk-percent calculation, stop basis, lot normalization/caps and fixed-lot/risk-percent precedence remain unknown.
5. **Grid/martingale/hedge:** absence is not inferred from filename, source prose or strings.
6. **External dependencies:** indicators/files/network/license requirements remain unknown.
7. **Account identity:** exact account/leverage and final effective tester economics require private pre-run capture.

## Readiness decision

Previous state: `READY_FOR_SETTINGS_FREEZE`.

Current state: `INPUT_SURFACE_QUALIFIED_OWNER_RISK_FROZEN_SEMANTICS_REQUIRED / READY_FOR_TEST = false`.

The owner value and exact input surface are now resolved. The material blocker is the unproven selection/disable semantics between `Risk_Percent=1.0` and `Fixed_Lot_Size=0.1`, followed by private tester/account binding and EX5 load/init qualification.

## Exact next gate

Before any MT5 performance run:

1. prove how the EA selects/disables `Risk_Percent` versus `Fixed_Lot_Size` without guessing or using outcome data;
2. bind exact terminal build + account/leverage + broker economics privately;
3. verify the binary loads/initializes on `XAUUSD M5` and identify any external-dependency failure;
4. only then create one fixed-config Model-1 MAIN+BWD execution contract.

No optimization, BWD retuning, HOLDOUT discovery, Grade/KINT/Candidate decision, deployment, runtime, or LIVE action follows automatically.

Machine-readable pretest owner: `portfolio/ZABGOLDPENDING_PRETEST_FREEZE_20260923.json`.
