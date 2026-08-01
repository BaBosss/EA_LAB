//+------------------------------------------------------------------+
//| LabCore.mqh (V2) - shared OnInit/OnTick/OnDeinit for all 3 builds|
//| Entry is compile-time (LAB_ENTRY). First order needs a valid     |
//| entry signal; added orders governed by Stack.mqh (9x).           |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_CORE_MQH
#define BOSS_LAB_CORE_MQH

#include "Inputs.mqh"
// ORDER-710: must come AFTER Inputs.mqh -- it enumerates that file's inputs per build tag, and
// Inputs.mqh is where the fallback tag is defined when a wrapper defines none.
#include "InputSurface_gen.mqh"   // GENERATED (gen_input_surface.py); guarded by check_input_surface_gen.py
#include "Indicators.mqh"
#include "Regime.mqh"
#include "Execution.mqh"
#include "MacroGate_Core.mqh"   // ORDER-073 Phase-3: optional in-EA macro self-gate (backtest A/B)
#include "RiskControl.mqh"
#include "MoneyManagement.mqh"
#include "ExitManager.mqh"
#include "Stack.mqh"
#include "Recovery.mqh"
#include "Hedge.mqh"
#include "Basket.mqh"

// compile-time entry selection (one only; wrapper defines the token + LAB_ENTRY_TAG)
#ifdef LAB_ENTRY_11
   #include "entries/Entry_GridTrendMA.mqh"
#endif
#ifdef LAB_ENTRY_12
   #include "entries/Entry_Breakout.mqh"
#endif
#ifdef LAB_ENTRY_13
   #include "entries/Entry_MeanReversion.mqh"
#endif
#ifdef LAB_ENTRY_14
   #include "entries/Entry_GridLog.mqh"
#endif
#ifdef LAB_ENTRY_15
   #include "entries/Entry_ST03.mqh"
#endif
#ifdef LAB_ENTRY_16
   // ORDER-072: entry 16 = self-contained Kangaroo basket engine (single exit
   // owner). Entry module first (defines Entry_Evaluate), then the engine.
   #include "entries/Entry_KangarooRSI.mqh"
   #include "entries/Kangaroo.mqh"   // ORDER-124: moved core/ -> core/entries/
#endif
#ifdef LAB_ENTRY_17
   #include "entries/Entry_Wave5.mqh"
#endif
#ifdef LAB_ENTRY_18
   #include "entries/Entry_JumStoch.mqh"
#endif
#ifndef LAB_ENTRY_TAG
   #define LAB_ENTRY_TAG "??"
#endif

// _0_BarOpenOnly state (recompile-safe: reset in OnInit)
datetime g_lab_last_bar = 0;

