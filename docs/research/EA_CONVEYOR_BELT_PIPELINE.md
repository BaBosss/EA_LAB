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
| 9 | Robustness Validation | locked center/near neighbours | BWD, year/regime, participation, exposure and risk evidence |
| 10 | Execution Fidelity | survivor only | required Model-4/real ticks, stress/sensitivity and MC where applicable |
| 11 | HOLDOUT | one frozen finalist | late untouched evidence; never a tuning surface |
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

BWD, regime evidence and HOLDOUT are not iterative optimizer surfaces. BWD validates a frozen center; HOLDOUT is spent only after a genuinely qualified finalist reaches Step 11.

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

## B16 mapping at adoption

At canonical `b27b6bbdbef76a3076ba5058a8c43f4f1627f2af`, B16 has completed Steps 1–4: identity/baseline, broad MAIN+BWD portability, position-engine confirmation and the reviewed 88-cell mechanism characterization.

Step 5 is the next consumer: `HYP-B16-GBP-SELL-TFPORT-01`, exact frozen GBPUSD SELL child on H1 and M15 with MAIN+BWD fixed-config evidence. Its purpose is to classify the strong H4 SELL result as multi-timeframe portable, one-adjacent-timeframe portable, H4-local, or mechanically unknown.

A positive Step-5 classification does **not** itself start optimization. It only permits a separately preregistered Step-6 Optimization Contract. Step 7 then uses the canonical genetic-first coarse workflow on MAIN, followed by region/fine-neighbour validation.
