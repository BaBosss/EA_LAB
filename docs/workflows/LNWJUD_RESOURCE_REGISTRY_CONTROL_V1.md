# lnwjud Resource / Registry Control V1

Status: **SOURCE/OFFLINE CANDIDATE — NOT RUNTIME ACTIVATED**.

Lane: `ct-lnwjud-resource-registry-control-v1-20261006`
Base: `90ad2013babd60673908b3cf72a7a463a9b67c86`

## Purpose

Expose narrow typed control of existing EA_LAB lane/resource state without creating another Registry or lease database. `scripts/lane_registry.ps1` remains the state-transition and conflict authority. Its existing `runtime_lane` field is the resource ownership identity.

## Typed surface

- `get_lane_current(lane_id)` reads one exact lane.
- `get_resource_lease(resource_id)` derives `FREE`, `OWNED`, or `AMBIGUOUS` from active writer lanes whose `runtime_lane` equals the resource.
- `request_resource_lease(...)` moves one exact READY/WAITING/PAUSED lane to RUNNING only after expected state/head and resource availability are proven.
- `release_resource_lease(...)` moves the proven RUNNING owner to WAITING or PAUSED and verifies release by readback.
- `request_lane_transition(...)` permits only a small server allowlist of routine non-review transitions. REVIEW/FROZEN/INTEGRATING entry is excluded and remains under separate review/integration authority.

Mutation requests bind request/idempotency identity, actor, contract SHA256, lane, exact expected state/head, operation, target state, resource where applicable, and creation time. Unknown fields are refused.

## Durability

A qualified durable audit store writes a PREPARED record before Registry mutation. The Registry transition itself still uses exact expected state/head and its own lock/conflict checks. A final immutable receipt is written only after exact Registry/resource readback. Exact replay returns the same final receipt; changed request bytes under the same idempotency key refuse. If acknowledgement is lost after the Registry transition, the PREPARED record may reconcile only when exact head and target post-state/resource proof match; otherwise the request remains blocked as ambiguous.

## Authority boundary

This source milestone performs no runtime activation and grants no generic Registry JSON write, shell, arbitrary PowerShell, process execution, Git integration, MT5, deployment, LIVE, HOLDOUT, trading, risk/default changes, review bypass, or integration bypass.

The future runtime bridge pins the PowerShell executable, `scripts/lane_registry.ps1` path/hash, Registry root and repository root server-side. Client input cannot supply executable paths or command text.

## Acceptance

Source acceptance requires syntax, focused positive and adversarial tests, existing Lane Registry regression where applicable, `git diff --check`, normal hooks, exact source identity, and one Acceptance-Grade Independent Exact-Head Scrutiny under `AGENTS.md`. Runtime publication waits for Job Control operational acceptance and has its own activation/rollback/direct-MCP acceptance milestone.
