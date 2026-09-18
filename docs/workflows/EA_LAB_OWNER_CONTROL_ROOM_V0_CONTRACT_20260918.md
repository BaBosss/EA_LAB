# EA_LAB Owner Control Room V0 — first Monitor increment

Date: 2026-09-18  
Owner contract: `EA_LAB-NEW-MAIN-CT-20260917`  
Base: `f9a9906f45418303e43345141cf8c6f81f15007a`  
Status: `LOCAL_IMPLEMENTATION_PENDING_ACCEPTANCE`  
Authority ceiling: `REPO_ONLY / READ_ONLY_PRESENTATION`

## Purpose and non-authority

This bounded increment adds one optional caller-supplied job-observation DTO to the existing Monitor. It
shows process observations separately from canonical taskboard declarations, Lane Registry audit state,
EA/Registry status, deliverable acceptance and review. It is not a collector, scheduler, runner, Registry
parser, workflow engine or second dashboard.

The consumed finite synthetic pilot is `ACCEPTED / PASS / HIGH`, manifest
`4f4e70e3dd77e7486ced85838f54dd4d46e28b4fd857b08a75063a2ec1a87a42`. It proves finite steps only;
it does not qualify a production scheduler, host survival, runtime hookup or unattended operation. The old
head `d47b9a6e9bd407c7996ccceffd541387ae32f931` remains `BLOCKED` after `FAIL / HIGH / DOC-001..003`.
No bytes, repair budget or inference are carried from that rejected package.

Source implementation alone does not change the deployed Monitor. The existing
`EA_LAB_MonitorV31_Refresh` task remains unchanged and pinned to tooling `e88ed119`. Provider hookup,
runtime tooling migration, Scheduled Tasks, OneDrive/VPS, public hosting and deployment remain separate
gates.

## Frozen input DTO

Only a Control Tower caller may derive the frozen file from existing durable lane/job status helpers and
pass it using `build_index.py --job-observations <path>`. The builder reads that file once. It never reads a
jobs root, process table, stdout log or postcondition output, and never launches or mutates a process.
The enclosing author job's postcondition remains the caller-owned fixed CLI result file published before
child exit; `runner stdout.log` is not that postcondition because it is written only afterward. No installed
runner change is required or authorized by this contract.

Envelope schema:

```json
{
  "schema_version": "EA_LAB_JOB_OBSERVATIONS_V1",
  "source_kind": "LOCAL_DURABLE_JOB_STATUS",
  "observed_at_utc": "YYYY-MM-DDTHH:MM:SSZ",
  "canonical_observed_sha": "40 lowercase hex",
  "observations": [
    {
      "lane_id": "safe literal ID",
      "job_id": "safe literal ID",
      "checked_utc": "YYYY-MM-DDTHH:MM:SSZ",
      "observed_state": "allowlisted job state",
      "durable_state": "allowlisted job state",
      "runner_alive": true,
      "child_alive": false,
      "postcondition_alive": false,
      "heartbeat_age_sec": 12.5,
      "retry_decision": "REFUSE_RETRY",
      "result": {
        "state": "COMPLETE",
        "exit": 0,
        "postcondition": "PASSED",
        "ended": "YYYY-MM-DDTHH:MM:SSZ"
      },
      "local_head": "optional 40 lowercase hex"
    }
  ]
}
```

The three process fields, heartbeat age, result exit and result end time may be null only where the source
cannot qualify them; null projects as `UNKNOWN`. State, retry and postcondition fields use the literal
`UNKNOWN`. Required keys may not be omitted and arbitrary extra keys are
refused. Identifiers are bounded ASCII literals; paths, URLs, account/login-shaped IDs, commands,
credentials and arbitrary prose are not accepted. The projection exports only the safe fields required by
the table plus source SHA256, source kind, timestamp basis, authority, freshness and canonical binding.

Freshness uses the existing Control Tower policy: 24-hour current ceiling and five-minute future tolerance.
Browser display-time checks additionally suppress current claims when offline, cached, stale, future or
canonical-unbound. Every process boolean means “observed at `checked_utc`”; it is never a continuous health
claim. `COMPLETE`/exit 0 establishes neither deliverable completion nor review/canonical acceptance.

## Ten-requirement coverage and next-gate matrix

