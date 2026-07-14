# ORDER-098-B MACD Divergence Optimization Summary

Tester mode: MT5 Model 1, 2023-01-01 to 2026-01-01, fixed lot 0.01.
Optimizer: fast genetic, coarse ranges in `_mt5_auto/ab_sets/order098b/MacdDiv_Naked_coarse_opt.set`.

## Full-window confirmed top PF sets

| Symbol | TF | PF | Net | Trades | DD% | Win% | RF | Sharpe | Set |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| EURUSD | H1 | 1.17 | 123.89 | 713 | 0.42 | 32.82 | 2.92 | 1.17 | `MacdDiv_Naked_EURUSD_H1_optPF.set` |
| EURUSD | H4 | 1.71 | 227.50 | 272 | 0.58 | 36.76 | 3.93 | 2.57 | `MacdDiv_Naked_EURUSD_H4_optPF.set` |
| XAUUSD | H1 | 1.09 | 455.96 | 1053 | 5.91 | 33.05 | 0.73 | 0.65 | `MacdDiv_Naked_XAUUSD_H1_optPF.set` |
| XAUUSD | H4 | 1.91 | 1635.80 | 280 | 3.03 | 38.57 | 4.99 | 2.70 | `MacdDiv_Naked_XAUUSD_H4_optPF.set` |

## Year split

| Symbol | TF | Year | PF | Net | Trades | DD% | Win% | RF | Sharpe |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| EURUSD | H1 | 2023 | 1.14 | 37.78 | 270 | 0.36 | 32.96 | 1.05 | 1.22 |
| EURUSD | H1 | 2024 | 1.09 | 19.02 | 231 | 0.28 | 34.20 | 0.67 | 0.67 |
| EURUSD | H1 | 2025 | 1.22 | 54.81 | 219 | 0.39 | 31.05 | 1.38 | 1.33 |
| EURUSD | H4 | 2023 | 1.03 | 4.36 | 123 | 0.58 | 33.33 | 0.08 | 0.19 |
| EURUSD | H4 | 2024 | 1.74 | 64.50 | 80 | 0.21 | 40.00 | 3.00 | 3.10 |
| EURUSD | H4 | 2025 | 2.55 | 147.97 | 69 | 0.30 | 39.13 | 5.00 | 3.53 |
| XAUUSD | H1 | 2023 | 1.42 | 346.68 | 280 | 1.53 | 33.93 | 2.19 | 2.27 |
| XAUUSD | H1 | 2024 | 1.01 | 15.14 | 374 | 2.98 | 33.69 | 0.05 | 0.11 |
| XAUUSD | H1 | 2025 | 1.05 | 137.34 | 398 | 6.00 | 32.41 | 0.22 | 0.40 |
| XAUUSD | H4 | 2023 | 1.80 | 347.71 | 104 | 1.14 | 42.31 | 3.06 | 3.34 |
| XAUUSD | H4 | 2024 | 1.86 | 424.99 | 71 | 1.37 | 40.85 | 3.04 | 2.47 |
| XAUUSD | H4 | 2025 | 1.99 | 865.58 | 106 | 3.26 | 33.02 | 2.64 | 2.94 |

Raw CSV artifacts:

- `_mt5_auto/order098b_macddiv_opt_top20.csv`
- `_mt5_auto/order098b_macddiv_confirm.csv`
- `_mt5_auto/order098b_macddiv_yearsplit.csv`
