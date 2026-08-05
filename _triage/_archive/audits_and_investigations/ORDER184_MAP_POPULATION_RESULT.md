# ORDER-184: backtest_corr_reports.csv population — result

Date: 2026-07-23

## Summary

- Target list (DEPLOYMENTS.csv status ACTIVE/PENDING_ATTACH ∩ expectations.csv numeric dd95_expected): **28 magics**.
- Rows added to `portfolio/backtest_corr_reports.csv`: **27**.
- Magics skipped (no verifiable report): **1** (991001 — see below).
- `--selftest`: **ALL PASS** (30/30).
- `corr_coverage.backtest_skipped`: **empty** `[]`.
- `corr_coverage.measured_pairs_backtest`: **338**.

## Mapping table

| magic | ea_name | symbol | report_path | header evidence (Expert / Symbol / Period found) |
|---|---|---|---|---|
| 990101 | (Boss)_ZeusInspired_GridLog | XAUUSD | `_mt5_auto/reports/ORDER166_990101_ZIGL_XAU.htm` | Expert `(Boss)_ZeusInspired_GridLog_rev01` (rev-suffix = same EA) · Symbol `XAUUSD` · Period `H1 (2020.01.01 - 2026.07.01)` — continuous full-span convention, extends past MAIN both ends incl. 2026H1 holdout, no MAIN-only report exists. Config confirmed vs `_demo_deploy/MT5/ZeusInspired_XAUUSD_H1_demo.set` (SlAtrMult=4.0/SlMaxPips=10000/DistAtrMult=1/AtrPeriod=14). |
| 991004 | (BRK)_SqueezeBreakout | XAUUSD | `_mt5_auto/reports/CORR_SQZ_XAU_MAIN.htm` | Expert shown as `corrSqueeze` (renamed compile of `(BRK)_SqueezeBreakout_rev01` for a correlation-testing batch — confirmed via `.mq5` source, same BbPeriod/KcPeriod/RangeBars inputs) · Symbol `XAUUSD` · Magic=991004 in header · Period `H4 (2023.01.01 - 2026.07.01)`. Config RangeBars=60/KcAtrMult=2.0/SlAtrMult=1.0/TpAtrMult=5.0 matches `_demo_deploy/MT5/SqueezeBreakout_XAU_demo.set` exactly. |
| 991002 | (BRK)_TrendlineBreakout | XAUUSD | `_mt5_auto/reports/CORR_TL_XAU_MAIN.htm` | Expert shown as `corrTrend` (renamed compile of `(BRK)_TrendlineBreakout_rev01/02`, same batch as CORR_SQZ) · Symbol `XAUUSD` · Magic=991002 in header · Period `H4 (2023.01.01 - 2026.07.01)`. Config RequireConverge=true/SlAtrMult=1.5/TpAtrMult=8.0/BufferAtrMult=0.10 matches `_demo_deploy/MT5/TrendlineBreakout_XAU_demo.set` exactly. |
| 990201 | Boss_14_GridLog | USDJPYm | `_mt5_auto/reports/O166_B14_USDJPY_M4.htm` | Expert `Boss_14_GridLog` · Symbol `USDJPY` · Period `H1 (2023.01.01 - 2025.12.31)` = exact MAIN window. Fresh full-pin batch (mtime 2026-07-23). |
| 990202 | Boss_14_GridLog | AUDNZDm | `_mt5_auto/reports/O166_B14_AUDNZD_M4.htm` | Expert `Boss_14_GridLog` · Symbol `AUDNZD` · Period `H1 (2023.01.01 - 2025.12.31)` = exact MAIN window. |
| 990203 | Boss_14_GridLog size-light | EURJPYm | `_mt5_auto/reports/O166_B14_EURJPY_M4_solo.htm` | Expert `Boss_14_GridLog` · Symbol `EURJPY` · Period `H1 (2023.01.01 - 2025.12.31)` = exact MAIN window (solo re-run, batch hit known 0-trade transient). |
| 990204 | Boss_14_GridLog | AUDCADm | `_mt5_auto/reports/O166_B14_AUDCAD_M4.htm` | Expert `Boss_14_GridLog` · Symbol `AUDCAD` · Period `H1 (2023.01.01 - 2025.12.31)` = exact MAIN window. |
| 990205 | Boss_14_GridLog size-light thin | CADJPYm | `_mt5_auto/reports/O166_B14_CADJPY_M4.htm` | Expert `Boss_14_GridLog` · Symbol `CADJPY` · Period `H1 (2023.01.01 - 2025.12.31)` = exact MAIN window. |
| 990206 | Boss_14_GridLog SELL | EURUSDm | `_mt5_auto/reports/O166_B14_EURUSD_M4.htm` | Expert `Boss_14_GridLog` · Symbol `EURUSD` · Period `H1 (2023.01.01 - 2025.12.31)` = exact MAIN window. |
| 990207 | Boss_14_GridLog | XAUUSDm | `_mt5_auto/reports/O166_B14_XAU_M4.htm` | Expert `Boss_14_GridLog` · Symbol `XAUUSD` · Period `H1 (2023.01.01 - 2025.12.31)` = exact MAIN window. |
| 990301 | Boss_17_Wave5 | XAUUSDm | `_mt5_auto/reports/ORDER166_990301_W5XAU_MAIN.htm` | Expert `Boss_17_Wave5` · Symbol `XAUUSD` · Period `H1 (2023.01.01 - 2026.07.01)` — continuous-span convention for this EA family (all Wave5-XAU reports in repo use this span, per ORDER-182: fixed WFA windowing ruled invalid for this basket EA). |
| 990302 | Boss_17_Wave5 | XAGUSDm | `_mt5_auto/reports/ORDER166_990302_W5XAG_MAIN.htm` | Expert `Boss_17_Wave5` · Symbol `XAGUSD` · Period `H1 (2023.01.01 - 2026.07.01)` — same convention as 990301. |
| 991003 | EA_BREAKOUT_XAU | USDJPYm | `_mt5_auto/reports/O159_991003_BRKXAU_USDJPY_MAIN.htm` | Expert `EA_BREAKOUT_XAU` · Symbol `USDJPY` · Magic=991003 · Period `H4 (2023.01.01 - 2025.12.31)` = exact MAIN window. |
| 991005 | EA_BREAKOUT_XAU | US30m | `_mt5_auto/reports/O159_991005_BRKXAU_US30_MAIN.htm` | Expert `EA_BREAKOUT_XAU` · Symbol `US30` · Magic=991005 · Period `H4 (2023.01.01 - 2025.12.31)` = exact MAIN window. |
| 999094 | MacdDiv_Naked | XAUUSDm | `_mt5_auto/reports/MacdDiv_XAUH4_M4_MAIN_2023_2025.htm` | Expert `MacdDiv_Naked` · Symbol `XAUUSD` · Period `H4 (2023.01.01 - 2025.12.31)` = exact MAIN window (filename itself states 2023_2025; preferred over the newer `ON_MacdDiv_XAUUSD_MAIN.htm` which extends to 2026.07.01). |
| 991070 | EmaStoRev | EURUSDm | `_mt5_auto/reports/O159_991070_EMASTOREV_EURUSD_MAIN.htm` | Expert `EmaStoRev` · Symbol `EURUSD` · Magic=991070 · Period `H1 (2023.01.01 - 2025.12.31)` = exact MAIN window. SlAtrMult=3.0/StoK=13 matches locked SL≥3.0 config. |
| 990066 | (EXP)_IchiADX_Naked_rev00 | USDJPYm | `_mt5_auto/reports/BASKET_medH4_FULL.htm` | Expert `(EXP)_IchiADX_Naked_rev00` · Symbol `USDJPY` · TenkanPeriod=12/KijunPeriod=34/SenkouPeriod=68 (matches basket-A H4-med) · Period `H4 (2020.01.01 - 2026.07.01)` — continuous full-span, no MAIN-only report found. Basket combined dd95 not per-leg separable; best available single-leg report for the primary magic. |
| 990068 | (EXP)_IchiADX_Naked_rev00 | XAUUSDm | `_mt5_auto/reports/CORR_ICHI_XAU.htm` | Expert `(EXP)_IchiADX_Naked_rev00` · Symbol `XAUUSD` · TenkanPeriod=20/KijunPeriod=60/SenkouPeriod=120 (matches basket-A H1-slow) · Period `H1 (2020.01.01 - 2026.07.01)` — continuous full-span. Same basket caveat as 990066. |
| 990020 | EA_SUPERTREND | XAUUSDm | `_mt5_auto/reports/ST_XAU_H4_M0_FULL.htm` | Expert `EA_SUPERTREND` · Symbol `XAUUSD` · Period `H4 (2023.01.01 - 2026.07.01)` — starts exactly at MAIN start, extends 7mo past MAIN end into holdout; no MAIN-only report found. Config ATRperiod=10/Multiplier=3.0/SL_ATR_mult=2.0 matches `_vps_deploy/EA_SUPERTREND_XAU/ST_XAUUSD_H4_demo_v1.set` exactly. |
| 990110 | (Boss)_ZeusInspired_GridLog | AUDJPYm | `_mt5_auto/reports/ORDER166_990110_ZEUS_AUDJPY_MAIN.htm` | Expert `(Boss)_ZeusInspired_GridLog_rev01` · Symbol `AUDJPY` · Period `H1 (2023.01.01 - 2026.07.01)` — continuous-span convention, extends past MAIN into holdout. Regime-gate AllowRange=true/AllowTrendUp=false/AllowTrendDown=false matches deployed range-only config. |
| 990208 | Boss_14_GridLog | GBPJPYm | `_mt5_auto/reports/O166_B14_GBPJPY_M4_solo.htm` | Expert `Boss_14_GridLog` · Symbol `GBPJPY` · Period `H1 (2023.01.01 - 2025.12.31)` = exact MAIN window (solo re-run). |
| 990303 | Boss_17_Wave5 | USDJPYm | `_mt5_auto/reports/ORDER166_990303_W5USDJPY_MAIN.htm` | Expert `Boss_17_Wave5` · Symbol `USDJPY` · Period `H1 (2023.01.01 - 2026.07.01)` — same continuous-span convention as 990301/990302. |
| 990984 | PairSpread_StatArb | EURUSDm | `_mt5_auto/reports/O098G_x03_MAIN.htm` | Expert `PairSpread_StatArb` · Symbol `EURUSD` (leg-A of EURUSD/GBPUSD) · Magic=990984 · Period `H4 (2023.01.01 - 2026.01.01)` — effectively MAIN (1-day tester end-boundary past 2025.12.31, not real holdout overlap). ZWindow=100/EntryZ=2.5/ExitZ=0.3/StopZ=3.5 matches the locked config exactly. |
| 990120 | Boss_12_Breakout (MacroGate leg) | USDJPYm | `_mt5_auto/reports/ORDER167_990120_MacroGate_GLOBALFIX.htm` | Expert `Boss_12_Breakout` · Symbol `USDJPY` · Period `H1 (2024.01.01 - 2024.12.31)` — **NOT** the 3yr MAIN window; single calendar-year 2024 in-sample only, a known documented limitation (no MAIN/BWD/holdout MacroGate report exists yet). Verified-gated reproduction from ORDER-171, not the stale-CSV-bug ungated file in the same folder. |
| 990025 | EA_SUPERTREND (crypto ST-BTC) | BTCUSD | `_mt5_auto/reports/O159_990025_STBTC_MAIN.htm` | Expert `EA_SUPERTREND` · Symbol `BTCUSD` · Magic=990025 · Period `H4 (2023.01.01 - 2025.12.31)` = exact MAIN window. Deployed `_vps_deploy/CRYPTO_TRENDRIDER/ST_BTC_deploy.set` used as-is. |
| 990030 | EA_DONCHIAN (crypto DON-ETH pyr3) | ETHUSD | `_mt5_auto/reports/AB_DON_ETH_PYR3_IS.htm` | Expert `EA_DONCHIAN` · Symbol `ETHUSD` · Magic=990030 · Period `H4 (2023.01.01 - 2026.01.01)` — effectively MAIN (1-day boundary). DonchPeriod=35/ATRPeriod=10/SL_ATR_mult=2.25/MaxPyramid=3 matches `_vps_deploy/CRYPTO_TRENDRIDER/DON_ETH_deploy.set` exactly. |
| 992004 | TrendRider_XAU (W2 S1) | XAUUSD | `_mt5_auto/reports/W2_S1_TrendRider_MAIN.htm` | Expert `TrendRider_XAU` · Symbol `XAUUSD` · Period `H4 (2023.01.01 - 2025.12.31)` = exact MAIN window. EmaFast=50/EmaSlow=200 consistent with ORDER-139 locked plateau-center config. |

