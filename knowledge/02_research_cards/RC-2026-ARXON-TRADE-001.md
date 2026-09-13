---
card_type: RESEARCH_CARD
card_id: RC-2026-ARXON-TRADE-001
source_id: SRC-ARXON-TRADE-20260913
evidence_depth: PUBLISHED_DESIGN_DESCRIPTION
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---

# Arxon Trade tools — indicator components for controlled one-change testing

## SOURCE_CLAIM

The user-supplied Arxon Trade tools page groups a set of chart/research tools around market context and oscillator/volume confirmation:

- Black Tide Wave: TPO, opening balance, anchored VWAPs, K2 ribbon, and Degrees of Power.
- Black Tide Map: modular structure/location context including market structure, order blocks, FVGs, key levels, daily zones, consolidation, and session clock.
- Arxon OBV+: OBV with divergence detection and slope colouring.
- Arxon MFI+: MFI represented as bullish / bearish / undecided band states.
- Stochastic + Dual Zone Entry: a one-shot event when both `%K` and `%D` enter the same adjustable extreme zone together.
- RSI Cross Alert: RSI zone-extreme peak/trough marking with smoothing choices and optional divergence.

The accessible TradingView Stochastic and RSI scripts are protected/closed-source. Public descriptions support only the documented behaviour, not implementation-equivalent reproduction.
## Method / context

- Market / asset: not fixed by the source page.
- Timeframe / horizon: not established as a transferable research home.
- Sample period: none; these are published indicator descriptions, not empirical studies.
- Method: source-description intake plus accessible TradingView release descriptions for Stochastic and RSI.
- Performance benchmark: none.

## Result

The sources support a decomposition into independently testable **components/events**. They do not support adopting a complete Arxon strategy or claiming profitability.

## Limitations / contradictions

- Black Tide overlaps existing EA_LAB Second Brain material and its Boss19 session-context branch is already falsified/parked.
- OBV+ lacks a public exact divergence/slope contract in the intake evidence.
- MFI+ lacks a public exact period/band/decision contract in the intake evidence.
- RSI timing is ambiguous across the public description and later release notes; exact Arxon parity cannot be asserted without source code or a single authoritative semantic statement.
- Stochastic has the clearest event definition, but the source does not say whether the event should be traded as reversal, continuation, entry gate, exit, or context.
- None of the sources supplies controlled MAIN/BWD, Model-4, cross-symbol, cost, or drawdown evidence.

## EA_LAB_INFERENCE

Treat Arxon as a **source of independently testable mechanisms**, not as an instruction to combine all tools. The highest-information first consumer is the Stochastic Dual Zone event because its source rule is relatively explicit and can be frozen without guessing its indicator calculation.
A future experiment should change exactly one causal element relative to one already qualified parent/home. It must prospectively state whether the Arxon-derived event is an entry rule, entry filter, exit rule, or context label; that mapping is an EA_LAB experiment choice, not a source claim.

No parameter optimization should be opened by this card. First evidence should be fixed-config, source-traceable, and use the canonical research model/window rules. Any later parameter search requires a separate qualified-survivor contract.

## Backtest readiness classification

- `Stochastic Dual Zone`: `WAITING_PARENT_AND_PREREGISTRATION`.
- `RSI Cross Alert`: `SEMANTICS_REQUIRED` before preregistration.
- `MFI+`: `SEMANTICS_REQUIRED` before preregistration.
- `OBV+`: `SEMANTICS_REQUIRED` before preregistration.
- `Black Tide session context`: `CLOSED_NEGATIVE / DO_NOT_REOPEN` via `HYP-SB-005`.
- Other Black Tide modules: possible future one-change research only; no rescue chain from `HYP-SB-005`.

## Links

- Source note: `knowledge/01_sources/ARXON_TRADE_SOURCE_NOTE_20260913.md`
- Future-work plan: `knowledge/10_synthesis/ARXON_TRADE_BACKTEST_PLAN_20260913.md`
- Existing Black Tide card: `knowledge/02_research_cards/RC-2026-BLACK-TIDE-MAP-001.md`
- Closed Black Tide session hypothesis: `knowledge/10_synthesis/HYP-SB-005-black-tide-session-context.md`

This card creates no ExperimentContract and schedules no MT5 run.