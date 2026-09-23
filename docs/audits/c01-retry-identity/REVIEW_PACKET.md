# C-01 retry process creation identity — author review packet

Owner authorization: new prospective C-01 repair, 2026-09-22. Author: Codex Primary;
requested model/reasoning: GPT-6 Astra / HIGH. Independent acceptance has not occurred.

Base: `5e84dd3e7c662e80e631d7f9e72903d0ba2420c6` (fresh fetch, `origin/master`, remote
HEAD and `refs/heads/master` agreed before source mutation).
Writer: `codex-c01-retry-identity-20260922`.
Worktree: `D:\EA_LAB_CONTROL\w\c01-retry-identity-0922`.
Branch: `codex/c01-retry-identity-20260922`.
Registry inventory found no overlapping active writer; Registry Check returned READY with no
conflicts, followed by one successful Claim. No previous lane was superseded or reset.

## Change and boundary

The prior retry inspector equated a present PID with the historical process and treated any process
query error as absence. It also allowed terminal retries without a recorded creation timestamp.

`inspect_before_retry.ps1` now consumes the accepted Job Identity Provider's exact UTC/100ns
comparison and process-evidence primitives. Those functions and its strict JSON reader were moved
from `capture_job_identity.ps1` into the already shared `_long_job_runner_lib.ps1`. Capture still
validates its exact clean source before loading that helper; its fingerprint covers the shared bytes.
The provider's Python adapter and public schema were not changed.

The shared primitive additionally rejects malformed PID types, missing/future creation timestamps,
incomplete/mismatched process snapshots and invalid current timestamps. Only documented process
absence proves NOT_PRESENT; access failures and exit races fail closed. Retry reports per-role
identity classifications and nullable liveness; unknown evidence is never represented as proven absence.

| Evidence | Retry behavior |
| --- | --- |
| Exact PID and exact creation time still live | REFUSE_RETRY, for every role |
| Same PID, different creation identity | Historical process is not live; existing state gate still applies |
| Recorded identity present and process known absent | Existing state gate still applies |
| Missing/ambiguous identity, duplicate JSON keys, changed job/state bytes | REFUSE_RETRY |
| Postcondition explicitly unconfigured | Only absent PID plus absent timestamp is accepted |
| Configured postcondition without complete identity | REFUSE_RETRY; never infer no descendant from an incomplete launch record |

Existing eligible states remain FAILED, POSTCONDITION_FAILED, TIMED_OUT, CANCELLED, LOST_PROCESS,
and the existing dead POSTCONDITION_RUNNING projection to LOST_PROCESS. STARTING, RUNNING,
CANCEL_REQUESTED, COMPLETE and unknown states do not gain retry eligibility. `job.json` must bind
the same job ID and explicitly describe postcondition configuration. Older incomplete records now refuse.

This is a sampled eligibility answer, not launch authorization or proof of arbitrary process-tree
quiescence/idempotency. In particular, generic dead-RUNNING recovery remains refused even with missing
direct parents and a surviving unrecorded descendant. The exhausted historical
`ct-longjob-lostprocess-retry-repair-20260919` lane remains BLOCKED; none of its rejected recovery
exception, proof system, source edits, or repair budget is reused.

No runtime activation, external dispatcher hookup, scheduler/service change, auto-kill, auto-restart,
push, or canonical state-document mutation. Runner launch, cancellation, timeout and descendant cleanup
implementation bytes are unchanged. Real process control in regressions is confined to the pre-existing
Long Job suite's disposable fixtures. No new acceptance reviewer was dispatched.

## Validation

External evidence: `D:\EA_LAB_CONTROL\evidence\codex-c01-retry-identity-20260922`.
The final external FREEZE receipt binds the exact commit, clean tree, source/evidence hashes and lane.

- `execution_reliability_tests.ps1`: PASS, 5 existing cases plus 46 C-01 cases invoked by the suite.
- `long_job_runner_tests.ps1`: PASS, 22 cases, including real failed-job retry eligibility and live
  child/postcondition descendant refusal with process survival through inspection.
- `run_job_identity_capture_tests.ps1`: PASS, including 42 Python provider tests (one Windows
  symlink-privilege skip; PowerShell reparse coverage passed).
- `run_mobile_report_hub_data_tests.ps1`: PASS, 154 tests, same one privilege-dependent skip.
- `reproduce_pid_reuse.ps1`: base reproduces false historical liveness; candidate correctly identifies
  the same real live PID with recorded creation time one 100ns tick earlier as a different process.
- Windows PowerShell 5.1 parsing: PASS for all six changed/new scripts; `git diff --check`: PASS.
- Process-control source unchanged from base: worker/start/cancel/status, Python watchdog and Job Object.

Commit/freeze blocker: the normal pre-commit hook passed state, protected-set, collision, handoff and
attested-pin checks, but `run_fast_cages.ps1:1980` failed while populating its disposable staged checkout:
`error: unable to write file tools/python312/libcrypto-3.dll`. No commit was created and the hook was not
bypassed. The system drive had 445,648,896 bytes free versus 443,662,314 bytes of tracked tree, before
checkout metadata/test support; this is a likely storage-pressure cause, not a proven DLL-specific RCA.
The inspected recent C-drive snapshot belongs to another task and was not touched. The six source/test
files and this packet remain staged. External `BLOCKED.json` records the staged tree and evidence hashes;
there is no clean frozen candidate HEAD and no READY_FOR_GPT_SCRUTINY claim.

Normal repository hooks must pass before freeze. The routine `make_status.ps1` publication step is
excluded by this owner's explicit no-state-doc-mutation boundary. This packet records author evidence;
the next gate is one independent exact-head GPT Scrutiny job, not author self-approval.
