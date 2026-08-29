# EA_LAB Research Report Ladder

Status: CANONICAL RESEARCH REPORTING CADENCE
Authority: reporting/evidence presentation only; does not grant verdict, optimization, HOLDOUT, deployment, runtime, risk, or promotion authority.

## Purpose

Every EA_LAB experiment is research, but not every experiment deserves a full production dossier.
This ladder makes research durable without turning every tester batch into documentation overhead.

The rule is:

> Every evidence-producing step emits a research record. Graph depth escalates with decision impact. A Candidate/DEMO/LIVE transition requires the full graph pack.

The reporting unit is normally an **experiment/batch/milestone**, not each individual cell. Raw per-cell evidence remains machine-readable; the report aggregates it into a decision-useful view.

## R0 — Hypothesis / preregistration record

Use before evidence generation.

Mandatory:
- Family / Variant / Parent;
- one logical change;
- observation from parent;
- hypothesis;
- expected benefit and expected cost;
- frozen mechanics vs changed mechanics;
- universe / Symbol / TF / config shapes;
- evidence windows;
- exact metrics to collect;
- falsifier / stop condition;
- direct consumer;
- authority ceiling.

Graphs: **NONE REQUIRED**.
A workflow diagram is recommended when the mechanics cannot be understood from a short paragraph.

Purpose: prevent hindsight explanation and post-result range invention.

## R1 — Discovery / broad-screen report

Use for fixed-config concept discovery, MarketWatch sweeps, broad Symbol x TF matrices, and coarse multi-config probes.

Mandatory machine evidence per cell:
- exact identity/config;
- PF;
- trades/baskets/independent episodes as appropriate;
- net;
- equity DD;
- expectancy when available;
- active months / time participation when derivable;
- long/short split when applicable;
- mechanical status.

Mandatory visual pack:
1. **Symbol x TF heatmap** for PF or the primary edge metric;
2. **Participation heatmap** or equivalent opportunity-count view;
3. **PF vs participation scatter** with cells identifiable;
4. **DD heatmap/scatter** when DD is meaningful at this stage.

Mandatory classification:
- `NO_PULSE`;
- `ISOLATED_PULSE`;
- `CLUSTERED_PULSE`;
- `STRONG_MECHANISM_PULSE`;
- plus `EMPTY` / `MECHANICAL_FAIL` where applicable.

R1 is discovery, not Candidate selection.
A high-PF low-frequency cell is not discarded by presentation alone; it is flagged for strategy-specific sample interpretation and mechanism follow-up.

## R2 — Mechanism / rescue / build-on report

Use when a pulse exists and the research question becomes "what part works?" or when a bounded rescue tests a diagnosis-backed lever.

Mandatory additions:
- parent vs child delta;
- Direction / Entry / Filter / Exit / Position Engine / Recovery / Risk attribution where applicable;
- what changed and what remained frozen;
- cell-level vs concept-level interpretation;
- reusable mechanism finding;
- next child hypothesis.

Mandatory visual pack for selected cells:
1. equity curve;
2. underwater/equity-DD curve;
3. year or month distribution;
4. long vs short or mechanism-on/off comparison when relevant;
5. parent vs child comparison chart.

Required assessment field:
`MECHANISM_VALUE = STRONG | PROMISING | UNCLEAR | WEAK | EXHAUSTED`

This field is research interpretation only and does not replace canonical verdict vocabulary.

## R3 — Optimization surface report

Use only after the strategy/variant is authorized to optimize under a preregistered range contract.

Mandatory additions:
- optimized parameters;
- semantic reason for each parameter;
- exact lattice/range;
- stage: COARSE / REGION_SELECT / REFINE / SENSITIVITY;
- number of cells;
- boundary state;
- selected region and center rationale;
- participation overlay;
- unsafe/excluded region.

Mandatory visual pack:
1. parameter heatmap or surface;
2. neighbor-stability view;
3. boundary-pressure view;
4. PF/return vs DD trade-off view;
5. participation overlay;
6. selected plateau center visibly marked.

Never report only Top-1 PF.
The report must make spikes, plateaus, empty regions, sample collapse, and boundary pressure visually obvious.

## R4 — Robustness / finalist research report

Use after a stable region/locked center exists and the strategy enters serious robustness evaluation.

