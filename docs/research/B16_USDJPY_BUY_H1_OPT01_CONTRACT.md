# B16 USDJPY BUY H1 H08 OPT01 - Entry-Surface Optimization Contract

Status: PREREGISTERED / RESEARCH_ONLY
Factory hypothesis: B16-H08-r1
Research batch: B16-H08-OPT01 / WIDE_COARSE_ENTRY
Canonical base at preregistration start: 4e5c7d9410e1e0136c367375caff417ca23a5123
Runtime forecast: NORMAL 15-30m; bottleneck = MT5 Model-1 optimizer + bounded missing-cell verification; parallel-safe on a free MT5 lane only.
Search data: MAIN 2023.01.01..2025.12.31 ONLY
BWD: validation-only after center lock
HOLDOUT: UNSPENT / FORBIDDEN

Selection bars: report current canonical MAIN PF >=1.20 + >=100 trades and BWD PF >=1.00 + >=100 trades; H08 itself creates no new verdict/Grade threshold.
Flat-lot probe: N-A for sizing escalation because _16_LadderMult=1.0 is frozen and no lot-progression dimension is searched.

## Direct consumer

Determine whether the accepted B16 / USDJPY / BUY / H1 parent contains a stable, participation-qualified RSI-entry region around 14/30 before any finalist/robustness work. The output is a region/center decision, not an optimizer-winner promotion.

## Accepted evidence reused - do not rediscover

- Canonical B16 USDJPY/H1 BUY parent: MAIN PF 1.53 / net +252.53 / 275 trades / native EqDD 3.85%; BWD PF 1.11 / net +44.10 / 267 trades / native EqDD 2.40%.
- Exact parent full-surface bytes reconstruct identically from all nine canonical one-change characterization sets: SHA256 `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`.
- Accepted build receipt `br-4fa94d22907b446ebc721d524bdfa5d1`; EX5 SHA256 `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
- Exit concentration diagnostic is accepted/reviewed at canonical `4e5c7d94...`: current SingleTP/BasketTP behavior stays frozen; exit-off aggregate gains were dominated by sparse, very long-lived concentrated cycles.
- Position engine, spacing law, sizing, protection and safety stay frozen. No H07 GBP depth result is imported as a USDJPY default.

## Causal claim and semantic range

BUY arms when RSI on the last closed H1 bar is below `_16_RsiLow`; baseline is `_16_RsiPeriod=14`, `_16_RsiLow=30`. A stable BUY-entry region should appear around that accepted trigger when memory horizon and oversold threshold are moved within a bounded semantics-preserving lattice.

Only two dimensions are TUNABLE:

| Parameter | Prospective lattice | Baseline | Semantic reason |
|---|---|---:|---|
| `_16_RsiPeriod` | `{7,14,21,28}` | 14 | bounded half-to-double RSI memory study around 14 |
| `_16_RsiLow` | `{20,25,30,35,40}` | 30 | all values remain strictly below neutral 50; baseline 30 is an interior point |

These values are a new USDJPY/H1 BUY research lattice, not inherited authority from historical XAU BUY or GBP SELL searches and not a universal safe range. No value may be added after observing H08 results.

## Frozen architecture and execution

- Exact parent direction `_16_Direction=1` BUY.
- `_16_MaxOrdersPerSide=10`, spacing, current SingleTP/BasketTP/overlap exits, sizing, protection, risk and runtime semantics are frozen.
- MAIN only, USDJPY/H1, Model 1, USD 10,000, leverage 1:100.
- Use MT5 Optimization=2 Fast Genetic as the screen. Since the lattice has only 20 combinations, bounded COMPLETE verification may fill only missing cells from this exact 4x5 lattice; no range expansion.
- `optimize_guard` must ALLOW exactly `_16_RsiPeriod` and `_16_RsiLow` under `B16-H08-r1`; no `-SkipOptimizeGuard`.
- Parent 14/30 must reproduce on the same MT5 install before any surface interpretation.

## Prospective plateau rule / falsifier

Interior centers are Period `{14,21}` x RsiLow `{25,30,35}`. For a center to be admissible, the center plus four orthogonal one-step neighbours must each:

1. be mechanically accepted;
2. have MAIN net profit > 0; and
3. have at least 100 closed trades in MAIN under the current canonical participation floor.

If no admissible center exists after the exact lattice is fully known, the stable-entry-region claim is FALSIFIED and H08 stops. Do not add spacing/exit/depth dimensions, expand ranges, use BWD to search, or spend HOLDOUT.

If multiple centers are admissible, select deterministically by: (1) maximum minimum MAIN net across the five-cell cross; (2) higher minimum trade count; (3) lower maximum native EqDD%; (4) smaller Manhattan distance from 14/30; (5) lower Period then lower RsiLow only as a final deterministic tie-break. PF-max or Complex Criterion cannot override this rule.

## Downstream validation

Only one locked center may continue. First reproduce it as a fixed-config MAIN single test on the same install, then run one frozen BWD 2020.01.01..2022.12.31 validation. BWD may invalidate/park the center but may not select another pair. Report year split, cycle/exposure, depth, aggregate lots, active-time/concentration and native EqDD. HOLDOUT remains untouched.

## Mechanical acceptance and loop breaker

Require exact hypothesis/binding identity, exact build/EX5/config lineage, correct USDJPY/H1/window/model, leverage MATCH, fresh artifact provenance, non-truncation, and exactly two authorized Y-flagged dimensions. Strategy loss is evidence, not mechanical failure. At most one bounded mechanical repair; same unresolved question twice => BLOCKED. No search beyond the 20-cell lattice.

## Authority ceiling

RESEARCH_ONLY. No strategy/risk/default change, no automatic adoption of a new RSI pair, no H04 unlock, no HOLDOUT, Candidate, DEMO/LIVE, deployment/runtime attachment, trading, KINT resolution or Grade authority.