// ORDER-192: effective-configuration summary, printed once at attach.
// The problem it solves: this chassis has 183 inputs and several pairs where one
// SILENTLY overrides another (a _*_BalPct twin beats its absolute sibling, an ATR
// target beats a money target). Reading a .set tells you what was REQUESTED; nothing
// told you what actually WON. Every line below is log-only - this function must never
// influence a trading decision.
void Lab_LogEffectiveConfig()
{
   Print("[CFG] ---- effective configuration (what actually wins at runtime) ----");

   // ORDER-710 (design 5.6). The line above tells a reader what won; this one lets a MACHINE
   // check it. The hash is over every input THIS BINARY EXPOSES, in the values it is actually
   // holding -- so it answers "is the .set on this chart the .set we validated", which reading
   // the .set file cannot (an unlisted input is filled from the per-terminal tester cache).
   // preset.py computes the same digest from the same preimage; the two are comparable only
   // because ea_template\core\InputSurface_gen.mqh is generated from the same parse of the
   // same file. Log-only, like everything else in this function.
   string cfg_fp = CFG_Fingerprint();
   if(cfg_fp == "")
      Print("[CFG] input surface: FINGERPRINT UNAVAILABLE - CryptEncode(CRYPT_HASH_SHA256) "
            "failed on this terminal. The configuration on this chart is UNVERIFIED; do not "
            "read the absence of a mismatch as a match.");
   else
      PrintFormat("[CFG] input surface: build=%s keys=%d scope=%s effective_config_hash=%s",
                  CFG_BuildTag(), CFG_SurfaceKeys(), CFG_FP_SCOPE, cfg_fp);

   // --- first lot. Deliberately NOT calling MM_FirstLot here: mode 42 needs an SL
   // distance from indicator buffers that are not filled yet at OnInit, so a number
   // printed now would be a lie (or would trip MM's "sizing unavailable" throttle).
   // Print the inputs that decide it instead, and resolve a real lot only for the
   // modes that can be resolved from account state alone.
#ifdef LAB_ENTRY_16
   // ORDER-190 follow-up: this branch used to print _16_BaseLot unconditionally, which
   // became a LIE the moment _16_BaseLotMode=1 existed - the log claimed a flat 0.01 while
   // the EA actually traded a balance-scaled 0.20. A summary whose whole job is "say what
   // really wins" must never be the thing that misreports the newest dial.
   // ORDER-194c (Codex review 2): report the lot that can actually REACH the broker, not
   // the raw formula output. Printing a raw 2.00 while _16_MaxLotPerOrder=0.50 and
   // RC_MaxLot=0.10 cap it at 0.10 is the same class of lie this block was fixed for once
   // already - a summary that is confidently wrong is worse than no summary.
   double raw16 = _16_BaseLot;
   if(_16_BaseLotMode == 1)
   {
      double bal16 = AccountInfoDouble(ACCOUNT_BALANCE);
      raw16 = (_43_BalanceAnchor > 0.0 ? _43_LotPerAnchor * (bal16 / _43_BalanceAnchor) : 0.0);
      PrintFormat("[CFG] sizing: Kangaroo owns lots - BALANCE-SCALED %.4f lot per %.2f balance; at the current balance %.2f the raw base is %.4f (_16_BaseLot %.4f IGNORED, FirstLotMode=%d IGNORED)",
                  _43_LotPerAnchor, _43_BalanceAnchor, bal16, raw16, _16_BaseLot, FirstLotMode);
   }
   else
      PrintFormat("[CFG] sizing: Kangaroo owns lots - flat base, raw base = _16_BaseLot %.4f (FirstLotMode=%d IGNORED)",
                  _16_BaseLot, FirstLotMode);
   double eff16 = raw16;
   if(_16_MaxLotPerOrder > 0.0 && eff16 > _16_MaxLotPerOrder) eff16 = _16_MaxLotPerOrder;
   if(RC_MaxLot > 0.0 && eff16 > RC_MaxLot) eff16 = RC_MaxLot;
   if(eff16 < raw16)
      PrintFormat("[CFG] entry-16 EFFECTIVE base after caps: %.4f (raw %.4f was cut by %s)", eff16, raw16,
                  (RC_MaxLot > 0.0 && RC_MaxLot <= _16_MaxLotPerOrder ? "RC_MaxLot" : "_16_MaxLotPerOrder"));
   // Kangaroo treats a non-positive per-order ceiling as DISABLED, so never print 0.00 as
   // if it were a ceiling of zero.
   if(_16_LadderMult > 1.0)
      PrintFormat("[CFG] entry-16 ladder ON: order 5+ = max open lot x %.2f, per-order ceiling %s",
                  _16_LadderMult,
                  (_16_MaxLotPerOrder > 0.0 ? DoubleToString(_16_MaxLotPerOrder, 2) : "OFF (<=0)"));
#else
   if(FirstLotMode == FIRSTLOT_FIXED)
      PrintFormat("[CFG] sizing: 41 FIXED -> first lot %.4f", _41_FixedLot);
   else if(FirstLotMode == FIRSTLOT_RISK)
      PrintFormat("[CFG] sizing: 42 RISK_PERCENT -> %.2f%% of balance per order, divided by the SL distance from SLMode=%d (lot varies per signal)",
                  _42_RiskPct, SLMode);
   else
   {
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      double raw43 = (_43_BalanceAnchor > 0.0 ? _43_LotPerAnchor * (bal / _43_BalanceAnchor) : 0.0);
      double eff43 = (RC_MaxLot > 0.0 && raw43 > RC_MaxLot ? RC_MaxLot : raw43);
      // ORDER-194c: same rule as the entry-16 branch - say what actually reaches the broker.
      if(eff43 < raw43)
         PrintFormat("[CFG] sizing: 43 BALANCE_SCALED -> %.4f lot per %.2f balance; at the current balance %.2f that is %.4f raw, CUT TO %.4f by RC_MaxLot",
                     _43_LotPerAnchor, _43_BalanceAnchor, bal, raw43, eff43);
      else
         PrintFormat("[CFG] sizing: 43 BALANCE_SCALED -> %.4f lot per %.2f balance; at the current balance %.2f that is %.4f lot",
                     _43_LotPerAnchor, _43_BalanceAnchor, bal, raw43);
      // the cent/USD trap: an anchor left at a USD figure on a cent account sizes 100x
      // too big and only RC_MaxLot stops it - by which point sizing is meaningless.
      if(bal > 0.0 && _43_BalanceAnchor > 0.0 && (bal / _43_BalanceAnchor) >= 50.0)
         PrintFormat("[CFG] WARN: balance is %.0fx the anchor - if this is a cent account, _43_BalanceAnchor is probably in the wrong units (see EA_CORE_AND_TEMPLATE_GUIDE section 3.6)",
                     bal / _43_BalanceAnchor);
   }
#endif
   PrintFormat("[CFG] caps: RC_MaxLot %.2f | ProtectLevel %d (killDD %.0f%% / depositLoad %.0f%% / recSteps %d) | maxLevels %d",
               RC_MaxLot, ProtectLevel, RC_KillDDPct(), RC_MaxDepositLoadPct(), RC_MaxRecSteps(), RiskControl_MaxLevels());
   // ORDER-195: RC_MaxLevelsOverride (>0) replaces only the step-count component
   // ProtectLevel would otherwise supply via RC_MaxRecSteps() (RiskControl.mqh
   // RiskControl_MaxLevels) -- it does NOT touch KillDD or DepositLoad, which stay
   // ProtectLevel's exactly as printed on the line above. Say precisely which one
   // component moved so a reader does not assume the whole preset was replaced.
   if(RC_MaxLevelsOverride > 0)
      PrintFormat("[CFG] depth cap: RC_MaxLevelsOverride %d replaces the step-count component of ProtectLevel %d -- IGNORING ProtectLevel's recSteps %d (killDD %.0f%% and depositLoad %.0f%% still come from ProtectLevel, untouched)",
                  RC_MaxLevelsOverride, ProtectLevel, RC_MaxRecSteps(), RC_KillDDPct(), RC_MaxDepositLoadPct());

   // --- inputs that are silently superseded by a twin. Name the loser explicitly:
   // "ignored" in a log line is what stops someone tuning a dead number for an hour.
   double bp;
   bp = MM_BalancePct(_2_BasketTP_BalPct);
   if(bp > 0.0)
      PrintFormat("[CFG] basket TP: _2_BasketTP_BalPct %.3f%% = %.2f money -- IGNORING _2_BasketTP_ATRmult %.2f and _2_BasketTP_Money %.2f",
                  _2_BasketTP_BalPct, bp, _2_BasketTP_ATRmult, _2_BasketTP_Money);
   else if(_2_BasketTP_ATRmult > 0.0)
      PrintFormat("[CFG] basket TP: _2_BasketTP_ATRmult %.2f -- IGNORING _2_BasketTP_Money %.2f",
                  _2_BasketTP_ATRmult, _2_BasketTP_Money);
   else if(_2_BasketTP_Money > 0.0)
      PrintFormat("[CFG] basket TP: _2_BasketTP_Money %.2f", _2_BasketTP_Money);

   bp = MM_BalancePct(_32_SL_BalPct);
   if(bp > 0.0)
      PrintFormat("[CFG] basket STOP: _32_SL_BalPct %.3f%% = %.2f money -- IGNORING _32_SL_Money %.2f", _32_SL_BalPct, bp, _32_SL_Money);
   else if(_32_SL_Money > 0.0)
      PrintFormat("[CFG] basket STOP: _32_SL_Money %.2f", _32_SL_Money);

   if(_57_DynCloseOn)
   {
      bp = MM_BalancePct(_57_DynCloseBalPct);
      if(bp > 0.0)
         PrintFormat("[CFG] dyn close: base from _57_DynCloseBalPct %.3f%% = %.2f -- IGNORING _57_DynCloseBase %.2f", _57_DynCloseBalPct, bp, _57_DynCloseBase);
      else
         PrintFormat("[CFG] dyn close: base _57_DynCloseBase %.2f", _57_DynCloseBase);
   }

   if(RecoveryMode == REC_ADAPTIVE)
   {
      bp = MM_BalancePct(_8_DDRefBalPct);
      if(bp > 0.0)
         PrintFormat("[CFG] recovery 82 DD reference: _8_DDRefBalPct %.3f%% = %.2f -- IGNORING _8_DDRefMoney %.2f", _8_DDRefBalPct, bp, _8_DDRefMoney);
      else
         PrintFormat("[CFG] recovery 82 DD reference: _8_DDRefMoney %.2f", _8_DDRefMoney);
   }

   // ORDER-195: _2_SuppressLegTP blanks every leg's broker TP to 0.0 (ExitManager.mqh
   // Exit_InitialTP, checked before anything else in that function). Only worth a WARN
   // when ExitMode would otherwise have put a real per-leg TP in force (21 FIXED_TP /
   // 22 ATR_TP) -- with TRAIL/RUN_TREND there is no per-leg TP to blank in the first
   // place, so nothing is actually overridden and the line would be noise.
   if(_2_SuppressLegTP && (ExitMode == EXIT_FIXED_TP || ExitMode == EXIT_ATR_TP))
      PrintFormat("[CFG] per-leg TP: _2_SuppressLegTP=true forces every leg's broker TP to 0.0 -- IGNORING ExitMode %d's per-leg TP (basket-level exits such as _2_BasketTP_* still apply)", ExitMode);

   // ORDER-195: _33_SL_MaxATRmult (>0) supersedes _33_SL_MaxPips as the ATR-SL distance
   // cap (ExitManager.mqh Exit_CapATRDist checks MaxATRmult first, unconditionally, and
   // only falls through to MaxPips when it is <=0). Both caps are reachable only from
   // the SL_ATR branch of SLMode, so gate the note on that -- on any other SLMode
   // neither cap is ever consulted and printing this would be a lie about what's live.
   if(SLMode == SL_ATR && _33_SL_MaxATRmult > 0.0)
      PrintFormat("[CFG] ATR-SL cap: _33_SL_MaxATRmult %.2f (portable, x current Risk-ATR) -- IGNORING _33_SL_MaxPips %.1f (legacy fixed-pip ceiling)",
                  _33_SL_MaxATRmult, _33_SL_MaxPips);

#ifdef LAB_ENTRY_17
   // ORDER-195: _17_UseStructLevels supersedes BOTH SLMode and ExitMode's per-order
   // SL/TP output (ExitManager.mqh Exit_InitialSL / Exit_InitialTP). SL: unconditional
   // whenever a valid structural level is published for the order. TP: only when
   // _2_SuppressLegTP has not already blanked it (checked first in Exit_InitialTP) AND
   // ExitMode is not TRAIL/RUN_TREND -- those two modes own the exit themselves, and
   // Exit_InitialTP explicitly skips the structural TP for them (the wave-1 TP anchor
   // is published only as a reference zone in that case, never a broker TP).
   if(_17_UseStructLevels)
   {
      PrintFormat("[CFG] entry-17 structural SL ON: every order's SL comes from the wave-1/wave-3 structural level, not the SLMode switch -- IGNORING SLMode %d", SLMode);
      if(_2_SuppressLegTP)
         Print("[CFG] entry-17 structural TP: moot -- _2_SuppressLegTP=true already blanked every leg's TP to 0.0 above the structural-TP check");
      else if(ExitMode == EXIT_TRAIL || ExitMode == EXIT_RUN_TREND)
         PrintFormat("[CFG] entry-17 structural TP: not applied -- ExitMode %d owns the exit (TRAIL/RUN_TREND); the wave-1 TP anchor is published as a reference zone only, no broker TP is set from it", ExitMode);
      else
         PrintFormat("[CFG] entry-17 structural TP ON: every order's TP comes from the wave-1/wave-3 structural level, not the ExitMode switch -- IGNORING ExitMode %d", ExitMode);
   }
#endif

   // --- the compounding stack. Three independent multipliers can stack on one order,
   // and the registry/guide both flag this as the most dangerous combination in the
   // chassis. If they are on together, say so where an operator will actually see it.
   if(_4_DdAdaptiveOn && (LotProg != PROG_NONE || RecoveryMode != REC_NONE))
      PrintFormat("[CFG] WARN: three lot multipliers are live at once - DD-adaptive (x up to %.2f) then LotProg %d then Recovery %d. Worst-case single-order lot must be checked by hand; RC_MaxLot %.2f is the only backstop.",
                  _4_DdHardCapMult, LotProg, RecoveryMode, RC_MaxLot);
   Print("[CFG] ---- end effective configuration ----");
}

