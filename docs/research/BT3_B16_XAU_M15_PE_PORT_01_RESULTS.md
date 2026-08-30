# BT3 — B16 XAUUSD/M15 Position-Engine Portability Ablation 01 — Results

Status: `PASS / HYPOTHESIS_NOT_FALSIFIED / RESEARCH_ONLY`
Hypothesis ID: `HYP-B16-XAU-M15-PE-PORT-01`
Preregistration commit: `94bec55d7c36c2dd717b75ebf1134e8f37ca088f`
Canonical base SHA: `4ad1b15f26644723f2954a1416f3662b58c0b565`
Runtime: `MT5-lane2 / D:\Meta 5b`
Model: `1`
Optimization: `0 / NONE`
HOLDOUT: `UNSPENT`
MECHANISM_VALUE: `UNCLEAR`

## Frozen intervention

Exactly one tester-input change from the accepted B16 parent configuration:

`_16_MaxOrdersPerSide: 10 -> 1`

Child full tester set SHA256: `07670fdd3da9f7b3e0006c6035bd25422257223403d24b885e7176ae5812d736`.
All other tester inputs remained frozen; set surface was `FULL 173/173`.

## Mechanical acceptance

Both authorized cells PASS mechanical acceptance. Exact logical/tester symbol was `XAUUSD`, TF `M15`, Model 1, optimization 0, Forward 0, USD 10000, leverage 1:100, same Meta5b install, fresh reports, no truncation, and full-window eligibility.

Build identity: `br-4fa94d22907b446ebc721d524bdfa5d1`; EX5 SHA256 `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
The runner's mtime stale warning is reconciled as a false positive: the B16 source blob and `ea_template/core` tree are byte-identical between the accepted build lineage and execution head.

## Evidence table

| Window | Parent PF | Child PF | Parent net | Child net | Parent EqDD% | Child EqDD% | Parent trades | Child trades | Report SHA256 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| MAIN 2023-2025 | 1.25 | 1.15 | +2643.64 | +213.52 | 11.88 | 3.15 | 1577 | 783 | `7c1cd3ccab30c6e1abe4d2ab5013892b4af50169f7addb0eaba2c3d71fcee74f` |
| BWD 2020-2022 | 1.10 | 1.07 | +1002.69 | +80.64 | 14.86 | 2.22 | 1463 | 814 | `e6deb26a409cebfff1cb0e4b77dd16bf9d9fa867f220d2c63637683cc4527322` |

Parent-to-child deltas:
- MAIN: PF `-0.10`; net `-2430.12`; EqDD `-8.73pp`; trades `-794`.
- BWD: PF `-0.03`; net `-922.05`; EqDD `-12.64pp`; trades `-649`.

## Year participation

| Window | Year | trades | PF | net |
|---|---:|---:|---:|---:|
| MAIN | 2023 | 230 | 0.61 | -161.99 |
| MAIN | 2024 | 249 | 0.87 | -54.99 |
| MAIN | 2025 | 304 | 1.70 | +430.50 |
| BWD | 2020 | 263 | 1.29 | +103.84 |
| BWD | 2021 | 261 | 0.73 | -119.07 |
| BWD | 2022 | 290 | 1.32 | +95.87 |

The aggregate is positive in both windows, but three of six calendar years are negative. This contradicting evidence is retained rather than averaged away.
## EVIDENCE

- The preregistered primary statement was that the XAUUSD/M15 entry-only component remains positive in both frozen windows.
- MAIN child net is `+213.52`; BWD child net is `+80.64`. Both are mechanically accepted and full-window eligible.
- Disabling adds reduced native EqDD materially but also removed most of the parent's aggregate net profit in both windows.
- This differs from BT1 B16 XAUUSD/H4 MaxOrders `10 -> 1`, where BWD net became `-32.09` and falsified dual-window entry-only positivity.
- The year split is heterogeneous: 2023, 2024 and 2021 are negative; 2025, 2020 and 2022 are positive.

## INTERPRETATION

The preregistered dual-window positivity statement is not falsified on XAUUSD/M15. This demonstrates that the XAUUSD/H4 entry-only failure is not an XAUUSD-wide result and that timeframe/regime context materially changes the entry-vs-position-engine contribution.

The result does not establish the position engine as unnecessary. Relative to the parent, the entry-only child retains only a small fraction of aggregate net while reducing drawdown sharply. The current evidence therefore supports a positive but unstable entry component plus a large position-engine contribution on XAUUSD/M15.

`MECHANISM_VALUE=UNCLEAR`: the entry-only component survives both aggregate windows, but its calendar-year direction is mixed and its economic contribution is much smaller than the parent. The evidence is useful for mechanism attribution but is not a robust standalone strategy verdict.

## DECISION

`HYPOTHESIS_NOT_FALSIFIED`.

Reusable mechanism finding: B16's dependence on its position engine is context-dependent. XAUUSD/H4 required the engine to preserve dual-window positivity, while XAUUSD/M15 and USDJPY/H1 retained positive aggregate entry-only behavior. This does not identify which deeper position-engine submechanism creates the parent's additional net.

Next consumer: a prospective B16 mechanism-characterization matrix using source-defined structural boundaries, not parameter search, to isolate first-add/depth, single-TP, basket-TP, spacing-floor, deep-spacing and direction contributions.
## R2 evidence artifacts

- `factory/runs/bt3_20260830/b16_xau_m15_pe_port01/evidence_summary.json`
- `factory/runs/bt3_20260830/b16_xau_m15_pe_port01/mechanical_acceptance.json`
- `factory/runs/bt3_20260830/b16_xau_m15_pe_port01/equity_curve.csv`
- `factory/runs/bt3_20260830/b16_xau_m15_pe_port01/year_split.csv`
- `factory/runs/bt3_20260830/b16_xau_m15_pe_port01/r2_equity_curve.svg`
- `factory/runs/bt3_20260830/b16_xau_m15_pe_port01/r2_underwater.svg`
- `factory/runs/bt3_20260830/b16_xau_m15_pe_port01/r2_year_distribution.svg`
- `factory/runs/bt3_20260830/b16_xau_m15_pe_port01/r2_parent_child.svg`
- deterministic compressed raw reports and freshness/leverage/truncation/source-byte evidence in the same run directory.

All SVGs are `VISUAL_ONLY_NO_AUTHORITY`.

## Authority ceiling

This result grants no H04 naming/unlock, optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default change, KINT resolution, Grade mapping, or production strategy-semantic authority. HOLDOUT remains `UNSPENT`; optimization remains `NONE`.
