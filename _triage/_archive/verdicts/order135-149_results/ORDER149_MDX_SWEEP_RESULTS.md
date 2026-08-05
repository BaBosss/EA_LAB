# ORDER-149 — MacdDiv divergence majors D1/H4 sweep — RESULTS (raw)

Date: 2026-07-20 · EA MacdDiv_Naked (default/locked) from demo set magic 999094 · flat 0.01 · Model 1+4 · MAIN 2023.01-2025.12 / BWD 2020.01-2022.12

| cell | M1 MAIN PF (n) | M1 BWD PF (n) | M4 MAIN (n) | M4 BWD (n) | mark |
|---|---|---|---|---|---|
| GBPUSD D1 | 1.86 (21) | 1.23 (43) | 1.86 (21) | 1.24 (43) | **PASS** |
| GBPUSD H4 | 1.18 (221) | 1.05 (246) | 1.15 (221) | 1.02 (247) | FAIL (M4 MAIN<1.2) |
| EURUSD D1 | 0.64 (39) | — | — | — | FAIL |
| EURUSD H4 | 0.93 (264) | — | — | — | FAIL |
| USDJPY D1 | 1.47 (39) | 1.30 (45) | 1.30 (39) | 1.11 (46) | **PASS** |
| USDJPY H4 | 1.10 (250) | 1.14 (221) | 1.07 (253) | 1.11 (221) | FAIL (M4 MAIN<1.2) |
| AUDUSD D1 | 0.91 (36) | — | — | — | FAIL |
| AUDUSD H4 | 0.97 (278) | — | — | — | FAIL |
| XAGUSD D1 | 0.64 (31) | — | — | — | FAIL |
| XAGUSD H4 | 0.87 (226) | — | — | — | FAIL |
| GBPJPY D1 | 0.72 (48) | — | — | — | FAIL |
| GBPJPY H4 | 0.79 (269) | — | — | — | FAIL |

Pre-registered marks: PASS = MAIN≥1.2 AND BWD≥1.0 M1+M4; FAIL otherwise. D1 cells n≥20 = OK (none THIN).

M4 phase: 4 survivors tested, 2 PASS + 2 FAIL (M4 MAIN cliff in H4 cells). No model cliff on PASS cells.

Status: DONE — awaiting Claude REVIEW. No verdict written (per order rules).
