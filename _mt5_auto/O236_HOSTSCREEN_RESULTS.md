# ORDER-236 Host Screen Results

## PART A - GEN-STANDING Zero-Trade Re-runs

### Run 1: PivotBreakout_XAU on XAUUSD D1 (2023.01.01-2025.12.31)
- **Trades:** 0
- **PF:** 0
- **Equity DD%:** 0
- **Net Profit:** 0
- **Leverage:** 1:100
- **Refusal/Error lines in Journal/Log:** No Journal/Log section present in report. No refusal lines found.

### Run 2: PivotBreakout_XAU on XAGUSD D1 (2023.01.01-2025.12.31)
- **Trades:** 0
- **PF:** 0
- **Equity DD%:** 0
- **Net Profit:** 0
- **Leverage:** 1:100
- **Refusal/Error lines in Journal/Log:** No Journal/Log section present in report. No refusal lines found.

## PART B - CTRL-Only Host Screen (B14_AB_off.set)

| symbol | window | PF | trades | DD% | net | leverage | report path |
|---|---|---|---|---|---|---|---|
| USDJPY | MAIN | 0.97 | 274 | 13.18 | -175.04 | 1:100 | D:/EA_LAB/_mt5_auto/reports/O236_HOST_USDJPY_MAIN.htm |
| USDJPY | BWD | 1.28 | 316 | 10.14 | 1684.81 | 1:100 | D:/EA_LAB/_mt5_auto/reports/O236_HOST_USDJPY_BWD.htm |
| EURJPY | MAIN | 1.82 | 184 | 7.13 | 2344.20 | 1:100 | D:/EA_LAB/_mt5_auto/reports/O236_HOST_EURJPY_MAIN.htm |
| EURJPY | BWD | 1.06 | 498 | 16.79 | 567.24 | 1:100 | D:/EA_LAB/_mt5_auto/reports/O236_HOST_EURJPY_BWD.htm |
| CADJPY | MAIN | 1.14 | 408 | 16.94 | 1023.28 | 1:100 | D:/EA_LAB/_mt5_auto/reports/O236_HOST_CADJPY_MAIN.htm |
| CADJPY | BWD | 1.12 | 364 | 17.02 | 850.51 | 1:100 | D:/EA_LAB/_mt5_auto/reports/O236_HOST_CADJPY_BWD.htm |
| EURUSD | MAIN | 0.95 | 327 | 21.44 | -319.04 | 1:100 | D:/EA_LAB/_mt5_auto/reports/O236_HOST_EURUSD_MAIN.htm |
| EURUSD | BWD | 0.87 | 188 | 13.92 | -615.70 | 1:100 | D:/EA_LAB/_mt5_auto/reports/O236_HOST_EURUSD_BWD.htm |
| GBPJPY | MAIN | 1.35 | 334 | 12.00 | 2369.26 | 1:100 | D:/EA_LAB/_mt5_auto/reports/O236_HOST_GBPJPY_MAIN.htm |
| GBPJPY | BWD | 0.15 | 40 | 24.97 | -2490.40 | 1:100 | D:/EA_LAB/_mt5_auto/reports/O236_HOST_GBPJPY_BWD.htm |

---

## Raw Parse Output

### USDJPY MAIN
ea_name: Boss_14_GridLog
  symbol: USDJPY
  company: TF Global Markets (Aust) Pty Ltd
  period: H1
  from_date: 2023.01.01
  to_date: 2025.12.31
  initial_deposit: 10000.0
  leverage: 1:100
  quality: 100% real ticks
  history_quality: 100% real ticks
  bars: 18624.0
  ticks: 77896418.0
  symbols_count: 0
  net_profit: -175.04
  gross_profit: 6243.34
  gross_loss: -6418.38
  balance_drawdown_abs: 664.33
  equity_drawdown_abs: 793.04
  balance_drawdown_maximal_abs: 173.3
  balance_drawdown_maximal_pct: 11.16
  equity_drawdown_maximal_abs: 397.43
  equity_drawdown_maximal_pct: 13.18
  balance_drawdown_relative_pct: 11.16
  equity_drawdown_relative_pct: 13.18
  profit_factor: 0.97
  recovery_factor: -0.13
  expected_payoff: -0.64
  sharpe_ratio: -0.1
  z_score: -9.21 (99.74%)
  ahpr: 0
  ghpr: 0
  lr_correlation: -0.31
  ontester_result: 0
  margin_level: 2153.74%
  total_trades: 274.0
  total_deals: 412.0
  short_trades: 0
  short_won_pct: 0
  long_trades: 274
  long_won_pct: 63.5
  profit_trades: 174
  profit_trades_pct: 63.5
  loss_trades: 100
  loss_trades_pct: 36.5
  largest_profit_trade: 209.44
  largest_loss_trade: -129.09
  avg_profit_trade: 0
  avg_loss_trade: 0
  avg_consecutive_wins: 0
  avg_consecutive_losses: 0
  max_consecutive_wins: 0
  max_consecutive_losses: 0

