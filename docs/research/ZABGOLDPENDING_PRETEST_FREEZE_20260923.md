# ZABgoldpending — prospective pretest freeze — 2026-09-23

Status: `PARTIALLY_FROZEN / OWNER_AND_INPUT_SURFACE_REQUIRED / NO_MT5`

Authority: `RESEARCH_ONLY_DOCUMENTARY`. This freezes only source-grounded and current-governance pretest fields. It does not authorize MT5 execution, backtesting, optimization, HOLDOUT, risk/default changes, deployment, runtime, DEMO/LIVE, or trading.

## Source identity

- Family: `ZABgoldpending`.
- Selected binary: `ZABgoldpending.ex5` — 53,368 bytes — SHA256 `f75e6d11f298765521d0bbcb7ce37c0e2fdacec3136315dd48047ee2249c9c90`.
- Exact source post: `725024260297268` / content SHA256 `9b818b646503247d7dda3a653c4d5a2301f95c944ff22d266b029c3acc5f96bb`.
- `SOURCE_CLAIM`: Gold M5 breakout bot; user chooses lot or risk-percent; source says remaining settings are prepared; demo is recommended first.
- EX5 source code is unavailable. The binary is opaque. A read-only ASCII/UTF-16 string probe did not recover trustworthy input names/defaults.

## Prospectively frozen now

- Role: `EA`.
- Home mapping: `XAUUSD` on ThinkMarkets-Live as an **EA_LAB experiment mapping** of the source term Gold, not a claim that the Facebook post literally named `XAUUSD`. Current filesystem observation shows XAUUSD history + ticks under both `D:\Meta 5` and `D:\Meta 5b`; this must be revalidated before any run.
- Timeframe: `M5` (`SOURCE_CLAIM`).
- First numerical research model: `M1_M1_OHLC_RESEARCH`.
- MAIN: `2023-01-01..2025-12-31`.
- BWD: `2020-01-01..2022-12-31`.
- HOLDOUT: `2026H1 = UNSPENT_DO_NOT_DISCOVER`.
- Optimization: `NOT_AUTHORIZED`; fixed-config qualification must come first.
- Candidate path: Model-4 MAIN+BWD remains mandatory later, with no M1→M4 retuning.

## Prospective tester lineage

- Acceptance-critical candidate install: `D:\Meta 5\terminal64.exe`.
- Observed terminal product/file version: `5.0.0.6182`.
- Current role in governance: MT5 lane 1 primary; Model-4 is serial and remains a later gate.
- This build observation is **not standing identity**: exact terminal build, account login, leverage, server and effective economics must be captured immediately before a future run.

## Cost/data policy

- Use tester-native broker economics from the exact accepted ThinkMarkets-Live installation.
- Capture effective spread/commission/swap evidence; if a required economic field is unavailable, mark it unavailable/block rather than inventing a number.
- Do not rely on historical INI spread/leverage knobs where current MT5 builds have shown silent no-op behavior; verify effective report identity instead.
- Never compare acceptance numbers across MT5 installs as if they were one lineage.

## Unresolved — intentionally not invented

1. **Owner money mode/value:** choose exactly one: `FIXED_LOT = <value>` or `RISK_PERCENT = <value>`. No value is inferred from prior risk preferences or Facebook prose.
2. **EX5 input surface/defaults:** parameter names, exact defaults and which field selects lot-vs-risk remain `UNKNOWN`; a separately authorized input-surface capture is required.
3. **Exact breakout mechanics:** trigger level/lookback/confirmation/pending-order logic remain unknown.
4. **Exit semantics:** TP/SL/trailing/time exit/basket exit remain unknown.
5. **MM mechanics:** risk-percent formula, stop basis, lot normalization/caps remain unknown.
6. **Grid/martingale/hedge:** absence is not inferred from filename or strings.
7. **External dependencies:** indicators/files/network/license requirements remain unknown.
8. **Account identity:** exact login/leverage and final effective tester economics require pre-run capture.

## Readiness decision

Previous state: `READY_FOR_SETTINGS_FREEZE`.

After this bounded work: `PARTIAL_SETTINGS_FREEZE_OWNER_AND_INPUT_SURFACE_REQUIRED / READY_FOR_TEST = false`.

This is progress, not a test contract. The source identity, XAUUSD/M5 carrier, M1 model, MAIN/BWD windows, HOLDOUT protection, no-optimization rule, and tester/cost policy are now explicit. The money choice and exact input surface remain blocking.

## Exact next gate

Before any MT5 performance run:

1. owner freezes `FIXED_LOT` or `RISK_PERCENT` and an exact value;
2. capture the EX5 input surface/defaults without guessing and without using outcome data;
3. bind exact terminal build + account/login/leverage + broker symbol economics;
4. verify the binary loads on `XAUUSD M5` and identify any dependency failure;
5. only then create one fixed-config Model-1 MAIN+BWD execution contract.

No optimization, BWD retuning, HOLDOUT discovery, Grade/KINT/Candidate decision, runtime/deployment or LIVE action follows automatically.

Machine-readable owner: `portfolio/ZABGOLDPENDING_PRETEST_FREEZE_20260923.json`.
