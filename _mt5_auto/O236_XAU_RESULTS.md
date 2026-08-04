# O236_XAU — Boss_14_GridLog / XAUUSD / H1 / Model-4

## STEP 0 — Binary Freshness

| File | LastWriteTime |
|---|---|
| `D:\Meta 5b\MQL5\Experts\EALabTpl\Boss_14_GridLog.ex5` | 2026-08-02 13:59:03 |
| `D:\EA_LAB\ea_template\core\Inputs.mqh` (latest) | 2026-08-02 12:49:58 |
| `D:\EA_LAB\ea_template\core\LabCore.mqh` | 2026-08-02 07:13:44 |
| `D:\EA_LAB\ea_template\core\LockedConstants_gen.mqh` | 2026-08-02 07:47:41 |
| `D:\EA_LAB\ea_template\core\ConfigFingerprint.mqh` | 2026-08-02 07:11:18 |
| `D:\EA_LAB\ea_template\core\InputSurface_gen.mqh` | 2026-08-02 07:12:57 |

All other core files older than 2026-08-02.
**STEP 0 = PASS** (binary newer than every core file).

---

## Results Table

| cell | window | PF | trades | DD% | net | leverage | report path |
|---|---|---|---|---|---|---|---|
| CTRL (B14_AB_off) | MAIN 23.01–25.12 | 0.95 | 237 | 6.90% | -148.87 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_XAU_CTRL_MAIN.htm |
| CTRL (B14_AB_off) | BWD 20.01–22.12 | 2.28 | 53 | 2.78% | 749.01 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_XAU_CTRL_BWD.htm |
| A (B14_AB_on) | MAIN 23.01–25.12 | 0.97 | 235 | 6.54% | -99.31 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_XAU_A_MAIN.htm |
| A (B14_AB_on) | BWD 20.01–22.12 | 1.99 | 57 | 3.52% | 663.02 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_XAU_A_BWD.htm |
| B (B14_PAon) | MAIN 23.01–25.12 | 0.95 | 237 | 6.90% | -148.87 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_XAU_B_MAIN.htm |
| B (B14_PAon) | BWD 20.01–22.12 | 2.28 | 53 | 2.78% | 749.01 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_XAU_B_BWD.htm |
| AB (AB_both) | MAIN 23.01–25.12 | 0.97 | 235 | 6.54% | -99.31 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_XAU_AB_MAIN.htm |
| AB (AB_both) | BWD 20.01–22.12 | 1.99 | 57 | 3.52% | 663.02 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_XAU_AB_BWD.htm |

**STEP 1 GATE:** CTRL BWD PF=2.28 >= 1.20, CTRL BWD trades=53 >= 30 → PASS. Continue to Steps 2-4.

---

## Raw Parse Output

### CTRL MAIN (O236_XAU_CTRL_MAIN.htm)

```
Strategy Tester Report
ThinkMarkets-Live (Build 5836)
Symbol: XAUUSD | Period: H1 (2023.01.01 - 2025.12.31)
History Quality: 100% real ticks | Bars: 17720 | Ticks: 99472212
Total Net Profit: -148.87
Gross Profit: 3026.43 | Gross Loss: -3175.30
Profit Factor: 0.95
Expected Payoff: -0.63
Recovery Factor: -0.20
Sharpe Ratio: -0.79
Equity Drawdown Maximal: 728.58 (6.90%)
Balance Drawdown Maximal: 488.40 (4.73%)
Total Trades: 237 | Total Deals: 439
Short Trades: 0 | Long Trades: 237 (18.14% won)
Profit Trades: 43 (18.14%) | Loss Trades: 194 (81.86%)
Largest profit trade: 288.29 | Largest loss trade: -143.80
Average profit trade: 70.38 | Average loss trade: -16.37
Max consecutive wins: 5 | Max consecutive losses: 30
Leverage: 1:100
```

### CTRL BWD (O236_XAU_CTRL_BWD.htm)

```
Strategy Tester Report
ThinkMarkets-Live (Build 5836)
Symbol: XAUUSD | Period: H1 (2020.01.01 - 2022.12.31)
History Quality: 99% real ticks | Bars: 17761 | Ticks: 78176200
Total Net Profit: 749.01
Gross Profit: 1332.23 | Gross Loss: -583.22
Profit Factor: 2.28
Expected Payoff: 14.13
Recovery Factor: 2.54
Sharpe Ratio: 7.56
Equity Drawdown Maximal: 294.90 (2.78%)
Balance Drawdown Maximal: 195.26 (1.85%)
Total Trades: 53 | Total Deals: 94
Short Trades: 0 | Long Trades: 53 (30.19% won)
Profit Trades: 16 (30.19%) | Loss Trades: 37 (69.81%)
Largest profit trade: 266.83 | Largest loss trade: -36.87
Average profit trade: 83.26 | Average loss trade: -15.76
Max consecutive wins: 5 | Max consecutive losses: 13
Leverage: 1:100
```

### A MAIN (O236_XAU_A_MAIN.htm)

```
Strategy Tester Report
ThinkMarkets-Live (Build 5836)
Symbol: XAUUSD | Period: H1 (2023.01.01 - 2025.12.31)
Total Net Profit: -99.31
Gross Profit: 3080.02 | Gross Loss: -3179.33
Profit Factor: 0.97
Expected Payoff: -0.42
Recovery Factor: -0.13
Sharpe Ratio: -0.71
Equity Drawdown Maximal: 690.58 (6.54%)
Balance Drawdown Maximal: 450.40 (4.36%)
Total Trades: 235 | Total Deals: 435
Short Trades: 0 | Long Trades: 235 (18.30% won)
Profit Trades: 43 (18.30%) | Loss Trades: 192 (81.70%)
Largest profit trade: 288.29 | Largest loss trade: -143.80
Average profit trade: 71.63 | Average loss trade: -16.56
Max consecutive wins: 5 | Max consecutive losses: 30
Leverage: 1:100
```