### USDJPY BWD
ea_name: Boss_14_GridLog
  symbol: USDJPY
  company: TF Global Markets (Aust) Pty Ltd
  period: H1
  from_date: 2020.01.01
  to_date: 2022.12.31
  initial_deposit: 10000.0
  leverage: 1:100
  quality: 99% real ticks
  history_quality: 99% real ticks
  bars: 18696.0
  ticks: 62246579.0
  symbols_count: 0
  net_profit: 1684.81
  gross_profit: 7608.71
  gross_loss: -5923.9
  balance_drawdown_abs: 790.74
  equity_drawdown_abs: 797.07
  balance_drawdown_maximal_abs: 114.81
  balance_drawdown_maximal_pct: 9.27
  equity_drawdown_maximal_abs: 224.62
  equity_drawdown_maximal_pct: 10.14
  balance_drawdown_relative_pct: 9.62
  equity_drawdown_relative_pct: 10.14
  profit_factor: 1.28
  recovery_factor: 1.38
  expected_payoff: 5.33
  sharpe_ratio: 0.75
  z_score: -8.89 (99.74%)
  ahpr: 0
  ghpr: 0
  lr_correlation: 0.86
  ontester_result: 0
  margin_level: 2516.03%
  total_trades: 316.0
  total_deals: 467.0
  short_trades: 0
  short_won_pct: 0
  long_trades: 316
  long_won_pct: 65.51
  profit_trades: 207
  profit_trades_pct: 65.51
  loss_trades: 109
  loss_trades_pct: 34.49
  largest_profit_trade: 182.96
  largest_loss_trade: -139.49
  avg_profit_trade: 0
  avg_loss_trade: 0
  avg_consecutive_wins: 0
  avg_consecutive_losses: 0
  max_consecutive_wins: 0
  max_consecutive_losses: 0

### EURJPY MAIN
ea_name: Boss_14_GridLog
  symbol: EURJPY
  company: TF Global Markets (Aust) Pty Ltd
  period: H1
  from_date: 2023.01.01
  to_date: 2025.12.31
  initial_deposit: 10000.0
  leverage: 1:100
  quality: 100% real ticks
  history_quality: 100% real ticks
  bars: 18624.0
  ticks: 125539367.0
  symbols_count: 0
  net_profit: 2344.2
  gross_profit: 5214.67
  gross_loss: -2870.47
  balance_drawdown_abs: 81.99
  equity_drawdown_abs: 117.41
  balance_drawdown_maximal_abs: 629.23
  balance_drawdown_maximal_pct: 5.43
  equity_drawdown_maximal_abs: 836.14
  equity_drawdown_maximal_pct: 7.13
  balance_drawdown_relative_pct: 5.43
  equity_drawdown_relative_pct: 7.13
  profit_factor: 1.82
  recovery_factor: 2.8
  expected_payoff: 12.74
  sharpe_ratio: 1.64
  z_score: -6.04 (99.74%)
  ahpr: 0
  ghpr: 0
  lr_correlation: 0.96
  ontester_result: 0
  margin_level: 2628.58%
  total_trades: 184.0
  total_deals: 268.0
  short_trades: 0
  short_won_pct: 0
  long_trades: 184
  long_won_pct: 71.74
  profit_trades: 132
  profit_trades_pct: 71.74
  loss_trades: 52
  loss_trades_pct: 28.26
  largest_profit_trade: 194.29
  largest_loss_trade: -115.6
  avg_profit_trade: 0
  avg_loss_trade: 0
  avg_consecutive_wins: 0
  avg_consecutive_losses: 0
  max_consecutive_wins: 0
  max_consecutive_losses: 0

