# lnwjud Job Control V1 — source/offline contract

## Status and authority ceiling

This is an **inert source/offline author candidate**, not independent acceptance, operational acceptance, or permission to activate runtime. The five typed interfaces below execute only against explicitly labelled synthetic fixtures. No production adapter, endpoint, queue, service, scheduler, process-control API, worker dispatch, provider call, MT5 action, LIVE/DEMO action, HOLDOUT use, or risk/default change is supplied.

Contract: `LNWJUD-JOB-CONTROL-V1-SOURCE-OFFLINE-20261004`.
Existing lane: `ct-lnwjud-job-control-v1-20261004`; DOT remains the sole Main Control Tower.
The admitted base is `872524af2444e27a343bce76afbf81770147290b`. The prior incomplete checkpoint was `a9a69935d2a49ffe355ec9fe06f0bfa00c6b90c4`, tree `23b7ff18c3a0e1612c2544d951ffbf4b8c4fa267`. That commit contained draft modules, not behavioral acceptance.

The external contract and evidence owner is `D:\EA_LAB_CONTROL\evidence\lnwjud-job-control-v1-20261004`. `CONTRACT.json` SHA256 is `a70853834b9bacbe175d4fc1073e7c066dc8cf4341741357df3280d855d7fd7b`. The original release receipt SHA256 is `13e7f5fe2e731a50001d4e21a78d11d5ead572bcfe51e62964c0809bf83dd74c`. These remain historical evidence, not a live-state substitute. The owner-direct resume receipt records the supported lifecycle result and readback separately.

The allowed tracked surface is exactly:

- `tools/lnwjud/job_control_v1/job_control.cjs`
- `tools/lnwjud/job_control_v1/request_contract.cjs`
- `tools/lnwjud/job_control_v1/test_job_control.cjs`
- `tools/lnwjud/job_control_v1/test_job_control_faults.cjs`
- this document

No registry schema, runner, gateway, server tool manifest, runtime pin, installation, or provider configuration is changed. The existing isolated worktree remains authoritative for the candidate. The dirty primary checkout and the lnwjud runtime workspace are not author surfaces.

## Relationship to existing infrastructure

The existing Lane Registry lifecycle remains the only resource/owner admission mechanism. Real lifecycle changes use `scripts/lane_registry.ps1`; this library has no Registry writer. It must not become another control tower or lane registry.

The existing runner family remains `scripts/long_jobs/start_long_job.ps1`, `worker_long_job.ps1`, and `status_long_job.ps1`, with atomic-write and identity primitives in `_long_job_runner_lib.ps1`. The fixture storage code deliberately ports the existing CreateNew + flush + atomic replacement pattern; it does not invoke a real runner. Existing bootstrap, provider-preflight, worker launch and Job Identity Provider surfaces are unchanged. Their production schemas are not extended here.

The facade separates a frozen request, durable protocol state, and an observed execution identity. Its `environment` and `observer` objects are synthetic stand-ins for future source-bound reads of those existing owners. No live catalogue mapper, filesystem identity probe, real runner wrapper, or production storage adapter is shipped by this scope. A future adapter would require its own bounded admission and acceptance; the fixture is not such an adapter.

## Typed interface boundary

`createJobControl` is an internal synchronous library constructor used by the test harness. Only trusted test code can supply storage, catalogue observations, or fixture callbacks. A `kind` label is an explicit test ceiling, **not authentication for arbitrary host JavaScript**. Untrusted JSON cannot supply adapters, callbacks, shell strings, storage roots or paths to execute. No API surface mounts this library for a remote caller.

| Interface | Input | Effect within the synthetic fixture |
|---|---|---|
| `submit_existing_contract_job` | Bounded UTF-8 request bytes for an admitted contract | Validate/freeze; reserve and persist an immutable receipt; read it back; persist dispatch intent; increment one fixture counter at most. |
| `get_job_current` | An existing opaque receipt/idempotency key | Read-only receipt and protocol/identity observation. It never launches, repairs or reconciles a process. |
| `adopt_existing_job` | Request bytes binding an existing job, latest receipt and exact checkpoint | Record provenance after matching current evidence. A proven lost ACK can be reconciled; no execution or budget is reset. |
| `request_pause_after_stage` | Request bytes binding the current stage and checkpoint | Persist pause intent. The current synthetic stage remains running until an exact pause ACK is observed. |
| `resume_existing_job` | Request bytes binding a qualified paused checkpoint and the next stage | Persist a same-job resume intent and next-stage identity atomically, then at most one fixture dispatch. Completed stages cannot be rerun. |

The methods accept no generic shell operation. `get_job_current` takes an opaque receipt reference, not a filesystem path or PID. All other operations require `LNWJUD_JOB_CONTROL_REQUEST_V1`; an operation must match the called method.

## Frozen request and catalogue binding

A request includes `request_id`, `idempotency_key`, operation and precise UTC `created_utc`, together with these mandatory bindings:

