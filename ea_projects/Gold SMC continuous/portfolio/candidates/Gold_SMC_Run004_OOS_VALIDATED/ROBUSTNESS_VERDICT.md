# Gold SMC Continuous (XAU H1) — Run004 RiskCapV1 · Full Pipeline Verdict

> Produced 2026-06-14 by the automated pipeline (parse → score → OOS compare →
> Monte Carlo). All numbers come from real MT5 reports in this folder. This is
> the first EA taken through the complete IS → OOS → robustness loop.

## Inputs (real report files)
- IS single test: `single_test/run_004_ReportTester-146237.html`
- OOS/forward:    `forward_test/forward_ReportTester-146237.html`
- Deals (extracted): `single_test/run_004_trades.csv` (479 trades, net 7,497.37, win 82%)

## 1. In-Sample backtest (2025.01–2026.06, XAU H1)
| PF | DD% | RF | Trades | ExpPayoff | NetProfit |
|---:|---:|---:|---:|---:|---:|
| 1.31 | 12.38 | 3.22 | 479 | 15.65 | 7,497.37 |

- One-big-trade check: largest win 513.48 / net 7,497 = **6.8%** → NOT one-trade dependent ✓
- **BacktestScore v1 ≈ 70/100 → Tier B (usable)** · VERDICT = **PASS**
  (PF 16.1 + DD 13.1 + RF 17.5 + Trades 10 + EP 9 + Monthly 5*) *monthly placeholder

## 2. Out-of-Sample (forward) — degradation check
| Metric | IS | OOS | Rule | OK? |
|---|---:|---:|---|---|
| PF | 1.31 | 1.11 | OOS PF > 1.05 | ✅ |
| DD% | 12.38 | 17.45 | DD ≤ 20 | ✅ |
| RF | 3.22 | 1.34 | RF ≥ 1.0 | ✅ |
| Trades | 479 | 596 | enough | ✅ |

→ **OOS HOLDS (conservative).** Edge degrades as expected but stays positive and within DD limit = robustness is real, not overfit. (Note: OOS must be judged on degradation, not the IS BacktestScore scale.)

## 3. Monte Carlo robustness (1,000 perms, deposit 10,000, ruin@50% DD)
| | observed | shuffle 95th | bootstrap 5th/95th |
|---|---:|---:|---:|
| PF | 1.31 | — | **1.02** / 1.72 (median 1.32) |
| DD% | 12.24 | 29.84 | — / **40.35** |
| Prob of ruin | — | 0.0% | **1.8%** |

- Sequence (shuffle) risk OK: DD 95th 29.8% < 50%, ruin 0%.
- Resampling: edge holds (median PF 1.32) but **5th-pct PF 1.02** = thin in adverse runs; **DD 95th 40%**.
- **Confirms the "backtest DD ×2–3 live" rule empirically** (12% → 30–40%).

## 4. Overall verdict
**Classification: CONDITIONALLY ROBUST → eligible for PORTFOLIO_TEST / DEMO.**
- OverfitRisk = **MEDIUM** (OOS holds, but bootstrap PF 5th near breakeven + DD 95th 40%).
- Final decision (gate matrix): Backtest PASS · Robustness WARN · Stress(MC) PASS · Forward NOT_STARTED → **PORTFOLIO_TEST / DEMO_READY**, **NOT yet LIVE_READY**.

## 5. If deployed (sizing implication)
- Plan for **worst-case live DD ~40%** → size so 40% DD is survivable; set DD kill-switch accordingly.
- Conservative edge (PF ~1.1–1.3 live) → only meaningful inside a **portfolio of uncorrelated EAs**, not solo.

## 6. Next steps for this EA
1. Demo ≥3 months (live-like broker) → ForwardDemoScore.
2. Correlation vs Pivot NZDUSD & EX197 GBPJPY before assigning to a port.
3. (pipeline TODO) fix parser comma-truncation so net_profit/one-big-trade auto-compute; add monthly distribution to scoring.
