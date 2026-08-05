========================================================================
ORDER-098-B MacdDiv_Naked — DEMO DEPLOY BUNDLE — XAUUSD H4
========================================================================
Status:   DEMO-ELIGIBLE (lead-engineer PASS to demo, 2026-07-16). NOT live-certified.
EA:       MacdDiv_Naked.ex5   (standalone naked flat-lot; MACD-divergence entry)
Source:   D:\EA_LAB\ea_projects\(EXP)_MacdDiv_Naked\MacdDiv_Naked.mq5
Build:    ex5 recompiled 2026-07-16 (0/0), MD5 436DEE39ADAD9BCD9547EB72A8EAA0B5, 31498 bytes
          (build+optimize = Codex commits 5477a5ae/7e0825d0; funnel+verdict = Claude 2026-07-16)
Symbol:   XAUUSD (match broker string: XAUUSD / XAUUSDm / XAUUSDc — see S6)
TF:       H4
Magic:    999094   (free vs cohort 990101/991001/991002/991004/990301)
Set:      MacdDiv_XAU_H4_demo_v1.set  (optPF params, verbatim; AllowLive=true; OptimizeMode=false)

Mechanism: bullish divergence = price lower-low + MACD main higher-low (mirror bearish).
           Single flat-lot order 0.01, SL = 3-bar extremum, TP = 200% SL. NO grid/martingale.

------------------------------------------------------------------------
!!! STATUS DOWNGRADED 2026-07-25 (ORDER-216) — READ BEFORE CITING THE EVIDENCE BELOW !!!
------------------------------------------------------------------------
"Full funnel cleared" NO LONGER HOLDS. Verdict is now PARKED-VERIFY(user):
stays on DEMO, but DO NOT size up and DO NOT promote to real money.

1) The "plateau, ZERO losing neighbor" claim below is a FAKE PLATEAU. It was counted on
   axes that cannot affect the EA at all:
     - `_02_MacdSignal` is passed to iMACD() but the EA only ever reads buffer 0 (the MACD
       main line). Buffer 1 -- the signal line, the ONLY thing this parameter controls -- is
       never read anywhere in the EA. Confirmed by reading the source, not just statistics.
       Values 10/11/13/15/16 return identical results to every digit on MAIN and BWD.
     - `_01_LookbackBars` is inert for every value >=48; the deployed 60 sits mid-dead-zone.
     - `_01_MinBarsApart` is inert at 1-4; the deployed 2 sits in the dead zone.
   Neighbors on a dead axis are identical by construction, so "no losing neighbor" was true
   automatically and measured nothing.

2) The deployed cell is a KNIFE EDGE on the one axis that does matter, `_01_SwingRadius`:
       SwingRadius    2        3 (deployed)     4
       MAIN PF        0.96     1.82             1.04
       BWD  PF        0.87     0.98             1.44
   One step either way and MAIN PF falls below 1.0. Of 405 fine-grid combos, 146 pass -- but
   135 of those 146 are SwingRadius=3. That is a single on/off switch, not width.

3) Worse than knife-edge: the axis REVERSES between regimes. MAIN prefers 3, BWD prefers 4,
   and NO value clears both windows at once. That is a regime-fit signature, not a durable
   mechanism.

Also corrected: BWD measured 0.98, not the 1.04 printed below.

What still stands: the EA is naked flat-lot with a real SL, no grid/martingale, and the
Model-4 numbers are not a fill artifact. It is safe to leave running on demo as-is.
See AGENT_TASKBOARD ORDER-216 for the full working.
------------------------------------------------------------------------

WHY DEPLOY (evidence as written 2026-07-16 — SUPERSEDED, see the block above)
------------------------------------------------------------------------
- Plateau (not spike): XAU H4 MAIN (2023-26) PF 1.91, 9 one-param neighbors 1.33-1.90 with
    ZERO losing neighbor on Slow/Fast/Buffer/ATR-period axes.   <-- FAKE, see (1) above
- Both-regime: BWD (2020-22) PF 1.04 (survives the opposite regime, DD 3.4%).
- Holdout (never used to select): 2026 H1 PF 1.30.
- Model-4 real ticks (the honest test): MAIN 1.89 / BWD 0.97 / HOLDOUT 1.28 — virtually
    unchanged from Model-1 => edge is real, NOT a fill/spread artifact (naked = no fill sensitivity).
