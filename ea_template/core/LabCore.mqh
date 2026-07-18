//+------------------------------------------------------------------+
//| LabCore.mqh (V2) - shared OnInit/OnTick/OnDeinit for all 3 builds|
//| Entry is compile-time (LAB_ENTRY). First order needs a valid     |
//| entry signal; added orders governed by Stack.mqh (9x).           |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_CORE_MQH
#define BOSS_LAB_CORE_MQH

#include "Inputs.mqh"
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
   #include "Kangaroo.mqh"
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

// ---- MacroGate self-gate (ORDER-073 Phase-3) -----------------------------
// OFF by default = fully inert (the cage and every live EA see no change). When
// ON, THIS EA reads the MRIS regime timeline and sets its own MACROGATE_* GVs,
// which the Execution bridge above then honours - this is how a SINGLE-EA
// strategy-tester A/B (gate off vs on) is run, since the tester cannot also run
// the standalone (Boss)_MacroGate watchdog. In LIVE, leave this OFF and use the
// standalone watchdog instead.
input bool   _MG_SelfGate       = false;                     // enable in-EA macro gate (backtest A/B only)
input string _MG_RegimeFile     = "EA_LAB_mris_regime.csv";  // regime timeline CSV
input bool   _MG_InCommon       = true;                      // read from Common\Files
input double _MG_LotMult        = 0.5;                       // new-order lot multiplier while gated
input bool   _MG_BlockNew       = true;                      // also veto new orders while gated
input bool   _MG_TriggerRiskOff = true;                      // gate on RISK_OFF too (false = STRESS only)
input int    _MG_OffsetHours    = 0;                         // server = CSV time + N hours

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
   RiskControl_Init();
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
#endif
#ifdef LAB_ENTRY_17
   Entry_Wave5_Init();
#endif
#ifdef LAB_ENTRY_18
   Entry_JumStoch_Init();
#endif
   PrintFormat("[INIT] Boss_%s | exit=%d sl=%d stack=%d conf=%d firstLot=%d prog=%d protect=%d dry=%s",
               LAB_ENTRY_TAG, ExitMode, SLMode, StackMode, StackConfirm,
               FirstLotMode, LotProg, ProtectLevel, (DryRun ? "Y" : "N"));
   if(StackMode == STACK_PYRAMID && _9_PendingMode != 2 && _9_PendingMode != 3)
      Print("[INIT] WARN: StackMode=93 but _9_PendingMode not 2/3 - ladder disabled, behaves like single");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
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
