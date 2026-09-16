# Arxon RSI Cross Alert — B4 source-semantic freeze

Date: 2026-09-16
Status: **B4_SOURCE_FREEZE / TIMING_VERSION_CONFLICT / NO_TRADING_ROLE / IMPLEMENTATION_BLOCKED_PENDING_VERSION_SELECTION**
Canonical parent at authoring: `2a42b8aee98dbd2437de1b684ae96893ee2916c4`.

## 1. Scope and authority
This contract records only what the fresh public RSI Cross Alert page supports and makes its internal timing conflict fail-visible.
It does **not** select an exact implementation version, BUY/SELL direction, ENTRY/FILTER/EXIT role, parent/home, risk, FamilyID, LAB_ENTRY, MT5 research or deployment.

## 2. Source binding
Fresh public capture:
- Source id: `S07`
- Publisher page: `https://www.tradingview.com/script/8T3APTKB-RSI-Cross-Alert/`
- Evidence text: `D:\EA_LAB_CONTROL\evidence\arxon-strategy-cards-20260916\S07.txt`
- Captured HTML SHA256: `e78799f92b1656719a6095a84f3b93fe743efa0f1427448d613ee6686cf90604`
- Observed: `2026-09-16T13:22:25+07:00`
Protected Pine source is unavailable.

## 3. Stable public facts
The indicator is based on classic RSI and exposes adjustable upper/lower band levels, including decimals.
It tracks the highest RSI value reached in an overbought episode and the lowest RSI value reached in an oversold episode.
The public feature list exposes smoothing choices: `SMA`, `EMA`, `RMA`, `WMA`, `VWMA`, and `SMA + Bollinger Bands`.
Regular bullish/bearish divergence detection is optional.
Marker visibility and marker size are user controls.
The page's usage prose calls the overbought peak a potential reversal down and the oversold trough a potential reversal up, but that is descriptive guidance, **not** an EA order mapping.

## 4. Public timing conflict — do not collapse it
The same captured page contains materially different timing descriptions:
- current feature prose: peak/trough marker is printed only **after RSI exits** the overbought/oversold zone;
- v1.4 history: peak/trough markers are confirmed on zone exit;
- v1.6 release note: a peak marker appears **one candle after** the highest RSI point is confirmed by a declining RSI bar, and resets/re-marks if a newer high occurs inside the same overbought episode;
- v1.6 trough behavior is the mirror: one candle after the lowest RSI point is confirmed by a rising RSI bar, with reset/re-mark on a newer low;
- v1.7.1 later restores a timeframe selector.

These are not equivalent causal event definitions.
B4 therefore refuses to label either `EXIT_CONFIRMED_EXTREME` or `REVERSAL_BAR_CONFIRMED_EXTREME` as the current protected-script behavior without a version-qualified reference.

## 5. What can be frozen now
A future provider may safely separate these source concepts:
- `rsi_value`;
- upper/lower band membership;
- running maximum RSI and its source bar during one overbought episode;
- running minimum RSI and its source bar during one oversold episode;
- an explicit marker/event confirmation time distinct from the historical extreme bar;
- optional smoothing output;
- optional regular divergence output.

The historical extreme's source bar must never be treated as if the event had been observable there before confirmation.
## 6. Still unresolved before implementation
Public prose does not freeze the exact RSI period/default, default band values, price source, smoothing default/length, Bollinger parameters, equality-at-band behavior, or warmup policy.
It also does not freeze divergence pivot rules, left/right confirmation, pairing window, equality/tie handling, event expiry, or repaint/finality behavior.
The restored timeframe selector needs an explicit selected-timeframe/completed-bar contract before an EA provider can be causal.

A provider implementation must therefore be version-labelled and must bind:
1. selected timing mode/reference version;
2. RSI calculation parameters and source;
3. band equality and episode-reset rules;
4. marker confirmation timestamp versus extreme timestamp;
5. timeframe and completed/developing-bar policy;
6. smoothing and divergence options independently.

## 7. Future deterministic acceptance cases
Before any adapter, tests must include:
- one overbought episode with several higher RSI highs;
- one oversold episode with several lower RSI lows;
- exit-confirmed timing fixture;
- reversal-bar-confirmed timing fixture;
- a new extreme after a provisional mark candidate;
- exact-band equality and repeated zone entry/exit;
- insufficient/missing/non-finite inputs;
- restart and prefix invariance;
- historical marker bar distinct from `confirmed_at`.

No single fixture may be called Arxon parity until the selected public/protected version is bound.

## 8. Gate outcome
Stable feature inventory is source-supported, but event timing remains `SEMANTICS_REQUIRED / VERSION_CONFLICT`.
No RSI provider should be presented as an exact Arxon clone yet.
No performance claim, optimization, BWD/HOLDOUT use, Candidate, risk/default, runtime, deployment or trading authority follows.
