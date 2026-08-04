# O1411 Results
## CELL 1 — MacdDiv_Naked / AUDJPY / H4

### STAGE 1 — Single-axis sweep (Model 1, MAIN 2023.01–2025.12)

| axis | value | PF | trades | DD% | net | report |
|---|---|---|---|---|---|---|
| _01_SwingRadius | 3 (baseline) | 1.18 | 173 | 0.84 | 48.47 | O1411_MDX_BASE |

| _01_SwingRadius | 1 | 0.93 | 333 | 0.86 | -38.25 | O1411_MDX_SwingRadius_1 |
| _01_SwingRadius | 2 | 1.01 | 216 | 0.94 | 2.70 | O1411_MDX_SwingRadius_2 |
| _01_SwingRadius | 4 | 1.46 | 160 | 0.51 | 108.18 | O1411_MDX_SwingRadius_4 |
| _01_SwingRadius | 5 | 1.20 | 126 | 0.57 | 45.42 | O1411_MDX_SwingRadius_5 |
| _03_BufferAtrMult | 0.05 | 0.96 | 201 | 0.93 | -13.28 | O1411_MDX_BufferAtrMult_0.05 |
| _03_BufferAtrMult | 0.10 | 1.01 | 189 | 0.85 | 3.22 | O1411_MDX_BufferAtrMult_0.10 |
| _03_BufferAtrMult | 0.25 | 0.97 | 165 | 1.08 | -8.17 | O1411_MDX_BufferAtrMult_0.25 |
| _03_BufferAtrMult | 0.40 | 0.99 | 134 | 0.70 | -1.63 | O1411_MDX_BufferAtrMult_0.40 |
| _03_AtrPeriod | 10 | 1.15 | 174 | 0.86 | 42.53 | O1411_MDX_AtrPeriod_10 |
| _03_AtrPeriod | 14 | 1.13 | 175 | 0.86 | 36.36 | O1411_MDX_AtrPeriod_14 |
| _03_AtrPeriod | 25 | 1.18 | 172 | 0.85 | 50.64 | O1411_MDX_AtrPeriod_25 |
| _03_AtrPeriod | 35 | 1.16 | 173 | 0.88 | 44.73 | O1411_MDX_AtrPeriod_35 |
| _01_LookbackBars | 30 | 1.18 | 173 | 0.84 | 48.47 | O1411_MDX_LookbackBars_30 |
| _01_LookbackBars | 45 | 1.18 | 173 | 0.84 | 48.47 | O1411_MDX_LookbackBars_45 |
| _01_LookbackBars | 90 | 1.18 | 173 | 0.84 | 48.47 | O1411_MDX_LookbackBars_90 |
| _01_MinBarsApart | 1 | 1.18 | 173 | 0.84 | 48.47 | O1411_MDX_MinBarsApart_1 |
| _01_MinBarsApart | 4 | 1.18 | 173 | 0.84 | 48.47 | O1411_MDX_MinBarsApart_4 |
| _07_UseRsiGate | true | 1.18 | 173 | 0.84 | 48.47 | O1411_MDX_UseRsiGate_true |
| _08_UseMacdCross | true | 1.18 | 173 | 0.84 | 48.47 | O1411_MDX_UseMacdCross_true |

### STAGE 1 CLASSIFICATION — CELL 1 (MacdDiv_Naked / AUDJPY / H4)
Baseline PF = 1.18

| axis | max |delta| | verdict |
|---|---|---|
| _01_SwingRadius | 0.28 | LIVE |
| _03_BufferAtrMult | 0.22 | LIVE |
| _03_AtrPeriod | 0.05 | LIVE |
| _01_LookbackBars | 0.00 | INERT |
| _01_MinBarsApart | 0.00 | INERT |
| _07_UseRsiGate | 0.00 | INERT(_07_UseRsiGate) — identical in every digit |
| _08_UseMacdCross | 0.00 | INERT(_08_UseMacdCross) — identical in every digit |

Top 2 LIVE axes for STAGE 2: _01_SwingRadius (delta=0.28), _03_BufferAtrMult (delta=0.22)

## CELL 2 — PivotBreakout_XAU / USDJPY / H4

### STAGE 1 — Single-axis sweep (Model 1, MAIN 2023.01–2025.12)

| axis | value | PF | trades | DD% | net | report |
|---|---|---|---|---|---|---|
| _01_AtrPeriod | 14 (baseline) | 1.17 | 211 | 1.14 | 149.01 | O1411_PVT_BASE |
| _01_AtrPeriod | 7 | 1.01 | 206 | 1.17 | 11.99 | O1411_PVT_AtrPeriod_7 |
| _01_AtrPeriod | 10 | 1.20 | 212 | 0.96 | 174.56 | O1411_PVT_AtrPeriod_10 |
| _01_AtrPeriod | 20 | 0.96 | 225 | 1.87 | -39.72 | O1411_PVT_AtrPeriod_20 |
| _01_AtrPeriod | 28 | 0.92 | 233 | 1.91 | -76.72 | O1411_PVT_AtrPeriod_28 |
| _02_SlAtrMult | 1.5 (baseline) | 1.17 | 211 | 1.14 | 149.01 | O1411_PVT_BASE |
| _02_SlAtrMult | 1.0 | 1.07 | 344 | 0.98 | 61.56 | O1411_PVT_SlAtrMult_1.0 |
| _02_SlAtrMult | 2.0 | 0.83 | 145 | 2.89 | -149.06 | O1411_PVT_SlAtrMult_2.0 |
| _02_SlAtrMult | 2.5 | 0.99 | 92 | 1.92 | -5.26 | O1411_PVT_SlAtrMult_2.5 |
| _02_SlAtrMult | 3.0 | 1.12 | 56 | 1.22 | 57.36 | O1411_PVT_SlAtrMult_3.0 |
| _02_TpRR | 3.0 (baseline) | 1.17 | 211 | 1.14 | 149.01 | O1411_PVT_BASE |
| _02_TpRR | 1.5 | 1.01 | 356 | 1.39 | 8.05 | O1411_PVT_TpRR_1.5 |
| _02_TpRR | 2.0 | 1.00 | 315 | 1.42 | 4.13 | O1411_PVT_TpRR_2.0 |
| _02_TpRR | 4.0 | 0.93 | 174 | 2.20 | -55.22 | O1411_PVT_TpRR_4.0 |
| _02_TpRR | 5.0 | 1.03 | 145 | 1.85 | 18.70 | O1411_PVT_TpRR_5.0 |
| session | 0-24 (baseline) | 1.17 | 211 | 1.14 | 149.01 | O1411_PVT_BASE |
| session | 7-20 | 1.01 | 192 | 1.71 | 9.50 | O1411_PVT_sess_7_20 |
| session | 12-21 | 0.81 | 185 | 2.38 | -162.04 | O1411_PVT_sess_12_21 |

### STAGE 1 CLASSIFICATION — CELL 2 (PivotBreakout_XAU / USDJPY / H4)
Baseline PF = 1.17

| axis | max delta | verdict |
|---|---|---|
| _01_AtrPeriod | 0.25 | LIVE |
| _02_SlAtrMult | 0.34 | LIVE |
| _02_TpRR | 0.17 | LIVE |
| session | 0.36 | LIVE |

Top 2 LIVE axes for STAGE 2: session (delta=0.36), _02_SlAtrMult (delta=0.34)
