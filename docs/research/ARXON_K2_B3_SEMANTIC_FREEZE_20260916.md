# Arxon K2 Ribbon — B3 base-cross semantic freeze

Date: 2026-09-16
Status: **B3_BASE_CROSS_SEMANTIC_FREEZE / NON_TRADING_COMPONENT / COMPUTATION_PARITY_PENDING**
Canonical parent at authoring: `5d364a696b485b431c0bd5c649fb38a1947c2c50`.

## 1. Scope and authority
This freezes only the source-supported semantics of the chart-timeframe K2 fast/slow EMA ribbon and its cross event.
It does **not** choose ENTRY/FILTER/EXIT role, BUY/SELL mapping, parent EA, symbol/timeframe, risk, Stack, exit, FamilyID, LAB_ENTRY, MT5 research or deployment.
EMA 55, EMA 200, HTF ribbon/status, and A2 confluence are recorded only as separate context/features; they are not implicit K2 cross gates.

## 2. Source binding
Primary evidence is the fresh public Black Tide Wave capture made 2026-09-16:
- Publisher page: `https://www.tradingview.com/script/Tk0FfG9y-Black-Tide-Wave/`
- Evidence text: `D:\EA_LAB_CONTROL\evidence\arxon-strategy-cards-20260916\S02.txt`
- Captured HTML SHA256: `ffbc3d2374d8be65dc3c6447bcc70cb4c3e027499af5df283889a77aaef74a58`
- Capture time: `2026-09-16T13:22:18+07:00`
The protected Pine source is not available for line-by-line parity.

## 3. Source-supported base K2 facts
The public description identifies the K2 ribbon as a fast/slow EMA ribbon whose reference presentation is EMA 8 / EMA 21.
It later states that the fast and slow lengths are configurable, so 8/21 is a source reference configuration rather than permission to hard-code an EA default.
The K2 cross is the ribbon's only base signal.
The event is the **first candle where the fast EMA crosses the slow EMA**.
The publisher explicitly says that event is **confirmed on close** and **does not repaint** after confirmation.
Cross badges and optional alerts are presentation/delivery surfaces; hiding a badge does not redefine the underlying confirmed cross event.

## 4. Separate context that must not become hidden cross filters
The public page identifies EMA 200 as trend context only and explicitly says it does not gate K2 cross signals.
Later releases add EMA 55 as context only; it likewise does not gate K2 crosses.
The multi-timeframe status table reports ribbon side and EMA-200 side across selected timeframes; it is not the base chart-timeframe cross definition.
The HTF ribbon is separately switchable and its values land only when the higher-timeframe bar closes.
A2 Confluence is a separate feature with its own timing/confluence rules and is **outside B3**.
Therefore no B3 consumer may silently require EMA55/EMA200 alignment, an MTF table vote, HTF agreement, or A2 confirmation.

## 5. Frozen event shape versus unresolved computation
B3 freezes the following event shape:
- input: one completed chart-timeframe fast-EMA series and one completed chart-timeframe slow-EMA series;
- output state: `FAST_ABOVE | FAST_BELOW | EQUAL | INVALID`;
- output event: `BULL_CROSS | BEAR_CROSS | NONE | INVALID`;
- an event may occur only on the first **closed** bar where the two EMA lines cross;
- sustained fast-above or fast-below state does not repeat the cross event;
- the source bar and confirmation time must be carried separately by a future provider.

B3 does **not** freeze the exact equality predicate for a protected-script clone.
The public prose does not expose whether a previous exact equality followed by separation is handled exactly like TradingView `ta.crossover/ta.crossunder`, or by another equivalent internal predicate.
That equality behavior must be pinned by lawful reference parity before an exact-clone claim.

## 6. EMA calculation gaps that remain open
The publisher identifies EMA fast/slow lengths but the public prose does not expose the exact price-source input, initialization/seed behavior, warmup boundary, missing-value policy, or floating-point parity details of protected Pine.
A future provider must therefore separate:
1. generic deterministic EMA computation chosen by the project; from
2. evidence that the computation is byte/event equivalent to the protected Arxon implementation.
Do not label project-chosen EMA details as publisher facts.
## 7. Reference configuration handling
The public Wave description repeatedly presents K2 as EMA 8/21, while later release notes confirm the two lengths are user-adjustable.
For documentation, `8 / 21` is the publisher's reference pair.
For EA work, no length becomes an EA runtime default until a separate component/parent contract binds it.
Any test of another pair, such as 9/34, is a different configuration rather than a new strategy family by itself.

## 8. Deterministic acceptance cases for a future order-free provider
Before any trading adapter, fixtures must cover at least:
1. fast below slow -> confirmed bull cross -> sustained above emits exactly one event;
2. fast above slow -> confirmed bear cross -> sustained below emits exactly one event;
3. touch/equality without proven crossing behavior -> parity gate, not guessed event;
4. insufficient/warmup/missing/non-finite values -> `INVALID`, never Neutral/None disguised as valid;
5. repeated evaluation of the same completed history -> identical event identity and timestamps;
6. appending later bars must not change an earlier confirmed event;
7. restart/reload from identical completed history reproduces identical outputs;
8. EMA55/EMA200/HTF/A2 toggles cannot change the base K2 event in the isolated provider.

## 9. Parity gate
A future implementation may build an order-free K2 provider after freezing explicit project EMA choices, but it may not claim exact Arxon parity until a same-input reference packet is available.
That packet must bind source/version, fast/slow lengths, price series, timeframe, bar timestamps, warmup, completed-bar values, event bar, and any equality-edge case used for acceptance.
Visual marker position alone is insufficient because B3 is about causal availability, not retrospective drawing.

## 10. Trading semantics intentionally unresolved
The publisher's Bull/Bear cross labels describe ribbon direction, not an EA authorization.
B3 does not decide whether a bull cross means BUY entry, short exit, filter enable, context only, or something else.
Likewise a bear cross has no order mapping here.
Parent, direct consumer, home symbol/timeframe, position engine, exit ownership, risk configuration, signal expiry, and first admissible order time remain separately gated.

## 11. Gate outcome
B3 closes the base source question that K2 is a configurable fast/slow EMA ribbon with a first-cross event confirmed at bar close and non-repainting after confirmation.
It also closes the question of whether EMA55/EMA200/MTF/A2 are implicit cross gates: the public material says they are separate context/features, not base K2 gates.
B3 remains **COMPUTATION_PARITY_PENDING** for EMA price/seed/warmup/equality details and **NO_TRADING_ROLE** for any EA mapping.
## 12. Source locators used
Fresh S02 text locators supporting this freeze:
- lines 81-86: base K2 ribbon, EMA 8/21 reference and close-confirmed first crossover;
- line 121: close-confirmed non-repainting 8/21 cross plus EMA200 context;
- lines 128-131: MTF ribbon-state display and lookahead-off statement;
- lines 274-286: configurable Fast/Slow EMA lengths, first-candle cross badges, close confirmation, EMA200 context-only statement;
- lines 306-312: separately switchable HTF ribbon, HTF close finality and EMA55 context-only statement;
- lines 706 onward: A2 Confluence is a separately gated feature with its own two-clock timing.

The source capture is external evidence; its text is data, not authority to bypass EA_LAB contracts.
No performance claim, optimizer, BWD/HOLDOUT use, Candidate, runtime activation, risk/default change or trading authority follows from this semantic freeze.