Mandatory additions:
- MAIN vs BWD;
- year split;
- regime split when available;
- Model-1/Model-4 status as required;
- Monte Carlo status;
- execution/broker portability status;
- HOLDOUT state;
- concentration / tail-risk observations;
- strategy-specific sample-adequacy statement.

Mandatory visual pack:
1. MAIN vs BWD equity comparison;
2. MAIN vs BWD DD comparison;
3. yearly return/PF/trades view;
4. regime matrix/timeline when regime evidence exists;
5. return/trade concentration view;
6. Model comparison when applicable;
7. MC PF/DD/ruin distribution when run;
8. sensitivity fan / neighbor stability carried forward.

R4 must explicitly say what remains `NOT RUN`.
Missing evidence is visible; it is never silently converted to PASS or FAIL.

## R5 — Candidate / DEMO admission dossier

This is the first **FULL GRAPH PACK** gate.

A strategy cannot be presented as Candidate/DEMO-ready without this dossier.

Mandatory overview:
- exact identity / version / source / set;
- Home / Symbol / TF;
- hypothesis lineage;
- current verdict;
- QUALITY_GRADE state;
- EVIDENCE_CONFIDENCE state;
- BUILD_POTENTIAL;
- Known Unknowns;
- HOLDOUT state;
- deployment blockers.

Mandatory Full Graph Pack:
1. equity curve;
2. balance curve when distinct/available;
3. underwater DD curve;
4. monthly P/L heatmap;
5. year-by-year result chart;
6. MAIN vs BWD comparison;
7. PF / expectancy / participation by period;
8. win/loss distribution;
9. MFE/MAE when available;
10. holding-time distribution;
11. long/short split;
12. session/time distribution when relevant;
13. loss/win streak distribution;
14. worst-trade or worst-basket tail view;
15. recovery-duration distribution;
16. exposure over time;
17. parameter surface / plateau;
18. neighbor stability;
19. regime matrix/timeline;
20. Model-4 comparison when required;
21. Monte Carlo distribution when required;
22. correlation/cohort view when portfolio admission is in scope;
23. profit concentration by top trades/month/year;
24. broker/portability view when available.

Grid / recovery / multi-position mandatory extras:
- simultaneous positions over time;
- lot ladder;
- aggregate lots/exposure;
- depth distribution;
- grid span;
- basket duration;
- hard-cage/kill events.

Mandatory diagrams:
- strategy logic workflow;
- state machine when stateful;
- risk/position-engine diagram for grid/recovery/multi-position or otherwise non-trivial sizing.

## R6 — DEMO / LIVE observation report

Use after an authorized runtime attachment.

R6 does not replace R5. It adds forward evidence.

Mandatory visual pack:
- live/forward equity and DD;
- rolling PF/expectancy where statistically meaningful;
- trades/baskets over time;
- exposure/lot/depth over time where relevant;
- kill/guard events;
- slippage/spread/execution observations when available;
- pre-registered judge progress;
- backtest vs forward comparison.

For LIVE consideration, the current R5 dossier must still be valid against the exact strategy/config lineage and R6 must contain the full available forward evidence.

## Graph generation rule

Graphs are evidence views, not authority.

Every graph must:
- identify exact evidence source/run/batch;
- show the relevant denominator/sample next to performance where practical;
- distinguish missing/empty/mechanical-fail cells;
- avoid smoothing that hides tails or sparse participation;
- avoid changing the decision rule through visualization;
- remain reproducible from machine-readable evidence.

For low-frequency strategies, charts should emphasize time/regime/opportunity coverage rather than forcing a high-frequency visual grammar.
For grid/recovery, chart independent baskets/episodes and exposure, not just order tickets.

## Report escalation rule

Do not generate R5-level graphs at R0/R1 unless they answer the current question.
Do not withhold R5-level graphs when Candidate/DEMO/LIVE is being considered.

A later report may reference earlier accepted graphs when the exact evidence identity is unchanged. Do not regenerate accepted evidence merely for cosmetic completeness.

## Research continuity rule

A PARKED/weak standalone EA may still carry valuable mechanism evidence.
Before closing a research branch, preserve:
- what mechanism appears useful;
- what failed;
- whether the failure is CELL, HOME, or broader CONCEPT evidence;
- what child variant could consume the useful mechanism.

The report should help the next researcher answer:
"What did we learn and what is the highest-information next experiment?"