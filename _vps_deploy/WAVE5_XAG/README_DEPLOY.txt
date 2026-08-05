========================================================================
ORDER-082 Wave5 (LAB_ENTRY_17) — DEMO DEPLOY BUNDLE — XAGUSD H1
========================================================================
Status:   DEMO-ELIGIBLE (lead-engineer PASS to demo, 2026-07-14). NOT live-certified.

!!! CONTAMINATED SELECTION -- added 2026-07-26 (audit AUDIT_BUNDLE_EVIDENCE_G2.md) !!!
          The "all 6 cells pass" mini-grid (XAGMG_*) scored every MAIN cell on
          2023.01.01 -> 2026.07.01, six months inside the declared 2026H1 holdout. Optimization=0
          on those .ini only means a PowerShell loop drove the grid rather than the tester's
          optimiser -- a ranked grid is selection either way.
          Also: the ORDER-166 re-run of the deployed .set gives 1.33 / 1.24, against the
          1.35 / 1.29 advertised below.
          => the MAIN figure here is not a clean-window number. Demo only (463666728, judge
          2026-10-16); no real money exposed. Do not promote on these numbers.
          Settle it with: the deployed cell on 2023.01.01 -> 2025.12.31, Model 4, full pinned .set.
EA:       Boss_17_Wave5.ex5  (same binary as WAVE5_XAU — Boss V2 template, Entry_17, both directions)
Source:   D:\EA_LAB\ea_template\Boss_17_Wave5.mq5  (+ core/entries/{Entry_Wave5,Wave5Swings}.mqh)
Build:    ex5 from commit bfa048f ; verdict/gates commit 0b4acdbc
Symbol:   XAGUSD (match broker string: XAGUSD / XAGUSDm / XAGUSDc — S6 below)
TF:       H1
Magic:    990302   (free; distinct from XAU instance 990301 — same binary, different symbol+magic)
Set:      WAVE5_XAG_H1_demo_v1.set  (plateau-center fib23.6 / mult0.618, verbatim + magic)

------------------------------------------------------------------------
WHY DEPLOY (evidence — XAG is the STRONGER gold home)
------------------------------------------------------------------------
- XAG mini-grid fib{20,23.6,27} x mult{0.5,0.618} = ALL 6 cells pass both windows:
    MAIN(2023-26) PF 1.30-1.45 / BWD(2020-22) PF 1.28-1.35, trades 161-257, DD 5-6.5% / 2-3%.
    plateau-center fib23.6/mult0.618 = MAIN 1.35 / BWD 1.29.
- Uniform plateau, STRONGER than XAU (XAU BWD 1.0-1.16 vs XAG BWD 1.28-1.35) = own edge, not a spillover.
- Same-EA multi-symbol reuse: correlation gate applies at portfolio level; XAU instance already
    cleared <0.8 vs cohort. Run XAG at the same cohort-standard sizing.
Naked single entry (MaxLevels=1) — NOT a grid/martingale.

------------------------------------------------------------------------
SILENT-STOP PRE-ATTACH CHECKLIST (clear ALL before going live on VPS)
------------------------------------------------------------------------
[S1] TESTER-GATE:  N/A — no MQL_TESTER/AllowLive gate in Boss V2 template (trades on attach).
[S2] RECOMPILE RESET: recompiling reverts inputs to defaults (EntryFib 38.2) -> reload this .set
     after any recompile, in a quiet window.
[S3] LOT/MIN: confirm lot clears broker min on the demo balance (check Experts log after attach).
     NOTE: XAG contract size / tick value differs from XAU — verify the loaded lot is sane for silver.
[S4] EXPIRY/LOCK: none known.
[S5] MAGIC: 990302 unique (XAU sibling = 990301). Keep distinct.
[S6] SYMBOL NAME: confirm the VPS broker's SILVER symbol string (XAGUSD variants).
[S7] SESSION/GMT: not session-gated; ensure clean H1 bars.

------------------------------------------------------------------------
NEXT STEP (user)
------------------------------------------------------------------------
Copy this folder to the VPS, attach Boss_17_Wave5 on an XAGUSD H1 chart in a quiet window,
load WAVE5_XAG_H1_demo_v1.set, confirm lot > 0 and magic 990302 in the Experts log.
Demo->live judge-date protocol applies.
========================================================================
