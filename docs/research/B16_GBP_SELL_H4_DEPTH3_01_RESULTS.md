# B16 GBPUSD SELL H4 Depth-3 Ablation - H07 Results

Status: `PASS MECHANICAL / HYPOTHESIS_NOT_FALSIFIED / DEPTH3_RECOVERS_2025_SIGN / RESEARCH_ONLY / DEPTH STRUCTURAL MILESTONE CLOSED`
Hypothesis: `HYP-B16-GBP-SELL-H4-DEPTH3-01`
Preregistered HEAD: `e2cf21e2a0c9f95559b88ebb92d9a520832b7126`
HOLDOUT: `UNSPENT`; Optimization: `NONE`.

## Executive answer
The exact GBPUSD/H4 SELL child with `_16_MaxOrdersPerSide 10 -> 3` satisfies the preregistered H07 statement. MAIN and BWD remain aggregate-net positive, and 2025 returns to positive net while depth 3 is actually exercised in two 2025 cycles. Classification is `HYPOTHESIS_NOT_FALSIFIED / DEPTH3_RECOVERS_2025_SIGN`.

Depth-3 MAIN is net `+309.13`, 78 trades, EqDD `1.57%`; BWD is net `+279.79`, 75 trades, EqDD `1.23%`. Both reports contain zero gross loss, so Profit Factor is mathematically undefined; MT5's displayed `0.00` field is preserved as a raw field but is not interpreted as PF=0.

This is stronger evidence than depth-2, but it is not automatic adoption. The max-10 parent remains an accepted research reference and depth-3 becomes a second research reference for the next owner-approved/future research routing. No strategy default, risk default, Candidate, HOLDOUT, DEMO or LIVE authority is created.

