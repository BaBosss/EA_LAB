---
card_type: RESEARCH_CARD
card_id: RC-DOI-RESTA00503-001
source_id: SRC-EALAB-QUANTCORNER-20260901
evidence_depth: PRIMARY_WEB_VERIFIED
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---

# Signed realized volatility contains asymmetric forecasting information in equities

Primary reference: Patton & Sheppard, *The Review of Economics and Statistics* 97(3), 2015, DOI:10.1162/REST_a_00503.

## SOURCE_CLAIM

Using high-frequency data for the S&P 500 Index and 105 individual stocks, the paper studies realized semivariances that separate variation associated with positive and negative returns.

The authors report that future volatility is more strongly related to volatility from past negative returns than from positive returns. They also report sign-asymmetric jump effects: negative price jumps are associated with higher future volatility while positive jumps are associated with lower future volatility. Models using these features improve out-of-sample volatility forecast performance in the source study.

## Method / context

- Market: U.S. equities.
- Data: high-frequency observations for the S&P 500 and 105 stocks.
- Features: positive/negative realized semivariance and signed jumps.
- Target: future volatility forecasting.

## Result

The source supports separating volatility into sign-aware realized components rather than assuming that an equal-sized positive and negative move carries identical information for future equity volatility.

## Limitations / caveats

- The empirical evidence is equities, not XAUUSD/FX/BTC.
- High-frequency realized measures require suitable intraday data quality and non-leaky construction.
- The source is about volatility forecasting; it does not by itself establish a profitable entry/exit rule.
- Sign conventions, jump estimator, sampling frequency and lookback matter.

## EA_LAB_INFERENCE

Create only a future **market-context hypothesis**: signed realized volatility / signed jump state may improve regime description or explain strategy performance.

Do not retrofit this feature into the already frozen Boss19 P4A classifier. Any FX/XAU/BTC use requires a new prospective definition and transfer test.

## Links

- New regime note: `knowledge/05_regimes/signed-volatility-and-jump-asymmetry.md`
- Hypothesis candidate: `knowledge/10_synthesis/HYP-SB-004-signed-volatility-regime-context.md`
