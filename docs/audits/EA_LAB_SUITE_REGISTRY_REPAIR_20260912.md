# QRESET-11 suite registry completeness repair

Date: 2026-09-12. Role: bounded Codex tooling worker, not Control Tower.
BASE: `014bc9c1d9a559bf6a1a3f3ee5360f051c506902`.
Worktree: `D:/EA_LAB_CONTROL/worktrees/qreset11-suite-registry-repair-20260912`.
Branch: `codex/qreset11-suite-registry-repair-20260912`.
Lane: `QRESET-11-SUITE-REGISTRY-REPAIR`.

## Scope and base

The owner supplied the exact bounded contract in chat. The existing lane record agrees with this base and scope; no new order or governance decision was created. Initial `git status --short --branch --untracked-files=all` was clean. HEAD and local `origin/master` both matched BASE. Live GitHub `master` was independently resolved through the read-only GitHub commit connector and matched BASE before the repair. Native `git ls-remote` failed with Schannel `SEC_E_NO_CREDENTIALS`; a process-local OpenSSL attempt failed certificate-chain verification. TLS verification was not disabled and persistent Git settings were not changed.

Read START_HERE, PROJECT_STATE, AGENTS, taskboard routing/active task search, lane record, registry, guard-trigger, fast-tier runner and all four omitted wrappers. The task DAG is serial: inspect/reproduce -> standalone measurements -> one registry repair -> direct reruns and impacted validation -> local commit/freeze if permitted. No additional worker lane or tester lane is needed.

Only four literal registry rows and their comment are added, plus this audit. `run_guard_trigger_tests.ps1` is unchanged: its existing production PART 8 already detects the precise missing-row defect. No new assertion is needed for this data repair. No budget, test, assertion, hook, suite wiring, product, strategy, risk/default, runtime, deployment, trading or owner authority is changed. No push is authorized or performed.

## Classification rationale

Canonical schema is `scripts/_test/SUITE_TIER_REGISTRY.txt`: FAST must match membership in exported `$FAST_SUITES` in both directions; HARNESS is the tier runner itself; SLOW requires measured cost making hook participation untenable; NOT_WIRED requires the recorded disposition; UNMEASURED denotes missing measurement against the pinned full-tier budget. Existing 2026-09-06 rows explicitly distinguish focused execution from incremental full-tier cost.

| Runner | Classification | Evidence and remaining qualification |
|---|---|---|
| `run_hermes_v2_tests.ps1` | UNMEASURED | MCP fixture wrapper uses an existing Hermes interpreter; all attempts returned a nonzero native interpreter result before a test summary. Successful suite cost and incremental full-tier cost are unknown. No interpreter/dependency substitution or test omission. |
| `run_mobile_monitor_operationalization_tests.ps1` | UNMEASURED | Offline temporary Git/runtime/registry/site fixtures; exercises real producer metadata, containment, publication filtering, lineage and terminal DailyMonitor branches without live collectors. Successful standalone timings exist; pinned-tier cost/dependency admission remains unmeasured. |
| `run_mt5_report_asset_tests.ps1` | UNMEASURED | Portable-Python compile plus 28 report-asset unit tests; offline fixture only, no MT5 execution. Successful standalone timings exist; incremental pinned-tier cost remains unmeasured. |
| `run_status_deployment_authority_tests.ps1` | UNMEASURED | 13 checks using the real status generator/template and temporary inventory with unrelated readers stubbed. Standalone timing exists; incremental pinned-tier cost remains unmeasured. |

None is a member of the existing 35-suite FAST set or the tier harness. Standalone durations do not justify a governed SLOW classification, and no canonical NOT_WIRED disposition for these four was found. UNMEASURED records the remaining admission question; it does not claim these suites were never executed or are accepted for permanent exclusion. Measuring the unchanged full tier below does not measure a hypothetical tier containing these four. No wiring decision was made merely to obtain a green completeness result.

## Standalone timing evidence

