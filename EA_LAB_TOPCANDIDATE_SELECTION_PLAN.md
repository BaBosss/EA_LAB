# EA_LAB_TOPCANDIDATE_SELECTION_PLAN.md

## 1. Purpose

Define the manual PLAN for selecting TopCandidates from EA_LAB Runs sheet records.

This PLAN is documentation only. It does not modify Excel, parse reports, move reports, create automation, run MT5, or modify EA_CORE_V1.

## 2. Baseline

Current EA_LAB project baseline:

- Project: D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED
- EA_CORE_V1 status: Closed / Frozen / Guarded
- Workflow mode: manual review only
- Parser status: not approved
- Automation status: not approved

## 3. SPEC Reference

Accepted SPEC reference:

- D:\EA_LAB\EA_LAB_TOPCANDIDATE_SELECTION_SPEC.md

This PLAN must remain consistent with that SPEC.

## 4. Inputs Required From Runs Sheet

Manual review inputs from EA_RESULTS.xlsx / Runs:

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

## 5. Ranking Workflow

Manual ranking workflow:

1. Confirm the Runs row was manually registered and reviewed.
2. Check NetProfit and ProfitFactor for positive expectancy context.
3. Check MaxDrawdownPct and MaxDrawdownAbs for risk context.
4. Check RecoveryFactor for profit efficiency relative to drawdown.
5. Check Sharpe Ratio or Sharpe-like value only if manually available.
6. Check TotalTrades to avoid overvaluing thin samples.
7. Review Notes for warnings or special context.
8. Apply classification workflow.

## 6. Candidate Classification Workflow

Classify each reviewed run as:

- Strong Candidate
- Candidate
- Reject

Classification must be manual and conservative.

No formula, score automation, parser, script, or Excel modification is created by this PLAN.

## 7. Strong Candidate Workflow

A run may be marked Strong Candidate in a future approved manual-entry phase when:

- ProfitFactor is credible and clearly positive
- MaxDrawdownPct is acceptable
- RecoveryFactor is strong or manually justified
- TotalTrades is sufficient for context
- NetProfit supports the result
- Notes show no material red flags
- source metadata is complete enough for review

## 8. Reject Workflow

A run should be rejected when:

- ProfitFactor is below acceptable level
- drawdown is excessive
- RecoveryFactor is weak without mitigating context
- TotalTrades is too low for confidence
- source report metadata is unreliable
- Notes contain material concerns

Rejected runs may remain in Runs for traceability, but should not be promoted to TopCandidates.

## 9. Tie-Break Workflow

Tie-break order:

1. Lower MaxDrawdownPct
2. Higher RecoveryFactor
3. Higher ProfitFactor
4. Higher TotalTrades when quality remains acceptable
5. Better metadata completeness
6. Fewer manual concerns in Notes

Ties should not be forced into a winner if evidence is incomplete.

## 10. TopCandidates Sheet Mapping

Future manual TopCandidates mapping may use:

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

This PLAN does not modify TopCandidates.

## 11. Manual Review Procedure

Manual review procedure:

1. Open EA_RESULTS.xlsx manually only after MASTER approves a manual review phase.
2. Review Runs rows manually.
3. Confirm each reviewed row has a valid ResultFileName.
4. Compare PF, drawdown, RecoveryFactor, trade count, and Notes.
5. Draft a classification decision outside Excel if review-only.
6. Do not enter TopCandidates data until a separate approved manual-entry phase.

## 12. Audit Procedure

Audit procedure before any future TopCandidates entry:

- confirm SPEC exists
- confirm PLAN exists
- confirm EA_CORE_V1 remains unchanged
- confirm no parser exists
- confirm no automation exists
- confirm no report movement occurred
- confirm no Excel modification occurred during plan/audit phases
- confirm candidate classification is based on Runs data only

## 13. Safety Checklist

Safety checklist:

- no build
- no parser
- no automation
- no Excel modification
- no report movement
- no MT5 runner
- no Telegram/dashboard/Power BI files
- no broker/live-trading files
- no strategy logic
- no EA_CORE_V1 modification

## 14. Acceptance Criteria

This PLAN is acceptable when:

- it references D:\EA_LAB\EA_LAB_TOPCANDIDATE_SELECTION_SPEC.md
- it references D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED
- it documents Runs inputs
- it documents manual ranking and classification
- it documents Strong Candidate, Reject, tie-break, and TopCandidates mapping
- it preserves no parser, no automation, no Excel modification, and no report movement boundaries

## 15. Risks

Risks:

- manual ranking may be inconsistent
- incomplete Runs data may lead to weak classification
- strong NetProfit may hide excessive drawdown
- high PF may be overvalued with low trade count
- TopCandidates may be populated too early without MASTER approval

Mitigation is conservative manual review and a separate approval gate before Excel entry.

## 16. Stop Condition

Stop after creating this PLAN.

Do not:

- build
- parse reports
- create automation
- modify Excel
- move reports
- modify EA_CORE_V1

Codex status: WAIT for MASTER review.
