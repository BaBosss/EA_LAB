========================================================================
ORDER-095 CAMPAIGN — EA_BREAKOUT_XAU expansion — DEMO DEPLOY — US30 H4
========================================================================
Status:   DEMO-ELIGIBLE, WATCH sizing (lead-engineer PASS to demo, 2026-07-14). NOT live-certified.
EA:       EA_BREAKOUT_XAU.ex5  (same binary as the live XAU leg magic 991001 — breakout40 /
          ATR1.5-5 SLTP / daily-EMA200 filter / buy-only / fixed lot 0.01)
Source:   D:\EA_LAB\ea_projects\EA_BREAKOUT_XAU\EA_BREAKOUT_XAU.mq5
Symbol:   US30 (index CFD — confirm broker's exact symbol string, e.g. US30/US30.cash/US30m — S6)
TF:       H4
Magic:    991005   (free; distinct from XAU leg 991001, Trendline 991002, USDJPY leg 991003, Squeeze 991004)
Set:      EA_BREAKOUT_US30_demo_v1.set  (BuyOnly=true, AllowLive=true, Magic=991005;
          all other inputs = compiled defaults, same as validated XAU leg)

------------------------------------------------------------------------
WHY DEPLOY — WITH A SIZING CAVEAT (see _triage/ORDER095_BREAKOUT_XAU_EXPAND_VERDICT.md)
------------------------------------------------------------------------
- Flat-lot both-window H4: MAIN(2023-26) PF 1.46 (34 trades) / BWD(2020-22) PF 1.39 (26 trades).
    Strongest PF of the whole expansion batch, DD tiny (0.16-0.19%).
- Correlation vs the live XAU leg: corr = -0.249 over 14 shared months -> near-zero / slightly
    negative -> additive, not redundant.
- ⚠️ CAVEAT: only 26-34 total trades per window = THIN SAMPLE. The PF is encouraging but not yet
    statistically solid the way USDJPY's 75-102 trades are. Treat as WATCH: deploy at reduced size
    relative to the XAU/USDJPY legs and let it accumulate live months before trusting the edge.

------------------------------------------------------------------------
SILENT-STOP PRE-ATTACH CHECKLIST (clear ALL before going live on VPS)
------------------------------------------------------------------------
[S1] TESTER-GATE: real gate — input _06_AllowLive (default false). Bundled .set sets it TRUE.
     CONFIRM after attach (Experts log) or the EA idles silently with no trades, no error.
[S2] RECOMPILE RESET: recompiling EA_BREAKOUT_XAU.ex5 while a chart uses it reverts inputs to
     compiled defaults -> AllowLive reverts FALSE. Re-attach in a quiet window + reload this .set.
[S3] LOT/MIN: fixed lot 0.01 on an INDEX CFD — index contract sizing / margin per lot can be very
     different from FX/metals. VERIFY 0.01 is valid and the margin requirement is sane for this
     account size before attaching; index CFDs sometimes have a much larger min lot or margin per
     unit than 0.01 implies for FX. Check the broker's contract spec for this symbol first.
[S4] EXPIRY/LOCK: none known.
[S5] MAGIC: 991005 unique vs the rest of the cohort.
[S6] SYMBOL NAME: index symbol strings vary a lot by broker (US30 / US30Cash / US30.cash / DJ30 /
     USA30). Confirm the exact string on this broker before attaching — a near-miss name will
     simply fail to find the symbol / not have a chart, no trades and possibly no clear error.
[S7] SESSION/GMT: indices have their own trading-session windows (may be closed weekends/holidays
     differently than FX) — confirm the broker's US30 session hours don't conflict with any
     scheduled maintenance/weekend-cut logic elsewhere in the account's EA stack.

------------------------------------------------------------------------
NEXT STEP (user)
------------------------------------------------------------------------
Copy this folder to the VPS, attach EA_BREAKOUT_XAU.ex5 on a US30 H4 chart in a quiet window,
load EA_BREAKOUT_US30_demo_v1.set, CONFIRM AllowLive=true, magic 991005, and a sane lot/margin
for the index contract in the Experts log before leaving it unattended. Size conservatively
(WATCH tier) until more live months accumulate. Demo->live judge-date protocol applies.
========================================================================