Windows PowerShell `5.1.26100.9444`; child command for each row:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/_test/<runner>
```

The driver dot-sourced `scripts/use_python.ps1`, then used `Assert-PortablePython -Root <worktree> -Provision` to restore the ignored standard-library ZIP from the canonical checkout. Process-local PSModulePath included `$PSHOME/Modules`. No persistent shell/profile setting was changed. Hermes used its unmodified default `%LOCALAPPDATA%/hermes/hermes-agent/venv/Scripts/python.exe`; its `pyvenv.cfg` records Python 3.11. All measurements include child-shell startup and output capture, with no custom budget overrides.

| Runner (prefix `run_`) | Before seconds (3 attempts) | After seconds (3 attempts) | After median | Result |
|---|---|---|---|---|
| `hermes_v2_tests.ps1` | 1.930 / 1.437 / 0.460 | 0.518 / 0.487 / 0.441 | 0.487, failed-attempt latency only | All wrapper exits 1; native result `-1058471934`; no test-count PASS established |
| `mobile_monitor_operationalization_tests.ps1` | 15.662 / 15.455 / 14.549 | 14.355 / 14.220 / 14.084 | 14.220 | All six exit 0, `PASS mobile monitor operationalization tests` |
| `mt5_report_asset_tests.ps1` | 2.158 / 1.942 / 1.907 | 1.941 / 1.944 / 1.897 | 1.941 | All six exit 0, 28 tests OK |
| `status_deployment_authority_tests.ps1` | 0.682 / 0.673 / 0.684 | 0.696 / 0.667 / 0.691 | 0.691 | All six exit 0, 13/13 PASS |

The initial mobile measurement batch overlapped the baseline guard invocation, so before/after differences are not a performance experiment. The entire after batch ran serially without another agent-started test workload. Host background load was not controlled. These results establish execution outcomes and local timing observations only; no performance root cause or speedup is claimed. The Hermes native failure is a remaining execution/environment prerequisite with its underlying cause unproven; failed-process latency must not be used as suite cost.

Raw local evidence is retained under ignored `build/qreset11/`: `timings.jsonl`, `before-<runner>-<n>.log`, `after-<runner>-<n>.log`, `guard-before.log`, and validation logs. The named audit is the tracked evidence summary; ignored logs are not claimed to be canonical artifacts.

## Validation and integration disposition

Baseline production guard: exactly four failures, all PART 8 UNCLASSIFIED and naming the four rows above. Scope: 113 tracked files / 109 rows; FAST 35, HARNESS 1, SLOW 4, NOT_WIRED 3, UNMEASURED 66. Parts 1-7 passed, including selection and 110s/195s budget-enforcement assertions. Baseline timing sum was 17.02s, including PART 8 0.09s; this is one observation, not a median.

Post-repair production guard: exit 0, 16.233s wall time. All parts green, including PART 8; 113 tracked files / 113 rows, FAST 35, HARNESS 1, SLOW 4, NOT_WIRED 3, UNMEASURED 70. Zero missing rows, duplicate rows, stale rows or FAST membership mismatches. Parts 3 and 5 validate generated pathspec and selection; Parts 6 and 7 retain negative evidence-mode and enforced-budget tests.

Existing `run_reverse_completeness_negative_tests.ps1`: exit 1, 97.264s. Attacks 1 (missing row), 2 (wildcard), 3 (stale row), 5 (short reason), and healthy control passed. Exact remaining failure: `ATTACK 4 expected PREDEV disposition BROKEN; got exit 0`. At BASE the fixture selects `run_new_template_entry_tests.ps1` and replaces `|NOT_WIRED|` with `|FAST|`, but that row is already FAST. PROJECT_STATE records its owner-directed promotion on 2026-09-07, and production PART 8 now preserves only the other two PREDEV dispositions. Thus this fixture performs no mutation. Its existing source and target row are unchanged by QRESET-11; fixing it would be a second unrelated repair and is not attempted.

### Full-tier outcome

Full-tier command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/_test/run_fast_cages.ps1`, with no staged-path filter or budget override. Exit 1; **35 suites / 10 failures / 92.2s reported suite total**, 93.002s outer wall time. The elapsed total is below 195s, but this is **not assertion-green or a full-tier PASS**. Failed/aborted suites prevent using it as a successful full-tier performance qualification; the runner exits on suite failures before its final budget verdict. Only one full-tier observation was taken. Exact observed failures are preserved here; abbreviated errors are exactly what the runner retained, not reconstructed tracebacks:

| Failing runner | Exit | Observed diagnostic |
|---|---|---|
| `run_portable_python_tests.ps1` | 1 | `git worktree add failed for the regression worktree`; 3/4 PASS |
| `run_monitor_integrity_tests.ps1` | -1 | `fixture green.json did not build: [TOOL-FAILURE] ajv could not run, so nothing was validated (exit 1): 'ajv' is not` |
| `run_schema_cages.ps1` | -1 | `SUITE THREW (stderr under EAP=Stop, or the launcher failed): python.exe : Traceback (most recent call last):` |
| `run_snapshot_s4_tests.ps1` | -1 | `fixture clean did not build: [TOOL-FAILURE] ajv could not run, so nothing was validated (exit 1): 'ajv' is not` |
| `run_monitor_snapshot_schema_repair_tests.ps1` | -1 | `powershell.exe : control_room_snapshot: snapshot_build.py refused this build (exit 3).` |
| `run_preset_tests.ps1` | 1 | `E2E populated synthetic config -> AJV is unavailable; schema validation did not run for TestUniverse` |
| `run_s10_tests.ps1` | -1 | `git.exe : warning: unable to access 'C:\Users\patip/.config/git/ignore': Permission denied` |
| `run_s11_tests.ps1` | 1 | 87 scenarios, 2 failed (WIRE1 and WIRE2): AJV unavailable |
| `run_s12_tests.ps1` | -1 | `python.exe : the full snapshot could not be verified, so no projection was built: ToolFailure: ajv could not run, so` |
| `run_front_guard_evidence_tests.ps1` | -1 | `hash-object produced no oid for taskboards/active/P03.md` |

