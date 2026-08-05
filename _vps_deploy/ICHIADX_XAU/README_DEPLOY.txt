========================================================================
ORDER-112E/F  IchiADX XAUUSD BASKET (2 legs) — strongest find of 2026-07-16B
========================================================================
Status:   DEMO-ELIGIBLE — real both-window edge, 2-leg basket = 6/6 years positive, MC PF_5th
          1.544 (robust, NOT thin). APPROVED for demo (user "เอาเข้าทั้งหมด"). DEMO = confirm it
          works forward, run NORMAL lot. (Corr numbers below are for the future live decision,
          NOT a demo gate.) Pending user attach.
EA:       (EXP)_IchiADX_Naked_rev00.ex5  (bundled; probe-grade EA, demo-only)
          MD5 68b349fa6e3029eab6867db58173a2dd
Source:   D:\EA_LAB\ea_projects\(EXP)_IchiADX_Naked\(EXP)_IchiADX_Naked_rev00.mq5
Symbol:   XAUUSD   (2 legs = 2 charts, different TF + Ichimoku periods)

  LEG A: XAUUSD H1  Magic 990068  Set IchiADX_XAUUSD_H1_slow.set
         Ichimoku 20/60/120 (slow), full-window PF 1.57 / 236t / Sharpe 3.0 / 5-of-6 yrs+ (2021 down)
  LEG B: XAUUSD H4  Magic 990069  Set IchiADX_XAUUSD_H4_med.set
         Ichimoku 12/34/68 (med), full-window PF 2.85 / 97t / Sharpe 2.76 / 6-of-6 yrs >=0.99

Signal (both): fresh Tenkan/Kijun cross ALIGNED with Kumo cloud + ADX>20 + DI dir. Single-position,
  flat lot, NO grid/martingale. Trend-follower. The 2 legs are weak in DIFFERENT years (slow-H1 down
  2021; med-H4 breakeven 2020/2022) -> the basket smooths to all-years-positive.

MERGED (both @0.10, chronological, Model-4 2020-2026, 333 trades):
  Combined PF 2.143 | net +$22,407 on $10k | TRUE max-DD 10.5% | ALL 6 years net-positive.
  MC (2000 resamples): PF_5th 1.544 | DD_95th 22.19% | Ruin(DD>=30%) 1.2%.
  => Much more robust than the USDJPY IchiADX basket (PF_5th 1.036). This is the session's best.

------------------------------------------------------------------------
WHY DEPLOY (overturned "XAU Ichimoku ceiling 1.13" + additive to the book)
------------------------------------------------------------------------
- ORDER-112 revived ICHIMOKU on USDJPY via the Kumo-PERIOD lever (the 2026-06-27 "DEAD" and
  the "XAU ceiling 1.13" were both DEFAULT-period 9/26/52 only). Applying the tuned periods to
  XAU (ORDER-112C/D) surfaced a real both-window edge that the default test missed.
- BOTH-WINDOW Model-4 (slow periods): MAIN(2023-26) 1.66 / BWD(2020-22) 1.39. medH4 config was
  even higher (3.94/1.25) but thinner + MAIN gold-bull-inflated; slow-H1 chosen = healthier sample.
- FULL 2020-2026 Model-4: PF 1.57, 236 trades (~36/yr), Sharpe 3.0, net +$7,038 on $10k.
- YEAR-SPLIT per leg: slow-H1 5/6 yrs+ (2021 0.84 down); med-H4 6/6 yrs >=0.99. Combined net per
  year (both legs) = ALL 6 years positive (2020 +1448 / 2021 +394 / 2022 +330 / 2023 +1455 /
  2024 +412 / 2025 +6247) — each leg covers the other's weak year.
- CORRELATION (monthly Pearson) vs the saturated XAU book — FOR THE FUTURE LIVE DECISION, NOT a
  demo gate (user 2026-07-16B: corr isn't needed for demo; demo confirms the EA works, corr-based
  sizing/cutting is a real-money call):
      vs BRK_XAU 0.263 (LOW) | vs KAUFMAN 0.574 | vs SuperTrend 0.646
  Low enough that it's genuinely additive (SuperTrend was 0.724). On DEMO: run at NORMAL lot to
  confirm forward performance. Apply corr-based sizing only if/when promoting to real money.

------------------------------------------------------------------------
CAVEATS
------------------------------------------------------------------------
- "(EXP)_" EA = probe-grade (its header says "NOT FOR DEPLOY"). Fine on DEMO for data collection;
  harden before any real-money promotion.
- "(EXP)_" EA = probe-grade; demo-only. Both legs ride the 2023-25 gold bull in the MAIN window
  (part of the strong PF) — the BWD window + year-split show the edge predates the bull, but size
  for a gold-trend regime.
- Combined MC DD_95th 22% (true max-DD 10.5%) — deeper than the USDJPY basket; sensible account DD
  alert ~12%, KILL ~18%. Ruin 1.2% (nonzero — a bad-luck run of the med-H4 leg can bite).
- (Live-only) corr max 0.646 vs SuperTrend — at real money size so it doesn't just double gold
  exposure. Irrelevant for demo (run normal lot to confirm forward).

------------------------------------------------------------------------
SILENT-STOP PRE-ATTACH CHECKLIST (both legs)
------------------------------------------------------------------------
[S1] NO live-gate in this EA => places orders the moment attached on a funded (demo) account.
[S2] RECOMPILE RESET: recompiling reverts inputs to defaults (Ichimoku 9/26/52, Magic 999092).
     After ANY recompile: re-attach + RELOAD each .set + confirm periods (LEG A 20/60/120,
     LEG B 12/34/68) AND magics (990068 / 990069) stuck. Wrong periods = trading the dead default.
[S3] magics 990068 / 990069 unique + DISTINCT (checked vs DEPLOYMENTS.csv) so the two legs don't
     share the single-position slot. [S4] no vendor lock. [S5] symbol XAUUSD (match broker suffix).
[S6] LEG A on an H1 chart, LEG B on an H4 chart. [S7] bar-open gate built in.

------------------------------------------------------------------------
KILL-SWITCH + NEXT
------------------------------------------------------------------------
- No internal KillDD. Account/equity DD alert 12%, manual KILL 18% (combined MC DD_95th 22%).
  Judge +3 months from attach.
- Attach LEG A (XAUUSD H1) + LEG B (XAUUSD H4), load each .set, confirm periods + magics + first
  signals arm. Tell Claude the attach date -> register 990068 + 990069 in DEPLOYMENTS.csv + judge.
- Evidence: _triage/_archive/verdicts/order104-126/ORDER112_ICHIMOKU_RESCUE_VERDICT.md (ORDER-112C/D/E/F sections)
  Merge+MC: _mt5_auto/xau_basket_merge_mc.ps1 | Corr: _mt5_auto/ichi_xau_corr.ps1
  Corr script: _mt5_auto/ichi_xau_corr.ps1 | Reports: _mt5_auto/reports/CORR_*_XAU.htm
