---
card_type: RESEARCH_CARD
card_id: RC-FINDYOUR8-001
source_id: SRC-EALAB-FINDYOUR8-CATALOG
evidence_depth: DERIVED_CATALOG
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---

# FINDYOUR8 — Adaptive Volatility-Aware Grid Seed

## SOURCE_CLAIM

The tracked EA_LAB catalog describes an Adaptive Grid concept whose zone is derived from a 10,000-path, 60-day block-bootstrap simulation using a 1,000-day history and 24-day blocks, with P10/P90 used as lower/upper grid bounds. The same catalog records spacing near `0.3 x ATR(RMA30)`, flat/non-escalating lot per level, a capped band, an equity kill, and inverse-ATR sizing `BaseSize x BaseATR / CurrentATR`.

## Method / context

The source material is a derived EA_LAB extraction from a FINDYOUR8 educational PDF corpus. The examples are primarily crypto spot/PAXG/BTC oriented, not native MT5 FX/CFD evidence.

## Result

The catalog provides several reusable grid-design levers: statistically derived zone boundaries, volatility-scaled spacing, non-escalating size, and volatility-normalized exposure.

## Limitations / caveats

- The current card does not re-read the original PDF pages.
- Source examples and self-reported performance are not EA_LAB acceptance evidence.
- Porting spot concepts to MT5 CFDs introduces swap/funding, spread, execution, broker, and leverage differences.
- Bootstrap-derived P10/P90 bounds can still fail during out-of-distribution or black-swan moves.
## EA_LAB_INFERENCE

The valuable transfer is not “copy this grid.” It is a hypothesis that a bounded, flat-lot grid may become less naive when its operating band, spacing, and exposure respond to measured volatility/statistical range rather than fixed price distances.

## Links

- Related mechanism: `grid.md`
- Proposed synthesis: `SEED-001-adaptive-volatility-aware-grid.md`
- Existing experiment/evidence IDs: none asserted by this card
