# EA_LAB Harness v1

This module packages five reusable Control Tower/worker checks:

1. deterministic execution routing;
2. RED-before-GREEN TDD evidence for applicable code changes;
3. observed worker role/model/effort identity validation;
4. hash-bound assurance packets with frozen candidate/reviewer binding and bounded review attempts;
5. a skill entrypoint for repeatable dispatches.

It is an evidence validator, not an authority layer. Existing EA_LAB governance, `scripts/lane_registry.ps1`, owner hard stops, and required independent review remain authoritative.

## Public entrypoint

The standard-library-only implementation is `tools/ea_lab_harness/harness.py`, exported by `tools/ea_lab_harness/__init__.py` and executable through `tools/ea_lab_harness/__main__.py`. The project skill entrypoint is `skills/ea-lab-harness/SKILL.md`.

## Mode contract

`route_execution(contract)` accepts a JSON object with `contract_id`, optional exact `requested_mode`, and safety fields:

```json
{
  "contract_id": "ORDER-EXAMPLE",
  "requested_mode": "TEAM",
  "task_kind": "code",
  "consequential": false,
  "high_risk": false,
  "review_required": false,
  "ready_lanes": [
    {"lane_id": "lane-a", "ready": true, "independent": true, "allowed_paths": ["tools/a/"]},
    {"lane_id": "lane-b", "ready": true, "independent": true, "allowed_paths": ["tools/b/"]}
  ],
  "owner_hard_stop_requested": [],
  "owner_approved_actions": []
}
```

The result always includes `mode`, a deterministic `reason`, `allowed`, `hard_stop_blocked_actions`, and `authority_granted=false`. `STRICT` wins consequential/high-risk/governance/review requirements. `RUNTIME` wins runtime/deployment-operation routing when strict is not required and never clears an unapproved owner hard stop. `TEAM` is selected only for at least two independent ready lanes with pairwise non-overlapping allowed paths; an ineligible TEAM request becomes `BOUNDED`.

## TDD evidence

Code contracts use `tdd_applicable=true` and provide `seal_tdd_evidence({...})` output:

```json
{
  "schema_version": "1.0",
  "applicable": true,
  "red": {"observed": true, "exit_code": 1, "command": "...", "observation": "...", "sequence": 1},
  "green": {"success": true, "exit_code": 0, "command": "...", "observation": "...", "sequence": 2},
  "evidence_sha256": "<sha256 of the preceding fields>"
}
```

RED must be an observed non-success result, GREEN must be successful, both must record commands and observations, and RED sequence must precede GREEN. Full-suite success cannot substitute for missing RED. Docs/data-only contracts set `tdd_applicable=false` and provide a non-empty `reason`. Any content/hash mismatch fails closed.

## Runtime identity evidence

When `identity_required=true`, the contract declares `expected_runtime_identity` with exact `role`, `model`, and `effort`. Each observed record is sealed with `seal_runtime_identity` and must be verified with matching fields. The validator returns `authority_granted=false`; identity is evidence, not permission.

## Assurance packet

`build_assurance_packet` binds `schema_version`, task/contract identity, the full contract identity (including `base_sha`, `candidate_sha`, optional `candidate_tree_sha256`, `lane_id`, and `allowed_paths`), test/negative/regression results with evidence hashes, artifact paths and SHA-256 hashes, runtime identities, TDD evidence, hard-stop requested/approved actions, and review state. The packet `packet_id` is SHA-256 over the canonical JSON body excluding `packet_id`.

The review object must carry `reviewer_id`, `reviewer_family`, `reviewer_model`, `candidate_sha`, `reviewed_head`, `frozen_binding`, `independent_required`, `different_family_required`, `attempt`, `max_attempts`, and `approved`. Validation rejects a moved head/candidate, packet or nested evidence hash mismatch, missing/failed evidence, self-review, same-family review when required, an exceeded attempt budget, unapproved hard-stop actions, and artifact hash mismatch. Callers provide `current_candidate_sha` and actual `artifact_hashes` to validate the frozen external state.

No current canonical SHA, user identity, risk default, deployment state, or approval boundary is hardcoded as policy.

## Validation

The focused suite is `tools/ea_lab_harness/test_harness.py`. Because the repository's embedded Python is isolated and this worktree may lack its stdlib archive, the deterministic local invocation used for this module is:

```powershell
& 'D:\EA_LAB\tools\python312\python.exe' -c "import sys,runpy; sys.path.insert(0, r'tools\ea_lab_harness'); runpy.run_path(r'tools\ea_lab_harness\test_harness.py', run_name='__main__')"
```

This module does not touch MT4/MT5/VPS runtime state or modify the lane registry.
