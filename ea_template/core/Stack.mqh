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
         datetime lastT = Exec_LastDirectionalTimeDir(dir);
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
// as resting pendings per basket, then does nothing until flat again.
// No per-leg TP, no market adds, Exec_CloseAll() clears leftovers on any exit.
// ORDER-132 (Codex F2-full): placement is TRANSACTIONAL - each leg carries its
// own placed flag + ticket, a rejected leg (news/macro/spread veto, broker
// error, margin budget) is retried every tick, and the ladder latches complete
// only when EVERY leg is broker-confirmed. Replaces the 129b any-placed patch
// (which stopped the zero-placed latch but still froze partial ladders).
#define STACK_MAX_LEGS 63

bool   g_stack_ladder_placed = false;              // every leg confirmed (or nothing to place)
bool   g_stack_ladder_own    = false;              // THIS session armed the current basket's ladder
int    g_stack_ladder_legs   = 0;                  // legs planned at arm time
int    g_stack_dir           = 0;                  // basket direction at arm time
double g_stack_leg0_price    = 0.0;                // leg0 refs snapshotted at arm time -
double g_stack_leg0_lot      = 0.0;                //   retries must NOT re-base on later fills
bool   g_stack_leg_ok[STACK_MAX_LEGS + 1];         // per-leg broker-confirmed (index 1..legs)
ulong  g_stack_leg_ticket[STACK_MAX_LEGS + 1];     // per-leg ticket (tracking/log; 0 in DryRun)

void Stack_LadderReset()
{
   g_stack_ladder_placed = false;
   g_stack_ladder_own    = false;
   g_stack_ladder_legs   = 0;
   g_stack_dir           = 0;
   g_stack_leg0_price    = 0.0;
   g_stack_leg0_lot      = 0.0;
   for(int k = 0; k <= STACK_MAX_LEGS; k++) { g_stack_leg_ok[k] = false; g_stack_leg_ticket[k] = 0; }
}

// ORDER-132 (Codex system-review SEV-1 #5): GTC ladder legs consume margin at
// FILL time, when the deposit-load cage can no longer refuse them - the old
// placement-time RiskControl_AllowNewOrder check was not enough (several legs
// filling together on a gap could jump load far above the cap). Budget = used
// margin + projected margin of every own resting pending + this leg, against
// the SAME cage cap (RC_MaxDepositLoadPct). Fail-closed: an unpriceable leg
// waits and is retried by the transactional loop - never placed unpriced.
bool Stack_MarginBudgetOK(const int dir, const double lot, const double price)
{
   double maxLoadPct = RC_MaxDepositLoadPct();
   if(maxLoadPct <= 0.0) return true;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0.0) return false;
   double legM = 0.0;
   ResetLastError();
   if(!OrderCalcMargin((dir == 1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), _Symbol, lot, price, legM))
   {
      static datetime last_log_calc = 0;
      datetime now = TimeCurrent();
      if(now - last_log_calc >= 60)
      {
         last_log_calc = now;
         PrintFormat("[STACK] OrderCalcMargin failed (err %d) - leg blocked (fail-closed), retrying", GetLastError());
      }
      return false;
   }
   double projected = AccountInfoDouble(ACCOUNT_MARGIN) + Exec_PendingMarginProjection() + legM;
   double loadPct   = 100.0 * projected / bal;
   if(loadPct >= maxLoadPct)
   {
      static datetime last_log_budget = 0;
      datetime now = TimeCurrent();
      if(now - last_log_budget >= 60)
      {
         last_log_budget = now;
         PrintFormat("[STACK] margin budget: leg blocked (projected load %.1f%% >= cap %.1f%%) - retrying",
                     loadPct, maxLoadPct);
      }
      return false;
   }
   return true;
}

// ORDER-132b (Codex E3): find an OWN resting pending within `tol` of a target
// price that is not already claimed by another leg - used to adopt the result
// of an ambiguous placement (timeout) instead of duplicating the leg. Ladder
// legs sit a full step apart, so half a step is an unambiguous match radius.
ulong Stack_FindPendingNear(const double price, const double tol)
{
   if(tol <= 0.0) return 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!Exec_OrdIsMine(i)) continue;
      ulong tk = OrderGetTicket(i);
      if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - price) > tol) continue;
      bool taken = false;
      for(int j = 1; j <= g_stack_ladder_legs; j++)
         if(g_stack_leg_ticket[j] != 0 && g_stack_leg_ticket[j] == tk) { taken = true; break; }
      if(!taken) return tk;
   }
   return 0;
}