### EURJPY BWD
ea_name: Boss_14_GridLog
  symbol: EURJPY
  company: TF Global Markets (Aust) Pty Ltd
  period: H1
  from_date: 2020.01.01
  to_date: 2022.12.31
  initial_deposit: 10000.0
  leverage: 1:100
  quality: 99% real ticks
  history_quality: 99% real ticks
  bars: 18696.0
  ticks: 90992235.0
  symbols_count: 0
  net_profit: 567.24
  gross_profit: 10670.77
  gross_loss: -10103.53
  balance_drawdown_abs: 1568.92
  equity_drawdown_abs: 1623.72
  balance_drawdown_maximal_abs: 568.92
  balance_drawdown_maximal_pct: 15.69
  equity_drawdown_maximal_abs: 689.64
  equity_drawdown_maximal_pct: 16.79
  balance_drawdown_relative_pct: 15.69
  equity_drawdown_relative_pct: 16.79
  profit_factor: 1.06
  recovery_factor: 0.34
  expected_payoff: 1.14
  sharpe_ratio: 0.16
  z_score: -9.99 (99.74%)
  ahpr: 0
  ghpr: 0
  lr_correlation: 0.83
  ontester_result: 0
  margin_level: 1670.57%
  total_trades: 498.0
  total_deals: 726.0
  short_trades: 0
  short_won_pct: 0
  long_trades: 498
  long_won_pct: 65.46
  profit_trades: 326
  profit_trades_pct: 65.46
  loss_trades: 172
  loss_trades_pct: 34.54
  largest_profit_trade: 213.89
  largest_loss_trade: -143.89
  avg_profit_trade: 0
  avg_loss_trade: 0
  avg_consecutive_wins: 0
  avg_consecutive_losses: 0
  max_consecutive_wins: 0
  max_consecutive_losses: 0

### CADJPY MAIN
ea_name: Boss_14_GridLog
  symbol: CADJPY
  company: TF Global Markets (Aust) Pty Ltd
  period: H1
  from_date: 2023.01.01
  to_date: 2025.12.31
  initial_deposit: 10000.0
  leverage: 1:100
  quality: 100% real ticks
  history_quality: 100% real ticks
  bars: 18624.0
  ticks: 108467946.0
  symbols_count: 0
  net_profit: 1023.28
  gross_profit: 8273.54
  gross_loss: -7250.26
  balance_drawdown_abs: 393.4
  equity_drawdown_abs: 429.5
  balance_drawdown_maximal_abs: 776.8
  balance_drawdown_maximal_pct: 15.57
  equity_drawdown_maximal_abs: 952.46
  equity_drawdown_maximal_pct: 16.94
  balance_drawdown_relative_pct: 15.57
  equity_drawdown_relative_pct: 16.94
  profit_factor: 1.14
  recovery_factor: 0.52
  expected_payoff: 2.51
  sharpe_ratio: 0.45
  z_score: -11.35 (99.74%)
  ahpr: 0
  ghpr: 0
  lr_correlation: 0.1
  ontester_result: 0
  margin_level: 3626.60%
  total_trades: 408.0
  total_deals: 611.0
  short_trades: 0
  short_won_pct: 0
  long_trades: 408
  long_won_pct: 64.95
  profit_trades: 265
  profit_trades_pct: 64.95
  loss_trades: 143
  loss_trades_pct: 35.05
  largest_profit_trade: 177.29
  largest_loss_trade: -109.85
  avg_profit_trade: 0
  avg_loss_trade: 0
  avg_consecutive_wins: 0
  avg_consecutive_losses: 0
  max_consecutive_wins: 0
  max_consecutive_losses: 0

