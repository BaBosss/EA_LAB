# B16 GBPUSD SELL H4 Depth-2 Ablation — H06 Results

Status: `PASS MECHANICAL / HYPOTHESIS_NOT_FALSIFIED / DEPTH2_DUAL_WINDOW_POSITIVE / RESEARCH_ONLY`
Hypothesis: `HYP-B16-GBP-SELL-H4-DEPTH2-01`
Preregistered HEAD: `9f6471aaf8c759130a29d9bc215a258dbff51a6f`
HOLDOUT: `UNSPENT`; Optimization: `NONE`.

## Executive answer
The exact GBPUSD/H4 SELL child with `_16_MaxOrdersPerSide 10 -> 2` remains aggregate-net positive in both frozen windows, so the preregistered first-add-sufficiency hypothesis is **not falsified**. Deeper-than-two exposure is therefore not required merely to preserve aggregate MAIN+BWD sign on this profile.

That is not an adoption result. Depth-2 materially damages MAIN economics and loses the accepted parent's all-six-calendar-year positivity: MAIN net falls from `+283.20` to `+50.11`, PF from `7.97` to `1.37`, and 2025 flips from `+119.21` to `-108.53`. BWD remains strong at `+247.04` with EqDD `1.04%`, but its report has zero gross loss, so PF is mathematically undefined; the MT5 displayed PF field `0.00` must not be interpreted as a zero-quality PF.

Decision: `RETAIN_PARENT_RESEARCH_REFERENCE / DEPTH2_NOT_ADOPTED`. The evidence says positions beyond the first add materially contribute to MAIN/year stability even though they are not necessary for dual-window aggregate sign.

## Identity and one-change integrity
- Base SHA: `50b263831e85a71a5f2d4bea417dbc00f2483a7e`.
- Parent SELL set SHA256: `c0e7cfad84236b798dece5b5106d271c708553fb220af370dba913d8610105de`.
- Child set SHA256: `d31a34b68caaaeabca07d960dede016a8cf513fd8e4c6cf2bbe124d172d55b14`.
- Sole input change: `_16_MaxOrdersPerSide=10 -> 2`.
- Direction remains SELL; RSI `14/70`, spacing, exits, sizing and cages remain frozen.
- Build receipt `br-4fa94d22907b446ebc721d524bdfa5d1`; EX5 SHA256 `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.

## Mechanical acceptance
Both Model-1 cells exited 0 on Meta5b with exact GBPUSD/H4 dates, Optimization 0, full `173/173` input surface, exact set/build/EX5 identity and leverage `1:100 MATCH`. Truncation checker is false for both windows; direct execution-log scan found no hard kill.

The runner emitted an mtime `STALE` warning because the isolated worktree was materialized after the accepted EX5. Git byte reconciliation from build source ref `cf32ba8d32a8292e8f7b5ad2ef766e3442b20125` to execution base found no relevant B16/core source change; this is a worktree-mtime false positive, not an identity failure. See `source_byte_reconciliation.txt` and `mechanical_acceptance.json`.

## Parent vs depth-2 child
| Window | Parent | Depth-2 child | Interpretation |
|---|---|---|---|
| MAIN | PF 7.97 / net +283.20 / 80 trades / EqDD 1.72% | PF 1.37 / net +50.11 / 73 trades / EqDD 1.73% | aggregate positive but materially weaker economics |
| BWD | PF 14.36 / net +268.97 / 76 trades / EqDD 1.27% | PF `UNDEFINED_NO_GROSS_LOSS` / net +247.04 / 73 trades / EqDD 1.04% | sign retained, net slightly lower, DD lower; PF ratio is not comparable |

MAIN net delta is `-233.09`; BWD net delta is `-21.93`. Max realized depth falls `4 -> 2` and max aggregate lots `0.04 -> 0.02` in both windows.

Cycle participation remains substantial rather than EMPTY: child MAIN has 68 cycles and BWD 69. Multi-entry positive gross-profit share is `52.76%` MAIN / `51.94%` BWD versus parent `70.96% / 58.94%`. Active-time share is `17.99%` MAIN / `9.29%` BWD versus parent `19.71% / 8.93%` under the same accepted parser methodology.

## Calendar-year evidence
Depth-2 MAIN: 2023 `+79.53`, 2024 `+79.11`, 2025 `-108.53`.
Depth-2 BWD: 2020 `+151.20`, 2021 `+58.45`, 2022 `+37.39`.

The primary falsifier is aggregate-window sign, so the negative 2025 year does not retroactively falsify the preregistered hypothesis. It does materially limit interpretation and prevents treating depth-2 as a superior or equally robust replacement for the accepted parent.

## Evidence / interpretation / decision
**Evidence:** two mechanically valid full-window cells remain net positive with max depth 2; MAIN economics collapse relative to parent and one MAIN calendar year becomes negative; BWD remains positive with no gross losing ticket in the report.

**Interpretation:** the first add is sufficient for aggregate dual-window positivity, but the third/fourth-position region contributes materially to MAIN economic output and year distribution. The position engine is therefore still structural; `depth > 2` is not required for sign, but it is not economically redundant.

**Decision:** `HYPOTHESIS_NOT_FALSIFIED / DEPTH2_DUAL_WINDOW_POSITIVE`, while `DEPTH2_NOT_ADOPTED`. Keep the accepted `14/70`, max-10 parent as the research reference. No default or risk semantics change follows.

## Assessment and next consumer
- Working research verdict: `PARK / DEPTH2_SIGN_SURVIVES_UTILITY_WEAKENS`.
- `QUALITY_GRADE = UNRATIFIED`; `EVIDENCE_CONFIDENCE = UNRATIFIED`.
- Model 4: `NOT RUN`; Monte Carlo: `NOT RUN`; HOLDOUT: `UNSPENT`.
- Candidate/DEMO/LIVE/deployment/risk/default authority: `NONE`.

Highest-information next child, if continued under a separate prospective contract: `HYP-B16-GBP-SELL-H4-DEPTH3-01`, changing only max depth `10 -> 3`. Direct consumer: locate whether the second adverse add recovers the lost MAIN/2025 economics while retaining materially lower exposure than the realized parent depth 4. Do not add that value to this already-completed H06 contract and do not search a depth range adaptively.

Machine evidence: `factory/runs/b16_h06_20260831/gbp_sell_h4_depth2/`. Visual `parent_depth2_net.svg` is `VISUAL_ONLY_NO_AUTHORITY`.