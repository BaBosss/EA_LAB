# EA_LAB Traycer Pilot Module

Purpose: adopt Traycer as an agent-workspace/orchestration UI without replacing EA_LAB authority controls.

## Authority boundary

Traycer may provide shared context, multi-agent sessions, A2A communication, provider switching, and workspace UI.
It does not become the source of truth for writer ownership, review authority, integration authority, deployment authority, or canonical Git state.

Retained EA_LAB controls:
- ChatGPT Control Tower: objective/DAG/routing/integration decisions.
- Lane Registry: writer/path/runtime ownership.
- EA_LAB Harness: deterministic routing/evidence validation.
- Hermes wrapper: constrained task-scoped worker execution when Hermes is used.
- Git + pushed origin/master: canonical bytes.
- Owner hard stops: deployment/runtime attachment, trading/LIVE, risk/default changes, attestations, destructive cleanup, force/history rewrite.

## Isolation

This module is developed only in:
`D:\EA_LAB_worktrees\traycer-ea-lab-pilot-20260825`

Base SHA:
`dc23aea70c79dd53b2241be0d2b32620a2e5e9c2`

Dirty `D:\EA_LAB` and descendants are explicitly rejected by the pilot helper module.
No PROJECT_STATE.md, AGENTS.md, taskboard, MT5, deployment, or risk files are in this lane's write scope.

## Installed runtime

- Traycer Desktop: 1.2.0
- Windows application signature: Valid, signer `TRAYCER AI INC.`
- Bundled Traycer CLI: present and executable.
- Traycer Host: 1.2.0, running as the user-scoped registered host service.
- Git / Claude Code / Codex / Qwen Code: detected.
- Gemini CLI: not installed and intentionally excluded from this pilot.
- Traycer account auth: not yet completed; runtime probe returns `E_AUTH_NO_CREDENTIALS` until owner/browser device authorization is completed.
## Scripts

- `scripts/install_traycer.ps1` — pinned Windows installer with Authenticode signer gate.
- `scripts/bootstrap_host.ps1` — installs/starts the pinned Traycer host without force-kill semantics.
- `scripts/runtime_probe.ps1` — non-secret installation, host, doctor, and auth/harness probe.
- `scripts/preflight.ps1` — exact worktree/head/cleanliness + CLI availability gate.
- `scripts/new_cage.ps1` — creates a disposable Git cage outside the protected EA_LAB checkout.
- `tests/run_tests.ps1` — deterministic negative/positive pilot tests.

## TDD / acceptance evidence

A genuine RED was observed before `TraycerPilot.psm1` existed. The test suite failed on Import-Module.
After implementation and bounded Windows/Git-harness repair, integration tests pass 8/8.
See `evidence/RED.md`, `evidence/GREEN.txt`, and `evidence/RUNTIME_PROBE.json`.

## Pilot phases

1. Installation and local host bootstrap — complete.
2. Disposable cage safety tests — complete.
3. Traycer account/browser authorization — external/user action still required.
4. After auth, enumerate enabled harnesses and verify Claude/Codex provider profiles without changing EA_LAB.
5. Run multi-agent/A2A tests in a disposable cage.
6. Only after those pass, run an EA_LAB read-only exact-SHA workspace pilot.
7. Bounded-write integration requires Lane Registry + Harness and explicit allowed paths.
8. Hermes direct/native provider access must not bypass the existing EA_LAB Hermes wrapper; bridge design is a later bounded step.

## Merge rule

Do not merge this branch while parallel EA_LAB lanes are still moving the canonical lineage.
Freeze this module at an exact commit, run independent review, then integrate once against the then-current origin/master and rerun impacted acceptance.
No canonical push is part of the module-build phase.
