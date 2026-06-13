# EA_LAB_MANUAL_RUN_REGISTER_GUIDE.md

## 1. Purpose

This guide explains how a human operator should manually register a backtest or optimization report into EA_LAB.

The guide is documentation only. It does not parse reports, move files, edit Excel files, run MT5, automate workflows, or modify EA_CORE_V1.

## 2. Current Project Reference

- Current EA_LAB project: D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED
- ProjectID: EA_CORE_V1_TESTBED
- EA_Code: EA_CORE_V1
- EA_Name: EA_CORE_V1 Testbed
- EA_Version: V1
- Status: ACTIVE_TESTBED
- Control workbook: D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\config\EA_CONTROL.xlsx
- Results workbook: D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\results\EA_RESULTS.xlsx

## 3. When To Use This Guide

Use this guide when a human operator has manually exported an MT5 backtest or optimization report and wants to register it consistently in EA_LAB.

Use this guide for:

- single backtest reports
- optimization reports
- forward/demo review reports
- manually reviewed report packages

Do not use this guide for automated parsing, automated report import, MT5 execution, broker connection, or EA_CORE_V1 source work.

## 4. Manual Report File Naming Rules

Recommended report file naming convention:

RUN_<EA_CODE>*<YYYYMMDD>*<0001>*<Symbol>*<Timeframe>_<ReportType>.<ext>

Only the canonical literals in this section are valid.

RunID alone uses:

RUN_<EA_CODE>*<YYYYMMDD>*<0001>

Full report filename uses:

RUN_<EA_CODE>*<YYYYMMDD>*<0001>*<Symbol>*<Timeframe>_<ReportType>.<ext>

Invalid legacy formats:

- RUN_<EA_CODE><0001>_.
- RUN*<EA_CODE><0001>_.
- RUN_<EA_CODE>*<YYYYMMDD>*<0001>*<Symbol>*<Timeframe>*<ReportType>.<ext>

Examples:

- RUN_EA_CORE_V1_20260612_0001_EURUSD_M15_SINGLE.html
- RUN_EA_CORE_V1_20260612_0002_XAUUSD_M5_OPTIMIZATION.xml

ReportType examples:

- SINGLE
- OPTIMIZATION
- FORWARD
- WALKFORWARD
- REVIEW

Accepted report placement:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\inbox

## 5. RunID Format

RunID format:

- RUN_<EA_CODE>*<YYYYMMDD>*<0001>

Example:

- RUN_EA_CORE_V1*20260612*0001

Use RunID for one manually reviewed run, single backtest, or report registration.

## 6. OptBatchID Format

OptBatchID format:

- OPT_<EA_CODE><0001>

Example:

- OPT_EA_CORE_V10001

Use OptBatchID for one optimization batch or one optimization report group.

## 7. PassID Format

PassID format:

- _P000001

Example:

- _P000001

Use PassID only for a specific optimization pass inside an OptBatchID.

PassID assignment remains manual.

## 8. CandidateID Format

CandidateID format:

- CAND_<EA_CODE>_

Example:

- CAND_EA_CORE_V1_

Use CandidateID only when a manually reviewed result is promoted as a candidate.

## 9. RecommendationID Format

RecommendationID format:

- REC_<EA_CODE><0001>

Example:

- REC_EA_CORE_V10001

Use RecommendationID only when a human creates a parameter recommendation from reviewed evidence.

## 10. Single Backtest Registration Steps

Manual steps:

1. Export the MT5 single backtest report manually.
2. Rename the report using the recommended naming convention.
3. Place the report manually into D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\inbox.
4. Assign or record a RunID manually.
5. Identify EA_Code, symbol, timeframe, date range, deposit, leverage, and report type.
6. Review the report manually.
7. If a future approved phase allows Excel edits, manually enter summary fields into EA_RESULTS.xlsx / Runs.
8. Leave reports\parsed unused.

No parser or automation is involved.

## 11. Optimization Report Registration Steps

Manual steps:

1. Export the MT5 optimization report manually.
2. Rename the report using the recommended naming convention.
3. Place the report manually into D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\inbox.
4. Assign or record an OptBatchID manually.
5. Assign PassID values manually only if reviewing specific optimization passes.
6. Identify EA_Code, preset, symbol, timeframe, date range, and optimization criterion.
7. Review the report manually.
8. If a future approved phase allows Excel edits, manually enter reviewed pass summaries into EA_RESULTS.xlsx / OptimizationPasses.
9. If candidates are selected, manually enter them into EA_RESULTS.xlsx / TopCandidates.
10. Leave reports\parsed unused.

No parser or automation is involved.

## 12. Manual Fields To Copy Into EA_RESULTS.xlsx / Runs

For single backtests, future human entry may use the Runs sheet fields:

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

Excel entry is not performed by this guide.

## 13. Manual Fields To Copy Into EA_RESULTS.xlsx / OptimizationPasses

For optimization reports, future human entry may use the OptimizationPasses sheet fields:

- OptBatchID
- PassID
- EA_Code
- PresetID
- PresetVersion
- Symbol
- Timeframe
- NetProfit
- ProfitFactor
- ExpectedPayoff
- MaxDrawdownPct
- RecoveryFactor
- TotalTrades
- WinRatePct
- SharpeLike
- ParameterSummary
- SourceReportFile
- ImportedAt
- Status
- Notes

Excel entry is not performed by this guide.

## 14. Manual Fields To Copy Into EA_RESULTS.xlsx / TopCandidates

When a human promotes an optimization pass or run as a candidate, future entry may use:

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

Candidate selection remains manual.

## 15. Manual Fields To Copy Into EA_RESULTS.xlsx / ParameterRecommendation

When a human creates a parameter recommendation, future entry may use:

- RecommendationID
- EA_Code
- PresetID
- Symbol
- Timeframe
- ParameterName
- RecommendedZone
- MinValue
- MaxValue
- PreferredValue
- EvidenceSummary
- RobustnessComment
- Status
- Notes

Parameter recommendation remains manual.

## 16. What Not To Do

Do not:

- run MT5
- create parser
- create automation scripts
- create Telegram files
- create dashboard or Power BI files
- create broker/live-trading files
- create strategy logic
- create optimization runner
- create report parser
- move or copy report files with Codex
- modify EA_CORE_V1
- use reports\parsed

## 17. Folder Handling Rules

Allowed report placement:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\inbox

Reports may later be moved manually by a human to:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\raw
- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\archive

Reserved folder:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\parsed

reports\parsed is reserved for future parser only and should not be used yet.

## 18. Parser / Automation Prohibition Reminder

No parser exists yet.

No automation exists yet.

This guide does not approve:

- parser logic
- report parser
- automation scripts
- report watchers
- MT5 runner
- Telegram automation
- dashboard automation
- Power BI automation

## 19. EA_CORE_V1 Isolation Reminder

EA_LAB is separate from EA_CORE_V1.

This guide does not modify:

- D:\EA_PROJECT
- EA_CORE_V1 source files
- EA_CORE_V1 test files
- EA_CORE_V1 build files
- EA_CORE_V1 release files

EA_CORE_V1 remains Closed / Frozen / Guarded.

## 20. Operator Checklist

Before manual registration:

- confirm the report was exported manually
- confirm the report belongs to EA_CORE_V1_TESTBED
- confirm the file name follows the recommended naming convention
- confirm the report is placed into reports\inbox manually
- assign RunID or OptBatchID manually
- assign PassID manually only if needed
- review report values manually
- do not use reports\parsed
- do not run parser or automation
- do not modify EA_CORE_V1

Codex status: WAIT.
