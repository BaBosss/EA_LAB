# MT5 Report Parser Hardening Repair4 — 2026-09-20

Status: OWNER_APPROVED_NEW_CONTRACT / REPAIR4_BUDGET_1_OF_1 / PROSPECTIVE_TOOLING_ONLY

## Owner approval
Owner explicitly approved continuing after Repair3 review failure and asked Main CT to check for duplicate lanes first. Lane Registry check at canonical `2a2fd59a88280f189e49296c92db752f2de330a8` found no active writers and no Repair4/B11-rerun lane.

## Trigger
Repair3 local head `7ca32506e8eed10dd39471929c808ed1333ff690` remains unpushed after `SCRUTINY_FAIL / HIGH / BLOCK_INTEGRATION`:
- `MT5-PARSER-004/HIGH`: alias fallback can override a matched empty/absent preferred label with a later alias value.
- `MT5-PARSER-005/MEDIUM`: plain-text inline extraction can accept a label-shaped value, e.g. `Expert: Symbol: XAUUSD`.

## Objective
Retain all prior grouped-number/table/plain-text hardening, while adding:
1. tri-state lookup: NOT_FOUND / FOUND_EMPTY / FOUND_VALUE;
2. alias fallback only when the preferred label is NOT_FOUND; FOUND_EMPTY must remain empty/default;
3. label-shaped guard on inline plain-text values as well as following-line candidates;
4. no historical evidence rewrite; public JSON keys/CLI unchanged.

## Allowed paths
`scripts/parse_mt5_report.py`, `scripts/_test/run_parse_mt5_report_tests.ps1`, this contract, P03/digest/state lifecycle only.

## Red-first required
Before source mutation:
- preferred `Average profit trade:` matched-empty followed by `Avg profit trade: 99.00` must stay default;
- preferred label present without adjacent cell followed by later alias value must stay default;
- `Expert: Symbol: XAUUSD` must leave Expert empty while Symbol retains XAUUSD;
- prior Repair3 62-case suite and immutable B11 fixtures remain bound.

## Acceptance
Repair4 1/1; focused/adversarial suite; immutable B11 MAIN/BWD; Build6090 8/8; Research Preflight 40/40; template baseline 5/5; pycompile/digest/strict-state/diff/hooks; one exact-head read-only GPT Scrutiny. No second Repair4 edit or duplicate reviewer after freeze.

## Direct consumer
Only after parser source PASS/HIGH/ALLOW and verified FF push: preregister the same fixed B11 example rerun (XAUUSD/H1, defaults, Model1, MAIN 2023-2025, BWD 2020-2022, USD10k, 1:100, Optimization=0) and continue through final report/review/state regardless of performance. No retune/optimization/HOLDOUT/Home/Candidate/runtime/deployment/trading authority.