| Binding | Required meaning |
|---|---|
| `lane_id`, `contract_id`, `contract_sha256` | Exact admitted lane/contract and hash of the supplied immutable contract bytes. |
| `source` | Exact commit, tree and configuration SHA256. |
| `worktree` | Exact absolute Windows worktree, branch, Git common-root and identity-evidence SHA256. |
| `allowlisted_paths` | Exact frozen relative paths; no wildcard, traversal, alternate stream, device name or case-insensitive duplicate. |
| `resource_owner`, `runtime_resource`, `host_id` | Incumbent resource identity; runtime is explicitly `NOT_APPLICABLE_OFFLINE`. |
| `acceptance_criteria`, `direct_consumer`, `route` | Nonempty admitted criteria, consumer identity and the exact synthetic existing-runner route. |
| `budget` | Frozen approved repair/retry ceilings. Current remaining amounts must come from the trusted ledger, not a client reset. |
| `checkpoint` | Stage/index, checkpoint digest, parent receipt digest and target job. Submit starts at index zero with no parent or target. |

Every client-supplied binding must exactly equal the trusted catalogue observation. A syntactically valid value is not authority. The fixture catalogue has a separate clean-worktree fact, verified path-identity fact, resource availability, immutable binding-evidence hash, stage plan, budget availability and remaining-budget observations. Missing or ambiguous facts refuse admission. The core does not itself inspect real Windows paths or infer cleanliness from strings.

The stage-plan digest is pinned in receipts; later catalogue changes cannot append, rename or replace stages of an existing job. Remaining-budget observations are also durable and monotone: subsequent receipts cannot replenish amounts already observed as spent. The original allocation is preserved in every receipt. Cooperative progression to the next stage is not an automatic retry, and this facade never grants or resets a retry allocation.

Parsing is bounded to 65,536 request bytes and a maximum nesting depth. It rejects malformed UTF-8, a BOM, duplicate keys including escaped duplicates, unsafe prototype keys, unknown/missing fields, non-finite/unsafe/non-integer numbers and negative zero. Timestamps are calendar-validated UTC `Z` strings with up to seven fractional digits and exact 100ns comparisons. Non-UTC offsets are refused rather than guessed. Observation time must bracket the request and current trusted time; no arbitrary freshness TTL is invented.

## Durable receipt and idempotency

The order is **validate → freeze exact bytes → durable PREPARED receipt → readback → durable dispatch intent → readback → fixture invocation**. The store's same exclusive lock protects admission, key reservation, expected-hash comparison, revision update and readback. Atomic replacement alone is not the concurrency policy.

`LNWJUD_JOB_CONTROL_RECEIPT_V1` records the exact request digest/length, internally derived logical request location, stable job ID, full frozen identity and checkpoint, operation, prepared sequence, parent receipt hash, binding/observation evidence hashes, stage-plan hash, remaining-budget observation, timestamps, and `PREPARED_OFFLINE_INTENT`. The exact original request bytes are retained in the same durable fixture state; they are not reserialized as idempotency authority. `fixture-state://requests/<key>/bytes_base64` is a logical location inside that record, not an external file supplied by the caller.

The state contains a revision and previous-state hash. A separate trusted fixture anchor provides the expected current digest and minimum revision. Receipt digests, parent links, job references, latest sequence, plan, stage and budget provenance are revalidated on read. A changed current-state digest at the same revision is not silently accepted.

Same key plus identical bytes returns the same immutable receipt and job identity while current admission remains valid. The current observation can change. Same key plus changed bytes, including whitespace or key ordering, refuses without authoritative mutation. A new key cannot create another execution for the same admitted lane/contract. Reusing a request ID under another key also refuses.

After lost ACK or restart, an existing dispatch/resume intent is reconciled before any retry decision. A fresh matching observation can bind the already-existing execution, including direct adoption after lost ACK. Without that proof, the result remains `RECONCILE_REQUIRED` and `UNKNOWN`; the facade does not invoke the fixture again. A PREPARED request with no dispatch intent can continue only after rereading its exact durable identity and proving no existing execution.

The fixture uses a fresh marked directory under `os.tmpdir()`. All state, lock, anchor and counter paths are internally derived under that directory. An orphan exclusive lock is never stolen. An orphan temporary write remains `STORAGE_RECONCILE_REQUIRED`; state/anchor disagreement remains `STALE_RECEIPT`. No automatic cleanup, migration or repair is performed by the core. Test teardown removes only its own marked fixture directory.

## Current state, pause and resume

Protocol state is not execution identity. Results expose `protocol_state`, `execution_state`, `durable_runner_state`, checkpoint and `progress` separately. Missing, malformed, stale, future-dated, hash-mismatched or differently bound execution observations produce `UNKNOWN`, not zero, running, terminal success or PASS. Structurally invalid durable state is a typed refusal rather than a fabricated current result.

