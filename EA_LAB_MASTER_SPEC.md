# EA_LAB_MASTER_SPEC.md

## 1. Purpose

EA_LAB is a separate workspace for managing EA testing, optimization records, manual MT5 report intake, candidate selection, and future portfolio tracking.

## 2. Separation Boundary

EA_LAB is separate from EA_CORE_V1.

This scaffold does not modify:

- D:\EA_PROJECT\CURRENT_BUILD
- D:\EA_PROJECT\RELEASES
- EA_CORE_V1 source files
- EA_CORE_V1 test files
- EA_CORE_V1 release ZIPs

## 3. Current Scope

Allowed in this scaffold:

- folders
- README placeholders
- Excel templates with schema headers only

Not approved in this scaffold:

- formulas
- macros
- VBA
- external connections
- PowerQuery
- parser logic
- script logic
- strategy logic
- live trading logic
- broker integration
- ExecutionEngine
- Telegram automation
- Power BI dashboard
- report parser
- MT5 execution
- EA_CORE_V1 build, compile, or test

## 4. Identifier Standards

- RunID format: RUN_<EA_CODE><0001>
- OptBatchID format: OPT_<EA_CODE><0001>
- PassID format: _P000001
- CandidateID format: CAND_<EA_CODE>_
- RecommendationID format: REC_<EA_CODE><0001>

## 5. Report Intake Status

Manual/auto MT5 reports are not parsed yet.

Reports may be manually placed into reports\inbox.

Parsing and automation are future phases only.

No parser exists yet.

No automation exists yet.

## 6. Current Status

EA_LAB scaffold = CREATED

EA_LAB template schemas = REFINED / HEADERS ONLY

Codex status = WAIT
