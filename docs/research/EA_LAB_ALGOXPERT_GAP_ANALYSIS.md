# EA_LAB vs AlgoXpert Alpha Research Framework â€” Gap Analysis

Status: `RESEARCH_ONLY / METHOD_GAP_ANALYSIS`
Source: Pham, Nguyen & Nguyen, *AlgoXpert Alpha Research Framework: A Rigorous ISâ€“WFAâ€“OOS Protocol for Mitigating Overfitting in Quantitative Strategies*, arXiv:2603.09219 (2026).
EA_LAB base reviewed: canonical `e9a3816775e1e2810ca99c55f349cdabc70d5348`.
Authority ceiling: research/process proposal only. This document does not change EA_LAB verdict, grade, KINT, optimization, HOLDOUT, risk, runtime, deployment, or trading policy.

## Why this paper is a high-ROI comparison

AlgoXpert targets the same failure class EA_LAB already cares about: a backtest that looks strong but fails under chronological validation, state carryover, execution friction, parameter sensitivity, or tail risk.

The paper's three-stage structure is:
`IS stability mapping -> purged rolling WFA -> strict OOS under parameter lock`.

Its source-level contributions include stable-region rather than single-optimum selection, cliff veto, restricted degrees of freedom, purge gaps, state normalization, fold-level forward gates, execution stress, safeguards, and safeguard ablation.

EA_LAB already overlaps strongly with the philosophy. The useful work is therefore a **delta**, not framework replacement.

## Gap matrix

| AlgoXpert element | Source claim / role | Current EA_LAB state | Classification | Bounded EA_LAB action |
|---|---|---|---|---|
| Plateau over single optimum | Prefer stable regions; avoid thin extrema | Canonical R&D protocol already says optimizer finds regions, not winners; R3 requires plateau/neighbor evidence | `ALREADY_PRESENT` | Reuse; no policy rewrite |
| Finite search budget / DoF disclosure | Report grid/trial budget and locking policy | EA_LAB reports exact ranges/cells and preregistration, but project-wide search-history disclosure is not always explicit | `PARTIAL` | Add future experiment field for search budget / materially distinct alternatives when consumer exists |
| One-step cliff veto | Reject configurations that collapse under minimal perturbation | Neighbor stability and boundary pressure exist; no common named cliff diagnostic | `PARTIAL` | Add optional diagnostic derived from existing neighbor surface; no universal thresholds |
| Parameter lock after stability selection | Prevent reopening search space in later stages | EA_LAB freezes selected center before BWD/HOLDOUT and forbids BWD retuning | `ALREADY_PRESENT` | Reuse |
| Purged rolling WFA | Train -> purge -> forward-test rolling folds | WFA is known in knowledge, but not a standard numbered canonical conveyor stage for every qualifying strategy | `GAP / OPTIONAL METHOD` | Define a bounded optional R4 methodology for stateful/path-dependent finalists |
| State normalization at each forward fold | Reset inventory/grid/trailing state to a canonical state before test | EA_LAB has execution/state evidence, but no general fold-boundary state-reset contract | `GAP` | Define explicit state-boundary semantics before any WFA experiment |
| Majority-pass across forward folds | Fold must meet precommitted benchmark; aggregate pass based on passing-fold proportion | No universal canonical fold gate | `GAP / DO_NOT IMPORT NUMERIC q` | If tested, preregister fold rule per experiment; do not create universal threshold here |
| Catastrophic veto | Immediate failure on severe constraint/risk integrity violation | EA_LAB has hard cages / mechanical invalid states / fail-closed controls | `PARTIAL STRONG OVERLAP` | Reuse existing safety owners; only add fold-context presentation if WFA exists |
| Zero evaluable folds => fail | Do not pass a WFA with no usable forward evidence | EA_LAB labels EMPTY/MECHANICAL_FAIL and keeps missing evidence visible | `CONCEPTUAL OVERLAP` | Preserve current evidence semantics; do not rewrite verdict vocabulary |
| Trainâ†’test degradation diagnostics | Diagnose resilience/decay without using it to tune/pass | EA_LAB compares MAIN/BWD/year/regime, but has no standard named degradation vector | `GAP / DIAGNOSTIC` | Add diagnostic-only trainâ†’test delta/resilience views where WFA consumer exists |
| Execution stress envelope | Inflate spread/commission / degrade fills | Broker portability/Model-4/execution evidence exists, but stress envelope is not a uniform stage | `PARTIAL` | Design strategy-specific adverse execution scenarios, never generic hidden defaults |
| Safeguard ablation | Disable one protection layer to measure marginal tail-risk contribution | EA_LAB already uses one-change ablation broadly, but safeguard ablation is not systematic | `PARTIAL / HIGH VALUE` | Use only when a safety layer's contribution is the explicit research question; never disable live safety |
| IS/WFA/OOS pass checklist | Auditable chronological decision gates | EA_LAB conveyor/report ladder already has staged gates | `ALREADY PRESENT / DIFFERENT VOCAB` | Map concepts, not AlgoXpert's decision labels |
| `Deploy / Reject / Refactor` states | Paper-specific decision output | EA_LAB has canonical verdict/governance vocabulary | `INCOMPATIBLE TO IMPORT` | Do not add these states |
| Paper minimum trade threshold `N_min` | Paper-specific feasibility filter | EA_LAB `KINT-001` remains OPEN; universal sample floor unratified | `DO NOT IMPORT` | Record participation; keep KINT unresolved |
| Paper plateau alpha default 0.9 | Paper-specific stable-region definition | EA_LAB has no universal 90% rule | `DO NOT IMPORT AS DEFAULT` | If ever used, preregister as experiment-specific and justify independently |
| Paper cliff thresholds | Paper-specific sensitivity limits | No EA_LAB universal cliff thresholds | `DO NOT IMPORT AS DEFAULT` | Treat cliff metric as diagnostic until separately ratified |
| OOS strict no tuning | Holdout only after lock | EA_LAB HOLDOUT is late/irreversible and BWD/HOLDOUT are not search surfaces | `ALREADY PRESENT` | Reuse |

