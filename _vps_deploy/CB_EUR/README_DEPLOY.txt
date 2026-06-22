VPS DEPLOY — (Boss)_LondonConsoBreakout_rev01 on EURUSD H1  (2026-06-22)
=========================================================================
STATUS: ⚠️ CONDITIONAL — deploy with close monitoring (see risk note)

Files to ship to the VPS:
  (Boss)_LondonConsoBreakout_rev01.ex5   → VPS MQL5\Experts\  (same binary as CB_GBP)
  CB_EUR_H1_live_v1.set                  → load as EA inputs after attaching

NOTE: .ex5 is identical to CB_GBP — same file, different symbol chart.
If CB_GBP is already deployed, skip copying the .ex5 (already there).

STEPS ON VPS (during market-quiet window, e.g. 22:00–23:30 EET):
  1. .ex5 already in VPS MQL5\Experts\ from CB_GBP deploy → skip copy if done.
  2. Open EURUSD H1 chart.
  3. Drag EA onto chart (or Navigator → attach).
  4. In the EA inputs dialog: Load → CB_EUR_H1_live_v1.set.
  5. Confirm _06_AllowLive = true and AutoTrading is ON.
  6. Verify in Experts tab: "(Boss)_LondonConsoBreakout init | AllowLive=YES".

MAGIC NUMBER NOTE:
  Magic=990005 (same as CB_GBP on GBPUSD H1). NO conflict — EA filters by
  symbol internally. Both can run simultaneously on different charts. ✅

KEY PARAMS (IS leader, plateau center):
  Consolidation: 06:00-11:00 EET,  AtrMult=1.5  (wider window than GBP)
  SL=2.0×ATR,  TP=4.0×ATR  (higher R:R than GBP)
  LotSize=0.01,  Magic=990005

PERFORMANCE SUMMARY:
  IS  2023-2025.06 : PF 2.09, 66 trades, DD 0.13%
  OOS 2025.06-2026 : PF 1.25, 33 trades
  OOS 2020-2022    : PF 0.86, 90 trades  ← FAILS (EUR bear 2022 crash)
  FULL 2020-2026   : PF 1.26, 189 trades

⚠️ RISK NOTE — WHY CONDITIONAL:
  EUR/USD dropped -22% in 2022 (1.23 → 0.96). Strong persistent downtrend
  suppresses win rate from 57% → 39% (90 trades = statistically real failure).
  This is a known regime weakness, not a sample-size fluke.
  CB_GBP passed the same window (GBPUSD more volatile/mean-reverting = safer).

STOP RULES (pause EA immediately if either triggers):
  1. Monthly DD > 1% (account equity, not just this EA)
  2. 10 consecutive losses
  3. Any sustained EUR bearish macro trend (rate divergence, crisis)

COMPARE TO CB_GBP:
  CB_GBP: 3/3 OOS pass, promote to full 1% risk after 30 trades
  CB_EUR: 2/3 OOS pass, keep at 0.01 lot, review monthly — do NOT increase size

MAGIC NUMBERS in use across all standalone EAs:
  990005 = (Boss)_LondonConsoBreakout_rev01  (CB_GBP GBPUSD + CB_EUR EURUSD)
  990006 = (Boss)_NRBreakout_rev01  (DEAD — not deployed)
  991001 = EA_BREAKOUT_XAU (live VPS)
