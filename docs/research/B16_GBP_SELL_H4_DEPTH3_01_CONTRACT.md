# B16 GBPUSD SELL H4 Depth-3 Ablation - H07 Contract

Status: `PREREGISTRATION / RESEARCH_ONLY / NO OPTIMIZATION`
Hypothesis ID: `HYP-B16-GBP-SELL-H4-DEPTH3-01`
Base SHA: `d302a9c0ea343a5d633c96facf76c782905b79a1`
Runtime target: `MT5-lane2 / D:\Meta 5b`, serial Model-1 only after a valid Lane Registry runtime claim.

## Accepted evidence - do not rediscover
The accepted max-10 GBPUSD/H4 SELL research reference is positive in both windows and all six calendar years, with realized max depth 4. H06 max-depth 2 remains aggregate positive but weakens MAIN from +283.20 to +50.11 and flips 2025 from +119.21 to -108.53; H06 is reviewed/canonical and is not an adopted child.

## Direct consumer
Determine whether allowing the second adverse add (maximum depth 3) restores the 2025 positive sign lost at depth 2 while preserving aggregate positive MAIN+BWD, and verify that depth 3 is actually exercised in 2025. This closes the bounded 2/3/parent-realized-4 structural depth question; it is not a depth search, optimization stage, or default proposal.

## One logical change
Parent set SHA256: `c0e7cfad84236b798dece5b5106d271c708553fb220af370dba913d8610105de`.
Child set: `factory/runs/b16_h07_20260831/gbp_sell_h4_depth3/B16_GBP_SELL_H4_DEPTH3_01.set`.
Child set SHA256: `3dbcf63f002a0bfad0371c5f26acf7156a6eabc8820f31a0d67f663f24f3edd5`.
Sole input change: `_16_MaxOrdersPerSide: 10 -> 3`.
Direction SELL, RSI 14/70, spacing, exits, sizing, protections and all other inputs remain byte-identical.

At cap 3, positions 4..10 and overlap recovery (requires four positions) are unreachable as a consequence of the sole cap change; basket TP remains reachable. This consequence does not create a second input change.

## Prospective hypothesis and classification
Primary statement: the second adverse add is sufficient to recover 2025 to net > 0 while retaining aggregate MAIN net > 0 and BWD net > 0, with at least one 2025 cycle reaching realized depth 3.

After mechanical acceptance:
- if 2025 has no realized depth-3 contact => `UNKNOWN_NO_2025_DEPTH3_CONTACT`; do not claim causal recovery/failure from this contract;
- if MAIN net <= 0, BWD net <= 0, or 2025 net <= 0 after 2025 depth-3 contact => `HYPOTHESIS_FALSIFIED / DEPTH3_DOES_NOT_RECOVER_REQUIRED_SIGN`;
- if MAIN net > 0, BWD net > 0, 2025 net > 0, and 2025 realized depth 3 is observed => `HYPOTHESIS_NOT_FALSIFIED / DEPTH3_RECOVERS_2025_SIGN`.

Secondary evidence compares depth-3 with accepted depth-2 and max-10 parent: PF state, native EqDD, trades, all calendar years, cycles, max depth/lots, multi-entry gross-profit share, active-time/concentration and parent-depth contact by year. Secondary metrics may limit adoption/utility interpretation but cannot rewrite the primary classification after results are visible.

## Frozen execution matrix
Exactly two new cells: GBPUSD/H4 MAIN `2023.01.01..2025.12.31` and BWD `2020.01.01..2022.12.31`.
Model 1; Optimization 0; Forward 0; USD 10,000; leverage 1:100; exact GBPUSD; same Meta5b install lineage.
Build receipt `br-4fa94d22907b446ebc721d524bdfa5d1`; EX5 SHA256 `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
HOLDOUT `2026H1` is forbidden and remains UNSPENT.

## Mechanical acceptance / loop breaker
Require tester exit 0, fresh report after run start, exact symbol/TF/dates/model, exact child set hash, accepted receipt/EX5, leverage 1:100 MATCH, explicit truncation/full-window check, hard-kill scan, and cycle reconstruction sufficient to establish 2025 depth-3 contact. A mechanically valid losing cell is evidence and is never replayed. At most one bounded harness repair. No depth 4 child, extra depth value, parameter, symbol, timeframe, optimizer or HOLDOUT may be added inside H07.

## Authority ceiling
RESEARCH_ONLY. No adopted default, risk change, optimizer stage, HOLDOUT, H04/Candidate, DEMO/LIVE, deployment/runtime attachment, trading, KINT resolution or Grade mapping is authorized. H07 closes only this structural depth milestone.
