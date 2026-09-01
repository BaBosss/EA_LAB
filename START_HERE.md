# EA_LAB START HERE

Purpose: deterministic startup router for every new EA_LAB Control Tower or worker session.

> This file is a router, not a second source of truth. Pushed GitHub `origin/master` is canonical. Chat history, copied handoffs, Project Operating Context, local dirty worktrees, and old lane records are context only until reconciled to the current pushed canonical bytes.

## 1. Boot sequence — always do this first

1. Resolve/fetch the current pushed `origin/master`.
2. Record the exact canonical SHA you are using.
3. Read this file from that exact ref.
4. Read `PROJECT_STATE.md` for current status, accepted decisions, blockers, and plan.
5. Read `AGENTS.md` before claiming or dispatching work.
6. Read `AGENT_TASKBOARD.md` and the relevant `taskboards/active/*` owner for current queue state.
7. Inspect Lane Registry before creating a writer/runtime lane: `scripts/lane_registry.ps1` + `D:\EA_LAB_CONTROL\lanes\registry-v1`.
8. Use an isolated clean worktree/explicit ref for canonical bytes. Never treat a dirty primary worktree/index as canonical.

If a handoff, Operating Context, or chat says a different SHA/status than pushed `origin/master`, re-anchor to Git first. Preserve the older artifact as history; do not silently promote it over canonical state.

## 2. Memory model

EA_LAB uses three memory layers:

- **Canonical Memory:** pushed repository bytes. This is the source of truth.
- **Boot/Snapshot Memory:** Project Instructions and Operating Context. These tell a new session how to find truth; they do not replace Git.
- **Transient Memory:** chats, worker reasoning, lane output, temporary files/processes. Useful during execution, but not durable authority by itself.

A decision made in chat is transient until it is migrated into its canonical owner and accepted/pushed. A worker result is not a new project fact merely because the worker says PASS; intake it against its contract and canonical state first.

## 3. Canonical owner router

### Project management / authority / queue
- Current status, accepted milestones, blockers, next plan: `PROJECT_STATE.md`
- Roles, permissions, hard stops, review/preservation rules: `AGENTS.md`
- Queue/intermediate task state: `AGENT_TASKBOARD.md` + `taskboards/active/*`
- Lane claims, one-writer/runtime ownership: `scripts/lane_registry.ps1`

### EA research / hypothesis / verdict
- Research method and evidence discipline: `docs/research/EA_RND_PROTOCOL.md`
- Regime attribution framework: `docs/research/EA_REGIME_FRAMEWORK.md`
- Current production verdict gate/vocabulary and deployment bars: `CLAUDE.md`
- Factory family/contracts/results: `docs/factory/` and the family-specific canonical artifacts referenced by `PROJECT_STATE.md`
- Do not turn a screening pulse into candidate/promotion authority without a separately preregistered downstream hypothesis.

### Reporting / graphs / workflow diagrams
- Report stages and when full graph packs become mandatory: `docs/research/EA_REPORT_LADDER.md`
- Canonical report fields: `docs/research/EA_REPORT_SCHEMA.md`
- Per-EA/source-bound workflow diagrams: `docs/research/EA_WORKFLOW_DIAGRAM_STANDARD.md`
- Diagrams are `VISUAL_ONLY_NO_AUTHORITY`; evidence and canonical contracts govern decisions.

### Optimization
- Canonical optimization procedure: `ea_template/OPTIMIZATION_PROCEDURE_V2.md`
- Optimization maps stable regions/plateaus; it is not permission to select a top-PF spike.
- Do not open optimization because a discovery screen is positive unless the current hypothesis/task contract explicitly unlocks it.

### Portfolio / control architecture
- Portfolio/control-system architecture: `docs/architecture/EA_LAB_PORTFOLIO_CONTROL_ARCHITECTURE_V1.md`
- Architecture defines EA -> Cluster -> Port -> Global Supervisor -> Human separation and ownership/state direction.
- Architecture alone does **not** authorize runtime activation, risk/default numbers, DEMO/LIVE changes, or trading.

