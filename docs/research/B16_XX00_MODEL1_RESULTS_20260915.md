# B16-00 Kangaroo USDJPY/H1 Fixed Model1 Result — 2026-09-15

Status: `EXECUTION_COMPLETE / MECHANICAL_PASS_2_OF_2 / RESEARCH_ONLY`
Classification: `DUAL_WINDOW_SCREEN_PULSE / BWD_THIN_YEAR_UNSTABLE`
Decision: `REFERENCE_ESTABLISHED / STOP_EXPANSION_NO_DIRECT_CONSUMER`
Contract: `docs/research/B16_XX00_REFERENCE_AND_MODEL1_CONTRACT_20260915.md`
Contract canonical head: `4d5325c00ca1f31a48db5dd6c499fec4882ba520`

## Exact execution identity

Both cells ran serially on `D:\Meta 5c`, MT5 build 6140, Model1 / 1 Minute OHLC, exact `USDJPY/H1`, USD 10,000, leverage 1:100, Optimization=0, Forward=0.
The frozen set SHA256 is `b9cd05f2b728c48e1095fb0ea113486e78ee264ad9d2464b46bc9b889a56f9c9`.
The stamped build receipt is `br-ed5d1cbd99514b7fac56dd78997e81d8`; EX5 SHA256 is `dd8f6170d6375b415d4522af9fdd78e9466b565e41cfb4cc7a5c6dbbcbb03014`.
The build source graph covers 83 static source files. MetaEditor compilation returned `0 errors, 0 warnings`.
Both launch identities passed full-surface `173/173` config coverage and the same config fingerprint `c9b7158ce1ca302419a7de037a030a8d891975270bf1fc0cacfa4f878c0fcaf6`.

| Window | Report SHA256 | PF | Net | Trades | EqDD | Quality | Mechanical |
|---|---|---:|---:|---:|---:|---:|---|
| MAIN 2023-2025 | `bb8b87fc73bbf92b903b84c7c5ddfc8b62aadcab1cac2638e06dfe58014e7c62` | 1.52 | +248.99 | 275 | 3.86% | 100% | PASS / not truncated |
| BWD 2020-2022 | `9f87321fb3ce3f2331c8cf656821f4e9c4d0742a4277ca2eea0461295e72db7c` | 1.03 | +11.31 | 186 | 2.41% | 99% | PASS / not truncated |

## Year split

| Window | Year | PF | Net | Trades | Balance DD |
|---|---:|---:|---:|---:|---:|
| MAIN | 2023 | 2.50 | +136.21 | 104 | 0.90% |
| MAIN | 2024 | 1.23 | +53.83 | 90 | 1.91% |
| MAIN | 2025 | 1.37 | +58.95 | 81 | 1.23% |
| BWD | 2020 | 0.34 | -116.34 | 24 | 1.24% |
| BWD | 2021 | 11.54 | +99.27 | 69 | 0.09% |
| BWD | 2022 | 1.13 | +28.38 | 93 | 1.69% |

MAIN is positive in all three calendar years. BWD is only barely positive in aggregate and contains a clear losing 2020, so the dual-window aggregate sign does not establish stable all-year robustness.

## Position / exposure evidence

| Window | Cycles | Max positions/depth | Max aggregate lots | Max entry-price span | Active-time share | Multi-entry GP share |
|---|---:|---:|---:|---:|---:|---:|
| MAIN | 239 | 7 | 0.07 | 15.627 | 21.68% | 74.65% |
| BWD | 161 | 5 | 0.05 | 13.105 | 36.82% | 75.50% |

The report-ledger reconstruction reconciles net profit and closed-ticket counts for both cells. Flat lots are observed; with frozen `_16_BaseLot=0.01` and `_16_LadderMult=1.0`, the observed realized ladder is `0.01` per simultaneous entry through the realized depths above. Broker volume-step metadata is not newly established by this result and remains outside the claim.
MAIN largest realized cycle loss is `-148.33` and largest closed-ticket loss `-68.67`; BWD is `-151.78` and `-53.27` respectively.

## Visual evidence

Derived R1 views are in `factory/runs/b16_xx00_model1_control_20260915/views/`: PF by window, participation, PF-versus-participation, and EqDD. Native MT5 report images are preserved inside each runtime cell directory. All derived views identify this exact B16-00 evidence package and do not replace the raw reports.

## Interpretation and decision

This current-source/current-build B16-00 reference produces an aggregate `DUAL_WINDOW_SCREEN_PULSE`: both MAIN and BWD are mechanically valid with PF > 1 and net > 0. That observation is bounded by weak BWD margin and the losing 2020 year. It is not a Candidate, optimization center, robustness PASS, or all-regime claim.

Earlier B16 USDJPY/H1 H02/R4 evidence belongs to different tester installation lineages. It may provide historical research context, but its numerical values are not acceptance comparators for these Meta5c cells and are not used to declare improvement, deterioration, or nondeterminism.

Decision is `REFERENCE_ESTABLISHED / STOP_EXPANSION_NO_DIRECT_CONSUMER`. The owner-ratified B16-00 configuration is now source/build/config-bound and has fresh Model1 MAIN+BWD evidence. This result does not create a justified new B16 parameter search: H05/H07/H08 and spacing directions remain closed, BWD is not a search surface, and the present evidence supplies no independent one-change causal question that should override those closures.

If a later strategy-plan handoff names B16-00 as a direct parent for a genuinely distinct source-traceable hypothesis, that hypothesis requires a separate prospective contract. Otherwise the next program consumer is the streaming EA-planning/backtest queue, not another B16 tester run.

## Authority / known limits

HOLDOUT=`UNSPENT`; Optimization=`NONE`; Model4=`NOT RUN`; Monte Carlo=`NOT RUN`; Grade/KINT=`UNRATIFIED`; Candidate/DEMO/LIVE/deployment/risk/default authority=`NONE`.
No source or set retune occurred between MAIN and BWD. No cross-install numerical comparison supports this decision.
Machine-readable owners: `evidence_summary.json`, `exposure_diagnostics.json`, `cell_summary.csv`, `year_split.csv`, `package_manifest.json`, and the exact runtime report/INI/sidecar files under the run directory.
