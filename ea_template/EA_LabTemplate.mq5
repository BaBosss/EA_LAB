//+------------------------------------------------------------------+
//|                                              EA_LabTemplate.mq5   |
//|   Dropdown-mode EA chassis for the EA_LAB funnel.                |
//|   Pluggable entry (signal-only) + shared MM/Exit/Risk modules.  |
//|   Phase 3a: Strategy-Tester only. Entry = Grid Trend MA.        |
//+------------------------------------------------------------------+
#property copyright "EA_LAB"
#property version   "0.10"
#property description "Dropdown-mode chassis (Grid Trend MA). Strategy-Tester phase; built-in indicators only."
#property strict

#define __EA_LAB_TEMPLATE__ 1

// ---- include order: Inputs FIRST, then modules, then entry style ----
#include "modules/Inputs.mqh"
#include "modules/Indicators.mqh"
#include "modules/Execution.mqh"
#include "modules/RiskControl.mqh"
#include "modules/MoneyManagement.mqh"
#include "modules/ExitManager.mqh"
#include "modules/entries/Entry_GridTrendMA.mqh"
#include "modules/Recovery.mqh"
#include "modules/Hedge.mqh"
#include "modules/Basket.mqh"

//+------------------------------------------------------------------+
int OnInit()
{
   if(!Indi_Init())
   {
      Print("[INIT] indicator handles failed");
      return INIT_FAILED;
   }
   Exec_Init();
   RiskControl_Init();
   PrintFormat("[INIT] EA_LabTemplate ready | entry=%d exit=%d sl=%d firstLot=%d prog=%d dryRun=%s",
               InpEntryStyle, InpExitMode, InpSLMode, InpFirstLotMode, InpLotProgression,
               (InpDryRun ? "true" : "false"));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Indi_Deinit();
}

//+------------------------------------------------------------------+
// grid spacing in points (ATR-based or fixed)
double Grid_StepPoints()
{
   double step = (InpGridStepUseATR ? InpGridStepATRmult * Indi_ATR_Points() : InpGridStepPoints);
   if(step <= 0.0) step = (InpGridStepPoints > 0.0 ? InpGridStepPoints : 300.0);
   return step;
}

//+------------------------------------------------------------------+
void OnTick()
{
   // (1) hard kill first
   if(RiskControl_CheckDD()) return;
   if(RiskControl_IsHalted()) return;

   // (2) manage existing basket; if it fully closed this tick, stop here
   if(Exit_ManageBasket()) return;

   // gated module hooks (no-op unless enabled)
   Recovery_OnTick();
   Hedge_OnTick();
   Basket_OnTick();

   // (3) entry signal (pure direction)
   EntrySignal sig = Entry_Evaluate(_Symbol, InpMA_TF);
   if(!sig.valid) return;

   // (4) risk gate
   if(!RiskControl_AllowNewOrder()) return;

   int dir  = sig.direction;          // 1 buy / 2 sell
   int have = Exec_CountDir(dir);
   if(have >= InpMaxGridLevels) return;

   // (5) grid decision: first order, or add as trend extends by GridStep
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   double pt   = Exit_Point();
   bool   open = false;
   if(have == 0)
      open = true;
   else
   {
      double last = Exec_LastPriceDir(dir);
      double step = Grid_StepPoints() * pt;
      if(dir == 1 && t.ask >= last + step) open = true;   // add as uptrend extends
      if(dir == 2 && t.bid <= last - step) open = true;   // add as downtrend extends
   }
   if(!open) return;

   // (6) size + protective prices, then execute (one new order per tick)
   double entry = (dir == 1 ? t.ask : t.bid);
   double sl    = Exit_InitialSL(dir, entry);
   double tp    = Exit_InitialTP(dir, entry);

   double firstLot = MM_FirstLot(Exit_SLDistancePoints());
   double lot      = MM_NextLot(firstLot, have);   // have = level index

   Exec_Open(dir, lot, sl, tp, "GridTrendMA L" + IntegerToString(have));
}
//+------------------------------------------------------------------+
