========================================================================
ORDER-095 CAMPAIGN — EA_BREAKOUT_XAU expansion — DEMO DEPLOY — USDJPY H4
========================================================================
Status:   DEMO-ELIGIBLE (lead-engineer PASS to demo, 2026-07-14). NOT live-certified.

!!! HOLDOUT SPENT (mild) -- added 2026-07-26 (audit AUDIT_BUNDLE_EVIDENCE_G2.md) !!!
          O095_BRK_USDJPY_H4_MAIN.ini runs 2023.01.01 -> 2026.07.01, so the ship/no-ship decision
          consumed six months of the 2026H1 holdout. No parameter was tuned (53-byte .set,
          compiled defaults), so nothing was selected into the leak.
          Direction of the error is favourable here: the clean re-run is BETTER (1.41 / 65t) than
          the 1.28 / 102t quoted below, so nothing is inflated. Recorded for completeness --
          2026H1 is spent for this leg, its forward evidence starts at attach.
EA:       EA_BREAKOUT_XAU.ex5  (same binary as the live XAU leg magic 991001 — breakout40 /
          ATR1.5-5 SLTP / daily-EMA200 filter / buy-only / fixed lot 0.01)
Source:   D:\EA_LAB\ea_projects\EA_BREAKOUT_XAU\EA_BREAKOUT_XAU.mq5
Symbol:   USDJPY (match broker string exactly — S6 below)
TF:       H4
Magic:    991003   (free; distinct from XAU leg 991001, Squeeze 991004, Trendline 991002)
Set:      EA_BREAKOUT_USDJPY_demo_v1.set  (BuyOnly=true, AllowLive=true, Magic=991003;
          all other inputs = compiled defaults: breakout40/ATR1.5-5/EMA200 — same as the
          validated XAU leg, nothing else changed)

------------------------------------------------------------------------
WHY DEPLOY (evidence — ORDER-095 CAMPAIGN, see _triage/ORDER095_BREAKOUT_XAU_EXPAND_VERDICT.md)
------------------------------------------------------------------------
- Flat-lot smoke = full-config test (this EA has no escalation to strip), both-window H4:
    MAIN(2023-26) PF 1.28 (102 trades) / BWD(2020-22) PF 1.25 (75 trades). DD 0.23-0.35%.
- Correlation vs the live XAU leg (same EA, same mechanism, different symbol): corr = 0.066
    (near-zero) over 19 shared months -> genuinely additive, not redundant exposure.
- XAG/GBP/EUR were tested in the same batch and FAILED (BWD PF 0.56-0.84) -> the breakout
    mechanism does not generalize everywhere; USDJPY specifically clears both windows.

------------------------------------------------------------------------
SILENT-STOP PRE-ATTACH CHECKLIST (clear ALL before going live on VPS)
------------------------------------------------------------------------
[S1] TESTER-GATE: this EA DOES have a real gate — input _06_AllowLive (default false in
     source). The bundled .set sets _06_AllowLive=true explicitly. CONFIRM this loads
     correctly after attach (check Experts log / input dialog) or the EA will sit idle
     with zero trades and no error.
[S2] RECOMPILE RESET: if EA_BREAKOUT_XAU.ex5 is recompiled while a live/demo chart uses it,
     inputs revert to compiled defaults -> AllowLive reverts to FALSE -> EA silently stops.
     Re-attach in a quiet window and reload this .set after any recompile.
[S3] LOT/MIN: fixed lot 0.01 — verify this clears the broker's USDJPY min lot (should be fine,
     0.01 is a standard min) and check the account currency conversion is sane for JPY pip value.
[S4] EXPIRY/LOCK: none known (repo-built EA, no vendor lock).
[S5] MAGIC: 991003 is unique vs the cohort (991001 XAU / 991002 Trendline / 991004 Squeeze).
[S6] SYMBOL NAME: confirm the VPS broker's USDJPY symbol string (USDJPY vs USDJPYm etc).
[S7] SESSION/GMT: not session-gated; H4 breakout logic is fine with any GMT offset, but
     confirm H4 bars are clean/complete on the broker feed.

------------------------------------------------------------------------
NEXT STEP (user)
------------------------------------------------------------------------
Copy this folder to the VPS, attach EA_BREAKOUT_XAU.ex5 on a USDJPY H4 chart in a quiet
window, load EA_BREAKOUT_USDJPY_demo_v1.set, CONFIRM AllowLive=true and magic 991003 in
the Experts log before leaving it unattended. Demo->live judge-date protocol applies.
========================================================================