## Identity and one-change integrity
- Base SHA: `d302a9c0ea343a5d633c96facf76c782905b79a1`.
- Parent SELL set SHA256: `c0e7cfad84236b798dece5b5106d271c708553fb220af370dba913d8610105de`.
- Child set SHA256: `3dbcf63f002a0bfad0371c5f26acf7156a6eabc8820f31a0d67f663f24f3edd5`.
- Sole input change: `_16_MaxOrdersPerSide=10 -> 3`.
- Direction SELL, RSI 14/70, spacing, exits, sizing and protections remain frozen.
- Build receipt `br-4fa94d22907b446ebc721d524bdfa5d1`; EX5 SHA256 `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.

## Mechanical acceptance
Both Model-1 cells exited 0 on Meta5b with exact GBPUSD/H4 windows, Optimization 0, full 173/173 input surface, exact set/build/EX5 identity and leverage `1:100 MATCH`. Truncation is false for both windows and execution-log scan finds no hard kill.

The runner emitted the known mtime `STALE` warning because the isolated worktree was materialized after the accepted EX5. Git reconciliation confirms no B16/core/`mt5_run.ps1` execution-byte change from build source ref `cf32ba8d...` through H07 base. The current canonical H03 parser SHA256 is pinned in `source_parser_reconciliation.txt` and is applied consistently to parent10, canonical depth2 and new depth3 raw reports.

## Depth ladder
| Window | Parent max10 | Depth2 | Depth3 |
|---|---|---|---|
| MAIN | PF 7.97 / net +283.20 / 80 trades / EqDD 1.72% / realized depth 4 | PF 1.37 / net +50.11 / 73 / EqDD 1.73% / depth 2 | PF `UNDEFINED_NO_GROSS_LOSS` / net +309.13 / 78 / EqDD 1.57% / depth 3 |
| BWD | PF 14.36 / net +268.97 / 76 trades / EqDD 1.27% / realized depth 4 | PF `UNDEFINED_NO_GROSS_LOSS` / net +247.04 / 73 / EqDD 1.04% / depth 2 | PF `UNDEFINED_NO_GROSS_LOSS` / net +279.79 / 75 / EqDD 1.23% / depth 3 |

Depth3 improves aggregate net versus the accepted parent by `+25.93` MAIN and `+10.82` BWD while native EqDD is lower by `0.15 pp` MAIN and `0.04 pp` BWD. Cycles remain almost unchanged: MAIN 70 vs parent 70; BWD 69 vs parent 69.

Multi-entry positive gross-profit share remains material at `69.58%` MAIN / `57.57%` BWD, close to the parent `70.96% / 58.94%`. The result therefore does not make the position engine irrelevant; it isolates the fourth-position region as unnecessary for the observed aggregate economics in these frozen windows.

## Calendar-year and branch-contact evidence
| Year | Parent max10 | Depth2 | Depth3 | Depth3 branch evidence |
|---|---:|---:|---:|---|
| 2020 | +173.13 | +151.20 | +183.95 | two depth-3 cycles |
| 2021 | +58.45 | +58.45 | +58.45 | max depth 2; cap-3 not binding |
| 2022 | +37.39 | +37.39 | +37.39 | max depth 1; cap-3 not binding |
| 2023 | +79.53 | +79.53 | +79.53 | max depth 2; cap-3 not binding |
| 2024 | +84.46 | +79.11 | +100.27 | one depth-3 cycle |
| 2025 | +119.21 | -108.53 | +129.33 | two depth-3 cycles; parent also has one depth-4 cycle |

All six depth-3 calendar years are positive. The preregistered causal check is satisfied specifically in 2025: depth2 is negative, depth3 is positive, and two child cycles actually touch depth 3. Because both depth2 and depth3 keep the four-position overlap branch unreachable, the depth2 -> depth3 difference cleanly isolates permission for the second adverse add.

## Evidence / interpretation / decision
**Evidence:** depth3 is mechanically valid, touches the newly permitted level in the target year, restores 2025 positive net, retains aggregate positive MAIN+BWD, preserves all-six-year positivity and has lower aggregate EqDD than the accepted parent in both windows.

**Interpretation:** the first adverse add (depth2) is enough for aggregate sign but not for stable MAIN/year utility; permitting the second adverse add (depth3) restores that utility in the tested windows. The accepted parent's realized fourth-position region is not required to reproduce all-six-year positivity or aggregate economics here. This is a bounded, context-specific mechanism conclusion, not a universal grid-depth rule.

**Decision:** `HYPOTHESIS_NOT_FALSIFIED / DEPTH3_RECOVERS_2025_SIGN`. Close the B16 structural-depth milestone with `PARENT10` and `DEPTH3` retained as research references; `DEPTH3` is **not automatically adopted as a strategy/risk default** by this experiment.

## Authority and next routing
- Working research status: `PARK / DEPTH_MILESTONE_CLOSED / DEPTH3_STRONG_RESEARCH_REFERENCE`.
- `KINT-001` remains OPEN; no numeric Grade/Confidence mapping is inferred.
- Model 4: `NOT RUN`; Monte Carlo: `NOT RUN`; HOLDOUT: `UNSPENT`.
- Candidate/DEMO/LIVE/deployment/risk/default authority: `NONE`.
- Do not run a depth-4 child or adaptively search more depth values: the accepted parent already supplies realized depth-4 evidence, and the 2/3/parent ladder has answered this direct consumer.
- Any later use of depth3 as a frozen revision, robustness finalist or default requires a separate prospective contract at the applicable authority boundary; BWD/HOLDOUT must not be mined to retune this result.

## Evidence package
Machine evidence: `factory/runs/b16_h07_20260831/gbp_sell_h4_depth3/`.
Key files: `evidence_summary.json`, `mechanical_acceptance.json`, `depth_ladder.csv`, `year_depth_ladder.csv`, `depth_ladder_evidence.json`, `milestone_summary.json`, `source_parser_reconciliation.txt`, raw `report.htm.gz` + tester/sidecars, and `artifacts.sha256`.

Visual `depth_ladder_net.svg` is `VISUAL_ONLY_NO_AUTHORITY`.
