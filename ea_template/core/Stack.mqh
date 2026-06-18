//+------------------------------------------------------------------+
//| Stack.mqh (V2) - decides whether to ADD a stacked order.         |
//|  StackMode 9x : 90 Single / 91 GridTrend / 92 GridAgainst(DCA)   |
//|  StackConfirm : 0 Distance /1 SignalValid /2 Retrigger /3 PA     |
//|  First order is handled by LabCore (needs a valid entry signal). |
//|  This module governs ADDED orders only (have > 0).               |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_STACK_MQH
#define BOSS_LAB_STACK_MQH
#include "Inputs.mqh"
#include "Indicators.mqh"
#include "Execution.mqh"
#include "entries/IEntry.mqh"

// grid step in price (Signal-ATR based or fixed points)
double Stack_StepPrice()
{
   double stepPts = (_9_StepUseATR ? _9_StepATRmult * Indi_ATR_Points() : _9_StepPoints);
   if(stepPts <= 0.0) stepPts = (_9_StepPoints > 0.0 ? _9_StepPoints : 300.0);
   return stepPts * Indi_Point();
}

// confirm gate for an add at trigger level (dir = basket direction)
bool Stack_ConfirmOK(const int dir, const double triggerLevel, const EntrySignal &sig)
{
   switch(StackConfirm)
   {
      case CONF_DISTANCE:
         return true;

      case CONF_SIG_VALID:
         return (sig.valid && sig.direction == dir);

      case CONF_RETRIGGER:
      {
         if(!(sig.valid && sig.direction == dir)) return false;
         // require a new bar since the last order in this direction
         datetime lastT = Exec_LastTimeDir(dir);
         datetime barT  = iTime(_Symbol, _Period, 0);
         return (lastT > 0 && barT > lastT);
      }

      case CONF_PRICE_ACT:
      {
         // last CLOSED bar must close beyond the trigger level (not just a wick)
         double c1 = iClose(_Symbol, _Period, 1);
         if(c1 <= 0.0) return false;
         if(dir == 1) return (c1 >= triggerLevel);   // long add: closed above
         else         return (c1 <= triggerLevel);   // short add: closed below
      }
   }
   return false;
}

// Should we add a stacked order now? dir = current basket direction.
bool Stack_DecideAdd(const int dir, const int have, const EntrySignal &sig)
{
   if(StackMode == STACK_SINGLE) return false;          // 90: never add
   if(have >= RiskControl_MaxLevels()) return false;    // cage + stack cap

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return false;
   double last = Exec_LastPriceDir(dir);
   if(last <= 0.0) return false;
   double step = Stack_StepPrice();
   if(step <= 0.0) return false;

   bool distanceOK = false;
   double triggerLevel = 0.0;

   if(StackMode == STACK_GRID_TREND)
   {
      // add as the trend extends in the basket direction
      if(dir == 1) { triggerLevel = last + step; distanceOK = (t.ask >= triggerLevel); }
      else         { triggerLevel = last - step; distanceOK = (t.bid <= triggerLevel); }
   }
   else // STACK_GRID_AGAINST (DCA / average down)
   {
      if(dir == 1) { triggerLevel = last - step; distanceOK = (t.ask <= triggerLevel); }
      else         { triggerLevel = last + step; distanceOK = (t.bid >= triggerLevel); }
   }

   if(!distanceOK) return false;
   return Stack_ConfirmOK(dir, triggerLevel, sig);
}

#endif // BOSS_LAB_STACK_MQH
