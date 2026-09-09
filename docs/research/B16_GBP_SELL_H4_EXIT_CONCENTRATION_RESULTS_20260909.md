# B16 GBPUSD/H4 SELL Exit-Concentration Results

Status: `BLOCKED_CONFIGURATION_CONFOUND / RESEARCH_ONLY`
Hypothesis: `HYP-B16-GBP-H4-EXITCONC-01`
Base: `2d298598d859fbbb9c0981e58050b27402405bee`
Execution: zero new MT5 runs; Optimization `NONE`; HOLDOUT `UNSPENT`.

## Evidence

The proposed control is valid. `SELL_DIRECTION/GBP_H4` reproduces the accepted SELL `14/70` parent exactly on MT5 lane2 / `D:\Meta 5b` / Model 1:

| Window | Net | PF | Trades | Native EqDD |
|---|---:|---:|---:|---:|
| MAIN | +283.20 | 7.97 | 80 | 1.72% |
| BWD | +268.97 | 14.36 | 76 | 1.27% |

All six source cells use build receipt `br-4fa94d22907b446ebc721d524bdfa5d1` and EX5 SHA256 `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`. Set SHA256 identities are `c0e7cfad84236b798dece5b5106d271c708553fb220af370dba913d8610105de` for the SELL control, `4f900139ae9e8acdff17198e6721028f769da1fb546b4be1415d050658e00fd1` for SingleTP off, and `04fbab069a582091f5e9a3833bc9bb4f67b20a079ac35b5c479db65586687eec` for BasketTP off. Raw child headlines are descriptive because of the configuration problem:

| Child window | Net | PF | Trades | Native EqDD |
|---|---:|---:|---:|---:|
| SingleTP off MAIN | +175.20 | undefined, no gross loss (MT5 field 0.00) | 3 | 1.33% |
| SingleTP off BWD | -802.83 | 0.41 | 40 | 13.16% |
| BasketTP off MAIN | +389.29 | undefined, no gross loss (MT5 field 0.00) | 3 | 3.90% |
| BasketTP off BWD | -456.59 | 0.56 | 24 | 13.50% |

The children do not satisfy the protocol's one-variant/one-logical-change rule. Each differs from that SELL parent on direction plus the named exit input:

| Child | Difference 1 | Difference 2 |
|---|---|---|
| `SINGLETP_OFF` MAIN+BWD | `_16_Direction: 2 -> 1` | `_16_TpSingleAtrMult: 0.35 -> 0.0` |
| `BASKETTP_OFF` MAIN+BWD | `_16_Direction: 2 -> 1` | `_16_BasketTpUsdPer01: 16.0 -> 0.0` |

The frozen calculations are preserved separately as `DESCRIPTIVE_NON_CAUSAL`. All four mechanically eligible child windows meet the frozen `>=3 of 4` concentration calculation, giving descriptive `C/E = 4/4`:

| Child window | Max hold, parent -> child | Active share, parent -> child | Top-1 positive-cycle GP share, parent -> child | Zero-close years, parent -> child | Descriptive result |
|---|---:|---:|---:|---:|---|
| SingleTP off MAIN | 106.91d -> 1029.17d | 19.71% -> 71.24% | 18.02% -> 81.37% | 0 -> 1 | 4/4 shift |
| SingleTP off BWD | 41.55d -> 644.16d | 8.93% -> 59.34% | 20.14% -> 29.13% | 0 -> 1 | 4/4 shift |
| BasketTP off MAIN | 106.91d -> 1061.33d | 19.71% -> 72.69% | 18.02% -> 100.00% | 0 -> 2 | 4/4 shift |
| BasketTP off BWD | 41.55d -> 1023.50d | 8.93% -> 70.39% | 20.14% -> 98.91% | 0 -> 1 | 4/4 shift |

These are observations of confounded BUY-plus-exit configurations, not causal SELL exit-only evidence. Exact source/report/config hashes and tester lineage are in `factory/runs/b16_exitdiag_20260909/gbp_h4/source_manifest.json`; raw metrics and year participation are in `diagnostic_summary.csv` and `year_participation.csv`. Package acceptance records `causal_sell_exit_only_attribution=false` and `preregistered_causal_question_answered=false`.

## Interpretation

Direction is a material B16 mechanism, so a direction change cannot be treated as incidental. The descriptive `4/4` result cannot distinguish an exit effect from the BUY-versus-SELL change and therefore cannot answer the preregistered third-context GBP SELL exit-only question.

Negative-memory disposition is `NO_PRIOR_MATCH` for a valid GBPUSD/H4 SELL exit-only replication: the existing reports match symbol, timeframe, windows, model, and exit-off values, but fail the required direction and one-logical-change dimensions.

## Decision

`BLOCKED_CONFIGURATION_CONFOUND`. Do not record a third-context causal replication and do not change the frozen exits.

No repair experiment is opened here. The only admissible next consumer, if separately authorized and preregistered later, is a one-change SELL `14/70` experiment that retains `_16_Direction=2` and changes only the applicable exit input. No new threshold, retuning, alternate proxy, or reuse of these confounded child reports can substitute for that evidence.

## Authority Ceiling

`RESEARCH_ONLY`. Model 4 and Monte Carlo are `NOT RUN`; HOLDOUT is `UNSPENT`; `QUALITY_GRADE` and `EVIDENCE_CONFIDENCE` remain `UNRATIFIED`. No optimization, exit/default change, Candidate/Grade/KINT, DEMO/LIVE, deployment, runtime, trading, or risk/default authority follows.
