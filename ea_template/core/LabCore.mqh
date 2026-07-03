//+------------------------------------------------------------------+
//| LabCore.mqh (V2) - shared OnInit/OnTick/OnDeinit for all 3 builds|
//| Entry is compile-time (LAB_ENTRY). First order needs a valid     |
//| entry signal; added orders governed by Stack.mqh (9x).           |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_CORE_MQH
#define BOSS_LAB_CORE_MQH

#include "Inputs.mqh"
#include "Indicators.mqh"
#include "Execution.mqh"
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
#ifndef LAB_ENTRY_TAG
   #define LAB_ENTRY_TAG "??"
#endif

// _0_BarOpenOnly state (recompile-safe: reset in OnInit)
datetime g_lab_last_bar = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   if(!Indi_Init())
   {
      Print("[INIT] indicator handles failed");
      return INIT_FAILED;
   }
   g_lab_last_bar = 0;
   Exec_Init();
   RiskControl_Init();
   Recovery_Init();
#ifdef LAB_ENTRY_14
   Entry_GridLog_Init();
#endif
   PrintFormat("[INIT] Boss_%s | exit=%d sl=%d stack=%d conf=%d firstLot=%d prog=%d protect=%d dry=%s",
               LAB_ENTRY_TAG, ExitMode, SLMode, StackMode, StackConfirm,
               FirstLotMode, LotProg, ProtectLevel, (DryRun ? "Y" : "N"));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
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
         if(Exec_CountAll() > 0) return;          // basket open: fully bar-gated
         if(RiskControl_IsHalted()) return;
         EntrySignal s = Entry_Evaluate();        // resting-stop trigger check
         if(!s.valid) return;
         if(!RiskControl_AllowNewOrder()) return;
         if(_9_MaxLevels <= 0) return;
         Lab_OpenOrder(s.direction, 0);
         return;
      }
      g_lab_last_bar = b;
   }

   // (1) hard kill first
   if(RiskControl_CheckDD()) return;
   if(RiskControl_IsHalted()) return;

   // (2) manage existing basket; stop if it fully closed this tick
   if(Exit_ManageBasket()) return;

   // gated hooks (no-op unless enabled)
   Recovery_OnTick();
   Hedge_OnTick();
   Basket_OnTick();

   // (3) entry signal
   EntrySignal sig = Entry_Evaluate();

   int haveBuy  = Exec_CountDir(1);
   int haveSell = Exec_CountDir(2);
   int have     = haveBuy + haveSell;

   if(have == 0)
   {
      // first order requires a valid entry signal
      if(!sig.valid) return;
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
