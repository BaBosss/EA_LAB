# Statistical Arbitrage / Pairs Trading

Authority: `RESEARCH_ONLY`.

## Mechanism

Trade relative mispricing between two or more assets whose price processes have a sufficiently stable relationship. The mechanism is relative-value mean reversion, not riskless arbitrage.

Existing source `RC-SSRN2147012-001` uses cointegration to identify U.S. equity pairs and studies how HFT-era market structure changes the opportunity set.

QuantCorner enrichment adds:
- `RC-ARXIV170103098-001`: cross-impact as a distinct two-leg execution-cost problem, not a source of alpha;
- `RC-ARXIV170508022-001`: macro forecasts as a conditional FX mean-reversion layer whose optimized weights create selection risk;
- `RC-ARXIV191110450-001`: proportional-cost transaction regions coupling pair timing and size;
- `RC-DOI-S40854024007027-001`: cointegration + copula cryptocurrency pairs with explicit transaction fees;
- `RC-ARXIV221015448-001`: neural-augmented Kalman/Bollinger relationship estimation as an advanced model-mismatch response.

## Research variables

- fixed pair / universe and membership policy;
- formation window and trading window;
- data synchronization and timestamp convention;
- cointegration or other relationship-stability criterion;
- spread construction / hedge ratio;
- fixed versus dynamic hedge ratio;
- divergence entry and convergence exit;
- structural break / relationship failure;
- simultaneous-leg execution semantics;
- spread, commission, slippage, swap/funding/borrow and latency;
- liquidity/session state;
- capital/exposure normalization;
- benchmark;
- multiple pair/model selection history.

## Deterministic baseline ladder

The first EA_LAB stat-arb experiment should be deliberately simpler than the most advanced papers.

1. Freeze the tradable universe or exact pair before outcome inspection.
2. Define a chronological formation period.
3. Define the relationship test and acceptance semantics.
4. Define hedge ratio / spread construction.
5. Define fixed divergence and convergence rules.
6. Define a relationship-break / emergency-exit rule.
7. Define all material trading costs and two-leg execution assumptions.
8. Run a broad **fixed-config** chronological screen.
9. Diagnose participation, gross-to-net erosion, break events and regime dependence.
10. Only if a reproducible pulse exists, authorize one later child mechanism change.

This baseline is intended to answer whether the relative-value mechanism exists before adding model flexibility.

## Advanced child ladder

Possible later children, each separately preregistered:

- dynamic hedge ratio using Kalman/state-space estimation;
- nonlinear dependence / copula signal;
- macro-conditioned mean reversion;
- stochastic-control entry/exit;
- ML pair selection;
- neural Kalman augmentation;
- RL direction/sizing.

`one child = one logical change`.

Do not bundle pair selection, nonlinear dependence, dynamic hedge ratio and RL sizing into the first test.

## Failure modes

### Relationship failure
A historically cointegrated or otherwise stable relationship can break. A fixed hedge relationship leaves residual risk, while a dynamic hedge model can hide or chase structural change.

### Cost failure
Pairs trading pays for two legs. Spread, commission, slippage, funding/swap, latency and leg mismatch can erase a narrow gross spread edge.

### Selection failure
Searching many pairs, formation windows, hedge estimators and thresholds creates a multiple-testing problem even when only one final pair is reported.

### Execution failure
Two-leg asynchronous fills, symbol trading hours, minimum volume, contract-size differences and broker-specific pricing can change realized exposure.

## EA_LAB transfer boundary

U.S. equity and Binance futures results do not transfer unchanged to MT5 FX/CFD execution.

BTCUSDT as a reference asset, weekly reselection, the source papers' entry thresholds, or neural architectures are **not** defaults.

The next legitimate output is `HYP-SB-003`, which remains `SEMANTICS_REQUIRED` until pair/universe, relationship, cost, timing and falsifier semantics are prospectively frozen.

## Links

- Existing evidence: `knowledge/02_research_cards/RC-SSRN2147012-001.md`
- Cross-impact execution evidence: `knowledge/02_research_cards/RC-ARXIV170103098-001.md`
- Macro-conditioned FX mean-reversion evidence: `knowledge/02_research_cards/RC-ARXIV170508022-001.md`
- Proportional-cost transaction-region evidence: `knowledge/02_research_cards/RC-ARXIV191110450-001.md`
- Crypto/cost evidence: `knowledge/02_research_cards/RC-DOI-S40854024007027-001.md`
- Neural/Kalman evidence: `knowledge/02_research_cards/RC-ARXIV221015448-001.md`
- Cost/failure note: `knowledge/07_risk_execution/pairs-trading-cost-and-relationship-failure.md`
- Hypothesis: `knowledge/10_synthesis/HYP-SB-003-cost-aware-cointegration-pairs-baseline.md`
