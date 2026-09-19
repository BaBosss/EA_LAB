# Order-Flow Components V1 — OF01 / OF02

Status: `SOURCE_IMPLEMENTED / ORDER_FREE / OFFLINE_FIXTURE_VALIDATED / TEMPLATE_EXIT_BINDING_REQUIRED`

Authority ceiling: research-component source only. This package is not a runnable EA, a broker adapter, qualified market data, a backtest, a strategy-performance result, a runtime default, or permission to trade/deploy. It does not allocate a FamilyID, `LAB_ENTRY`, Boss wrapper, Home, session, profile recipe, exit recipe, or signal/execution-symbol mapping.

## 1. Provenance and claim boundary

The referenced screenshot/text supports only the high-level causal frame:

`Context -> Location -> Evidence -> Trigger -> Risk`

and the two concepts:

- rejection at value-area edges followed by reversion toward value;
- acceptance beyond a value-area edge followed by continuation after retest.

It does **not** establish the exact numeric rules implemented here. The following are the owner-approved EA_LAB research proposal encoded by this package, not quotations from the source, original-video parity, optimization output, or profitable-strategy evidence:

| Rule | V1 research proposal |
|---|---|
| Value profile | prior completed session; upstream-supplied `VAL < POC < VAH` |
| Zone / stop buffer | `0.20 * ATR(14)` calculated from completed M5 bars ending immediately before the setup candidate; frozen for that setup |
| Relative volume | current real executed total volume `>= 1.50 * median(previous 20 completed M5 bars)` |
| Signed delta | `(executed_ask_volume - executed_bid_volume) / (ask + bid)` |
| OF01 rejection delta | long `<= -0.20`; short `>= +0.20` |
| OF01 wick | relevant rejection wick / full bar range `>= 0.40` |
| OF01 trigger window | next 3 completed M5 bars; close strictly beyond the test high/low |
| OF01 risk gate | caller-observed quote and caller-supplied all-in price cost; net RR `>= 1.50`; frozen POC target |
| OF02 breakout | two consecutive completed M5 closes beyond the frozen outer zone; second bar meets volume and directional `|delta| >= 0.20` |
| OF02 retest / confirm | retest within 6 completed M5 bars; confirmation within next 3, close beyond retest extreme and delta strictly directional |
| OF02 target | prospective 2R geometry from the supplied quote and structural stop |
| OF02 time exit | proposed 12 M5 bars after an **actual fill**; consumer-owned and not implemented here |

All comparisons above are exact/inclusive where written `>=`/`<=`, and strict where written “strictly” or `>`/`<`. The components use completed bars only.

## 2. Typed upstream contract

The component never selects or derives these policies. Every call is pinned by `OFDataContract`, `OFFreshnessPolicy`, `OFProfile`, one completed M15 context bar, chronological completed M5 bars, and a prospective `OFQuote`.

Required upstream pins:

- dataset, source, source revision, signal instrument, profile instrument;
- session-definition ID and timezone/DST ruleset ID;
- profile algorithm ID and value-area algorithm ID;
- volume-provenance ID;
- profile ID/revision and prior-session clocks;
- caller-chosen positive freshness ceilings for M5, M15, profile, and quote;
- same instrument, or a non-empty explicitly qualified mapping ID.

No broker, Home, symbol suffix, signal/execution mapping, session boundary, timezone, DST rule, profile binning/tie/value-area algorithm, roll/basis rule, incomplete-bar policy, fill model, or cost model is inferred.

`TRUE_ORDERFLOW` requires genuine executed ask-side and bid-side volume with qualified provenance. Tick volume and up/down-tick classification have separate proxy identities and are rejected. There is no automatic proxy fallback. The test schema is `orderflow_fixture/v1` / `FIXTURE`; qualified external data must use `orderflow_qualified/v1` / `QUALIFIED`, explicit bars, and `source_qualified=true`. Fixture acceptance is never data qualification.

The validator rejects missing pins, stale/future clocks, incomplete bars, non-monotonic or duplicate records, source/profile contradictions, invalid OHLC, zero/negative/NaN volume, ask+bid/total contradictions, invalid profile geometry, unqualified mappings, stale/pre-trigger quotes, proxy-as-real claims, and missing explicit freshness policy.

## 3. OF01 — value-edge rejection / reversal

Long and short are mirrored:

1. The latest completed M15 context close is strictly inside `[VAL, VAH]` (strictly greater than VAL and strictly less than VAH).
2. A completed M5 test overlaps the `edge +/- frozen buffer` zone, actually reaches/crosses the edge, and closes back inside value.
3. The test meets relative executed volume, opposing signed delta, and relevant rejection-wick rules.
4. The component arms for the next three completed M5 bars. A long requires a close above the test high; a short requires a close below the test low.
5. Two consecutive completed closes beyond the value-exterior side of the frozen zone cancel the setup. Source/profile/context revision changes also cancel it.
6. Stop geometry is beyond the most adverse extreme from test through confirmation plus the frozen buffer. Target is the frozen prior-session POC.
7. Entry is the caller's observed ask for long or bid for short. Caller-supplied round-trip price cost is added to risk and subtracted from reward. A signal is returned only when net RR is at least 1.5.

