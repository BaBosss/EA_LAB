# ORDER-136 Wave 2 — Boss_14 GBPJPY H4 base vs LOG13

Run by Codex, 2026-07-21. Model 1, main lane `D:\Meta 5`, `EALabTpl\\Boss_14_GridLog`, GBPJPY H4, deposit 10000. MAIN = 2023.01.01–2025.12.31; BWD = 2020.01.01–2022.12.31. Fresh reports are under `_mt5_auto/reports/`.

| Variant | Window | PF | Net | EqDD% | Trades | Quality |
|---|---|---:|---:|---:|---:|---:|
| BASE LotProg=50 | MAIN | 1.80 | 948.38 | 6.18 | 37 | 100% |
| BASE LotProg=50 | BWD | 0.92 | -117.83 | 9.36 | 26 | 99% |
| LOG13 LotProg=55, factor=1.3 | MAIN | 1.80 | 948.38 | 6.18 | 37 | 100% |
| LOG13 LotProg=55, factor=1.3 | BWD | 0.91 | -128.30 | 9.46 | 26 | 99% |

Raw report paths:

- `_mt5_auto/reports/O136_W2_B14_GJ_BASE_MAIN_M1.htm`
- `_mt5_auto/reports/O136_W2_B14_GJ_BASE_BWD_M1.htm`
- `_mt5_auto/reports/O136_W2_B14_GJ_LOG13_MAIN_M1.htm`
- `_mt5_auto/reports/O136_W2_B14_GJ_LOG13_BWD_M1.htm`

Gate evidence only: BASE BWD PF=0.92 (<1.0), so the pre-registered M1 gate for M4 confirmation was not met. LOG13 did not improve MAIN, BWD, or EqDD. No M4 runs, verdict, deployment, or demo-set changes performed.
