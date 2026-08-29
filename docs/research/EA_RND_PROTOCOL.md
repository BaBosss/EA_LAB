# EA_LAB EA R&D Protocol

Status: CANONICAL RESEARCH-METHOD OWNER
Authority: research/process contract only; no runtime, deployment, trading, risk/default, HOLDOUT-use, or owner-attestation authority.

## Purpose and ownership

This file owns **how EA research and Boss-family variant development are performed**. It does not own current project state, worker authority, raw evidence, or reusable research knowledge.

Canonical neighbors:
- authority / worker boundaries: `AGENTS.md`;
- current accepted state: `PROJECT_STATE.md`;
- active queue: `AGENT_TASKBOARD.md` + `taskboards/active/*`;
- regime definitions: `docs/research/EA_REGIME_FRAMEWORK.md`;
- mandatory report fields: `docs/research/EA_REPORT_SCHEMA.md`;
- family experimental history: family Evolution Ledger;
- reusable research knowledge: `knowledge/*` Second Brain (non-authoritative research layer);
- raw/accepted evidence: the existing evidence owners referenced by each experiment.

## 1. Family / variant lineage

A family may have many variants. **One variant = one logical experimental change.**

Example:
```text
19-0  base/reference
 |- 19-1  one MACD-alignment hypothesis
 |- 19-2  one ER hypothesis
 `- 19-3  one pullback hypothesis
```

A child does not automatically inherit other children. A rejected `19-1` does not force `19-2` to use `19-1` as parent.Every variant record must declare:
- Family and Variant ID;
- Parent;
- Change;
- observation from parent;
- hypothesis and expected benefit/cost;
- frozen mechanics and changed mechanics;
- pre-registered evidence contract;
- measured evidence and parent delta;
- interpretation;
- decision;
- lesson;
- next hypothesis.

Hypothesis and decision fields must exist **before** the result they are meant to judge. Missing semantics remain `UNKNOWN / UNRESOLVED`; do not fill them from hindsight.

## 2. Canonical research loop

```text
Base Concept
 -> Freeze Hypothesis
 -> Build / Compile / Mechanics tests
 -> fixed-config smoke
 -> broad Symbol x TF matrix
 -> regime attribution
 -> parent comparison
 -> survivor-only deep optimization
 -> WIDE/COARSE
 -> REGION_SELECT
 -> MEDIUM_REFINE
 -> FINE / neighbor stability
 -> locked center
 -> exposure/risk report
 -> BWD + regime validation
 -> sensitivity / required Model-4 / MC
 -> HOLDOUT late
 -> Candidate
 -> DEMO only under owner authority
