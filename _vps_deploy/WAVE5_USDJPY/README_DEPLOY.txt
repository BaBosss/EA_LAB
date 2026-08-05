========================================================================
Boss_17_Wave5 — USDJPY H1 — DEMO (optimize-rescued, all-years-positive)
========================================================================
Status:   DEMO-ELIGIBLE. Same EA as the deployed Wave5 XAU/XAG legs — just another chart.

!!! CONTAMINATED SELECTION -- added 2026-07-26 (audit AUDIT_BUNDLE_EVIDENCE_G2.md) !!!
          The word "optimize" in this README refers to run_wave5_uj_opt.ps1: 9 MAIN cells
          (W5OPT_f*_m*_MAIN.ini), the winner f382/m1618 read off WAVE5_UJ_OPT.csv. EVERY one of
          those cells was scored on 2023.01.01 -> 2026.07.01 -- six months of the declared
          2026H1 holdout inside the ranking window. Optimization=0 on each file only records
          that a PowerShell loop drove the grid instead of the tester's optimiser; a ranked grid
          is selection regardless.
          => "MAIN 1.56" below is not a clean-window number, and this leg was RESCUED by that
          selection (the compiled default fails BWD), so the selection is load-bearing here in a
          way it is not for a config that was already good.
          The year-split ("all 6 years positive") IS clean -- W5YS_USDJPY_2025 stops at
          2026.01.01 -- but it was run after the cell was chosen. It confirms the winner; it did
          not select it. That distinction is the whole point.
          Demo only (463666728 USDJPYm, judge 2026-10-16); no real money exposed.
          Settle it with: f382/m1618 on 2023.01.01 -> 2025.12.31, Model 4, full pinned .set.
          Found thin in the overnight multi-home (1.12/1.50), then optimize lifted it to a
          clean all-years-positive candidate. Pending user attach.
EA:       Boss_17_Wave5.ex5 (bundled; same as WAVE5_XAU/XAG)
Symbol:   USDJPY   TF: H1   Magic: 990303   Set: WAVE5_USDJPY_H1_demo_v1.set
Config:   EntryFib 38.2 / Wave3MinMult 1.618 (stricter entry than XAU/XAG legs), ExitMode 23,
          MaxLevels 1, Trail 2000/800.

WHY: both-window Model-4 = MAIN 1.56 / BWD 1.92 (plateau, neighbors both-positive). Year-split
     = ALL 6 years positive (2020 1.56 / 2021 1.62 / 2022 2.29 / 2023 1.94 / 2024 1.70 / 2025 2.14).
CAVEAT: THIN — 11-17 trades/yr (~85 total). Size light, judge over months. Same-EA family as the
     XAU/XAG legs (correlation is a LIVE decision, not a demo gate).

SILENT-STOP: [S1] Wave5 live gate per chassis — confirm it arms. [S2] recompile resets inputs ->
reload this .set + confirm EntryFib=38.2, Wave3MinMult=1.618, Magic 990303. [S5] USDJPY (broker
suffix). [S6] H1 chart.
NEXT: attach -> tell Claude the date -> register 990303 + judge +3mo.
Verdict: _triage/ORDER082B_WAVE5_USDJPY_VERDICT.md