void Stack_ManagePyramid()
{
   if(StackMode != STACK_PYRAMID) return;

   int filled  = Exec_CountDirectionalDir(0);
   int pending = Exec_CountPending();

   if(filled == 0)
   {
      // flat: safety-net cancel (normal path already cancelled via CloseAll)
      if(pending > 0) Exec_CancelAllPending();
      Stack_LadderReset();
      return;
   }
   if(g_stack_ladder_placed) return;
   if(_9_PendingMode != 2 && _9_PendingMode != 3) { g_stack_ladder_placed = true; return; }

   if(!g_stack_ladder_own)
   {
      if(filled != 1 || pending > 0)
      {
         // mid-basket restart/recompile: ladder (or its fills) already exists at
         // the broker and THIS session did not place it - never re-place on top
         g_stack_ladder_placed = true;
         return;
      }
      // arm: snapshot leg0 refs once. Later retry ticks may see filled>1 (a
      // pending filled) - LastPriceDir/TotalLots would then re-base the ladder
      // on the wrong leg, so every retry reuses this snapshot.
      int dir = (Exec_CountDirectionalDir(1) > 0 ? 1 : 2);
      double leg0price = Exec_LastDirectionalPriceDir(dir);
      double leg0lot   = Exec_TotalDirectionalLots(); // filled==1 -> exactly leg0's lot
      if(leg0price <= 0.0 || leg0lot <= 0.0) return;

      int maxLegs = RiskControl_MaxLevels();
      int nPend   = _9_PendingLegs;
      if(nPend > maxLegs - 1) nPend = maxLegs - 1;
      if(nPend > STACK_MAX_LEGS) nPend = STACK_MAX_LEGS;
      if(nPend <= 0) { g_stack_ladder_placed = true; return; }

      g_stack_ladder_own  = true;
      g_stack_ladder_legs = nPend;
      g_stack_dir         = dir;
      g_stack_leg0_price  = leg0price;
      g_stack_leg0_lot    = leg0lot;
      for(int k = 0; k <= STACK_MAX_LEGS; k++) { g_stack_leg_ok[k] = false; g_stack_leg_ticket[k] = 0; }
   }

   if(!RiskControl_AllowNewOrder()) return;      // halt / deposit-load block: retry next tick
   double step = Stack_StepPrice();
   if(step <= 0.0) return;

   bool isStop = (_9_PendingMode == 3);
   bool allOk  = true;
   for(int k = 1; k <= g_stack_ladder_legs; k++)
   {
      if(g_stack_leg_ok[k]) continue;
      double off   = k * step;
      double price = (g_stack_dir == 1 ? (isStop ? g_stack_leg0_price + off : g_stack_leg0_price - off)
                                       : (isStop ? g_stack_leg0_price - off : g_stack_leg0_price + off));
      // ORDER-132b (Codex E3): an earlier AMBIGUOUS attempt (timeout reported as
      // failure, broker created the order anyway) must not be re-placed as a
      // duplicate leg - adopt an own resting pending near the target first.
      ulong adopted = Stack_FindPendingNear(price, step * 0.5);
      if(adopted != 0)
      {
         g_stack_leg_ok[k]     = true;
         g_stack_leg_ticket[k] = adopted;
         PrintFormat("[STACK] leg %d adopted existing pending %I64u (earlier ambiguous placement)", k, adopted);
         continue;
      }
      double lot   = MM_NextLot(g_stack_leg0_lot, k);
      if(!Stack_MarginBudgetOK(g_stack_dir, lot, price)) { allOk = false; continue; }   // budget: leg waits
      double sl    = Exit_InitialSL(g_stack_dir, price);
      if(Exec_PlacePending(g_stack_dir, isStop, lot, price, sl, "PYR L" + IntegerToString(k)))
      {
         // ORDER-132b (Codex E3): a confirmed leg needs a real ticket, not just a
         // true-ish call result (DryRun keeps intent-only semantics with ticket 0)
         ulong tkNew = (DryRun ? 0 : g_trade.ResultOrder());
         if(DryRun || tkNew != 0)
         {
            g_stack_leg_ok[k]     = true;
            g_stack_leg_ticket[k] = tkNew;
         }
         else
            allOk = false;   // accepted-looking call without a ticket: NOT confirmed
      }
      else
         allOk = false;                                   // vetoed/rejected: retry next tick
   }
   g_stack_ladder_placed = allOk;
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
   double last = Exec_LastDirectionalPriceDir(dir);
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
