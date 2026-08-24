---
name: ea-lab-harness
description: Run deterministic EA_LAB worker contracts through mode, TDD, runtime-identity, and assurance gates.
---

# EA_LAB Harness v1

Use this skill for Control Tower dispatches and worker packets that need repeatable execution-mode selection or structural evidence validation. It is a tooling gate; it does not replace EA_LAB governance, the lane registry, owner approval, or independent review.

Inputs are a JSON contract, hash-bound TDD evidence, observed runtime identity records, test/negative/regression results, artifact SHA-256 records, and a frozen reviewer record. The implementation is under `tools/ea_lab_harness/`; the detailed contract is [docs/EA_LAB_HARNESS_V1.md](../../docs/EA_LAB_HARNESS_V1.md).

Run the CLI with the repository-approved Python runtime:

```powershell
& 'D:\EA_LAB\tools\python312\python.exe' tools\ea_lab_harness\__main__.py route contract.json
& 'D:\EA_LAB\tools\python312\python.exe' tools\ea_lab_harness\__main__.py validate-tdd contract.json tdd.json
& 'D:\EA_LAB\tools\python312\python.exe' tools\ea_lab_harness\__main__.py validate-runtime contract.json runtime.json
& 'D:\EA_LAB\tools\python312\python.exe' tools\ea_lab_harness\__main__.py validate-packet packet.json artifact-hashes.json --current-candidate <sha>
```

Modes are exactly `QUICK`, `BOUNDED`, `TEAM`, `STRICT`, and `RUNTIME`. `STRICT` overrides consequential/high-risk/review requirements; `RUNTIME` is selected for runtime/deployment-operation tasks and still fails closed on owner hard stops; `TEAM` requires two or more independent, ready, non-overlapping lanes and otherwise routes to `BOUNDED`.

For applicable code changes, TDD evidence must show a hash-bound failing RED observation before a successful GREEN observation. Docs/data-only work must provide a non-empty not-applicable reason. Required runtime identity is observed evidence only and grants no authority. Assurance packets are SHA-256 bound to contract/base/candidate/lane/scope, results, artifacts, identities, TDD evidence, hard-stop actions/approvals, and frozen independent/different-family reviewer state.

Authority ceiling: this skill may route and reject evidence; it cannot approve owner hard stops, change risk/defaults, deploy, attach runtime, trade, promote DEMO to LIVE, select a Factory candidate, or self-declare independent review.