## Magics that could NOT be mapped

| magic | ea_name | symbol | reason |
|---|---|---|---|
| 991001 | EA_BREAKOUT_XAU (home leg) | XAUUSD | Initially mapped to `SMOKE_BRK_XAU_H4.htm` (Expert/Symbol/Magic/config all matched the compiled defaults — BreakoutBars=40/SlAtrMult=1.5/TpAtrMult=5.0/EmaPeriod=200). **Rejected after running the admission script**: this file turned out to be a degenerate 0-trade tester artifact (Deals=0, file only 13KB vs 100KB+ for populated reports) — the script correctly flagged it via `backtest_skipped: ["991001: no realized 'out' deals parsed..."]`. The only other candidate, `CORR_BRK_XAU.htm`, uses a different, non-deployed parameter set (BreakoutBars=55/TpAtrMult=8.0/EmaPeriod=150 vs the deployed Bars40/TpAtr5.0/Ema200) so was not a safe substitute. No other report in `_mt5_auto/reports/` has Expert=EA_BREAKOUT_XAU + Symbol=XAUUSD + Magic=991001 + a non-empty deal history and matching config. **Row removed from the CSV; magic falls back to the conservative corr=1.0 default**, per task instructions ("a missing row is safe"). |

## selftest output (exact)

```
PASS  1_golden_sample
PASS  2_bounds_assert
PASS  3_missing_corr_defaults_to_one
PASS  4_lot_factor_bounds
PASS  5_parser_rejects_every_unknown_form
PASS  6_expectations_file_absent
PASS  7_basket_counted_once
PASS  8_corrupt_pnl_does_not_become_zero
PASS  9_admit_bounds_guard_on_existing
PASS  10_broker_min_fails_closed
PASS  11_rounded_factor_within_budget
PASS  12_admission_path_collapses_baskets
PASS  13_basket_id_magic_namespace_separation
PASS  14_emitted_reduced_respects_lower_bound
PASS  15_formula_guard_mutation_protection
PASS  16_nonfinite_pnl_poisons_magic_end_to_end
PASS  17_admission_validates_own_inputs
PASS  18_safe_output_path_guard
PASS  19_basketed_candidate_same_identity
PASS  20_overflowing_pnl_poisons_magic
PASS  21_extreme_finite_inputs_fail_closed
PASS  22_multiple_pending_decisions_compose
PASS  23_pearson_overflow_is_unmeasurable
PASS  24_exact_budget_defers_not_refuses
PASS  25_conflicting_siblings_canonical_dd95
PASS  26_pearson_result_stays_in_range
PASS  27_strict_budget_and_type_conflict
PASS  28_backtest_corr_provenance
PASS  29_backtest_map_fail_soft_hardening
PASS  30_malformed_report_rows_poison
ALL PASS
```

