# B16 Mechanism Characterization Matrix — Prospective Contract — 2026-08-30

Status: `PREREGISTERED / EXECUTION_LOCKED_UNTIL_COMMIT`
Authority: `RESEARCH_ONLY`
Canonical base SHA: `4ad1b15f26644723f2954a1416f3662b58c0b565`
Research lineage includes independently reviewed BT2 and BT3 evidence before this contract.
Runtime: `MT5-lane2 / D:\Meta 5b`, one job at a time, no `-Force`.
Model: `1`; Optimization: `0 / NONE`; HOLDOUT: `UNSPENT / FORBIDDEN`.
Parent full tester set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`.
Build receipt: `br-4fa94d22907b446ebc721d524bdfa5d1`.
EX5 SHA256: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.

## Objective

Characterize the active B16 `Boss_16_KangarooGrid` mechanism with source-defined structural interventions rather than parameter search. The consumer is a final B16 R2 mechanism report answering which active components contribute, how that contribution changes across the three accepted H02 pulses, and which questions remain genuinely unresolved.

No variant is an optimizer row, candidate, default proposal, H04, HOLDOUT test, or production setting. Each child changes exactly one tester input from the accepted parent.

## Frozen parent contexts

| Context | MAIN PF / trades / net / EqDD | BWD PF / trades / net / EqDD |
|---|---|---|
| `XAUUSD/H4` | 4.08 / 79 / +707.78 / 6.27% | 1.44 / 148 / +512.69 / 8.29% |
| `USDJPY/H1` | 1.53 / 275 / +252.53 / 3.85% | 1.11 / 267 / +44.10 / 2.40% |
| `XAUUSD/M15` | 1.25 / 1577 / +2643.64 / 11.88% | 1.10 / 1463 / +1002.69 / 14.86% |
Exact accepted parent report SHA256 identities:
- XAUUSD/H4 MAIN `aee6819ba12f929caade4cf1b70915978a3259ec2b7136a1009e077057bb0e7e`; BWD `df63addd9975b66a9471aafe929d3b7f31377a95a93342cc6f1521728f07cff3`.
- USDJPY/H1 MAIN `45ac54affa7635cf350ba69492102d58557d54373424d802a3e2b57cdc562c64`; BWD `745cb0a465fbcb1b864e3e117e4ac1ce3de698606b100eb514adb110739a1893`.
- XAUUSD/M15 MAIN `2aeb5f6c0de9a517b3a49c2ca62b75e87938edc457e7adac2317a0a7b5afb728`; BWD `27149f0074c81e70b086a31dbf722eafa2920c281f05adaaf9022dd8a8bc2644`.

## Accepted evidence reused — no rediscovery

- H03 XAUUSD/H4 parent: multi-entry cycles supplied 79.80% MAIN and 87.89% BWD gross profit; max depth 10 MAIN / 8 BWD; outcome `POSITION_ENGINE_DEPENDENT_OR_UNKNOWN`.
- MaxOrders `10 -> 1` already exists for all three parent contexts. XAUUSD/H4 falsified dual-window entry-only positivity; USDJPY/H1 and XAUUSD/M15 did not.
- Overlap `_16_OverlapMinUsd 5 -> 0` already exists for XAUUSD/H4 and showed a MAIN/BWD sign reversal. That pair is reused, not rerun.

Cross-context interpretation is descriptive. There is no invented majority-vote threshold across the three cells.

## H1 — DEPTH2 / first-add sufficiency

Change: `_16_MaxOrdersPerSide: 10 -> 2`.
Source meaning: exactly one adverse grid add can exist; basket TP is reachable at two positions; overlap and deep-spacing tiers are unreachable.
Statement per context: one adverse add is sufficient to retain positive aggregate net in both frozen windows.
Falsifier per context: mechanically accepted net `<= 0` in either MAIN or BWD.
Direct consumer: distinguish entry-only behavior from the marginal value of the first add.
Set SHA256: `385fb586b44199a7bc936cc3e952d1f5265ccb467f4ab041e8ee8f7cf2f2acb9`.

## H2 — DEPTH4 / pre-deep boundary sufficiency

Change: `_16_MaxOrdersPerSide: 10 -> 4`.
Source meaning: orders 1..4 are allowed, overlap becomes eligible at four positions, but the post-order-4 wider spacing tier cannot produce order 5.
Statement per context: the pre-deep engine retains positive aggregate net in both windows.
Falsifier per context: mechanically accepted net `<= 0` in either MAIN or BWD.
Direct consumer: locate whether deeper-than-four exposure is required for the accepted pulse.
Set SHA256: `4bace434784d79d165244c4eaac237c1279734c007fa5bcd6c80b99c924d4bfe`.
## H3 — DEPTH5 / first deep-spaced add sufficiency

Change: `_16_MaxOrdersPerSide: 10 -> 5`.
Source meaning: the first order using `_16_AtrMultAfter` can occur; overlap remains available; deeper orders 6..10 are disabled.
Statement per context: allowing the first deep-spaced add is sufficient to retain positive aggregate net in both windows.
Falsifier per context: mechanically accepted net `<= 0` in either MAIN or BWD.
Direct consumer: isolate the structural transition from the four-order zone into the deep-spacing zone.
Set SHA256: `2a72b67c08964f5053cdbf07d25411205fd1d762083786a153b0da9ffbb5cf57`.

## H4 — SINGLETP_OFF / single-order exit contribution

Change: `_16_TpSingleAtrMult: 0.35 -> 0.0`.
Source meaning: `Kangaroo_SingleTPHit()` becomes inactive while grid adds, basket TP, overlap, SL and cages remain frozen.
Statement per context: the active single-order managed TP is beneficial to the parent trade-off.
Falsifier per context: disabled child has non-lower net **and** non-higher native EqDD% than parent in both MAIN and BWD.
Direct consumer: determine whether B16's profit engine relies materially on closing successful single entries before they become baskets.
Set SHA256: `4f900139ae9e8acdff17198e6721028f769da1fb546b4be1415d050658e00fd1`.

## H5 — BASKETTP_OFF / multi-position basket exit contribution

Change: `_16_BasketTpUsdPer01: 16.0 -> 0.0`.
Source meaning: the `have >= 2` net-dollar basket TP branch is disabled; single TP, overlap, grid, SL and cages remain frozen.
Statement per context: the active basket net-dollar TP is beneficial to the parent trade-off.
Falsifier per context: disabled child has non-lower net and non-higher native EqDD% than parent in both MAIN and BWD.
Direct consumer: distinguish recovery from ordinary full-basket profit realization.
Set SHA256: `04fbab069a582091f5e9a3833bc9bb4f67b20a079ac35b5c479db65586687eec`.

## H6 — OVERLAP_OFF portability

Change: `_16_OverlapMinUsd: 5.0 -> 0.0`.
Source meaning: overlap pair-close is disabled while entry, grid depth/spacing, single TP and basket TP remain frozen.
Statement per context: overlap pair-close is beneficial to the parent trade-off.
Falsifier per context: disabled child has non-lower net and non-higher native EqDD% than parent in both MAIN and BWD.
XAUUSD/H4 is accepted evidence already and will not rerun; only USDJPY/H1 and XAUUSD/M15 receive new cells.
Direct consumer: determine whether the H4 MAIN/BWD sign reversal is specific to that context or recurs elsewhere.
Set SHA256: `a029dec80b7c4d800992595415cb5f06f6f403321a93caa8c9e51b00e21bb213`.
## H7 — PIPFLOOR_OFF / spacing-floor contribution

Change: `_16_MinDistPips: 150.0 -> 0.0`.
Source meaning: grid step becomes ATR-only (`max(ATR-mult × closed-bar ATR, 0)`) instead of ATR-or-fixed-pip-floor; all other grid mechanics remain frozen.
Statement per context: the fixed 150-pip minimum spacing floor is beneficial to the parent trade-off.
Falsifier per context: floor-off child has non-lower net and non-higher native EqDD% than parent in both MAIN and BWD.
Direct consumer: determine whether fixed absolute spacing materially explains cross-symbol/timeframe behavior.
Set SHA256: `9b1bc32cc6e0ae4a7ce999c125d5ff65a5ae461160bdac38121bb0cc5b1e465e`.

## H8 — DEEP_SPACING_EQUAL / post-four widening contribution

Change: `_16_AtrMultAfter: 1.4 -> 0.8`, equal to `_16_AtrMultFirst4`.
Source meaning: removes the wider post-order-4 ATR tier while preserving max depth 10 and every exit/recovery branch.
Statement per context: wider spacing after four positions is beneficial to the parent trade-off.
Falsifier per context: equal-spacing child has non-lower net and non-higher native EqDD% than parent in both MAIN and BWD.
Direct consumer: isolate spacing-regime contribution from max-depth contribution.
Set SHA256: `29d02543ad49a7c6335510d71fe3607dad8d97f900a084e01f3b768ec6703207`.

## H9 — SELL_DIRECTION / direction portability

Change: `_16_Direction: 1 -> 2`.
Source meaning: fixed SELL instance using RSI-high fade; the source does not run both directions inside one instance.
Statement per context: SELL-side configuration also retains positive aggregate net in both frozen windows.
Falsifier per context: mechanically accepted net `<= 0` in either MAIN or BWD.
Direct consumer: determine whether accepted B16 pulse behavior is strongly BUY-direction specific.
Set SHA256: `c0e7cfad84236b798dece5b5106d271c708553fb220af370dba913d8610105de`.

## Frozen execution matrix

Contexts: `XAUUSD/H4`, `USDJPY/H1`, `XAUUSD/M15`.
Windows: MAIN `2023.01.01..2025.12.31`; BWD `2020.01.01..2022.12.31`.
Every new cell: Model 1, optimization 0, Forward 0, USD 10000, leverage 1:100, exact symbol identity, same Meta5b install.

New cells: H1/H2/H3/H4/H5/H7/H8/H9 = `8 × 3 × 2 = 48`; H6 adds `2 contexts × 2 windows = 4`; total **52 new Strategy Tester cells**.
Accepted reused cells are never replayed merely for convenience.
## Mechanical acceptance

Each new cell must have: intended EX5/build receipt and full 173/173 set surface; exact logical/tester symbol and TF; exact dates; fresh report provenance; leverage `1:100` MATCH; explicit truncation/full-window eligibility; no unauthorized input difference; source/build bytes reconciled if mtime-only stale warning occurs.

A poor strategy result is evidence, not mechanical failure. A pre-launch harness refusal is not a strategy result. At most one bounded harness repair is allowed for a newly discovered mechanical defect; no losing Strategy Tester cell is rerun to seek a better outcome.

The exact build-receipt registry is `D:\EA_LAB_CONTROL\handoffs\LANE_H_BUILD_RECEIPT_REGISTRY_cf32ba8d.jsonl`, SHA256 `6c5d70ba538123b24984ba9a62f547c66da7ea6353af738b4ebcc374fd28fef8`.

## Required evidence and diagnostics

For every new MAIN/BWD pair preserve raw report bytes (deterministic gzip), tester INIs, leverage/truncation sidecars, report/set/build hashes and execution log. Reuse `scripts/research/b16_h03/parse_h02_reports.py` without semantic modification to reconstruct source-supported cycles/exposure: cycle count, closed tickets, maximum simultaneous positions, maximum aggregate lots, entry span, multi-entry gross-profit share, concentration and year/fold participation where available.

Aggregate outputs must include parent-child PF/net/native-EqDD/trades deltas, yearly distribution, depth ladder, direction comparison, mechanism-on/off comparison, and exposure/cycle diagnostics. Unsupported exit-type or intratrade-EqDD attribution stays `UNKNOWN`.

Final report level: `R2 MECHANISM CHARACTERIZATION`; selected-cell visuals must include equity, underwater proxy, year distribution, parent-child view, depth ladder, mechanism matrix and source-bound workflow diagram. Visuals are `VISUAL_ONLY_NO_AUTHORITY`.

## Stop / loop breaker

This matrix is the bounded completion set for the current B16 characterization milestone. Do not add an adaptive parameter value after seeing results. Do not turn depth 2/4/5 into an optimizer sweep. Same unresolved question twice becomes `UNKNOWN/BLOCKED`. After the 52 new cells are mechanically accepted or honestly blocked, stop expansion, synthesize the final report, independently review the frozen milestone head, and integrate when canonical lineage is safe.

## Authority ceiling

No H04 naming/unlock, optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, runtime attachment, risk/default change, KINT resolution, Grade mapping, or production strategy-semantic change is authorized. Existing dormant B16 features (`FlattenOn`, ladder sizing, balance scaling) are not activated by this contract. SL/emergency-DD/risk-cage parameters remain frozen.
