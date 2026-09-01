---
card_type: COMPONENT_NOTE
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---

# Formulaic alphas are reusable building-block patterns, not copy-paste EAs

`RC-SSRN2701346-001` shows how short-horizon alphas can be expressed as combinations of price, return, volume, VWAP, ranking, decay and industry-neutralization operators. The source mixes mean-reversion and momentum at the building-block level.

## Alpha Primitive Library

The useful EA_LAB abstraction is not the paper's individual formulas. It is a small vocabulary of **observable + operator + semantics** that can be composed into falsifiable hypotheses.

### Observable primitives

| Primitive | Meaning | Transfer caveat |
|---|---|---|
| `OPEN/HIGH/LOW/CLOSE` | bar price observations | broker feed/session definition must be explicit |
| `RETURN/DELTA` | change over a specified horizon | exact arithmetic/log convention and lag must be frozen |
| `VWAP` | volume-weighted price | OTC FX/CFD volume semantics can differ from centralized-market volume |
| `VOLUME` | activity / participation observable | tick volume is not interchangeable with exchange volume |
| `RANGE/VOLATILITY` | dispersion / bar-range information | estimator and sampling horizon are first-class semantics |

### Temporal operators

- lag / delay;
- difference / return;
- rolling sum / mean;
- rolling min / max;
- rolling standard deviation / dispersion;
- time-series rank;
- rolling covariance / correlation;
- decay / weighted memory;
- scaling / normalization;
- sign / signed power;
- conditional branch.

### Cross-sectional operators

- rank across a frozen universe;
- cross-sectional normalization;
- group/industry neutralization;
- pairwise relative-value comparison.

These require synchronized comparable observations. They must not be silently approximated by running the same single-symbol EA separately.

## Primitive record requirements

Every reusable primitive or generated hypothesis should bind:

1. raw observable inputs;
2. exact operator / formula family;
3. time-series versus cross-sectional semantics;
4. source timestamp and information-availability timing;
5. lag/delay convention;
6. sign/direction hypothesis;
7. lookback / holding horizon;
8. normalization / neutralization requirement;
9. universe or pair requirement;
10. expected market mechanism;
11. execution/cost sensitivity;
12. transfer limitations;
13. deterministic implementation capability;
14. falsifier.

## Research-use rule

Use primitives to generate **mechanism-first** hypotheses:

`primitive -> economic/market mechanism -> exact semantics -> prospective test`.

Do not use them as a combinatorial formula generator that searches thousands of expressions and promotes the highest backtest score. Multiple-testing/selection history remains part of the evidence.

One child experiment should change one logical mechanism at a time.

## Transfer boundary

Do not transplant a formula if the target market lacks the same data timing, cross-sectional universe, volume semantics, neutralization capability, or execution assumptions.

The QuantCorner catalog adds many alpha-design references, but entries that have not been source-reviewed remain `CATALOG_ONLY`; their filenames do not expand this primitive library automatically.

## Links

- Existing source card: `knowledge/02_research_cards/RC-SSRN2701346-001.md`
- Multiple testing: `knowledge/06_validation/multiple-testing-and-selection.md`
- QuantCorner intake: `knowledge/10_synthesis/QUANTCORNER-20260901-paper-intake-and-gap-matrix.md`
