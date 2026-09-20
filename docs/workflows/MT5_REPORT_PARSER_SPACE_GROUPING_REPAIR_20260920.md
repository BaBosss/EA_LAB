# MT5 Report Parser Space-Grouping Repair — 2026-09-20

Status: OWNER_AUTHORIZED / PROSPECTIVE TOOLING REPAIR / NO RETROACTIVE EVIDENCE REWRITE

## Trigger

B11 default example loop exact-head GPT Scrutiny on local result head `60c0c17ff6df66e82c74a1f733a3845ce68ef4c8` returned `SCRUTINY_FAIL / HIGH / BLOCK_INTEGRATION` with finding `B11-EXAMPLE-001`.

The raw Build6090 reports use space-separated thousands such as:
- `1 878.51 (18.63%)`;
- `2 214.70 (21.67%)`;
- `24 558.74`;
- `-23 861.79`.

Current `scripts/parse_mt5_report.py` drops the leading thousands group in maximal-drawdown regexes, searches `Symbols` against already-stripped HTML, and requests `Avg profit/loss trade` while the raw MT5 labels are `Average profit/loss trade`.

## Objective

Repair the canonical MT5 report parser so a single parser result is numerically faithful to raw Strategy Tester HTML for supported fields, with explicit regression coverage for the real B11 failure and synthetic boundaries.

## Allowed source

- `scripts/parse_mt5_report.py`
- `scripts/_test/run_parse_mt5_report_tests.ps1`
- this contract;
- P03/digest/state only for factual contract/acceptance convergence.

No EA source, set, risk/default, tester runner, runtime, deployment, historical report or accepted evidence byte may be changed by this tooling repair.

## Required red-first evidence

Before source repair, the new focused suite must fail against canonical `c9b363fe1bb328c5e65a3af33cf7ce5e12dc9a9c` on the exact defect classes:
1. real B11 MAIN raw report: Symbols=1; Balance Drawdown Maximal=1847.36; Equity Drawdown Maximal=1878.51; Average profit/loss=21.32/-14.29;
2. real B11 BWD raw report: Equity Drawdown Maximal=2214.70 and the matching raw fields;
3. synthetic positive/negative numbers with spaces and commas;
4. no silent conversion of missing fields into a false parsed source value where the parser contract does not support them.

The real B11 raw reports are external immutable defect fixtures and must be hash-bound:
- MAIN SHA256 `f4775e102c62cdd3b205bc4b3350b7159cb76820f84312a81830cf9d88c76f2b`;
- BWD SHA256 `65cde7679c7a811a7be7c3b436146a170938111c004beddb378b32e8d4ba1dce`.

## Repair constraints

- Preserve public keys and CLI shape used by existing callers.
- Keep `pn()` tolerant of ordinary MT5 numeric separators without accepting arbitrary malformed text.
- Parse value cells from raw HTML/table structure consistently; do not add a second unrelated parser implementation.
- Do not reinterpret PF/net/trade semantics or add performance policy.
- Unsupported/missing labels remain missing/default under the current public contract; do not invent values.
- No historical report/result is rewritten automatically.

## Acceptance

Required before source integration:
- focused parser suite green, including both immutable B11 reports;
- existing impacted parser/preflight/template tests green;
- `python -m py_compile scripts/parse_mt5_report.py`;
- strict state/digest/diff gates green;
- separate exact-head read-only GPT Scrutiny = PASS/HIGH/ALLOW_INTEGRATION;
- normal FF push verified by fetch + ls-remote.

One bounded source repair is authorized for this new tooling contract. If exact-head scrutiny fails after that repair, preserve the finding and stop; do not PASS-shop or reset the budget.

## Direct consumer

After parser source acceptance, a separate prospective B11 rerun contract may repeat the **same** example carrier/settings/windows from the prior loop solely to prove corrected end-to-end reporting. The rerun must not optimize, retune from prior outcomes, use HOLDOUT, assign Home/Candidate/Grade/KINT, or change risk/default/runtime/deployment/trading state.

This contract grants tooling repair and the later fixed-config example rerun only. It grants no strategy promotion or trading authority.
