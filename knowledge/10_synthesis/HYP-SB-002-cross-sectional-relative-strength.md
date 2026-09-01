---
object_type: TESTABLE_HYPOTHESIS_CANDIDATE
hypothesis_id: HYP-SB-002
status: SEMANTICS_REQUIRED
authority: RESEARCH_ONLY
pod_contract_sha256: 81b4937a38f2f68274000c28ab2f7e460f9bfdd8d662d69102c18fe165c80838
canonical_base_sha: 594df6ab8e85c64346bf7407991df5aca8a785b5
---

# Cross-Sectional Relative-Strength Rotation

## R0 identity

- Family: `SECOND_BRAIN_RELATIVE_STRENGTH`
- Variant: `HYP-SB-002`
- Parent mechanism: `MECH-RS-001`
- Current state: `UNTESTED_IN_EA_LAB / SEMANTICS_REQUIRED`
- One logical change: introduce cross-sectional relative-strength leader selection as a distinct prospective mechanism family.
- Direct consumer: a separate prospective semantics/preregistration packet for a future controlled cross-sectional experiment.
- HOLDOUT: `UNSPENT / NOT AUTHORIZED HERE`
- Optimization: `NONE / NOT AUTHORIZED HERE`

## Frozen hypothesis

A predeclared cross-sectional relative-strength rotation rule that ranks a fixed tradable universe by trailing performance and allocates only to leaders may improve net performance versus a preregistered static benchmark, but any effect is expected to be conditional on market, universe, horizon and regime.
## Evidence

### Supporting

`RC-SSRN1585517-001` reports positive long-horizon evidence for monthly cross-sectional ranking across U.S. sectors and later global asset classes. Its mechanism is relative ranking among assets, not a single asset crossing its own trend reference. The same source also reports residual volatility/drawdown and implementation frictions including turnover, commissions, slippage, taxes and historical investability.

`MECH-RS-001` therefore records cross-sectional relative strength as a distinct research mechanism whose transfer into EA_LAB remains `UNTESTED_IN_EA_LAB`.

### Contradicting

`RC-SSRN2269045-001` reports very little abnormal risk-adjusted momentum performance over the full Irish-equity sample after bootstrap/Newey-West treatment of non-normal and serially dependent returns. Some high-growth subperiod configurations were positive, but the source supports conditionality rather than a universal momentum claim.

`knowledge/90_negative_knowledge/momentum-not-universal.md` consequently requires a prospective momentum hypothesis to bind market, universe, horizon, regime, ranking/holding design and inference method.

## Interpretation

The evidence supports spending design effort on a cross-sectional mechanism hypothesis, but it does not support choosing a specific EA_LAB implementation from hindsight. Positive and negative source evidence both point to the same research consequence: the implementation contract is first-class evidence, not an interchangeable detail.

This hypothesis must not be reduced to "trade the currently strongest single symbol" or to the existing time-series trend workflow. A valid test needs simultaneous comparable observations across a frozen universe and a defined rebalance/allocation rule.
## Semantics required before any experiment

The following are deliberately unresolved and may not be filled after seeing results:

1. exact tradable ranking universe and membership policy;
2. comparable return calculation, including FX quote-direction/base-currency treatment where relevant;
3. exact trailing lookback or prospectively defined multi-lookback rule;
4. selection breadth (`top-k`, percentile, or another exact rule) and long-only versus long/short semantics;
5. rebalance cadence, signal timestamp, execution timestamp and any no-trade/hysteresis band;
6. capital allocation, exposure normalization and concentration limits;
7. transaction-cost, spread, slippage, swap/funding and turnover treatment;
8. exact static/alternative benchmark and primary comparison metric;
9. MAIN/BWD-compatible evidence windows and universe-history availability, without using HOLDOUT;
10. regime-conditioning rule, if any, fixed before results rather than selected afterward;
11. inference method appropriate for non-normal/serially dependent returns and multiple tested specifications;
12. exact falsifier and stop condition for the fully specified implementation.

Until these are prospectively fixed, this artifact is not an executable ExperimentContract.

## Deterministic capability check

A repository probe found `scripts/symbol_fitness.py`, which ranks symbols by how well their curated profile or prior single-EA smoke PF fits a strategy type. That is useful screening tooling, but it is not a portfolio-level cross-sectional ranking/rebalance simulator and does not implement this mechanism.

The current Capability Scout query `cross-sectional portfolio ranking backtest` returned `USE_EXISTING` because it matched the generic EA_LAB backtest capability. That answer is insufficient for this consumer: deterministic MT5 backtest execution does not by itself prove a cross-sectional portfolio simulation capability. Treat this as a separate bounded Scout relevance defect, not as evidence that the capability gap is closed.
## Falsifier

For any future fully specified implementation, the preregistered leader-selection rule must fail if it does not improve its preregistered net benchmark under the required evidence windows after stated costs. This intake deliberately authorizes no numeric threshold, parameter value, ranking horizon or universe selection.

## Decision

`SEMANTICS_REQUIRED / DO NOT EXECUTE YET`.

Evidence is sufficient to retain `HYP-SB-002` as a source-traceable hypothesis candidate, but insufficient to launch MT5, a portfolio simulator, optimization, HOLDOUT, Factory promotion or any runtime action. The legal next step is a prospective semantics packet that resolves the twelve items above without inspecting outcome evidence.

## Next consumers

1. repair/review the Capability Scout relevance defect exposed by this real query;
2. determine whether an existing deterministic EA_LAB component can support synchronized cross-sectional ranking/rebalance evidence after semantics are fixed;
3. if not covered, use the Scout only to shortlist research-only candidates for a separate adoption review;
4. create a new exact ExperimentContract only after universe/ranking/rebalance/cost/benchmark/inference semantics are frozen.

## Authority boundary

This file is Second Brain research synthesis only. It does not create a strategy registry entry, ExperimentResult, Factory order, portfolio allocation rule, risk/default change, HOLDOUT use, deployment, DEMO/LIVE transition or trading authority.

## 2026-09-01 QuantCorner enrichment — Learning-to-Rank is a later child

`RC-ARXIV201207149-001` adds primary-source evidence that pairwise/listwise Learning-to-Rank can improve asset ranking for cross-sectional systematic portfolios in the source study. The paper's demonstrative case is cross-sectional momentum and it reports approximately threefold Sharpe improvement versus traditional ranking approaches in those experiments.

This does **not** change `HYP-SB-002` state or semantics. Learning-to-Rank is a later model child only after the deterministic cross-sectional mechanism is actually testable: the universe, synchronized returns, ranking horizon, rebalance, allocation, costs, benchmark and inference semantics must be frozen first, and a non-ML baseline must exist.

The reported source performance is not an EA_LAB expectation or threshold. This enrichment grants no simulator, Factory, HOLDOUT, portfolio-allocation or runtime authority.
