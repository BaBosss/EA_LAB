//+------------------------------------------------------------------+
//|                                              EA_LabTemplate.mq5   |
//|   Dropdown-mode EA chassis for the EA_LAB funnel.                |
//|   Pluggable entry (signal-only) + shared MM/Exit/Risk modules.  |
//|   Phase 3a: Strategy-Tester only. Entry = Grid Trend MA.        |
//+------------------------------------------------------------------+
//| *** DEPRECATED - V1 CHASSIS, DO NOT USE FOR NEW WORK ***         |
//|                                                                   |
//| Superseded by Boss V2 (ea_template/core/ + Boss_11..18_*.mq5).   |
//| Not maintained: 0 rows in the deployments inventory, 0 backtest  |
//| reports, 0 .set files reference this file or ea_template/modules/|
//| (unmodified since 2026-06-18). Boss V2 has no dependency on this |
//| file or on modules/ - the two trees are parallel, not layered.  |
//|                                                                   |
//| Known live defects, neither fixed here (would change behavior,  |
//| this is a comment-only banner):                                 |
//|  1. Silent lot-mode fallback: MM_FirstLot() (modules/            |
//|     MoneyManagement.mqh) defaults to InpFixedLot whenever RISK   |
//|     mode can't produce a distance, with no warning/failure - the |
//|     exact silent-fallback defect Boss V2 removed in MM-SAFETY-001|
//|     (2026-07-24: V2 now fails the attach / skips the order        |
//|     instead of borrowing another mode's value).                 |
//|  2. Lot normalizer rounds a below-minimum lot UP to the broker   |
//|     minimum; Boss V2's normalizer returns 0 (skip the order)     |
//|     instead of silently sizing up past what was requested.       |
//|                                                                   |
//| Do not deploy this chassis. Do not build new work on it. See     |
//| docs/EA_CORE_AND_TEMPLATE_GUIDE.md section 3.1 (V1 vs V2) and    |
//| ea_template/DESIGN_V2.md for the full V1->V2 rationale.          |
//+------------------------------------------------------------------+
#property copyright "EA_LAB"
#property version   "1.00"
#property description "Dropdown-mode chassis (Grid Trend MA / Breakout). Strategy-Tester phase; built-in indicators only."
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
#include "modules/entries/Entry_Breakout.mqh"
#include "modules/entries/Entry_MeanReversion.mqh"
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
// entry dispatch: routes to the correct entry module based on InpEntryStyle
EntrySignal Entry_Dispatch()
{
   switch(InpEntryStyle)
   {
      case ENTRY_BREAKOUT:       return Entry_Breakout_Evaluate(_Symbol, _Period);
      case ENTRY_MEAN_REVERSION: return Entry_MeanReversion_Evaluate(_Symbol, _Period);
      default:                   return Entry_GridTrendMA_Evaluate(_Symbol, InpMA_TF);
   }
}

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
   EntrySignal sig = Entry_Dispatch();
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

   string entryTag = (InpEntryStyle == ENTRY_BREAKOUT ? "Breakout" : "GridTrendMA");
   Exec_Open(dir, lot, sl, tp, entryTag + " L" + IntegerToString(have));
}
//+------------------------------------------------------------------+
