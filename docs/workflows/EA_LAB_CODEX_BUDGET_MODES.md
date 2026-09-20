# EA_LAB Codex Budget Modes V3 — packet/mode tooling plus read-only reporter

Status: **source-only packet/mode tooling plus bounded read-only Reporter V3; pending deterministic checks and separate exact-head GPT Scrutiny**.

This component creates compact, deterministic `TASK_PACKET` and `REVIEW_PACKET` JSON plus a navigation-only `BOOT_MINI`. Reporter V3 is a separate read-only observer authorized by its 2026-09-20 contract with `source_repair_used=0`; it is a new milestone that closes only `CURV2-001` and does not reset or rewrite Reporter V2's failed review or spent repair. It does not change installed Codex settings, detect a subscription, route or launch a model, activate a profile, use the network, or touch MT5/runtime.

The packet schema remains authoritative for compact task/review contracts. Reporter V3 does not create replacement loose task/review schemas and does not change `NORMAL`/`ECONOMY` acceptance requirements.

`NORMAL` is the default recommendation. `ECONOMY` is an explicit alternative recommendation. Their author-reasoning, WIP, subagent, compactness, and advisory alert metadata differ, but their acceptance requirements are byte-equivalent and cannot waive a contract-owned gate. The alert values are advisory local-efficiency signals—not quotas, acceptance bars, or operational controls. No measured token or quota saving is claimed. The public library accepts only the exact packaged `mode_policy.json` bytes; caller-supplied policy bytes are permitted only when byte-identical to that canonical file.

## Compact flow

1. `BOOT_MINI` points to the task/lane, exact source-head text, packet type, and preserved source/evidence records. It is navigation only, not governance, source truth, or evidence.
2. `TASK_PACKET` carries one bounded objective, allowed and forbidden scope, authority ceiling, direct consumer, downstream skips, required gates, repair state, and exact declared locators/hashes.
3. `REVIEW_PACKET` adds distinct author/reviewer job and lane identities, an equal reviewed/source head, and the frozen evidence identity for separate read-only scrutiny.

Large source/evidence bytes are optional. Without supplied bytes, the record is `DECLARED_NOT_RECOMPUTED`. When canonical base64 bytes are supplied, their SHA-256 must match or creation refuses, and the record becomes `VERIFIED_SUPPLIED_BYTES`. A locator must be unique case-insensitively across both source and evidence records; every cross-array duplicate refuses. A 40-hex source head passes syntax validation only; it is not Git/worktree acceptance.

The receipt hashes the actual input bytes, policy bytes, and canonical compact output payload bytes and states its self-hash limitation. The CLI uses create-only output: the input's `unique_output` must be a simple `.json` filename, the output directory must already exist, and existing files, traversal, ambiguous paths, duplicate JSON keys, unknown fields, and invalid identities refuse without overwrite.

## CLI

Use only the repository portable Python:

```json
{"allowed_paths":["tools/codex_budget/packet_builder.py"],"authority_ceiling":["SOURCE_ONLY","NO_RUNTIME"],"direct_consumer":"Control Tower deterministic checks and separate exact-head GPT scrutiny","downstream_skip":["accepted EA source/runtime suites","old usage-reporter tests"],"evidence_records":[{"locator":"D:\\EA_LAB_CONTROL\\evidence\\packet\\CONTRACT.md","sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}],"forbidden_operations":["runtime activation","usage reporter transfer"],"lane_id":"ct-budget-packet","mode":"NORMAL","objective":"Build one bounded deterministic packet.","packet_type":"TASK_PACKET","repair_limit":1,"repair_used":1,"required_gates":[{"gate_id":"focused-tests","requirement":"Run the focused unit tests."}],"schema_version":"codex_budget_packet_input/1","source_head":"7c6bdea7aa980eb1adabebb822785eb74cbc058f","source_records":[{"locator":"tools/codex_budget/packet_builder.py","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}],"task_id":"BUDGET-PACKET-V1","unique_output":"AUTHOR_RESULT.json"}
```

```powershell
. .\scripts\use_python.ps1
$budgetPython = Assert-PortablePython -Provision
& $budgetPython .\tools\codex_budget\packet_builder.py --input .\task-input.json --output-dir .\packet-output
```

Running the same command again against the retained output demonstrates the create-only error path: it returns exit code `2` and `REFUSED: output already exists: AUTHOR_RESULT.json` without changing either file.

On success stdout is compact JSON with `CREATED`, the output path, output SHA-256, source-head text, input SHA-256, and policy SHA-256. The caller-named file (for example `AUTHOR_RESULT.json`) is the sole sink. Unknown, malformed, unsafe, ambiguous, mismatched, or already-existing output returns exit code `2`, writes `REFUSED: <reason>` to stderr, and does not overwrite an output.

The input schema is [packet.schema.json](../../tools/codex_budget/packet.schema.json). `mode` may be omitted only to select the `NORMAL` default. Every other listed field is required; `REVIEW_PACKET` requires its additional author/reviewer/head/evidence fields. Runtime validation intentionally enforces semantic constraints JSON Schema cannot express portably, including cross-array case-insensitive locator uniqueness, locator normalization, canonical base64, supplied-byte digest equality, repair ordering, author/reviewer separation, and reviewed-head equality.

## Read-only Reporter V3

`usage_reporter.py` selects `RECENTLY_UPDATED_THREADS`: threads whose `updated_at_ms` lies in the inclusive interval `[as_of_ms - hours, as_of_ms]`. `--hours` must be finite and greater than zero and is validated before any database existence check or open. `--as-of-ms` is an optional positive integer observation cutoff; omitting it uses current UTC milliseconds. The default Codex home is `~/.codex`; tests and callers may pass an explicit `--codex-home`.

Selected `tokens_used` values are lifetime counters observed on recently updated threads, not token consumption within the time window. The report exposes their known sum and completeness while `window_delta_tokens` remains `null` with `UNAVAILABLE_NO_BOUNDED_COUNTER_DELTAS`. A NULL counter remains unknown, never zero. Local counters and packaged thresholds are efficiency observations only—not quota, billing, credits, plan allowance, percent savings, or token-to-quota conversion.

Both databases are opened exclusively through SQLite URI `mode=ro`. Output goes to stdout unless `--out` is supplied; file output is create-only. The reporter accepts no alternate policy bytes or path and reads thresholds only from packaged canonical `mode_policy.json`. Its closed output contract is `usage_report.schema.json`; Reporter V3 adds equivalent standard-library validation for every reachable schema type, const, enum, bound, pattern, nullability, array item, and closed-object rule without changing the existing `codex_budget_usage_report/2` wire identity or adding a `jsonschema` dependency.

```powershell
. .\scripts\use_python.ps1
$budgetPython = Assert-PortablePython -Provision
& $budgetPython .\tools\codex_budget\usage_reporter.py --hours 24 --as-of-ms 1789862400000 --codex-home C:\path\to\synthetic-codex-home
```

## Acceptance boundary

This source is not accepted merely because it parses or its focused tests pass. The direct consumers are Control Tower deterministic checks and a separate read-only exact-head GPT Scrutiny review. Downstream work must skip already-accepted EA source/runtime suites and MT5; the focused Reporter V2 behavioral suite remains regression coverage inside the V3 suite. NORMAL/ECONOMY remain recommendations only until a separately authorized hookup exists; usage reporting and full operating-mode activation remain incomplete.