No second repair was attempted. Dependency/permission diagnostics do not establish every failure's underlying cause. No performance root cause is claimed. The guard-trigger suite passed inside this full-tier run as well as directly.

Separate `scripts/gen_fast_tier_pathspec.ps1 -Check`: PASS, 198 entries match. `run_fast_cages.ps1 -ExportSelection -StagedPaths scripts/_test/SUITE_TIER_REGISTRY.txt` retains the existing no-match fallback selecting all 35 suites. `git diff --check`: PASS.

Local raw-log SHA256:

- `build/qreset11/after-run_fast_cages.ps1.log`: `6ed068f680b9e2f703ab2c4b1db4b1c4b61e4c521189d7af057cf5fd5eb091a6`.
- `build/qreset11/after-run_reverse_completeness_negative_tests.ps1.log`: `273630fbb750b90affae4e9d1079f767192b42b6f50bd7b8824b7d341947fcdd`.
- `build/qreset11/timings.jsonl`: `23076b88a5d7b15a19a0857571b038e81ce2c6ff2d221c256c50464779349af7`.

### Source identity at BASE

Git blob IDs (raw tracked objects):

| Path under `scripts/_test/` | Git blob |
|---|---|
| `SUITE_TIER_REGISTRY.txt` | `4c35aab31db8d51d0370d98c500ed108e01861c8` |
| `run_fast_cages.ps1` | `d1ca8d2c00cb38cedcdd6bb2e72db48303c7d712` |
| `run_guard_trigger_tests.ps1` | `4b868771ddbbf7275e184d1994b234d43aa03335` |
| `run_hermes_v2_tests.ps1` | `848ebaabf5e13c6b278d6a177e35495199e7ef92` |
| `run_mobile_monitor_operationalization_tests.ps1` | `885117e8127a1b6c8feb9dcf2d881bfa823545b1` |
| `run_mt5_report_asset_tests.ps1` | `9e51c92a5e06ec347d8bbf6b748a03a9718cb2f7` |
| `run_reverse_completeness_negative_tests.ps1` | `e7e8069ac62b2975d8923f092071b8990a455944` |
| `run_status_deployment_authority_tests.ps1` | `cc45693b9ecd299b893d784464fc10b3a1b054cf` |

## Final worker handoff

Live GitHub `master` was rechecked before staging and still equalled BASE. No remote movement was observed; no fetch, reconciliation, branch switch or push occurred.

Staging the exact two intended files was attempted once and failed:

```text
fatal: Unable to create 'D:/EA_LAB/.git/worktrees/qreset11-suite-registry-repair-20260912/index.lock': Permission denied
```

The managed sandbox permits working-file changes here but not shared Git metadata writes, and approval escalation is unavailable. No alternate index, alternate repository or hook bypass was used. **Commit: NOT CREATED. Normal commit hooks: NOT RUN**, because the intended patch could not be staged. Effective hooksPath remains `.githooks`. Post-commit `make_status` is not applicable because no commit occurred.

Final HEAD remains `014bc9c1d9a559bf6a1a3f3ee5360f051c506902` with exactly this audit untracked and the registry modified; the index is unchanged. The requested external lane transition cannot be written under the current permission boundary: `D:/EA_LAB_CONTROL/lanes/registry-v1` is outside the writable workspace. Its record remains RUNNING at BASE, not falsely FROZEN. A clean frozen repair commit is not claimed.

**SAFE_TO_INTEGRATE: NO / BLOCKED pending local commit, normal hooks and integration review.** The narrow reverse-completeness repair is verified; overall acceptance remains limited by the Hermes execution prerequisite, stale negative fixture and ten recorded full-tier failures. The integration owner can consume the two-file patch and exact evidence; this worker does not authorize repair of those other issues or grant Schema V2/full-tier acceptance. One bounded source-data repair was made, with no follow-on repair or performance-root-cause claim.
