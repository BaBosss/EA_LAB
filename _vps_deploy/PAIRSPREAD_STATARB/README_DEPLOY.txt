========================================================================
PairSpread_StatArb — DEMO deploy bundle (ORDER-098-G/H)
========================================================================
Status : DEMO ONLY — CANDIDATE_WEAK (not standalone-live approved).
         Small-weight diversifier leg, data-collection on demo.
Built  : 2026-07-17  (Claude, Opus)
Source : ea_projects/(EXP)_PairSpreadArb/PairSpread_StatArb.mq5
Binary : PairSpread_StatArb.ex5 (34,300 bytes)
Git    : commit 03424a39 (repo D:\EA_LAB)

------------------------------------------------------------------------
WHAT IT IS
------------------------------------------------------------------------
Pairs-spread statistical arbitrage (mean-reversion). Two correlated
symbols; spread = log(EURUSD) - log(GBPUSD); rolling z-score (window 100).
When |z| > EntryZ: fade the spread — SELL the rich leg / BUY the cheap leg
(2-leg hedged basket, equal flat lots). Exit when |z| < ExitZ (mean revert)
OR |z| > StopZ (z-stop cage). One basket at a time, no martingale.
NEW diversifier class (pairs mean-reversion) — orthogonal to the
momentum/grid/breakout book (corr-check: max +0.36 vs cohort, ADDITIVE).

------------------------------------------------------------------------
LOCKED CONFIG  (set: PAIRSPREAD_EURGBP_H4_demo_v1.set)
------------------------------------------------------------------------
Symbols : EURUSD (leg A / chart) + GBPUSD (leg B)   ** attach chart = EURUSD H4 **
TF      : H4
EntryZ 2.5 / ExitZ 0.3 / ZWindow 100 / StopZ 3.5
Lots    : 0.05 + 0.05 (small — candidate sizing; raise only after demo track)
Magic   : 990984
Account : ** HEDGING required ** (2 opposing legs held simultaneously)

------------------------------------------------------------------------
WHY DEPLOY (validation, ORDER-098-G/H)
------------------------------------------------------------------------
Locked ExitZ0.3 config (edge-thickened from the original ExitZ0.5 candidate):
  both-window PF : MAIN 1.14 / BWD 1.15   (2023-26 / 2020-22)
  true holdout   : PF 1.23  (2017-2019, never used to select)
  plateau        : ExitZ 0.2/0.3/0.4 neighbors all hold (not a spike)
  Monte Carlo    : ruin 0%, obs PF 1.141, OoS date-split PF 0.917
  caveat         : bootstrap PF_5th 0.75 (< 0.8) = edge real but thin tail
                   -> CANDIDATE_WEAK, small size, watch. NOT live-approved.
  corr-check     : additive vs cohort (hedges MACD/MG_v1); watch-item =
                   DD-timing overlap 69% with ST03_replica (both GBP mean-rev).
Full verdict: _triage/_archive/verdicts/order076-098/ORDER098F_PAIRSPREAD_STATARB_VERDICT.md

------------------------------------------------------------------------
SILENT-STOP PRE-ATTACH CHECKLIST  (clear ALL before it will trade)
------------------------------------------------------------------------
[S1] AllowLive = true in the loaded .set  -> SET (this .set has it). Without it
     MQL_TESTER is false on a live chart and the EA trades nothing.
[S2] After ANY recompile of the binary a live chart uses -> re-attach in a
     quiet window + reload this .set (inputs reset to compiled defaults =
     AllowLive flips false).
[S3] Lot vs broker min: 0.05 >> 0.01 min -> OK (fixed lot, no cent-balance math).
[S4] Expiry/lock: none in source -> OK.
[S5] Magic 990984 unique (checked free vs DEPLOYMENTS.csv 2026-07-17).
[S6] Symbol strings: broker must expose EURUSD AND GBPUSD exactly (watch .r/.m
     suffixes). BOTH legs' history/quotes must be live or the basket never arms.
[S7] N/A (no session-hours logic).
EXTRA (multi-symbol): the EA pulls SymbolB (GBPUSD) data internally — confirm
     GBPUSD is in Market Watch on the VPS or leg B won't compute.

------------------------------------------------------------------------
ATTACH STEPS (VPS, demo account)
------------------------------------------------------------------------
1. Copy PairSpread_StatArb.ex5 -> VPS  <DataDir>\MQL5\Experts\
2. Ensure EURUSD + GBPUSD both in Market Watch.
3. Open EURUSD H4 chart -> drag EA on -> load PAIRSPREAD_EURGBP_H4_demo_v1.set
4. Confirm AllowLive=true, AutoTrading on, "smiley" active.
5. Report attach date -> Claude records DEMO_DEPLOYMENT_PLAN + judge +3 months.
========================================================================
