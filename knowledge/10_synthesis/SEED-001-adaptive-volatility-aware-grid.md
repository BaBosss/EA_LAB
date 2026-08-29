---
object_type: TESTABLE_HYPOTHESIS
hypothesis_id: HYP-SB-001
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---

# Adaptive Volatility-Aware Bounded Grid

## TESTABLE_HYPOTHESIS

A non-escalating bounded grid may be more robust than a naive fixed-distance grid when the operating zone and spacing respond to measured range/volatility, exposure decreases as volatility rises, and realistic swap/spread/funding costs are modeled explicitly.

## Mechanism

- Family: bounded grid / mean-reversion harvesting.
- Zone candidate: statistical or volatility-derived outer band rather than hand-picked S/R.
- Spacing candidate: ATR- or percentage-scaled rather than fixed absolute distance.
- Sizing candidate: flat base lot with inverse-volatility normalization; no geometric lot escalation.
- Failure condition: persistent break outside the operating band / regime change.
- Execution requirement: include target-broker spread, swap/funding, lot rules, and margin effects.

## Supporting research

- `SRC-EALAB-FINDYOUR8-CATALOG` — derived catalog describing MC P10/P90 band, ATR spacing, flat lot, inverse-ATR sizing, and bounded risk concepts.

## Contradictions / gaps

- Current seed has no direct EA_LAB MT5 controlled evidence for this exact combination.
- Original educational examples are crypto-spot oriented; FX/XAU/CFD transfer is unproven.
- Statistical bands do not protect against out-of-distribution breaks.

## Direct consumer

A future, separately authorized ExperimentContract may use this as research provenance. This file itself does not create an experiment, EA, Factory order, risk default, or deployment action.