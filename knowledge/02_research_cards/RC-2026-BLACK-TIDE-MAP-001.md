---
card_type: RESEARCH_CARD
card_id: RC-2026-BLACK-TIDE-MAP-001
source_id: SRC-BLACK-TIDE-MAP-20260903
evidence_depth: PUBLISHED_DESIGN_DESCRIPTION
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---

# Black Tide Map / Wave — context layers for controlled attribution

## SOURCE_CLAIM

Black Tide Map is described by its current TradingView publication as a **reference layer**, explicitly not a trade system, strategy, or signal generator. Its published design separates current-flow reading in the companion Black Tide Wave from price-structure/location context in Black Tide Map.

Source-supported Map concepts relevant to EA_LAB include:

- confirmed-pivot BOS / CHoCH market structure, described as non-repainting after confirmation;
- Asia / London / New York session highs/lows and an explicit London/New York overlap clock;
- order-block origin, lifecycle, revisit-volume, and absorption-style measurements;
- confirmed-bar FVG / IFVG logic with ATR and displacement filters;
- naked/period levels and daily premium/discount location context;
- a momentum-exhaustion Trend Path using MFI and stochastic saturation.

The Map page describes Black Tide Wave as reading current flow using VWAP, K2 ribbon, opening balance, TPO profile, and a Degrees of Power meter.

## Method / context

- Market / asset: not fixed by the source description.
- Timeframe / horizon: multi-timeframe visual tool; exact transfer horizon not established.
- Sample period: none; this is a design-description source, not an empirical study.
- Method: published protected-script documentation and release notes.
- Comparison / benchmark: none.
## Result

The source supports a decomposition of chart context into independently observable layers. It does **not** report controlled evidence that those layers improve profitability or robustness.

## Limitations / caveats

Source-stated limitations:

- buy/sell split is a candle-derived proxy, not true order-flow delta;
- revisit volume is a measurement whose predictive meaning still requires testing;
- the script is protected/closed-source;
- some release behavior and module identity changed over time.

EA_LAB transfer limitations:

- no source-controlled backtest, cross-asset comparison, or out-of-sample result is available;
- session semantics are timezone-sensitive and cannot be guessed;
- Map/Wave UI combinations are not equivalent to one causal strategy change;
- combining several layers at once would confound attribution.

## EA_LAB_INFERENCE

Use the publication as **independent mechanism motivation**, not as a signal to copy. The highest-value transfer is a staged context-attribution program in which deterministic, non-repainting features are tested one family at a time against already source-bound EA outcomes.

For Boss19, the first candidate should be session context because it is simple, deterministic once timezone/session semantics are frozen, and orthogonal to the P4 classifier labels that already failed to yield a stable lever. No London-only, New-York-only, overlap-only, BOS/CHoCH, OB, FVG, or VWAP rule is adopted from this card.

Later feature families may be considered only after the prior family reaches a decision: session -> structure -> consolidation/displacement/location -> optional OB/FVG/value context. Do not combine them adaptively to rescue a failed result.

## Links

- Proposed hypothesis: `knowledge/10_synthesis/HYP-SB-005-black-tide-session-context.md`
- Current Boss19 blocker/decision owner: `docs/research/BOSS19_P4_2022_CONFOUND_DIAGNOSTIC_20260903.md`
- Contradicting cards: none identified; lack of performance evidence is preserved as an explicit limitation.
- Existing experiment/evidence IDs: Boss19 accepted P4 broad36 / regime-attribution evidence only; this card creates no new ExperimentContract.
