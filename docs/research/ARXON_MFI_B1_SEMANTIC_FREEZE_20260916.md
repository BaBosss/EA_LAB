# Arxon MFI+ B1 — source-to-computation semantic freeze

Date: 2026-09-16
Status: **B1_SEMANTIC_FREEZE / COMPONENT_ONLY / NO_TRADING_ROLE / PARITY_REFERENCE_PENDING**
Base canonical: `328096e0fe62edfba821253ea8f7aefc33359838`
Direct consumer: future Work Package C order-free MFI provider implementation contract only.

## 1. Authority and hard boundary
This freezes one deterministic, non-trading computation contract for the standalone Arxon MFI+ component.
It does **not** select an EA parent, symbol, timeframe, BUY/SELL mapping, entry/exit rule, Stack mode, lot/risk rule,
FamilyID, LAB_ENTRY, Factory StrategyRecord, MT5 test, optimizer, Candidate, deployment or trading action.
Neutral is data, not an exit. Bull/bear colours are context states, not orders.

The protected TradingView source is not available for line-by-line parity. This contract therefore separates:
1. publisher-supported standalone settings/state semantics;
2. standard MFI mathematics documented by TradingView; and
3. explicit fail-closed provider choices that must later be checked against same-feed reference values.

## 2. Evidence used
- Canonical family card: `ea_template/strategy_cards/arxon/families/ARX-04.md`.
- Canonical component card: `ea_template/strategy_cards/arxon/components/O02.md`.
- Fresh S05 publication receipt: SHA256 `51633b3bd68ffc4b1ac95e0dc31ed724a7ade1f9e0de7c2d65e7567cb219be43`, observed 2026-09-16.
- Publisher page: `https://www.tradingview.com/script/eBoUoU2u-Arxon-MFI/`.
- TradingView MFI calculation reference, observed 2026-09-16: `https://www.tradingview.com/support/solutions/43000502348-money-flow-mfi/`.
- S08 manual details remain carried notes only; the full manual was not re-audited in this milestone.

## 3. Publisher-frozen standalone reference
The standalone v1.0 description supports the following component reference values. They are **not EA runtime defaults**:

| Field | Frozen reference |
|---|---|
| Length | `7` |
| Price source | `hlc3` = `(H + L + C) / 3` |
| Bull state | `MFI > 55` |
| Neutral state | `45 <= MFI <= 55` |
| Bear state | `MFI < 45` |
| Overbought extreme | `MFI > 90` |
| Oversold extreme | `MFI < 10` |
| Middle line | `50`, visual reference only |
| State memory | none; level-based each bar, no hysteresis |
| Trading role | none in the publisher description |

For this component contract, completed-bar-only sampling is a **provider safety choice** that avoids using developing-bar state.
This is not claimed as a protected-script parity fact; v1 exposes **completed-bar values only** and developing-bar output is out of scope.

## 4. Deterministic computation contract
Input is an ordered sequence of completed bars with `high`, `low`, `close`, `volume`, and source-bar time.
Every numeric input must be finite. Negative volume is invalid input. Volume zero is allowed but may lead to zero-flow invalidity below.

For bar `i`:
1. `tp[i] = (high[i] + low[i] + close[i]) / 3`.
2. `raw_flow[i] = tp[i] * volume[i]`.
3. If `tp[i] > tp[i-1]`, assign `raw_flow[i]` to positive flow and zero to negative flow.
4. If `tp[i] < tp[i-1]`, assign `raw_flow[i]` to negative flow and zero to positive flow.
5. If `tp[i] == tp[i-1]`, assign zero to both; equality does not manufacture directional flow.
6. Sum the last 7 classified positive-flow and negative-flow elements.
7. If `negative_sum > 0`, compute `ratio = positive_sum / negative_sum` and `MFI = 100 - 100 / (1 + ratio)`.
8. If `negative_sum == 0` and `positive_sum > 0`, return `MFI = 100`.
9. If `positive_sum == 0` and `negative_sum > 0`, return `MFI = 0`.
10. If both sums are zero, return `valid=false`, `reason=ZERO_FLOW_UNDEFINED`; do **not** invent `50` or treat it as Neutral.

Seven classified flow elements require one prior price for comparison, so the conservative provider warmup is 8 complete bars.
The later parity check must verify TradingView's first-valid-bar behavior; until then, earlier bars remain invalid rather than guessed.

The zero-denominator policy in steps 8–10 is an explicit provider contract/safety choice derived from the standard formula's limits
and the project's fail-closed missing-data rule. It is **not** claimed as a reverse-engineered detail of protected Arxon Pine code.

## 5. Volume and feed contract
The provider receives a bound `volume` series plus a declared `volume_basis`; it does not silently select real versus tick volume.
Permitted provenance labels for a future implementation must distinguish at least `REAL`, `TICK`, and `UNKNOWN/INVALID`.
`UNKNOWN/INVALID` may not produce a valid MFI output.

