# EA_LAB Multica Adoption Pilot

Status: MODULE LANE / NON_AUTHORITATIVE_SIDECAR / LOCAL COMMIT TARGET

## Objective

Evaluate and package Multica as the EA_LAB agent-operations surface for multi-provider dispatch/status while preserving existing governance and safety boundaries.

Direct consumer: EA_LAB Control Tower and the later Multica integration/acceptance lane.

Downstream skip: future adoption work should not rediscover the Multica/Traycer/LNWJUD responsibility split, dirty-primary prohibition, exact-ref resource rule, installed CLI identity, or initial runtime safety posture.

## Non-overlap architecture

`Owner -> ChatGPT Control Tower -> Lane Registry / canonical Git governance -> Multica operations UI -> constrained provider workers -> isolated worktrees -> frozen review -> integration`

Specialized adjacent components remain:
- Traycer: complex planning, specification decomposition, architecture/plan verification. Do not run it as a second authoritative task board alongside Multica.
- LNWJUD: restricted execution/security gateway. Multica does not replace permission enforcement.
- EA_LAB Harness: deterministic task/evidence validation where applicable.
- Remote Desktop Commander: Windows/operator transport; Multica does not replace general machine/MT5 transport.

## Anti-duplication rule

Multica Issues/Projects are operational views only during the pilot. They must not become a competing canonical queue against `AGENT_TASKBOARD.md` and Lane Registry. A Multica status such as DONE is not an EA_LAB ACCEPTED verdict. Writer/reviewer ownership remains in Lane Registry and canonical acceptance remains bound to exact Git lineage.

Traycer remains available as a specialist planner/verifier, not a parallel dispatcher for the same live task. If a task has already been claimed in Multica, Traycer may produce a bounded plan/review artifact only when it has a unique output and direct consumer.

## Canonical start and lane

Base: `165c999d4b91421bbd78d844d5388c3cc6c5bef6`
Branch: `module/multica-ea-lab-pilot-20260826`
Worktree: `D:\EA_LAB_worktrees\multica-ea-lab-pilot-20260826`

The dirty/diverged primary `D:\EA_LAB` is preservation-only and is never a Multica pilot resource.

## Installed Multica CLI

Version: `0.4.34`
Build commit reported by CLI: `e5f976144`
Platform: `windows/amd64`
Installed binary: `%USERPROFILE%\.multica\bin\multica.exe`
Installed binary SHA-256: `E43833C124F9986C0BEB3B323DE856A98F7BCAA0238ADAA093675D5E92D60980`

Official release asset: `multica-cli-0.4.34-windows-amd64.zip`
Official checksum: `a3ac7ca1c48029ebc6c9eb172c8b6572050161836d1c97fd1debda3043f79276`
Downloaded archive checksum: exact match.

The release archive checksum was the authenticity/integrity gate used for this pilot. The extracted Windows executable itself reports no Authenticode signature; this is recorded rather than treated as signed evidence.

## Runtime posture

Detected local provider CLIs: Git, Claude Code, Codex, Qwen Code, Antigravity (`agy`). Gemini CLI is not required by this pilot.

Current Multica state at module build:
- server/setup: not configured
- browser/account auth: not performed
- daemon: STOPPED
- runtime activation: not performed

This module deliberately does not run `multica setup`, login/auth, daemon start, or agent execution.

## Resource safety contract

1. EA_LAB must use `github_repo`, not `local_directory`.
2. EA_LAB resource `ref` must be an exact lowercase 40-hex Git SHA.
3. Dirty `D:\EA_LAB` and all descendants are rejected.
4. `local_directory` is allowed only inside `D:\EA_LAB_CONTROL\multica-pilot\cages` for disposable tests.
5. Multica task state never grants EA_LAB writer/reviewer/integration authority.
6. Before any future bounded write: Lane Registry claim + isolated exact-ref worktree + explicit allowed paths + applicable Harness/evidence gates.
7. No terminal publication, deployment, runtime attachment, trading, LIVE promotion, risk/default change, owner attestation, force push, or history rewrite is authorized.

## TDD and acceptance

RED was captured first: the focused test suite failed because `MulticaPilot.psm1` did not yet exist.

GREEN acceptance requires:
- protected dirty-primary root/descendant refusal
- EA_LAB `local_directory` refusal
- disposable cage allow
- exact SHA GitHub resource allow and symbolic-ref refusal
- all authority flags inert / `NON_AUTHORITATIVE_SIDECAR`
- installed Multica version/hash match
- required provider CLI discovery
- exact base/branch identity
- wrapper read-only status/resource validation
- Multica daemon remains STOPPED
- `git diff --check` PASS
- applicable repository state checks PASS or an explicit environment-only classification

## Post-commit next gate

Local commit does not authorize activation. The next adoption step is an owner-visible browser/setup action followed by disposable-cage provider/A2A tests. Only after cage acceptance should an exact-SHA EA_LAB read-only Multica workspace be opened. Any mutation or runtime use remains separately bounded by normal EA_LAB governance.
