---
object_type: TESTABLE_HYPOTHESIS_CANDIDATE
hypothesis_id: HYP-SB-003
status: SEMANTICS_REQUIRED
authority: RESEARCH_ONLY
source_bundle: SRC-EALAB-QUANTCORNER-20260901
canonical_base_sha: 0f2cc63d7ca86a8a3a476faf122141aafb513f5b
---

# Cost-Aware Deterministic Cointegration Pairs Baseline

## R0 identity

- Family: `SECOND_BRAIN_STATISTICAL_ARBITRAGE`
- Variant: `HYP-SB-003`
- Parent mechanism: `knowledge/03_strategy_mechanisms/statistical-arbitrage.md`
- Current state: `UNTESTED_IN_EA_LAB / SEMANTICS_REQUIRED`
- One logical change: introduce a deterministic two-leg relative-value baseline as a distinct prospective family.
- Direct consumer: a separate prospective semantics/preregistration packet for a controlled stat-arb experiment.
- HOLDOUT: `UNSPENT / NOT AUTHORIZED HERE`
- Optimization: `NONE / NOT AUTHORIZED HERE`
- Runtime: `NONE / NOT AUTHORIZED HERE`

## Frozen hypothesis

A prospectively specified pair/universe selected by a deterministic relationship rule, traded using a fixed cointegration/spread divergence-convergence baseline with explicit two-leg costs and a relationship-failure rule, may exhibit a reproducible **net** relative-value pulse under chronological testing.

The hypothesis is about the baseline mechanism. It does not include copulas, Kalman filters, neural networks, RL, dynamic sizing, or hindsight pair selection.

## Evidence

### Supporting

`RC-SSRN2147012-001` supports statistical-arbitrage / pairs trading as a relative-value mechanism whose opportunity set depends on pair selection and market structure.

`RC-ARXIV170103098-001` separates cross-impact execution cost from the alpha mechanism and therefore supports explicit two-leg implementation accounting without assuming that market impact is material in EA_LAB.

`RC-ARXIV170508022-001` shows a source-specific FX experiment where macro forecasts were layered onto mean reversion; EA_LAB treats that as a later child because optimized macro weights add selection degrees of freedom.

`RC-ARXIV191110450-001` shows that under proportional costs, pair timing and trade size can be coupled through transaction regions; EA_LAB treats this as an advanced control child after a simple baseline.

`RC-DOI-S40854024007027-001` reports a crypto pairs framework using cointegration plus copulas and explicitly includes transaction fees. For EA_LAB the useful baseline lesson is that relationship selection and gross-to-net cost treatment are core mechanics, not post-processing.

`RC-ARXIV221015448-001` shows that dynamic/neural state-space estimation can be used to address model mismatch, but it is intentionally treated as a later child rather than evidence that the first baseline must be complex.

### Contradicting / cautionary

A historically stable relationship can break. Two-leg spread, slippage, funding/swap and asynchronous fills can erase a narrow gross edge. Searching many pairs, formation windows, hedge estimators and thresholds creates selection bias.

No reviewed source establishes that any specific EA_LAB FX/XAU/BTC pair is profitable.

## Interpretation

The evidence is sufficient to spend bounded design effort on a deterministic baseline because it creates a genuinely different strategy mechanism from single-asset trend/grid families and can be falsified without ML.

The evidence is insufficient to choose the pair, timeframe, formation window, threshold, hedge estimator, cost model or risk settings from hindsight.

## Semantics required before any experiment

The following are deliberately unresolved:

1. exact tradable pair or frozen candidate universe and membership policy;
2. exact broker/data source and symbol contract identities;
3. timestamp/time-zone synchronization and missing-bar handling;
4. formation window;
5. trading/evaluation window;
6. cointegration/stationarity test and exact eligibility semantics;
7. multiple-pair selection handling if a universe is allowed;
8. hedge-ratio estimator;
9. spread definition and normalization;
10. divergence entry rule;
11. convergence/target exit rule;
12. maximum holding / time exit, if any;
13. relationship-break detector;
14. action on relationship break with an open pair;
15. re-entry/cooldown semantics after a break;
16. simultaneous/two-leg fill model;
17. spread, commission, slippage, swap/funding and other material cost semantics;
18. position/exposure normalization without inventing universal risk defaults;
19. chronological MAIN/BWD-compatible evidence windows;
20. preregistered benchmark;
21. primary evidence metrics;
22. participation reporting;
23. multiple-testing/search-history disclosure;
24. exact falsifier and stop condition.

Until these are frozen prospectively, this file is not an ExperimentContract.

## Baseline / child boundary

The first experiment must not contain:
- copula nonlinear dependence;
- Kalman dynamic hedge ratio;
- neural relationship model;
- RL policy;
- adaptive pair reselection driven by tested outcomes;
- parameter optimization.

If the deterministic baseline has no pulse, advanced children are not justified by this hypothesis.

If a pulse exists and a specific failure mode is diagnosed, one later child may change one mechanism at a time.

## Falsifier

The fully specified baseline is falsified if its preregistered chronological evidence does not support its stated **net** relative-value claim after all declared costs, or if the relationship/execution assumptions make the evidence mechanically invalid.

No numeric threshold is authorized in this intake.

## Decision

`SEMANTICS_REQUIRED / DO NOT EXECUTE YET`.

## Next consumer

Create a prospective semantics packet resolving the 24 items above without inspecting candidate outcome evidence. Only after that packet is frozen may a separate controlled experiment contract be considered.

## Authority boundary

This is Second Brain research synthesis only. It creates no Factory order, MT5 run, optimization, HOLDOUT use, risk/default change, portfolio allocation, deployment, DEMO/LIVE transition or trading authority.
