# B15 CountBars Timing Sensitivity 01 Results

Status: **PASS MECHANICAL / TIMING_NOT_IMPROVED / PARK_COUNTBARS_TIMING_PATH / RESEARCH_ONLY**
Hypothesis: `HYP-B15-COUNTBARS-SENS-01`
Preregistered contract: `docs/research/B15_COUNTBARS_SENS_01_CONTRACT.md`
Execution package: `factory/runs/b15_countbars_sens01_20260831/`
HOLDOUT: `UNSPENT`
Optimization: `NONE`
Model-4 / Monte Carlo: `NOT RUN`

## 1. Decision summary

All 12 prospectively authorized Model-1 child cells completed mechanically on Meta5c. The preregistered cross-home test did **not** improve over the accepted CountBars=2 parent: parent, CountBars=1, and CountBars=3 each have exactly `1/3` H4 homes with PF>1 in both MAIN and BWD.

`CountBars=3` materially improves the already-positive GBPUSD/H4 home, especially BWD, but does not repair USDJPY/H4 BWD or EURUSD/H4 MAIN. This is a local/home effect, not portable timing improvement under the preregistered test.

Decision: **PARK the CountBars timing path.** Do not widen CountBars, change MACD periods, enable RearmBars, disable EdgeTrigger, or mine BWD in response to this result. A different parameter family requires a new prospective hypothesis and direct consumer.

`MECHANISM_VALUE = WEAK` for the CountBars timing-adjustment path. This does **not** reverse the previously accepted contribution of the ST03 edge latch itself.

## 2. Identity and mechanics

EA/build: Boss15 / `Boss_15_ST03` / `LAB_ENTRY_15`. Tester: Model 1, USD 10,000, leverage 1:100, Meta5c portable.
Source signal: closed bar MACD main above/below signal increments BUY/SELL consecutive counters; a signal is emitted once the counter reaches `_15_CountBars`. With `_15_EdgeTrigger=true`, only one signal fires per uninterrupted MACD-state run; `_15_RearmBars=0` keeps re-fire disabled until the state flips.

Frozen baseline mechanics include MACD `12/26/9`, both-direction trading, `StackMode=90` (`STACK_SINGLE`), fixed first lot `0.01`, `LotProg=50` (`PROG_NONE`), `RecoveryMode=80` (`REC_NONE`), `HedgeMode=0`, ATR TP (`3.0 x Risk-ATR`) and ATR SL (`2.0 x Risk-ATR`). The experiment changed only `_15_CountBars`: parent `2`, children `1` and `3`.

Accepted EX5 SHA256: `f3dd7c5f2e2c1eb5a9f30a95a120e8977aa071e86f5ea4d9929e84f74940803a`.
Parent set SHA256: `ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c`.
COUNT1 set SHA256: `4fb0fc9ba11f0b9f762bd6115c447891447c74cea2021c9958dacbe9ae5df94c`.
COUNT3 set SHA256: `6834c47a4f7f43a2679c03dd237101f2b011ea155cb8fd9a4676837ef73d75e1`.
Each child set differs from the accepted parent on exactly one line: `_15_CountBars`.

## 3. Mechanical acceptance

- 12/12 authorized cells produced fresh reports and runner exit code 0.
- 12/12 leverage receipts are `MATCH` at 1:100.
- 12/12 truncation receipts report `false`.
- Raw report SHA256 values reconcile 12/12 with `evidence_summary.json`.
- Execution console contains 12 `RUN_START`, 12 `RUN_END code=0`, and the terminal sequence marker.
- Every launch reported `FULL` 157/157 input surface and the same stamped build receipt `br-58971201f0774c47bf5e6f423c47e1bc`.

The launcher also printed a source-mtime `STALE` warning because the re-anchored Git worktree gave source files newer checkout timestamps than the accepted EX5. This is a harness/provenance timestamp warning, not accepted evidence of byte drift: current `Boss_15_ST03.mq5` SHA256 equals the build-receipt source SHA `e235105deac8c975093a920b34b84565d2d6e355fa64a7802b05dd6592c1d88f`, while the EX5 hash also matches the stamped receipt exactly.
## 4. Evidence

PF values below are native MT5 report metrics. EqDD is the native `Equity Drawdown Maximal` percentage. Parent GBPUSD net is `UNAVAILABLE` because the accepted H02 pair-matrix owner did not preserve parent net in that table; it is not reconstructed here.

| CountBars | Home | MAIN PF / net / trades / EqDD | BWD PF / net / trades / EqDD | Dual-positive? |
|---:|---|---|---|---|
| 2 parent | GBPUSD H4 | 1.10 / UNAVAILABLE / 214 / 0.97% | 1.07 / UNAVAILABLE / 218 / 1.83% | YES |
| 2 parent | USDJPY H4 | 1.24 / +173.71 / 199 / 1.45% | 0.97 / -18.83 / 204 / 1.61% | NO |
| 2 parent | EURUSD H4 | 0.96 / -30.63 / 206 / 0.97% | 1.25 / +179.25 / 217 / 0.92% | NO |
| 1 | GBPUSD H4 | 1.01 / +9.10 / 210 / 1.07% | 1.11 / +123.58 / 217 / 2.00% | YES |
| 1 | USDJPY H4 | 1.10 / +79.13 / 199 / 1.96% | 0.91 / -60.46 / 196 / 1.18% | NO |
| 1 | EURUSD H4 | 0.87 / -95.73 / 203 / 1.50% | 1.12 / +91.93 / 212 / 1.11% | NO |
| 3 | GBPUSD H4 | 1.13 / +104.81 / 213 / 1.53% | 1.47 / +424.00 / 212 / 1.03% | YES |
| 3 | USDJPY H4 | 1.20 / +144.16 / 187 / 1.71% | 0.85 / -104.03 / 198 / 1.61% | NO |
| 3 | EURUSD H4 | 0.92 / -52.42 / 202 / 1.32% | 1.27 / +184.71 / 211 / 0.86% | NO |

