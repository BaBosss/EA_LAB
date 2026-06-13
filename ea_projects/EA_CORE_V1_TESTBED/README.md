# EA_CORE_V1_TESTBED

EA_CORE_V1_TESTBED is the first real EA_LAB project instance for collecting and organizing future manual MT5 backtest and optimization results related to EA_CORE_V1.

This project was created from the finalized EA_LAB template project.

## Project Identity

- ProjectID: EA_CORE_V1_TESTBED
- EA_Code: EA_CORE_V1
- EA_Name: EA_CORE_V1 Testbed
- EA_Version: V1
- Status: ACTIVE_TESTBED

The included Excel workbooks are template schemas only. They contain sheet names and practical column headers only.

No formulas, macros, VBA, external connections, PowerQuery, parser logic, scripts, automation, strategy logic, live trading logic, or broker integration are created by this template.

## Folders

- config: EA control workbook and preset parameters.
- results: EA result workbook.
- reports\inbox: manual MT5 report drop zone.
- reports\raw: raw report archive location.
- reports\parsed: future parsed report output location.
- reports\archive: completed report archive location.
- set_files: MT5 `.set` files and preset exports.
- handoff: notes for review, candidate promotion, and manual handoff.

## Workflow Note

Manual/auto MT5 reports are not parsed yet.

Reports may be manually placed into reports\inbox.

Parsing and automation are future phases only.

No parser exists yet.

No automation exists yet.

## Identifier Formats

- RunID format: RUN_<EA_CODE><0001>
- OptBatchID format: OPT_<EA_CODE><0001>
- PassID format: _P000001
- CandidateID format: CAND_<EA_CODE>_
- RecommendationID format: REC_<EA_CODE><0001>
