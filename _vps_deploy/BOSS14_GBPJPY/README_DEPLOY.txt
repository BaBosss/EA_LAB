========================================================================
ORDER-106 Boss_14 GridLog — GBPJPY H4 — DEMO LEG #8 (cohort 990201-207 -> +990208)
========================================================================
Status:   DEMO-ELIGIBLE additive leg (lead 2026-07-16). Same EA as the live 7-leg
          Boss_14 cohort, new symbol+magic. Rescue of a previously default-only-parked cell.

!!! HOLDOUT NOTE — added 2026-07-26 after the ORDER-202 contamination retro-scan !!!
          The PARAMETER VALUES of this cohort are CLEAN: every deployed leg traces to
          BOSS14_OPT_<SYM>_IS.ini at 2023.01.01 -> 2025.06.30 (the contaminated round-1
          BOSS14_OPT_<SYM>_1.ini sweeps were superseded and are not the source).
          BUT the promotion gate -- the "fresh-start OOS" 2025.07.01 -> 2026.07.01 plus the
          FULL/M4CONFIRM windows -- reached into 2026H1 for 7 of the 8 legs. So the values are
          clean while the SHIP/NO-SHIP DECISION consumed the holdout.
          => 2026H1 is SPENT for this cohort. Do NOT cite any 2026H1 result as independent
             confirmation of these legs. Genuine forward evidence starts at demo attach
             (same disposition as the Boss_16 precedent: demo-forward-as-holdout).
          No re-optimize is needed -- this is a policy/labelling correction, not a defect.
          See _triage/ORDER202_HOLDOUT_CONTAMINATION_RETROSCAN.md.
          Separately (ORDER-136 Wave 2): keep LotProg=55 on this leg -- escalation beat flat
          on BWD real-tick Model-4 (PF 1.32 vs 1.07, lower eqDD). Do not revert to flat.
EA:       Boss_14_GridLog.ex5  (the SHARED cohort EA — already attached for 990201-207;
          just add one more chart on GBPJPY H4 with this .set + magic 990208)
Source:   D:\EA_LAB\ea_template\Boss_14_GridLog.mq5 (LabCore chassis)
Build:    Boss_14_GridLog.ex5  MD5 1A082ECF05B6EC5623A4E0A39576DC35
Symbol:   GBPJPY   TF: H4   Magic: 990208   Set: Boss14_GridLog_GBPJPY_H4_demo_leg8.set

Config: GridLog BUY-side ATR grid, DistAtrMult 2.0 / 6 legs / LOG-lot base 0.10 /
  basket-money-TP $250 / per-leg SL 4xATR (cap 150 pip) / KillDD 25%. d2.0/s4.0 = the
  Model-4-confirmed plateau point (the finer d1.5 was rejected — Model-4 fill-optimism).

------------------------------------------------------------------------
WHY DEPLOY (rescued from default-only park; full funnel cleared)
------------------------------------------------------------------------
- Origin: GBPJPY was parked as "default-only, OOS 1.12 borderline" (under-swept). Coarse+finer
  sweep found a genuine H4 plateau at d2.0.
- Model-4 (real ticks) both-window: MAIN(2023-26) 1.43 / BWD(2020-22) 1.11. DD ~9% both.
- YEAR-SPLIT (Model-4) all-years-positive: 2021 2.03 / 2022 1.28 / 2023 1.75 / 2024 1.70 /
  2025 2.36 / 2026 1.50. NO losing year (cleaner than the Zeus AUDJPY rescue, whose 2023 lost).
- CORR vs the 7 cohort legs all < 0.8 (max 0.791) => additive, not redundant.

------------------------------------------------------------------------
CAVEATS
------------------------------------------------------------------------
- THIN sample: 9-28 trades/year (~110 total over the window). Edge is real+consistent but
  low-frequency; a couple of bad baskets swing a year. Size accordingly.
- 2020 = 0 trades (GBPJPY H4 history gap on this feed — not a fault, just no data). BWD PF 1.11
  rests on 2021-22 only.
- CADJPY(990205) corr 0.791 — just under the 0.8 gate but both are JPY-cross grids. GBPJPY +
  CADJPY will tend to draw down together in JPY-driven moves. USER AWARE: if you'd rather not
  double the JPY-cross-grid exposure, drop one (both are thin, size-light). Not auto-dropped.

------------------------------------------------------------------------
SILENT-STOP PRE-ATTACH CHECKLIST
------------------------------------------------------------------------
[S1] LIVE GATE: LabCore uses `DryRun` (NOT AllowLive). Bundled .set has DryRun=false; CONFIRM
     it stuck after load (DryRun=true => logs intents, places NO orders = silent no-trade).
[S2] RECOMPILE RESET: recompiling reverts inputs to compiled defaults (DryRun=false is the
     default so orders still fire, BUT the grid/SL/magic params reset) -> after any recompile
     re-attach + RELOAD this .set + confirm _0_Magic=990208 + _14_DistAtrMult=2.0 stuck.
[S3] magic 990208 unique (checked vs portfolio/DEPLOYMENTS.csv 990201-207). [S4] no vendor lock.
[S5] symbol GBPJPY (match broker suffix e.g. GBPJPYm on the VPS feed). [S6] H4 chart.
[S7] Bar-gate: _0_BarOpenOnly=true (sample once per H4 bar). Grid on closed bars, no repaint.

------------------------------------------------------------------------
KILL-SWITCH + NEXT
------------------------------------------------------------------------
- Equity DD alert 15%, KILL 20% (internal KillDD fires at 25%). Judge +3 months from attach.
- Attach Boss_14_GridLog on GBPJPY H4, load this .set, confirm DryRun=false + magic 990208 +
  first basket arms. Tell Claude attach date -> register 990208 in DEPLOYMENTS.csv + judge date.
- Verdict: _triage/_archive/verdicts/order104-126/ORDER106_GBPJPY_RESCUE_VERDICT.md

========================================================================
2026-08-02 — ORDER-510 ADOPT-ONCE BUNDLE ADDED (S-2026-08-02-ADOPT208)
========================================================================
The .ex5 in this folder was REPLACED. The previous one (2026-07-16, MD5
1A082ECF05B6EC5623A4E0A39576DC35) is kept as
Boss_14_GridLog_PRE132_2026-07-16.ex5.old — it predates ORDER-132/138 and has
no persist gate, which is why nothing has migrated on this chart yet.

New: Boss_14_GridLog.ex5, MD5 5D2C5A9E7CB9A5B4BB2D99EA1E07AA41, compiled
2026-08-02 from current source, 0 errors / 0 warnings on 9 targets.
tpl_regression CLEAN 8/8 on lane 1 and ea_template/** is unchanged since that
run (verified by git log), so Boss_14's behaviour is baseline-identical — the
only deliberate difference on this leg is the two persist flags.

F3 on 415573666 found ONE pre-132 key: Boss_990208_rc_peak_eq = 60027.15.
This is the only magic in the fleet that needs adopt-once; the other three
accounts censused empty on 2026-08-02.

DO NOT attach from this folder without reading
ADOPT_ONCE_990208_CHECKLIST.txt — the three O510_990208_STEP*.set files must
be used in order, and STEP1 is only safe while the leg is FLAT (DryRun
suppresses closes as well as opens).

⚠️ The 52-value Boss14_GridLog_GBPJPY_H4_demo_leg8.set is kept for reference but
is a PARTIAL set (the build exposes 116 inputs). The STEP files are full-surface
for that reason; unlisted inputs otherwise come from the terminal's last-used
cache and a re-attach is then not reproducible.
