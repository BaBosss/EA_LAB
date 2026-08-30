# BT2 — B16 USDJPY/H1 Position-Engine Portability Ablation 01 — Preregistration

Status: `PREREGISTERED / READY_TO_EXECUTE`
Hypothesis ID: `HYP-B16-PE-PORT-01`
Authority: `RESEARCH_ONLY`
Canonical base SHA: `4ad1b15f26644723f2954a1416f3662b58c0b565`
Runtime: `MT5-lane2 / D:\Meta 5b`
HOLDOUT: `UNSPENT / FORBIDDEN`
Optimization: `NONE`

## Question

Does the B16 USDJPY/H1 H02 pulse retain an independently positive entry-only component when the adverse-add position engine is disabled, or does the entry-only failure observed prospectively on B16 XAUUSD/H4 repeat on this second accepted B16 pulse?

This is a new prospective mechanism-portability experiment. It is not H04, not tuning, not an optimizer seed, and not a rerun of B16 H03 or BT1 XAUUSD/H4.

## Frozen one-change intervention

- EA: `EALabTpl\Boss_16_KangarooGrid`
- Symbol/TF: `USDJPY / H1`
- Parent full tester set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`
- Child set: `factory/runs/bt2_20260830/b16_usdjpy_pe_port01/B16_USDJPY_PE_PORT_01.set`
- Child set SHA256: `07670fdd3da9f7b3e0006c6035bd25422257223403d24b885e7176ae5812d736`
- Exactly one parameter change: `_16_MaxOrdersPerSide: 10 -> 1`.
- `_16_OverlapMinUsd` remains `5.0`; every other tester input remains frozen.

## Accepted parent evidence reused — no rerun

Accepted H02 `B16 / USDJPY / H1` on Meta5b:

| Window | PF | trades | net | EqDD% | report SHA256 | INI SHA256 |
|---|---:|---:|---:|---:|---|---|
| MAIN 2023-01-01..2025-12-31 | 1.53 | 275 | 252.53 | 3.85 | `45ac54affa7635cf350ba69492102d58557d54373424d802a3e2b57cdc562c64` | `cbaf78fe09628809b6777b98e0505a9b72fd8443bf9b158e871267fe4d748cdd` |
| BWD 2020-01-01..2022-12-31 | 1.11 | 267 | 44.10 | 2.40 | `745cb0a465fbcb1b864e3e117e4ac1ce3de698606b100eb514adb110739a1893` | `9b94f4c4e3924e5692e939e0bdaae7b40ceacf16b51026ca72a35572abcfb9a6` |

Both accepted parent cells use exact `USDJPY/H1`, Model 1, optimization 0, USD 10000, leverage 1:100, and the same Meta5b lineage.

## Evidence basis

Supporting evidence:
- accepted B16 H03 showed XAUUSD/H4 multi-entry cycles supplied 79.80% MAIN and 87.89% BWD gross profit;
- prospective BT1 `HYP-B16-PE-ABL-01` then disabled adds and produced MAIN net +149.08 but BWD net -32.09, falsifying entry-only positivity across both XAUUSD/H4 windows;
- B16 USDJPY/H1 is an independent accepted H02 pulse with positive MAIN/BWD PF and is therefore a direct portability check rather than a parameter search.

Contradicting evidence:
- USDJPY/H1 may contain a more independent entry edge than XAUUSD/H4; family-level dependence is not assumed from one symbol.

## Frozen execution plan

Exactly two new Strategy Tester cells, sequentially on Meta5b:
1. MAIN `2023.01.01..2025.12.31`
2. BWD `2020.01.01..2022.12.31`

Freeze: Model 1; optimization 0; Forward 0; USD 10000; leverage 1:100; no rescaling; no HOLDOUT; no parameter change beyond MaxOrders.

Mechanical acceptance requires intended EX5/build receipt/config identity, exact logical/tester USDJPY, H1 and dates, fresh report provenance, leverage match, explicit truncation/full-window eligibility, and no unauthorized parameter difference. Poor PF is evidence, not mechanical failure.

## Falsifier and interpretation

Primary testable statement: **the B16 USDJPY/H1 entry-only component remains positive in both frozen windows**.

Falsified if mechanically accepted full-window net profit is `<= 0` in either MAIN or BWD. If both windows remain positive, the statement is not falsified; that still grants no optimization or promotion authority.

Direct consumer: determine whether the XAUUSD/H4 entry-only failure appears symbol-specific or repeats on another accepted B16 pulse, thereby guiding whether future B16 research should focus family-wide on the position engine or retain symbol-specific entry hypotheses.

Report level: `R2 MECHANISM`. Required outputs include parent/child table, yearly participation, equity/DD views, and explicit evidence/interpretation/decision separation.

Authority ceiling: no H04 naming/unlock, optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default change, KINT resolution, or Grade authority.