`PROVEN_RUNNING` and `PROVEN_TERMINAL` in these tests mean **qualified synthetic observations only**. Terminal `FAILED`, `CANCELLED`, `TIMED_OUT` and `POSTCONDITION_FAILED` remain distinct from `SUCCEEDED`. Every result carries `evidence_kind: SYNTHETIC_FIXTURE` and `runtime_supported: false`.

A pause request produces `PAUSE_REQUESTED`, not an immediate stopped worker. `PAUSED_AFTER_STAGE` requires the qualified synthetic consumer, matching job/binding/stage/current evidence, successful terminal stage completion, an exact checkpoint, and an ACK naming the precise pause request digest. Bare terminal state, another pause request's ACK, failed completion or an old observer cannot qualify a pause. Adoption during a pause retains that original ACK identity.

Resume binds the latest receipt and acknowledged checkpoint and moves only to the next declared incomplete stage of the same job. Request + next stage + resume intent are persisted in one atomic update. A crash after that update but before the fixture invocation is deliberately reconcile-only, not replayable PREPARED work. This conservative ambiguity can block progress; it cannot justify an unsafe second launch.

Real runner stage pause/resume is **`UNSUPPORTED_STAGE_CONSUMER`**. Synthetic fixture success does not qualify real cooperative stop, process liveness, native concurrency, provider routing, server callability or operating-system durability. Execution Identity V2 server tool count does not establish direct ChatGPT acceptance. No Job Control runtime follows from this source candidate or a future source-only PASS.

## Deterministic and adversarial evidence

Run from the existing isolated worktree with the existing Node installation:

```text
node --check tools/lnwjud/job_control_v1/request_contract.cjs
node --check tools/lnwjud/job_control_v1/job_control.cjs
node --check tools/lnwjud/job_control_v1/test_job_control.cjs
node --check tools/lnwjud/job_control_v1/test_job_control_faults.cjs
node tools/lnwjud/job_control_v1/test_job_control.cjs
node tools/lnwjud/job_control_v1/test_job_control_faults.cjs
git diff --check
```

The positive suite covers frozen bindings, durable ordering, exact-byte replay, restart readback, overlapping same-key admission, lost-ACK reconciliation and adoption, read-only current state, unknown identity, typed terminal outcomes, pause ACK identity, sequential same-job resume, budget preservation and the runtime ceiling. Overlap is a deterministic interleaving of two library/store instances under the same real fixture file lock, **not native production-concurrency qualification**.

The fault suite names every required negative category: unknown lane; wrong source; dirty worktree; missing contract; mismatched contract; idempotency drift; leased resource; duplicate execution; stale receipt; malformed state; future timestamp; missing acceptance; disallowed provider; generic shell; arbitrary path. Additional cases cover strict bytes, budget and stage-plan regression, malformed environment, unavailable/mismatched identity, failed pause/resume, CAS conflict, torn state, readback mismatch, orphan locks and unobservable launch gaps.

Cut-point exceptions cover reservation, temporary write, replacement, anchor update, PREPARED, intent, readback, fixture invocation, ACK and resume reconciliation. A simulated exception/reconstructed library instance is not a machine power-cut test. File flush and atomic replacement in the fixture do not certify production filesystem crash durability. Unknown intervals are refused rather than called successful.

Refusal tests compare authoritative fixture state/anchor/counter bytes before and after the refused operation, and check that the dispatch count did not change. Fault tests distinguish committed intent from pre-intent absence and prove at-most-once invocation through each allowed recovery. They do not delete evidence to force a retry.

Normal repository pre-commit and commit-msg hooks must still run. Do not alter assertions, bypass hooks, use `--no-verify`, replace guard providers or relax trust settings. Exact-allowlist and clean-tree checks apply independently of test success. Existing baseline files and governance are unchanged.

## Budget, freeze and DOT intake

The original allocation remains author 1 / 90 minutes, repair 1 / 30 minutes, independent read-only review 1 / 20 minutes, and one conditional targeted recheck / 15 minutes under the original contract. The prior durable author spend was 8.1735 minutes. Resumed active time is cumulative; paused wall time is not silently charged as author execution, and no allocation is reset. Synthetic request budget values are test data, not additional worker or retry authority.

The original author completion remains incomplete until syntax, positive/fault/negative tests, exact allowlist, diff-check and normal hooks are green. Preserve every earlier attempt log and the original denial/checkpoint evidence. A commit is not acceptance. Freeze the exact clean candidate commit/tree, file manifest and evidence hashes, then provide one source-bound packet to DOT. DOT alone schedules the independent read-only exact-head review within WIP <= 4 and the remaining budget. The author must not self-approve or launch another reviewer.

The packet must state actual canonical/source identities, lifecycle and owner resource, deterministic results, remaining cumulative budget, review status, blockers and one next action. Review/repair/recheck receipts must remain exact-head and original-budget bound. This source lane performs no worker push or runtime activation.
