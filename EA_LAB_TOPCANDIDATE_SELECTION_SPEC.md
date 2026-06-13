# EA_LAB_TOPCANDIDATE_SELECTION_SPEC.md

## 1. Purpose

Define the manual, documentation-only selection rules for identifying TopCandidates from EA_LAB backtest result records.

This SPEC supports future human review of EA_RESULTS.xlsx without parser logic, automation, or Excel modification in this phase.

## 2. Scope

Scope is limited to the EA_LAB project:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED

This SPEC documents how a human operator may later evaluate Runs sheet records and decide whether a run should be considered for TopCandidates.

## 3. Non-Goals

This SPEC does not:

- create a PLAN
- modify Excel files
- parse reports
- create automation
- run MT5
- create strategy logic
- create optimization logic
- create portfolio allocation logic
- modify EA_CORE_V1
- create broker/live-trading behavior

## 4. Candidate Selection Workflow

Manual candidate selection workflow:

1. Human operator reviews completed records in EA_RESULTS.xlsx / Runs.
2. Human operator confirms the source report was manually registered and reviewed.
3. Human operator compares key metrics using the ranking methodology in this SPEC.
4. Human operator classifies the run as Strong Candidate, Candidate, or Reject.
5. Human operator may later record accepted selections into TopCandidates only after a separate approved manual-entry phase.

## 5. Inputs From EA_RESULTS.xlsx Runs Sheet

Expected manual input fields from Runs include:

- RunID
- RunSource
- EA_Code
- PresetID
- PresetVersion
- Symbol
- Timeframe
- DateFrom
- DateTo
- Deposit
- Leverage
- SpreadMode
- NetProfit
- GrossProfit
- GrossLoss
- ProfitFactor
- ExpectedPayoff
- MaxDrawdownAbs
- MaxDrawdownPct
- RecoveryFactor
- TotalTrades
- WinRatePct
- ResultFileName
- ImportedAt
- Status
- Notes

## 6. Ranking Methodology

Ranking is manual and evidence-based.

Primary ranking dimensions:

- ProfitFactor
- MaxDrawdownPct
- RecoveryFactor
- Sharpe-like or Sharpe Ratio metric if manually available
- TotalTrades
- NetProfit
- Notes and stability comments

No formula, script, parser, or automated score is created in this SPEC.

## 7. PF Evaluation

ProfitFactor evaluation:

- Higher PF is better when trade count is sufficient.
- Very high PF with very low trade count requires caution.
- PF below 1.00 is generally reject unless explicitly retained for diagnostic review.
- PF should be considered together with drawdown, recovery, and trade count.

## 8. Drawdown Evaluation

Drawdown evaluation:

- Lower MaxDrawdownPct is better.
- A run with high NetProfit but excessive drawdown should not be classified as Strong Candidate.
- MaxDrawdownAbs may be used as supporting context.
- Drawdown must be evaluated relative to deposit, leverage, symbol, and timeframe.

## 9. Recovery Factor Evaluation

Recovery Factor evaluation:

- Higher RecoveryFactor is better.
- RecoveryFactor should support the idea that profit was earned efficiently relative to drawdown.
- Low or missing RecoveryFactor does not automatically reject a run if other evidence is strong, but it should reduce confidence.

## 10. Sharpe Ratio Evaluation

Sharpe Ratio evaluation:

- Sharpe Ratio or Sharpe-like values may be used only if manually available.
- Higher Sharpe is better when calculated consistently.
- Missing Sharpe must not be guessed.
- Sharpe must not override severe drawdown or very low trade count concerns.

## 11. Tie-Break Rules

Tie-break priority:

1. Lower MaxDrawdownPct
2. Higher RecoveryFactor
3. Higher ProfitFactor
4. Higher TotalTrades, when quality metrics remain acceptable
5. More stable Notes / fewer manual concerns
6. Cleaner source report and metadata completeness

## 12. Strong Candidate Definition

Strong Candidate:

- PF is clearly positive and credible.
- MaxDrawdownPct is acceptable for the test context.
- RecoveryFactor is strong or manually justified.
- Trade count is sufficient for review context.
- No major notes or manual red flags are present.
- Source report and Runs metadata are complete enough for future review.

## 13. Candidate Definition

Candidate:

- PF is positive or promising.
- Drawdown is not disqualifying.
- RecoveryFactor is acceptable or pending.
- Some fields may be incomplete but not blocking.
- Human review finds enough merit for watchlist or later comparison.

## 14. Reject Definition

Reject:

- PF is below acceptable threshold.
- Drawdown is excessive.
- RecoveryFactor is weak without mitigating context.
- Trade count is too low for confidence.
- Report metadata is unreliable.
- Notes contain a material concern.

## 15. TopCandidates Sheet Usage

TopCandidates is reserved for future approved manual entry.

Potential future TopCandidates fields include:

- CandidateID
- OptBatchID
- PassID
- EA_Code
- PresetID
- PresetVersion
- Symbol
- Timeframe
- BacktestScore
- RobustnessScore
- DeployScorePreview
- NetProfit
- ProfitFactor
- MaxDrawdownPct
- RecoveryFactor
- TotalTrades
- ParameterSummary
- SelectionReason
- Status
- Notes

This SPEC does not modify TopCandidates.

## 16. Future PortfolioGrouping Relationship

PortfolioGrouping is a later-stage relationship.

TopCandidates may later feed PortfolioGrouping only after:

- candidate selection is manually reviewed
- forward/demo review is available if required
- correlation or symbol exposure is reviewed
- MASTER approves the portfolio grouping phase

This SPEC does not create portfolio allocation logic.

## 17. Acceptance Criteria

This SPEC is acceptable when:

- it references D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED
- it documents manual candidate selection only
- it defines PF, drawdown, RecoveryFactor, and Sharpe evaluation
- it defines Strong Candidate, Candidate, and Reject
- it documents TopCandidates usage without modifying Excel
- it prohibits parser, automation, build, and EA_CORE_V1 modification

## 18. Risks

Risks:

- manual ranking may be inconsistent
- missing metrics may reduce confidence
- high PF may be overvalued with too few trades
- low drawdown may hide low opportunity quality
- candidate promotion may happen too early without forward/demo evidence

Mitigation is manual review, conservative classification, and MASTER approval before any later data-entry or portfolio phase.

## 19. Stop Condition

Stop after creating this SPEC.

Do not:

- create a PLAN
- modify Excel
- parse reports
- create automation
- run MT5
- modify EA_CORE_V1

Codex status: WAIT for MASTER review.