### Deployment / monitoring
- Actual deployment inventory: `portfolio/DEPLOYMENTS.csv`
- Deployment/judge operating plan: `DEMO_DEPLOYMENT_PLAN.md` and exact canonical deployment owners referenced by `PROJECT_STATE.md`
- Never infer attachment or LIVE authority from research evidence.

## 4. Evidence hierarchy

When sources conflict, prefer in this order unless a newer explicit owner decision says otherwise:

1. current pushed `origin/master` exact bytes;
2. canonical owner document for that subject;
3. accepted, hash/source-bound evidence referenced by the owner document;
4. current Lane Registry/runtime evidence;
5. handoffs / Operating Context snapshots;
6. chat summaries and worker prose.

Do not rerun accepted evidence merely to rediscover it. Re-run only when a new contract requires a genuinely new observation, identity is invalid, or accepted evidence is unavailable for a required diagnostic.

## 5. Research execution default

Use deterministic/local tooling first:

`contract -> exact config/build identity -> runner/tester -> parser/validation -> machine-readable evidence -> aggregate/report -> review -> state convergence`

Use models only when they provide a unique output with a direct consumer. Repetitive Strategy Tester execution belongs to deterministic tooling, not a model waiting on MT5.

For non-trivial dispatch, declare runtime forecast, bottleneck, parallel safety, exact base/ref, allowed/forbidden scope, accepted evidence not to rediscover, investigation budget/loop breaker, acceptance, and authority ceiling.

## 6. Safety / preservation

- Preserve unrelated dirty, untracked, and staged work. Never reset/clean/stash it away.
- One acceptance-critical integration lineage has one active writer.
- Freeze a clean exact HEAD before review. Moving HEAD invalidates the old review.
- Mechanical/harness/environment failures are not strategy losses.
- Missing/ambiguous evidence is `UNKNOWN`/BLOCKED, not silently inferred.
- HOLDOUT is not a selection surface.
- Do not silently resolve open semantic conflicts such as `KINT-001` or owner-reserved strategy semantics.

## 7. Owner hard stops

Stop for owner approval before:

- deployment/runtime attachment;
- trading/real-money action;
- DEMO -> LIVE / LIVE changes;
- risk/default changes;
- consequential new strategy/risk semantics;
- owner signature/attestation;
- consequential governance/approval-boundary or scope change;
- QI-2+;
- destructive cleanup outside bounded fixtures;
- force push/history rewrite;
- irreversible strategic decisions.

Local Strategy Tester/backtests inside an approved research contract are not deployment/trading.

## 8. Integration and durable-memory rule

After a lane passes its contract:

1. intake evidence separately from interpretation;
2. classify PASS/BLOCKED with blocker class;
3. integrate only from clean exact lineage;
4. run impacted deterministic checks/regression;
5. obtain required independent review on the frozen HEAD;
6. synchronize the canonical owner/state/taskboard when needed;
7. fast-forward push when standing authorization gates pass;
8. verify final remote SHA;
9. only then treat the new decision/evidence as durable project memory.

Operating Context should be refreshed after material milestone/loop closure, but remains a **snapshot**. New sessions must always return here and re-resolve Git before consequential work.

## 9. Fast-path tools after boot

Do not rebuild orchestration helpers ad hoc when the canonical reliability pack already covers the need:

- exact clean worktree verification: `scripts/execution_reliability/bootstrap_worktree.ps1`;
- linked-worktree portable Python: dot-source `scripts/use_python.ps1`, then `Assert-PortablePython -Root <worktree> -Provision`;
- bounded Codex worker: `scripts/execution_reliability/launch_worker.ps1`;
- detached exact-head Claude review: `scripts/execution_reliability/launch_reviewer.ps1`;
- long-job status/recovery: `docs/LONG_JOB_RUNNER.md` + `scripts/long_jobs/`;
- report authoring: `docs/research/EA_REPORT_AUTHORING_FASTPATH.md`;
- milestone self-audit: `docs/research/EA_MILESTONE_SCRUTINY_CHECKLIST.md`.

Prefer file-backed PowerShell scripts over long inline `powershell -Command` expressions when variables, pipelines or `$LASTEXITCODE` matter; shell-wrapper interpolation is a harness risk, not research evidence.
