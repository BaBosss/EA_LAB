# BT1 — B16 Recovery Ablation 01 — Preregistration

Status: `PREREGISTERED / RESEARCH_ONLY`
Hypothesis ID: `HYP-B16-REC-ABL-01`
Base canonical SHA: `f3f95d6964c3bdff966697439007b6c0b152aecb`
Dependency: `HYP-B16-PE-ABL-01` mechanically complete; result commit `ee1ee6d8fd93a78502f23a0222de149c9499b3d5`
HOLDOUT: `UNSPENT`
Optimization: `NONE`
Runtime: `MT5-lane2 / D:\Meta 5b` only
Expected runtime: QUICK; two serial Model-1 cells on one install

## Question

Does B16's overlap pair-close recovery branch contribute beneficially to the accepted XAUUSD/H4 pulse after positions accumulate?

This is a prospective component ablation. It is not H04, not an optimizer probe, and not a parameter search.

## One logical change

Accepted parent set: `D:\EA_LAB_CONTROL\handoffs\B16_H01_FULL_TESTER_cf32ba8d.set`
Parent set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`
Child set: `factory/runs/bt1_20260830/b16_rec_abl01/B16_REC_ABL_01.set`
Child set SHA256: `a029dec80b7c4d800992595415cb5f06f6f403321a93caa8c9e51b00e21bb213`

Only semantic change: `_16_OverlapMinUsd=5.0 -> 0.0`.
Binary-preserving set construction changes exactly that one assignment and preserves file length and all other bytes.

## Frozen identity and semantics

Expert: `EALabTpl\Boss_16_KangarooGrid`
EX5 SHA256: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`
Build receipt: `br-4fa94d22907b446ebc721d524bdfa5d1`
Accepted source SHA256 for `ea_template/Boss_16_KangarooGrid.mq5`: `e22f64302ea443c5bec14c22fbb4787002f1c88742b9ca30d416040affe4e8d3`

Canonical source semantics are explicit in `ea_template/core/entries/Kangaroo.mqh`: the overlap branch is entered only when position count reaches `_16_OverlapMinOrders` and `_16_OverlapMinUsd > 0.0`; the newest+oldest pair must then meet `(nP + oP) >= _16_OverlapMinUsd`. Setting the threshold to `0.0` therefore disables this source-gated pair-close branch while leaving entry, add spacing, maximum depth, flat-lot sizing, basket TP, and ordinary basket behavior unchanged.

The child set is `FULL`: 173/173 declared inputs are present, so no tester-cache inputs are inherited.

Accepted parent comparison, same Meta5b lineage:
- MAIN 2023.01.01..2025.12.31: PF `4.08`, trades `79`, net `707.78`, EqDD `6.27%`, report SHA256 `aee6819ba12f929caade4cf1b70915978a3259ec2b7136a1009e077057bb0e7e`.
- BWD 2020.01.01..2022.12.31: PF `1.44`, trades `148`, net `512.69`, EqDD `8.29%`, report SHA256 `df63addd9975b66a9471aafe929d3b7f31377a95a93342cc6f1521728f07cff3`.

## Execution contract

Run exactly two cells, serially on Meta5b: MAIN then BWD. Use XAUUSD/H4, Model 1, Optimization 0, Forward 0, USD 10000, leverage 1:100, exact child set above, and the accepted build-receipt registry `D:\EA_LAB_CONTROL\handoffs\LANE_H_BUILD_RECEIPT_REGISTRY_cf32ba8d.jsonl`.

Mechanical acceptance requires: exit code 0; fresh report produced after run start; exact logical/tester symbol identity; build/config identity PASS; leverage sidecar MATCH; truncation sidecar false; full-window eligibility; no HOLDOUT date; and no second run/retry unless the first attempt fails mechanically before producing admissible evidence.

Required evidence: PF, net, EqDD%, trade count, yearly participation, exact report/set/EX5 hashes, parent-child deltas, and source-supported cycle/overlap-close attribution where deterministically extractable.

## Falsification and interpretation

Preregistered hypothesis: `overlap pair-close is beneficial`.

Falsify it only if the disabled child has **non-lower net profit AND non-higher EqDD% than the accepted parent in BOTH MAIN and BWD**, with mechanical acceptance passing.

If that strict condition is not met, record `NOT_FALSIFIED`; do not convert a mixed result into a winner. Mechanism assessment uses `STRONG | PROMISING | UNCLEAR | WEAK | EXHAUSTED` as research interpretation only.

No universal sample floor or Grade threshold may be invented; `KINT-001` remains outside this experiment.

## Direct consumer / authority ceiling

Direct consumer: decide whether later B16 recovery research should preserve, redesign, or deprioritize the overlap pair-close mechanism.

Authority ceiling: research-only. This contract grants no recovery-default change, H04 naming/unlock, optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default, KINT, or Grade authority.
