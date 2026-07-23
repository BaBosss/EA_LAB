RSI-MR (Boss)_RSI_MR_GridLog_rev01 -- DEMO-ISOLATE bundle
============================================================
Prepared: 2026-07-23 by Claude (Opus-seat)
Source: D:\EA_LAB\ea_projects\(Boss)_RSI_MR_GridLog\(Boss)_RSI_MR_GridLog_rev01.mq5
        (unchanged since 2026-07-08 -- NOT recompiled today, .ex5 reused as-is)
Symbol/TF: EURUSD H1
Magic: 990103
Set file: RSIMR_EURUSD_H1_demo_v1.set  (locked -- do not hand-edit; regenerate
          from D:\EA_LAB\_mt5_auto\ab_sets\rsimr_fan\RSIMR_CENTER.set if changed,
          only difference vs that file is _07_AllowLive=true)

---------------------------------------------------------------
IMPORTANT HISTORY -- READ BEFORE ATTACHING
---------------------------------------------------------------
This EA was previously LIVE on a REAL account (159503454 "Blazing Arrow") and
was REMOVED on 2026-07-18 for hitting the 25% closed-DD kill trigger. This
bundle is a RE-VALIDATED config, not a first-time deploy. The project record
(DEMO_DEPLOYMENT_PLAN.md) flags demo-isolate re-attach as an OPTIONAL step,
not a default action -- this bundle exists so that option is ready, not to
imply the decision has already been made.

---------------------------------------------------------------
RE-VALIDATION EVIDENCE (ORDER-182 through 186, 2026-07-23, commits
3242a91 / 99ec44f / 0f0138f / fd46c2b / 91376d9)
---------------------------------------------------------------
Methodology note: the EA is a genuine dual-side BASKET/grid (MaxPositions=8,
LOG-lot escalation) -- all numbers below are from CONTINUOUS single-span
backtests, not the stitched-window WFA the original 2026-07-08 validation used
(stitched windows are known to lie for basket EAs -- see ORDER-182).

  Window          PF      Trades   DD%    Notes
  MAIN 2023-25    1.96    216      4.99   both-window plateau, not a spike
  BWD  2020-22    1.56    199      5.48   (sensitivity fan: 8/8 variants
                                           stay PF>1 both windows, none flip
                                           negative -- cleanest fan of the
                                           whole 2026-07-23 session)
  Flat-lot MAIN   1.33    163      1.57   entry itself has real edge
  Flat-lot BWD    0.82    159      4.12   escalation needed under trend stress
  MC (5000 iter)  PF-5th MAIN 1.544 / BWD 1.209 -- both clear "comfortable"
                  ruin 0% both windows
  Basket duration max: MAIN 98.4 days / BWD 182.1 days (improved from the
                  pre-tuning baseline's 159/292 days, but still a multi-month
                  worst-case capital lockup -- size accordingly)

  HOLDOUT 2026H1: PF 0.76, n=21 trades -- FAILS the >=1.0 bar.
  Confirmed on TWO independent configs (old baseline 0.73/n=26, this new
  center 0.76/n=21) landing at the same result -- this is a real regime
  weakness in 2026H1, not something tunable away. This is the one gate
  the VERDICT GATE tree does not let pass: holdout <1.0 formally routes back
  to "diagnosis", kept alive here only via the BUILD-ON exception (edge
  proven elsewhere). It is NOT a validated CANDIDATE.

VERDICT: BUILD-ON, not CANDIDATE. Everything the pipeline can check without
live/forward data checks out; the live-forward record itself is the missing
evidence. This bundle is offered as a documented option, not a recommendation
to attach on the same footing as a validated candidate.

---------------------------------------------------------------
PRE-ATTACH CHECKLIST (vps-deploy-ops silent-stop list)
---------------------------------------------------------------
[S1] TESTER-GATE: _07_AllowLive=true is set in this .set (confirmed above).
     On a live/demo chart MQL_TESTER is false, so this MUST stay true.
[S2] RECOMPILE RESET: do not recompile this EA's source without re-attaching
     afterward in a quiet window and reloading this .set (inputs revert to
     compiled defaults on recompile).
[S3] CENT LOT: this EA uses fixed/escalating lot from _05_BaseLot=0.01, not
     balance-derived Lots_divided sizing -- no cent-lot-below-min risk.
[S4] EXPIRY/LOCK: source is ours (not a locked/expiring third-party binary) --
     n/a.
[S5] MAGIC UNIQUENESS: 990103 was freed when removed from 159503454 on
     2026-07-18 -- confirm no other currently-active EA has claimed 990103
     in portfolio/DEPLOYMENTS.csv before attaching.
[S6] SYMBOL NAME: confirm the broker's exact symbol string (EURUSD vs
     EURUSD.r/EURUSDm/EURUSDc suffix) matches what this account uses.
[S7] SESSION HOURS: this EA is not session-gated (RSI mean-reversion, no
     London/NY time window) -- n/a.
[HEDGE] This EA REQUIRES a hedging-mode account (holds simultaneous BUY and
     SELL baskets) -- confirm the target account is Hedge mode, not Netting.

---------------------------------------------------------------
NEXT STEP (per vps-deploy-ops FINAL RULE)
---------------------------------------------------------------
Bundle staged here, not yet copied to any VPS/account.
If proceeding: copy this folder to the target demo account's terminal,
attach in a market-quiet window, load RSIMR_EURUSD_H1_demo_v1.set, confirm
_06_AllowLive... (checklist above), THEN add a DEPLOYMENTS.csv row and
pre-register judge criteria before calling it attached.
This document does not update DEPLOYMENTS.csv or claim the EA is running --
that only becomes true once a human actually attaches it on an account.
