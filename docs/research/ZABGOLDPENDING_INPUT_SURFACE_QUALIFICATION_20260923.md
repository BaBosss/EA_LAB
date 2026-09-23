# ZABgoldpending — input surface qualification — 2026-09-23

Status: `INPUT_SURFACE_QUALIFIED / OWNER_RISK_PERCENT_1PCT_FROZEN / MONEY_MODE_SEMANTICS_REQUIRED / READY_FOR_TEST=false`.

Authority: `RESEARCH_ONLY_DOCUMENTARY_NO_PERFORMANCE_TEST`. This qualification does not authorize a performance backtest, optimization, HOLDOUT use, Candidate/Grade/KINT decision, deployment, runtime or LIVE trading.

## Owner decision

- Owner choice: `RISK_PERCENT = 1%`.
- Exact exposed field binding: `Risk_Percent=1.0`.
- This freezes the requested value only. It does **not** prove how the opaque EA chooses between risk-percent sizing and fixed-lot sizing.

## Source identity

- `ZABgoldpending.ex5` — SHA256 `f75e6d11f298765521d0bbcb7ce37c0e2fdacec3136315dd48047ee2249c9c90` — 53,368 bytes.
- Exact Facebook source claim remains: Gold, M5, breakout bot, user chooses lot or risk-percent; no exact internal precedence/disable rule is stated.
- Source code is unavailable; EX5 remains opaque.

## Qualification method

- Used isolated portable MT5 metadata probes only. No account configuration was copied into either isolate.
- Probe A used MT5 build `6090`; Probe B used MT5 build `6182`.
- Both probes used a deliberately unusable symbol `__INPUT_SURFACE_ONLY__` and future dates only to make the terminal inspect EX5 metadata.
- Both logs state: `tester not started because the account is not specified`.
- Performance report count: `0`; tester started: `false`; backtest started: `false`; tested performance: `NONE`.
- Both builds generated the same 12-input tester surface. Parameter-line SHA256: `d518cdbf844b23d22ca2c8250fa9ad4af2a7b5f9d6a37df79f991118aa200a16`.

## Exact captured input surface

| Input | Default | Start | Step | Stop | Optimize |
|---|---:|---:|---:|---:|:---:|
| `tp_sl_points` | `400.0` | `400.0` | `40.000000` | `4000.000000` | `N` |
| `Fixed_Lot_Size` | `0.1` | `0.1` | `0.010000` | `1.000000` | `N` |
| `Risk_Percent` | `1.0` | `1.0` | `0.100000` | `10.000000` | `N` |
| `Magic_Number` | `123456` | `123456` | `1` | `1234560` | `N` |
| `Trailing_Start` | `70` | `70` | `1` | `700` | `N` |
| `Trailing_Step` | `50` | `50` | `1` | `500` | `N` |
| `Slipage` | `3` | `3` | `1` | `30` | `N` |
| `Show_Debug_Info` | `true` | `false` | `0` | `true` | `N` |
| `Swing_Period` | `7` | `7` | `1` | `70` | `N` |
| `Min_Swing_Distance` | `50` | `50` | `1` | `500` | `N` |
| `Use_Volume_Filter` | `true` | `false` | `0` | `true` | `N` |
| `Max_Lookback` | `100` | `100` | `1` | `1000` | `N` |

## Material semantic blocker

The surface exposes both `Risk_Percent=1.0` and `Fixed_Lot_Size=0.1`, both non-zero, and exposes **no explicit money-mode selector**. The Facebook source says the user can choose lot or risk-percent but does not state the exact disable/precedence rule. Searches of the accepted Facebook evidence did not find the exact parameter names `Risk_Percent` or `Fixed_Lot_Size`.

A targeted read-only recheck of the exact Facebook post and loaded comments was also performed through the existing persistent research session. The post again states only ตั้งแค่ lot หรือ risk เป็น %; the loaded comments discuss MT5, testing/help and installation, with no precedence/disable rule. The source-side semantic search is therefore still unresolved rather than silently inferred.

Therefore:

- `RISK_PERCENT=1%` is owner-frozen and maps cleanly to `Risk_Percent=1.0`.
- `Fixed_Lot_Size` is **not** silently changed to `0`, `0.01`, or any other value.
- No claim is made that `Risk_Percent > 0` overrides fixed lot, or vice versa.
- No executable fixed-config `.set` is authorized yet.
- `READY_FOR_TEST=false`.

## Remaining gates

1. Prove the exact `Risk_Percent` versus `Fixed_Lot_Size` selection/disable semantics without using outcome data or guessing.
2. Bind the accepted tester/account identity privately and revalidate the exact terminal build immediately before any future run; account identifiers must not be copied into Git.
3. After money-mode semantics resolve, verify the selected EX5 can load/init on `XAUUSD M5` without an external-dependency failure.
4. Only then may a separate fixed-config Model-1 MAIN+BWD execution contract be frozen. Optimization remains unauthorized and HOLDOUT `2026H1` remains unspent.

Machine-readable qualification: `portfolio/ZABGOLDPENDING_INPUT_SURFACE_QUALIFICATION_20260923.json`. External raw capture: `D:/EA_LAB_CONTROL/evidence/zabgoldpending-inputsurface-20260923/INPUT_SURFACE_CAPTURE.json`.