- Monte Carlo (5000 iters, $10k, MAIN deals): ruin 0.00%, P(net<0) 0.0%, DD worst 4.76%.
- Correlation vs live gold cohort (5 EAs, monthly P&L): max |corr| 0.555 < 0.8 (additive;
    Breakout_XAU actually -0.555 = diversifying). Zeus 0.400 / Squeeze 0.043 / Trendline -0.048 /
    Wave5 0.204.

------------------------------------------------------------------------
SILENT-STOP PRE-ATTACH CHECKLIST (clear ALL before demo attach on VPS)
------------------------------------------------------------------------
[S1] TESTER-GATE:  REAL. Code = `allow = _06_AllowLive || MQL_TESTER; if(!allow) return;`.
     In Strategy Tester it always trades; on a LIVE/DEMO chart it does NOTHING unless
     _06_AllowLive=true. The bundled .set sets it TRUE — but CONFIRM it stuck after load
     (this is the #1 silent-stop trap: green EA, zero trades).
[S2] RECOMPILE RESET: recompiling while attached reverts inputs to compiled defaults
     (AllowLive=false, OptimizeMode=false, opt params -> defaults). After ANY recompile,
     re-attach in a quiet window and RELOAD MacdDiv_XAU_H4_demo_v1.set.
[S3] LOT/MIN: fixed 0.01 — confirm it clears the demo account broker min. Check Experts log.
[S4] EXPIRY/LOCK: none (repo-built, no vendor lock).
[S5] MAGIC: 999094 unique vs cohort — keep it; do not reuse another EA's magic.
[S6] SYMBOL NAME: confirm the VPS broker gold symbol string matches the attached chart.
[S7] BAR GATE: entry evaluates on closed H4 bars (no intrabar repaint) — ensure H4 history clean.

------------------------------------------------------------------------
EXPECTED BEHAVIOUR (for the ~2-week monitor vs backtest)
------------------------------------------------------------------------
- ~90-95 trades/year on XAU H4 (280 trades over 3yr MAIN). Win% ~38%, PF ~1.9 in trending
  gold, ~1.0 (breakeven) in ranging years. Modest per-trade edge, low DD (worst ~5%).
- KILL-SWITCH candidate rules (lead proposal, user confirms at attach):
    closed-equity DD > 15%  OR  3 consecutive losing months  OR  PF < 0.9 over 40+ trades.

------------------------------------------------------------------------
EXNESS CENT (XAUUSDc, 3-digit) VARIANT — added 2026-07-16
------------------------------------------------------------------------
Set: MacdDiv_XAUc_exness3d_v1.set  (for the 10,000-cent real port, symbol XAUUSDc)
- ONLY change vs the demo set = _06_Deviation 20 -> 300 (3-digit gold: 1 point = 0.001, so 300 pts
  = 0.30 slippage room for the wider cent-feed spread). Everything else identical.
- DIGIT-SAFE confirmed: SL = bar-extremum ± ATR-buffer, TP = 2×dist, all price-relative via
  SymbolInfoDouble(POINT)/SYMBOL_DIGITS at runtime — NO 2-digit assumption, works on 3-digit as-is.
- ⚠️ EXPERIMENT CAVEAT: MacdDiv was validated on ThinkMarkets XAUUSD (2-digit) history. Running it on
  Exness XAUUSDc (3-digit, different spread/liquidity) is a LIVE spread-reality test on a NEW feed —
  the live numbers may differ from the backtest. Treat this cent run as feed-validation, not a repeat
  of the validated result. Watch first ~20 trades for entry-quality / spread drag vs the backtest PF.
- MAGIC 999094 is free on the cent account 159503454 (existing: 990101/991001/991004/991002/990103).
- Lot 0.01 on cent = tiny; the ATR SL/TP scale with price so risk% is the same as backtest.

------------------------------------------------------------------------
NEXT STEP (user)
------------------------------------------------------------------------
Copy this folder to the VPS, attach MacdDiv_Naked on an XAUUSD H4 chart in a quiet window,
load MacdDiv_XAU_H4_demo_v1.set, confirm (a) AllowLive=true stuck, (b) lot 0.01, (c) magic
999094 in the Experts log, (d) first trade fires within a few bars. Tell Claude the attach
date -> register in DEPLOYMENTS.csv + DEMO_DEPLOYMENT_PLAN + judge +3 months.
========================================================================
