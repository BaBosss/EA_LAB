# EA_LAB Autonomous Orchestrator V1 — source-only DRY_RUN

**Status:** Proposed T1 read-only source, NOT source acceptance, installed JobControl, a scheduler, generic job dispatch, or 24/7 autonomy. The existing Main Control Tower owns admission, review and normal integration. The Orchestrator never becomes a CT, Registry, Monitor, runner or provider authority.

## Purpose and exact source

- `tools/lnwjud/job_control_runtime_v1/orchestrator_read_only_reconciler.cjs` exports pure `reconcile(input)`. It makes zero subprocess/network/provider/filesystem/Registry/scheduler calls and does not cache state.
- The tests are `test_orchestrator_read_only_reconciler.cjs`; run with `node --test`. This is an **offline deterministic classifier**, not live dispatch.
- Existing sources remain authoritative: `AGENTS.md §1.4`, Lane Registry, `scripts/long_jobs`, `tools/lnwjud/job_control_v1`, `tools/lnwjud/job_control_runtime_v1`, `tools/ea_lab_harness`, `skills/ea-lab-harness/SKILL.md`.
- The Policy Amendment V1 file `EA_LAB_AUTONOMOUS_ORCHESTRATION_POLICY_DRAFT_20261011.md` with expected SHA256 `5d18f319526da30a3df56dc1647c624191cf6e37b0a603d8b38b01951ea9c2ca` was not found in bounded BaBoss checks. It is DRAFT and **does not** add authority.

## Input and output contract

Top-level schema `EA_LAB_ORCHESTRATOR_READ_ONLY_INPUT_V1`, exact fields: `schema, now_utc, source, registry, leases, jobs, tasks`. Snapshot `source` requires the independently verified canonical HEAD/TREE, fetch `origin_master`, `ls_remote`, checkout HEAD/TREE, clean=true and UTC capture time (fresh <= 15 minutes). Exact `registry` fields: validated=true, single Main CT ID and ordered lane owner/state/worktree/critical paths. Each task has immutable identity (`task_id`, `lane_id`, `owner`, `idempotency_key`, `source_head`, `source_tree`, `worktree`), stage, known non-T3 action, original remaining repair budget, resources, DAG dependency IDs, distinct author/reviewer, optional provider authentication and explicit cost cap.

A resource lease needs the same owner, unexpired UTC expiry, unique resource, lease ID and SHA256 readback over its exact binding payload. A live job needs bound job/task/lane/source and positive PID, creation UTC, executable path, worktree and heartbeat. Terminal evidence additionally requires exit 0, explicit postcondition PASS and SHA256-bound exact job/task/lane/source receipt. Review requires accepted hash-bound positive+negative tests and one independent exact-source SCRUTINY_PASS record. A receipt SHA256 checks byte-integrity only: **it does not authenticate the producer**.

Output schema `EA_LAB_ORCHESTRATOR_READ_ONLY_DECISION_V1` contains deterministic per-task `{task_id,status,reason}` and status counts. Valid decisions: `READY`, `BLOCKED`, `WAITING_RESOURCE`, `UNKNOWN`, `PROVEN_TERMINAL`, `READY_FOR_REVIEW`, `READY_FOR_CT_INTEGRATION`. These are read-only **eligibility observations**, not persisted Registry/job state transitions or authority for action. In particular, `READY` never submits a job. `READY_FOR_CT_INTEGRATION` never pushes.

## Preflight/admission and dependency semantics

1. Trusted existing adapter obtains canonical Git, Registry Validate/Audit, owner+critical paths, worktree identity, live process+resource leases and receipt readback **independently**. Unqualified caller JSON is not live authority.
2. Fail-closed classification: unknown/stale/future/unbound/malformed/contradictory source and process evidence remains UNKNOWN or BLOCKED; no guessed liveness or free lease. Exclusive resource overlap and active writer path collisions WAITING_RESOURCE. Duplicate task/idempotency blocks both; duplicate concurrent resource requests wait rather than arbitrary first-wins.
3. Child work becomes eligible only on **PROVEN_TERMINAL** dependency postcondition; a blocked SYSTEM task does not prevent independent EA research when no resource/dependency overlap.
4. No automatic retry. An explicit `RETRY` action is blocked once `repair_remaining=0`; original Budget/Registry evidence must be pinned by adapter.
5. `stage=REVIEW` requires hash-bound positive and negative deterministic tests. `stage=INTEGRATE` also requires an independent reviewer identity and exact frozen source bytes. Main CT independently performs Git/owner/lease/normal hooks/FF before considering integration.
6. Optional provider route requires explicitly named provider/model, VERIFIED authentication observation within the last hour, a positive finite ceiling and estimated cost within that ceiling. This source does not call Gemini, Qwen, Hermes, Claude or any API and cannot know real quota; the trusted adapter must check the actual route, quota, account and billing out-of-band.

## Security, limits and negative cases

Pure JS object inputs and SHA256 of canonical JSON data for fixtures. No parser is provided to ingest hostile raw JSON: production boundary MUST use the existing JobControl strict parser, rejecting duplicate keys, unknown schema, malformed UTF-8, untrusted prototypes and unsafe numbers before calling reconciler. Type/shape/date mistakes are rejected where checked; **do not treat this prototype as comprehensive arbitrary-JSON sanitation or credential attestation**. Tests cover stale/future sources; mismatched HEAD/TREE; dirty/wrong worktree; missing/foreign/expired/forged leases; unknown PID/creation; missing/forged terminal postcondition; zero repair budget; duplicate job/key/resource; cross-lane isolation; interrupted/repeat observation; source/review identity conflict; tampered hash/time/schema; T3 denial and cyclic/failed DAG.

**Known integration boundaries:** The current lnwjud plugin exposes SELFTEST-only JobControl, not general dispatcher API. The input adapter, durable Registry source of truth, lease authenticity, hardware/process identity, real live bindings, exact provider cost ceiling, runtime security/credentials, executor dispatch, installed scheduler and hourly notifications are all **out of scope and unaccepted**. No passive monitoring or unattended execution has been installed.

## T0–T2 gate and T3 activation freeze

T1: single scoped source owner; test-first RED then GREEN, full impacted JobControl/adaptor fault suites, Harness and negative cases, original failures preserved. T2: normal hooks, exact candidate commit TREE, procedurally independent one-shot exact-head scrutiny; Main CT only FF-integrates after remote/Registry recheck. A previous offline pass is not a runtime PASS.

**T3 is separately owner gated:** exact installed runtime executable/script SHA, task identity and effective privileged principal, the one incumbent publisher/gateway/Monitor owner, exclusive lease, signed/bound durable reader adapter, injection controls, credential isolation, provider + dollar ceilings, security tests, process PID/start/executable/status, idempotent checkpoint/CAS/readback, original rollback manifest, dry-run positive/negative/concurrency/anti-tamper tests, authenticated user interface and owner-approved runtime switch. MT5/optimizer, HOLDOUT, Factory, Real Submit, risk/defaults and LIVE trading remain forbidden. Never turn on Hermes cron/gateway, a new task, paid fallback or deployment based on source PASS.

## Reporting

The existing CT writes durable evidence with HEAD/TREE, file hashes, original failed gates, rejected negatives, exact command/EXIT/log SHA, one independent scrutiny binding, integration/post-push verified SHA, Registry status and unchanged historical WIP. A source closeout can say SOURCE_ACCEPTED only after these gates; it cannot say OPERATIONAL_AUTONOMY or RUNTIME_ACCEPTED.