Preregistered dual-positive counts: parent `1/3`, COUNT1 `1/3`, COUNT3 `1/3`. Therefore the exact classification is `TIMING_NOT_IMPROVED`.

## 5. Calendar-year evidence

The full machine-readable year split is `factory/runs/b15_countbars_sens01_20260831/year_split.csv`. It shows that aggregate dual-window positivity does not imply uniform calendar-year behavior.
Selected examples: COUNT3/GBPUSD MAIN is aggregate-positive but 2024 (`PF 0.919`, `-20.32`) and 2025 (`PF 0.828`, `-53.30`) are negative; BWD 2021 is near-flat (`PF 0.996`, `-1.10`). USDJPY BWD remains negative in all three BWD years for both children. EURUSD MAIN remains structurally mixed/negative despite positive BWD aggregates.

## 6. Parent-child interpretation

COUNT1 weakens PF versus parent on five of the six symbol-window comparisons and improves only GBPUSD BWD (`1.07 -> 1.11`). It does not improve the number of dual-positive homes.

COUNT3 improves GBPUSD MAIN (`1.10 -> 1.13`) and BWD (`1.07 -> 1.47`), and slightly improves EURUSD BWD (`1.25 -> 1.27`). It still leaves USDJPY BWD at `0.85` and EURUSD MAIN at `0.92`, so the cross-home problem remains unchanged.

This supports a reusable mechanism finding: the previously accepted one-fire-per-state-run edge latch remains important, but moving the consecutive-confirmation threshold by one bar around the parent does not create portable cross-home robustness. GBPUSD/H4 appears more tolerant of longer confirmation than the other tested H4 homes.

Historical context only, not part of this experiment's preregistered decision rule: archived reviewed ORDER-119 previously swept MACD parameters with CountBars values `2/3/4` under a different rolling MAIN window/home set and also failed to find a robust both-window flat-lot configuration. The present experiment uses the current canonical H02 windows/homes and adds the previously untested local neighbor `CountBars=1`; its decision stands on the 12 prospective cells above.

## 7. Exposure, exit and risk state

The active baseline is `STACK_SINGLE`; no grid/add ladder is active in this experiment. First-lot mode is fixed at `0.01` and lot progression is `PROG_NONE`. Recovery and hedge modes are off. `_9_MaxLevels=5` belongs to the dormant stack surface and is not evidence that five levels were used here.

ATR TP and ATR SL remain frozen at `3.0x` and `2.0x` Risk-ATR respectively. `RC_MaxLot=0.2` is present as a cage cap, `RC_AcctDDLimitPct=0.0`, and adaptive DD sizing is off. Exact maximum concurrent open positions and floating-equity time-series exposure were not reconstructed from closed-deal rows in this R2 report; where unavailable they remain `UNAVAILABLE` rather than inferred.
## 8. R2 visual pack

Selected cell for detailed visualization: COUNT3 / GBPUSD / H4 / MAIN, because it is the strongest local child effect while still failing the cross-home routing gate.

Required R2 views:
1. `visuals/r2_closed_deal_balance_proxy.svg` - closed-deal cumulative balance proxy.
2. `visuals/r2_closed_deal_underwater_proxy.svg` - closed-deal underwater proxy.
3. `visuals/r2_year_distribution.svg` - calendar-year net distribution.
4. `visuals/r2_countbars_mechanism_compare.svg` - CountBars mechanism comparison across homes/windows.
5. `visuals/r2_parent_child_pf_delta.svg` - parent-versus-child PF comparison.

The proxy charts are explicitly not native floating-equity curves. The native MT5 report does not expose a timestamped floating-equity series in the HTML. Four native MT5 PNGs for the selected cell are preserved under `visuals/native/` and remain source evidence; every generated SVG is `VISUAL_ONLY_NO_AUTHORITY`.

## 9. Assessment and routing

`VERDICT = PARK` for this CountBars timing path.
`QUALITY_GRADE = UNRATIFIED`.
`EVIDENCE_CONFIDENCE = UNRATIFIED` (12/12 mechanically eligible prospective cells; numeric/letter mapping remains unratified).
`BUILD_POTENTIAL = EXHAUSTED` for this CountBars timing path only, not for all possible B15 research.
`MECHANISM_VALUE = WEAK` for CountBars timing adjustment.

Known unknowns: no Model-4 fidelity run, no Monte Carlo, no HOLDOUT use, no new regime attribution, and no authoritative universal Grade mapping. This experiment grants no deployment/risk/default or promotion authority.

Next consumer: **none for CountBars/MACD timing optimization under this contract.** The timing path is PARKED. Any future B15 child must be justified by a different prospectively registered causal mechanism with a direct consumer and must not mine these BWD outcomes.

## 10. Evidence owners

Machine-readable owners: `evidence_summary.json`, `mechanical_acceptance.json`, `cell_summary.csv`, `parent_child.csv`, `year_split.csv`, raw per-cell report bundles, exact sets, execution manifest and execution console under `factory/runs/b15_countbars_sens01_20260831/`.