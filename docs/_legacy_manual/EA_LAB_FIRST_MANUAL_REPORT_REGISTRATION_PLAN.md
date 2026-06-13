# EA_LAB_FIRST_MANUAL_REPORT_REGISTRATION_PLAN.md

## 1. Purpose

This plan defines the manual registration workflow for the first validated EA_LAB inbox report.

The plan is documentation only. It does not parse the report, open report contents, edit Excel files, move report files, create automation, run MT5, or modify EA_CORE_V1.

## 2. Current Project Reference

- Current EA_LAB project: D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED
- Project purpose: safe manual collection and organization of future EA_CORE_V1 MT5 backtest and optimization results
- EA_CORE_V1 status: Closed / Frozen / Guarded
- Manual Inbox Re-Audit status: PASS

## 3. Validated Report Reference

Validated inbox report:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\inbox\RUN_EA_CORE_V1_20260612_0001_EURUSD_M15_SINGLE.html

This file has been validated by filename and inbox placement only. Its contents have not been parsed or read by Codex.

## 4. Validated Filename Metadata

Filename-derived metadata:

- RunID: RUN_EA_CORE_V1_20260612_0001
- EA_Code: EA_CORE_V1
- Date: 20260612
- Sequence: 0001
- Symbol: EURUSD
- Timeframe: M15
- ReportType: SINGLE
- Extension: .html

## 5. Registration Target Workbook Reference

Registration target workbook:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\results\EA_RESULTS.xlsx

This plan does not modify the workbook.

## 6. Registration Target Sheet For SINGLE Report

Target sheet:

- Runs

Do not enter this SINGLE report into optimization-only sheets during this phase.

## 7. Manual Data Fields To Copy From Report Into EA_RESULTS.xlsx / Runs

When MASTER approves manual Excel entry, a human operator may register one row in the Runs sheet.

Relevant Runs fields for this report:

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

## 8. Fields Already Known From Filename

Filename-derived fields already known:

- RunID = RUN_EA_CORE_V1_20260612_0001
- RunSource = MN
- EA_Code = EA_CORE_V1
- Symbol = EURUSD
- Timeframe = M15
- ResultFileName = RUN_EA_CORE_V1_20260612_0001_EURUSD_M15_SINGLE.html
- Status = INBOX_VALIDATED

These values may be used for manual entry only after MASTER approval.

## 9. Fields Requiring Human Reading From Report

The following fields require a human operator to read the MT5 report manually:

- PresetID
- PresetVersion
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
- ImportedAt
- Notes

Codex must not parse or read the report contents in this phase.

## 10. Fields Allowed To Remain Blank If Not Available

If the MT5 report does not clearly provide a value, the human operator may leave the field blank rather than infer it.

Fields commonly allowed to remain blank:

- PresetID
- PresetVersion
- SpreadMode
- ExpectedPayoff
- RecoveryFactor
- WinRatePct
- ImportedAt
- Notes

Unknown values should not be guessed.

## 11. Manual Validation Checklist Before Excel Entry

Before any future manual Excel entry, confirm:

- the report remains in reports\inbox
- the report filename still matches RUN_EA_CORE_V1_20260612_0001_EURUSD_M15_SINGLE.html
- RunID remains RUN_EA_CORE_V1_20260612_0001
- Symbol remains EURUSD
- Timeframe remains M15
- ReportType remains SINGLE
- extension remains .html
- no parser has processed the report
- no automation has imported the report
- EA_RESULTS.xlsx is available for manual editing
- EA_CORE_V1 remains unchanged

## 12. Manual Excel Entry Sequence

Recommended manual sequence after MASTER approval:

1. Open EA_RESULTS.xlsx manually.
2. Open the Runs sheet manually.
3. Create one new row for RunID RUN_EA_CORE_V1_20260612_0001.
4. Enter the filename-derived fields first.
5. Read the MT5 report manually.
6. Copy only clearly visible report metrics into the Runs row.
7. Leave unavailable fields blank.
8. Set Status to INBOX_VALIDATED unless MASTER approves a later status.
9. Save the workbook manually.
10. Stop and request review before moving the report.

## 13. What Not To Enter Yet

Do not enter this SINGLE report into:

- OptimizationPasses
- TopCandidates
- ParameterRecommendation

Do not create:

- candidate records
- parameter recommendations
- deployment readiness records
- portfolio grouping records

## 14. Parser / Automation Prohibition Reminder

No parser is approved.

No automation is approved.

Do not create or use:

- report parser
- report watcher
- MT5 runner
- Excel importer
- PowerQuery
- macro
- VBA
- script-based importer
- Telegram automation
- dashboard automation
- Power BI automation

## 15. Report Movement Prohibition For This Phase

Do not move, copy, rename, or archive the report in this phase.

The validated report must remain at:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\inbox\RUN_EA_CORE_V1_20260612_0001_EURUSD_M15_SINGLE.html

reports\raw and reports\archive remain future manual handling destinations only.

reports\parsed remains reserved for a future parser phase only.

## 16. EA_CORE_V1 Isolation Reminder

This registration plan is EA_LAB documentation only.

It must not modify:

- D:\EA_PROJECT
- EA_CORE_V1 source files
- EA_CORE_V1 test files
- EA_CORE_V1 build outputs
- EA_CORE_V1 release files
- PROJECT_MASTER_SPEC.md

EA_CORE_V1 remains Closed / Frozen / Guarded.

## 17. Risks And Mitigations

Risk: manual operator copies a value into the wrong sheet.

Mitigation: use Runs only for this SINGLE report.

Risk: unavailable fields are guessed.

Mitigation: leave unclear fields blank.

Risk: the report is moved before registration review.

Mitigation: keep the report in reports\inbox for this phase.

Risk: parser or automation scope starts early.

Mitigation: prohibit parser, automation, MT5 runner, macros, scripts, and dashboard integration.

Risk: EA_CORE_V1 isolation is broken.

Mitigation: keep all activity inside EA_LAB and avoid all EA_CORE_V1 files.

## 18. Stop Condition

Stop after this plan is created.

Do not:

- edit EA_RESULTS.xlsx
- read or parse the HTML report
- move the report
- create parser logic
- create automation
- run MT5
- modify EA_CORE_V1

Codex status: WAIT for MASTER review.
