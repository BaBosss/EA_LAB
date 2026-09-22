# FB-A01 — Adaptive Donchian Trend Flip

## 1. Thesis

Capture directional expansions only when a Donchian breakout, SuperTrend direction and acceptable volatility regime agree. Hold the winning leg with a trailing/structural exit and reverse only after the old side is fully closed.

This is a **trend-following / breakout** hypothesis. It does not inherit the Facebook post's 82/100 code-readiness score as performance evidence.

## 2. Evidence versus EA_LAB design

Owner-supplied screenshots explicitly mention Donchian, Adaptive ATR percentile, SuperTrend, Breakout, Stop & Reverse, `WaitPositionsClosed`, MaxPositions, OneTradePerBar, pending/duplicate guards, spread protection and trailing SL.

The screenshots do not expose the exact indicator formulas, periods, percentile window, breakout equality rule or stop distances. Those details must be frozen by the executable contract; they are not reconstructed as facts about the external EA.

## 3. V0 role

- Direction: LONG and SHORT.
- Position style: one directional strategy position at a time.
- Entry owner: Donchian breakout.
- Confirmation owner: SuperTrend state.
- Volatility owner: ATR-percentile regime gate.
- Exit owner: trailing trend/volatility stop plus explicit opposite-signal reversal.
- Lot mode for first research build: fixed-lot only; risk-percent sizing remains a later separately reviewed surface.

## 4. Decision timing

Signals are evaluated from completed bars only. The breakout channel must exclude the decision bar so the trigger cannot move with the same bar being tested.

Prospective closed-bar definitions:

- `Upper = highest(High, DonchianBars, bars 2..N+1)`
- `Lower = lowest(Low, DonchianBars, bars 2..N+1)`
- decision price = `Close[1]`
- BUY breakout: `Close[1] > Upper + BreakoutBuffer`
- SELL breakout: `Close[1] < Lower - BreakoutBuffer`

Exact equality handling and buffer units must be frozen before code execution. The owner-approved design prefers an ATR-relative buffer rather than a hard-coded pip value.

## 5. SuperTrend confirmation

A valid long breakout additionally requires `SuperTrendState = UP`; a valid short breakout requires `DOWN`.

The executable contract must freeze the SuperTrend ATR period, multiplier, price source, band-carry rule, initial/warmup state and closed-bar finality. No external proprietary indicator is assumed.

## 6. ATR-percentile volatility gate

Compute current closed-bar ATR and rank it against a frozen historical ATR window. The gate classifies volatility into at least:

`LOW / NORMAL / HIGH / EXTREME`

V0 structural policy:

- `LOW`: no new entry or a separately frozen conservative breakout threshold;
- `NORMAL`: entry permitted;
- `HIGH`: entry permitted only with the frozen wider buffer/stop policy;
- `EXTREME`: block new entries.

Percentile cutoffs and history length are experiment parameters, not inferred facts from the screenshot.

## 7. Entry state machine

Required state sequence:

`FLAT -> LONG` or `FLAT -> SHORT`

No same-direction duplicate may be opened on repeated ticks/bars. `OneTradePerBar`, max-position and pending/position guards must be deterministic.

When an opposite qualified signal appears while a position is open:

`LONG -> CLOSING_LONG -> FLAT_VERIFIED -> SHORT`

or

`SHORT -> CLOSING_SHORT -> FLAT_VERIFIED -> LONG`

The reverse order may not be submitted until the old strategy-owned position is confirmed flat. A close refusal, partial close, stale position view or execution error fails closed and cancels the immediate reverse attempt.

## 8. Exit model

V0 is designed to let trends run rather than force a small fixed TP.

The first executable contract should compare or freeze one primary trailing owner only, with no hindsight mixing:

1. SuperTrend trailing line; or
2. ATR trailing distance.

An initial protective stop remains mandatory for the research build. Its exact ATR/structural formula must be frozen separately from the trailing rule. Shared account hard-kill/risk cages stay authoritative.

## 9. Anti-churn and execution guards

Mandatory mechanics before performance interpretation:

- one decision per closed bar;
- one active strategy position maximum;
- position/pending duplicate guard;
- minimum reverse cooldown only if preregistered;
- broker-normalized price/volume;
- spread gate;
- deterministic close/flat verification;
- no hedge overlap created by the stop-and-reverse transition.

## 10. Spread gate

The screenshot supports spread protection but does not define its formula. EA_LAB V0 should expose a source-independent guard with an absolute emergency ceiling and, if implemented, a separately frozen adaptive baseline. No spread statistic may be introduced after observing performance results.

## 11. Scientific comparators

The first meaningful mechanism study should preserve identical symbol/TF/window/lot/exit risk and compare only preregistered changes such as:

- Donchian-only breakout versus Donchian + SuperTrend confirmation;
- confirmed entry with ATR-percentile gate OFF versus ON;
- no immediate reversal versus close/flat/reverse.

Only one treatment difference per child variant under the EA R&D protocol.

## 12. Required evidence

Before any edge claim, report at minimum:

- entries, exits and reversals by timestamp;
- false-breakout/reversal frequency;
- average hold time;
- time in market;
- MAE/MFE where available;
- spread refusals and volatility-regime refusals;
- close/flat/reverse failures;
- PF/net/DD/trades only from an authorized Model-1 research contract;
- frozen same-lineage Model-4 MAIN+BWD before Candidate eligibility.

## 13. Direct consumer

A future dedicated Template identity/entry engine after a separate executable contract freezes the unresolved numeric and indicator semantics and after conflicting core-writer ownership is clear. This design does not allocate a Boss number or LAB_ENTRY.
