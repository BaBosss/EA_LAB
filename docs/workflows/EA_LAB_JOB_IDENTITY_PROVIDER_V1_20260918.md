# EA_LAB Job Identity Provider V1

Date: 2026-09-18

Owner contract: `EA_LAB-NEW-MAIN-CT-20260917`

Implementation base: `da2b396f345dbbefa62f7cad07206a5a4185efc0`

Accepted source head: `bc2e4afe09ca3309b091a032c020140ea1c5a858`

Status: `SOURCE_ACCEPTED / REVIEWED / CANONICAL / REPO_ONLY / NO_RUNTIME_HOOKUP`

Authority: read-only source capture and deterministic adaptation only

## Purpose and boundary

This provider is the bounded missing producer for the accepted Owner Control Room V0 optional
`EA_LAB_JOB_OBSERVATIONS_V1` input. It takes an explicit list of safe lane IDs, freezes each lane's exact
lease plus its bound Long Job `job.json`, `state.json`, optional `heartbeat.json`, and optional
`result.json`, records PID creation identity at one check, and adapts that private bundle into the existing
V0 DTO. It does not enumerate lanes or jobs.

Source presence does not install or activate the provider. The existing refresh task, runner, status,
retry, dispatcher, watchdog, Registry, Monitor schema, builder and UI are unchanged. A future hookup needs
its own frozen rollback and compatibility contract with explicit runtime authority.

The prerequisite evidence was read by exact filename from `watchdog_input_preflight`:
`IDENTITY_GAP_OBSERVATION.json`, `identity_gap_observation.ps1`, `job_observations.json`,
`MANIFEST_SHA256.txt`, `NEXT_IDENTITY_PROVIDER_CONTRACT.md`, `projection.json`,
`SOURCE_MAPPING_RECEIPT.json`, and `watchdog_snapshot.json`. The verified reused-PID example records
postcondition PID `20008` at `2026-09-18T03:34:23.1831533Z` and a different process at that PID created at
`2026-09-18T03:49:53.0812905Z`. The unrelated process name stays outside the public DTO.

## Capture contract

`capture_job_identity.ps1` requires absolute `RepoRoot`, `LeaseRoot`, `JobsRoot`, and a fresh external
`OutputRoot`, an exact lowercase 40-hex candidate-source `ExpectedHead`, a separately supplied current
`CanonicalObservedHead`, and an explicit `LaneIds` array. Before any repository helper is read or
dot-sourced, `RepoRoot` must be a non-reparse clean repository at the exact candidate head. Output may not
overlap or contain/be contained by an input root. Reparse components, hardlinked sources, traversal,
duplicate or unsafe/sensitive IDs, missing essential files, and lease/job ID or base mismatches fail
closed. The lease filename is derived as `<LeaseRoot>/<lane_id>.json`; the job root is derived as
`<JobsRoot>/<job_id>`. Operational paths supplied by a lease are validated as strings but never resolved,
opened, or trusted.

Each lease has exactly this adapter-validated shape:

```json
{
  "lane_id": "safe-lane-id",
  "job_id": "safe-job-id",
  "created_utc": "timezone-aware timestamp with up to 7 fractional digits",
  "job_root": "untrusted operational path",
  "status_script": "untrusted operational path",
  "runner_root": "untrusted operational path",
  "requested_file": "untrusted operational path",
  "launch_file": "untrusted operational path",
  "worktree": "untrusted operational path",
  "base_sha": "40 lowercase hex",
  "stage": "untrusted operational label"
}
```

This is the exact installed eleven-field dispatcher shape. It has no provider-specific schema field and
permits no extra field. The provider consumes only `lane_id`, `job_id`, `created_utc`, and `base_sha` as
identity/chronology data; explicit caller roots remain the sole path authority.

The collector copies original bytes to a new private bundle with SHA-256, length, last-write time, and
before/after fingerprints. Absent heartbeat/result files use an explicit `ABSENT` sentinel. Strict JSON
syntax, duplicate-key and exact allowed/required-key validation for every raw record completes before any
PID query. Every declared
lease/job/state/heartbeat/result and the canonical `_long_job_runner_lib.ps1` helper is checked before and
after process observation. A change is refused before an output root is created.

