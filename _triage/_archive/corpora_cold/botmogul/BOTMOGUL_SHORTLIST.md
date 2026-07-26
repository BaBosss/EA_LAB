# BOTMOGUL_SHORTLIST — ORDER-091B phase 1 (parse+rank, no backtests, no verdicts)

Source: `_triage\BOTMOGUL_CLAIMS.csv`, 711 BOT MOGUL Bundles html reports (type=html, scan_folder='BOT MOGUL Bundles').
Parse status: ok=711, partial=0, fail=0 (of 711).
X-ray join hits (ea_id/expert_name vs FXDREEMA_XRAY.csv name): 2/711 (expected low — most BOT MOGUL entries are .ex4/.ex5-only, no matching source).

**All numbers below are vendor CLAIMS from the vendor's own MT4/MT5 Strategy Tester report. Not verified. Do not treat as pass/fail — memory `wobr-botranking`: this corpus lineage ranks adverse-selected/overfit results. Phase 2 (BWD spot-kill on our own data) is required before any verdict.**

## Window distribution (cherry-pick measure)

| bucket | count | % of 711 |
|---|---|---|
| <=1yr (single-year) | 711 | 100.0% |
| 1-2yr | 0 | 0.0% |
| >=2yr | 0 | 0.0% |

**Headline: 100.0% of the 711-report bundle is tested on <2 years of data (single-year or 1-2yr window) — the majority is single-year/short-window cherry-pick territory, per the ORDER-091A spot-check hypothesis.**

## Top-30 by claimed Profit Factor — RESTRICTED to window_years >= 2

(Single-year / 1-2yr reports are excluded from this ranking on principle — listed separately below. `structural_red_flag` is visible, NOT a filter: flagged rows stay in the table so the judge sees them.)

| # | ea_id | symbol | TF | PF | bal_dd% | eq_dd% | trades | window | years | red_flag | note |
|---|---|---|---|---|---|---|---|---|---|---|---|
| - | (none) | - | - | - | - | - | - | - | - | - | no reports with window_years>=2 parsed successfully |

## Single-year / short-window reports (top-15 by claimed PF — NOT in the main ranking)

| # | ea_id | symbol | TF | PF | bal_dd% | eq_dd% | trades | window | years | red_flag |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 202.5.3 | TRUE | H1 | 761.49 | 0.15 | 11.08 | 1 | 2024.01.01-2024.12.31 | 0.999 | MARTINGALE;NO_SL |
| 2 | 202.3.3 | TRUE | H1 | 760.33 | 0.15 | 11.08 | 1 | 2024.01.01-2024.12.31 | 0.999 | MARTINGALE;NO_SL |
| 3 | 202.4.3 | TRUE | H1 | 760.33 | 0.15 | 11.08 | 1 | 2024.01.01-2024.12.31 | 0.999 | NO_SL |
| 4 | 202.2.3 | TRUE | H1 | 759.15 | 0.15 | 11.02 | 1 | 2024.01.01-2024.12.31 | 0.999 | NO_SL |
| 5 | 204.3.3 | TRUE | H1 | 752.48 | 0.15 | 10.91 | 1 | 2024.01.01-2024.12.31 | 0.999 | MARTINGALE;NO_SL |
| 6 | 203.5.4 | TRUE | H1 | 747.93 | 0.15 | 11.11 | 1 | 2024.01.01-2024.12.31 | 0.999 | MARTINGALE;NO_SL |
| 7 | 203.2.3 | TRUE | H1 | 747.66 | 0.15 | 11.11 | 1 | 2024.01.01-2024.12.31 | 0.999 | MARTINGALE;NO_SL |
| 8 | 204.4.3 | TRUE | H1 | 747.62 | 0.15 | 11.00 | 1 | 2024.01.01-2024.12.31 | 0.999 | NO_SL |
| 9 | 204.2.3 | TRUE | H1 | 747.54 | 0.15 | 11.07 | 1 | 2024.01.01-2024.12.31 | 0.999 | NO_SL |
| 10 | 202.2.4 | TRUE | H1 | 747.32 | 0.15 | 11.07 | 1 | 2024.01.01-2024.12.31 | 0.999 | MARTINGALE;NO_SL |
| 11 | 204.4.4 | TRUE | H1 | 747.27 | 0.15 | 11.04 | 1 | 2024.01.01-2024.12.31 | 0.999 | NO_SL |
| 12 | 202.5.4 | TRUE | H1 | 745.81 | 0.15 | 11.01 | 1 | 2024.01.01-2024.12.31 | 0.999 | MARTINGALE;NO_SL |
| 13 | 203.3.3 | TRUE | H1 | 745.55 | 0.15 | 10.98 | 1 | 2024.01.01-2024.12.31 | 0.999 | MARTINGALE;NO_SL |
| 14 | 203.4.3 | TRUE | H1 | 744.81 | 0.15 | 11.09 | 1 | 2024.01.01-2024.12.31 | 0.999 | NO_SL |
| 15 | 202.4.4 | TRUE | H1 | 744.25 | 0.14 | 10.88 | 1 | 2024.01.01-2024.12.31 | 0.999 | MARTINGALE;NO_SL |

## Parse failures

0 rows failed to parse essential fields (symbol/period/net_profit/profit_factor/total_trades). ea_id + reason:

(none)
