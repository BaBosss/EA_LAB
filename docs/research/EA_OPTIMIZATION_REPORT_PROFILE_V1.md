# EA_LAB Optimization Report Profile V1

Status: `CANONICAL REPORT PROFILE / OPTIMIZATION SEARCH / NO NEW AUTHORITY`
Authority: presentation/reporting profile only. `ea_template/OPTIMIZATION_PROCEDURE_V2.md`, `EA_RND_PROTOCOL.md`, `EA_REPORT_SCHEMA.md`, the exact preregistered optimization contract, and accepted evidence remain authoritative.

## Purpose

Use this profile for an **optimization/search milestone**, not for a single frozen configuration.

The report must explain the search surface and why a stable center/region was selected. A Top-1 PF cell is never an automatic winner.

A selected center may later receive its own Single-Config report, but the optimization report remains the owner of search-surface evidence.

## Required reading order

Recommended section order:

`Optimization Front -> Search Contract -> Parameter/Lattice Map -> Search-Surface Visuals -> Stability/Plateau Map -> Boundary Pressure -> Candidate Region -> Complete Neighbours -> Selected Center -> Frozen Parameters -> Fixed BWD -> Model4 MAIN+BWD -> Sensitivity/Robustness -> Evidence/Interpretation/Decision -> Known Unknowns -> Traceability`

The first pages must answer:
- what was optimized and why;
- what remained frozen;
- exact search ranges/steps and number of cells;
- whether search was Complete or Genetic;
- where stable regions exist;
- why the selected center is not a spike;
- what downstream validation remains.
## Search-contract section

The report must show the prospective search contract before presenting results:
- exact parent/config/build identity;
- MAIN search window;
- optimized parameters and semantic reason for each;
- exact min/max/step or discrete values;
- frozen parameters and mechanisms;
- expected total cells / search mode;
- eligibility/mechanical gates;
- selection rule and stop rule;
- BWD / Model4 / HOLDOUT authority state.

Do not hide a change of parameter semantics behind a numeric range. Unknown semantics are `SEMANTICS_REQUIRED / BLOCKED`, not an optimization input.

## Mandatory optimization visuals

Prefer visuals that reveal topology rather than only rank:
- 2D heatmap / surface for two important dimensions;
- ranked cells with participation/exposure context;
- plateau/stability region map;
- selected-center plus immediate neighbour table;
- boundary-pressure markers;
- mandatory R3 PF/return-versus-DD view required by EA_REPORT_LADDER.md;
- additional trade-off views such as net vs participation or stability vs exposure when useful.

Genetic output is a region map. It may narrow the region, but the report must distinguish sampled genetic cells from completed bounded neighbours.
## Selection and downstream validation

The report must record why the selected center was chosen:
- stable region membership;
- immediate-neighbour behavior;
- distance from fragile/boundary cells;
- participation/exposure sanity;
- absence of hindsight use from BWD/HOLDOUT.

After selection, freeze the center. Then report downstream validation separately:
- fixed-config BWD;
- mandatory Model4 MAIN+BWD when Candidate eligibility is in scope;
- direct-question sensitivity or Monte Carlo only when contractually authorized;
- HOLDOUT only at its protected late gate.

BWD and HOLDOUT are not optimizer surfaces. A BWD failure does not authorize retuning inside the same search contract.

## Optimization decision card

The owner-facing conclusion should state one of the bounded outcomes appropriate to the contract, for example:
- stable region found / center frozen;
- no stable region found;
- boundary pressure requires a separately preregistered bounded expansion;
- center rejected on fixed BWD;
- evidence incomplete due to harness/environment failure.

Preserve negative evidence and distinguish strategy evidence from mechanical/harness failure.

## Reuse rule

Optimization report binaries are outputs. Reusable truth is the preregistered contract, machine search table, stable-region/neighbor computation, frozen-center identity, validation evidence, and this profile. Before finalizing, run `EA_REPORT_VISUAL_QA_CHECKLIST_V1.md`.