# B16 GBPUSD SELL H4 OPT01  Entry-Surface Optimization Results

Status: COMPLETE / RESEARCH_ONLY / CENTER_NOT_ADOPTED
Factory hypothesis: `B16-H05-r1`
Stage: `WIDE_COARSE_ENTRY -> LOCKED_FIXED_MAIN+BWD_VALIDATION`
Runtime evidence: MT5 lane2 / `D:\Meta 5b` / Model 1 / USD 10,000 / leverage 1:100
HOLDOUT: `UNSPENT`

## Executive summary

- The preregistered 45 RSI-entry lattice was fully observed: 20/20 MAIN combinations.
- The accepted parent `14/70` reproduced exactly on the coarse surface at net `+283.20`, PF `7.97`, 80 trades, native EqDD `1.72%`.
- Exactly one preregistered interior five-cell cross passed the positive-net plateau rule: center `RsiPeriod=21 / RsiHigh=70`.
- The center was frozen before BWD. Fixed validation passed mechanically in both windows and remained profitable in every calendar year 20202025.
- The center is **not adopted**: versus accepted parent `14/70`, it materially reduces net profit, trades, cycles, active participation, and BWD realized position-engine participation.
- Lower DD is real, but it does not satisfy the direct consumer: finding a useful stable entry region around the accepted profile.
- Medium/fine refinement is `NOT RUN`; BWD was not used to retune.

## 1. Identity and prospective contract

- Preregistration commit: `0f0ffbc8c86a304e937c0b509a7c4719a3e10bf1`.
- Factory registration commit: `581e08dc782ece1a1ce596f7d5696b30280e4587`.
- Coarse evidence commit: `0c0d35d5422e85115947e882694f73740766eebe`.
- Fixed-center package commit: `b58de5c29fc005dfd07eb0a6689cf400cde7a575`; bounded harness repair: `5fa1596aa54bb80e8a42c9678ac93cc8d0d55136`.
- Accepted parent SELL set SHA256: `c0e7cfad84236b798dece5b5106d271c708553fb220af370dba913d8610105de`.
- Locked center set SHA256: `e98bc667a5384047991a1bfc674d84caefec381534834500b1a3db40652f6bc5`.- Relative to the parent, the locked set changes only `_16_RsiPeriod 14 -> 21`; `_16_RsiHigh` remains `70.0`.
- Build receipt: `br-4fa94d22907b446ebc721d524bdfa5d1`; EX5 SHA256: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
- Relevant Boss16/core source bytes remained unchanged from accepted build source ref `cf32ba8d32a8292e8f7b5ad2ef766e3442b20125`.

## 2. Frozen versus tunable surface

Only `_16_RsiPeriod={7,14,21,28}` and `_16_RsiHigh={60,65,70,75,80}` were TUNABLE. Direction stayed SELL. Position engine, spacing, exits, sizing, runtime identity, protection, and safety stayed frozen.

`optimize_guard` resolved 161 `B16-H05-r1` ParameterBindings and returned `ALLOW 2 / REFUSE 0`; no `-SkipOptimizeGuard` was used.

## 3. Coarse MAIN surface and plateau selection

- Optimizer XML SHA256: `18ad98f125610bc7f86089c635d49884c875fbbde4d7a435950ed22af68d7211`.
- Fast Genetic exposed all 20 lattice cells, so no COMPLETE fill-in was needed.
- Selection did not use top PF or optimizer Result. The preregistered rule required an interior center whose center plus four orthogonal neighbors each had MAIN net > 0.
- Six interior candidate centers were evaluated; only `21/70` was admissible.
- Selected cross: minimum MAIN net `+13.22`, minimum trade count `11`, maximum native EqDD `1.7762%`.
- This proves a positive MAIN neighborhood exists, but the thin edge cells are a warning, not promotion evidence.

## 4. Fixed center validation

| Window | Net | PF | Trades | Native EqDD | Cycles | Max depth | Max lots | Multi-entry GP share |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| MAIN | +102.13 | 6.03 | 30 | 1.35% | 26 | 4 | 0.04 | 73.50% |
| BWD | +37.55 | 7.28 | 27 | 0.15% | 27 | 1 | 0.01 | 0.00% |

