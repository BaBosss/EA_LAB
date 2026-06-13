# Gold SMC Run004 OOS Validated Candidate

Project: Gold SMC continuous  
Candidate ID: `Gold_SMC_Run004_OOS_VALIDATED`  
Current status: `OOS_VALIDATED`  
Pipeline phase: `Portfolio Validation`  
Candidate lock source: `run_004`  
Optimizer pass: `1568`

## Decision

This candidate is accepted as a usable conservative portfolio component.

It is not an aggressive money printer. Do not try to force PF higher by increasing recovery, lot size, DD limits, martingale behavior, or any risk cap.

## Locked Set

Use only:

`set/Gold_SMC_Continuous_MT5_RiskCapV1_opt1.set`

No parameter changes are allowed after this package is frozen.

## Locked Inputs

| Parameter | Value |
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

## Validation Metrics

### IS / Single Test: run_004

| Metric | Result |
|---|---:|
| Profit | 7,497.37 |
| PF | 1.310 |
| Recovery | 3.219 |
| Sharpe | 3.146 |
| Equity DD | 12.38% |
| Trades | 479 |
| Win rate | 82.46% |

### Forward / OOS

| Metric | Result |
|---|---:|
| Profit | 2,398.89 |
| PF | 1.110 |
| Recovery | 1.343 |
| Sharpe | 0.822 |
| Equity DD | 17.45% |
| Balance DD | 19.13% |
| Trades | 596 |
| Win rate | 78.52% |

## Verdict

Status: `OOS_VALIDATED`

Interpretation:

- Usable candidate.
- Conservative portfolio component.
- Forward graph did not collapse.
- Risk caps remained visible and fixed.
- DD stayed controlled enough for portfolio validation.
- PF is low, so this candidate should not be used alone or oversized.

## Package Contents

| Folder | Contents |
|---|---|
| `set/` | Frozen `.set` file |
| `single_test/` | run_004 report, graph, and supporting tester images |
| `forward_test/` | forward/OOS report, graph, and supporting tester images |
| `optimization_snapshot/` | optimizer raw result and parsed summary snapshots |
| `source/` | locked MQ5/EX5 files |
| `notes/` | OOS plan and acceptance rule references |

## Rules

- Do not optimize this candidate further.
- Do not change strategy logic.
- Do not change parameters.
- Do not loosen risk caps.
- Do not increase lot size or recovery.
- Do not deploy as a single-EA production portfolio.
- Use it only inside portfolio validation with 2-3 behaviorally different EAs.

## Next Required Workflow

1. Run portfolio correlation test against other candidate EAs.
2. Build a candidate pool with different strategy personalities.
3. Create a 2-3 EA portfolio test.
4. If portfolio validation passes, move to `FORWARD_PENDING`.
5. Run tiny live only after portfolio validation.
6. Keep tiny live focused on execution quality, not profit.

