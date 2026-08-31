# B16 GBPUSD SELL H4 Depth-2 Ablation — H06 Contract

Status: `PREREGISTRATION / RESEARCH_ONLY / NO OPTIMIZATION`
Hypothesis ID: `HYP-B16-GBP-SELL-H4-DEPTH2-01`
Base SHA: `50b263831e85a71a5f2d4bea417dbc00f2483a7e`
Runtime target: `MT5-lane2 / D:\Meta 5b`, serial Model-1 only after a valid Lane Registry runtime claim.

## Observation and direct consumer
The accepted B16 GBPUSD/H4 SELL research reference is positive in MAIN and BWD and all six calendar years, but realized max basket depth is 4 in both windows. Multi-entry cycles supply 70.96% MAIN and 58.94% BWD of positive gross profit. H05 RSI-entry optimization is closed and did not improve the parent.

Direct consumer: determine whether the accepted H4 SELL economics require recovery depth beyond the first adverse add before any later robustness/candidate routing. This is a structural position-engine question, not tuning or a default proposal.

## One logical change
Parent set SHA256: `c0e7cfad84236b798dece5b5106d271c708553fb220af370dba913d8610105de`.
Child set: `factory/runs/b16_h06_20260831/gbp_sell_h4_depth2/B16_GBP_SELL_H4_DEPTH2_01.set`.
Child set SHA256: `d31a34b68caaaeabca07d960dede016a8cf513fd8e4c6cf2bbe124d172d55b14`.
Sole input change: `_16_MaxOrdersPerSide: 10 -> 2`.
Direction stays SELL, RSI 14/70 stays frozen, spacing/SL/TP/sizing/cages stay byte-identical.

Source meaning: one first market position plus at most one adverse add. Basket TP remains reachable at two positions; overlap requires four positions and is therefore unreachable; post-order-4 spacing and positions 3..10 are unreachable as a consequence of the single cap change.

## Prospective hypothesis and falsifier
Statement: the first adverse add is sufficient for the frozen GBPUSD/H4 SELL child to retain positive aggregate full-window net in both MAIN and BWD.
Falsifier: after mechanical acceptance, net `<= 0` in either MAIN or BWD => `HYPOTHESIS_FALSIFIED / DEPTH_GT2_REQUIRED_FOR_DUAL_WINDOW_POSITIVITY` for this tested profile.
If both windows have net `> 0`, classify `HYPOTHESIS_NOT_FALSIFIED / DEPTH2_DUAL_WINDOW_POSITIVE`; this does not authorize adoption. `UNKNOWN_MECHANICAL` is not strategy evidence.

Secondary evidence: PF, native EqDD%, trades, year split, cycles, max depth/lots, multi-entry gross-profit share, active-time/concentration, hard-kill/truncation state. Secondary metrics cannot rewrite the primary classification after results are visible.

## Frozen execution matrix
Exactly two new cells: GBPUSD/H4 MAIN `2023.01.01..2025.12.31` and BWD `2020.01.01..2022.12.31`.
Model 1; Optimization 0; Forward 0; USD 10,000; leverage 1:100; exact GBPUSD; same Meta5b install lineage.
Build receipt `br-4fa94d22907b446ebc721d524bdfa5d1`; EX5 SHA256 `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
HOLDOUT `2026H1` is forbidden and remains UNSPENT.

## Mechanical acceptance / loop breaker
Require tester exit 0, fresh report after run start, exact symbol/TF/dates/model, exact child set hash, accepted receipt/EX5, leverage 1:100 MATCH, explicit truncation/full-window check, and hard-kill inspection. A losing valid cell is evidence and is never replayed to seek a better result. At most one bounded pre-launch/harness repair; no extra depth value, parameter, symbol or timeframe may be added inside this contract.

## Authority ceiling
RESEARCH_ONLY. No default/risk change, optimizer stage, HOLDOUT, H04/Candidate, DEMO/LIVE, deployment/runtime attachment, trading, KINT resolution or Grade mapping is authorized.