// ---- MacroGate self-gate (ORDER-073 Phase-3) -----------------------------
// _MG_* inputs moved to Inputs.mqh (ORDER-124 chore 2 - one input home). Names
// unchanged so every existing .set still loads.

//+------------------------------------------------------------------+
int OnInit()
{
   // ORDER-129 magic-collision guard (Codex system review SEV-1): every Boss wrapper
   // compiles with the same default magic (990001). Ownership is symbol+magic only, so
   // two Boss EAs attached with compiled defaults would count, stack, partially close
   // and hard-kill EACH OTHER's positions. On any real/demo account the default is
   // therefore refused; the tester keeps working so default-param smokes still run.
   if(!MQLInfoInteger(MQL_TESTER) && _0_Magic == 990001)
   {
      Print("[INIT] FATAL: _0_Magic is still the compiled default (990001) - load a .set with this EA's unique magic before attaching to an account");
      return INIT_FAILED;
   }
   // ORDER-132b (Codex P1): scoped persist keys must fit MT5's 63-char GlobalVariable
   // name limit - an over-length key makes every kill/halt persist silently fail and a
   // restart resurrects a killed EA as RUNNING. Probe with the longest state name and
   // refuse the live/demo attach fail-closed (tester sandbox is exempt).
   // ORDER-138: longest key is now "exit_closeall" (13 chars), not "rc_peak_eq".
   if(!MQLInfoInteger(MQL_TESTER) && StringLen(Persist_Key("exit_closeall")) > 63)
   {
      PrintFormat("[INIT] FATAL: persist key exceeds the 63-char GV limit (%s) - symbol/login/magic too long for persisted safety state",
                  Persist_Key("exit_closeall"));
      return INIT_FAILED;
   }
   // MM-SAFETY-001 (Codex review 2026-07-24): a sizing mode whose ingredients are missing
   // used to degrade to _41_FixedLot silently at the first order. Config errors now die
   // here instead; only runtime data failures are handled (as skipped orders) in MM_FirstLot.
   if(!MM_ConfigValid())
      return INIT_FAILED;
   if(!Indi_Init())
   {
      Print("[INIT] indicator handles failed");
      return INIT_FAILED;
   }
   g_lab_last_bar = 0;
   if(!Regime_Init())
   {
      Print("[INIT] regime handles failed");
      return INIT_FAILED;
   }
   Exec_Init();
   if(_MG_SelfGate)
   {
      // self-gate this EA on its own magic (RowStaleMaxHours huge: tester rows are dense daily)
      MG_Setup(_MG_LotMult, _MG_BlockNew, _MG_TriggerRiskOff, _MG_OffsetHours, 8760, 168);
      MG_ParseMagics(IntegerToString(_0_Magic));
      MG_LoadRegime(_MG_RegimeFile, _MG_InCommon);
      MG_Tick(TimeCurrent());
   }
   // ORDER-138 #1: an identity-less ACTIVE legacy kill/halt without explicit
   // RC_AdoptLegacyHalt consent must fail the attach (details in the [RISK] log)
   if(!RiskControl_Init())
      return INIT_FAILED;
   ExitManager_Init();   // ORDER-138 #3: restore a persisted full-basket close intent
   Recovery_Init();
#ifdef LAB_ENTRY_14
   Entry_GridLog_Init();
#endif
#ifdef LAB_ENTRY_15
   Entry_ST03_Init();
#endif
#ifdef LAB_ENTRY_16
   Entry_KangarooRSI_Init();
   Kangaroo_Init();
   // ORDER-125 (Codex MAJOR-3): Boss_16 exits exclusively through Kangaroo's
   // own exit owner (Kangaroo_OnTick returns before Exit_ManageBasket), so the
   // shared vertical-barrier input is a silent no-op here. Warn loudly rather
   // than fail - the input is an inert dial, not a safety promise.
   if(_2_MaxHoldBars > 0)
      Print("[INIT] WARN: _2_MaxHoldBars has NO EFFECT on Boss_16/Kangaroo (Kangaroo owns its exits) - input ignored");
#endif
#ifdef LAB_ENTRY_17
   Entry_Wave5_Init();
   // MM-SAFETY-001: ORDER-082 guard G4 documented "structural mode is banned with
   // stacking - naked probe only", but nothing enforced it. Unenforced, a .set with
   // StackMode 91/92/93 put grid adds and resting pendings on Wave5's published
   // structural SL - a level computed for ONE entry at ONE price, reused for orders
   // it was never validated against (the 93 ladder never re-checks it at all). Fail
   // the attach instead of trading a design that was never designed.
   if(_17_UseStructLevels && StackMode != STACK_SINGLE)
   {
      PrintFormat("[INIT] FATAL: Boss_17 structural SL (_17_UseStructLevels=true) is naked-probe only - StackMode must be 90, got %d (ORDER-082 guard G4)", StackMode);
      return INIT_FAILED;
   }
   // ORDER-194b (Codex audit, high): StackMode was only one of the three ways to get a
   // SECOND order onto the one structural level. The documented invariant is "no grid /
   // recovery / martingale" (Inputs.mqh entry-17 header), and Recovery_OnTick runs for
   // every StackMode except 93 - so StackMode=90 + RecoveryMode=81 passed the check above
   // and still opened adds against a stop computed for a different entry at a different
   // price. Hedge can likewise add an opposite leg. Close both doors.
   if(_17_UseStructLevels && RecoveryMode != REC_NONE)
   {
      PrintFormat("[INIT] FATAL: Boss_17 structural SL is naked-probe only - RecoveryMode must be 80, got %d (recovery adds would reuse the wave-1 invalidation level of a different entry)", RecoveryMode);
      return INIT_FAILED;
   }
   if(_17_UseStructLevels && HedgeMode != HEDGE_OFF)
   {
      PrintFormat("[INIT] FATAL: Boss_17 structural SL is naked-probe only - HedgeMode must be 0, got %d", HedgeMode);
      return INIT_FAILED;
   }
   // ORDER-432 finding 3 (Codex blind audit 2026-07-27). Every guard above is gated on
   // _17_UseStructLevels, which is a plain user-switchable input (Inputs.mqh:292). Turn
   // it off and the three checks above stop applying AND the structural SL disappears:
   // Exit_InitialSL falls through to the SLMode switch, SL_NONE returns 0.0,
   // Exit_StructSLMissing returns false on the same flag, and Lab_OpenOrder sends
   // sl=0 -- a naked position, with no after-the-fact detector anywhere in the chassis
   // (POSITION_SL is read in exactly two places repo-wide, both trailing paths).
   //
   // Wave5 is a structural design: its whole thesis is a stop at the wave-1
   // invalidation level. Running it with no per-order stop at all is not a
   // configuration of that strategy, it is a different and unbounded one. Refuse the
   // attach rather than trade it. SLMode 31/33/34/35/36 all remain legal with the flag
   // off -- this only closes "no stop at all".
   if(!_17_UseStructLevels && (SLMode == SL_NONE || SLMode == SL_MONEY))
   {
      PrintFormat("[INIT] FATAL: Boss_17 with _17_UseStructLevels=false needs a per-order SL, but SLMode=%d yields none (30 NONE / 32 MONEY) - that combination opens naked positions (ORDER-432 finding 3). Use SLMode 31/33/34/35/36, or leave _17_UseStructLevels=true.", SLMode);
      return INIT_FAILED;
   }
#endif
#ifdef LAB_ENTRY_18
   Entry_JumStoch_Init();
#endif
   PrintFormat("[INIT] Boss_%s | exit=%d sl=%d stack=%d conf=%d firstLot=%d prog=%d protect=%d dry=%s",
               LAB_ENTRY_TAG, ExitMode, SLMode, StackMode, StackConfirm,
               FirstLotMode, LotProg, ProtectLevel, (DryRun ? "Y" : "N"));
   Lab_LogEffectiveConfig();   // ORDER-192: log-only summary of which inputs actually win
   if(StackMode == STACK_PYRAMID && _9_PendingMode != 2 && _9_PendingMode != 3)
      Print("[INIT] WARN: StackMode=93 but _9_PendingMode not 2/3 - ladder disabled, behaves like single");
   // ORDER-124 chore 3: exit-owner assert. Mode 93 declares the pending ladder the
   // single exit owner; LabCore's runtime guard already SKIPS Recovery/Hedge/partial
   // under 93 (OnTick + Exit_ManagePartialClose), so a .set that turns them on is a
   // declared-but-ignored config, not a live conflict -> hard-WARN, never fail
   // (Codex catch: do not trip dormant combos - e.g. entry 16, where Kangaroo owns
   // everything and returns before ExitManager, stays silent here by design).
   // Legal-combo table: DESIGN_V2.md section 3c.
   // Codex review 445a1b7 (MINOR-1): entry 16 short-circuits into Kangaroo before any
   // of these paths, so its informational StackMode value must not trip the assert.
#ifndef LAB_ENTRY_16
   if(StackMode == STACK_PYRAMID)
   {
      if(RecoveryMode != REC_NONE)
         Print("[INIT] WARN: exit-owner - StackMode=93 disables Recovery; RecoveryMode!=80 in this .set is IGNORED (DESIGN_V2 3c)");
      if(HedgeMode != HEDGE_OFF)
         Print("[INIT] WARN: exit-owner - StackMode=93 disables Hedge; HedgeMode!=0 in this .set is IGNORED (DESIGN_V2 3c)");
      // note: this can also fire when the basket target is 0 (partial would be off
      // anyway) - accepted, the message stays true: 93 skips partial regardless.
      if(_2_PartialPct1 > 0.0 || _2_PartialPct2 > 0.0)
         Print("[INIT] WARN: exit-owner - StackMode=93 disables partial-close; _2_PartialPct1/2 in this .set are IGNORED (DESIGN_V2 3c)");
      // Codex review 445a1b7 (SEV-2): under 93, leg0 still receives a broker TP from
      // Exit_InitialTP when ExitMode=21/22 and _2_SuppressLegTP=false - a genuinely
      // CONCURRENT second close path (leg0 broker TP vs basket exit owner) that can
      // fragment the ladder. WARN, not fail: the pinned 93 probe set
      // (_mt5_auto/ab_sets/order132_93probe.set) runs exactly this combo and its cage
      // numbers were pinned with it - failing here would brick the regression probe.
      if((ExitMode == EXIT_FIXED_TP || ExitMode == EXIT_ATR_TP) && !_2_SuppressLegTP)
         Print("[INIT] WARN: exit-owner - StackMode=93 with ExitMode 21/22 and _2_SuppressLegTP=false gives leg0 a live per-leg broker TP (second close path vs basket owner) - set _2_SuppressLegTP=true (DESIGN_V2 3c)");
   }
#endif
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
#ifdef LAB_ENTRY_17
   // ORDER-432 finding 6: print the Wave5 guard fire counts. Without this a report of
   // zero trades cannot distinguish "no eligible signal" from "a guard rejected
   // everything" from "the guard never ran" -- and the VERDICT GATE requires a fired
   // count before any guard may be written up as passed. Diagnostic only; nothing
   // branches on it, and no other build compiles this line.
   Entry_Wave5_LogCounters();
#endif
   if(_MG_SelfGate) MG_Deinit();   // clear any MACROGATE_* GVs we set
   Regime_Deinit();
   Indi_Deinit();
}

