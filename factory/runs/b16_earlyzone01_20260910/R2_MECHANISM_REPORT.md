# B16 XAUUSD/M15 Early-Zone Spacing 01 — R2 Mechanism Report

Status: `MECHANICALLY_ACCEPTED / RESEARCH_ONLY / HYPOTHESIS_NOT_FALSIFIED / DUAL_WINDOW_SIGN_SURVIVES_WIDER_EARLY_ZONE`
Prereg commit: `9b26192acb54c61c98e055272e0f7b2945b93c4b`
Installation lineage: `D:\Meta 5c` only; Model 1 / 1 Minute OHLC; Optimization 0; HOLDOUT UNSPENT.
Parent set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`.
Child set SHA256: `551385b8a1b16141f3924315988bdf101d12a6aee2246ac1eb59ff1ba16ad88f`.
Sole executed input change: `_16_AtrMultFirst4: 0.8 -> 1.4`; `_16_AtrMultAfter=1.4` remains frozen.
EX5 SHA256: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.

## Evidence
| Window | Parent net / PF / trades / EqDD | Child net / PF / trades / EqDD | Child-parent |
|---|---|---|---|
| MAIN | 2709.57 / 1.25 / 1575 / 11.91% | 1724.58 / 1.19 / 1289 / 11.82% | net -984.99; trades -286; EqDD -0.09pp |
| BWD | 983.57 / 1.10 / 1462 / 14.94% | 426.33 / 1.05 / 1256 / 14.27% | net -557.24; trades -206; EqDD -0.67pp |

Mechanical acceptance: `PASS`; all 4 cells exact XAUUSD/M15, leverage 1:100, full-window eligible, and parser reconciliation PASS. Source-graph check compared 35 files: changed=0, missing=0; stale launch banner is mtime-only.

The same-install Meta5c parent rerun is the acceptance-critical comparator. Historical Meta5b parent metrics are lineage context only and are not numerically compared across installations.

Year evidence: child MAIN remains positive in 2023/2024/2025; BWD 2021 is negative for both arms and worsens from -573.56 parent to -897.81 child. Both arms still reach realized depth 10, so the result is not explained by the grid becoming inactive.

## Interpretation
The preregistered sign hypothesis is **not falsified**: widening the early zone from 0.8 ATR to 1.4 ATR still leaves aggregate MAIN and BWD net positive. Therefore 0.8 ATR is not proven necessary merely to preserve dual-window positive sign on XAUUSD/M15.

The child is not an improvement direction. Net and participation fall materially in both windows while native EqDD improves only slightly. This supports retaining the narrower early-zone spacing as the stronger research reference for this context, without turning 0.8 into a production/default claim.

`MECHANISM_VALUE = WEAK` for the **wider-early-zone intervention**. This is not a grade of the B16 family.

## Decision
`SYMMETRIC_WIDER_SPACING_SIGN_ADMISSIBLE_BUT_NOT_IMPROVEMENT_DIRECTION`. Close this one-change spacing question. Do not open a wider-spacing optimizer, do not retune from BWD, and do not spend HOLDOUT from this result.

## Known unknowns / authority ceiling
No claim is made for other symbols/timeframes, Model4 fidelity of this child, intratrade equity path, Candidate/Grade/KINT, DEMO/LIVE, deployment, trading, or risk/default changes. BWD remains evidence only, never a search surface.

## Lesson / next consumer
Early-zone compression contributes useful participation/net in this XAUUSD/M15 lineage, but it is not required for aggregate dual-window sign. The next B16 research question must be a different unresolved causal question; this spacing direction is closed unless genuinely new evidence creates a distinct consumer.

Visuals: `visuals/r2_parent_child_metrics.svg`, `r2_year_net.svg`, `r2_balance_proxy.svg`, `r2_underwater_proxy.svg`, `r2_depth_distribution.svg`. All are `VISUAL_ONLY_NO_AUTHORITY`.
