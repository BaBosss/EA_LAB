# BT7 — B13 Bollinger-Gate Portability 02 Results

Status: `PASS / RESEARCH_ONLY`
Hypothesis: `HYP-B13-BB-PORT-02`
Intervention: `_13_RequireBB=true -> false` (RSI-only child)
Runtime: `MT5-lane3 / D:\Meta 5c`, Model 1, same-install parent/child.
HOLDOUT: `UNSPENT`. Optimization: `NONE`.

## Mechanical acceptance

- Authorized/completed cells: `8/8`.
- Full input surface: `157/157` on every run.
- Build/config identity: PASS; leverage `1:100`.
- Truncation guard: `0/8` truncated.
- Parent and child were run on the same MT5 install for each comparison.

## Aggregate evidence

| Home | Window | Parent PF | Child PF | Parent net | Child net | Parent EqDD | Child EqDD |
|---|---|---:|---:|---:|---:|---:|---:|
| EURUSD H4 | MAIN | 1.15 | 1.18 | +109.87 | +149.83 | 1.46% | 1.21% |
| EURUSD H4 | BWD | 0.98 | 0.97 | -20.35 | -36.01 | 2.10% | 1.81% |
| XAUUSD H4 | MAIN | 0.79 | 0.78 | -1334.25 | -1499.90 | 18.69% | 20.11% |
| XAUUSD H4 | BWD | 1.03 | 1.04 | +104.16 | +141.40 | 6.93% | 6.93% |

## Interpretation

The intervention is mixed rather than portable. Removing the Bollinger gate improves EURUSD/H4 MAIN and XAUUSD/H4 BWD, but worsens EURUSD/H4 BWD and XAUUSD/H4 MAIN. The strongest adverse cell is XAUUSD/H4 MAIN, where the child loses an additional 165.65 and EqDD rises by 1.42 percentage points.

Therefore the preregistered portability claim is **not established**. The evidence supports `MARKET_WINDOW_DEPENDENT / MECHANISM_VALUE=UNCLEAR`, not removal of the BB gate family-wide.

Year splits reinforce the instability: the child does not create a consistently improved annual pattern across both homes and both windows. Exact yearly values are in `year_split.csv`.

## Decision boundary

- Do not remove `_13_RequireBB` from B13 globally.
- Do not open optimization or HOLDOUT from this experiment.
- A later B13 continuation, if opened, should test a distinct source-defined mechanism rather than repeat BB on more symbols without a direct consumer.
- This result grants no Candidate, DEMO/LIVE, deployment, risk/default, Grade, or KINT authority.

## Evidence

- `factory/runs/bt7_20260830/b13_bb_port02/evidence_summary.json`
- `factory/runs/bt7_20260830/b13_bb_port02/parent_child.csv`
- `factory/runs/bt7_20260830/b13_bb_port02/year_split.csv`
- `factory/runs/bt7_20260830/b13_bb_port02/r2_parent_child.svg` (`VISUAL_ONLY_NO_AUTHORITY`)
- `factory/runs/bt7_20260830/b13_bb_port02/raw/*`
- `factory/runs/bt7_20260830/b13_bb_port02/mechanical_acceptance.json`
