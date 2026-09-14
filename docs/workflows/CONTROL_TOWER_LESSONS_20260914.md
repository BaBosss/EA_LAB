# Control Tower Lessons and Corrections — 2026-09-14

Purpose: reusable operational lessons from the Arxon / Registry / Reporting / Forward Alpha / Monitor continuation, with explicit evidence and repair state. This is documentation, not a new governance, research-verdict or runtime authority owner. AGENTS.md and subject-specific contracts still govern.
Verified source baseline: `1ff95c92ed12caaf75493e4140502320748bca69`. Consumer: `ORDER-CT-POSTMONITOR-INTAKE-20260914`, future exact-head integration and owner context replacement.

## 1. What was corrected in this rotation

- CLOSED applies to delivered Monitor source/state and the completed Reporting/intake/Forward Alpha source-gap scopes. It does not mean the real Forward Alpha adapter/panel or rejected Master Registry passed. The earlier broad chat closeout must not be used as whole-pipeline acceptance.
- Monitor state review for `1ff95c92...` is PASS / **medium-high** confidence, not HIGH. The reviewer used existing records and disclosed unavailable raw post-repair test/hook logs. Source: `D:\EA_LAB_CONTROL\evidence\monitor-dashboard-merge-r3-20260914\STATE_REVIEW.txt`. No historical review bytes are edited or upgraded.
- A fetched/ls-remote-matched SHA proves remote presence, not who pushed it. The earlier assertion that another Control Tower pushed the Monitor commit was not established by those observations. Retain verified remote identity; leave actor attribution UNKNOWN unless separately evidenced.
- Explicit RegistryRoot/RepoRoot and readback resolved the operational lane lookup blockage. That is not enough by itself to prove the entire prior phantom-writer root cause; do not promote an invocation hypothesis to proven RCA without recorded arguments/root comparisons.
- No runtime/deletion change was made by the Monitor repo-only consolidation or by this rotation. That must not be generalized to all other chats: a separate 19:28+07 dashboard-retirement receipt reports removals and needs its own ownership/authority reconciliation.
- Arxon Stochastic is a source-backed planning lead, not an accepted experiment, selected parent, parity implementation or result. The rejected Registry's proposed identifier/ranking is not research authority.

## 2. Applied lessons and exact consumers

### L01 — One writer, one canonical join
State: DOC_ROUTING_APPLIED; existing governance unchanged.
Before integration, compare current origin, candidate ancestry, exact changed paths and live lane ownership. If the exact commit is already canonical, do not cherry-pick/push it again. Verify pending state/queue independently. A lane rename/re-anchor does not reset the repair budget. Consumer: next Control Tower boot; sources: START_HERE.md and AGENTS.md.

### L02 — Pin every operational root and preserve encoding
State: DOC_ROUTING_APPLIED; no registry-tooling change.
Use the same explicit RegistryRoot and RepoRoot for Check/Get/List/Audit/Claim/Transition; read state before expected-state transitions. Use file-backed PowerShell when variables, pipelines or exit codes matter. Preserve BOM/newline style and fail on ambiguous text anchors before writing. Shell interpolation/parser failures are B_HARNESS_TEST, not evidence of product/strategy failure. Consumer: lane/commit scripts; sources: START_HERE.md §9 and Monitor continuation evidence.

### L03 — Progress must correspond to durable completion
State: DOC_ROUTING_APPLIED.
A process start is not success; exit 0 is not postcondition/review PASS. Inspect job output, exact HEAD, worktree state and result hashes before retrying. Resume completed cells, do not duplicate them. Tool-window expiry is D_EXECUTION_INCOMPLETE/checkpoint, not a product blocker. Consumer: Long Job / execution-reliability workflow; sources: docs/LONG_JOB_RUNNER.md and scripts/execution_reliability/.

### L04 — History is not active work
State: IMPLEMENTED_AND_REVIEWED in Monitor lineage ending `e88ed119...`.
Preserve sanitized DONE/CLOSED history separately; cumulative registry records are not concurrent agents, running processes or runtime health. Keep canonical taskboard status, noncanonical lane observations and runtime evidence distinct. Consumer: Work / Agent Graph / Detailed lanes. Sources: tools/mobile_report_hub/control_tower.py, mobile_report_hub/app.js and Monitor integration workflow.

### L05 — Missing/stale evidence is UNKNOWN, not zero
State: IMPLEMENTED_AND_REVIEWED in Monitor.
Recheck envelope observation time as well as row freshness. Stale/cached/offline/future/missing evidence must suppress current counts and owner actions; Current blocked=0 is not justified by an unqualified envelope. Keep historic counts labeled as historic. Consumer: Work/Alerts; source: tools/mobile_report_hub/tests/browser_v3.cjs and existing projection.

### L06 — Completeness is not trading quality
State: IMPLEMENTED_AND_REVIEWED in Monitor.
Factory 9/1/8 is a dated artifact-completeness observation. MISSING_ARTIFACT/INCOMPLETE_EVIDENCE does not mean loss, EA malfunction, strategy failure or runtime failure. Use source SHA/time/limits and safe relative report links; no new dashboard parser or second source of truth. Consumer: EA Lab / Alerts; source: docs/workflows/EA_LAB_MONITOR_CONTROL_DASHBOARD_INTEGRATION_V1.md.

### L07 — Verify sanitizer output, not its intention
State: IMPLEMENTED_AND_REVIEWED by `e88ed119a56c4e7ea1781d872202333149f3ea76`.
The bounded P2 repair covers Windows drive paths with either separator, file:// and UNC references, then fail-closes incomplete redaction before emitting successful metadata. The regression reproduces D:/EA_LAB/private/report.html. This is the accepted bounded path-leak repair, not a claim of universal HTML/security sanitization. Consumer: Factory artifact publisher; sources: _factory_report_artifact in tools/mobile_report_hub/build_index.py and its data regression.

