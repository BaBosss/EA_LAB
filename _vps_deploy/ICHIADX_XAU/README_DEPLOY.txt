========================================================================
ORDER-112E  IchiADX XAUUSD (slow periods) — ADDITIVE XAU LEG — reduced-lot
========================================================================
Status:   DEMO-ELIGIBLE — real both-window edge (PF 1.57 full-window, Sharpe 3.0). Strongest
          find of 2026-07-16B. APPROVED for demo (user "เอาเข้าทั้งหมด"). DEMO = confirm it
          works forward, run NORMAL lot. (Corr numbers below are for the future live decision,
          NOT a demo gate.) Pending user attach.
EA:       (EXP)_IchiADX_Naked_rev00.ex5  (bundled; probe-grade EA, demo-only)
          MD5 68b349fa6e3029eab6867db58173a2dd
Source:   D:\EA_LAB\ea_projects\(EXP)_IchiADX_Naked\(EXP)_IchiADX_Naked_rev00.mq5
Symbol:   XAUUSD   TF: H1   Magic: 990068   Set: IchiADX_XAUUSD_H1_slow.set
Config:   Ichimoku 20/60/120 (slow periods), ADX>20, ATR-trail 2.5, SL 2.0xATR, flat 0.10
Signal:   fresh Tenkan/Kijun cross ALIGNED with Kumo cloud + ADX>20 + DI dir. Single-position,
          flat lot, NO grid/martingale. Trend-follower.

------------------------------------------------------------------------
WHY DEPLOY (overturned "XAU Ichimoku ceiling 1.13" + additive to the book)
------------------------------------------------------------------------
- ORDER-112 revived ICHIMOKU on USDJPY via the Kumo-PERIOD lever (the 2026-06-27 "DEAD" and
  the "XAU ceiling 1.13" were both DEFAULT-period 9/26/52 only). Applying the tuned periods to
  XAU (ORDER-112C/D) surfaced a real both-window edge that the default test missed.
- BOTH-WINDOW Model-4 (slow periods): MAIN(2023-26) 1.66 / BWD(2020-22) 1.39. medH4 config was
  even higher (3.94/1.25) but thinner + MAIN gold-bull-inflated; slow-H1 chosen = healthier sample.
- FULL 2020-2026 Model-4: PF 1.57, 236 trades (~36/yr), Sharpe 3.0, net +$7,038 on $10k.
- YEAR-SPLIT: 5 of 6 years positive (2020 2.15 / 2021 0.84 down / 2022 1.25 / 2023 1.36 /
  2024 1.10 / 2025 2.25). Only 2021 down, modest.
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
- 2021 was the one down year (0.84). MAIN window partly rides the 2023-25 gold bull.
- (Live-only) corr max 0.646 vs SuperTrend — when this goes to real money, size it so it doesn't
  just double gold-trend exposure. Irrelevant for demo.
- OPTIONAL 2nd leg (basket): medH4 config (12/34/68 H4, 6/6 yrs >=0.99, thin 8-20t/yr) loses in
  DIFFERENT years than slow-H1 -> a 2-leg XAU basket would smooth further. Not corr-checked yet;
  add only after its own corr pass. Magic 990069 reserved if pursued.

------------------------------------------------------------------------
SILENT-STOP PRE-ATTACH CHECKLIST
------------------------------------------------------------------------
[S1] NO live-gate in this EA => places orders the moment attached on a funded (demo) account.
[S2] RECOMPILE RESET: recompiling reverts inputs to defaults (Ichimoku 9/26/52, Magic 999092).
     After ANY recompile: re-attach + RELOAD .set + confirm periods 20/60/120 AND Magic 990068 stuck.
     Wrong periods = silently trading the default (dead) config.
[S3] magic 990068 unique (checked vs DEPLOYMENTS.csv). [S4] no vendor lock.
[S5] symbol XAUUSD (match broker suffix). [S6] H1 chart. [S7] bar-open gate built in.

------------------------------------------------------------------------
KILL-SWITCH + NEXT
------------------------------------------------------------------------
- No internal KillDD. Account/equity DD alert 8%, manual KILL 12% (full-window DD ~ small; MC not
  run on this cell — run before any lot increase). Judge +3 months from attach.
- Attach on XAUUSD H1, load this .set, confirm periods + magic 990068 + first signal arms.
  Tell Claude the attach date -> register 990068 in DEPLOYMENTS.csv + judge date.
- Evidence: _triage/ORDER112_ICHIMOKU_RESCUE_VERDICT.md (ORDER-112C/D/E sections)
  Corr script: _mt5_auto/ichi_xau_corr.ps1 | Reports: _mt5_auto/reports/CORR_*_XAU.htm