The quote is labeled prospective and never represented as a fill.

## 4. OF02 — value-edge acceptance / continuation

Long and short are mirrored:

1. The latest completed M15 context close is strictly beyond VAH (long) or VAL (short).
2. The first completed M5 close beyond the exterior edge of the `edge +/- frozen buffer` zone freezes ATR and buffer.
3. The immediately following M5 bar must also close beyond that same exterior edge. The second bar must meet relative executed volume and directional signed delta.
4. Within the next six completed bars, the retest must overlap the frozen zone and close on the breakout side of the profile edge.
5. Within the next three completed bars, confirmation must close beyond the retest extreme with delta strictly in the breakout direction.
6. A close past the “opposite outer edge” cancels. In V1 that phrase is made explicit as the value-side boundary of the frozen breakout zone: `VAH-buffer` for long and `VAL+buffer` for short.
7. Stop is beyond the most adverse retest-through-confirmation extreme plus the frozen buffer. Prospective TP is exactly 2R from the supplied quote and that structural stop.

The proposed 12-M5-bar exit cannot begin until an actual fill exists. This order-free component has no fill and therefore does not implement or simulate that exit.

## 5. Template seam

The current V2 `EntrySignal` contains direction, strength, confidence, validity and reason only. It has no structural stop, target, expiry, profile/source identity, prospective quote identity, or fill-relative time-exit contract. Mapping OF01/OF02 to that type would silently discard decision-critical geometry.

`OrderFlowTemplateSeam.mqh` therefore copies the full `OFGeometry` into an inert `OFTemplateSeamProposal` and hard-codes:

- `current_entry_signal_compatible = false`;
- `order_execution_authorized = false`;
- `time_exit_implemented = false`;
- `binding_status = TEMPLATE_EXIT_BINDING_REQUIRED`.

A downstream Control Tower contract must first qualify the data source/session/profile/Home/exit/recipe semantics and add a geometry-owning consumer. Only then may serialized core integration be proposed. This source does not invent `strength` or `confidence`.

## 6. Files and validation

MQL component source:

- `ea_template/components/orderflow/OrderFlowTypes.mqh`
- `ea_template/components/orderflow/OrderFlowValidation.mqh`
- `ea_template/components/orderflow/OF01Reversal.mqh`
- `ea_template/components/orderflow/OF02Continuation.mqh`
- `ea_template/components/orderflow/OrderFlowTemplateSeam.mqh`
- `ea_template/components/orderflow/OrderFlowComponents.mqh`

Deterministic native harness:

- `ea_template/tests/OrderFlowComponents_Test.mq5`

Offline reference and fixture contract:

- `tools/orderflow/offline_reference.py`
- `tools/orderflow/orderflow_schemas.json`
- `tools/orderflow/fixtures/positive_cases.json`
- `tools/orderflow/tests/test_orderflow.py`

Portable-Python gate:

```powershell
. .\scripts\use_python.ps1
Assert-PortablePython -Provision
python -m unittest discover -s .\tools\orderflow\tests -p 'test_*.py' -v
python .\tools\orderflow\offline_reference.py --input .\tools\orderflow\fixtures\positive_cases.json --expect-class FIXTURE
```

The MQL harness may be compiled by MetaEditor only from a copied evidence tree. Under this order it is not attached or executed in Terminal/Tester. Therefore report native evidence as `COMPILED`, never `EXECUTED`. Python fixture execution is a reference replay, not proof of MQL execution parity.

## 7. Evidence state and remaining blockers

- Strategy performance: `NOT RUN / NOT AUTHORIZED`.
- MT5 Tester and native MQL harness execution: `NOT RUN / PROHIBITED BY THIS ORDER`.
- Qualified real order-flow dataset: `NOT PROVIDED / NOT QUALIFIED`.
- Home, broker, session/timezone/DST, profile algorithm, symbol mapping, roll/basis, fill/cost policy: `UNRESOLVED / UPSTREAM REQUIRED`.
- Current Template execution/exit binding: `TEMPLATE_EXIT_BINDING_REQUIRED`.
- Runtime adapter, wrapper, FamilyID, `LAB_ENTRY`, defaults, deployment: `NOT IMPLEMENTED / NOT AUTHORIZED`.
- HOLDOUT, Candidate, DEMO/LIVE, profitability, risk/default claims: `NO AUTHORITY`.

Source-only completion is not data, backtest, execution, runtime, or production completion.
