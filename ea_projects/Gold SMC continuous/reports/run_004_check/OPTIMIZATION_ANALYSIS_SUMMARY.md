# Optimization Analysis Summary

- Generated: 2026-06-04T22:25:28
- Root: `C:\Users\patip\OneDrive\.Codex\EA_LAB\ea_projects\Gold SMC continuous`
- Files scanned: 201
- Excel/XML/CSV optimizer sources found: 10
- Optimizer passes extracted: 11,320
- Tester summaries extracted: 7
- Duplicate file groups by SHA1: 54

## Best Risk-Adjusted Optimizer Passes

| Rank | Symbol | Strategy/File | Pass | Profit | PF | Recovery | Sharpe | DD% | Trades | Score |
|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 |  | ReportOptimizer-146237.xml | 1568.0 | 10074.07 | 1.442046 | 4.513068 | 4.146669 | 10.6026 | 464.0 | 85.9 |
| 2 |  | pass_1_optimizer_parsed.csv | 2295.0 | 15819.1 | 1.400321 | 5.18416 | 4.277232 | 11.7964 | 688.0 | 84.57 |
| 3 |  | pass_1_plan_rejected.csv | 2295.0 | 15819.1 | 1.400321 | 5.18416 | 4.277232 | 11.7964 | 688.0 | 84.57 |
| 4 |  | pass_1_rejected_risk_violations.csv | 2295.0 | 15819.1 | 1.400321 | 5.18416 | 4.277232 | 11.7964 | 688.0 | 84.57 |
| 5 |  | ReportOptimizer-146237.xml | 2295.0 | 15819.1 | 1.400321 | 5.18416 | 4.277232 | 11.7964 | 688.0 | 84.57 |
| 6 |  | pass_1_optimizer_parsed.csv | 2395.0 | 15817.42 | 1.401633 | 5.18259 | 4.297886 | 11.799 | 689.0 | 84.57 |
| 7 |  | pass_1_plan_rejected.csv | 2395.0 | 15817.42 | 1.401633 | 5.18259 | 4.297886 | 11.799 | 689.0 | 84.57 |
| 8 |  | pass_1_rejected_risk_violations.csv | 2395.0 | 15817.42 | 1.401633 | 5.18259 | 4.297886 | 11.799 | 689.0 | 84.57 |
| 9 |  | ReportOptimizer-146237.xml | 2395.0 | 15817.42 | 1.401633 | 5.18259 | 4.297886 | 11.799 | 689.0 | 84.57 |
| 10 |  | pass_1_valid_candidates.csv | 1074.0 | 8479.05 | 1.285731 | 4.128932 | 2.92494 | 11.3402 | 494.0 | 83.2 |
| 11 |  | ReportOptimizer-146237.xml | 1605.0 | 9600.21 | 1.39998 | 4.300437 | 3.897926 | 10.8545 | 460.0 | 83.08 |
| 12 |  | pass_1_optimizer_parsed.csv | 2109.0 | 17195.75 | 1.392954 | 4.066247 | 4.446874 | 15.2932 | 689.0 | 83.0 |
| 13 |  | pass_1_plan_rejected.csv | 2109.0 | 17195.75 | 1.392954 | 4.066247 | 4.446874 | 15.2932 | 689.0 | 83.0 |
| 14 |  | pass_1_rejected_risk_violations.csv | 2109.0 | 17195.75 | 1.392954 | 4.066247 | 4.446874 | 15.2932 | 689.0 | 83.0 |
| 15 |  | ReportOptimizer-146237.xml | 2109.0 | 17195.75 | 1.392954 | 4.066247 | 4.446874 | 15.2932 | 689.0 | 83.0 |

## Tester Summary Highlights

| File | Expert | Symbol | Net Profit | PF | Recovery | Sharpe | Trades |
|---|---|---|---:|---:|---:|---:|---:|
| ReportTester-146237.xlsx | Gold_SMC_Continuous_MT5 | XAUUSD | 27181.36 | 1.448864 | 3.454633 | 1.996263 | 706.0 |
| ReportTester-146237.xlsx | Gold_SMC_Continuous_MT5 | XAUUSD | 27181.36 | 1.448864 | 3.454633 | 1.996263 | 706.0 |
| ReportTester-146237 - risk cap.xlsx | Gold_SMC_Continuous_MT5 | XAUUSD | 27181.36 | 1.448864 | 3.454633 | 1.996263 | 706.0 |
| ReportTester-146237.xlsx | Gold_SMC_Continuous_MT5_RiskCapV1 | XAUUSD | 13870.55 | 1.342346 | 4.00803 | 3.589049 | 686.0 |
| ReportTester-146237.xlsx | Gold_SMC_Continuous_MT5_RiskCapV1 | XAUUSD | 7497.37 | 1.309982 | 3.219068 | 3.146481 | 479.0 |
| ReportTester-146237.xlsx | Gold_SMC_Continuous_MT5_RiskCapV1 | XAUUSD | 2596.61 | 1.113887 | 0.942669 | 1.277235 | 434.0 |
| ReportTester-146237.xlsx | Gold_SMC_Continuous_MT5_RiskCapV1 | XAUUSD | 2596.61 | 1.113887 | 0.942669 | 1.277235 | 434.0 |

## Reading Notes

- Score is risk-adjusted, not profit-only. It rewards Profit, Profit Factor, Recovery Factor, Sharpe Ratio, and lower Equity DD%.
- `selection_flag` requires Profit > 0, PF >= 1.2, Recovery >= 1.0, Sharpe >= 0.5, DD <= 40%, and Trades >= 100.
- OLD_Report contains duplicated historical copies; duplicate groups are tracked in the inventory instead of silently ignored.
