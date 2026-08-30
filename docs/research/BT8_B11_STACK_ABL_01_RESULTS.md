# BT8 — B11 GridTrend Stack Ablation Results

Status: `PASS / HYPOTHESIS_SUPPORTED / RESEARCH_ONLY`
Hypothesis: `HYP-B11-STACK-ABL-01`
Intervention: `StackMode=91 -> 90` (`GRID_TREND -> SINGLE`)
Runtime: `MT5-lane3 / D:\Meta 5c`, Model 1, same-install parent/child.
HOLDOUT: `UNSPENT`. Optimization: `NONE`.

## Mechanical acceptance

- Authorized/completed cells: `8/8`.
- Full input surface: `151/151` on every run.
- Build/config identity: PASS; leverage `1:100`.
- Truncation guard: `0/8` truncated.
- Parent and child were run on the same MT5 install.

## Aggregate evidence

| Home | Window | Parent PF | Child PF | Parent net | Child net | Parent EqDD | Child EqDD |
|---|---|---:|---:|---:|---:|---:|---:|
| USDJPY H4 | MAIN | 0.97 | 1.10 | -90.00 | +138.39 | 3.86% | 2.26% |
| USDJPY H4 | BWD | 1.05 | 1.11 | +133.54 | +130.70 | 4.23% | 2.28% |
| XAUUSD H4 | MAIN | 1.02 | 1.04 | +247.51 | +252.33 | 17.76% | 9.24% |
| XAUUSD H4 | BWD | 0.81 | 0.82 | -1749.54 | -839.62 | 21.88% | 10.76% |

## Interpretation

The single-position child improves PF and EqDD in all four diagnostic windows. USDJPY/H4 MAIN also changes sign from negative to positive. XAUUSD/H4 BWD remains a losing configuration, but its loss and drawdown are roughly halved.

This supports the preregistered claim that B11's grid-stack layer is a material contributor to its weak portability. It does **not** establish that the MA entry alone is a qualified strategy, because XAUUSD/H4 BWD remains below PF 1 and the yearly splits still contain losing years.

Mechanism classification: `GRID_STACK_MATERIAL_WEAKNESS / ENTRY_ONLY_NOT_YET_QUALIFIED`.

## Decision boundary

- Preserve this as mechanism evidence; do not promote the child automatically.
- A later B11 continuation should investigate the MA-entry core or a bounded rescue contract, not tune the removed grid stack blindly.
- No optimization/HOLDOUT/Candidate/DEMO/LIVE/deployment/risk/default/Grade/KINT authority is created.

## Evidence

- `factory/runs/bt8_20260830/b11_stack_abl01/evidence_summary.json`
- `factory/runs/bt8_20260830/b11_stack_abl01/parent_child.csv`
- `factory/runs/bt8_20260830/b11_stack_abl01/year_split.csv`
- `factory/runs/bt8_20260830/b11_stack_abl01/r2_parent_child.svg` (`VISUAL_ONLY_NO_AUTHORITY`)
- `factory/runs/bt8_20260830/b11_stack_abl01/raw/*`
- `factory/runs/bt8_20260830/b11_stack_abl01/mechanical_acceptance.json`
