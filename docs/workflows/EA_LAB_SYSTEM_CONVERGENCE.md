# EA_LAB system convergence tooling — 2026-09-06

This milestone implements bounded seams identified by the independent ecosystem audit. It does not claim that every EA_LAB subsystem is production-ready. Canonical state remains `PROJECT_STATE.md`; authority remains `AGENTS.md`; tools below emit read-only observations or validation results. The owner put system reliability ahead of further PWA work.

## Operational path

Objective -> exact-ref context -> scoped contract and dependency/resource plan -> existing deterministic runner or qualified worker -> evidence/postcondition checks -> required review -> serial integrator intake -> canonical state/remote reconciliation -> owner progress/decision/blocker/approval.

- “Continue”: inspect the existing attempt and accepted evidence before executing anything again.
- “Do all”: continue ready dependencies inside the authorized objective; an external blocker blocks only that branch.
- “Parallel”: use independent file/runtime ownership and existing Lane Registry/MT5 constraints. Model 4 remains serial; no cross-install numerical acceptance comparison.
- Use `tools/external_capability_scout/scout.py` to locate existing capabilities, including this milestone's tools. `USE_EXISTING` is a navigation result; inspect the returned qualification/authority limits before dispatch. It grants no execution permission.

## Context and recovery

Use an isolated exact-ref worktree. Resolve pushed `origin/master` with `git ls-remote origin refs/heads/master`; read `START_HERE.md`, state, authority and the assigned task from that ref. Then generate a context packet:

```powershell
powershell -NoProfile -File scripts\make_context_packet.ps1 -Root <absolute-repo> -Ref <exact-sha> -ExpectedRemoteSha <verified-remote-sha> -OrderId <order-id> -OutputPath <absolute-task-output-json>
```

The packet now includes the router, actual program-status excerpt, and Git blob identities. All files are read from one resolved commit. Its older `freshness` field compares a local tracking ref; `remote_verification` explicitly distinguishes caller-supplied remote evidence from no network verification. The packet cannot write inside the repository and never owns project facts.

A requested canonical order is returned through its next peer heading, without the former silent 90-line cutoff. Check `order_lookup_state` and `order_complete`; `MISSING` is not a usable assignment. For an owner-assigned task whose contract is in the task output area, omit `-OrderId` and supply all of `-TaskContractPath <absolute-file> -ExpectedTaskContractSha256 <raw-byte-hash> -TaskContractId <owner-task-id>`. This binds the external contract path/hash as `OWNER_LOCAL_NONCANONICAL_EVIDENCE`; it includes no unrelated canonical order and does not treat the file contents as new authority.

For an interrupted or completed long job:

```powershell
powershell -NoProfile -File scripts\long_jobs\status_long_job.ps1 -JobId <id> -JobsRoot <absolute-jobs-root> -Json
. scripts\use_python.ps1
$python = Assert-PortablePython -Root <absolute-repo>
& $python scripts\execution_reliability\resume_work.py --job-dir <absolute-job-folder> --expected-base <job-input-base-sha>
```

The adapter reads durable `job.json`, `state.json` and `result.json`. It never retries a job. A missing/dead process requires inspection; `COMPLETE` is only `EXECUTION_COMPLETE_UNACCEPTED`. An existing job ID is never reused by Long Jobs. The result serializer preserves postcondition success/failure and the end timestamp includes postconditions.

Optional assurance intake requires an independently supplied, SHA-256-pinned admission file, the existing Harness packet, actual artifact root and current candidate SHA. Admission schema `ea-lab-job-admission/v1` binds `job_id`, exact `assurance_contract`, explicit author/reviewer identities and review-policy booleans. The shared contract must contain `execution_binding`, computed by `resume_work.execution_binding(job_dir, expected_base)`: job ID, base SHA and actual SHA-256 of the completed job/state/result records plus execution logs. Missing bindings, a packet for another attempt and changed execution evidence are refused. Create the binding after the attempt finishes, then freeze it into the admission and reviewed packet; hashes establish byte identity, not authenticated execution provenance. Use `--assurance`, `--admission`, `--admission-sha256`, `--artifact-root`, and `--current-head` together. The caller/integrator supplies the actual frozen clean candidate identity; the adapter does not infer or authenticate it. `ASSURANCE_VALIDATED` means the supplied contracts/artifacts passed the Harness; authorized integration and canonical acceptance remain separate. No self-declared packet can weaken the pinned review policy.

## Evidence and executor boundary

`scripts/mt5_run.ps1` retains tester arguments, guard thresholds, and its advisory exit-code contract. Its truncation sidecar now distinguishes `CHECK_PASS`, `TRUNCATED`, `CHECK_ERROR` and `UNKNOWN`, preserving checker exit code. Inconclusive zero-exit diagnostics are not full-window proof.

Hermes full-window eligibility consumes that typed result. Old `truncated=false` alone could also encode an exception, so it is insufficient for **new** admission. Existing accepted H2/H3 and research receipts are not rewritten or retrospectively invalidated. No MT5 run was needed to test this serialization/consumer seam; existing report-message tests remain applicable. Hermes provider migration is separate and remains pending.

## Knowledge, template and monitoring consumers