//+------------------------------------------------------------------+
void Lab_OpenOrder(const int dir, const int level)
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   double entry    = (dir == 1 ? t.ask : t.bid);
   double sl       = Exit_InitialSL(dir, entry);
   if(Exit_StructSLMissing(sl)) return;   // MM-SAFETY-001: never open on a broken structural-SL promise
   double tp       = Exit_InitialTP(dir, entry);
   double firstLot = MM_FirstLot(Exit_SLDistancePoints());
   double lot      = MM_NextLot(firstLot, level);
   Exec_Open(dir, lot, sl, tp, LAB_ENTRY_TAG + " L" + IntegerToString(level));
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(_MG_SelfGate)
   {
      // refresh the macro gate once per M1 bar (regime is daily; this runs BEFORE any
      // entry logic below so Exec_Open/PlacePending see the current GV state this tick)
      static datetime mg_lastbar = 0;
      datetime mg_cb = iTime(_Symbol, PERIOD_M1, 0);
      if(mg_cb != mg_lastbar) { mg_lastbar = mg_cb; MG_Tick(TimeCurrent()); }
   }
#ifdef LAB_ENTRY_16
   // entry 16 (KangarooGrid, ORDER-072): Kangaroo.mqh owns the ENTIRE pipeline
   // (first entry, adverse grid adds, every exit, emergency DD) - one exit
   // owner. Cage hard-kill runs inside it, first. Always returns true; the
   // runtime guard (not a bare return) keeps the code below compiling without
   // unreachable-code warnings. Other builds: this block does not exist.
   if(Kangaroo_OnTick()) return;
