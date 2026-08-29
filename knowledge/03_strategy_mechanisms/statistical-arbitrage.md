# Statistical Arbitrage / Pairs Trading

Authority: `RESEARCH_ONLY`.

## Mechanism

Trade relative mispricing between two or more assets whose price processes have a sufficiently stable long-run relationship. The mechanism is relative-value mean reversion, not riskless arbitrage.

Batch 1 source `RC-SSRN2147012-001` uses cointegration to identify U.S. equity pairs and studies how HFT-era market structure changes the opportunity set.

## Research variables

- pair/universe selection;
- cointegration or relationship-stability criterion;
- spread construction / hedge ratio;
- divergence entry and convergence exit;
- structural break / relationship failure;
- transaction cost, borrow, latency and liquidity;
- market-structure state.

## Failure modes

A historically cointegrated relationship can break; more candidate pairs can coexist with smaller or more uneven profits; a fixed hedge relationship leaves residual risk; execution costs can dominate narrow spread opportunities.

## EA_LAB transfer boundary

FX or crypto pair implementations require separate evidence. Do not infer that U.S. equity HFT findings transfer unchanged to MT5 broker execution.