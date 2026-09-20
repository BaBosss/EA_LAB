# MT5 Report Parser Hardening Repair2 — 2026-09-20

Status: OWNER_APPROVED_NEW_CONTRACT / REPAIR2_BUDGET_1_OF_1 / PROSPECTIVE_TOOLING_ONLY

## Owner approval

On 2026-09-20 the owner explicitly approved continuing all work after Repair1 exact-head review failed and authorized a new parser-hardening contract/new repair budget. This is a NEW contract and does not reset, erase, reopen, or reinterpret Repair1.

## Trigger

Repair1 local head `736672c41f5b2d6e721df0a9eae8b18c083aaad8` was not integrated after exact-head GPT Scrutiny `SCRUTINY_FAIL / HIGH / BLOCK_INTEGRATION` with:
- `MT5-PARSER-001/HIGH`: raw HTML extraction can cross cells/rows and consume a later value when the labeled field is missing.
- `MT5-PARSER-002/MEDIUM`: numeric grammar accepts malformed grouping such as `12 34.56` and `1,2,3`.

Canonical state at this contract base is `51409edba7f3eddec98d6084b68e3ff0a9bf32f6`.

## Objective

Harden `scripts/parse_mt5_report.py` so:
1. table field extraction is constrained to the target label cell's immediately adjacent value cell and never crosses another cell/row;
2. missing/empty target values cannot silently consume a later field;
3. ordinary MT5 numeric forms remain accepted: ungrouped digits, correctly grouped spaces, correctly grouped commas, optional sign, optional decimal;
4. malformed grouping is rejected under the current public contract rather than normalized into a false number;
5. existing public keys and CLI shape remain unchanged;
6. real B11 reports and versioned Build6090 regression reports remain numerically faithful.

## Allowed files

- `scripts/parse_mt5_report.py`
- `scripts/_test/run_parse_mt5_report_tests.ps1`
- this contract;
- P03/digest/state for factual lifecycle convergence only.

No EA source/set/risk/default/tester-runner/runtime/deployment/historical evidence bytes may change.

## Required red-first adversarial gates

Before Repair2 source mutation, focused tests must reproduce both review findings against canonical parser bytes:
- missing target value followed by another populated field: target remains missing/default and the next field retains its own value;
- malformed values `12 34.56`, `1,2,3`, mixed/group-invalid variants do not parse as valid numbers;
- valid `12 345.67`, `12,345.67`, `12345.67`, signed grouped values remain valid;
- immutable B11 MAIN/BWD raw fixtures remain hash-bound and expose the original grouped-number facts;
- synthetic MT5 table shape retains Symbols, drawdown pairs, counts, AHPR/GHPR, Average/Maximum labels.

## Repair constraints

- Use one parser implementation only; do not create a parallel parser.
- In HTML table mode, a field value must come from the immediate adjacent value cell; if absent/empty, return missing/default according to the current public contract.
- Plain-text fallback is allowed only when no table-cell match for the label/value structure exists and must not scan across unrelated labeled fields.
- Numeric normalization may remove separators only after the full token matches a valid grammar.
- Space-grouping and comma-grouping are separately valid; mixed separators in one integer are invalid.
- Historical reports/results are immutable and are never rewritten automatically.
- Repair2 source budget is exactly 1/1. One exact-head GPT Scrutiny follows. If it fails, stop without another repair or reviewer.

## Acceptance

Required:
- adversarial red-first evidence on canonical base;
- Repair2 focused suite green;
- immutable B11 MAIN/BWD raw fixture checks green;
- Build6090 versioned report regression 8/8;
- Research Preflight 40/40;
- template baseline guard 5/5;
- parser pycompile, digest, strict-state, diff and normal hooks PASS;
- exact-head read-only GPT Scrutiny = PASS/HIGH/ALLOW_INTEGRATION;
- normal FF push verified fetch + ls-remote.

Hermes safe-tester suite remains optional coverage if its process-local `mcp` dependency is unavailable; any NOT_RUN_ENV must stay explicit and cannot be called PASS.

## Direct consumer after acceptance

Only after parser source acceptance, preregister a separate B11 rerun using exactly the same source/default set/example carrier XAUUSD/H1/Model1/MAIN+BWD windows as the prior example. No retune, optimization, HOLDOUT, Home selection, Candidate/Grade/KINT, runtime/deployment/trading authority is created.