Recorded PIDs are queried through `Get-LjrProcessSnapshot`. A null helper result triggers a second
read-only `System.Diagnostics.Process.GetProcessById` query: only its documented no-such-process exception
qualifies `RECORDED_PROCESS_NOT_PRESENT`; access/metadata/race failures remain `UNKNOWN`. No query captures
process name, command line, account, environment or authentication text. The private identity values are
`MATCHING_RECORDED_PROCESS`, `RECORDED_PROCESS_NOT_PRESENT`, `DIFFERENT_CREATION_IDENTITY`, and `UNKNOWN`.

PID plus creation time is compared after timezone normalization at the full supplied 100ns precision.
Different seventh fractional digits never match. A null postcondition PID is absent only when private job
metadata explicitly has no configured postcondition. Missing runner/child identity, access denial, an
unknown creation time, unsafe metadata, a source change, or incomplete role coverage makes the complete
requested snapshot unavailable.

All overlap, reparse, hardlink, JSON, binding and process-identity refusal checks complete before the
output root is created. The manifest is written last. Exclusive file creation and a fresh output root
prevent overwrite. Until the
manifest exists and `INCOMPLETE.json` is absent, a bundle is incomplete.

## Deterministic adapter and mapping

`job_identity_provider.py` performs no subprocess, network, process or live probing beyond reading the
supplied frozen bundle. It rejects duplicate JSON keys, nonfinite values, extra/unknown source keys,
undeclared or extra bundle files, duplicate IDs, sensitive-looking public IDs, unsafe paths,
symlink/reparse or hardlinked input, hash/length mismatch,
source-presence changes, malformed types/times, mismatched IDs/base, future chronology, and unsupported
state combinations.

The adapter validates creation identities and exact `ended <= checked <= captured envelope` chronology at
full 100ns precision before converting times to V0 whole-second UTC. It also mirrors V0's maximum-safe-
integer and sensitive-identifier boundaries. The existing 24-hour/five-minute V0 freshness policy is
unchanged and remains enforced by `owner_operations.project`.

Mapping rules are deliberately narrow:

- `MATCHING_RECORDED_PROCESS` maps to `true`; known absent or different creation identity maps to `false`;
  `UNKNOWN` refuses the complete snapshot.
- A reused PID never makes the historical job live. A terminal `COMPLETE` result is preserved when a
  different process occupies the old PID.
- A terminal child or postcondition that still matches the recorded identity refuses the snapshot. A
  terminal runner may still be publishing its receipt, matching accepted V0 semantics.
- `RUNNING` maps to `LOST_PROCESS` only when the recorded runner is known absent/mismatched. A live runner
  with a missing child is unrepresentable under V0 (V0 forbids `LOST_PROCESS` with a live runner) and
  refuses the envelope. A matching
  `POSTCONDITION_RUNNING` postcondition remains active; an ambiguous active/postcondition combination is
  unavailable. `CANCEL_REQUESTED` and incomplete `STARTING` identity are unsupported.
- Result bytes are never corrected. Terminal result/state/end/exit/postcondition contradictions refuse.
- The provider emits only `UNKNOWN` or conservative `REFUSE_RETRY`; it never emits `ALLOW_RETRY`.
- An explicitly requested empty lane list is a valid zero-row snapshot. A refused envelope creates no
  `job_observations.json`, so refusal cannot resemble a valid empty observation.

The public file contains only the exact `EA_LAB_JOB_OBSERVATIONS_V1` envelope and row allowlist already
accepted by V0. Precise expected/current identities, checked times, source hashes, exact public output and
provider status remain in `private_provenance_receipt.json`. `expected_head` / `candidate_source_head`
identify the local candidate provider source only; the caller-supplied `canonical_observed_sha` is the
current canonical binding in the public DTO, so a candidate SHA is never relabeled canonical.
`publication_receipt.json` is written last;
`INCOMPLETE.json` is removed only after all publication files are durable. Existing Monitor code remains
the final V0 validator and projector.