## Final corr_coverage block (from `_triage/ORDER154_RISK_ADMISSION_CURRENT_STATE.json`, after removing the 991001 row)

```json
{
  "backtest_map_found": true,
  "backtest_map_path": "D:\\EA_LAB\\portfolio\\backtest_corr_reports.csv",
  "backtest_skipped": [],
  "measured_pairs": 338,
  "measured_pairs_backtest": 338,
  "measured_pairs_live": 0,
  "default_1_0_pairs": 608,
  "possible_pairs_active_or_pending": 946,
  "note": "every pair NOT listed above used the conservative default corr=1.0 (fully additive); live pairs outrank backtest pairs when both exist"
}
```

## Notes / caveats for the lead (not interpreting values, just flagging provenance)

- Several rows (990101, 990110, 990301, 990302, 990303, 990020, 990066, 990068) use a **continuous-span window** (starting 2020 or 2023, ending 2026.07.01) rather than the strict MAIN 2023.01–2025.12 window, because no MAIN-only report exists for these EAs in `_mt5_auto/reports/` — this appears to be a deliberate repo convention for several grid/DCA/basket EA families (see commit `3242a914` ORDER-182 continuous-span note). These spans include part of the 2026H1 holdout period. This is disclosed per-row in the CSV `notes` column.
- 990120 (MacroGate) uses a single calendar-year 2024 window only — a pre-existing, documented limitation (no 3yr MAIN report exists for this EA yet).
- 990984 and 990030 report periods end on `2026.01.01` rather than `2025.12.31` — a 1-day tester end-boundary artifact, not a real holdout leak.
- 990066/990068 (IchiADX baskets) map to single-leg reports; the dd95_expected figure in `expectations.csv` for these magics is basket-combined (2-leg), not separable per-leg.
- 991004/991002 (SqueezeBreakout/TrendlineBreakout) map to reports whose "Expert" header string is a renamed compile (`corrSqueeze`/`corrTrend`) from what appears to be a dedicated correlation-testing batch — confirmed as the same EA by cross-checking `.mq5` source input names and the deployed `.set` parameter values (exact match), not by name alone.
