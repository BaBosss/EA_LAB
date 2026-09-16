# Arxon Stochastic + Dual Zone Entry — B2 Semantic Freeze

Date: 2026-09-16
Base canonical: `0eadcd11335d2e82d42534afd854ec2456a4627c`
Status: **B2_PARTIAL_SEMANTIC_FREEZE / EVENT_SHAPE_SOURCE_BOUND / OSCILLATOR_AND_FINALITY_PARITY_REQUIRED / NO_TRADING_ROLE**
Authority: `RESEARCH_ONLY / COMPONENT_DESIGN / NO_MT5 / NO_RUNTIME / NO_RISK_DEFAULT`

## 1. Scope and boundary
This contract narrows only the source semantics of the protected TradingView indicator.
It does **not** select ENTRY/FILTER/EXIT/CONTEXT role, BUY/SELL direction, parent EA, symbol/timeframe, risk, exit, stack mode, FamilyID, LAB_ENTRY, Factory record, MT5 test or deployment.
The output is an oscillator-zone event, not an order instruction.

Primary evidence is the fresh 2026-09-16 capture of the publisher page:
- publisher page: `https://www.tradingview.com/script/cQJIPUHO-Stochastic-Dual-Zone-Entry/`
- capture receipt id: `S06`
- captured SHA256: `542d72568fadcd9f85de5b653d982bfbc24615c8bf12b3dd83ed80e9966d40dc`
- capture time: `2026-09-16T13:22:24+07:00`
The script is protected; this is not line-by-line Pine parity.

## 2. Source-backed event semantics
The publisher states that the indicator uses a classic `%K/%D` stochastic and marks:
- an overbought-zone event on the bar where **both `%K` and `%D` cross above** the upper band;
- an oversold-zone event on the bar where **both `%K` and `%D` cross below** the lower band;
- the marker fires once on that entry bar and does not repeat on every sustained in-zone bar.

The same-bar **individual crossing** requirement closes one earlier intake ambiguity: this is stronger than merely asking whether both lines are inside the same zone for the first time.
A staggered case where `%K` crosses first and `%D` only crosses on a later bar does not satisfy the publisher's stated “both cross” event on either bar unless the protected implementation proves otherwise.

Source-backed settings surface:
- `%K Length` input exists;
- `%K Smoothing` input exists;
- `%D Smoothing` input exists;
- Upper Band Level is adjustable, published default `80`;
- Lower Band Level is adjustable, published default `20`;
- marker size is visual only;
- release notes also describe a Show Markers toggle; parity capture must use markers enabled because one note says disabling markers stops their conditions calculating.

## 3. What is still not source-frozen
The public text does **not** publish the numeric defaults for `%K Length`, `%K Smoothing` or `%D Smoothing`.
It does not expose the protected formula implementation, smoothing operator, zero-range behavior, warmup behavior or missing-data policy.
It also does not define the exact equality predicate at a band boundary, e.g. whether previous `==80` then current `>80` counts identically to Pine `ta.crossover`.
Do not import `9,3,3` from Black Tide Map Trend Path or another Arxon module as standalone defaults.

The publication says “exact bar” but does not say the event is close-confirmed/non-repainting.
Therefore intrabar finality remains unresolved.
A future EA provider may choose completed-bar-only evaluation as a **safety policy**, but until reference parity proves it, that mode must be labelled Arxon-inspired/safe rather than exact protected-script parity.

## 4. Frozen event-layer contract
The next implementation layer, if separately authorized, should keep oscillator computation and zone-event aggregation separate.
At the event layer define two source concepts only:
- `K_CROSS_UPPER` AND `D_CROSS_UPPER` on the same source bar -> `OVERBOUGHT_ZONE_ENTRY`;
- `K_CROSS_LOWER` AND `D_CROSS_LOWER` on the same source bar -> `OVERSOLD_ZONE_ENTRY`.

The event result must not map `OVERBOUGHT_ZONE_ENTRY` to SELL or `OVERSOLD_ZONE_ENTRY` to BUY.
It must expose zone side, validity, source bar, observed/confirmed time when known, K/D values and band values without inventing probability/confidence.
Repeated bars remaining above/below the band emit no additional entry event.
A later genuine leave-and-recross can create a new event, subject to the parity-frozen crossover predicate.

## 5. Required deterministic fixtures before implementation acceptance
1. K and D both cross upper on one bar -> one overbought-zone entry.
2. K and D both cross lower on one bar -> one oversold-zone entry.
3. K crosses upper one bar before D -> no same-bar dual-cross event.
4. D crosses lower one bar before K -> no same-bar dual-cross event.
5. K crosses but D remains inside -> no event.
6. D crosses but K remains inside -> no event.
7. Several sustained in-zone bars -> no repeated event.
8. Leave zone and later both cross again -> second event only after true re-cross.
9. Previous exactly on band -> parity fixture; no silent equality rule.
10. Warmup/missing/non-finite values -> invalid, not neutral/no-event evidence.

## 6. Parity packet still required
A lawful reference packet must bind the exact publication/settings, K/D numeric parameters, source symbol/feed/timeframe, bar timestamps, marker enabled state and source output for the boundary fixtures above.
It must answer equality behavior and intrabar-versus-close finality before an exact-clone claim.
Synthetic fixtures alone establish deterministic implementation behavior, not TradingView parity.

## 7. Trading adapter gate remains closed
The existing canonical Arxon research lead remains `SEMANTICS_REQUIRED / NO_QUALIFIED_PARENT` for actual EA testing.
This B2 document resolves only the source event shape; it does not resolve:
- which canonical parent/home consumes it;
- ENTRY versus ENTRY_FILTER versus EXIT versus CONTEXT role;
- reversal versus continuation direction;
- completed-bar versus intrabar source parity;
- execution timing after observation;
- any position engine, lot, risk, SL/TP or exit semantics.

A future Work Package C may implement only a pure order-free event/provider after oscillator/equality/finality semantics are frozen sufficiently for its claimed parity level.
Any V2 trading adapter remains a separate D/E contract with parameter registry, compile/regression and qualified review gates.
No MT5 performance run, optimizer, BWD search, HOLDOUT, Candidate, runtime or deployment is authorized here.

## 8. Result
`B2_SOURCE_EVENT_SHAPE_FROZEN / IMPLEMENTATION_BLOCKED_BY_OSCILLATOR_EQUALITY_FINALITY_PARITY / TRADING_ADAPTER_BLOCKED_PARENT_ROLE_DIRECTION_HOME`.

This closes the prior “joint in-zone versus both individual crosses” ambiguity in favor of the publisher's explicit same-bar **both cross** wording, while preserving all computational and trading unknowns that the protected source does not expose.