- `tools/knowledge_validation/research_handoff_validator.py` validates exact source citations and the six-question research handoff. Valid structure does not establish semantic correctness or unlock QI-2/Factory/experiments.
- `tools/knowledge_validation/offline_replay_validator.py` selects only news/data revisions available at the decision time and refuses incomplete/unknown coverage and time-contract failures. Synthetic fixtures qualify the selector contract, not a real historical dataset, broker clock mapping, EA replay or trading policy.
- `_triage/factory_os/template_applicability.py` compares recorded dependency hashes against exact Git bytes. Different commit SHA alone does not invalidate unchanged dependency evidence. Changed/missing dependencies are `UNVERIFIED`, not a negative strategy verdict or an instruction to rerun every EA.
- The parameter-contract documentation follows the operational CSV vocabulary. The Profile/Universe repair is integrated at `89e0c3d5b79003f5591b2edb8b94dc14a0adee5d`, with qualified different-family static review and separately reviewed test-tooling additions. Original failed combined attempts are preserved; each cohesive source commit passed its normal hooks. See `portfolio/SYSTEM_CONVERGENCE_CLOSEOUT_20260906.json`. No universe, profile or live config was populated.
- `scripts/monitor_health_snapshot.ps1` distinguishes observation/generation time, explicitly unknown date-only feeds, future timestamps and runtime revision. Missing/stale evidence stays visible. This change does not install or switch a scheduled producer.
- `provider_cli_preflight.ps1` parses CLI help offline. `launch_worker.ps1 -ValidateOnly` checks argument construction without starting a worker; supplied help fixtures are permitted only in that mode. Actual launches require the native executable and its own compatible help/version. `-Model gpt-5.6-sol -ReasoningEffort low` supplies task-scoped overrides without changing global defaults. Other allowed model names are input validation, not availability proof. CLI compatibility does not prove model resolution, auth, billing, or reviewer competence. Gemini/Hermes M2 qualification remains separate.

## Still blocked or deliberately parked

The existing owner-operated Antigravity static selector review is task-qualified: the independently graded M2-AQ01 exercise and actual response/patch hashes bind to local generation metadata for gemini-3.8-flash. This retrospective admission used no new model request. IDE OAuth is the implemented route with observed-session use inferred; billing/free-tier stays unverified and gates future agent-issued requests. IDE/client versions and the captured final response explicitly replace an inapplicable standalone CLI process exit. This does not qualify unattended/API routing or the whole provider M2. The bounded patch is now integrated; another identical reviewer response is unnecessary; GPT actors still cannot substitute for different-family review. Evidence: `portfolio/SYSTEM_CONVERGENCE_TEMPLATE_REVIEW_20260906.json`. Real Profile/Universe membership and downstream config selection need their own reviewed contract. Second Brain unresolved semantics and KINT-001 are not silently resolved. Historical news coverage/available-at provenance and EA replay are not yet qualified. Part B heartbeat and ORDER-353/VPS retain their existing blockers and owner deferral. No risk/default, runtime attachment, scheduled-task, trading, optimization, HOLDOUT or Candidate change is made.

Mobile/PWA stays parked until its upstream producer/delivery requirements are met. Reuse the existing lifecycle register (5,275 inventory facets with original timestamps), not a new scan: age/name alone never establishes disuse, and no archive/delete action is granted. Future cleanup requires consumer/reference checks, unique-content/evidence preservation and rollback proof for each selected directory.

## Validation

Focused suites: `run_context_packet_identity_tests.ps1`, `knowledge_os_tests.ps1`, `test_resume_work.py`, `long_job_runner_tests.ps1`, `run_truncation_evidence_tests.ps1`, `run_truncation_message_tests.ps1`, Hermes executor tests, `run_knowledge_validation_tests.ps1`, monitor-health/integrity, provider/launcher tests, template applicability, and existing Capability Scout tests. Supply explicit absolute `Root`/`RepoRoot` parameters to PowerShell runners. Portable Python is provisioned per worktree; Hermes MCP tests use its already installed Python environment. A real local Long Job ran only offline validation scripts and postconditions; no model or MT5 execution was involved.

A separate bounded read-only Codex launcher smoke on clean pushed base `749da682d03615761cda7a46b31a663ad0b306f5` completed with exit 0 and postcondition 0. The client reported `codex-cli 0.144.2`, ChatGPT OAuth, `gpt-5.6-sol` and `low`; it returned the expected sentinel and left that worktree unchanged. This qualifies that read-only client/launcher path only, not write execution, Gemini, Hermes migration or different-family review.

Audit/output contract and receipts remain in the owning task's `outputs/system_convergence_20260906` area. They distinguish fixture results, source-bound read-only observations, unaccepted patches and runtime activation. No offline pass should be presented as whole-system production acceptance.

## Owner continuation checkpoint

The scoped tooling milestone is complete. Use `docs/workflows/EA_LAB_OWNER_HANDOFF_20260906.md` for the mobile Control Tower intake and next dependencies. Re-resolve pushed origin/master before decisions. AJV fixture transport was measured at 14.305s before / 6.252s after with identical 143-case output. Immutable-history caching preserves per-repository/per-runner boundaries and never caches failed or mutable-ref reads. Six existing runners are now explicitly UNMEASURED for incremental full-tier cost; classification is not automatic wiring. After a 98.6s all-green registry selection exceeded 90s, the owner approved the separately reviewed per-path ceiling 90 -> 110s for all selections; the full-tier ceiling remains 195s. This is a latency-policy amendment, not a measured execution speedup. Combined per-path latency remains a capacity consideration, not grounds to weaken a gate.
