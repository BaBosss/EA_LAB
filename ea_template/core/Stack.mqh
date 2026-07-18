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
#include "Regime.mqh"          // add-gating: Stack_DecideAdd may consult Regime_AllowsEntryDirection
#include "PriceAction.mqh"     // StackConfirm=CONF_PA_ENGULF uses PA_Bull/BearEngulf
#include "RiskControl.mqh"
#include "MoneyManagement.mqh"
#include "ExitManager.mqh"
#include "entries/IEntry.mqh"

// grid step in price (Signal-ATR based or fixed points), with an optional
// additive pips floor (_9_StepMinPips, default 0=off). Zeus GridLog port (14)
// uses this floor to prevent near-zero-ATR degenerate spacing (its _03_MinDistPips).
// Pip = 10*point on 3/5-digit symbols (matches standalone PipSize()), else = point.
double Stack_PipSize()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = Indi_Point();
   if(digits == 5 || digits == 3) return point * 10.0;
   return point;
}

double Stack_StepPrice()
{
   double stepPts = (_9_StepUseATR ? _9_StepATRmult * Indi_ATR_Points(_9_StepATRShift) : _9_StepPoints);
   if(stepPts <= 0.0) stepPts = (_9_StepPoints > 0.0 ? _9_StepPoints : 300.0);
   double stepPrice = stepPts * Indi_Point();
   if(_9_StepMinPips > 0.0)
   {
      double floorPrice = _9_StepMinPips * Stack_PipSize();
      if(stepPrice < floorPrice) stepPrice = floorPrice;
   }
   return stepPrice;
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

      case CONF_PA_ENGULF:
         // add only when an engulfing confirms the add direction: a long add
         // needs a bullish engulfing (real bounce), a short add a bearish one.
         // Turns a blind distance grid into "add at a confirmed turn/continuation".
         return (dir == 1) ? PA_BullEngulf() : PA_BearEngulf();
   }
   return false;
}

// ---- STACK_PYRAMID (93) - pending ladder (MERGE-03) ----------------------
// Leg0 opens through LabCore's normal first-entry path; this places legs 1..N
// as resting pendings ONCE per basket, then does nothing until flat again.
// No per-leg TP, no market adds, Exec_CloseAll() clears leftovers on any exit.
bool g_stack_ladder_placed = false;

void Stack_ManagePyramid()
{
   if(StackMode != STACK_PYRAMID) return;

   int filled  = Exec_CountAll();
   int pending = Exec_CountPending();

   if(filled == 0)
   {
      // flat: safety-net cancel (normal path already cancelled via CloseAll)
      if(pending > 0) Exec_CancelAllPending();
      g_stack_ladder_placed = false;
      return;
   }
   if(g_stack_ladder_placed) return;
   if(_9_PendingMode != 2 && _9_PendingMode != 3) { g_stack_ladder_placed = true; return; }
   if(filled != 1 || pending > 0)
   {
      // mid-basket restart/recompile: ladder (or its fills) already exists at
      // the broker - never re-place on top of it
      g_stack_ladder_placed = true;
      return;
   }

   double step = Stack_StepPrice();
   if(step <= 0.0) return;
   int dir = (Exec_CountDir(1) > 0 ? 1 : 2);
   double leg0price = Exec_LastPriceDir(dir);
   double leg0lot   = Exec_TotalLots();          // filled==1 -> exactly leg0's lot
   if(leg0price <= 0.0 || leg0lot <= 0.0) return;

   int maxLegs = RiskControl_MaxLevels();
   int nPend   = _9_PendingLegs;
   if(nPend > maxLegs - 1) nPend = maxLegs - 1;
   if(nPend <= 0) { g_stack_ladder_placed = true; return; }
   if(!RiskControl_AllowNewOrder()) return;      // deposit-load block: retry next tick

   bool isStop = (_9_PendingMode == 3);
   bool anyPlaced = false;
   for(int k = 1; k <= nPend; k++)
   {
      double off   = k * step;
      double price = (dir == 1 ? (isStop ? leg0price + off : leg0price - off)
                               : (isStop ? leg0price - off : leg0price + off));
      double lot   = MM_NextLot(leg0lot, k);
      double sl    = Exit_InitialSL(dir, price);
      if(Exec_PlacePending(dir, isStop, lot, price, sl, "PYR L" + IntegerToString(k)))
         anyPlaced = true;
   }
   // ORDER-129b (Codex audit): a tick where EVERY leg is vetoed (news/macro/spread window)
   // must not latch the ladder as placed - that left the basket permanently single-leg
   // after conditions normalized. Zero placed -> retry next tick. (A partial ladder still
   // latches; full transactional per-leg tracking = ORDER-132.)
   g_stack_ladder_placed = anyPlaced;
}

// Should we add a stacked order now? dir = current basket direction.
bool Stack_DecideAdd(const int dir, const int have, const EntrySignal &sig)
{
   if(StackMode == STACK_PYRAMID) return false;         // 93: adds come from the resting ladder only
   if(StackMode == STACK_SINGLE) return false;          // 90: never add
   if(have >= RiskControl_MaxLevels()) return false;    // cage + stack cap

   // add-gating (opt-in, default off): don't extend a basket when the 5x Regime
   // disallows its direction. The LabCore Regime gate only blocks the flat seed;
   // this closes the gap for the grid ADDS. Reuses the ADX Regime module.
   if(_9_RegimeGateAdds)
   {
      const int regimeDir = (dir == 1) ? 1 : 2;   // Stack dir 1=long/else short -> Regime 1/2
      if(!Regime_AllowsEntryDirection(regimeDir)) return false;
   }

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
