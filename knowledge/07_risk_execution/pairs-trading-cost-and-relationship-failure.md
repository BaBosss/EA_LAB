---
card_type: RISK_EXECUTION_NOTE
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---

# Pairs-trading cost and relationship-failure model

## Why this is first-class

Pairs/stat-arb is a two-leg relative-value strategy. A narrow statistical spread edge can disappear when either the relationship or the execution assumptions fail.

Source anchors:
- `RC-SSRN2147012-001` — pairs opportunity and market-structure dependence;
- `RC-DOI-S40854024007027-001` — crypto cointegration/copula pairs with transaction fees included;
- `RC-ARXIV221015448-001` — dynamic/neural relationship estimation as a later model extension.

## Cost stack to bind prospectively

Depending on instrument and broker, model explicitly:
- bid/ask spread on both legs;
- commission;
- slippage / adverse fill;
- asynchronous leg-fill risk;
- minimum lot / lot step;
- contract-size and quote-currency conversion;
- swap / overnight financing;
- crypto funding where applicable;
- borrow constraints where applicable;
- trading-session mismatch;
- latency / stale quote risk;
- margin interaction of both legs.

A backtest that omits a material leg cost is not comparable to a net implementation claim. Cross-impact must not be invented for retail-sized MT5 orders when it is not observable; use it only as a measured or explicit scenario cost when a direct consumer justifies it.

## Relationship-failure stack

Track separately:
- loss of cointegration/stationarity;
- hedge-ratio drift;
- spread variance explosion;
- residual trend;
- structural event / regime break;
- one asset becoming illiquid or unavailable;
- reference-asset behavior changing;
- repeated entry while the relationship is already broken.

## Baseline safety semantics to define before testing

A prospective experiment must state:
1. what proves a relationship eligible;
2. what invalidates it during the trading period;
3. whether an open pair is closed on invalidation;
4. whether re-entry is blocked and for how long;
5. how leg imbalance is handled;
6. maximum intended exposure mechanics, without inventing project-wide risk defaults;
7. what execution failure makes a run mechanically invalid.

## Gross-to-net evidence

Always preserve:
- gross P&L;
- each cost component where available;
- net P&L;
- turnover / number of pair transactions;
- holding time;
- cost as a share of gross edge;
- sensitivity to an adverse but preregistered cost scenario when justified.

The goal is not to optimize against a chosen stress number; it is to see whether the mechanism survives plausible implementation friction.

## Advanced-model warning

A dynamic hedge ratio, copula, neural model or RL policy can improve fit while simultaneously hiding relationship failure or increasing selection degrees of freedom.

Advanced models should therefore be children of an accepted deterministic baseline, not substitutes for proving the baseline mechanism.

## Links

- Mechanism: `knowledge/03_strategy_mechanisms/statistical-arbitrage.md`
- Baseline hypothesis: `knowledge/10_synthesis/HYP-SB-003-cost-aware-cointegration-pairs-baseline.md`
