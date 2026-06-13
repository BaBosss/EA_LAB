# OOS Validation Plan

Project: Gold SMC continuous  
Candidate status: RUN_NOW / conservative candidate  
Candidate lock: run_004 / optimizer pass 1568  
Lifecycle status now: IS_VALIDATED -> OOS_PENDING

## Locked Candidate

This OOS plan validates the exact candidate already accepted from `run_004`.

IS reference metrics:

| Metric | Value |
|---|---:|
| Net profit | 7,497.37 |
| Profit factor | 1.310 |
| Recovery factor | 3.219 |
| Sharpe ratio | 3.146 |
| Equity DD | 12.38% |
| Trades | 479 |

Optimizer source:

`C:\Users\patip\OneDrive\.Codex\EA_LAB\ea_projects\Gold SMC continuous\optimization\raw_results\pass_2_raw\ReportOptimizer-146237.xml`

Single-test evidence:

`C:\Users\patip\OneDrive\.Codex\EA_LAB\ea_projects\Gold SMC continuous\backtest\manual_runs\run_004\ReportTester-146237.xlsx`

## Non-Negotiable Rules

- Use the exact same `.set` file that produced `run_004`.
- Do not optimize during OOS.
- Do not change parameters.
- Do not change strategy logic.
- Do not change risk-cap settings.
- Do not increase risk, lot cap, recovery depth, DD cap, deposit-load cap, or recovery multiplier.
- Each OOS run must be a single test, not an optimizer run.

## Set-File Preflight

Before OOS starts, archive and reference the exact `.set` file used for `run_004`.

Required archive target:

`C:\Users\patip\OneDrive\.Codex\EA_LAB\ea_projects\Gold SMC continuous\backtest\manual_runs\run_004\set_used.set`

If the original file cannot be identified, OOS is blocked until the exact set file is recovered from the run configuration. Re-creating a new set by hand from report values is not accepted as the same-file control.

Input signature to verify in every OOS report:

| Parameter | Locked value |
|---|---:|
| `InpSwingPeriod` | 5 |
| `InpRiskReward` | 1.8 |
| `InpLotSize` | 0.01 |
| `InpLotMultiplier` | 1.5 |
| `InpMinGapPts` | 300 |
| `InpTakeProfitUSD` | 130 |
| `InpDailyTargetUSD` | 140 |
| `InpSLBufferPts` | 25 |
| `InpMaxLotAbsolute` | 0.2 |
| `InpMaxDepositLoadPercent` | 30 |
| `InpMaxFloatingDDPercent` | 20 |
| `InpMaxDailyLossPercent` | 5 |
| `InpMaxRecoverySteps` | 3 |
| `InpRecoveryMultiplierMax` | 1.3 |
| `InpStopNewEntriesWhenDDPercent` | 15 |
| `InpCloseAllWhenDDPercent` | 25 |
| `InpOneRecoveryChainAtATime` | true |
| `InpBlockNewCycleAfterLoss` | true |
| `InpCooldownBarsAfterStop` | 40 |

## OOS Runs

### OOS_1: Pre-IS Recent Regime

Period: 2024.01.01 to 2024.12.31  
Purpose: Validate the candidate on the full year immediately before the IS window.  
Expected regime coverage: gold trend swings, range compression, news-driven volatility, USD-rate repricing, intermittent momentum bursts.

Recommended tester setup:

- Symbol: `XAUUSD`
- Timeframe: `H1`
- Model: Every tick based on real ticks
- Deposit: 10,000 USD
- Leverage: 1:100
- Spread: broker current/real tick spread; also record average and max spread from the report/log if available
- Execution: same broker server as IS, no artificial execution improvement

### OOS_2: Older Stress/Regime Shift

Period: 2023.01.01 to 2023.12.31  
Purpose: Stress the same candidate on an older market regime without touching the set.  
Expected regime coverage: gold macro repricing, sharp trend legs, CPI/FOMC shocks, choppy reversals, changing liquidity.

Recommended tester setup:

- Symbol: `XAUUSD`
- Timeframe: `H1`
- Model: Every tick based on real ticks
- Deposit: 10,000 USD
- Leverage: 1:100
- Spread: broker current/real tick spread; if fixed spread is required, use a conservative spread not lower than the IS run
- Execution: same broker server as IS, no optimization, no visual/manual intervention

### OOS_3: Forward Holdout

Period: 2026.06.02 to 2026.09.30, or the latest available forward data after the IS end date once enough trades exist  
Purpose: Validate post-selection behavior after the candidate was locked.  
Expected regime coverage: true holdout after selection, live-like changing liquidity, post-optimization drift.

Recommended tester setup:

- Symbol: `XAUUSD`
- Timeframe: `H1`
- Model: Every tick based on real ticks
- Deposit: 10,000 USD
- Leverage: 1:100
- Spread: live/current broker spread only; do not use a favorable fixed spread
- Execution: same broker server as intended deployment

OOS_3 cannot be called complete until the minimum-trade rule is satisfied. If the period is too short, keep it in OOS_PENDING and extend the end date forward without changing parameters.

## Market-Regime Notes

The three OOS windows deliberately test different failure modes:

- OOS_1 checks whether the edge existed before the IS period.
- OOS_2 checks whether the risk cap survives older stress and different gold behavior.
- OOS_3 checks whether the candidate survives after selection, which is the most important deployment gate.

No single OOS period is enough for live approval. At least OOS_1 and OOS_2 must pass before forward testing. OOS_3 or a forward demo must pass before any live micro deployment.

## Lifecycle Gates

| Status | Meaning | Entry condition | Exit condition |
|---|---|---|---|
| IS_VALIDATED | Candidate passed locked IS single test | run_004 accepted | Exact set archived and OOS matrix created |
| OOS_PENDING | OOS not complete | This plan exists | Required OOS reports exported |
| OOS_PASSED | OOS gates passed | OOS_1 and OOS_2 pass; OOS_3 pass or enough forward evidence exists | Start forward/demo monitoring |
| FORWARD_PENDING | Waiting for forward/demo evidence | OOS passed | Forward evidence meets rules |
| LIVE_MICRO | Tiny live deployment only | Forward passed | Stable micro-live monitoring period passes |
| LIVE_APPROVED | Approved for normal controlled deployment | Micro-live passes with unchanged risk caps | Portfolio-level approval only |

## Next Workflow After OOS

1. Run OOS_1, OOS_2, and OOS_3 exactly as defined in `oos_run_matrix.csv`.
2. Export MT5 HTML and XLSX reports for every OOS run.
3. Verify the input signature in each report before reading performance metrics.
4. Apply `oos_acceptance_rules.md`.
5. If OOS passes, run correlation against the current EA basket using monthly PnL.
6. If correlation is acceptable, move to FORWARD_PENDING with the same set file.
7. After forward pass, move to LIVE_MICRO only, with the same fixed risk caps and no larger risk.

