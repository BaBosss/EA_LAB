# EA_LAB Job Identity Provider V1

Date: 2026-09-18

Owner contract: `EA_LAB-NEW-MAIN-CT-20260917`

Base: `da2b396f345dbbefa62f7cad07206a5a4185efc0`

Status: `IMPLEMENTATION_PENDING_REVIEW / REPO_ONLY / NO_RUNTIME_HOOKUP`

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
`OutputRoot`, an exact lowercase 40-hex `ExpectedHead`, and an explicitly supplied `LaneIds` array. The
repository must be clean at that exact head. Output may not overlap or contain/be contained by an input
root. Reparse components, traversal, duplicate or unsafe IDs, missing essential files, and lease/job ID or
base mismatches fail closed. The lease filename is derived as `<LeaseRoot>/<lane_id>.json`; the job root is
derived as `<JobsRoot>/<job_id>`. No root or path supplied inside a lease is trusted.

Each lease has exactly this adapter-validated shape:

```json
{
  "schema_version": "EA_LAB_JOB_IDENTITY_LEASE_V1",
  "lane_id": "safe-lane-id",
  "job_id": "safe-job-id",
  "base_sha": "40 lowercase hex"
}
```

The collector copies original bytes to a new private bundle with SHA-256, length, last-write time, and
before/after fingerprints. Absent heartbeat/result files use an explicit `ABSENT` sentinel. Every declared
lease/job/state/heartbeat/result and the canonical `_long_job_runner_lib.ps1` helper is checked before and
after process observation. A change leaves only an incomplete bundle and no accepted manifest.

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

The manifest is written last. Exclusive file creation and a fresh output root prevent overwrite. Until the
manifest exists and `INCOMPLETE.json` is absent, a bundle is incomplete.

## Deterministic adapter and mapping

`job_identity_provider.py` performs no subprocess, network, process or live probing beyond reading the
supplied frozen bundle. It rejects duplicate JSON keys, nonfinite values, extra/unknown source keys,
undeclared or extra bundle files, duplicate IDs, unsafe paths, symlink/reparse input, hash/length mismatch,
source-presence changes, malformed types/times, mismatched IDs/base, future chronology, and unsupported
state combinations.

The adapter validates creation identities and all source chronology before converting times to V0
whole-second UTC. The existing 24-hour/five-minute V0 freshness policy is unchanged and remains enforced
by `owner_operations.project`.

Mapping rules are deliberately narrow:

- `MATCHING_RECORDED_PROCESS` maps to `true`; known absent or different creation identity maps to `false`;
  `UNKNOWN` refuses the complete snapshot.
- A reused PID never makes the historical job live. A terminal `COMPLETE` result is preserved when a
  different process occupies the old PID.
- A terminal child or postcondition that still matches the recorded identity refuses the snapshot. A
  terminal runner may still be publishing its receipt, matching accepted V0 semantics.
- `RUNNING` with a known missing/mismatched runner or child maps to `LOST_PROCESS`. A matching
  `POSTCONDITION_RUNNING` postcondition remains active; an ambiguous active/postcondition combination is
  unavailable. `CANCEL_REQUESTED` and incomplete `STARTING` identity are unsupported.
- Result bytes are never corrected. Terminal result/state/end/exit/postcondition contradictions refuse.
- The provider emits only `UNKNOWN` or conservative `REFUSE_RETRY`; it never emits `ALLOW_RETRY`.
- An explicitly requested empty lane list is a valid zero-row snapshot. A refused envelope creates no
  `job_observations.json`, so refusal cannot resemble a valid empty observation.

The public file contains only the exact `EA_LAB_JOB_OBSERVATIONS_V1` envelope and row allowlist already
accepted by V0. Precise expected/current identities, checked times, source hashes, exact public output and
provider status remain in `private_provenance_receipt.json`. `publication_receipt.json` is written last;
`INCOMPLETE.json` is removed only after all publication files are durable. Existing Monitor code remains
the final V0 validator and projector.

## Command/API usage

The Control Tower supplies roots and IDs explicitly. These examples use placeholders and do not identify
or activate a runtime:

```powershell
powershell -NoProfile -File scripts/execution_reliability/capture_job_identity.ps1 `
  -RepoRoot <clean-absolute-repo> -ExpectedHead <40-hex-head> `
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
git diff --check da2b396f345dbbefa62f7cad07206a5a4185efc0 -- <exact allowlist>
```

Focused coverage includes matching, absent, reused, inaccessible and 100ns-different creation identity;
terminal history with unrelated PID; active/postcondition/lost/terminal-live states; NOT_CONFIGURED;
strict IDs/keys/types/JSON; source mutation and absence/presence change; stale/future/order/timezone;
valid-empty versus refused output; collision/traversal/reparse; deterministic bytes; and V0 positive/refusal
compatibility. The PowerShell harness observes only its own process and a deliberately absent PID. It does
not control a process or inspect production inputs.

Author tests are not independent acceptance. Status remains
`IMPLEMENTATION_PENDING_REVIEW / REPO_ONLY / NO_RUNTIME_HOOKUP` until the Control Tower freezes exact source,
runs its prescribed one-shot capture and impacted checks, commits normally, and obtains the one independent
exact-head normal-tooling review. A fixture or sampled capture is not production readiness, and a real
capture may honestly be `UNAVAILABLE`.
