---
object_type: TESTABLE_HYPOTHESIS_CANDIDATE
hypothesis_id: HYP-SB-004
status: SEMANTICS_REQUIRED
authority: RESEARCH_ONLY
source_bundle: SRC-EALAB-QUANTCORNER-20260901
canonical_base_sha: e9a3816775e1e2810ca99c55f349cdabc70d5348
---

# Signed-Volatility / Signed-Jump Regime Context

## R0 identity

- Family: `SECOND_BRAIN_REGIME_CONTEXT`
- Variant: `HYP-SB-004`
- Parent component: `knowledge/05_regimes/signed-volatility-and-jump-asymmetry.md`
- Current state: `UNTESTED_IN_EA_LAB / SEMANTICS_REQUIRED`
- One logical change: split realized volatility context by return/jump sign instead of using unsigned magnitude alone.
- Direct consumer: a separate future context/attribution experiment, not the frozen Boss19 P4A classifier.
- HOLDOUT: `UNSPENT / NOT AUTHORIZED HERE`
- Optimization: `NONE / NOT AUTHORIZED HERE`
- Trading signal: `NONE`

## Frozen hypothesis

For a prospectively chosen EA_LAB asset with adequate intraday data, sign-separated realized volatility and/or signed-jump features may contain incremental information about future volatility or strategy-condition outcomes beyond an otherwise comparable unsigned-volatility baseline.

This is a **context/attribution hypothesis**, not an entry or position-sizing rule.

## Evidence

### Supporting

`RC-DOI-RESTA00503-001` records Patton & Sheppard's evidence from high-frequency S&P 500 and 105-stock data. The source reports stronger future-volatility association with past negative-return variation than positive-return variation, asymmetric effects from negative versus positive jumps, and improved out-of-sample volatility forecasts from sign-aware models.

`RC-DOI108654119-001` adds a methodological macro-state lesson from Stock and Watson: current-state estimation and forecasting a later state are different objects. EA_LAB therefore keeps signed-volatility attribution separate from any forward regime forecast and from the frozen Boss19 P4A classifier.

### Transfer caution

The source evidence is U.S. equities. It does not establish the same asymmetry for XAUUSD, FX or BTC, and it does not establish a profitable trading rule.

The estimator, intraday sampling, trading hours, weekend behavior, gaps and data quality can materially change the feature.

## Interpretation

The paper provides a plausible reason to test whether “ATR/volatility magnitude alone” hides information useful for research attribution.

It does **not** justify changing an existing strategy or classifier before a prospective transfer test.

## Semantics required before any experiment

Freeze:

1. target asset;
2. exact historical data source and immutable receipt;
3. intraday sampling frequency;
4. missing-data / market-closure handling;
5. return definition;
6. realized-semivariance estimator;
7. whether jumps are included;
8. jump estimator / classification if included;
9. sign convention;
10. aggregation/lookback window;
11. exact feature timestamp / anti-lookahead rule;
12. baseline unsigned-volatility feature;
13. target: next-window volatility, strategy P&L attribution, DD attribution, or another exact outcome;
14. forecast/attribution horizon;
15. chronological MAIN/BWD-compatible windows;
16. comparison statistic / diagnostic;
17. multiple-testing handling if multiple estimators/windows are compared;
18. falsifier.

Until these are prospectively fixed, this file is not an ExperimentContract.

## Current Boss19 P4 boundary

Boss19 P4A remains frozen. `HYP-SB-004` must not:
- add features to P4A;
- reinterpret P4A labels;
- use P4A HOLDOUT as a search surface;
- claim to solve current P4B data-blocker issues.

A later experiment may compare this context feature only under a new contract with its own data provenance.

## Falsifier

The future fully specified hypothesis fails if the preregistered sign-aware feature does not provide incremental out-of-sample/context information versus its preregistered unsigned baseline, or if data quality/timing makes the comparison invalid.

No numeric threshold or preferred estimator is authorized here.

## Decision

`SEMANTICS_REQUIRED / DO NOT EXECUTE YET`.

## Next consumer

A future regime/context semantics packet after an immutable intraday data source and exact research target exist.

## Authority boundary

This is Second Brain research synthesis only. It creates no P4A change, Factory order, MT5 run, optimization, HOLDOUT use, automatic strategy enable/disable, risk/default change, deployment, DEMO/LIVE transition or trading authority.
