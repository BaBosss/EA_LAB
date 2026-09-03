# Boss18 H01 Fixed-Baseline Results — 2026-09-03

Status: `COMPLETE / MECHANICAL PASS / R1 ISOLATED_PULSE / RESEARCH_ONLY`
Routing: `STOP_EXPANSION_NO_DIRECT_CONSUMER`.
Authority: `NON_AUTHORITATIVE_SIDECAR`; no optimization, HOLDOUT, Candidate, Grade/KINT, DEMO/LIVE, deployment, trading, risk/default, or strategy-redesign authority.

## 1. Contract and identity

- Family / revision: `B18 / Boss_18_JumStoch / B18-H01-r1`.
- Semantic owner: `_18_DirMode=1 = FAITHFUL_MOMENTUM_JOIN`; `_18_Direction=1`.
- Mode2 remains `ALTERNATE_REVERSION_HYPOTHESIS_ONLY` and was not run.
- Historical Lane-A performance was not used as H01 selection or validation evidence.
- Standing historical status remains `DEAD-OPTIMIZED / NOT-DEPLOY` and is not superseded by H01.
- Prospective contract: `docs/factory/B18_H01_PROSPECTIVE_REGISTRATION_CONTRACT.md`.
- Registration commit: `a016faa9bc0f02ef421d778be49a3cd57f81de52`.
- First-green package commit: `848f35f9304b62134a6995b83689ff497da822ec`.
- Reviewed/pushed prereg lineage source: `64b5fcb37cfe59e05166b18de4e567dd02c01b6d`.
- Set: 159/159 physical keys, SHA256 `67973adaf57211858f8bb615c4a73864adc03fd31e6ad0d16f6a044a8882a1c1`.
- EX5 SHA256: `f66101bc54cd167ec5fa3bcfb6b5192a326413c2c1d6cf5c256fa7dee71ec8d0`.
- Build receipt: `br-d03f750716bd4f5d8b4630d0e9d3d03b`.

## 2. Frozen tester contract

- Installation: `D:\Meta 5` for both acceptance-critical cells.
- Logical / actual symbol: `XAUUSD / XAUUSD`.
- Timeframe: `H1`; tester model: `1`.
- Deposit / leverage: `10000 USD / 1:100`.
- MAIN: `2023.01.01..2025.12.31`.
- BWD: `2020.01.01..2022.12.31`.
- Optimization: `0 / NONE`.
- HOLDOUT `2026H1`: `UNSPENT / FORBIDDEN`.

Both cells passed exact-symbol preflight, full-surface config identity, stamped build identity, leverage verification and full-window truncation checks. History quality was 98% MAIN and 99% BWD. The runner also printed an mtime-only `STALE` line because the isolated worktree checkout gave source files timestamps later than the already-stamped EX5; exact source SHA, EX5 SHA, set SHA and build receipt matched. This is retained as a harness/environment timestamp caveat, not an identity mismatch, and no outcome-seeking rerun was performed.

## 3. Evidence — aggregate

| Window | PF | Net | Trades | EqDD maximal | History quality | Active months | Baskets |
|---|---:|---:|---:|---:|---:|---:|---:|
| MAIN | 1.19 | +2347.58 | 1631 | 5.11% | 98% | 36/36 | 412 |
| BWD | 0.98 | -154.55 | 1583 | 7.82% | 99% | 36/36 | 391 |

The EA was long-only in both reports: MAIN 1631 long / 0 short; BWD 1583 long / 0 short.

## 4. Evidence — calendar-year split

| Window | Year | PF | Net | Trades | Closed-deal balance-DD proxy |
|---|---:|---:|---:|---:|---:|
| MAIN | 2023 | 0.9319 | -213.77 | 613 | 5.3222% |
| MAIN | 2024 | 1.2439 | +844.82 | 542 | 2.5322% |
| MAIN | 2025 | 1.2891 | +1716.53 | 476 | 4.8202% |
| BWD | 2020 | 1.0175 | +55.05 | 445 | 3.6955% |
| BWD | 2021 | 0.9831 | -48.30 | 540 | 2.9101% |
| BWD | 2022 | 0.9515 | -161.30 | 598 | 7.4377% |

The yearly DD column is explicitly a closed-deal balance proxy reconstructed by `scripts/report_year_split.py`; it is not native floating-equity DD. Native aggregate equity DD remains the MT5 report field in section 3.

## 5. Evidence — grid / exposure

