# CODEX Usage Reporter V3 — Schema Validation Prospective Contract

Status: **PROSPECTIVE / BLOCKED_OWNER_AUTHORITY / CONTRACT_ONLY / NO_IMPLEMENTATION**

## Basis

- Exact prospective parent: `7348a40b2e42e20d5864eccdc64550efa7eae5b3`.
- The Codex Budget Packet component is already accepted/reviewed/canonical at that parent. Do not reopen or repeat packet repair/review absent actual drift.
- Reporter V2 local head `e38921c86f6b37240cc6eabbb19df5e95d7ba1a2` remains **SCRUTINY_FAIL / HIGH / BLOCK_INTEGRATION** with `CURV2-001_RUNTIME_VALIDATOR_TYPED_SCHEMA_GAP`; its source repair budget is spent. V3 is a new prospective milestone, not Repair2 and not a budget reset.
- V2 negative evidence/history remains immutable and must be consumed, not rewritten.

## Qualified direct consumer

The canonical Budget Modes workflow still states usage reporting and full operating-mode activation are incomplete. A truthful read-only usage observation is required before a later separately authorized NORMAL/ECONOMY hookup and observational calibration can be evaluated. Therefore this successor has a direct consumer. This contract itself grants **no** hookup/profile/runtime/model-routing authority.

## Future implementation scope, only after explicit owner authorization

Allowed source paths are limited to:

- `docs/workflows/EA_LAB_CODEX_BUDGET_MODES.md`
- `tools/codex_budget/usage_report.schema.json`
- `tools/codex_budget/usage_reporter.py`
- `tools/codex_budget/tests/test_usage_reporter.py`

The implementation must bind this exact parent or a mechanically reanchored current-canonical child before author work begins. No source work is authorized by this contract-only commit.

## Required behavior

1. Preserve Reporter V2 failure evidence and all earlier BUDGET-001..004 history.
2. Close only the typed runtime/schema equivalence gap exposed by `CURV2-001`.
3. `policy_sha256` must be exactly lowercase hexadecimal matching `^[0-9a-f]{64}$`.
4. Runtime validation must distinguish JSON Schema `integer` from `number`; booleans must never satisfy integer/number fields merely because Python treats `bool` as an `int`.
5. Every schema-bound field must have runtime type/const/enum validation equivalent to `usage_report.schema.json`, including `model`, `reasoning_effort`, nested counts, heaviest-thread fields, nullable integer fields, arrays, and closed-object keys.
6. Preserve read-only SQLite URI `mode=ro`; no writes, migrations, mutable pragmas, subprocess, network, model calls, runtime controls, profile changes, MT5, or hidden persistent files.
7. Preserve truthful semantics: selected population is `RECENTLY_UPDATED_THREADS`; `tokens_used` is a lifetime counter; `window_delta_tokens=null`; NULL counters remain unknown; no quota/billing/credits/plan/savings/token-to-quota claim.
8. Mode policy remains package-pinned. No plan/subscription auto-detection.
9. `--out`, if retained, remains create-only and refuses overwrite.
10. No runtime/profile hookup is granted even if source later passes review.

## Prospective acceptance tests

The future author must run the existing Reporter V2 focused synthetic/read-only suite without weakening it, plus new typed-equivalence adversarial coverage.

Minimum new adversarial fixtures:

- `policy_sha256 = "z"*64` -> runtime refusal.
- integer field represented as numerically equal floating point, e.g. lifetime total `0.0` -> refusal wherever schema says `integer`.
- boolean substituted into every integer/number field -> refusal.
- `model=7`, `reasoning_effort=false` -> refusal.
- empty/non-string values for every schema string field with `minLength:1` -> refusal.
- invalid enum/const values -> refusal.
- invalid nullable fields: only the schema-declared integer-or-null values are accepted.
- nested object unknown/missing keys -> refusal.
- array item wrong types for `model_counts`, `reasoning_effort_counts`, `thread_history_item_type_counts`, and `heaviest_top_level_threads` -> refusal.

The test suite must load `usage_report.schema.json`, enumerate every typed/const/enum leaf reachable from the root and `$defs`, and produce a deterministic coverage receipt proving each schema-bound leaf is either directly adversarially exercised or covered by a named shared validator rule. Any unaccounted schema leaf blocks acceptance. This is a standard-library test oracle/coverage check; adding `jsonschema` is not required.

Required gates after owner-authorized implementation:

- red-first reproduction of the exact V2 adversarial probe;
- existing Reporter V2 synthetic/read-only tests remain green;
- full typed-equivalence adversarial matrix green;
- schema coverage receipt has zero uncovered leaves;
- `py_compile`;
- JSON schema parse;
- exact path/scope audit;
- synthetic SQLite files byte-identical before/after;
- `git diff --check`;
- normal hooks;
- clean exact frozen head;
- **one** separate read-only acceptance-grade GPT Scrutiny.

Only `SCRUTINY_PASS / HIGH / ALLOW_INTEGRATION` permits source-only integration. No second repair/reviewer loop is implied. Any later NORMAL/ECONOMY runtime/profile hookup remains a separate owner-gated milestone.