| # | Requested owner section | Existing Monitor support / source owner | V0 addition | V0 state and exact next gate |
|---|---|---|---|---|
| 1 | Program status and percentage | Overview shows canonical global state from `PROJECT_STATE.md`; no authoritative percentage input exists | None | `UNAVAILABLE`; define and approve an authoritative structured program-progress source before any percentage is rendered |
| 2 | M1–M6 completion | Current/Next show literal `PROJECT_STATE.md` plan context only | None | `NOT_IMPLEMENTED`; a milestone owner must publish structured milestone IDs, denominators and acceptance states |
| 3 | Current work and job observations | Work separates canonical taskboard headers from noncanonical Lane Registry Audit observations | Optional frozen job table with lane/job, checked time and observed process snapshot | `IMPLEMENTED_PENDING_ACCEPTANCE`; later provider hookup must supply the exact DTO without changing Registry parsing |
| 4 | Runtime/process health | Runtime already shows monitoring source observations and explicit UNKNOWN placeholders | Same read-only observed-job table; current claims suppressed when unqualified | `SNAPSHOT_ONLY`; production collection/host-survival qualification is a separate contract |
| 5 | Next three executable steps | Overview shows the first three literal `PROJECT_STATE.md` plan-context items, explicitly not executable readiness | None | `UNAVAILABLE`; requires an authoritative eligibility/dependency projection, not prose inference |
| 6 | Owner decisions / NEED BOSS | Existing NEED BOSS uses its accepted Lane Registry qualification and preserves historical/unqualified evidence | No new action derivation; generic E-class appears only as `WAIT_EXTERNAL` in blocker grouping | `NO_NEW_OWNER_ACTION_SOURCE`; a future structured owner-action DTO must carry an explicit action and authority |
| 7 | Blockers, root causes and dependencies | Work/Alerts already show safe blocker class and Lane Registry dependency metadata | Groups safe A–E observations and literal dependency IDs; no raw blocker prose | `IMPLEMENTED_PENDING_ACCEPTANCE`; richer root cause needs a separately source-bound structured classifier |
| 8 | Visit delta / what changed since last visit | No durable per-owner visit checkpoint exists | None | `NOT_IMPLEMENTED`; define owner-scoped checkpoint identity, retention and comparison authority before showing deltas |
| 9 | EA maturity / portfolio readiness | EA Lab and accepted EA Detail/Report show source-bound lifecycle, evidence and report fields | None; accepted views are not redesigned | `PARTIAL_EXISTING / NO_NEW_SYNTHESIS`; any maturity rollup needs a Registry-owned structured definition and source |
| 10 | Demo parity and production readiness | Existing Report/Demo evidence may be opened through accepted records when source-bound | None; no Alpha fixture panel or invented production values | `UNAVAILABLE_AS_ROLLUP`; requires exact Demo/replay identity, qualified evidence and a separate accepted presentation contract |

Percentages, M1–M6 completion, executable next steps, owner decisions, visit deltas, EA maturity and Demo
parity are deliberately not backfilled from prose or inferred from process exit. The V0 layout therefore
keeps known unknowns visible instead of approaching a claimed readiness percentage.

## UI and status separation

Runtime and Work consume `owner_operations` if present and tolerate its absence in older indexes. Columns
show lane/job, observed runner/child/postcondition state, checked time, heartbeat age, qualified local head,
process terminal result and the literal `UNKNOWN / UNKNOWN / UNKNOWN` deliverable-review-canonical scope.
The source SHA256, basis, authority, observation time, binding and limitation are inspectable without a
filesystem path.

Work and Alerts group existing safe blocker classes with exact Lane Registry dependency IDs. Class E is
displayed as `WAIT_EXTERNAL`; it is not an instruction to continue, approve or bypass review. This V0 does
not create NEED BOSS from generic E-class or missing owner-action data. There are no action, approval,
dispatch, retry, process-control or trading controls.

## Validation and review gate

Author validation:

```text
python tools/mobile_report_hub/tests/test_owner_operations.py -v
powershell -File scripts/_test/run_mobile_report_hub_data_tests.ps1
powershell -File scripts/_test/run_mobile_report_hub_ui_tests.ps1
node --check mobile_report_hub/app.js
node --check mobile_report_hub/sw.js
git diff --check
```

Focused cases cover valid/absent input, schema/time/head/type refusal, duplicate/conflicting identities,
stale/future/binding states, hostile paths/text, terminal-versus-scope separation and deterministic output.
The caller must validate exact changed paths and source HEAD, run frozen source/browser checks, make the
clean commit with normal hooks, and obtain independent exact-head normal-tooling review before eligible
integration/state convergence. Author-side tests are not independent acceptance.

## Explicitly out of scope

No database, collector, network call, process enumeration/control, runner change, Registry parser,
scheduler, runtime-provider hookup, timing/uptime guarantee, MT5/MetaEditor, research ranking, Alpha fixture,
EA Detail/Report redesign, risk/default change, deployment, trading, DEMO/LIVE promotion, push or owner
attestation is authorized or performed.