Both reports are fresh, leverage MATCH, `Optimization=0`, and truncation checker says `false`.MAIN has a quiet 138.3-day tail, explicitly classified by the checker as signal inactivity rather than cage truncation; native EqDD stayed 1.35%. BWD realizes only single-position cycles (`max depth=1`, max aggregate lots `0.01`), materially different from the accepted parent BWD path, which reached depth 4.

## 5. Parent versus selected center

| Window | Parent net | Center net | Delta | Parent trades | Center trades | Parent PF | Center PF | Parent EqDD | Center EqDD |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| MAIN | +283.20 | +102.13 | -181.07 | 80 | 30 | 7.97 | 6.03 | 1.72% | 1.35% |
| BWD | +268.97 | +37.55 | -231.42 | 76 | 27 | 14.36 | 7.28 | 1.27% | 0.15% |

- MAIN cycles fall `70 -> 26`; active-time share falls `19.71% -> 7.72%`.
- BWD cycles fall `69 -> 27`; active-time share falls `8.93% -> 0.86%`.
- BWD max depth falls `4 -> 1`; multi-entry positive gross-profit share falls `58.94% -> 0%`.
- DD improves, but the center does not improve or preserve participation/economic output and shifts the realized behavior toward a much thinner signal path.

## 6. Calendar-year participation

| Window | Year | Parent net | Center net | Parent trades | Center trades | Center cycles |
|---|---:|---:|---:|---:|---:|---:|
| BWD | 2020 | +173.13 | +23.83 | 35 | 18 | 18 |
| BWD | 2021 | +58.45 | +7.80 | 23 | 5 | 5 |
| BWD | 2022 | +37.39 | +5.92 | 18 | 4 | 4 |
| MAIN | 2023 | +79.53 | +14.37 | 33 | 10 | 10 |
| MAIN | 2024 | +84.46 | +74.32 | 19 | 11 | 7 |
| MAIN | 2025 | +119.21 | +13.44 | 28 | 9 | 9 |

All six center calendar years are net positive. The issue is not a simple sign failure; it is utility, participation, and realized-mechanism shrinkage versus the accepted parent.

## 7. Evidence, interpretation, decision

**Evidence.** A non-boundary positive MAIN RSI-entry neighborhood exists. Center `21/70` is positive in fixed MAIN and fixed BWD and positive in each year 2020-2025. Mechanical identity is green.

**Interpretation.** Local sign stability is real, but it is obtained by moving to a much thinner realized profile. The parent `14/70` is economically stronger but itself fails the preregistered five-cell plateau rule because one orthogonal neighbor is negative. Therefore neither "parent is robust" nor "21/70 is a better replacement" is supported.

**Decision.** `DO_NOT_ADOPT_CENTER_RETAIN_PARENT_RESEARCH_REFERENCE`. Close `B16-H05-r1` without medium/fine refinement. Do not use BWD to choose another RSI pair. A later search dimension requires a separate prospective hypothesis and direct consumer.

## 8. Assessment / authority

- Working research verdict: `PARK / ENTRY_OPT01_NON_IMPROVING`.
- `QUALITY_GRADE = UNRATIFIED`.
- `EVIDENCE_CONFIDENCE = UNRATIFIED`.
- HOLDOUT: `UNSPENT`.
- Model 4: `NOT RUN`.
- Monte Carlo: `NOT RUN`.
- Candidate/DEMO/LIVE/deployment/risk/default authority: `NONE`.
- `KINT-001` remains OPEN; no sample-floor conflict is resolved here.

## 9. Next research routing

Entry-only RSI optimization is exhausted at this bounded scope: the only stable coarse center does not improve the accepted lead. If B16 is continued, the next consumer should be a separately preregistered one-change question on a mechanism already identified as structural, rather than a wider RSI search. No next child is authorized by this report itself.

## 10. Visuals and machine-readable evidence

- `factory/runs/b16_opt01_20260831/gbp_sell_h4/opt01_surface.svg` - coarse 4x5 entry surface.
- `factory/runs/b16_opt01_20260831/gbp_sell_h4/parent_center_comparison.svg` - fixed parent-vs-center comparison.
- `factory/runs/b16_opt01_20260831/gbp_sell_h4/optimizer_surface.csv`, `plateau_candidates.csv`, `selection.json`, `validation_analysis.json`, `parent_center_comparison.csv`, `validation_year_split.csv`, `final_summary.json`.
- Visuals are `VISUAL_ONLY_NO_AUTHORITY`; exact reports/configs and machine-readable evidence control.