#endif
   // (1) hard kill FIRST - before any cadence gate. ORDER-129 (Codex system review
   // SEV-1): the bar gate below used to early-return before the kill check, so with
   // _0_BarOpenOnly=true and a basket open, an intrabar equity crash went unexamined
   // until the next bar-open (H4 = up to 4 hours of unmanaged free-fall). Safety is
   // never bar-gated; only signal/management cadence is.
   if(RiskControl_CheckDD()) return;
   if(RiskControl_IsHalted()) return;
   if(Exit_SafetyMoneyStop()) return;   // ORDER-129b: basket money-STOP never bar-gated (Codex audit F1)

   // (0) optional Zeus-style once-per-bar gate (default false = every tick,
   // unchanged). Management/stack/recovery evaluate once per bar-open ONLY;
   // the flat-entry trigger still runs intrabar so an armed resting-stop
   // level can fill at its exact price (standalone parity: pending stops
   // fill intrabar even though everything else is bar-gated).
   if(_0_BarOpenOnly)
   {
      datetime b = iTime(_Symbol, _Period, 0);
      if(b == g_lab_last_bar)
      {
         if(Exec_CountAll() > 0) return;          // basket open: management stays bar-gated (kill already ran above)
         if(Regime_BlocksFlatEntry()) return;     // mode 0=no-op; only flat first-entries are gated
         EntrySignal s = Entry_Evaluate();        // resting-stop trigger check
         if(!s.valid) return;
         if(!Regime_AllowsEntryDirection(s.direction)) return;
         if(!RiskControl_AcctGateOK()) return;    // acct-DD gate (first-entry only, no-op when off)
         if(!RiskControl_AllowNewOrder()) return;
         if(_9_MaxLevels <= 0) return;
         Lab_OpenOrder(s.direction, 0);
         return;
      }
      g_lab_last_bar = b;
   }

   // (2) manage existing basket; stop if it fully closed this tick
   if(Exit_ManageBasket()) return;

   // gated hooks (no-op unless enabled). Mode 93 owns its basket lifecycle -
   // Recovery/Hedge market-adds would fight the resting ladder (MERGE-02
   // synthesis: one mode, one owner), so they are skipped under 93.
   if(StackMode != STACK_PYRAMID)
   {
      Recovery_OnTick();
      Hedge_OnTick();
   }
   Basket_OnTick();
   Stack_ManagePyramid();   // no-op unless StackMode==93

   // (3) entry signal
   EntrySignal sig = Entry_Evaluate();

   int haveBuy  = Exec_CountDir(1);
   int haveSell = Exec_CountDir(2);
   int have     = haveBuy + haveSell;

   if(have == 0)
   {
      // first order requires a valid entry signal
      if(Regime_BlocksFlatEntry()) return;        // gate only the first entry; open baskets stay untouched
      if(!sig.valid) return;
      if(!Regime_AllowsEntryDirection(sig.direction)) return;
      if(!RiskControl_AcctGateOK()) return;   // acct-DD gate (first-entry only, no-op when off)
      if(!RiskControl_AllowNewOrder()) return;
      if(_9_MaxLevels <= 0) return;
      Lab_OpenOrder(sig.direction, 0);
      return;
   }

   // added orders: governed by Stack (direction = current basket)
   int dir = (haveBuy > 0 ? 1 : 2);
   if(!Stack_DecideAdd(dir, have, sig)) return;
   if(!RiskControl_AllowNewOrder()) return;
   Lab_OpenOrder(dir, have);   // level = current count
}
//+------------------------------------------------------------------+

#endif // BOSS_LAB_CORE_MQH
