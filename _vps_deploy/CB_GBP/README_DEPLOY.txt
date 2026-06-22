VPS DEPLOY — (Boss)_LondonConsoBreakout_rev01 on GBPUSD H1  (2026-06-22)
=========================================================================
STATUS: Demo/paper first — see RISK note below before going live.

Files to ship to the VPS:
  (Boss)_LondonConsoBreakout_rev01.ex5   → VPS MQL5\Experts\
  CB_GBP_H1_live_v1.set                  → load as EA inputs after attaching

COMPILE STEP (do ONCE before deploy, on dev machine):
  1. Open MT5 MetaEditor.
  2. Open D:\EA_Project\CURRENT_BUILD\TEMPLATE\(Boss)_LondonConsoBreakout_rev01.mq5
  3. Compile (F7). Confirm 0 errors.
  4. Find the compiled .ex5 in terminal AppData:
       %APPDATA%\MetaQuotes\Terminal\<ID>\MQL5\Experts\
     OR check MetaEditor → Experts list.
  5. Copy that .ex5 to this folder: D:\EA_LAB\_vps_deploy\CB_GBP\

STEPS ON VPS (during market-quiet window, e.g. 22:00-23:30 EET):
  1. Copy (Boss)_LondonConsoBreakout_rev01.ex5 into VPS MQL5\Experts\.
  2. Open GBPUSD H1 chart.
  3. Drag EA onto chart (or Navigator → attach).
  4. In the EA inputs dialog: Load → CB_GBP_H1_live_v1.set.
  5. Confirm _06_AllowLive = true and AutoTrading is ON.
  6. Verify in Experts tab: "(Boss)_LondonConsoBreakout init | AllowLive=YES".

KEY PARAMS (confirmed from IS/OOS):
  Consolidation: 06:00-10:00 EET,  AtrMult=1.0
  SL=2.5×ATR,  TP=2.0×ATR
  LotSize=0.01 (demo size),  Magic=990005

PERFORMANCE SUMMARY:
  IS  2023-2025.06 : PF 1.96, 41 trades, DD 0.10%
  OOS 2025.06-2026 : PF 2.08, 16 trades  ← thin, watch closely
  OOS 2020-2022    : PF 1.25, 45 trades
  MC 5th pct PF   : ~1.10  (passes gate)

RISK NOTE:
  - ST_EA03 GBPUSD H1 is already in the live portfolio (same instrument).
  - Day overlap ~12% (different signal types: compression vs MACD).
  - Size at 0.5% account risk (HALF normal 1%) to limit GBPUSD concentration.
  - OOS1 only 16 trades — treat as DEMO/monitor for first 3 months.
  - Promote to full live only after ≥30 real trades confirm PF ≥ 1.40.

MAGIC NUMBERS in use:
  990001 = (reserved)
  990002 = (Boss)_RSI_Swing_BB_rev01
  990003 = (Boss)_TrendRegression_rev01
  990004 = (Boss)_SessionBreakout_rev01  (DEAD — not deployed)
  990005 = (Boss)_LondonConsoBreakout_rev01  ← THIS EA
  990006 = (Boss)_NRBreakout_rev01  (DEAD — not deployed)
  991001 = EA_BREAKOUT_XAU (live VPS)
