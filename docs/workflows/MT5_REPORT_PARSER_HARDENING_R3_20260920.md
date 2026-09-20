# MT5 Report Parser Hardening Repair3 — 2026-09-20

Status: OWNER_APPROVED_NEW_CONTRACT / REPAIR3_BUDGET_1_OF_1 / PROSPECTIVE_TOOLING_ONLY

## Owner approval

On 2026-09-20 the owner explicitly approved continuing after Repair2 exact-head scrutiny failed and authorized a NEW Parser Hardening Repair3 1/1. This contract does not reset or erase Repair1/Repair2; both failed reviews remain negative evidence.

## Trigger

Repair2 local head `5771b7667eddbcbdd54f7060858452b922bf2e38` was not integrated after exact-head GPT Scrutiny `SCRUTINY_FAIL / HIGH / BLOCK_INTEGRATION` with:
- `MT5-PARSER-001-R2/HIGH`: an HTML label with no adjacent value cell can fall through to document-wide plain-text scanning and consume a later-row value.
- `MT5-PARSER-003/MEDIUM`: plain-text fallback can accept another labeled field when label and value share one line.

Canonical contract base: `d9b1d26ac7270b8c68c79b32c3b33df90636ae1b`.

## Objective

Produce one parser implementation that cleanly separates HTML-table extraction from legacy plain-text extraction:
1. if MT5 HTML table cells are present, field lookup is table-only and never falls through to document text;
2. a matched label without an immediately adjacent value cell returns missing/default;
3. a matched label with an empty adjacent cell returns missing/default;
4. plain-text fallback is used only when no HTML table-cell structure is present at all;
5. plain-text values must be on the same logical line after the label or the next non-empty line only when that line is not itself another label;
6. prior grouped-number and exact-label fixes from Repair1/Repair2 are retained;
7. malformed grouping remains rejected and valid grouping remains accepted;
8. public keys and CLI shape remain unchanged.

## Allowed paths

- `scripts/parse_mt5_report.py`
- `scripts/_test/run_parse_mt5_report_tests.ps1`
- this contract;
- P03/digest/state only for factual lifecycle convergence.

No EA source/set/risk/default/tester runner/runtime/deployment/historical report/result bytes may change.

## Required red-first adversarial evidence

Before Repair3 source mutation, the focused suite must fail on canonical bytes for:
- HTML label with **absent adjacent value cell** followed by a later-row numeric value: target remains missing/default;
- HTML label with **empty adjacent value cell** followed by populated later field: no bleed;
- UTF-16 plain text `Expert:\nSymbol: XAUUSD`: Expert must remain missing rather than consume another labeled field;
- plain text `Expert: PlainEA` and line-oriented `Expert:\nPlainEA` remain supported;
- all prior Repair2 malformed/valid grouping fixtures;
- immutable B11 MAIN/BWD raw reports and synthetic MT5 table fixture.

## Repair constraints

- One canonical parser implementation only.
- Detect HTML table-cell mode explicitly. If table cells exist, never use document-wide plain-text fallback for field values.
- In table mode, require exact label cell and immediate adjacent value cell. No cross-cell/row search.
- In plain-text mode, a candidate value that matches a label-shaped token (e.g. `Symbol: XAUUSD`) must be refused as the previous field's value.
- Numeric token must full-match the strict grammar before separator removal.
- Historical reports/results remain immutable.
- Repair3 budget is exactly 1/1. One exact-head reviewer follows. If it fails, stop; no Repair4 without a new owner approval.

## Acceptance

Required:
- red-first evidence on canonical base;
- focused/adversarial suite green;
- immutable B11 MAIN/BWD raw fixtures green;
- Build6090 versioned report regression 8/8;
- Research Preflight 40/40;
- template baseline guard 5/5;
- parser pycompile, digest, strict-state, diff and normal hooks PASS;
- exact-head read-only GPT Scrutiny = PASS/HIGH/ALLOW_INTEGRATION;
- normal FF push verified fetch + ls-remote.

Hermes safe-tester remains optional coverage if the process-local optional `mcp` module is absent; any NOT_RUN_ENV must stay explicit.

## Direct consumer after parser acceptance

Preregister a separate B11 rerun using exactly the same source/default set/example carrier XAUUSD/H1/Model1 windows:
- MAIN 2023.01.01..2025.12.31
- BWD 2020.01.01..2022.12.31
- USD 10,000
- leverage 1:100
- Optimization=0

The rerun must use fresh Build6090 identity and continue through report/review/state regardless of PF/BWD outcome. No retune, optimization, HOLDOUT, Home/Candidate/Grade/KINT, runtime/deployment/trading authority is created.
