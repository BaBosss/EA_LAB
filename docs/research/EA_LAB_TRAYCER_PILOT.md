# EA_LAB Traycer Adoption Pilot

Status: MODULE LANE / NOT CANONICAL / NOT MERGED

## Objective

Use Traycer's agent-workspace advantages while preserving the existing EA_LAB governance stack.
The intended gain is fewer manual context transfers between Claude Code, Codex, Qwen/Hermes-compatible workers, with shared agent context and A2A orchestration in one UI.

## Non-overlap architecture

`Boss -> ChatGPT Control Tower -> Lane Registry/Harness -> Traycer workspace -> constrained workers -> isolated Git worktrees -> frozen review -> canonical integration`

Responsibility split:

| Component | Authority / role |
| --- | --- |
| ChatGPT Control Tower | objective, DAG, routing, integration control |
| Traycer | workspace UI, sessions, context sharing, A2A, provider switching |
| Lane Registry | writer/path/runtime ownership and conflict refusal |
| EA_LAB Harness | deterministic mode/evidence validation |
| Hermes wrapper | task-scoped constrained Hermes mutation path |
| Git | exact lineage and canonical bytes |
| Owner | hard-stop decisions |

Traycer A2A is not evidence of EA_LAB one-writer ownership.
Traycer peer review is not automatically an EA_LAB frozen-HEAD independent review.

## Pinned pilot runtime

- EA_LAB base: `dc23aea70c79dd53b2241be0d2b32620a2e5e9c2`
- Branch: `module/traycer-ea-lab-pilot-20260825`
- Traycer Desktop: `1.2.0`
- Installer SHA-256: `538aefba2114610b3e3313c20bd81dc1d5b9385a43d81e01193347eda5f8ce0f`
- Authenticode signer: `TRAYCER AI INC.` / Valid
- Traycer Host: `1.2.0`
- Host registry SHA-256: `9fb84a05d3fccfdfb562e80982a12c0f6a7e8b55b5523fdfd05000985b58c822`
- Host: installed, user service registered, running locally
- Claude Code / Codex / Qwen Code: present on BaBoss
- Gemini CLI: absent; outside this pilot
## Runtime findings

Traycer Host 1.2.0 advertises provider-pack convergence including Claude, Codex, Qwen, Hermes and other harnesses. This is runtime discovery only; it does not grant those providers EA_LAB mutation authority.

Before Traycer account authorization, the local host is healthy and listening, but authenticated RPC cannot be fully verified. The harness query returns `E_AUTH_NO_CREDENTIALS`. No credential/token is stored in this module.

## Safety gates before EA_LAB use

1. Complete Traycer device/browser authorization.
2. Verify `host doctor` has no blocking issue.
3. Enumerate actual enabled harnesses/provider profiles.
4. Run Claude + Codex sessions only in a disposable cage first.
5. Exercise A2A, stop/resume, context handoff and concurrent-edit conflict cases.
6. Verify no writes escape the disposable cage.
7. Open an exact-SHA EA_LAB read-only workspace, never dirty `D:\EA_LAB`.
8. Any bounded EA_LAB write must have a Lane Registry claim, Harness contract/evidence, isolated clean worktree and explicit path allowlist.
9. Native Traycer Hermes access must not bypass the accepted `run_profile_task.ps1` safety path.
10. No deployment/runtime attachment, MT5 change, trading, LIVE/DEMO promotion, risk/default change, attestation, destructive cleanup, force push or history rewrite is authorized by this pilot.

## Current acceptance

- Traycer Desktop install/signature verification: PASS
- Traycer Host install/start: PASS
- Disposable cage helper tests: PASS
- Full local module tests with CLI smoke: 8/8 PASS
- Protected dirty-primary path rejection: PASS
- Traycer auth: WAITING / owner-external browser authorization
- Multi-agent/A2A functional cage test: WAITING on auth
- EA_LAB read-only Traycer pilot: WAITING on cage acceptance
- EA_LAB bounded-write through Traycer: NOT YET AUTHORIZED by this module

## Integration discipline

This branch is intentionally isolated while other EA_LAB lanes are committing in parallel. It may be committed locally as a self-contained module, but it must not be merged into moving canonical lineage until the module is frozen, reviewed independently, current origin/master is reconciled, and impacted checks are rerun once.
