---
card_type: CORPUS_SYNTHESIS
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---
# Supplied Research Corpus — Strategy Intelligence Synthesis
## Coverage closure
The supplied Drive inventory contains 26 direct PDF objects. Classification is complete: **21 promoted trading/research sources**, **3 rejected unrelated sources**, and **2 byte-identical 151 Trading Strategies objects** retained as duplicate evidence. `PENDING_CLASSIFICATION = 0`. No Drive object was deleted or moved.

Promoted source bytes are SHA-256 bound in the source registry/receipts. The three rejects are also hash-receipted so exclusion is traceable. The two duplicate 151 objects share the previously recorded exact SHA-256 and are not independently promoted as competing sources.

## Cross-source durable knowledge
1. **Mechanism before indicator.** RSI/MACD/TSI/MA thresholds change meaning with trend, momentum and mean-reversion hypotheses.
2. **Regime is part of the strategy.** Trend/range, inflation/macro, volatility and session context can alter expected behavior.
3. **Optimization is evidence-sensitive.** Better historical parameters are not enough; search breadth and multiple testing matter.
4. **Validation must challenge selection.** IS/OOS, walk-forward, bootstrap/non-normality checks and parameter stability are distinct evidence layers.
5. **Execution can erase edge.** Spread, slippage, price impact, turnover, liquidity, benchmark timing and instrument access must be modeled.
6. **Portfolio actions have frictions.** Rebalancing can require no-trade bands instead of exact continuous target restoration.
7. **Alpha libraries are component libraries.** Formulaic alpha examples expand the design vocabulary but require data/timing/market transfer validation.
8. **Contradictory evidence is valuable.** Momentum and indicator findings vary across markets and samples; Second Brain must retain counterexamples rather than average them away.
9. **ML/crypto evidence remains feature-level until transferred.** Source forecasting improvements do not automatically become entry rules.
## Strategy synthesis contract
A future Second Brain strategy proposal should state: mechanism; target market/symbol/timeframe; expected regime; inputs/components; entry and exit semantics; sizing/risk assumptions; execution assumptions; supporting and contradicting source cards; transfer gaps; falsification conditions; and a bounded validation plan.

The output state is `TESTABLE_HYPOTHESIS`, never `ACCEPTED_STRATEGY`. Existing Factory/experiment/evidence owners decide whether the hypothesis survives testing.

## Direct consumer
The completed corpus can now feed `ea-knowledge-query`, `ea-strategy-synthesizer`, `ea-evidence-critic` and `ea-negative-memory` to generate bounded research hypotheses without rereading all PDFs. QI-2+, runtime, deployment, LIVE and risk/default authority remain outside this corpus.