# EA_LAB_MANUAL_REPORT_INTAKE_WORKFLOW_SPEC.md

## 1. Purpose

This SPEC defines how manually exported MT5 reports may be placed into EA_LAB for later review.

The workflow is manual intake only. It does not parse, transform, import, automate, or execute any report file.

## 2. Current EA_LAB Workspace Reference

- EA_LAB root: D:\EA_LAB
- EA_LAB master spec: D:\EA_LAB\EA_LAB_MASTER_SPEC.md
- EA_LAB README: D:\EA_LAB\README.md
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

## 4. Scope

This SPEC covers:

- manual placement of MT5 report files
- recommended manual report naming
- report folder roles
- manual metadata capture expectations
- relationship between report files and RunID / OptBatchID / PassID identifiers
- how EA_CONTROL.xlsx and EA_RESULTS.xlsx relate to future manual review

## 5. Non-Goals

This SPEC does not approve:

- report parsing
- report copying or moving
- report import into Excel
- automation scripts
- MT5 runner
- report parser
- optimization runner
- Telegram files
- dashboard or Power BI files
- broker/live-trading files
- strategy logic
- EA_CORE_V1 modification

## 6. Manual Report Intake Folders

Accepted manual report placement folders:

- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\inbox
- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\raw
- D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED\reports\archive

Folder intent:

- reports\inbox: manual drop zone for newly exported MT5 reports awaiting review.
- reports\raw: manually retained raw report location after initial triage.
- reports\archive: manually archived report location after review or supersession.

The reports\parsed folder remains a placeholder only. Parsing is not approved.

## 7. Accepted Report File Types For Manual Placement

Accepted file extensions to document only:

- .html
- .htm
- .xml
- .csv
- .xlsx
- .pdf
- .zip

These are manual intake options only.

This SPEC does not create, copy, move, read, parse, or validate any report file.

## 8. Naming Convention Recommendation For Manually Placed Reports

Recommended manual file naming convention:

RUN_<EA_CODE>_<YYYYMMDD>_<0001>_<Symbol>_<Timeframe>_<ReportType>.<ext>

Examples:

- RUN_EA_CORE_V1_20260612_0001_EURUSD_M15_SINGLE.html
- RUN_EA_CORE_V1_20260612_0002_XAUUSD_M5_OPTIMIZATION.xml

ReportType examples:

- SINGLE
- OPTIMIZATION
- FORWARD
- WALKFORWARD
- REVIEW

## 9. RunID / OptBatchID / PassID Relationship

Identifier formats remain:

- RunID format: RUN_<EA_CODE><0001>
- OptBatchID format: OPT_<EA_CODE><0001>
- PassID format: _P000001
- CandidateID format: CAND_<EA_CODE>_
- RecommendationID format: REC_<EA_CODE><0001>

Relationship policy:

- RunID identifies one manual backtest or report review run.
- OptBatchID identifies one optimization batch.
- PassID identifies one optimization pass within an OptBatchID.
- A single optimization report may later produce many PassID records, but no parser is approved now.
- Manual file names may include run-style sequence numbers for human readability even before workbook entry.

## 10. Manual Metadata Capture Expectations

When a report is manually placed into reports\inbox, the reviewer should be able to identify:

- EA_Code
- report date
- sequence number
- symbol
- timeframe
- report type
- source preset or parameter set if known
- related RunID or OptBatchID if known
- manual notes about source, purpose, or status

Metadata capture remains manual until a future approved workflow introduces structured intake.

## 11. How EA_CONTROL.xlsx Relates To Manual Report Intake

EA_CONTROL.xlsx is the project control workbook.

For manual report intake, it may provide context such as:

- ProjectID
- EA_Code
- EA_Name
- EA_Version
- preset definitions
- symbol list
- timeframe list
- optimization plan references

This SPEC does not edit EA_CONTROL.xlsx.

This SPEC does not add formulas, macros, connections, PowerQuery, or scripts.

## 12. How EA_RESULTS.xlsx Relates To Future Manual Review

EA_RESULTS.xlsx is the project results workbook.

For future manual review, it may be used to record:

- Runs
- OptimizationPasses
- TopCandidates
- ParameterRecommendation
- Notes

Manual report files placed into reports\inbox may later be reviewed and summarized into EA_RESULTS.xlsx by a separate approved phase.

This SPEC does not edit EA_RESULTS.xlsx.

This SPEC does not import report data.

## 13. Inbox-To-Raw-To-Archive Conceptual Workflow

Conceptual manual workflow:

1. User exports an MT5 report manually.
2. User names the report using the recommended naming convention.
3. User manually places the report into reports\inbox.
4. User or reviewer manually inspects the report outside this SPEC.
5. User may manually move retained original reports into reports\raw.
6. User may manually move completed or superseded reports into reports\archive.

This workflow is conceptual only.

No file movement is performed by Codex in this SPEC.

## 14. Parser Prohibition

No parser is approved.

Forbidden:

- report parser
- CSV parser
- HTML parser
- XML parser
- PDF parser
- report-to-Excel importer
- automated extraction
- file scanning automation

## 15. Automation Prohibition

No automation is approved.

Forbidden:

- automation scripts
- scheduled jobs
- report watchers
- Telegram automation
- dashboard automation
- Power BI refresh automation
- MT5 automation
- broker automation

## 16. MT5 Runner Prohibition

No MT5 runner is approved.

This SPEC does not:

- run MT5
- start Strategy Tester
- launch terminal
- compile MQL
- execute backtests
- execute optimizations
- connect to broker

## 17. EA_CORE_V1 Isolation Boundary

EA_LAB remains separate from EA_CORE_V1.

This SPEC does not modify:

- D:\EA_PROJECT
- D:\EA_PROJECT\CURRENT_BUILD
- any EA_CORE_V1 source file
- any EA_CORE_V1 test file
- any EA_CORE_V1 build artifact
- any EA_CORE_V1 release file

EA_CORE_V1 remains Closed / Frozen / Guarded.

## 18. Risks And Mitigations

Risk: report files may be inconsistently named.

Mitigation: use the recommended naming convention.

Risk: manual placement may mix single-test and optimization reports.

Mitigation: include ReportType in file name.

Risk: reviewers may assume parser behavior exists.

Mitigation: this SPEC explicitly prohibits parser and automation behavior.

Risk: EA_LAB work may be confused with EA_CORE_V1 source work.

Mitigation: EA_CORE_V1 isolation boundary is explicitly recorded.

## 19. Acceptance Criteria

This SPEC is acceptable if:

- it references D:\EA_LAB
- it references D:\EA_LAB\ea_projects\EA_CORE_V1_TESTBED
- it documents reports\inbox, reports\raw, and reports\archive
- it documents accepted manual report file extensions
- it documents the recommended naming convention
- it documents RunID / OptBatchID / PassID relationship
- it documents manual metadata expectations
- it documents how EA_CONTROL.xlsx and EA_RESULTS.xlsx relate to future review
- it prohibits parser, automation, and MT5 runner behavior
- it records EA_CORE_V1 isolation
- it does not modify Excel files, report files, or EA_CORE_V1 files

## 20. Next Phase After SPEC

Recommended next phase:

- EA_LAB_MANUAL_REPORT_INTAKE_WORKFLOW_PLAN.md

Phase type:

- PLAN ONLY

Codex status: WAIT.

