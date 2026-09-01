---
card_type: VALIDATION_NOTE
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---

# Purged Walk-Forward Analysis for stateful/path-dependent strategies

## Source basis

`RC-ARXIV260309219-001` records AlgoXpert's use of rolling train/test folds separated by a purge gap, restricted degrees of freedom, state normalization before each forward test, precommitted fold evaluation, and strict later OOS.

## Why stateful strategies need special boundary semantics

For a stateless indicator calculation, a chronological split still needs lookback leakage control.

For a path-dependent EA, additional hidden state may cross the boundary:
- open inventory / recovery basket;
- grid level;
- trailing-stop state;
- adaptive counters;
- cooldown/halt state;
- equity or risk state;
- features whose lookback overlaps the split.

A forward test is not truly blind if the initial state depends on outcomes or positions from the training segment unless that behavior is explicitly part of the intended protocol.

## Candidate EA_LAB fold contract

A future qualified consumer should preregister:

`TRAIN_i -> PURGE_i -> TEST_i`

and bind:

1. train start/end;
2. purge length and units;
3. basis for purge length;
4. test start/end;
5. parameter dimensions that may be selected in train;
6. frozen shortlist / degrees of freedom;
7. exact test-start state;
8. treatment of train positions that would cross into purge/test;
9. indicator warm-up policy;
10. fold-evaluable conditions;
11. fold metrics and negative evidence;
12. aggregate interpretation rule;
13. catastrophic mechanical/risk invalidation semantics;
14. diagnostic-only train-to-test degradation fields;
15. final parameter-lock rule before any later OOS/HOLDOUT.

## Relationship to current EA_LAB conveyor

This is an **optional validation method**, not a new mandatory stage for every EA.

Use only when:
- a strategy has survived prior discovery/mechanism work;
- path dependence or temporal adaptation creates a real consumer;
- the expected information gain justifies the extra tester budget.

BWD and HOLDOUT remain robustness/final evidence surfaces, not optimizer round two.

## Diagnostics worth preserving

Without creating universal thresholds, a WFA report can expose:
- performance/expectancy/PF change;
- DD expansion;
- participation collapse;
- holding-time/exposure drift;
- cost sensitivity change;
- fold-to-fold dispersion;
- state-reset sensitivity.

These are diagnostic until a concrete experiment preregisters how they affect a decision.

## Explicit non-imports

This note does not import from AlgoXpert:
- a universal 90%-of-best stable region;
- universal `N_min`;
- universal majority-pass fraction;
- universal cliff thresholds;
- universal purge length;
- `Deploy / Reject / Refactor` as EA_LAB verdicts.

`KINT-001` remains open.

## Links

- Source card: `knowledge/02_research_cards/RC-ARXIV260309219-001.md`
- Gap analysis: `docs/research/EA_LAB_ALGOXPERT_GAP_ANALYSIS.md`
- Multiple testing: `knowledge/06_validation/multiple-testing-and-selection.md`
