# Arxon Trade tools source note — 2026-09-13

Status: `RESEARCH_ONLY / SOURCE_INTAKE`

Purpose: record the user-supplied Arxon Trade tools page as source-grounded research input for EA_LAB Second Brain. This note records published indicator/tool descriptions and explicit evidence gaps only. It is not performance evidence and creates no strategy, optimization, HOLDOUT, Candidate, risk, runtime, deployment, or trading authority.

## Primary sources

1. Arxon Trade tools page: `https://pmpenguin.github.io/arxon-trade/#tools`
2. TradingView — **Stochastic + Dual Zone Entry**, by `peeradetm`: `https://www.tradingview.com/script/cQJIPUHO-Stochastic-Dual-Zone-Entry/`
3. TradingView — **RSI Cross Alert**, by `peeradetm`: `https://www.tradingview.com/script/8T3APTKB-RSI-Cross-Alert/`
4. Existing canonical EA_LAB Black Tide source bundle: `SRC-BLACK-TIDE-MAP-20260903`.

Retrieved: `2026-09-13`.

The Arxon page also links Black Tide Wave, Black Tide Map, Arxon OBV+, Arxon MFI+, manuals, and TradingView pages. Where the linked protected/manual content was not directly retrievable in this intake, only the Arxon page's own published description is treated as source evidence.

## SOURCE_CLAIM — Black Tide Wave / Black Tide Map

Arxon describes **Black Tide Wave** as a session-context overlay combining four named layers: TPO market profile, opening-balance range, anchored VWAPs, and a K2 trend ribbon, plus a `Degrees of Power` directional score.

Arxon describes **Black Tide Map** as a modular map containing 11 independently toggleable modules including Trend Path, Market Structure, Order Blocks, Fair Value Gaps, key levels by session/day, daily zones, anchor candles, consolidation, and a session clock.

These descriptions materially overlap the already registered canonical Black Tide source bundle and do not reopen the previously closed session-context branch.
## SOURCE_CLAIM — Arxon OBV+

The Arxon page describes **Arxon OBV+** as On-Balance Volume extended with divergence detection and slope colouring, intended to show whether volume behaviour confirms or disagrees with price. The intake source does not publish the exact divergence pivot rules, slope lookback, thresholds, confirmation timing, or executable formula changes beyond standard OBV.

## SOURCE_CLAIM — Arxon MFI+

The Arxon page describes **Arxon MFI+** as a Money Flow Index view split into three states: bullish above an upper band, bearish below a lower band, and undecided between the bands. The intake source does not establish exact period, band defaults, smoothing, timeframe mapping, or whether these states are intended as entry, filter, or display-only semantics.

## SOURCE_CLAIM — Stochastic + Dual Zone Entry

The directly accessible TradingView publication is a protected/closed-source script based on classic `%K/%D`. It marks the exact entry bar when **both** lines enter the same extreme zone together, fires once rather than on every sustained zone bar, and exposes `%K` length, `%K` smoothing, `%D` smoothing, and dynamic upper/lower band inputs. Published defaults are upper `80` and lower `20`.

The publication describes the overbought marker when both `%K` and `%D` cross above the upper band and the oversold marker when both cross below the lower band. This is a published event definition, not evidence that the event predicts profitable reversal or continuation.

## SOURCE_CLAIM — RSI Cross Alert

The directly accessible TradingView publication is a protected/closed-source RSI extension with adjustable upper/lower bands, peak/trough markers, smoothing choices (`SMA`, `EMA`, `RMA`, `WMA`, `VWMA`, `SMA + Bollinger Bands`), and optional regular bullish/bearish divergence.

The current public page contains a timing-description conflict that must be preserved. Its main description says the maximum overbought peak / minimum oversold trough is printed after RSI exits the zone; later release text says a peak/trough can be marked one candle after the extreme is confirmed by an opposite-direction RSI bar while still in the zone, with re-marking if a new extreme occurs. Because the implementation is closed-source, this intake does not silently choose one behaviour as exact Arxon parity.
## DEDUP / NEGATIVE-KNOWLEDGE BOUNDARY

EA_LAB already registered Black Tide Map/Wave under `SRC-BLACK-TIDE-MAP-20260903` and tested the one-change Boss19 session-context candidate `HYP-SB-005`. That branch is `FALSIFIED_STOP_EXPANSION_PARK`: no named session survived its preregistered robustness checks. Therefore this Arxon intake must not relabel, rerun, or rescue that session branch by changing hours, DST treatment, overlap precedence, or adding another Black Tide layer.

A future Black Tide-derived experiment is admissible only as a genuinely new independently motivated one-change hypothesis with its own direct consumer and preregistration.

## EA_LAB_INFERENCE — useful transfer shape

The new value of this intake is a **component hypothesis pool**, not a complete trading system:

- `Stochastic Dual Zone` is the most directly reproducible event candidate because its public event rule is relatively explicit.
- `RSI Cross Alert` is potentially reproducible only after EA_LAB freezes one explicit timing interpretation; it must not be called exact Arxon parity while the public descriptions conflict.
- `MFI+` is a possible three-state momentum/flow context component but remains `SEMANTICS_REQUIRED` before experiment design.
- `OBV+` is a possible volume-confirmation/divergence component but remains `SEMANTICS_REQUIRED` before experiment design.
- Black Tide modules remain linked to the existing Black Tide card and closed negative evidence; they are not duplicated here as new strategy claims.

## Evidence boundary

These sources describe indicator architecture, display states, and event ideas. They provide no controlled evidence that any Arxon component improves PF, net profit, drawdown, robustness, transfer across symbols/timeframes, or portfolio value.

Required causal path remains:

`published description -> exact semantic freeze -> one-change preregistration -> controlled EA_LAB backtest -> evidence -> interpretation -> decision`.

No backtest is authorized by this source note alone.