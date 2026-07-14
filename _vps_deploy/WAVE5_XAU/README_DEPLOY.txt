========================================================================
ORDER-082 Wave5 (LAB_ENTRY_17) — DEMO DEPLOY BUNDLE — XAUUSD H1
========================================================================
Status:   DEMO-ELIGIBLE (lead-engineer PASS to demo, 2026-07-14). NOT live-certified.
EA:       Boss_17_Wave5.ex5  (Boss V2 template, Entry_17 = Elliott wave-4 retrace, both directions)
Source:   D:\EA_LAB\ea_template\Boss_17_Wave5.mq5  (+ core/entries/{Entry_Wave5,Wave5Swings}.mqh)
Build:    ex5 from commit bfa048f ; verdict/gates commit 0b4acdbc
Symbol:   XAUUSD (match broker string: XAUUSD / XAUUSDm / XAUUSDc — S6 below)
TF:       H1
Magic:    990301   (free; cohort uses 990101/991001/991002/991004/990207)
Set:      WAVE5_XAU_H1_demo_v1.set  (locked plateau-center fib23.6 / mult0.618, verbatim + magic)

------------------------------------------------------------------------
WHY DEPLOY (evidence — all gates cleared)
------------------------------------------------------------------------
- Plateau (not spike): XAU H1 both-window pass block fib23.6->30 x all mults.
    plateau-center fib23.6/mult0.618 = MAIN(2023-26) PF 1.11 / BWD(2020-22) PF 1.11.
- Robust across TF: XAU H4 @ fib23.6 = MAIN 1.74 / BWD 1.01 (window never used to select).
- Monte Carlo (5000 iters, $10k): ruin 0.00%, P(net<0) 0.0%, DD worst 7.97% MAIN / 4.43% BWD.
- Gold-class: XAG silver mini-grid all 6 cells both-window (see WAVE5_XAG bundle).
- Correlation vs live gold cohort: max |corr| 0.415 << 0.8 (additive, not redundant).
Naked single entry (MaxLevels=1) — NOT a grid/martingale. Modest edge (PF ~1.1) but regime-general.

------------------------------------------------------------------------
SILENT-STOP PRE-ATTACH CHECKLIST (clear ALL before going live on VPS)
------------------------------------------------------------------------
[S1] TESTER-GATE:  N/A — Boss V2 template has NO MQL_TESTER/AllowLive gate. The EA
     trades live immediately on attach; there is no flag to enable. (Confirmed: no
     tester-gate input in core.) Nothing to set — but that also means: attach only
     when you intend it to trade.
[S2] RECOMPILE RESET: if you recompile Boss_17_Wave5 while a live chart uses it, inputs
     revert to compiled defaults (EntryFib 38.2, not 23.6) -> WRONG config silently.
     After any recompile, re-attach in a quiet window and RELOAD this .set.
[S3] LOT/MIN: verify the template's lot-sizing clears broker min (0.01) on the demo
     account balance. Check the loaded lot in the Experts log after attach.
[S4] EXPIRY/LOCK: none known (repo-built template, no vendor lock).
[S5] MAGIC: 990301 is unique vs the cohort — keep it; do not reuse another EA's magic.
[S6] SYMBOL NAME: confirm the VPS broker's gold symbol string matches the chart you attach.
[S7] SESSION/GMT: Wave5 is NOT session-gated (structure-based), so GMT offset is not
     critical — but the fib/wave logic reads closed bars, so ensure H1 bars are clean.

------------------------------------------------------------------------
NEXT STEP (user)
------------------------------------------------------------------------
Copy this folder to the VPS, attach Boss_17_Wave5 on an XAUUSD H1 chart in a market-quiet
window, load WAVE5_XAU_H1_demo_v1.set, confirm lot > 0 and magic 990301 in the Experts log.
Demo->live judge-date protocol applies (standard cohort judge date).
========================================================================
