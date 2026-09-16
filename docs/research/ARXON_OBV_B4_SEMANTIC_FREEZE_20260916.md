# Arxon OBV+ — B4 source-semantic freeze

Date: 2026-09-16
Status: **B4_SOURCE_FREEZE / CORE_OBV_IDENTIFIED / ADDON_SEMANTICS_PARTIAL / NO_TRADING_ROLE**
Canonical parent at authoring: `2a42b8aee98dbd2437de1b684ae96893ee2916c4`.

## 1. Scope and authority
This records only source-supported OBV+ component semantics and the gaps that block an exact provider clone.
It does **not** choose entry direction, parent/home, ENTRY/FILTER/EXIT role, risk, FamilyID, LAB_ENTRY, MT5 research or deployment.

## 2. Source binding
Fresh public capture:
- Source id: `S04`
- Publisher page: `https://www.tradingview.com/script/K0cUsn6T-Arxon-OBV/`
- Evidence text: `D:\EA_LAB_CONTROL\evidence\arxon-strategy-cards-20260916\S04.txt`
- Captured HTML SHA256: `30898923146e56d53c979bf1866b9fe37a1ace6cad4d2a5e44f39fcb85dae4a4`
- Observed: `2026-09-16T13:22:22+07:00`
Protected Pine source is unavailable.

## 3. Source-supported mechanism
The publisher says OBV+ is built on TradingView's built-in OBV and that the **core calculation is unchanged**.
Around that core it adds three readouts:
- cumulative OBV colored by slope, intended to show accumulation/distribution direction;
- regular and hidden divergence detection, bullish and bearish;
- a smoothing MA with cross alerts, intended to show flow-momentum turns.
The publisher explicitly says OBV+ **does not generate entries**; location, structure and risk remain external decisions.
Therefore no slope colour, divergence mark or MA cross becomes BUY/SELL by itself.

## 4. What is not exposed publicly
The fresh page does not specify:
- exact slope formula, lookback, threshold, flat/equality handling or colour transition rule;
- smoothing MA type, length, source/default, or exact cross predicate;
- divergence pivot definition, left/right confirmation, pairing window, regular-versus-hidden precedence, tie handling, or historical repositioning/finality;
- initialization/seed and warmup details beyond the statement that TradingView built-in OBV is the unchanged core;
- exact volume feed/provenance behavior for the target broker/home.

These are implementation-critical, not cosmetic omissions.
A future project implementation may use documented TradingView/standard OBV mechanics as an explicit project policy, but may not label addon behavior as Arxon parity without reference evidence.

## 5. Safe component separation
A future order-free implementation should keep these outputs independent:
- `obv_value` and validity;
- `slope_state` with its exact chosen/verified definition;
- `smoothed_obv` plus a separate cross event;
- regular bullish divergence event;
- regular bearish divergence event;
- hidden bullish divergence event;
- hidden bearish divergence event;
- source-bar and confirmation timestamps for every delayed detector.

Missing/invalid volume must be distinct from a valid flat OBV state.
A divergence marker's historical pivot bar must never be treated as its earlier availability time if confirmation occurred later.
## 6. Deterministic acceptance cases for a future provider
Before any trading adapter, tests must cover:
- unchanged core OBV sequence against a bound TradingView/reference fixture;
- rising, falling and exactly flat OBV slope cases;
- smoothing cross with equality/touch edge cases;
- each of the four divergence classes on a version-qualified pivot fixture;
- divergence confirmation timing separated from pivot/source time;
- repeated observation without duplicate event creation;
- restart/prefix invariance;
- zero/missing/invalid volume and warmup behavior.

## 7. Parity and feed gate
Exact Arxon parity remains blocked until source/reference evidence freezes the addon definitions above.
Any future broker/home contract must also bind symbol, timeframe, actual volume basis/feed, completed-bar policy and first-valid output.
Cross-feed disagreement must be reported as feed provenance, not silently called algorithm nondeterminism.

## 8. Gate outcome
B4 closes only the high-level source decomposition: unchanged TradingView OBV core plus slope, regular/hidden divergence, smoothing and cross alerts.
Slope, smoothing and divergence details remain `SEMANTICS_REQUIRED`; an exact provider implementation is not yet authorized from this source alone.
No performance claim, optimizer, BWD/HOLDOUT use, Candidate, risk/default, runtime, deployment or trading authority follows.
