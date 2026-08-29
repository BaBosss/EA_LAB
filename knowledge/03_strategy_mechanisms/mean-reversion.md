---
card_type: MECHANISM_CARD
mechanism_id: MECH-MR-001
status: RESEARCH_ONLY
transfer_status: UNTESTED_IN_EA_LAB
authority: RESEARCH_ONLY
---

# Mean Reversion

## Thesis

Exploit temporary deviations from a reference level or relative relationship when there is evidence that the deviation tends to decay.

## Inputs / components

The tracked SSRN-151 extraction includes IBS single-bar reversion, OU-style log-price mean reversion, pairs trading, and cluster/cross-sectional reversion. These are different mechanisms and must not be treated as interchangeable merely because all are labeled mean reversion.

## Expected operating envelope

Range-like or statistically stable relationships are the natural hypothesis; strong persistent trend or structural breaks can invalidate the expected reversion.

## Failure modes

- mistaking a structural trend/break for temporary deviation;
- non-stationary reference relationships;
- cost/turnover overwhelming a short-horizon edge;
- cross-sectional methods being reduced incorrectly to a single instrument.

## Evidence links

- Supporting: `SRC-EALAB-SSRN151-CATALOG`, `SRC-EALAB-SSRN151-MECHANISMS`
- Contradicting: not yet normalized in the seed corpus
- EA_LAB evidence: none asserted here

## Transfer note

Every variant needs its own hypothesis, reference definition, horizon, target symbol, and controlled validation.
## Batch 2 full-text evidence

`RC-SSRN4708400-001` adds a concrete short-horizon ETF example: a TSI-centered long-only oversold system for SPY/QQQ with RSI and other supporting filters, evaluated across stated IS/OOS windows and paper trading.

This evidence does **not** collapse TSI, RSI, moving averages, IBS, OU, pairs, or other reversion variants into one mechanism. The transferable unit remains the exact reference definition, signal horizon, market, execution timing and validation design.

The source-reported performance is research evidence only. EA_LAB has not independently replicated the paper's parameters or accepted an EA from this card.
## Strategy-development evidence

`RC-SSRN4878676-001` adds a practical mean-reversion development workflow with exact rule translation, transaction fees, bounded optimization, walk-forward/real-time evaluation, entry/exit, risk management and position sizing as separate design concerns.

The workflow is reusable; the paper's indicator choices are not promoted as universal rules.