```

Failure at an intermediate gate does not erase research value. Always record `Observation -> Interpretation -> Next Hypothesis` and preserve mechanical/harness failures separately from strategy evidence.## 3. Broad smoke before deep optimization

Broad smoke is a **fixed-configuration research screen**, not candidate ranking and not a parameter search.

Current Boss19 research design (family-specific; not a universal project default):
- Symbols: `XAUUSD, EURUSD, GBPUSD, AUDUSD, USDJPY, BTCUSD`;
- TF: `M15, H1, H4`;
- MAIN: `2023-01-01..2025-12-31`;
- BWD: `2020-01-01..2022-12-31`;
- HOLDOUT `2026H1`: untouched during broad R&D.

Broad-screen classifications:
- `GREEN`: promising/consistent enough for deeper work;
- `YELLOW`: measurable pulse but regime-specific, participation-limited, or uncertain;
- `RED`: weak/loss/failure as strategy evidence;
- `EMPTY`: insufficient participation to interpret;
- `MECHANICAL_FAIL`: execution/harness/environment failure, not strategy evidence.

Do not apply unresolved `KINT-001` sample-floor semantics as an automatic kill switch for broad smoke. Record actual participation and evidence quality. Canonical production/verdict gates remain separate until explicitly migrated.

## 4. Optimization: coarse to fine

Parameter ranges are **hypothesis-specific** and must be pre-registered before results.

1. `WIDE / COARSE` — map the broad landscape.
2. `REGION_SELECT` — identify plateau, boundary pressure, participation and unsafe regions.
3. `MEDIUM_REFINE` — refine only inside an accepted region.
4. `FINE / NEIGHBOR_STABILITY` — select a center with local stability, not the single best row.
5. `SENSITIVITY / ROBUSTNESS` — survivor-only stress of the selected region.The optimizer finds **interesting regions**. It does not have authority to declare one exact row the best strategy.

Selection must consider at least:
- plateau shape and neighbor stability;
- boundary pressure;
- participation;
- drawdown/tail behavior;
- exposure;
- BWD behavior;
- regime behavior;
- execution-quality requirements applicable to the strategy.

A boundary hit may permit **one bounded expansion** when the experiment contract says so. Repeated same-boundary pressure stops automatic widening. Never manufacture an optimum by widening indefinitely.

No historical narrow range becomes universal truth merely because it was used before. For future Boss19 spacing research, the old `StepATR=0.20..0.40` surface is evidence history, not a global domain. Any wider lattice (for example an owner-conceptual ATR-spacing region around `0.4..2.0`) must be normalized and pre-registered before execution; exact endpoints/steps may not be chosen after seeing results.

## 5. HOLDOUT

HOLDOUT is an expensive, irreversible evidence resource.

Do not use HOLDOUT for:
- base-concept smoke;
- every child variant;
- routine tuning;
- coarse/medium/fine search.

Use it only after a genuinely qualified finalist reaches the HOLDOUT gate under current owner/hard-stop authority. Boss19 `2026H1` is currently **UNSPENT**.

## 6. Evidence discipline

Keep evidence and interpretation separate:
- evidence = exact run/config/report/metric/provenance;
- interpretation = what those facts suggest;
- decision = the bounded action authorized by the contract.

A harness/environment failure is not strategy evidence. Missing evidence reduces confidence; it does not automatically prove failure. Negative experiments remain reusable evidence and should be linked into existing experiment/negative-memory owners rather than erased.## 7. Control Tower / Hermes split

ChatGPT Control Tower owns research architecture, hypothesis/experiment design, interpretation, dispatch, integration and decisions inside already owner-approved scope.

Hermes is a **mechanical evidence factory**. It may execute only an exact approved contract: deterministic manifests, approved local backtests/batches, report normalization, completeness checks, year/regime aggregation, parent-vs-child comparison, and pre-registered optimization stages. Its detailed qualification boundary is owned by `tools/hermes_ea_lab_pilot/README.md`.

Hermes may not invent hypotheses, widen ranges, change parent mechanics, choose HOLDOUT, change risk/defaults, deploy/attach runtime, trade, promote a candidate, or convert a mechanical failure into a strategy verdict.

## 8. Reports and visuals

Every evidence-producing step is research and must leave a durable research record, but reporting depth follows `docs/research/EA_REPORT_LADDER.md` rather than forcing a full production dossier after every tester batch. Discovery gets compact aggregate graphs; mechanism/optimization/robustness add decision-specific visuals; Candidate/DEMO requires the full graph pack.

Every serious variant report must satisfy `docs/research/EA_REPORT_SCHEMA.md`. Grid/multi-position systems must expose position count, lot ladder, aggregate lots/exposure and grid span; PF/DD alone are insufficient.

Per-EA workflow continuity follows `docs/research/EA_WORKFLOW_DIAGRAM_STANDARD.md`. A mechanism claim or child-variant design should have a source-bound workflow view; Candidate/DEMO requires the applicable full strategy/state/risk diagram set. Numeric evidence changes do not require redrawing unchanged mechanics.

When architecture, workflow or strategy semantics are materially easier to understand visually, use the already-canonical Diagram Design layer through `skills/ea-workflow-diagrams`. Diagram output remains `VISUAL_ONLY_NO_AUTHORITY`; unresolved semantics must stay visibly unresolved.

## 9. Completion rule

A research lane closes by preserving:
`identity -> preregistered hypothesis -> exact evidence -> interpretation -> decision -> lesson -> next consumer`.

Do not promote a report, diagram, score, optimizer row, Second Brain synthesis, or Hermes output into project authority by presentation alone. Git pushed `origin/master` remains canonical bytes; `PROJECT_STATE.md`, `AGENTS.md`, and the taskboard retain their existing state/authority/queue roles.