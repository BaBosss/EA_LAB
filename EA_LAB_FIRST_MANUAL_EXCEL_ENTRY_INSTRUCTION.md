# EA_LAB_FIRST_MANUAL_EXCEL_ENTRY_INSTRUCTION.md

## 1. Purpose

This instruction document tells a human operator how to manually enter the first validated EA_LAB inbox report into EA_RESULTS.xlsx.

This document is instruction only. It does not parse the report, open report contents, edit Excel files, move report files, create automation, run MT5, or modify EA_CORE_V1.

## 2. Validated Report Reference

Validated report:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\inbox\RUN_EA_CORE_V1_20260612_0001_EURUSD_M15_SINGLE.html

Validated report status:

- Manual Inbox Re-Audit = PASS
- ReportType = SINGLE
- Extension = .html

## 3. Target Workbook And Sheet

Registration target workbook:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\results\EA_RESULTS.xlsx

Registration target sheet:

- Runs

Only the Runs sheet is in scope for this first SINGLE report entry.

## 4. Row Insertion Rule

After MASTER approval for manual Excel entry:

1. Open EA_RESULTS.xlsx manually.
2. Open the Runs sheet manually.
3. Add exactly one new row for RunID RUN_EA_CORE_V1_20260612_0001.
4. Do not overwrite existing rows.
5. Do not create formulas, macros, VBA, scripts, external connections, or PowerQuery.
6. Save the workbook manually only after checking the row.

## 5. Filename-Derived Fields And Values

Enter these fields from the validated filename:

- RunID = RUN_EA_CORE_V1_20260612_0001
- RunSource = MN
- EA_Code = EA_CORE_V1
- Symbol = EURUSD
- Timeframe = M15
- ResultFileName = RUN_EA_CORE_V1_20260612_0001_EURUSD_M15_SINGLE.html
- Status = INBOX_VALIDATED

## 6. Human-Read Fields To Collect From Report

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

## 7. Allowed Blank Fields

If not clearly available in the report, these fields may remain blank:

- PresetID
- PresetVersion
- SpreadMode
- ExpectedPayoff
- RecoveryFactor
- WinRatePct
- Notes

Do not guess missing values.

## 8. Exact Column Mapping For Runs Sheet

Use this column mapping for the Runs sheet:

| Runs Column | Entry Source | Value Or Instruction |
| --- | --- | --- |
| RunID | Filename | RUN_EA_CORE_V1_20260612_0001 |
| RunSource | Filename / manual convention | MN |
| EA_Code | Filename | EA_CORE_V1 |
| PresetID | Human-read report field | Enter manually if available |
| PresetVersion | Human-read report field | Enter manually if available |
| Symbol | Filename | EURUSD |
| Timeframe | Filename | M15 |
| DateFrom | Human-read report field | Enter manually |
| DateTo | Human-read report field | Enter manually |
| Deposit | Human-read report field | Enter manually |
| Leverage | Human-read report field | Enter manually |
| SpreadMode | Human-read report field | Enter manually if available |
| NetProfit | Human-read report field | Enter manually |
| GrossProfit | Human-read report field | Enter manually |
| GrossLoss | Human-read report field | Enter manually |
| ProfitFactor | Human-read report field | Enter manually |
| ExpectedPayoff | Human-read report field | Enter manually if available |
| MaxDrawdownAbs | Human-read report field | Enter manually |
| MaxDrawdownPct | Human-read report field | Enter manually |
| RecoveryFactor | Human-read report field | Enter manually if available |
| TotalTrades | Human-read report field | Enter manually |
| WinRatePct | Human-read report field | Enter manually if available |
| ResultFileName | Filename | RUN_EA_CORE_V1_20260612_0001_EURUSD_M15_SINGLE.html |
| ImportedAt | Human manual timestamp | Enter manually if used |
| Status | Filename / intake status | INBOX_VALIDATED |
| Notes | Human note | Enter manually if needed |

## 9. Manual Validation Before Saving Excel

Before saving EA_RESULTS.xlsx, confirm:

- exactly one Runs row was added for RUN_EA_CORE_V1_20260612_0001
- RunID matches the validated report filename
- ResultFileName matches the validated report filename
- Symbol is EURUSD
- Timeframe is M15
- Status is INBOX_VALIDATED
- no optimization sheets were edited
- no formulas were added
- no macros or VBA were added
- no external connections or PowerQuery were added
- the report file remained in reports\inbox
- EA_CORE_V1 files were not modified

## 10. What Not To Update

Do not update these sheets yet:

- OptimizationPasses
- TopCandidates
- ParameterRecommendation
- Notes unless manually needed

Do not update:

- central candidate workbooks
- strategy idea bank workbooks
- template project files
- EA_CORE_V1 files

## 11. Parser / Automation Prohibition Reminder

No parser is approved.

No automation is approved.

Do not create or use:

- report parser
- report watcher
- MT5 runner
- Excel importer
- script-based importer
- macro
- VBA
- PowerQuery
- Telegram automation
- dashboard automation
- Power BI automation

## 12. Report Movement Prohibition Reminder

Do not move, copy, rename, or archive the report in this phase.

The report must remain at:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\inbox\RUN_EA_CORE_V1_20260612_0001_EURUSD_M15_SINGLE.html

reports\raw and reports\archive are future manual handling destinations only.

reports\parsed remains reserved for a future parser phase only.

## 13. EA_CORE_V1 Isolation Reminder

This instruction is EA_LAB documentation only.

It must not modify:

- D:\EA_PROJECT
- EA_CORE_V1 source files
- EA_CORE_V1 test files
- EA_CORE_V1 build outputs
- EA_CORE_V1 release files
- PROJECT_MASTER_SPEC.md

EA_CORE_V1 remains Closed / Frozen / Guarded.

## 14. Stop Condition After Excel Entry

After the human operator manually enters the Runs row and saves EA_RESULTS.xlsx:

- stop
- do not parse the report
- do not move the report
- do not create scripts
- do not run MT5 from Codex
- do not update optimization sheets
- do not create candidates
- wait for MASTER review

Codex status: WAIT.
