---
card_type: REGIME_NOTE
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---

# Signed volatility and jump asymmetry

## Source evidence

`RC-DOI-RESTA00503-001` records Patton & Sheppard's equity evidence using high-frequency S&P 500 and 105-stock data.

The source separates realized variation associated with positive and negative returns and reports asymmetric forecasting information:
- future volatility relates more strongly to past negative-return variation than positive-return variation;
- negative jumps are associated with higher future volatility;
- positive jumps are associated with lower future volatility;
- sign-aware models improve out-of-sample volatility forecasts in the source study.

## Mechanism interpretation

Unsigned volatility compresses direction-specific shock information into one magnitude.

A sign-aware context representation may distinguish:
- upside continuous variation;
- downside continuous variation;
- positive jump variation;
- negative jump variation;
- imbalance between positive and negative realized variation.

This is a **market-context / volatility-state** concept, not an entry signal.

## Semantics required for EA_LAB transfer

Before any FX/XAU/BTC test, freeze:

1. target asset and exact data source;
2. intraday sampling frequency;
3. bar/tick quality and missing-data handling;
4. realized-semivariance formula;
5. jump estimator / jump classification, if used;
6. sign convention;
7. aggregation window;
8. timestamp availability / anti-lookahead rule;
9. comparison against an unsigned-volatility baseline;
10. target variable: next-window volatility, EA performance attribution, or another exact outcome;
11. MAIN/BWD-compatible chronology;
12. falsifier.

## Transfer limits

The published evidence is U.S. equities. Crypto, gold and FX can have different microstructure, trading hours, leverage, weekend gaps and news behavior.

No threshold, estimator tuning, forecast coefficient, or expected performance effect is imported.

## Current-project boundary

Boss19 P4A is already frozen. This note does not add a new P4A feature or reinterpret the frozen classifier.

If tested, the concept must be a separate future hypothesis/experiment with its own data provenance.

## Links

- Source card: `knowledge/02_research_cards/RC-DOI-RESTA00503-001.md`
- Hypothesis: `knowledge/10_synthesis/HYP-SB-004-signed-volatility-regime-context.md`