- Chassis: `STACK_GRID_AGAINST (92)`; configured `_9_MaxLevels=5`.
- Spacing: `_9_StepUseATR=true`, `_9_StepATRmult=1.0`; ATR is recomputed for each add decision, so a single static total grid span in ATR is not claimed (`UNAVAILABLE_DYNAMIC_ATR`).
- First lot: fixed `0.01`; lot progression `PROG_NONE (50)`.
- Configured lot ladder L0..L4: `0.01 / 0.01 / 0.01 / 0.01 / 0.01`; configured five-level aggregate = `0.05` lots; `RC_MaxLot=0.2`.
- Observed MAIN: max 3 simultaneous positions, max 0.03 lots, max observed level L2; entry counts L0/L1/L2 = 412/959/260.
- Observed BWD: max 3 simultaneous positions, max 0.03 lots, max observed level L2; entry counts L0/L1/L2 = 391/969/223.
- Both windows ended flat with zero active positions / zero active lots.

## 6. Evidence — exit / risk surface

- Exit mode `22 = EXIT_ATR_TP`; `_22_TP_ATRmult=3.0`.
- Stop mode `33 = SL_ATR`; `_33_SL_ATRmult=2.0`; adaptive SL is off.
- `ProtectLevel=2` is frozen as part of the baseline; this report does not reinterpret that selector into a new risk policy.
- `RC_AcctDDLimitPct=0.0`; `RC_MaxLevelsOverride=0`; `RC_PersistHalt=true`; `RC_AdoptLegacyHalt=false`.
- No hard-kill/truncation event was observed: both tester reports traded through the intended end of window.

## 7. R1 visual pack

1. PF Symbol x TF heatmap: `factory/runs/b18_h01_20260903/visuals/pf_symbol_tf_heatmap.svg`.
2. Participation heatmap: `factory/runs/b18_h01_20260903/visuals/participation_heatmap.svg`.
3. PF vs participation scatter: `factory/runs/b18_h01_20260903/visuals/pf_vs_participation.svg`.
4. Equity-DD window scatter: `factory/runs/b18_h01_20260903/visuals/dd_window_scatter.svg`.

Because H01 contains one frozen Symbol x TF identity, the heatmaps are intentionally one-cell MAIN/BWD panels rather than pretending a broader cross-sectional surface exists.

## 8. Interpretation

The current frozen Mode1 baseline shows a positive MAIN aggregate but does not reproduce profitability in the preceding BWD window. MAIN itself contains one losing calendar year (2023), while BWD contains two losing years (2021-2022). Participation is not sparse: both windows are active in all 36 calendar months and contain hundreds of flat-to-flat baskets.

R1 classification is therefore `ISOLATED_PULSE`: there is current-window positive evidence, but no cross-window cluster or robustness claim. This classification is a research presentation label only; it is not a Candidate/Grade/promotion verdict and does not override the standing historical `DEAD-OPTIMIZED / NOT-DEPLOY` status.

## 9. Decision / routing

- Mechanical acceptance: `PASS` (2/2 eligible cells).
- H01 research result: `R1 ISOLATED_PULSE / MIXED MAIN-BWD EVIDENCE`.
- Historical production/port status: unchanged `DEAD-OPTIMIZED / NOT-DEPLOY`.
- `QUALITY_GRADE = UNRATIFIED`; no numeric A/B/C/D mapping is invented.
- HOLDOUT remains `UNSPENT`; optimization remains `NONE`; Model4/MC were not run and are not unlocked.
- No H02, Mode2, optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, risk/default, KINT or Grade work is automatically opened.
- Routing: `STOP_EXPANSION_NO_DIRECT_CONSUMER`.
- `NEXT_ADMISSIBLE_QUESTION = NONE_FROM_H01`; any new experiment requires a distinct unresolved mechanism question and direct consumer.

## 10. Durable evidence package

Package root: `factory/runs/b18_h01_20260903/`.
Machine summary: `summary.json`; calendar split: `year_split.csv`; exposure: `exposure_summary.json`; run receipts: `run_receipts.jsonl`; mechanical gate: `mechanical_acceptance.json`.
Raw source-bound tester evidence is preserved under `MAIN/` and `BWD/`, together with leverage/truncation sidecars and exact tester INI files.
Package integrity manifest: `report_package_manifest.json`, SHA256 `02475fb3b7082166ef72d8840d4e6ce09bae20aeac02d498a75e053e16384b75`, 23 declared artifacts.

Evidence, interpretation and routing above are intentionally separate. A valid negative BWD result is retained as evidence and was not used as a search surface.
