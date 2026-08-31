# B16 GBPUSD SELL H4 OPT01 - Entry-Surface Optimization Contract

Status: PREREGISTERED / RESEARCH_ONLY
Factory hypothesis: B16-H05-r1
Research batch: B16-OPT01 / WIDE_COARSE_ENTRY
Canonical base at preregistration start: 72229aabc1e8a6c6ce158aa4d3e49197e5c71b98
Runtime: MT5-lane2 / D:\\Meta 5b
Search data: MAIN 2023.01.01..2025.12.31 ONLY
HOLDOUT: UNSPENT / FORBIDDEN

## Direct consumer

Determine whether the accepted B16 / GBPUSD / SELL / H4 local profile contains a stable RSI-entry region around its accepted trigger before any wider mechanism optimization is considered. The output is a region/center decision, not an optimizer-winner promotion.

## Accepted evidence reused - do not rediscover

- Step 5 HYP-B16-GBP-SELL-TFPORT-01 is canonical and independently reviewed at 72229aabc1e8a6c6ce158aa4d3e49197e5c71b98.
- The exact frozen SELL child is H4-local under the preregistered adjacent-timeframe test.
- Accepted H4 SELL lead: MAIN PF 7.97, trades 80, net +283.20, native EqDD 1.72%; BWD PF 14.36, trades 76, net +268.97, native EqDD 1.27%.
- Accepted SELL set SHA256: c0e7cfad84236b798dece5b5106d271c708553fb220af370dba913d8610105de.
- Build receipt: r-4fa94d22907b446ebc721d524bdfa5d1; EX5 SHA256: 212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db.
- Accepted H4 SELL observed max basket depth is 4; _16_AtrMultAfter (post-order-4 tier) is outside the first optimization consumer and remains frozen.

## Causal claim

The H4-local SELL profile has a stable RSI-entry region around accepted RsiPeriod=14 / RsiHigh=70. Moving the memory horizon and overbought threshold within a bounded, semantics-preserving lattice should reveal a non-boundary positive plateau rather than a single isolated profit spike.

## Frozen architecture and configuration

The parent is the exact accepted SELL_DIRECTION configuration. _16_Direction=2 remains locked. Position engine, spacing, exits, sizing, runtime identity, protection and safety inputs remain frozen. This contract does not change risk/default semantics.

Only two dimensions are TUNABLE:

| Parameter | Search lattice | Baseline | Semantic reason |
|---|---|---:|---|
| _16_RsiPeriod | 7..28 step 7 = {7,14,21,28} | 14 | integer RSI memory horizon; bounded half-to-double study around the accepted value |
| _16_RsiHigh | 60..80 step 5 = {60,65,70,75,80} | 70 | SELL trigger remains strictly above neutral 50 and centered on accepted overbought threshold |

The ranges are prospective starting search lattices, not measured optima and not universal safe ranges. No value may be added after observing results under this hypothesis.

## Search execution

WIDE/COARSE:
- GBPUSD / H4;
- MAIN 2023.01.01..2025.12.31 only;
- Model 1;
- MT5 Optimization=2 Fast Genetic;
- criterion 7 Complex Criterion is only the search-engine ordering signal, not the final selector;
- USD 10,000, leverage 1:100;
- exact accepted build receipt / EX5 identity;
- full set surface, exact frozen non-tunable values;
- optimize_guard must ALLOW both dimensions under B16-H05-r1; no -SkipOptimizeGuard.

If Fast Genetic does not expose every neighbour needed to judge a possible plateau, a bounded COMPLETE verification may evaluate only missing cells from the same preregistered 4x5 lattice. This is not a range expansion and may not introduce a new value.

## Prospective plateau rule / falsifier

A plateau center must be interior on both axes:
- RsiPeriod center in {14,21};
- RsiHigh center in {65,70,75}.

For a center to be admissible, the center and its four orthogonal one-step neighbours must each be mechanically accepted and have MAIN net profit > 0.

If no admissible center exists after the preregistered lattice is fully known, the stable-entry-region claim is FALSIFIED and this hypothesis stops. Do not add spacing/exit dimensions, expand ranges, use BWD to search, or spend HOLDOUT.

If multiple admissible centers exist, select deterministically:
1. maximum of the minimum MAIN net profit across the five-cell cross;
2. tie-break: higher minimum trade count across the cross;
3. tie-break: lower maximum native EqDD% across the cross;
4. tie-break: smaller Manhattan lattice distance from accepted 14/70.

No PF-max or single best optimizer row can override this rule.

## Downstream validation

Only one locked center may continue. First reproduce it as a fixed-config MAIN single test; if mechanically consistent, run one frozen BWD 2020.01.01..2022.12.31 validation. BWD is validation only and cannot select a different parameter pair. Year split, cycle/exposure, position count, total lots, entry span, concentration and native EqDD must be reported before any later transition.

## Mechanical acceptance

Require exact hypothesis/binding identity, exact build/EX5/config, correct GBPUSD/H4/window/model, leverage MATCH, fresh artifact provenance, non-truncation, and no unauthorized Y-flagged dimension. Strategy loss is evidence, not mechanical failure.

## Authority ceiling

No H04 naming/unlock, HOLDOUT, Candidate, DEMO/LIVE, deployment/runtime attachment, trading, risk/default change, KINT resolution or Grade authority. Any later mechanism dimension requires a new prospective hypothesis and direct consumer.
