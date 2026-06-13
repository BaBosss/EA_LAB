# EA_LAB_MANUAL_REPORT_INTAKE_WORKFLOW_PLAN.md

## 1. Purpose

This PLAN defines the manual workflow for placing MT5 reports into EA_LAB for later human review.

The workflow is manual-only. It does not approve parser logic, automation, MT5 runner behavior, report movement by Codex, Excel import, or EA_CORE_V1 changes.

## 2. SPEC Reference

- Accepted SPEC: D:\EA_LAB\EA_LAB_MANUAL_REPORT_INTAKE_WORKFLOW_SPEC.md
- SPEC status: EA_LAB_MANUAL_REPORT_INTAKE_WORKFLOW_SPEC.md = ACCEPTED FOR PLAN
- Current EA_CORE_V1 status: EA_CORE_V1 = Closed / Frozen / Guarded
- Current EA_CORE_V1 regression: 1417 PASS / 0 FAIL

## 3. Current Testbed Project Reference

- Current EA_LAB project: D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED
- ProjectID: EA_CORE_V1_TESTBED
- EA_Code: EA_CORE_V1
- EA_Name: EA_CORE_V1 Testbed
- EA_Version: V1
- Status: ACTIVE_TESTBED
- Control workbook: D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\config\EA_CONTROL.xlsx
- Results workbook: D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\results\EA_RESULTS.xlsx

## 4. Manual Report Intake Folder Roles

Folder roles:

- reports\inbox = human drops newly exported reports here
- reports\raw = human-approved raw report storage
- reports\archive = old/superseded/manual archive only
- reports\parsed = reserved for future parser phase only, do not use now

Accepted folders for current manual workflow:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\inbox
- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\raw
- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\archive

## 5. Manual File Naming Plan

Naming convention to preserve:

RUN_<EA_CODE>_<YYYYMMDD>_<0001>_<Symbol>_<Timeframe>_<ReportType>.<ext>

Examples:

- RUN_EA_CORE_V1_20260612_0001_EURUSD_M15_SINGLE.html
- RUN_EA_CORE_V1_20260612_0002_XAUUSD_M5_OPTIMIZATION.xml

Accepted extensions to document:

- .html
- .htm
- .xml
- .csv
- .xlsx
- .pdf
- .zip

Only the workflow is documented. No report files are created, moved, copied, parsed, imported, or validated by this PLAN.

## 6. Manual Metadata Capture Plan

For each manually placed report, the operator should capture or be able to infer:

- EA_Code
- report date
- sequence number
- symbol
- timeframe
- report type
- source preset or parameter set if known
- RunID if known
- OptBatchID if known
- PassID if known
- manual notes about purpose, source, or status

Metadata capture remains human/manual until a future approved phase changes that scope.

## 7. RunID / OptBatchID / PassID Assignment Plan

Identifier formats remain:

- RunID format: RUN_<EA_CODE><0001>
- OptBatchID format: OPT_<EA_CODE><0001>
- PassID format: _P000001
- CandidateID format: CAND_<EA_CODE>_
- RecommendationID format: REC_<EA_CODE><0001>

Assignment guidance:

- Use RunID for a single backtest, single exported report, or manually reviewed report run.
- Use OptBatchID for an optimization report or optimization batch.
- Use PassID only for a specific pass inside an OptBatchID.
- Do not generate PassID records automatically.
- Do not parse optimization reports to create pass records.
- Keep all assignment manual until a parser or automation phase is separately approved.

## 8. Inbox Review Plan

Manual inbox review should check:

- file name follows recommended naming convention
- file extension is one of the documented accepted extensions
- EA_Code appears to match the intended project
- symbol and timeframe are visible in the file name
- report type is visible in the file name
- duplicate or superseded files are manually identified by the operator

No automated inbox scanner is approved.

## 9. Raw / Archive Handling Plan

Manual handling guidance:

- Keep newly exported files in reports\inbox until a human review begins.
- Move human-approved raw report copies to reports\raw if they should be retained as source evidence.
- Move old, superseded, or completed review files to reports\archive when the operator decides they are no longer active.
- Do not use reports\parsed in this phase.

Codex must not move report files in this PLAN.

## 10. Manual Excel Entry Plan For Future Human Use

Future human entry may use:

- EA_CONTROL.xlsx for project, preset, symbol, timeframe, and optimization-plan context.
- EA_RESULTS.xlsx for manually entered Runs, OptimizationPasses, TopCandidates, ParameterRecommendation, and Notes.

Current PLAN limitations:

- no Excel file is edited
- no report data is imported
- no formulas are added
- no macros are added
- no external connections are added
- no PowerQuery is added
- no scripts are added

## 11. Parser Prohibition Plan

Parser behavior is not approved.

Forbidden:

- report parser
- HTML parser
- XML parser
- CSV parser
- PDF parser
- XLSX parser for report import
- ZIP unpacking parser
- automated extraction
- report-to-Excel importer
- parser scripts

## 12. Automation Prohibition Plan

Automation is not approved.

Forbidden:

- automation scripts
- scheduled jobs
- file watchers
- report watchers
- Telegram automation
- dashboard automation
- Power BI refresh automation
- MT5 automation
- broker automation

## 13. MT5 Runner Prohibition Plan

MT5 runner behavior is not approved.

Forbidden:

- running MT5
- launching terminal
- starting Strategy Tester
- compiling MQL
- running backtests
- running optimizations
- connecting to broker
- generating reports from MT5

## 14. EA_CORE_V1 Isolation Plan

EA_LAB remains separate from EA_CORE_V1.

This PLAN does not modify:

- D:\EA_PROJECT
- D:\EA_PROJECT\CURRENT_BUILD
- any EA_CORE_V1 source file
- any EA_CORE_V1 test file
- any EA_CORE_V1 build artifact
- any EA_CORE_V1 release file

EA_CORE_V1 remains Closed / Frozen / Guarded.

## 15. Operator Checklist

Before placing a report:

- confirm the report came from a manual MT5 export
- confirm the report is for EA_CORE_V1_TESTBED
- rename the file using the recommended naming convention
- confirm the file extension is documented as accepted
- place the file manually into reports\inbox

Before moving a report out of inbox:

- review the file manually
- decide whether it belongs in reports\raw or reports\archive
- record any workbook entries manually only if a separate phase approves Excel edits
- leave reports\parsed unused

## 16. Risks And Mitigations

Risk: inconsistent file names.

Mitigation: use the recommended naming convention.

Risk: report files get mistaken for parsed data.

Mitigation: keep reports\parsed unused until a parser phase is approved.

Risk: manual Excel entry may drift from source reports.

Mitigation: keep report file names tied to RunID or OptBatchID references.

Risk: EA_LAB work could be confused with EA_CORE_V1 source work.

Mitigation: preserve EA_CORE_V1 isolation and do not modify D:\EA_PROJECT.

## 17. Acceptance Criteria

This PLAN is acceptable if:

- it references the accepted SPEC
- it references D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED
- it documents manual folder roles
- it preserves the naming convention
- it documents accepted file extensions
- it documents manual metadata capture expectations
- it documents RunID / OptBatchID / PassID assignment guidance
- it prohibits parser, automation, and MT5 runner behavior
- it preserves EA_CORE_V1 isolation
- it does not modify Excel files, report files, source files, or existing README/spec files

## 18. Stop Condition

Stop after creating this PLAN.

Do not run MT5.
Do not create parser.
Do not create automation scripts.
Do not create Telegram files.
Do not create dashboard or Power BI files.
Do not create broker/live-trading files.
Do not create strategy logic.
Do not create optimization runner.
Do not create report parser.
Do not move or copy report files.
Do not modify Excel files.
Do not modify EA_CORE_V1.

Codex status: WAIT.