### CADJPY BWD
ea_name: Boss_14_GridLog
  symbol: CADJPY
  company: TF Global Markets (Aust) Pty Ltd
  period: H1
  from_date: 2020.01.01
  to_date: 2022.12.31
  initial_deposit: 10000.0
  leverage: 1:100
  quality: 99% real ticks
  history_quality: 99% real ticks
  bars: 18696.0
  ticks: 68262465.0
  symbols_count: 0
  net_profit: 850.51
  gross_profit: 8132.53
  gross_loss: -7282.02
  balance_drawdown_abs: 1544.48
  equity_drawdown_abs: 1610.41
  balance_drawdown_maximal_abs: 569.49
  balance_drawdown_maximal_pct: 15.66
  equity_drawdown_maximal_abs: 720.76
  equity_drawdown_maximal_pct: 17.02
  balance_drawdown_relative_pct: 15.66
  equity_drawdown_relative_pct: 17.02
  profit_factor: 1.12
  recovery_factor: 0.49
  expected_payoff: 2.34
  sharpe_ratio: 0.31
  z_score: -9.23 (99.74%)
  ahpr: 0
  ghpr: 0
  lr_correlation: 0.84
  ontester_result: 0
  margin_level: 2943.55%
  total_trades: 364.0
  total_deals: 534.0
  short_trades: 0
  short_won_pct: 0
  long_trades: 364
  long_won_pct: 65.11
  profit_trades: 237
  profit_trades_pct: 65.11
  loss_trades: 127
  loss_trades_pct: 34.89
  largest_profit_trade: 202.63
  largest_loss_trade: -176.64
  avg_profit_trade: 0
  avg_loss_trade: 0
  avg_consecutive_wins: 0
  avg_consecutive_losses: 0
  max_consecutive_wins: 0
  max_consecutive_losses: 0

### EURUSD MAIN
ea_name: Boss_14_GridLog
  symbol: EURUSD
  company: TF Global Markets (Aust) Pty Ltd
  period: H1
  from_date: 2023.01.01
  to_date: 2025.12.31
  initial_deposit: 10000.0
  leverage: 1:100
  quality: 100% real ticks
  history_quality: 100% real ticks
  bars: 18624.0
  ticks: 59351286.0
  symbols_count: 0
  net_profit: -319.04
  gross_profit: 6284.0
  gross_loss: -6603.04
  balance_drawdown_abs: 1625.77
  equity_drawdown_abs: 1673.61
  balance_drawdown_maximal_abs: 201.64
  balance_drawdown_maximal_pct: 20.82
  equity_drawdown_maximal_abs: 272.18
  equity_drawdown_maximal_pct: 21.44
  balance_drawdown_relative_pct: 20.82
  equity_drawdown_relative_pct: 21.44
  profit_factor: 0.95
  recovery_factor: -0.14
  expected_payoff: -0.98
  sharpe_ratio: -0.14
  z_score: -9.02 (99.74%)
  ahpr: 0
  ghpr: 0
  lr_correlation: -0.75
  ontester_result: 0
  margin_level: 1904.36%
  total_trades: 327.0
  total_deals: 481.0
  short_trades: 0
  short_won_pct: 0
  long_trades: 327
  long_won_pct: 61.77
  profit_trades: 202
  profit_trades_pct: 61.77
  loss_trades: 125
  loss_trades_pct: 38.23
  largest_profit_trade: 194.16
  largest_loss_trade: -136.11
  avg_profit_trade: 0
  avg_loss_trade: 0
  avg_consecutive_wins: 0
  avg_consecutive_losses: 0
  max_consecutive_wins: 0
  max_consecutive_losses: 0

### EURUSD BWD
ea_name: Boss_14_GridLog
  symbol: EURUSD
  company: TF Global Markets (Aust) Pty Ltd
  period: H1
  from_date: 2020.01.01
  to_date: 2022.12.31
  initial_deposit: 10000.0
  leverage: 1:100
  quality: 99% real ticks
  history_quality: 99% real ticks
  bars: 18696.0
  ticks: 61697932.0
  symbols_count: 0
  net_profit: -615.7
  gross_profit: 4036.73
  gross_loss: -4652.43
  balance_drawdown_abs: 1161.0
  equity_drawdown_abs: 1227.24
  balance_drawdown_maximal_abs: 250.12
  balance_drawdown_maximal_pct: 12.39
  equity_drawdown_maximal_abs: 418.71
  equity_drawdown_maximal_pct: 13.92
  balance_drawdown_relative_pct: 12.39
  equity_drawdown_relative_pct: 13.92
  profit_factor: 0.87
  recovery_factor: -0.43
  expected_payoff: -3.28
  sharpe_ratio: -0.46
  z_score: -7.39 (99.74%)
  ahpr: 0
  ghpr: 0
  lr_correlation: -0.01
  ontester_result: 0
  margin_level: 1784.76%
  total_trades: 188.0
  total_deals: 285.0
  short_trades: 0
  short_won_pct: 0
  long_trades: 188
  long_won_pct: 60.64
  profit_trades: 114
  profit_trades_pct: 60.64
  loss_trades: 74
  loss_trades_pct: 39.36
  largest_profit_trade: 185.33
  largest_loss_trade: -135.74
  avg_profit_trade: 0
  avg_loss_trade: 0
  avg_consecutive_wins: 0
  avg_consecutive_losses: 0
  max_consecutive_wins: 0
  max_consecutive_losses: 0

