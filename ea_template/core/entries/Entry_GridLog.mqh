//+------------------------------------------------------------------+
//| Entry_GridLog.mqh (V2) - fixed-direction breakout-arm entry.     |
//| Ported from the standalone Zeus-inspired GridLog EA: the source  |
//| arms ONE pending stop order (distPrice = max(ATR*mult, minPips)  |
//| away from price) and lets the broker fill it. This chassis has   |
//| no pending-order infra (Exec_Open is market-only), so the same   |
//| trigger semantics are reproduced with a stateful arm-and-wait:   |
//| when flat, latch a reference price; once market price has moved  |
//| distPrice beyond that reference in the fixed trade direction,    |
//| fire a MARKET order (equivalent fill to the pending stop being   |
//| touched). This preserves "no confirmation, first breakout past   |
//| the level fills" behavior - just via market order, not pending.  |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_GRIDLOG_MQH
#define BOSS_LAB_ENTRY_GRIDLOG_MQH
#include "IEntry.mqh"
#include "../Indicators.mqh"

// recompile-safe arm state (reset in Entry_GridLog_Init from OnInit)
double   g_gl_armed_level   = 0.0;   // FIXED trigger level (emulated resting stop) - latched at arm time
datetime g_gl_armed_bar     = 0;     // bar on which we (re)armed - informational only
datetime g_gl_last_eval_bar = 0;     // arming is allowed only at bar open (standalone places pendings once/bar)

void Entry_GridLog_Init()
{
   g_gl_armed_level   = 0.0;
   g_gl_armed_bar     = 0;
   g_gl_last_eval_bar = 0;
}

// distance (price units) for both the arm trigger and grid-add step:
// max(Signal-ATR * _14_DistAtrMult, _14_MinDistPips * pip). Pip = 10*point on
// 3/5-digit symbols (AUDJPY=3 digits), else = point (mirrors standalone PipSize()).
double Entry_GridLog_PipSize()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = Indi_Point();
   if(digits == 5 || digits == 3) return point * 10.0;
   return point;
}

double Entry_GridLog_DistPrice()
{
   double atr = Indi_ATR(1);   // shift=1, matches standalone GetATR(1) bar-close read
   if(atr <= 0.0) return 0.0;
   double pip = Entry_GridLog_PipSize();
   double d1  = atr * _14_DistAtrMult;
   double d2  = _14_MinDistPips * pip;
   return (d1 > d2 ? d1 : d2);
}

EntrySignal Entry_Evaluate()
{
   // LabCore calls Entry_Evaluate() unconditionally every tick (even when a
   // basket is open, for entries whose signal is stateless). This entry's arm
   // state is only meaningful while flat; if a basket is open, do nothing and
   // do not touch g_gl_armed_price (avoids corrupting the next arm cycle).
   if(Exec_CountAll() > 0) return Entry_MakeNone("basket open - GridLog arm N/A");

   // Resting-stop emulation, faithful to the standalone's pending BuyStop:
   //  - ARM only at bar open (standalone's g_bar_checked gate places pendings
   //    once per bar): latch a FIXED trigger level = price + dist(ATR at arm).
   //  - TRIGGER check every tick against that fixed level (a resting stop
   //    fills intrabar at its exact level - re-deriving dist per bar would
   //    move the level and mis-price the fill; found in parity attempt 4).
   datetime curBar = iTime(_Symbol, _Period, 0);
   bool newBar = (curBar != g_gl_last_eval_bar);
   if(newBar) g_gl_last_eval_bar = curBar;

   int dir = (_14_Direction == 1 ? 1 : 2);   // fixed direction, never both (matches standalone)

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return Entry_MakeNone("No tick");

   if(g_gl_armed_level <= 0.0)
   {
      if(!newBar) return Entry_MakeNone("flat intrabar - arm waits for bar open");
      double dist = Entry_GridLog_DistPrice();
      if(dist <= 0.0) return Entry_MakeNone("ATR not ready");
      g_gl_armed_level = (dir == 1 ? t.ask + dist : t.bid - dist);
      g_gl_armed_bar   = curBar;
      return Entry_MakeNone("armed, resting level latched");
   }

   bool triggered = (dir == 1) ? (t.ask >= g_gl_armed_level)
                                : (t.bid <= g_gl_armed_level);
   if(!triggered) return Entry_MakeNone("waiting for breakout");

   EntrySignal sig;
   sig.direction  = dir;
   sig.strength   = g_gl_armed_level;   // informational: the resting level that filled
   sig.confidence = 1.0;
   sig.valid      = true;
   sig.reason     = "breakout-arm triggered";
   // disarm - LabCore will open the order this tick; re-arm happens naturally
   // next time Entry_Evaluate() runs with have==0 (basket flat again).
   g_gl_armed_level = 0.0;
   return sig;
}

#endif // BOSS_LAB_ENTRY_GRIDLOG_MQH
