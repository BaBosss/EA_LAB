# EA_LAB Ponytail Adapter Module

Purpose: apply Ponytail's minimal-implementation discipline to EA_LAB workers without replacing EA_LAB governance, tests, evidence, review, or safety controls.

## Upstream basis

Pinned upstream for this module build:

- repository: `DietrichGebert/ponytail`
- commit: `2ed6c52c9d7e5e56942508591085fd45dea277d3`
- Codex plugin version at that commit: `4.9.0`
- upstream project: https://github.com/DietrichGebert/ponytail

The upstream ladder is adapted, not copied as authority: understand the touched flow first, then avoid unnecessary work, reuse existing code, prefer standard-library/native capability and existing dependencies, and only then add the minimum implementation needed.

EA_LAB changes the optimization target from "shortest code" to **minimum necessary complexity**. LOC reduction is never an acceptance criterion.

## Authority boundary

This is a repository-only sidecar policy module. It does not install or activate Ponytail globally, modify governance/runtime/MT4/MT5/VPS/deployment/risk state, grant authority, or weaken existing cages and safety controls.

Every result contains `authority_granted=false`.

## Modes

| Request | Low-risk tooling/docs/tests | Protected or mixed | Unknown |
|---|---|---|---|
| `auto` | `full` | `review` | `review` |
| `full` | `full` | `review` | `review` |
| `lite` | `lite` | `review` | `review` |
| `review` | `review` | `review` | `review` |
| `off` | `off` | `off` | `off` |
| `ultra` | **REFUSE in v1** | **REFUSE in v1** | **REFUSE in v1** |

Protected work types include core, execution, position, accounting, money, risk, runtime, deployment, trading, and LIVE work. Protected paths include EA source/core surfaces, MT4/MT5 source, deployment/runtime stores, and MT4/MT5/deploy/live/risk launcher scripts.

Unknown, unsafe, or mixed paths fail closed to `review` rather than gaining write-mode minimalism.

## Mandatory preservation

Ponytail discipline may never be used as a reason to remove validation, error handling, security, applicable accessibility, observability/diagnostics, deterministic fail-closed behavior, tests/cages/negative tests, evidence/auditability, or owner hard-stop guards.

Readability and explicit state transitions may legitimately require more lines than compressed code.

## Contract and use

Input JSON:

```json
{"task_id":"EXAMPLE","requested_mode":"auto","work_type":"tooling","paths":["tools/example/checker.ps1"]}
```

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/ponytail_ea_lab/ponytail_policy.ps1 -InputPath contract.json
```

Output includes `decision`, `effective_mode`, deterministic `reasons`, `optimization_target=minimum_necessary_complexity`, `preserve`, `worker_overlay`, `authority_granted=false`, and the exact upstream pin/version.

Control Tower may inject `worker_overlay` into a bounded worker prompt. Existing Harness, Lane Registry, task acceptance, required different-family review, and owner hard stops remain controlling.

Recommended flow:

`task contract -> Lane Registry/Harness -> Ponytail decision -> worker overlay -> tests/evidence -> over-engineering review -> existing EA_LAB review -> later integration`

For core/execution/position/accounting/money/risk work this module is advisory review only.

## Tests

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/ponytail_ea_lab/tests/run_tests.ps1
```

The focused suite covers low-risk selection, protected-path/work-type downgrade, mixed-path downgrade, unknown/traversal fail-closed handling, explicit review/off, Ultra refusal, structured invalid-contract refusal, authority=false, preservation rules, complexity target, and upstream pin.

TDD evidence is under `evidence/`.

## Merge boundary

This module-build lane stops at a local frozen commit. It does not merge or push canonical master. Later integration should review the exact frozen head, reconcile against then-current `origin/master`, rerun impacted acceptance, and merge only if semantics remain unchanged.