B1 does not bind an instrument home or data feed, so volume provenance remains configuration rather than an assumed source default.
A later EA/home contract must bind broker/symbol/feed and volume basis explicitly before any parity or research claim.
A value produced on one feed is not evidence of parity on another feed.

## 6. Output contract
The future order-free provider must expose the semantic equivalent of:
- `valid`: boolean.
- `mfi_value`: finite `0..100` only when valid.
- `state`: `BULL | NEUTRAL | BEAR | INVALID`.
- `extreme`: `OVERBOUGHT | NONE | OVERSOLD | INVALID`.
- `source_bar_time`: the completed bar that owns the value.
- `confirmed_at`: that bar's close/availability time under the bound feed/calendar.
- `reason`: explicit invalid/no-data reason when `valid=false`.

Field names are contract concepts, not an installed ABI. No `strength`, `confidence`, probability or score floor is defined here.

## 7. State and timing classifier
When `valid=true`, classify in this order:
1. `MFI > 55` -> `BULL`.
2. `MFI < 45` -> `BEAR`.
3. otherwise -> `NEUTRAL`.

Extreme classification is independent of the three-state layer:
- `MFI > 90` -> `OVERBOUGHT`.
- `MFI < 10` -> `OVERSOLD`.
- otherwise -> `NONE`.

Exactly `45`, `50`, and `55` are Neutral. Exactly `10` and `90` are not extreme under the publisher wording used here.
No previous state is carried forward. A Bull->Neutral transition is just a new context state, not an exit command.

Availability is close-confirmed only: the value for source bar `t` becomes observable at that bar's completed close.
No downstream `first_action_at` is defined by B1 because there is no selected consumer, parent, direction or execution rule.
Restart/reload must reproduce the same completed-bar sequence from the same bound input history; no hidden latch is permitted.

## 8. Deterministic acceptance fixtures for Work Package C
A future implementation must include fixture-level tests before any adapter or MT5 research run:
- Boundary classifier: `44.999`, `45`, `50`, `55`, `55.001`, plus `9.999`, `10`, `90`, `90.001`.
- Monotonic rising typical price with positive volume -> one-sided positive flow and the defined 100 limit case.
- Monotonic falling typical price with positive volume -> one-sided negative flow and the defined 0 limit case.
- Equal typical price sequence with nonzero volume -> no directional flow; all-zero window is invalid, not Neutral.
- Zero-volume sequence -> all-zero window is invalid with `ZERO_FLOW_UNDEFINED`.
- Mixed rise/fall fixture with hand-computed 7-element sums and exact MFI expectation.
- One NaN/non-finite OHLC or negative volume -> invalid result; no coercion to zero/Neutral.
- Warmup fixture -> invalid until 7 classified flow elements are available from 8 completed bars.
- Prefix invariance: appending later bars may not change already-confirmed historical outputs.
- Restart determinism: identical history/config yields identical outputs and invalid reasons.

## 9. Parity gate — still required
Work Package C may implement this order-free contract, but it may not claim an exact Arxon clone until same-input reference parity is demonstrated.
The parity packet must bind publication/version, exact source settings, symbol/feed, volume basis, timeframe, bar timestamps,
reference extraction method, implementation build hash and fixture/history hash.

Required comparisons include ordinary values, state boundaries, warmup, equal-price bars, one-sided flow windows and zero-flow windows.
If the protected/public reference behaves differently on an edge case, classify the mismatch openly and return to semantic review;
do not tune the implementation against later strategy P/L and do not rewrite this freeze silently.

## 10. What is now closed versus still blocked
**Closed by B1 after review:**
- standalone reference constants `7 / hlc3 / 55 / 45 / 90 / 10`;
- standard source-to-MFI computation contract;
- completed-bar-only provider timing;
- explicit validity, zero-flow and no-hysteresis behavior for the future order-free provider;
- deterministic fixture expectations and parity evidence fields.

**Still blocked / deliberately unset:**
- exact Pine-source equivalence and same-feed parity;
- standalone-versus-embedded Wave MFI reuse;
- broker/home `volume_basis` selection;
- parent, role, direction, Neutral treatment inside a trading system, signal expiry and order timing;
- FamilyID/LAB_ENTRY/input-registry/core edits;
- any MT5 performance work, optimizer, BWD, HOLDOUT, Candidate, deployment or trading action.

## 11. Exit gate and next consumer
B1 is complete only after exact-head documentary/semantic-contract review passes.
Its next eligible consumer is a **separate Work Package C implementation order** for an isolated order-free MFI provider + deterministic harness.
That implementation may consume OHLCV and emit the outputs in §6, but it may not call order/execution/risk/position APIs and may not wire itself into LabCore.

A later V2 FILTER/ENTRY adapter remains gated by a qualified parent or separately approved new-family contract plus explicit role/direction/home semantics.
This B1 freeze does not resolve the existing Stochastic `SEMANTICS_REQUIRED / NO_QUALIFIED_PARENT` blocker and does not rank Arxon strategies.
