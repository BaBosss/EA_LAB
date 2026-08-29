# Second Brain Drive Batch 2 — Research Synthesis

> RESEARCH_ONLY synthesis. It does not accept a strategy, change Factory policy, launch an experiment, implement QI-2+, alter execution/risk defaults, deploy anything, or authorize trading.

## 1. Mean reversion needs an exact mechanism contract

The TSI study (`RC-SSRN4708400-001`) adds a positive short-horizon SPY/QQQ example, but its signal is a composite of TSI plus supporting filters and specific close-to-next-open execution assumptions. It should not be generalized into "oscillator mean reversion works."

A transferable hypothesis needs the exact reference, oversold/overbought semantics, market, horizon, entry/exit timing, costs and parameter-stability plan.

## 2. Momentum evidence is conditional, not universal

Positive long-horizon evidence from RSI momentum and relative-strength rotation coexists with the Irish-equity counterexample (`RC-SSRN2269045-001`). The negative paper also shows why non-normal and serially dependent strategy returns can make conventional significance tests misleading.

EA_LAB should therefore bind momentum claims to market/universe/horizon/regime and choose inference methods appropriate to the return distribution.

## 3. Cross-sectional relative strength is not time-series trend

`RC-SSRN1585517-001` ranks assets against each other and rotates into leaders. That mechanism differs from asking whether one instrument is above its own moving-average or trend reference. Universe definition, rebalance cadence and turnover are first-class semantics.
## 4. Entry alpha and execution are separate research layers

The continuous-double-auction study (`RC-SSRN1843305-001`) and benchmark-liquidity study (`RC-SSRN3375564-001`) both show that execution conditions can vary with remaining opportunity or event time. Neither supplies a production MT5 execution rule.

Future execution work should measure fill probability, spread/slippage and time/event context independently of entry-signal profitability before any runtime semantics are proposed.

## 5. Validation consequence

Batch 2 reinforces Batch 1's multiple-testing lesson: a promising mechanism card is a hypothesis source, not acceptance evidence. Search breadth, parameter sensitivity, distributional assumptions, implementation frictions and genuine holdout evidence remain separate questions.

## Direct next research consumers

- use the completed supplied corpus to generate source-traceable `TESTABLE_HYPOTHESIS` candidates through the existing knowledge-query and strategy-synthesis skills;
- ingest additional execution/cost and counterevidence sources where they close a concrete hypothesis gap;
- use these cards to narrow prospective hypotheses, not to auto-generate accepted strategies.

Existing strategy, experiment, evidence, Factory, runtime, deployment and risk owners remain authoritative.