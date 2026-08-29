---
card_type: MECHANISM_CARD
mechanism_id: MECH-TREND-001
status: RESEARCH_ONLY
transfer_status: UNTESTED_IN_EA_LAB
authority: RESEARCH_ONLY
---

# Trend Following

## Thesis

Exploit persistence by taking exposure in the direction of an established trend rather than forecasting a turning point.

## Inputs / components

The tracked SSRN-151 extraction includes single/two/three moving-average rules, Donchian/channel logic, volatility-scaled trend weights, and `tanh(R/kappa)` smoothing intended to reduce sign-flip/whipsaw behavior.

## Expected operating envelope

Persistent directional markets are the natural hypothesis. Choppy/range regimes are a known structural threat because repeated direction changes can create whipsaw.

## Failure modes

- range-bound/noisy price action;
- cost drag from frequent flips;
- parameter selection that only fits one historical trend regime;
- transfer mismatch from cross-sectional/futures research to retail MT5 instruments.

## Evidence links

- Supporting: `SRC-EALAB-SSRN151-CATALOG`, `SRC-EALAB-SSRN151-MECHANISMS`
- Contradicting: not yet normalized in the seed corpus
- EA_LAB evidence: none asserted here

## Transfer note

Treat MA/Donchian/vol-scale/tanh variants as experimentable components, not accepted production rules.