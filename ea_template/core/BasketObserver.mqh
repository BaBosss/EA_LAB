//+------------------------------------------------------------------+
//| BasketObserver.mqh (R18 v1) - worst basket depth and hold time   |
//| for the optimize standard (docs/workflows/                       |
//| EA_TEMPLATE_OPTIMIZE_STANDARD.md R18).                           |
//|                                                                  |
//| READ-ONLY and STRATEGY-TESTER-ONLY: it never sends, modifies or  |
//| closes an order, and outside the tester every function returns   |
//| at its first line, so a live chart behaves byte-for-byte as      |
//| before.                                                          |
//|                                                                  |
//| A basket is one episode from "no open position" to the next "no  |
//| open position". In the tester the account holds this EA alone,   |
//| so every position counts (B17 opens legs under per-structure     |
//| magics, so a magic filter would miss them). Depth is the largest |
//| fall of EQUITY below equity at basket start, as % of that start: |
//| closed and floating legs of the same episode count together, so  |
//| a deep grid that closes a few legs on the way down is not        |
//| under-measured (memory guard-bounds-floating-not-episode).       |
//| A basket still open on the last tick is closed out as of that    |
//| tick (its floating loss counts, at the bid/ask the tester used). |
//|                                                                  |
//| Output: OnTester() returns                                       |
//|   1e12 + depth_bp * 1e6 + min(hold_hours, 999999)                |
//| so "OnTester result" (single run) and "Custom" (optimizer pass)  |
//| carry both numbers, and a value below 1e12 means the observer    |
//| did not run. depth_bp = depth in basis points (0..10000).        |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_BASKET_OBSERVER_MQH
#define BOSS_LAB_BASKET_OBSERVER_MQH

bool     g_bo_active      = false;   // a basket is open
datetime g_bo_start_time  = 0;
double   g_bo_start_eq    = 0.0;
double   g_bo_flat_eq     = 0.0;     // equity on the last tick with no position (pre-entry baseline)
double   g_bo_depth_pct   = 0.0;     // depth of the open basket so far
double   g_bo_worst_pct   = 0.0;     // worst depth over the run
double   g_bo_worst_hold  = 0.0;     // longest hold over the run, seconds
int      g_bo_baskets     = 0;
bool     g_bo_open_at_end = false;

void BasketObserver_Close(const datetime when)
{
   double hold = (double)(when - g_bo_start_time);
   if(g_bo_depth_pct > g_bo_worst_pct) g_bo_worst_pct = g_bo_depth_pct;
   if(hold > g_bo_worst_hold) g_bo_worst_hold = hold;
   g_bo_active = false;
}

void BasketObserver_OnTick()
{
   if(!MQLInfoInteger(MQL_TESTER)) return;
   int open = PositionsTotal();
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(!g_bo_active)
   {
      if(open <= 0) { g_bo_flat_eq = eq; return; }
      // The hook runs before trading, so the first tick that SEES the basket is the one after
      // its first entry. Start from what was true before it: equity on the last flat tick (an
      // entry commission already lowers the balance, so balance would understate the depth).
      // Only if the EA has never been flat on a tick (positions from tick one) is balance used.
      // The start time is the earliest open position's own open time.
      g_bo_active     = true;
      g_bo_start_eq   = (g_bo_flat_eq > 0.0 ? g_bo_flat_eq : AccountInfoDouble(ACCOUNT_BALANCE));
      g_bo_start_time = TimeCurrent();
      for(int i = 0; i < open; i++)
      {
         ulong tk = PositionGetTicket(i);
         if(tk > 0 && PositionSelectByTicket(tk))
         {
            datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
            if(ot > 0 && ot < g_bo_start_time) g_bo_start_time = ot;
         }
      }
      g_bo_depth_pct  = 0.0;
      g_bo_baskets++;
   }
   if(g_bo_start_eq > 0.0)
   {
      double d = (g_bo_start_eq - eq) / g_bo_start_eq * 100.0;
      if(d > g_bo_depth_pct) g_bo_depth_pct = d;
   }
   if(open <= 0)
   {
      g_bo_flat_eq = eq;                // flat again: the next basket starts from here
      BasketObserver_Close(TimeCurrent());
   }
}

double BasketObserver_Result()
{
   if(!MQLInfoInteger(MQL_TESTER)) return 0.0;
   BasketObserver_OnTick();             // final sample, also opens a basket first entered on the last tick
   if(g_bo_active) { g_bo_open_at_end = true; BasketObserver_Close(TimeCurrent()); }
   double bp = MathMin(10000.0, MathMax(0.0, MathRound(g_bo_worst_pct * 100.0)));
   double hh = MathMin(999999.0, MathFloor(g_bo_worst_hold / 3600.0));
   PrintFormat("[R18] baskets=%d worst_depth_pct=%.2f worst_hold_h=%.0f open_at_end=%s",
               g_bo_baskets, g_bo_worst_pct, hh, (g_bo_open_at_end ? "true" : "false"));
   return 1e12 + bp * 1e6 + hh;
}

#endif
