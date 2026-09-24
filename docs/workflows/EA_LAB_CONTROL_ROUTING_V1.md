# EA_LAB Control Routing V1

Status: **SOURCE-ONLY CANDIDATE / PASSIVE / NOT ACTIVATED / REVIEW REQUIRED**.

## Purpose

Control Routing V1 is a bounded decision/routing module for the existing EA_LAB
control plane. It is not a second Control Tower, Registry, queue, Monitor, scheduler,
service, or source of truth. Its intended direct consumer is the existing Main Control
Tower after exact-head acceptance.

The core rule is simple: when deterministic software can prove a fact, use
deterministic software rather than a model. Model recommendations exist only for
residual implementation or reasoning work.

## Existing authorities remain unchanged

V1 does not replace or mutate:

- PROJECT_STATE, taskboards, or the Lane Registry;
- tools/local_control_collector or canonical Long Job status/retry interfaces;
- tools/mobile_report_hub or the existing owner-facing Monitor;
- tools/codex_budget or its inactive NORMAL/ECONOMY recommendation path;
- required exact-head GPT Scrutiny;
- any MT5, risk, deployment, trading, LIVE, HOLDOUT, Candidate, or owner hard stop.

The rejected Codex Budget Mode Hookup lineage remains rejected. This module neither
repairs nor bypasses BMH-004.

## Routing contract

The closed V1 task classes are:

| Work type | Advisory lane | Advisory model | Reasoning |
| --- | --- | --- | --- |
| DETERMINISTIC | LOCAL_DETERMINISTIC | none | none |
| MECHANICAL | LUNA_LOW | gpt-6-luna | low |
| BOUNDED | LUNA_MEDIUM | gpt-6-luna | medium |
| COMPLEX | LUNA_HIGH | gpt-6-luna | high |
| HARD | SOL_HIGH | gpt-6-sol | high |

software_can_prove=true always chooses the deterministic lane. Declared owner hard
stops produce OWNER_DECISION_REQUIRED and no model. The closed risk flags
ARCHITECTURE_UNCERTAINTY, CORE_EXECUTION, and SECURITY, or two prior failed
implementation attempts, recommend SOL_HIGH.

These are recommendations only. V1 launches no model, installs no profile, changes
no Codex personalization, and makes no subscription, quota, or cost claim.

Before any later dispatcher uses a model recommendation, it must independently verify
the installed client, authentication, model availability, and exact task authority.
A recommendation is not dispatch authority.

## Deterministic decision boundary

decision.py evaluates only bounded state supplied by its caller. Precedence is
fail-closed:

Validation occurs before decisions. A FAILED process requires a required FAIL gate
and the existing non-NONE failure classification. An OWNER_DECISION_REQUIRED route
with owner_hard_stop=false is inconsistent and refuses. A newly asserted hard stop
still takes precedence over an earlier ordinary route recommendation.

deterministic_gates must include at least one required gate. Missing, empty, or
optional-only evidence refuses, even when review_state=PASS. V1 has no qualified
contract-backed non-applicability exception; callers cannot infer one from an empty
list. This minimum does not independently establish a complete required-gate inventory.

1. unapproved owner hard stop -> OWNER_DECISION_REQUIRED;
2. writer conflict / waiting dependency / running process -> WAIT;
3. blocked dependency, environment/contract failure, or exhausted repair -> BLOCK;
4. unknown required truth -> VERIFY_MORE;
5. repairable code failure -> RETRY, with repeated failure -> ESCALATE;
6. required review not yet passed -> REVIEW;
7. all required deterministic gates plus required review pass -> COMPLETE.

For combined gate failures, environment/contract/unknown failure classifications and
exhausted repair budgets block before unknown process or required-gate truth is
considered. With repair available, required UNKNOWN evidence returns VERIFY_MORE
before either code RETRY or repeated-failure ESCALATE, regardless of gate order.
Optional UNKNOWN evidence does not stand in for required UNKNOWN evidence.

COMPLETE means only SOURCE_SCOPE_CANDIDATE_NOT_CANONICAL. It is never evidence of
merge, push, deployment, runtime health, research validity, or trading authority.

## Jev boundary

V1 contains only a shadow envelope. It performs no HTTP request and has no live
TypeSafe/Jev adapter. TYPESAFE_API_KEY is referenced only by environment-variable
name; the module exposes at most a boolean auth_present and never emits the value.

Shadow output always reports transport_status=DISABLED_NO_LIVE_ADAPTER,
authority_ceiling=SHADOW_ONLY_NO_CONTROL_AUTHORITY, activation=false, and
canonical=false.

A future live Jev adapter requires a separate frozen contract, exact API/schema
binding, credential handling, calibration/evaluation, deterministic fallbacks, and
acceptance review. Jev confidence may never override compiler/tests, owner hard stops,
repair budgets, review requirements, or other canonical evidence.

## Integrity binding

implementation_manifest.json byte-binds every file executed by the V1 CLI plus the
policy. integrity.py rejects both an omitted or extra runtime path and a digest
mismatch. This specifically prevents an acceptance manifest from silently omitting
an executed router component.

The manifest is not a cryptographic trust root by itself. Accepted Git identity and
exact-head review remain authoritative. The verifier emits the manifest SHA256 so
review evidence can bind the exact manifest bytes.

## CLI

Use the repository portable Python from an isolated worktree. The available commands
are:

- python tools/control_routing_v1/cli.py verify-integrity
- python tools/control_routing_v1/cli.py route --input task.json
- python tools/control_routing_v1/cli.py decide --input decision.json
- python tools/control_routing_v1/cli.py jev-shadow --input shadow.json

Every non-integrity command verifies the implementation manifest first and refuses on
mismatch. Inputs are closed objects; unknown fields refuse. Output is stdout-only.
Duplicate JSON member names refuse at every input object level, including objects
inside arrays and equivalent escaped names. Repeated identical values also refuse.
Refusals return native exit 2 and stderr beginning REFUSED, with no stdout result.

## Acceptance boundary

Author completion requires focused tests, pycompile, manifest verification,
git diff --check, a clean committed exact HEAD, and a handoff. This source must then
receive a separate read-only exact-head GPT Scrutiny before Main Control Tower
integration. No source mutation is permitted by the reviewer.

This milestone deliberately stops before runtime activation, Monitor wiring, live Jev
transport, model dispatch, scheduler/service installation, or canonical push.

### Prospective Repair1 (2026-09-24)

The exact review of 97900d90cff03b6c9106fc5c796ac8060497e610 remains
SCRUTINY_BLOCKED / HIGH / BLOCK_INTEGRATION. The existing owner
EA_LAB-CONTROL-ROUTING-20260924 prospectively allocated one bounded CR1-CR4 repair
under the same ct-control-routing-v1-20260924 lane. Repair1 is 1/1 USED; this does
not reset any historical budget or imply another repair.

For this delivery the worker leaves authored files and actual deterministic gate
logs unstaged in the bound repair worktree. CT runs normal hooks and commits/freezes
the exact source, then obtains the one targeted independent recheck. Integration
requires acceptance and current-canonical drift/reuse proof. Source acceptance
grants no runtime activation. The original author and review worktrees are preserved.
