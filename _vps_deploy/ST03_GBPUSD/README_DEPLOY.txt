============================================================
EA_RUNNER_ST03  —  GBPUSD H1  —  LR2 winner @ 1x
Deploy bundle  (built 2026-06-26)

!!! SUPERSEDED -- DO NOT DEPLOY ON THIS EVIDENCE (added 2026-07-26) !!!
    Audit AUDIT_BUNDLE_EVIDENCE_G1.md sec.3. The windows here are CLEAN (2024 only), so
    nothing was fitted -- but the headline "IS 8.31 / OOS 3.93 -> DEPLOY SMALL" was replaced
    in the registry by PF 0.86 over 585 trades, the loop was closed, and this EA was PULLED
    OFF the real account on 2026-07-18. This README is the only place still selling it.
    Treat as historical. A new deploy decision starts from the registry, not from here.
============================================================

WHAT THIS IS
  Framework-controlled standalone of the ST_EA03 "MACD count + tiered-TP OCO
  scalp" (mean-reversion harvester). This is a REPLICA of the already-live
  ST_EA03 GBPUSD, so DO NOT run it in the same account/portfolio as the live
  fxDreema ST_EA03 GBPUSD (they are the same edge = correlated). Use it as a
  framework-owned alternative, or on a SEPARATE account/portfolio.

PROVENANCE
  Source .mq5 : D:\EA_Project\CURRENT_BUILD\TEMPLATE\EA_RUNNER_ST03.mq5
  EA code commit (EA_Project): a221213  (vol-gate added, default OFF)
  Data/registry commit (EA_LAB): 043d338
  Locked set used in validation: D:\EA_LAB\_mt5_auto\ST03_optimized_v2.set
  Live set in this bundle      : ST03_GBPUSD_live_v1.set  (= validation set +
                                  InpAllowLiveOrders=true)

CONFIG (LR2 winner)
  Symbol/TF   : GBPUSD H1
  LotRepeat=2 (2-leg OCO) | tp3=50 (5pip group TP) | near=50 (5pip ladder)
  No stop-loss (by design — the edge IS the no-SL reversion wait)
  Sizing      : InpLotSizerBase=0.01 FIXED (1x). DO NOT size up (see WHY below).
  Magic       : 990010

VALIDATION  (Model 4 real-tick, GBPUSD H1)
  IS  2024.01-03 : PF 8.31
  OOS 2024.09-11 : PF 3.93  (no degradation)
  Monte Carlo (229 calm trades): PF 5th 2.92, ruin 0% (but PF-range 20.5 = wide)
  VERDICT: robustness MARGINAL  ->  DEPLOY SMALL + LIVE-MONITOR first 30 trades.

WHY 1x ONLY  (do not increase lot)
  Edge is CALM-ONLY: every real crisis is PF<1 (no-SL tail). At 12x the 2022
  crisis = 14% DD and Brexit-2016-type ~42%. The tail CANNOT be filtered out
  (vol-gate = gap-spikes only; ADX trend-gate FALSIFIED/counterproductive; hard
  SL kills the edge). So 1x small size is the only safe deploy. WFA 4/6 windows
  profitable and 2025H1 was WEAK -> watch live, it is regime-dependent.

OPTIONAL VARIANT
  ST03_volgate_v1.set (in _mt5_auto) turns on InpVolGateOn (ATR>1.5xATR_MA(300)).
  Cheap GAP insurance only (saved Brexit -218->+94) at ~0 calm cost; does NOT fix
  trend crises. Use if you want gap protection; otherwise the plain set is fine.

============================================================
SILENT-STOP CHECKLIST  —  clear ALL before going live
(these all backtest fine then trade NOTHING live)
============================================================
[S1] AllowLiveOrders : live set has InpAllowLiveOrders=true. VERIFIED in this
     bundle's .set. (In the tester it trades regardless; on a live chart false =
     zero trades. This is the #1 "deployed, no trades" cause.)
[S2] RECOMPILE RESET : if you recompile this EA's source, the chart auto-reloads
     and inputs revert to DEFAULTS (AllowLiveOrders=false) -> it silently stops.
     After any recompile, re-attach in a quiet window and RELOAD this .set.
[S3] LOT >= BROKER MIN : base 0.01 FIXED -> fine (not balance-derived). On a CENT
     account 0.01 is also fine.
[S4] EXPIRY/LOCK : none (framework EA, no expiry).
[S5] MAGIC UNIQUE : 990010 must be unique on the target account; in particular
     NOT shared with the live ST_EA03 GBPUSD (would mix position bookkeeping).
[S6] SYMBOL NAME : confirm broker's symbol string is exactly GBPUSD (not
     GBPUSD.r / GBPUSDm). Mismatch = no chart = no trades.
[S7] N/A : no session/GMT filter active (InpSessionFilter=false).

============================================================
NEXT STEP
  Copy this folder to the VPS. Attach EA_RUNNER_ST03 on a GBPUSD H1 chart in a
  market-quiet window, load ST03_GBPUSD_live_v1.set, confirm InpAllowLiveOrders=
  true and the checklist above, then enable AutoTrading. Monitor first 30 trades
  against the backtest expectation (use the ea-live-monitor skill).
============================================================
