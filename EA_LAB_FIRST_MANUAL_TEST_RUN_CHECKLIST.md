# EA_LAB_FIRST_MANUAL_TEST_RUN_CHECKLIST.md

## 1. Purpose

This checklist guides a human operator through the first manual MT5 report intake into EA_LAB.

The checklist is documentation only. It does not run MT5, parse reports, move files, edit Excel files, create automation, or modify EA_CORE_V1.

## 2. Current Project Reference

- Current EA_LAB project: D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED
- ProjectID: EA_CORE_V1_TESTBED
- EA_Code: EA_CORE_V1
- EA_Name: EA_CORE_V1 Testbed
- EA_Version: V1
- Status: ACTIVE_TESTBED
- Control workbook: D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\config\EA_CONTROL.xlsx
- Results workbook: D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\results\EA_RESULTS.xlsx

## 3. Preconditions Before Manual Test

- EA_CORE_V1 remains Closed / Frozen / Guarded.
- EA_LAB project folder exists.
- EA_CONTROL.xlsx exists.
- EA_RESULTS.xlsx exists.
- reports\inbox exists.
- reports\raw exists.
- reports\archive exists.
- reports\parsed exists but is reserved for future parser only.
- Operator performs MT5 export manually outside Codex.

## 4. Required Manual Report Destination

Manual destination:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\inbox

Only a human operator may place the first report file there.

Codex must not move or copy report files in this task.

## 5. Approved Canonical Report Filename Format

Operational canonical specification literal:

RUN_<EA_CODE>*<YYYYMMDD>*<0001>*<Symbol>*<Timeframe>_<ReportType>.<ext>

The asterisks in the specification literal are schema separators only.

Do not use asterisks in actual manually exported report filenames.

Actual manually exported report filenames must follow the underscore-separated examples below.

## 6. First Suggested RunID

First suggested RunID:

- RUN_EA_CORE_V1_20260612_0001

Use this as the human registration reference for the first single-test report if MASTER accepts the date and sequence.

## 7. First Suggested Single-Test Filename Example

First suggested single-test filename:

- RUN_EA_CORE_V1_20260612_0001_EURUSD_M15_SINGLE.html

This is an example only. The human operator may change symbol, timeframe, date, sequence, or extension before placing a real report.

## 8. First Suggested Optimization Filename Example

First suggested optimization filename:

- RUN_EA_CORE_V1_20260612_0002_XAUUSD_M5_OPTIMIZATION.xml

This is an example only. The human operator may change symbol, timeframe, date, sequence, or extension before placing a real report.

## 9. What MT5 Report Types May Be Manually Exported

Manual export may include:

- single backtest report
- optimization report
- forward/demo review report
- walk-forward review report
- manually zipped report package

Allowed documented extensions remain:

- .html
- .htm
- .xml
- .csv
- .xlsx
- .pdf
- .zip

## 10. What Not To Export Yet

Do not export or place:

- broker account credentials
- live trading logs
- private account statements
- execution ticket exports
- files requiring parser automation
- files requiring dashboard automation
- files requiring Telegram automation

## 11. What Not To Create Yet

Do not create:

- parser
- automation scripts
- MT5 runner
- Telegram files
- dashboard files
- Power BI files
- broker/live-trading files
- strategy logic
- optimization runner
- report parser

## 12. Manual Placement Steps

Manual steps:

1. Human operator exports the MT5 report manually.
2. Human operator names the report using the accepted example style.
3. Human operator confirms the report is for EA_CORE_V1_TESTBED.
4. Human operator places the report into D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\inbox.
5. Human operator leaves reports\parsed unused.
6. Human operator records any review notes manually outside this checklist.

Codex performs none of these file operations.

## 13. Manual EA_RESULTS.xlsx Entry Reminder

EA_RESULTS.xlsx may be used by a human in a future approved manual entry phase.

Potential target sheets:

- Runs
- OptimizationPasses
- TopCandidates
- ParameterRecommendation
- Notes

This checklist does not edit EA_RESULTS.xlsx.

## 14. Manual Review Checklist

Before considering the first report ready for review, confirm:

- file is in reports\inbox
- file name includes EA code
- file name includes date
- file name includes sequence number
- file name includes symbol
- file name includes timeframe
- file name includes report type
- extension is one of the documented accepted extensions
- report is not parsed
- report is not imported into Excel by automation
- EA_CORE_V1 was not modified

## 15. Parser / Automation Prohibition Reminder

No parser exists yet.

No automation exists yet.

No MT5 runner is approved.

Do not create:

- parser logic
- report parser
- automation scripts
- report watcher
- MT5 runner
- Telegram automation
- dashboard automation
- Power BI automation

## 16. EA_CORE_V1 Isolation Reminder

EA_LAB is separate from EA_CORE_V1.

This checklist does not modify:

- D:\EA_PROJECT
- EA_CORE_V1 source files
- EA_CORE_V1 test files
- EA_CORE_V1 build files
- EA_CORE_V1 release files

EA_CORE_V1 remains Closed / Frozen / Guarded.

## 17. Known Minor Doc Issue Note

Known minor documentation issue:

- Manual Run Register Guide may contain a previously unresolved naming-literal audit issue.

Operational canonical specification literal for this checklist is:

RUN_<EA_CODE>*<YYYYMMDD>*<0001>*<Symbol>*<Timeframe>_<ReportType>.<ext>

Do not treat asterisk-separated actual filenames as valid.

Invalid actual filename style:

- RUN_EA_CORE_V1*20260612*0001*EURUSD*M15_SINGLE.html

This checklist does not fix the Manual Run Register Guide.

## 18. Stop Condition After First Report Is Placed

After the first report is manually placed into reports\inbox:

- stop
- do not parse the report
- do not move the report automatically
- do not update Excel automatically
- do not create scripts
- do not run MT5 from Codex
- wait for MASTER review

Codex status: WAIT.
