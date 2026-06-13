# EA_LAB_FIRST_TOPCANDIDATE_SELECTION_CHECKLIST.md

## 1. Purpose

Provide a manual checklist for the first TopCandidate selection review in EA_LAB.

This checklist is documentation only. It does not modify Excel, parse reports, move reports, create automation, run MT5, build anything, or modify EA_CORE_V1.

## 2. Scope

Scope is limited to manual candidate review for:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED

Reference documents:

- D:\EA_LAB\EA_LAB_TOPCANDIDATE_SELECTION_SPEC.md
- D:\EA_LAB\EA_LAB_TOPCANDIDATE_SELECTION_PLAN.md

## 3. Preconditions

Confirm before review:

- EA_LAB_TOPCANDIDATE_SELECTION_SPEC.md exists.
- EA_LAB_TOPCANDIDATE_SELECTION_PLAN.md exists.
- EA_CORE_V1_TESTBED exists.
- EA_RESULTS.xlsx exists.
- Runs sheet contains manually reviewed data or is ready for manual review.
- No parser is approved.
- No automation is approved.
- No Excel modification is approved in this checklist phase.
- No report movement is approved in this checklist phase.

## 4. Required Runs

Required Runs record for first review:

- RunID must be present.
- EA_Code must be present.
- Symbol must be present.
- Timeframe must be present.
- ResultFileName must be present.
- Status must indicate a validated or review-ready state.

Do not infer missing Runs values.

## 5. Run Validation Checklist

Validate the Runs record manually:

- RunID is unique.
- EA_Code matches EA_CORE_V1.
- Symbol is readable.
- Timeframe is readable.
- ResultFileName points to the expected report name.
- ProfitFactor is available or explicitly blank.
- MaxDrawdownPct is available or explicitly blank.
- RecoveryFactor is available or explicitly blank.
- TotalTrades is available or explicitly blank.
- Notes are reviewed for warnings.

## 6. Ranking Checklist

Manual ranking checklist:

- Compare ProfitFactor.
- Compare MaxDrawdownPct.
- Compare RecoveryFactor.
- Compare Sharpe Ratio only if available.
- Compare TotalTrades.
- Compare NetProfit.
- Review Notes.
- Avoid ranking by one metric alone.

## 7. PF Evaluation Checklist

PF evaluation:

- PF is greater than 1.00.
- PF is credible relative to TotalTrades.
- Very high PF with too few trades is treated cautiously.
- PF is evaluated with drawdown and recovery.
- PF is not used as the only promotion reason.

## 8. Drawdown Evaluation Checklist

Drawdown evaluation:

- MaxDrawdownPct is reviewed.
- MaxDrawdownAbs is reviewed if available.
- Drawdown is acceptable for the test context.
- High NetProfit does not override excessive drawdown.
- Drawdown concerns are noted.

## 9. Recovery Factor Evaluation Checklist

Recovery Factor evaluation:

- RecoveryFactor is reviewed if available.
- Higher RecoveryFactor is preferred.
- Missing RecoveryFactor is not guessed.
- Weak RecoveryFactor reduces confidence unless manually justified.
- RecoveryFactor is considered with PF and drawdown.

## 10. Sharpe Ratio Evaluation Checklist

Sharpe Ratio evaluation:

- Sharpe Ratio or Sharpe-like metric is used only if manually available.
- Missing Sharpe is left blank.
- Higher Sharpe is preferred when calculated consistently.
- Sharpe does not override severe drawdown.
- Sharpe does not override too few trades.

## 11. Tie-Break Checklist

Tie-break order:

- lower MaxDrawdownPct
- higher RecoveryFactor
- higher ProfitFactor
- higher TotalTrades if quality remains acceptable
- better metadata completeness
- fewer manual concerns in Notes

Do not force a tie-break if evidence is incomplete.

## 12. Candidate Classification Checklist

Classification options:

- Strong Candidate
- Candidate
- Reject

Before classifying:

- review PF
- review drawdown
- review RecoveryFactor
- review Sharpe if available
- review TotalTrades
- review Notes
- confirm no parser or automation was used

## 13. Strong Candidate Checklist

Strong Candidate requires:

- credible positive PF
- acceptable MaxDrawdownPct
- strong or justified RecoveryFactor
- sufficient TotalTrades for context
- supportive NetProfit
- no material Notes red flags
- complete enough metadata for future review

## 14. Reject Checklist

Reject if:

- PF is below acceptable level
- drawdown is excessive
- RecoveryFactor is weak without mitigation
- TotalTrades is too low for confidence
- metadata is unreliable
- Notes contain material concerns

Rejects remain traceable in Runs but are not promoted.

## 15. TopCandidates Sheet Preparation Checklist

TopCandidates preparation is review-only in this phase.

Confirm future mapping fields:

- CandidateID
- EA_Code
- PresetID
- PresetVersion
- Symbol
- Timeframe
- NetProfit
- ProfitFactor
- MaxDrawdownPct
- RecoveryFactor
- TotalTrades
- SelectionReason
- Status
- Notes

Do not modify the TopCandidates sheet in this checklist phase.

## 16. Manual Review Checklist

Manual review controls:

- human reviews Runs data only
- human does not parse report by script
- human does not move report files
- human does not edit Excel during this checklist phase
- human records observations outside Excel if needed
- MASTER approval is required before any TopCandidates entry

## 17. Audit Checklist

Audit before acceptance:

- SPEC is referenced.
- PLAN is referenced.
- EA_CORE_V1_TESTBED is referenced.
- no build occurred.
- no parser was created.
- no automation was created.
- no Excel file was modified.
- no report file was moved.
- EA_CORE_V1 was not modified.

## 18. Acceptance Criteria

This checklist is acceptable when:

- all 20 sections exist
- SPEC and PLAN are referenced
- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED is referenced
- ranking and classification checks are documented
- PF, drawdown, RecoveryFactor, and Sharpe checks are documented
- no build, parser, automation, Excel modification, or report movement is introduced

## 19. Risks

Risks:

- manual bias in classification
- incomplete Runs metrics
- overvaluing PF with low trade count
- underweighting drawdown
- promoting a run before enough evidence exists
- accidental Excel modification during review-only phase

Mitigation is conservative review and MASTER approval before any data-entry phase.

## 20. Stop Condition

Stop after creating this checklist.

Do not:

- build
- parse reports
- create automation
- modify Excel
- move reports
- modify EA_CORE_V1

Codex status: WAIT for MASTER review.
