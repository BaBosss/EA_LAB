========================================================================
ORDER-109 Zeus AUDJPY + Regime-gate — DEMO DEPLOY BUNDLE — AUDJPY H1
========================================================================
Status:   DEMO-EXPERIMENT candidate (regime-rescue #1, lead 2026-07-16). NOT live-certified.
          AUDJPY-SPECIFIC. ⚠️ CARRIES A KNOWN WEAK YEAR (2023) — see CAVEAT. Deploy small.
EA:       (Boss)_ZeusInspired_GridLog_rev01.ex5  (Zeus ATR-grid + LOG-lot, now with the _50_
          Regime.mqh gate grafted in — range-only mode is what rescues AUDJPY)
Source:   D:\EA_LAB\ea_projects\(Boss)_ZeusInspired_GridLog\(Boss)_ZeusInspired_GridLog_rev01.mq5
          (+ Regime_Standalone.mqh in the same folder — needed to recompile)
Build:    ex5 2026-07-16, MD5 00E45B86176BA65DF69296ACAE3DFB40
Symbol:   AUDJPY   TF: H1   Magic: 990110   Set: ZeusAUDJPY_regime_demo_v1.set

Config (Model-4 confirmed): Zeus BUY-side ATR grid (dist 2.2xATR, LOG-lot base 0.16, max 6 legs,
  basket TP $240, per-leg SL 4xATR, emergency DD 25%) + REGIME GATE range-only:
  _50_RegimeMode=1 / AllowRange=true / AllowTrend=false / ADX_TrendMin=25 (regime TF H4) /
  StormATRmult=1.5. i.e. the grid only opens NEW baskets when the H4 market is RANGING (ADX<25)
  and not in an ATR storm. This is the whole rescue — the naked grid both-window-FAILED.

------------------------------------------------------------------------
WHY DEPLOY (regime gate rescued a both-window-fail base — Model-4 confirmed)
------------------------------------------------------------------------
- Base (no gate) both-window FAILED: MAIN 1.12 / BWD 0.94. Range-only gate flips it.
- Model-4 (real ticks) both-window plateau across ADX thr 20/25/30 (not a lucky point):
  thr20 1.63/1.28 · thr25 1.24/1.29 · thr30 1.30/1.52. BWD (2020-22) = all 3 years positive.
- This bundle = thr25 + storm1.5 (best preset from the storm sweep): MAIN 1.35 / BWD 1.20,
  DD 14.0%/9.0% (lower DD than storm2.0). Verified from THIS .set: PF 1.35 / net +1193 / 124t.
- no-op proof: the graft is bit-identical to the pre-graft EA at RegimeMode=0 — the gate is the
  only change, and it only filters NEW-basket first-entries (grid-adds + exits untouched).
- Mechanism: a grid harvests range oscillation and bleeds in strong trends; gating to RANGE
  regime is the orthogonal fix (direction-lock mode looked good in sim but died on real ticks).

------------------------------------------------------------------------
⚠️ CAVEAT — READ BEFORE ATTACHING (why this is demo-experiment, not a clean leg)
------------------------------------------------------------------------
- YEAR-SPLIT (Model-4): 2020 1.16 / 2021 1.16 / 2022 1.23 / **2023 0.68 (-900, LOSING)** /
  2024 5.85 (only 28t = thin/lucky) / 2025 1.06 (breakeven) / 2026 2.10. => 6/7 years positive
  but 2023 is a real losing year and the MAIN edge leans on a thin 2024.
- 2023 was a TRENDING yen year -> a range-only grid gets hurt; storm-gating only trimmed the
  loss (-1107 -> -900), it did NOT fix it. This EA will underperform in trending-AUDJPY regimes.
- Therefore: DEPLOY SMALL, treat as a regime-dependent experiment, and expect drawdown when
  AUDJPY trends hard. It is NOT an all-weather leg.

------------------------------------------------------------------------
SILENT-STOP PRE-ATTACH CHECKLIST
------------------------------------------------------------------------
[S1] TESTER/LIVE GATE: `allow = _07_AllowLive || MQL_TESTER`. Bundled .set has AllowLive=true;
     CONFIRM it stuck after load (else green EA, zero live orders).
[S2] ⚠️ RECOMPILE RESET (CRITICAL HERE): recompiling reverts inputs to compiled defaults, which
     include **_50_RegimeMode=0 = NO GATE**. That makes the EA trade the un-rescued base grid
     (both-window-fail). After ANY recompile: re-attach quiet + RELOAD this .set + CONFIRM
     _50_RegimeMode=1 stuck. A green EA with RegimeMode=0 is silently trading the broken config.
[S3] LOT: base 0.16, LOG-lot to max 6 legs, _06_MaxTotalLot=4.8 cap. Ensure account can hold 6
     legs at 0.16-0.42 lot on AUDJPY without margin stop. (Demo $10k = fine.)
[S4] no vendor lock / no DLL. [S5] magic 990110 unique (checked vs DEPLOYMENTS.csv).
[S6] symbol string = AUDJPY (match broker suffix, e.g. AUDJPY.a if present).
[S7] Bar-gate: OnTick sampled once per H1 bar-open (g_bar_checked); regime classified on closed
     H4 bar (shift 1) — no repaint.

------------------------------------------------------------------------
KILL-SWITCH (demo monitoring)
------------------------------------------------------------------------
- Equity DD alert 15%, KILL 20% (internal emergency exit fires at 25% — kill before it).
- Watch 2023-style behavior: if AUDJPY enters a sustained trend and the grid stacks against it,
  expect the losing-year pattern. A losing quarter during a clear AUDJPY trend = expected, not a
  bug; a losing quarter during a RANGE regime = the edge is gone, kill.
- Judge +3 months from attach date.

------------------------------------------------------------------------
NEXT STEP (user)
------------------------------------------------------------------------
corr vs cohort = informational (demo experiment; closest relatives = JPY-cross grids). Attach the
EA on AUDJPY H1, load ZeusAUDJPY_regime_demo_v1.set, confirm AllowLive=true + magic 990110 +
_50_RegimeMode=1 + first basket arms. Tell Claude the attach date -> register in DEPLOYMENTS.csv
(portfolio/) + set judge +3 months. Verdict doc: _triage/ORDER109_ZEUS_REGIME_VERDICT.md
