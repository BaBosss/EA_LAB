# BT2 — B16 USDJPY/H1 Position-Engine Portability Ablation 01 — Results

Status: `PASS / HYPOTHESIS_NOT_FALSIFIED / RESEARCH_ONLY`
Hypothesis ID: `HYP-B16-PE-PORT-01`
Preregistration commit: `b155b5e1318eba871e7deb30d971bf00e9043de1`
Canonical base SHA: `4ad1b15f26644723f2954a1416f3662b58c0b565`
Runtime: `MT5-lane2 / D:\Meta 5b`
Model: `1`
Optimization: `0 / NONE`
HOLDOUT: `UNSPENT`

## Frozen intervention

Exactly one tester-input change from the accepted B16 parent configuration:

`_16_MaxOrdersPerSide: 10 -> 1`

Child full tester set SHA256: `07670fdd3da9f7b3e0006c6035bd25422257223403d24b885e7176ae5812d736`.
All other tester inputs remained frozen; set surface was `FULL 173/173`.

## Mechanical acceptance

Both authorized cells PASS mechanical acceptance. Exact logical/tester symbol was `USDJPY`, TF `H1`, Model 1, optimization 0, Forward 0, USD 10000, leverage 1:100, same Meta5b install, fresh reports, no truncation, and full-window eligibility.

Build identity: `br-4fa94d22907b446ebc721d524bdfa5d1`; EX5 SHA256 `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
The runner's mtime stale warning is reconciled as a false positive: the B16 source blob and `ea_template/core` tree are byte-identical between the accepted build lineage and execution head.

## Evidence table

| Window | Parent PF | Child PF | Parent net | Child net | Parent EqDD% | Child EqDD% | Parent trades | Child trades | Report SHA256 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| MAIN 2023-2025 | 1.53 | 2.87 | +252.53 | +172.87 | 3.85 | 0.57 | 275 | 290 | `b2eda7a33b93bcadf559f7760715275b375cda86ae2cc0354dba78a2694a8b4c` |
| BWD 2020-2022 | 1.11 | 1.22 | +44.10 | +33.22 | 2.40 | 0.70 | 267 | 260 | `15b4fe68a91f59b6d278b0f97071d07615ea82a126af63fe37185107608b2eec` |

Parent-to-child deltas:
- MAIN: PF `+1.34`; net `-79.66`; EqDD `-3.28pp`; trades `+15`.
- BWD: PF `+0.11`; net `-10.88`; EqDD `-1.70pp`; trades `-7`.

## Year participation

| Window | Year | trades | PF | net |
|---|---:|---:|---:|---:|
| MAIN | 2023 | 108 | 4.20 | +80.72 |
| MAIN | 2024 | 87 | 4.39 | +63.84 |
| MAIN | 2025 | 95 | 1.59 | +28.31 |
| BWD | 2020 | 91 | 0.67 | -29.24 |
| BWD | 2021 | 79 | 4.14 | +29.52 |
| BWD | 2022 | 90 | 1.63 | +32.94 |

The BWD aggregate is positive, but 2020 is negative. This contradicting subperiod evidence is retained rather than averaged away.

## EVIDENCE

- The preregistered primary statement was that the USDJPY/H1 entry-only component remains positive in both frozen windows.
- MAIN child net is `+172.87`; BWD child net is `+33.22`. Both are mechanically accepted and full-window eligible.
- Compared with the parent, disabling adds reduced net in both windows but also reduced reported EqDD materially and raised PF in both windows.
- This differs from BT1 B16 XAUUSD/H4 MaxOrders `10 -> 1`, where BWD net became `-32.09` and falsified dual-window entry-only positivity.
- The BWD yearly split is heterogeneous: 2020 is negative while 2021 and 2022 are positive.

A first launcher attempt was refused before MT5 launch because the default build-receipt registry did not contain the stamped B16 receipt. The accepted H02/BT1 receipt registry was then supplied explicitly; this was harness routing only. No Strategy Tester result was replayed or replaced.

## INTERPRETATION

The preregistered dual-window positivity statement is not falsified on USDJPY/H1. The evidence therefore rejects a simple family-wide conclusion that B16's entry-only component necessarily collapses whenever the add engine is removed.

At the same time, lower child net in both windows shows that this experiment does not establish the position engine as useless. On USDJPY/H1, the fixed entry logic has an independently positive aggregate contribution under this ablation, while the parent position engine is associated with additional aggregate net profit at higher drawdown.

The contrast with XAUUSD/H4 is evidence of symbol/market dependence in the entry-vs-position-engine contribution. It is not authority to redesign, optimize, or generalize B16 across symbols. The negative 2020 child year also prevents treating the entry-only result as uniformly robust across subperiods.

## DECISION

`HYPOTHESIS_NOT_FALSIFIED`.

Research conclusion: **B16 entry-only positivity is demonstrated prospectively on the accepted USDJPY/H1 pulse but did not survive prospectively on XAUUSD/H4; current evidence supports symbol-dependent mechanism contribution rather than a universal family-wide entry-only or position-engine verdict.**

No automatic next experiment is opened by this result. Any further B16 mechanism work requires a new prospective one-change hypothesis with a direct consumer.

## R2 evidence artifacts

- `factory/runs/bt2_20260830/b16_usdjpy_pe_port01/evidence_summary.json`
- `factory/runs/bt2_20260830/b16_usdjpy_pe_port01/mechanical_acceptance.json`
- `factory/runs/bt2_20260830/b16_usdjpy_pe_port01/equity_curve.csv`
- `factory/runs/bt2_20260830/b16_usdjpy_pe_port01/year_split.csv`
- `factory/runs/bt2_20260830/b16_usdjpy_pe_port01/r2_equity_curve.svg`
- `factory/runs/bt2_20260830/b16_usdjpy_pe_port01/r2_underwater.svg`
- `factory/runs/bt2_20260830/b16_usdjpy_pe_port01/r2_year_distribution.svg`
- `factory/runs/bt2_20260830/b16_usdjpy_pe_port01/r2_parent_child.svg`
- deterministic compressed raw reports and freshness/leverage/truncation/source-byte evidence in the same run directory.

All SVGs are `VISUAL_ONLY_NO_AUTHORITY`.

## Authority ceiling

This result grants no H04 naming/unlock, optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default change, KINT resolution, Grade mapping, or production strategy-semantic authority. HOLDOUT remains `UNSPENT`; optimization remains `NONE`.
