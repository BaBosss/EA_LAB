# EA_LAB Codex Budget Modes V1 — packet/mode tooling only

Status: **partial source-only packet/mode tooling; pending deterministic checks and separate exact-head GPT Scrutiny**.

This component creates compact, deterministic `TASK_PACKET` and `REVIEW_PACKET` JSON plus a navigation-only `BOOT_MINI`. It does not implement or accept the usage reporter. The safety-blocked reporter proposal remains unaccepted with its historical repair `1/1` spent; this component neither transfers that code nor allocates another repair. It also does not change installed Codex settings, detect a subscription, route or launch a model, activate a profile, read a Codex database, or touch MT5/runtime.

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

## Acceptance boundary

This source is not accepted merely because it parses or its focused tests pass. The direct consumers are Control Tower deterministic checks and a separate read-only exact-head GPT Scrutiny review. Downstream work must skip already-accepted EA source/runtime suites, MT5, and all old usage-reporter tests. NORMAL/ECONOMY remain recommendations only until a separately authorized hookup exists; usage reporting and full operating-mode activation remain incomplete.
