# BT1 — B16 Position-Engine Ablation 01

Status: `PREREGISTERED / READY_FOR_EXECUTION`
Hypothesis ID: `HYP-B16-PE-ABL-01`
Authority: `RESEARCH_ONLY`
Canonical base SHA: `b26af204faf7907fe7e78a2b5f90a5dfa8c6bc02`
HOLDOUT: `UNSPENT`
Optimization: `NONE`

## Question and mechanism

Does the accepted B16 XAUUSD/H4 pulse contain an independently positive single-entry RSI-fade component when adverse grid adds are removed?

One logical change only:
`_16_MaxOrdersPerSide=10 -> 1`.

Known structural consequence: maximum depth 1 routes the existing source into its single-position exit path rather than multi-position basket/overlap exits. This consequence is recorded, not treated as a second parameter change.

Supporting accepted evidence: B16 H03 found multi-entry cycles supplied 79.80% MAIN and 87.89% BWD gross profit. H03 verdict remains `POSITION_ENGINE_DEPENDENT_OR_UNKNOWN`; H04 remains locked.

## Frozen identity

- Expert: `EALabTpl\Boss_16_KangarooGrid`
- Current source SHA256: `e22f64302ea443c5bec14c22fbb4787002f1c88742b9ca30d416040affe4e8d3`
- EX5 SHA256 on Meta5b: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`
- Build receipt: `br-4fa94d22907b446ebc721d524bdfa5d1`
- Receipt registry SHA256: `6c5d70ba538123b24984ba9a62f547c66da7ea6353af738b4ebcc374fd28fef8`
- Parent set: `D:\EA_LAB_CONTROL\handoffs\B16_H01_FULL_TESTER_cf32ba8d.set`
- Parent set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`
- Variant set: `factory/runs/bt1_20260830/b16_pe_abl01/B16_PE_ABL_01.set`
- Variant set SHA256: `07670fdd3da9f7b3e0006c6035bd25422257223403d24b885e7176ae5812d736`
- Byte-preserving semantic replacement: only `_16_MaxOrdersPerSide=10` -> `_16_MaxOrdersPerSide=1`
- Runtime lineage: `MT5-lane2 / D:\Meta 5b`; MAIN and BWD stay on this install.

## Accepted parent comparison — same install only

| Window | PF | Trades | Net | EqDD | Quality | Report SHA256 |
|---|---:|---:|---:|---|---|---|
| MAIN | 4.08 | 79 | 707.78 | 636.50 (6.27%) | 98% | `aee6819ba12f929caade4cf1b70915978a3259ec2b7136a1009e077057bb0e7e` |
| BWD | 1.44 | 148 | 512.69 | 873.12 (8.29%) | 99% | `df63addd9975b66a9471aafe929d3b7f31377a95a93342cc6f1521728f07cff3` |

These parent numbers were accepted H02 evidence on the same `D:\Meta 5b` install and are not rerun.

## Frozen execution plan

- Symbol / TF: `XAUUSD / H4`
- MAIN: `2023.01.01..2025.12.31`
- BWD: `2020.01.01..2022.12.31`
- Model: `1`; Optimization: `0`; Forward: `0`
- Deposit / currency / leverage: `10000 / USD / 1:100`
- Execution order: MAIN then BWD, sequential on Meta5b.
- No rescale, no second parameter change, no HOLDOUT date.
## Falsification and mechanical acceptance

The hypothesis that the entry-only component remains positive in both windows is falsified if a mechanically accepted variant has full-window net profit `<= 0` in either MAIN or BWD.

Mechanical PASS requires, independently of profit:
- exact expert/source/EX5/build-receipt identity above;
- exact variant set SHA256 above and no additional parameter difference;
- logical/tester symbol XAUUSD and TF H4;
- exact window, Model 1, Optimization 0, Forward 0, USD 10000 and leverage 1:100;
- fresh report newer than the run start and report SHA256;
- history quality captured;
- explicit truncation result and full-window eligibility;
- no HOLDOUT date.

A poor PF or negative net is evidence, not a mechanical failure and not a reason to replay the run.

Runtime expectation: two fixed Model-1 H4 runs; normally QUICK/NORMAL. This lane is parallel-safe with independent Model-1 work on MT5-lane3, subject to Lane Registry ownership.

## Direct consumer / authority ceiling

Direct consumer: decide whether later B16 research should investigate entry semantics or remain focused on position-engine/recovery mechanisms.

Authority ceiling: research evidence only. No H04 naming/unlock, optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, production risk/default change, KINT resolution, or grade authority.