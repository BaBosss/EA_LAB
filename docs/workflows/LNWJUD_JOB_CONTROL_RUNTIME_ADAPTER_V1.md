# lnwjud Job Control Production Adapter V1

Status: **SOURCE/OFFLINE CANDIDATE — NOT RUNTIME ACTIVATED**.

Lane: `ct-lnwjud-job-control-runtime-adapter-v1-20261006`
Base: `90ad2013babd60673908b3cf72a7a463a9b67c86`
External contract: `D:\EA_LAB_CONTROL\evidence\lnwjud-job-control-runtime-adapter-v1-20261006\CONTRACT.json`.

## Purpose

This successor preserves the accepted `tools/lnwjud/job_control_v1` synthetic/offline core byte-for-byte and adds a separate production-shaped adapter. It is the source seam between typed lnwjud Job Control intent and the existing EA_LAB Long Job Runner. This milestone does not publish a new MCP tool, launch a real process from the adapter tests, alter Registry state, activate a scheduler/service, touch MT5, or grant deployment/trading authority.

## Client boundary

`LNWJUD_JOB_CONTROL_RUNTIME_REQUEST_V1` contains only:

- request/idempotency/operation identity;
- lane + contract identity and exact contract SHA-256;
- exact source head/tree/config identity;
- stage + stage index;
- checkpoint/parent receipt/target logical job identity;
- UTC creation time.

The client cannot provide an executable, shell text, argument list, worktree path, JobsRoot, PID, provider command, Registry operation, runtime resource, postcondition executable, or arbitrary filesystem target. Unknown or extra keys fail closed before authoritative state mutation.

## Server-side binding and launch catalog

The trusted server environment owns lane/contract/source/worktree identity, resource owner, host, direct consumer, admitted stage plan, and `stage -> {profile_id, profile_sha256}` mapping. The Windows bridge owns the matching immutable launch catalog. A profile is accepted only when its SHA-256 covers its complete server-side payload and stage/source/base identities match the request binding.

The bridge always targets the existing canonical runner entrypoint:

`scripts/long_jobs/start_long_job.ps1`

A profile may contain the already-approved server-side target executable/arguments and postcondition inputs required by that exact contract, but those values are never supplied by the client. An unknown, drifted, wrong-stage, or wrong-source profile is refused before the adapter writes a new receipt.

## Durable state

The adapter requires `EXCLUSIVE_LOCK_CAS_DURABLE_READBACK` storage. The Windows implementation stores `state.json` plus a revision/hash anchor under a server-selected absolute root. Every mutation is serialized; compare-and-swap verifies the previous authoritative hash; state and anchor are read back before execution is allowed to continue.

Exact request bytes are retained as base64 in the durable store. Same idempotency key + same exact bytes reuses the immutable receipt. Same key + changed bytes is `IDEMPOTENCY_DRIFT`.

## Dispatch / lost acknowledgement

For submit/resume the adapter writes and reads back the durable request/receipt, then writes and reads back `DISPATCH_INTENT`/`RESUME_INTENT`, before calling the typed bridge. Each stage has one deterministic Long Job Runner job ID. If actuation succeeds but the acknowledgement is lost, an exact replay first asks the bridge for that deterministic existing job identity. Matching durable identity is adopted; the stage is never redispatched. Identity drift is a hard refusal.

A second independent submit for the same bound lane/contract is refused as `DUPLICATE_EXECUTION`.

## Execution truth

Execution Identity V1/V2 is the execution-state authority. Long Job Runner status is used only for durable runner/result/checkpoint facts. Registry `RUNNING`, PID alone, heartbeat freshness, or runner `RUNNING` cannot produce `PROVEN_RUNNING`.

Missing, stale, future, or unavailable Execution Identity evidence yields `UNKNOWN`. `IDENTITY_MISMATCH` remains explicit. A stage is complete only when Execution Identity says `PROVEN_TERMINAL`, Long Job Runner says `COMPLETE`, and a typed checkpoint SHA-256 exists.

## Pause / resume

`request_pause_after_stage` does not kill the active process. It prevents progression after the current stage. Once the current stage is proven terminal + complete, protocol state becomes `PAUSED_AFTER_STAGE`.

`resume_existing_job` requires the latest pause receipt/checkpoint and exactly the next admitted stage. It creates exactly one new deterministic Long Job Runner job for that stage. Completed stages are not replayed.

## Source/offline evidence

Current author gates on this candidate lineage:

- runtime adapter positive: **18/18 PASS**;
- runtime adapter negative/adversarial: **36/36 PASS**;
- accepted Job Control V1 positive regression: **24/24 PASS**;
- accepted Job Control V1 fault/negative regression: **279/279 PASS**;
- Node syntax checks: PASS for all five source/test files;
- `git diff --check`: PASS;
- accepted `tools/lnwjud/job_control_v1` bytes vs `origin/master`: unchanged;
- real process launches from adapter tests: **0**;
- runtime activation: **false**.

These are source/offline results only. Full precommit TPL evidence and the required independent exact-head GPT Scrutiny remain gates before source integration.

## Activation boundary

Source integration does not activate Job Control. Runtime publication requires a separate activation/rollback contract and a fresh owner-facing direct MCP acceptance of Execution Identity. The active ChatGPT client must see and successfully exercise the Execution Identity tools; a local server catalogue alone is not direct-client acceptance.

No Registry mutation from client requests, generic shell/process API, arbitrary command/path endpoint, new scheduler/daemon/watchdog, MT5 action, HOLDOUT spend, deployment, trading, LIVE, or risk/default change is granted by this adapter.
