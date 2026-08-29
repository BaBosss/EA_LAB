# Drive Deep Intake Batch 1 — Cross-Paper Synthesis

Status: `RESEARCH_ONLY` / `NON_AUTHORITATIVE`

This synthesis links seven full-text research cards. It does not accept a strategy, change Factory policy, launch an experiment, implement QI-2+, or authorize runtime/trading/risk changes.

## 1. Strategy discovery and validation must be connected

`RC-SSRN2474755-001` shows why a strong-looking selected backtest can be a false discovery when many alternatives were tried. Strategy-generation work should therefore preserve search multiplicity and selection provenance rather than treating the winner as if it were the only test.

## 2. Mechanism semantics matter more than indicator labels

`RC-SSRN3412429-001` demonstrates one concrete RSI interpretation in which range persistence and RSI > 70 represent trend consistency and upside momentum. The implication is not that this threshold is universally bullish; the implication is that indicator semantics must be declared per strategy family and tested.

## 3. Regime is a conditioning variable, not a universal trigger

`RC-SSRN3813202-001` shows materially different historical behavior in high-and-rising inflation regimes, while `RC-SSRN962461-001` presents long-horizon price trend following as a simple risk-management overlay. Together they motivate explicit operating/failure regimes without turning macro state into an automatic entry rule.

## 4. Features should earn their place empirically

`RC-SSRN3808539-001` shows that price and return representations are not automatically interchangeable in directional ML models. `RC-SSRN5048674-001` shows that cross-asset crypto volatility information can add forecasting value beyond asset-local inputs. Both support preregistered feature ablation rather than indicator accumulation.
## 5. Market structure can change an edge without changing its label

`RC-SSRN2147012-001` treats statistical-arbitrage opportunity as conditional on pair selection, relationship stability and the HFT environment. A strategy family name such as “pairs trading” is insufficient without its market-structure and execution assumptions.

## Candidate research hypotheses — not experiments yet

- RSI trend/momentum semantics may transfer to selected EA assets only after asset/timeframe/cost validation.
- A simple trend/regime filter may improve failure-mode control without requiring a large indicator stack.
- BTC volatility forecasting may improve when peer-crypto volatility/commonality features are included.
- Stat-arb relationship stability may need an explicit structural-break gate.
- Any large parameter/strategy search should retain the number and dependence of attempts for selection-aware validation.

## Next corpus need

Deep-ingest direct mean-reversion, execution-cost/implementability and contradictory momentum evidence next, then build contradiction maps before proposing a larger strategy-hypothesis set.