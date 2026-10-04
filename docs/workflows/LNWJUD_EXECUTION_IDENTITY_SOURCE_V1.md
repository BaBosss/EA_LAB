# LNWJUD Execution Identity — V2 source successor, not deployed

This retained document path now describes contract LNWJUD-EXECUTION-IDENTITY-READ-V2-20261004.
Owner EA_LAB-MAIN-CT-20260928; DOT is sole CT; author Codex-Primary.
Owner authority Sentinel_8a6aea0d6f208191b186eb13634672e9.
Lane ct-lnwjud-execution-identity-read-v2-20261004.
Base 471a94d6d65fc86882ac7a4bbb882e280edbe98d, tree bb1dbea90d1de8097db9e1b50736722b13211257.
Isolated worktree D:\EA_LAB_CONTROL\w\lnwjud-execution-identity-v2-1004.
Contract SHA256 f4084d2583090020c2ef4efadb1d2472005a2a5a6f962514c10fad268e943fca.

## Preserved lineage and authority

V1 candidate 1c66f77f96a88816c21f957cadd7569778e48feb remains SCRUTINY_FAIL,
with EXEC-ID-001 (missing postcondition proof) and EXEC-ID-002 (comparison before validity).
Both V1 lanes remain BLOCKED/PARKED with their repair/review budgets exhausted.
V2 adopted the exact parent diff SHA256
124ec74c01e31555a1fb8182772311cc49be32e7ee590e1c5f3c92183b5070c2
into a new worktree; no failed history was rewritten.

V2 allocates author1, bounded repair1, independent exact-head review1, and a
targeted recheck only if its repair is used. Local candidate commits use normal
hooks. Workers never integrate, push, deploy or activate endpoints. Deterministic
fixtures alone do not establish runtime acceptance. Real process fixtures and
direct MCP acceptance require later separate DOT admission. Current-client WriteV1
acceptance is already recorded by DOT and is not repeated here.

## Read behavior and proof order

The two strict tools are list_active_executions() and get_execution_identity(job_id).
Existing 14 tools retain byte-identical registration/handler bodies. Clients can
supply only a server-bound job_id, never PID/path/executable/command payloads.

Snapshot records supply bounded inventory and identity anchors only. Per-request
reads recheck durable job/state/result/heartbeat and the selected Registry lane,
then perform the fixed read-only process observation. Registry RUNNING, cached
snapshots, and heartbeat updates are not live proof or progress.

All applicable expected/current fields must be valid before any disagreement
escapes: job/lane IDs, source SHA, absolute worktree/executable paths, PID,
creation, check/image timestamps and result bindings. Missing, malformed,
unobservable, stale or future evidence returns UNKNOWN. Even a valid disagreement
elsewhere cannot override an unproven applicable field. IDENTITY_MISMATCH is
reserved for two valid current identities that materially disagree.

States: PROVEN_RUNNING, PROVEN_TERMINAL, QUEUED, WAITING_RESOURCE, BLOCKED,
UNKNOWN, IDENTITY_MISMATCH. Running proof requires current runner plus active
stage PID/creation/image. A running postcondition also requires child absence.
A configured postcondition is applicable to terminal proof even when its PID or
creation is missing. Each applicable terminal stage needs current qualified
absence evidence plus a bound terminal result; missing postcondition evidence
returns UNKNOWN/POSTCONDITION_IDENTITY_UNPROVEN even with integer exit codes.
A terminal outcome is not a claim of successful work.

The active list excludes only PROVEN_TERMINAL. UNKNOWN and mismatch entries stay
visible. Valid job IDs with malformed inventory source bindings remain UNKNOWN
without invoking an observer. Invalid/unaddressable job IDs cannot be queried.
The list is explicitly incomplete: server inventory cap1000, observation cap10,
unobserved count reported. Each observation has a 10-second, 1-MiB bound.

## Reused observer and limitations

The fixed observer reuses scripts/long_jobs/_long_job_runner_lib.ps1
Get-IdentityEvidence and strict JSON parser, pinned SHA256
13fc33f017fabaceb7aea302497adddecaf1b39d7871864ddbe49cc7dcaaceef.
Accepted provider ancestry includes bc2e4afe09ca3309b091a032c020140ea1c5a858.
No unintegrated runner repair, watcher, scheduler, Registry, or service is added.
Source import/registration never queries processes. After separately authorized
deployment, the fixed short-lived inspection shell reads image between existing
identity checks; it does not start or stop observed executions.

Freshness means process/image checks within this request; creation comparison
retains 100ns precision. Future heartbeat is UNKNOWN with null age, never clamped.
Heartbeat is not progress. Argument hash is labeled runner_argument_hash, not EA
input proof. Terminal/install identity remains null without evidence.

## Deterministic and hash gates

The source suite preserves legacy missing-field fixtures, all 14 handler
differentials/strict schemas, synthetic live/terminal cases and adversarial
identity cases. V2 adds both review findings, unknown-first mixed cases,
postcondition applicability/absence and active-list retention. Fixture
PROVEN_RUNNING is synthetic; no live observer or gateway activation is tested.

The verifier retains historical A2 and V1 profile pins/refusals. DOT explicitly
approved the additional verifier path for a V2 profile binding this contract,
canonical base/tree, failed-parent candidate/manifest and exact 17-file scope.
Manifest self-exclusion, strict UTF8, file kinds, path/size/hash checks and
unknown-profile refusal remain in force. Historical acceptance is not inferred
from profile compatibility.

Evidence and budget receipts live outside source under
D:\EA_LAB_CONTROL\evidence\lnwjud-execution-identity-v2-20261004.
Source acceptance requires all gates plus a separate clean exact-head GPT Scrutiny.
Job Control is a later distinct milestone; no Job Control implementation or launch
authority is supplied by this document.
