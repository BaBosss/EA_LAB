# FIRST_TOPCANDIDATE_SELECTION_AUDIT.md

## 1. Purpose

Audit the first three manually recorded EA_LAB Runs records and produce a manual TopCandidate selection recommendation.

This audit is documentation only. It does not build, parse reports, create automation, modify Excel, move reports, run MT5, or modify EA_CORE_V1.

## 2. Audit Scope

EA_LAB project:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED

Reviewed Runs:

- RUN_EA_CORE_V1_20260612_0001
- RUN_EA_CORE_V1_20260612_0002
- RUN_EA_CORE_V1_20260612_0003

Source reviewed:

- EA_RESULTS.xlsx / Runs sheet values only

## 3. Recorded Runs Snapshot

| Rank Input | RunID | Symbol | Timeframe | Net Profit | Profit Factor | Max Drawdown % | Recovery Factor | Sharpe Ratio | Win Rate % | Expected Payoff | Total Trades | Status |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- |
| Run 0001 | RUN_EA_CORE_V1_20260612_0001 | XAUUSD | H1 | 2737.52 | 1.12 | 17.07 | 1.23 | Not recorded | 78.79 | 5.69 | 481 | MANUAL_RECORDED |
| Run 0002 | RUN_EA_CORE_V1_20260612_0002 | XAUUSD | H1 | 9240.87 | 1.38 | 14.77 | 4.22 | Not recorded | 84.56 | 20.67 | 447 | MANUAL_RECORDED |
| Run 0003 | RUN_EA_CORE_V1_20260612_0003 | XAUUSD | H1 | 992.93 | 1.04 | 20.82 | 0.40 | Not recorded | 82.72 | 1.31 | 758 | MANUAL_RECORDED |

## 4. Metric Evaluation

Net Profit:

- Best: RUN_EA_CORE_V1_20260612_0002
- Second: RUN_EA_CORE_V1_20260612_0001
- Third: RUN_EA_CORE_V1_20260612_0003

Profit Factor:

- Best: RUN_EA_CORE_V1_20260612_0002 at 1.38
- Second: RUN_EA_CORE_V1_20260612_0001 at 1.12
- Third: RUN_EA_CORE_V1_20260612_0003 at 1.04

Max Drawdown %:

- Best: RUN_EA_CORE_V1_20260612_0002 at 14.77
- Second: RUN_EA_CORE_V1_20260612_0001 at 17.07
- Third: RUN_EA_CORE_V1_20260612_0003 at 20.82

Recovery Factor:

- Best: RUN_EA_CORE_V1_20260612_0002 at 4.22
- Second: RUN_EA_CORE_V1_20260612_0001 at 1.23
- Third: RUN_EA_CORE_V1_20260612_0003 at 0.40

Sharpe Ratio:

- Not recorded in the current Runs sheet.
- Sharpe Ratio is not scored in this audit.
- No Sharpe value is inferred or estimated.

Win Rate:

- Best: RUN_EA_CORE_V1_20260612_0002 at 84.56
- Second: RUN_EA_CORE_V1_20260612_0003 at 82.72
- Third: RUN_EA_CORE_V1_20260612_0001 at 78.79

Expected Payoff:

- Best: RUN_EA_CORE_V1_20260612_0002 at 20.67
- Second: RUN_EA_CORE_V1_20260612_0001 at 5.69
- Third: RUN_EA_CORE_V1_20260612_0003 at 1.31

## 5. Candidate Ranking

Top 1:

- RUN_EA_CORE_V1_20260612_0002
- Reason: strongest Net Profit, Profit Factor, Max Drawdown %, Recovery Factor, Win Rate, and Expected Payoff among the three reviewed Runs.

Top 2:

- RUN_EA_CORE_V1_20260612_0001
- Reason: acceptable positive result and second-best balance of PF, drawdown, recovery, and expected payoff.

Top 3:

- RUN_EA_CORE_V1_20260612_0003
- Reason: weakest Net Profit, Profit Factor, Max Drawdown %, Recovery Factor, and Expected Payoff despite the highest trade count.

## 6. Strong Candidate Classification

Strong Candidate:

- RUN_EA_CORE_V1_20260612_0002

Justification:

- Net Profit = 9240.87
- Profit Factor = 1.38
- Max Drawdown % = 14.77
- Recovery Factor = 4.22
- Win Rate % = 84.56
- Expected Payoff = 20.67
- Total Trades = 447

This Run is the strongest first TopCandidates entry candidate.

## 7. Candidate Classification

Candidate:

- RUN_EA_CORE_V1_20260612_0001

Justification:

- Net Profit is positive.
- Profit Factor is above 1.00.
- Max Drawdown % is below RUN 0003.
- Recovery Factor is positive but much weaker than RUN 0002.
- Expected Payoff is positive.

This Run may remain under watch or comparison but should not enter TopCandidates before RUN 0002.

## 8. Reject Classification

Reject:

- RUN_EA_CORE_V1_20260612_0003

Justification:

- Profit Factor = 1.04, only marginally above break-even.
- Max Drawdown % = 20.82, worst among the reviewed Runs.
- Recovery Factor = 0.40, weakest among the reviewed Runs.
- Expected Payoff = 1.31, weakest among the reviewed Runs.
- Net Profit = 992.93, weakest among the reviewed Runs.

This Run should be rejected for TopCandidates selection unless future evidence gives a specific diagnostic reason to retain it.

## 9. Recommendation

Run that should enter TopCandidates first:

- RUN_EA_CORE_V1_20260612_0002

Run that should be rejected:

- RUN_EA_CORE_V1_20260612_0003

Additional Runs required before PortfolioGrouping:

- YES

Reason:

- Three Runs are enough for a first manual candidate selection, but not enough for PortfolioGrouping.
- PortfolioGrouping should wait for more Runs across symbols, timeframes, market conditions, and ideally forward/demo tracking.
- Sharpe Ratio is not recorded, so risk-adjusted comparison remains incomplete.

## 10. Safety Confirmation

This audit did not:

- build
- parse reports
- create automation
- modify Excel
- move reports
- run MT5
- modify EA_CORE_V1

## 11. Audit Verdict

FIRST_TOPCANDIDATE_SELECTION_AUDIT = PASS

Recommended first TopCandidates entry:

- RUN_EA_CORE_V1_20260612_0002

Recommended reject:

- RUN_EA_CORE_V1_20260612_0003

PortfolioGrouping readiness:

- NOT READY

Codex status: WAIT for MASTER review.