## Command/API usage

The Control Tower supplies roots and IDs explicitly. These examples use placeholders and do not identify
or activate a runtime:

```powershell
powershell -NoProfile -File scripts/execution_reliability/capture_job_identity.ps1 `
  -RepoRoot <clean-absolute-repo> -ExpectedHead <candidate-source-40-hex-head> `
  -CanonicalObservedHead <current-canonical-40-hex-head> `
  -LeaseRoot <absolute-lease-root> -JobsRoot <absolute-jobs-root> `
  -LaneIds <lane-a>,<lane-b> -OutputRoot <fresh-absolute-private-bundle>
```

```powershell
. scripts/use_python.ps1
Assert-PortablePython -Root (Get-Location)
python tools/mobile_report_hub/job_identity_provider.py `
  --bundle-manifest <absolute-private-bundle>/manifest.json `
  --output-root <fresh-absolute-publication-root>
```

Python callers may use `adapt_bundle(Path(manifest), Path(output_root))`; it returns the public DTO and
private receipt only after immutable publication succeeds. Provider errors raise `ProviderError`. The CLI
returns exit `2` with `UNAVAILABLE` and leaves no public DTO when validation refuses.

## Validation and acceptance boundary

Author validation:

```text
python -m unittest discover -s tools/mobile_report_hub/tests -p test_job_identity_provider.py -v
powershell -NoProfile -File scripts/_test/run_job_identity_capture_tests.ps1
powershell -NoProfile -File scripts/_test/run_mobile_report_hub_data_tests.ps1
python -m py_compile tools/mobile_report_hub/job_identity_provider.py tools/mobile_report_hub/tests/test_job_identity_provider.py
powershell -NoProfile -File scripts/make_taskboard_digest.ps1 -Check
git diff --check 293c3ef13bc47f70f7ef3e7064ad80ed4e97647a -- <six-file repair allowlist>
```

Focused coverage includes matching, absent, reused, inaccessible and 100ns-different creation identity;
terminal history with unrelated PID; active/postcondition/lost/terminal-live states; NOT_CONFIGURED;
strict IDs/keys/types/JSON before PID reads; source mutation and absence/presence change;
`ended<=checked<=envelope`; stale/future/order/timezone; valid-empty versus refused output;
collision/traversal/reparse/hardlink before output creation; candidate/canonical separation;
deterministic bytes; and V0 positive/refusal
compatibility. The PowerShell harness observes only its own process and a deliberately absent PID. It does
not control a process or inspect production inputs.

Author tests were not independent acceptance. The first independent review at
`293c3ef13bc47f70f7ef3e7064ad80ed4e97647a` returned `FAIL / HIGH / BLOCK` with
`JIPV1-001..008`. One bounded repair fixed exactly those findings. Targeted independent recheck of exact
head `bc2e4afe09ca3309b091a032c020140ea1c5a858` returned `PASS / HIGH / ALLOW`; all eight findings are
closed and no material regression was found.

Accepted repair evidence is: focused provider tests `36/36 PASS` plus one privilege-dependent symlink
skip covered by the PowerShell reparse harness; capture harness PASS; full Monitor data tests `141/141
PASS` with the same privilege-dependent skip; Python compile, digest check, diff check, source/hash
preservation, and normal commit hooks PASS. Canonical push and remote readback bind the accepted repo
source to `bc2e4afe09ca3309b091a032c020140ea1c5a858`.

Acceptance is source-only. No production-root capture, provider hookup, refresh-task change, scheduler,
process control, runtime activation, deployment, Registry operation, MT5 action, or core-reviewer
qualification occurred. A fixture or sampled capture is not production readiness, and a future real
capture may honestly be `UNAVAILABLE`. Existing refresh/runtime hookup remains a later separately frozen
contract with rollback and compatibility evidence.
