# EA_LAB Multica Pilot Module

Purpose: package Multica as a non-authoritative agent-operations sidecar without replacing EA_LAB governance, Traycer planning, or LNWJUD execution safety.

## Authority boundary

Multica may later provide workspace UI, issue/task views, provider routing, session continuity, and runtime visibility. It is not the source of truth for canonical Git bytes, writer ownership, review acceptance, deployment authority, or owner hard stops.

Retained owners:
- ChatGPT Control Tower: objective, DAG, routing, integration control.
- `origin/master`: canonical repository bytes.
- `PROJECT_STATE.md` / `AGENTS.md` / taskboards: durable governance and queue.
- Lane Registry: writer/path/runtime ownership.
- LNWJUD: restricted execution/security gateway where used.
- Traycer: planning/spec/verification specialist; not a second authoritative work board.
- Owner: hard-stop decisions.

## Pilot safety

- Dirty `D:\EA_LAB` and descendants are rejected.
- EA_LAB may be represented only as `github_repo` pinned to an exact 40-hex SHA.
- `local_directory` is allowed only below `D:\EA_LAB_CONTROL\multica-pilot\cages`.
- Setup, browser auth, daemon start, runtime activation, deployment, trading, LIVE promotion, risk/default changes, owner attestation, force push, and history rewrite are all false in `pilot-policy.json`.
- No MT4/MT5 terminal path is in this module's write scope.

## Installed binary evidence

Pinned pilot CLI: Multica `0.4.34`.
Official release asset: `multica-cli-0.4.34-windows-amd64.zip`.
Official release checksum and downloaded archive checksum matched.
Installed binary SHA-256 is pinned by tests and recorded in `evidence/INSTALLATION_EVIDENCE.json`.
The Multica daemon remains stopped; `multica setup` and account authorization were not run by this pilot.

## Commands

Read-only status:
`powershell -File tools\multica_ea_lab_pilot\Invoke-MulticaPilot.ps1 -Action Status`

Read-only preflight:
`powershell -File tools\multica_ea_lab_pilot\Invoke-MulticaPilot.ps1 -Action Preflight`

Validate an exact-ref EA_LAB resource:
`powershell -File tools\multica_ea_lab_pilot\Invoke-MulticaPilot.ps1 -Action ValidateResource -ResourceType github_repo -Location https://github.com/BaBosss/EA_LAB -Ref <40-hex-sha>`

Run focused tests:
`powershell -File tools\multica_ea_lab_pilot\tests\run_tests.ps1 -Integration`

## Next gate

After this module is committed, authentication/runtime activation is a separate owner-external/runtime step. Before any EA_LAB write through Multica, run a disposable-cage provider/A2A test, prove no write escape, then require Lane Registry + exact isolated worktree + explicit allowed paths. No pilot PASS grants deployment or trading authority.