### A BWD (O236_XAU_A_BWD.htm)

```
Strategy Tester Report
ThinkMarkets-Live (Build 5836)
Symbol: XAUUSD | Period: H1 (2020.01.01 - 2022.12.31)
Total Net Profit: 663.02
Gross Profit: 1296.44 | Gross Loss: -633.42
Profit Factor: 1.99
Expected Payoff: 11.63
Recovery Factor: 1.77
Sharpe Ratio: 5.18
Equity Drawdown Maximal: 373.63 (3.52%)
Balance Drawdown Maximal: 272.29 (2.59%)
Total Trades: 57 | Total Deals: 100
Short Trades: 0 | Long Trades: 57 (28.07% won)
Profit Trades: 16 (28.07%) | Loss Trades: 41 (71.93%)
Largest profit trade: 266.83 | Largest loss trade: -36.87
Average profit trade: 81.03 | Average loss trade: -15.45
Max consecutive wins: 5 | Max consecutive losses: 13
Leverage: 1:100
```

### B MAIN (O236_XAU_B_MAIN.htm)

```
Strategy Tester Report
ThinkMarkets-Live (Build 5836)
Symbol: XAUUSD | Period: H1 (2023.01.01 - 2025.12.31)
Total Net Profit: -148.87
Gross Profit: 3026.43 | Gross Loss: -3175.30
Profit Factor: 0.95
Expected Payoff: -0.63
Recovery Factor: -0.20
Sharpe Ratio: -0.79
Equity Drawdown Maximal: 728.58 (6.90%)
Balance Drawdown Maximal: 488.40 (4.73%)
Total Trades: 237 | Total Deals: 439
Short Trades: 0 | Long Trades: 237 (18.14% won)
Profit Trades: 43 (18.14%) | Loss Trades: 194 (81.86%)
Largest profit trade: 288.29 | Largest loss trade: -143.80
Average profit trade: 70.38 | Average loss trade: -16.37
Max consecutive wins: 5 | Max consecutive losses: 30
Leverage: 1:100
```

### B BWD (O236_XAU_B_BWD.htm)

```
Strategy Tester Report
ThinkMarkets-Live (Build 5836)
Symbol: XAUUSD | Period: H1 (2020.01.01 - 2022.12.31)
Total Net Profit: 749.01
Gross Profit: 1332.23 | Gross Loss: -583.22
Profit Factor: 2.28
Expected Payoff: 14.13
Recovery Factor: 2.54
Sharpe Ratio: 7.56
Equity Drawdown Maximal: 294.90 (2.78%)
Balance Drawdown Maximal: 195.26 (1.85%)
Total Trades: 53 | Total Deals: 94
Short Trades: 0 | Long Trades: 53 (30.19% won)
Profit Trades: 16 (30.19%) | Loss Trades: 37 (69.81%)
Largest profit trade: 266.83 | Largest loss trade: -36.87
Average profit trade: 83.26 | Average loss trade: -15.76
Max consecutive wins: 5 | Max consecutive losses: 13
Leverage: 1:100
```

### AB MAIN (O236_XAU_AB_MAIN.htm)

```
Strategy Tester Report
ThinkMarkets-Live (Build 5836)
Symbol: XAUUSD | Period: H1 (2023.01.01 - 2025.12.31)
Total Net Profit: -99.31
Gross Profit: 3080.02 | Gross Loss: -3179.33
Profit Factor: 0.97
Expected Payoff: -0.42
Recovery Factor: -0.13
Sharpe Ratio: -0.71
Equity Drawdown Maximal: 690.58 (6.54%)
Balance Drawdown Maximal: 450.40 (4.36%)
Total Trades: 235 | Total Deals: 435
Short Trades: 0 | Long Trades: 235 (18.30% won)
Profit Trades: 43 (18.30%) | Loss Trades: 192 (81.70%)
Largest profit trade: 288.29 | Largest loss trade: -143.80
Average profit trade: 71.63 | Average loss trade: -16.56
Max consecutive wins: 5 | Max consecutive losses: 30
Leverage: 1:100
```

### AB BWD (O236_XAU_AB_BWD.htm)

```
Strategy Tester Report
ThinkMarkets-Live (Build 5836)
Symbol: XAUUSD | Period: H1 (2020.01.01 - 2022.12.31)
Total Net Profit: 663.02
Gross Profit: 1296.44 | Gross Loss: -633.42
Profit Factor: 1.99
Expected Payoff: 11.63
Recovery Factor: 1.77
Sharpe Ratio: 5.18
Equity Drawdown Maximal: 373.63 (3.52%)
Balance Drawdown Maximal: 272.29 (2.59%)
Total Trades: 57 | Total Deals: 100
Short Trades: 0 | Long Trades: 57 (28.07% won)
Profit Trades: 16 (28.07%) | Loss Trades: 41 (71.93%)
Largest profit trade: 266.83 | Largest loss trade: -36.87
Average profit trade: 81.03 | Average loss trade: -15.45
Max consecutive wins: 5 | Max consecutive losses: 13
Leverage: 1:100
```
