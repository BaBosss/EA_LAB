# Candidate Lifecycle Status

Candidate: `Gold_SMC_Run004_OOS_VALIDATED`  
Project: Gold SMC continuous  
Updated: 2026-06-04

## Current Stage

`OOS_VALIDATED`

Equivalent lifecycle mapping:

| Stage | Status |
|---|---|
| Idea / Prototype | Done |
| Optimization | Done |
| Single Test Passed | Done |
| OOS Validated | Current |
| Portfolio Test | Next |
| Tiny Live | Pending |
| Production Portfolio | Pending |

## Lifecycle State Machine

| Status | Meaning | Allowed next action |
|---|---|---|
| `IS_VALIDATED` | Single test passed with locked candidate | OOS validation |
| `OOS_PENDING` | OOS/forward validation not complete | OOS single tests only |
| `OOS_PASSED` | OOS rules passed | Portfolio validation |
| `OOS_VALIDATED` | Same as OOS passed; candidate is usable for portfolio work | Correlation and portfolio test |
| `FORWARD_PENDING` | Portfolio passed; waiting for demo/live-forward evidence | Tiny live preparation |
| `LIVE_MICRO` | Tiny live only | Execution monitoring |
| `LIVE_APPROVED` | Controlled production allocation approved | Production portfolio governance |

## Current Evidence

- Optimizer pass: `1568`
- Single test: `run_004`
- Forward/OOS: `Forward test`
- Set file: `Gold_SMC_Continuous_MT5_RiskCapV1_opt1.set`
- EA: `Gold_SMC_Continuous_MT5_RiskCapV1`
- Symbol/timeframe: `XAUUSD,H1`

## Why It Passed

- Forward graph continued upward without equity collapse.
- No equity death spiral was visible.
- DD remained controlled for this risk-capped recovery style.
- Deposit load stayed low.
- Trade sample was large enough for usable candidate status.

## Why It Is Not Production Yet

- PF is only about `1.11` in forward/OOS.
- Recovery is usable but not strong at `1.34`.
- Sharpe is moderate at `0.82`.
- It must be tested as part of a portfolio, because a single conservative component can still fail during the wrong regime.

## Hard Rules Going Forward

- No optimization.
- No parameter changes.
- No logic changes.
- No larger risk.
- No looser DD caps.
- No martingale/recovery expansion.

## Next Gate

Portfolio validation.

Required outputs:

- Correlation matrix against candidate pool.
- Combined equity curve for 2-3 EA basket.
- Portfolio DD and deposit-load check.
- Tiny-live plan only after portfolio validation.