## Highest-value additions

### A. Purged WFA for stateful/path-dependent strategies

This is the largest genuine method gap.

For a grid, trailing, recovery, or inventory strategy, a chronological split can still leak path state. Any future WFA contract should prospectively specify:

1. train window;
2. purge/embargo length and unit;
3. why that length covers relevant lookback/state contamination;
4. test window;
5. whether positions must be flat at test start;
6. exact reset state for grid level, trailing state, counters, persisted halt, and related state;
7. treatment of trades that would straddle the boundary;
8. fold-evaluable criteria;
9. fold metrics;
10. precommitted aggregate interpretation;
11. no-HOLDOUT rule while designing WFA.

No values are supplied here because choosing them requires the exact strategy consumer.

### B. Search-transparency packet

Future R3/R4 reports can benefit from a small provenance block:

- number of materially distinct hypotheses tried;
- number of parameter dimensions opened;
- search lattice / trial budget;
- shortlist size;
- whether the current candidate was selected after observing the same data;
- what later windows were kept blind.

This complements `knowledge/06_validation/multiple-testing-and-selection.md`.

### C. Degradation / resilience diagnostics

For rolling WFA, report trainâ†’test changes as diagnostics only. Candidate fields include:
- return/PF/expectancy delta;
- DD expansion;
- participation collapse;
- holding-time / exposure shift;
- cost sensitivity shift.

Do not turn a derived ratio into a new universal pass threshold without separate ratification.

### D. Execution-stress envelope

A future method can preregister adverse spread/commission/slippage/fill scenarios appropriate to the instrument and broker. The purpose is to identify the break point, not to optimize the strategy against the stress set.

### E. Safeguard ablation

EA_LAB's one-logical-change discipline is already suitable for this. A safeguard ablation is legal only as an offline research experiment under a bounded contract. It must never imply disabling a safety layer in DEMO/LIVE.

## Things explicitly not imported

- AlgoXpert's `Deploy / Reject / Refactor` vocabulary.
- A universal 90%-of-best plateau rule.
- A universal minimum trade count.
- Universal majority-pass or catastrophic-veto numeric thresholds.
- Universal purge-gap length.
- Any paper-specific leverage, drawdown, spread, or kill-switch number.

These would cross current EA_LAB semantics/governance boundaries or conflict with `KINT-001`.

## Recommendation

Adopt **conceptual method deltas**, not the paper's numeric policy.

Priority:
1. preserve current plateau/parameter-lock/HOLDOUT discipline;
2. add a research-only purged-WFA template for stateful strategies;
3. expose search degrees of freedom more explicitly;
4. add optional cliff/degradation diagnostics;
5. add execution stress and safeguard-ablation experiments only when they answer a concrete strategy question.

No current EA is automatically advanced, retested, optimized, or redeployed because of this paper.
