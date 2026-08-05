========================================================================
ORDER-112B  IchiADX USDJPY BASKET — DEMO-ELIGIBLE (thin edge, small-lot) — 2 legs
========================================================================
Status:   DEMO-ONLY data-collection candidate (build-on from ORDER-112 ICHIMOKU revive).
          Positive-expectancy both-window + MC-survive, but THIN (MC PF_5th 1.036) =>
          demo cohort to collect forward data, NOT a strong live leg.
          *** APPROVED for demo cohort by user 2026-07-16B ("เอาเข้าทั้งหมด"); pending user attach. ***
EA:       (EXP)_IchiADX_Naked_rev00.ex5  (bundled here; probe-grade EA)
          MD5 68b349fa6e3029eab6867db58173a2dd
Source:   D:\EA_LAB\ea_projects\(EXP)_IchiADX_Naked\(EXP)_IchiADX_Naked_rev00.mq5
Symbol:   USDJPY   (single symbol, 2 legs = 2 charts, different TF + Ichimoku periods)

  LEG A: USDJPY H4  Magic 990066  Set IchiADX_USDJPY_H4_med_leg_A.set
         Ichimoku 12/34/68 (med periods), ADX>20, ATR-trail 2.5, SL 2.0xATR, flat 0.10
  LEG B: USDJPY H1  Magic 990067  Set IchiADX_USDJPY_H1_slow_leg_B.set
         Ichimoku 20/60/120 (slow periods), ADX>20, ATR-trail 2.5, SL 2.0xATR, flat 0.10

Signal (both legs): fresh Tenkan/Kijun cross ALIGNED with Kumo cloud + ADX>20 + DI dir.
  Single-position, flat lot, NO grid/martingale/recovery. Trend-follower.

------------------------------------------------------------------------
WHY DEPLOY (rescued from a wrong "DEAD"; the 2 legs diversify each other)
------------------------------------------------------------------------
- ORDER-112 overturned "EA_ICHIMOKU DEAD 2026-06-27": that verdict tested XAU (capped) with
  DEFAULT Ichimoku periods and never swept the period lever. On the right home (USDJPY,
  momentum->JPY-trender) with the Kumo-PERIOD lever swept, a real both-window Model-4 plateau
  appears (6/8 cells >1.1).
- The 2 legs lose in DIFFERENT years (med-H4: 2020/2023 down ; slow-H1: 2021/2025 down) =>
  running BOTH diversifies the drawdowns.
- MERGED equity (both @0.10, chronological, Model-4 real ticks, 2020-2026, 357 trades):
      Combined PF 1.339 | net +$1,955 on $10k | TRUE max-DD 6.09% (NOT the sum of the two =>
      the drawdowns are time-separated, confirming diversification).
- MONTE CARLO (2000 resamples of the 357-trade combined sequence):
      PF_5th = 1.036 | DD_95th = 10.77% | Ruin(DD>=30%) = 0%.
- Year-split of the basket: 5 of 6 years positive (only 2020 down -$167, small).

------------------------------------------------------------------------
CAVEATS  (read before deciding to include)
------------------------------------------------------------------------
- THIN EDGE: MC PF_5th 1.036 is barely above 1.0 — a bad-luck sequence is near breakeven.
  This is a SMALL positive expectancy, not a robust one (strong legs sit ~1.3-1.7). Small lot.
- NOT all-years-positive (2020 down) — below the GBPJPY leg-8 bar. Both legs individually are
  4/6 positive; only the BASKET reaches 5/6. Deploy the PAIR or not at all — a single leg is weaker.
- Same signal family + same symbol => the decorrelation is period-driven, could weaken out-of-sample.
  This is exactly what the demo forward-test is meant to check.
- "(EXP)_" EA = probe-grade (its own header says "NOT FOR DEPLOY"). Fine on DEMO for data
  collection; do NOT promote to real money without hardening + more forward data.
- Thin frequency: ~55 trades/yr combined (H4 ~19 + H1 ~35). A few bad trades swing a quarter.

------------------------------------------------------------------------
SILENT-STOP PRE-ATTACH CHECKLIST
------------------------------------------------------------------------
[S1] NO live-gate in this EA (trades in tester AND live/demo identically) => it WILL place
     orders the moment it's attached on a funded (demo) account. Intended for demo only.
[S2] RECOMPILE RESET: recompiling reverts inputs to compiled defaults (Ichimoku 9/26/52,
     Magic 999092). After ANY recompile, re-attach + RELOAD each .set + confirm the periods
     (12/34/68 for A, 20/60/120 for B) AND magic (990066 / 990067) stuck. Wrong periods =
     silently trading the default config, not the validated one.
[S3] magics 990066 / 990067 unique (checked vs DEPLOYMENTS.csv — free). Two DISTINCT magics
     are REQUIRED so the two legs don't cannibalize each other's single-position slot.
[S4] no vendor lock. [S5] symbol USDJPY (match broker suffix, e.g. USDJPYm on the VPS feed).
[S6] LEG A on an H4 chart, LEG B on an H1 chart (the TF is the chart's, not in the .set).
[S7] Bar-open gate is built in (samples once per bar, closed-bar reads, no repaint).

------------------------------------------------------------------------
KILL-SWITCH + NEXT
------------------------------------------------------------------------
- No internal KillDD in this EA. Set an account/equity DD alert 10%, manual KILL 15%
  (MC DD_95th was 10.77%). Judge +3 months from attach.
- Attach both legs, load both .sets, confirm periods + magics stuck + first signals arm.
  Tell Claude the attach date -> register 990066 + 990067 in DEPLOYMENTS.csv + judge date.
- Verdict / evidence: _triage/_archive/verdicts/order104-126/ORDER112_ICHIMOKU_RESCUE_VERDICT.md
  Merged-equity + MC script: _mt5_auto/ichi_basket_merge_mc.ps1
  Reports: _mt5_auto/reports/BASKET_medH4_FULL.htm , BASKET_slowH1_FULL.htm