### L08 — Existing process-local runtimes before installing dependencies
State: ENVIRONMENT_RESOLVED in the prior Monitor acceptance; no new install here.
Use scripts/use_python.ps1 + Assert-PortablePython -Provision in linked worktrees. Reuse verified installed Playwright/AJV with process-local NODE_PATH; do not change global npm/config or claim an environment failure is a product regression. Browser port failures require a bounded harness rerun, not weakened browser acceptance. Consumer: future Monitor tests; source: tools/mobile_report_hub/README.md and prior browser evidence.

### L09 — Model4 mention is not completed execution
State: OPEN_NOT_REPAIRED / A_PRODUCT_DEFECT; Registry contract repair budget exhausted.
Registry head `4f9cdd583dffde907191d721e93dcc6498e59f0d` passed 28 tests and validator 152/0, but the reviewer reproduced false EXECUTED for planned, blocked and negated RUN wording. Preserve NOT_RUN/BLOCKED/UNKNOWN unless affirmative source-bound completed evidence exists. Future work needs a separately accepted contract; do not patch or integrate the rejected importer under this rotation. Consumer: Registry intake; source: master-registry-v1-20260913/TARGETED_MODEL_STATE_REVIEW.txt in external evidence.

### L10 — Regenerated artifacts must bind the actual generator
State: OPEN_NOT_REPAIRED in the same rejected Registry package.
Pin source ref and exact generator bytes alongside artifact hashes. Regeneration alone does not refresh a stale tool hash in the receipt. Source SHA, generator SHA256 and produced bytes must describe the same accepted chain. Consumer: any future Registry generator/receipt contract; source: the second P2 in the same targeted recheck.

### L11 — Reporting acceptance has both content and visual gates
State: IMPLEMENTED_AND_REVIEWED in durable reporting package `75c4f910...`.
A FINAL filename, File Library reference or extracted text does not prove durable bytes or clean layout. Inspect every rendered DOCX/PDF page, preserve failed versions, and bind final/superseded artifacts by bytes/hash/source. Word conversion required usable-page-width image scaling and table fitting. Do not repeat already accepted QA without changed artifacts or a demonstrated defect. Consumer: report-authoring fast path; sources: EA_REPORT_VISUAL_QA_CHECKLIST_V1.md and portfolio/REPORTING_STANDARD_V1_DURABLE_ARTIFACTS_20260914.json.

### L12 — Hash identity and reproduction are different claims
State: DOCUMENTED_AND_ACCEPTED in Reporting.
Use SHA256/byte counts to locate each exact delivered binary. Reproductions can differ in container metadata or pagination; disclose the actual comparison. Here the dossier had 9/9 identical rendered pages, while the three-page optimization template had identical normalized text and disclosed page-2/3 pagination jitter, not pixel/binary equality. Missing accepted native equity stays UNAVAILABLE; never rerun MT5 just for a prettier picture or relabel replay as accepted evidence. Consumer: owner delivery/manifest verification; source: docs/research/examples/REPORTING_DURABLE_ARTIFACTS_20260914.md.

### L13 — Real Forward Alpha requires an honest pre-outcome source
State: SOURCE_GAP_CANONICAL; adapter and Alpha panel remain BLOCKED.
MRIS context, news calendars and deal histories are not qualified forward price evidence. Market time, availability time, ingestion time and file mtime are not interchangeable. Bind observation context before outcome and bind settlement independently; retain negative/open evidence. A source-gap contract is a valid limited deliverable, not successful adapter/Monitor implementation. Consumer: Forward Alpha qualification; source: docs/research/FORWARD_ALPHA_REAL_SOURCE_ADAPTER_CONTRACT_V1.md.

### L14 — Intake, discovery and semantics are separate gates
State: DOC_ROUTING_APPLIED; no new Arxon experiment.
Arxon intake is canonical but the backtest backlog still requires qualified parent/home and explicit event role/direction/timing/settings. Do not derive a trade rule or source-parity claim from an indicator description, nor reopen Black Tide session failure. Core-review competence is likewise task-scoped: historical Gemini reviews do not close general provider M2 or a new core gate. Consumer: next planning intake; sources: Arxon backtest plan, AGENTS.md and provider transition owner.

### L15 — Other-chat completion and deletion require reconciliation
State: INTAKE_REQUIRED, not a new cleanup authorization.
Keep each request in a canonical queue home; handoffs are locators, not orphan queues. Inspect exact local/canonical state before repeating work. Dated backup verification and DONE metadata are not blanket permission to remove a workspace or runtime task. The newer dashboard-retirement receipt must be reconciled separately from the Monitor repo-only milestone. Consumer: ORDER-CT-POSTMONITOR-INTAKE-20260914; sources: root-retirement DEEP_RESULTS.md and dashboard-retirement post_retirement.json (external, dated).

## 3. What changed versus what did not

Applied now: corrected context wording, current owner-status pointers, next-intake queue home, START_HERE lesson/rotation routing, and preserved review limitations. Supplied Project Context/Instructions are replacement snapshots for the owner to paste; no automated Project UI change is claimed.
Not changed: AGENTS.md approval boundaries, any core/strategy/risk code, Registry's rejected importer, real Alpha adapter, Monitor runtime/hosting/delivery, Scheduled Tasks, trading, HOLDOUT, native graphs or external recovery archives.
No new universal sample floor, grade threshold, Alpha qualification score, optimizer authority, Candidate eligibility exception or research verdict is created.
