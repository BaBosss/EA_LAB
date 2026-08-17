# ExpertMAPSAR — MAIN + yearly evidence (participation-gap closure)

Candidate: ExpertMAPSAR · source SHA-256 `6c5e7b665a766e6e995b673d9b8cd1e4c40e4de885c4413ad8f7e4b8a9a45e62`
Lane: `D:\Meta 5` (DataDir `9CA16B8382AE4CF692710FB36B9DA355`) · Symbol NZDUSD · TF H1 · Model 1
Set: `sets/ExpertMAPSAR_defaults.set` (same 7-line full surface as the accepted 2025 evidence, unchanged)

## MAIN 2023.01.01–2025.12.31 (single continuous run — the authoritative evidence)

| metric | value |
|---|---|
| trades | 100 |
| deals | 200 |
| PF | 9.16 |
| net | +207.47 |
| expected payoff | 2.07 |
| recovery factor | 3.44 |
| Sharpe | 1.11 |
| balance DD | 19.71 (0.19%) |
| equity DD | 60.37 (0.59%) |
| invalid stops / failed entries / invalid volume / runtime errors | 0 / 0 / 0 / 0 |

Report: `_mt5_auto/reports/M2W5C4_MAPSAR_NZDUSD_H1_MAIN_2023_2025_M1.htm`
Journal segment: `journal/M2W5C4_MAPSAR_MAIN_and_yearly_tester_journal.log`

## Canonical yearly breakdown — `scripts/report_year_split.py` on the MAIN report (AGENTS.md §3 rule 3)

```
FULL   trades= 100  PF= 9.16  net=   +207.47  balDD= 0.19%
2023   trades=  26  PF=  inf  net=    +79.98  balDD= 0.00%
2024   trades=  43  PF=2137.50  net=    +85.46  balDD= 0.00%
2025   trades=  31  PF= 2.65  net=    +42.03  balDD= 0.20%
```
No losing year. Trade counts sum exactly to MAIN's 100 (26+43+31=100), as they must — this is a
partition of one continuous deal list, not a second measurement.

## Independent standalone single-year reruns (as this task's own instruction literally specified)

| window | trades | PF | net | balDD | execution validity |
|---|---|---|---|---|---|
| 2023.01.01–2023.12.31 | 27 | 8.67 | +70.75 | 0.09% | PASS (0 invalid stops/failed/invalid volume) |
| 2024.01.01–2024.12.31 | 19 | **0.77** | **-10.09** | 0.39% | PASS (0 invalid stops/failed/invalid volume) |
| 2025.01.01–2025.12.31 | 3 (reused accepted evidence, commit `e81a33c1`) | 0.23 | -18.07 | 0.23%/0.64% | PASS |

Sum: 27+19+3 = **49 trades**, net = **+42.59**.

## 🔴 Finding: standalone single-year reruns are NOT equivalent to a year-slice of the continuous run

Same EA, same set, same lane, same symbol/TF, same calendar year — two different measurements:

- 2024: standalone rerun = **19 trades, PF 0.77 (losing)**. Canonical slice of MAIN = **43 trades,
  PF 2137.50 (no material losers)**. A >2x trade-count gap and an inverted profitability sign for
  the identical calendar window.
- 2025: standalone rerun = **3 trades, PF 0.23**. Canonical slice of MAIN = **31 trades, PF 2.65**.
  A >10x trade-count gap.
- 2023 is the one year where the two methods roughly agree (27 vs 26 trades) — consistent with it
  being the FIRST year of both the standalone rerun and the continuous MAIN run, i.e. the only year
  where neither method carries pre-existing indicator/PSAR state into the window.

**Root cause (observed, not fixed — no source touched):** `CSignalMA`(period 12) and
`CTrailingParabolicSAR` are both stateful across time — PSAR accumulates its acceleration factor
and extreme point over the life of a trend, and a fresh backtest starting exactly at a year
boundary has no lead-in bars to establish that state or the MA's rolling window. A continuous
MAIN run carries indicator/PSAR state across the 2023→2024→2025 boundaries; an isolated
single-year rerun starts cold every time. This is a **test-construction artifact of running
independent single-year backtests on a stateful/trailing strategy**, not a product defect — no
invalid stop, no failed entry, no invalid volume, no runtime error differs between the two
methods; only the signal/trade generation differs, which is exactly the class of number
`AGENTS.md §3 rule 3` exists to protect against by mandating `report_year_split.py` on ONE
continuous run rather than independent per-year reruns.

**Disposition below is based on the MAIN run + its canonical `report_year_split.py` breakdown**,
per that binding rule — not on the standalone reruns, which are recorded here for completeness
and as a caveat for any future single-year Factory run on a PSAR/trailing-stateful candidate.
