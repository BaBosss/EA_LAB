# EA_LAB Standard Conveyor Belt Pipeline

Status: `PROCESS ROUTER / NO NEW AUTHORITY`
Authority: this document only maps the existing canonical research, optimization, reporting, verdict, and deployment owners into one numbered end-to-end flow.

It does **not** create numeric sample floors, Grade mappings, risk defaults, HOLDOUT authority, Candidate authority, DEMO/LIVE authority, or a second verdict system. `KINT-001` remains OPEN.

Canonical owners remain:
- research method: `docs/research/EA_RND_PROTOCOL.md`;
- optimization: `ea_template/OPTIMIZATION_PROCEDURE_V2.md`;
- report ladder/schema: `docs/research/EA_REPORT_LADDER.md` + `EA_REPORT_SCHEMA.md`;
- regime attribution: `docs/research/EA_REGIME_FRAMEWORK.md`;
- verdict/deployment bars: `CLAUDE.md` and the current project owners it references;
- permissions/hard stops: `AGENTS.md`;
- current status: `PROJECT_STATE.md`.

## Standard 14-step flow

| Step | Stage | Search surface | Required outcome before next step |
|---|---|---|---|
| 1 | Identity / Baseline Freeze | none | exact source/build/set/profile/tester identity |
| 2 | Baseline MAIN+BWD | fixed config | interpretable parent evidence; mechanical failures separated |
| 3 | Broad Portability Screen | fixed config across Symbol×TF | locate evidence-bearing homes without tuning |
| 4 | Mechanism Characterization | one logical change per variant | explain material entry/exit/stack/recovery/direction/risk mechanisms |
| 5 | Lead Confirmation / Portability | fixed qualified child | confirm whether the lead repeats outside its discovery cell |
| 6 | Optimization Contract | none | freeze causal parameters, semantics, safe ranges, objective and loop breaker |
| 7 | WIDE / COARSE Optimization | MAIN only | broad landscape map; normally Fast Genetic when the space is large |
| 8 | Region → Medium → Fine / Neighbours | accepted MAIN region only | stable plateau center plus local-neighbour evidence |
| 9 | Robustness + Sensitivity Validation | locked center/near neighbours | BWD, year/regime, participation, exposure, risk and pre-HOLDOUT sensitivity/stress evidence |
| 10 | HOLDOUT | one frozen finalist | late untouched evidence; never a tuning or rescue surface |
| 11 | Post-HOLDOUT Fidelity | holdout-passed finalist only | MC, required Model-4/real ticks when due, and fill/correlation confirmation |
| 12 | Candidate Dossier | no search | full report/graphs/workflow plus portfolio/correlation routing |
| 13 | DEMO Forward | no research search | owner-approved attachment plus pre-registered judge/kill evidence |
| 14 | LIVE Decision | no search | owner decision after required DEMO evidence and independent review |

**Backtest/R&D completion boundary:** Step 12. Steps 13–14 are deployment/forward-evidence stages and cross owner hard stops.

## Search-mode rule

Steps 1–5 answer **what the strategy is and why it behaves that way**. They use fixed configurations or one-logical-change causal tests. Do not substitute a multi-parameter optimizer for causal attribution.

Steps 6–8 answer **where a stable parameter region exists**. This is where optimization belongs:

`SEMANTIC/RANGE FREEZE -> FAST GENETIC WIDE/COARSE -> REGION_SELECT -> MEDIUM_REFINE -> BOUNDED COMPLETE FINE/NEIGHBOUR GRID -> LOCK CENTER`

Fast Genetic is preferred for a large preregistered coarse space because it cheaply explores the landscape. Its best row is never an automatic winner. The coarse output is consumed to identify stable regions, boundary pressure, participation and unsafe zones.

The accepted region is then refined. Final center selection uses bounded complete-grid/neighbour evidence where tractable so local stability is observed directly rather than inferred from a genetic winner.

BWD, regime evidence and HOLDOUT are not iterative optimizer surfaces. BWD and the sensitivity/stress fan validate a locked center before HOLDOUT. HOLDOUT is spent at Step 10 only after a genuinely qualified finalist is frozen; MC and required Model-4 fidelity follow at Step 11.

## Stage contract template

Every transition records: exact base SHA; parent/child identity; hypothesis/direct consumer; changed and frozen semantics; windows/model/install; allowed search surface; falsifier/acceptance; evidence outputs; authority ceiling; loop breaker; next transition.
## Transition and loop-breaker rules

1. Mechanical/harness/environment failure is classified separately and never becomes a strategy loss.
2. Same unresolved question twice => `UNKNOWN/BLOCKED`; stop expansion until the missing prerequisite changes.
3. One causal/mechanism child = one logical change. A multi-parameter optimizer belongs only after Step 6 freezes the causal surface.
4. Do not widen ranges or invent a new objective after seeing a target result without a new prospective contract.
5. Genetic/coarse survivors are regions, not Candidates. Reject top-1 spike selection.
6. BWD may invalidate or qualify a locked center but must not be repeatedly mined to pick parameters.
7. HOLDOUT is late and irreversible evidence; do not use it for rescue optimization.
8. Preserve negative experiments and contradictory years/regimes in the durable report.
9. A stage may PARK a family even when mechanism value is high; evidence quality, strategy quality and portfolio value remain separate axes.
10. Any deployment/runtime attachment, DEMO→LIVE, trading, risk/default change, or other owner hard stop remains outside automatic conveyor authority.

## B16 example mapping at canonical adoption

B16 demonstrates both normal progression and an evidence-driven early stop. Steps 1-4 are complete: identity/baseline, broad MAIN+BWD portability, position-engine confirmation, and reviewed mechanism characterization. Step 5 is also complete: fixed GBPUSD SELL H1/M15 portability classified the strong H4 SELL lead as `H4_LOCAL`.

A separate prospective `B16-H05-r1` child then opened Step 6 and a bounded Step-7 entry-surface search on GBPUSD/H4 SELL. Fast Genetic/complete coarse evidence found one preregistered positive interior five-cell RSI cross at 21/70, but fixed MAIN+BWD validation showed materially lower participation and economic output than the accepted 14/70 parent. Decision: `DO_NOT_ADOPT_CENTER_RETAIN_PARENT_RESEARCH_REFERENCE`.

The B16 child therefore stops before medium/fine adoption, HOLDOUT, Candidate, DEMO, or LIVE. This is a valid conveyor outcome: a stage may close as `PARK / RESEARCH_ONLY` when its direct consumer is satisfied and further search has no current downstream value. Any B16 continuation now requires a new prospective structural-mechanism consumer; it may not reopen the exhausted RSI-entry search, mine BWD for retuning, or spend HOLDOUT automatically.

## Execution-efficiency pointers

The conveyor defines stage order; use these execution/reporting fast paths without changing stage authority:

- reliable worktree/worker/reviewer orchestration: `scripts/execution_reliability/` + `docs/LONG_JOB_RUNNER.md`;
- report generation and evidence packaging: `docs/research/EA_REPORT_AUTHORING_FASTPATH.md`;
- final methodology/process self-audit: `docs/research/EA_MILESTONE_SCRUTINY_CHECKLIST.md`.

For Step 7, prefer Fast Genetic when the preregistered MAIN coarse space is large; keep the causal surface small enough to interpret, then use bounded complete neighbours at Step 8. The exact number of parameters/ranges remains experiment-contract specific—this router creates no universal range or parameter-count rule.

If a stage already answers its direct consumer with `PARK`, `BLOCKED`, or a non-improving result, stop instead of generating downstream optimization/reporting work with no current consumer.