### GBPJPY MAIN
ea_name: Boss_14_GridLog
  symbol: GBPJPY
  company: TF Global Markets (Aust) Pty Ltd
  period: H1
  from_date: 2023.01.01
  to_date: 2025.12.31
  initial_deposit: 10000.0
  leverage: 1:100
  quality: 100% real ticks
  history_quality: 100% real ticks
  bars: 18624.0
  ticks: 130612863.0
  symbols_count: 0
  net_profit: 2369.26
  gross_profit: 9233.56
  gross_loss: -6864.3
  balance_drawdown_abs: 281.0
  equity_drawdown_abs: 428.14
  balance_drawdown_maximal_abs: 282.23
  balance_drawdown_maximal_pct: 10.8
  equity_drawdown_maximal_abs: 431.8
  equity_drawdown_maximal_pct: 12.0
  balance_drawdown_relative_pct: 10.8
  equity_drawdown_relative_pct: 12.0
  profit_factor: 1.35
  recovery_factor: 1.65
  expected_payoff: 7.09
  sharpe_ratio: 1.11
  z_score: -9.57 (99.74%)
  ahpr: 0
  ghpr: 0
  lr_correlation: 0.81
  ontester_result: 0
  margin_level: 2115.40%
  total_trades: 334.0
  total_deals: 487.0
  short_trades: 0
  short_won_pct: 0
  long_trades: 334
  long_won_pct: 71.86
  profit_trades: 240
  profit_trades_pct: 71.86
  loss_trades: 94
  loss_trades_pct: 28.14
  largest_profit_trade: 191.7
  largest_loss_trade: -127.44
  avg_profit_trade: 0
  avg_loss_trade: 0
  avg_consecutive_wins: 0
  avg_consecutive_losses: 0
  max_consecutive_wins: 0
  max_consecutive_losses: 0

### GBPJPY BWD
ea_name: Boss_14_GridLog
  symbol: GBPJPY
  company: TF Global Markets (Aust) Pty Ltd
  period: H1
  from_date: 2020.01.01
  to_date: 2022.12.31
  initial_deposit: 10000.0
  leverage: 1:100
  quality: 99% real ticks
  history_quality: 99% real ticks
  bars: 18696.0
  ticks: 87409435.0
  symbols_count: 0
  net_profit: -2490.4
  gross_profit: 430.26
  gross_loss: -2920.66
  balance_drawdown_abs: 2490.4
  equity_drawdown_abs: 2490.69
  balance_drawdown_maximal_abs: 490.4
  balance_drawdown_maximal_pct: 24.9
  equity_drawdown_maximal_abs: 498.96
  equity_drawdown_maximal_pct: 24.97
  balance_drawdown_relative_pct: 24.9
  equity_drawdown_relative_pct: 24.97
  profit_factor: 0.15
  recovery_factor: -1.0
  expected_payoff: -62.26
  sharpe_ratio: -5.0
  z_score: -1.94 (94.76%)
  ahpr: 0
  ghpr: 0
  lr_correlation: -0.97
  ontester_result: 0
  margin_level: 1781.76%
  total_trades: 40.0
  total_deals: 70.0
  short_trades: 0
  short_won_pct: 0
  long_trades: 40
  long_won_pct: 25.0
  profit_trades: 10
  profit_trades_pct: 25.0
  loss_trades: 30
  loss_trades_pct: 75.0
  largest_profit_trade: 186.51
  largest_loss_trade: -163.31
  avg_profit_trade: 0
  avg_loss_trade: 0
  avg_consecutive_wins: 0
  avg_consecutive_losses: 0
  max_consecutive_wins: 0
  max_consecutive_losses: 0
