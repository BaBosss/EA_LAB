//+------------------------------------------------------------------+
//|                                              M2W5C3_StopGuard.mqh |
//| Wave5 Candidate 3 (ExpertMACD) -- broker stop-validity arithmetic. |
//+------------------------------------------------------------------+
//| PURE on purpose. Every quantity these functions need is passed in; |
//| none of them touch the terminal, a symbol, or global state. That   |
//| is what lets the focused test harness drive the SHIPPED code with  |
//| synthetic quotes the strategy never actually produces (a           |
//| wrong-side stop, a zero-distance stop), instead of a copy of it    |
//| that is free to drift away from what the EA really runs.           |
//|                                                                    |
//| The one thing a pure cage cannot prove is the wiring -- that the   |
//| EA reads the right bid/ask and calls these at all. That half is    |
//| proven separately, by the runtime retest.                          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2026, MetaQuotes Ltd."

//+------------------------------------------------------------------+
//| The server's rule is "distance >= stops_level", inclusive at the   |
//| boundary. Levels reach these functions as differences of prices    |
//| already rounded to the symbol's digits, so a distance that IS      |
//| exactly the minimum can land a few 1e-16 short of it once it is    |
//| expressed in binary -- which would turn the documented `>=` into   |
//| a nondeterministic `>` and refuse an order the broker accepts.     |
//| The gate is therefore relaxed by one part per million of the       |
//| required distance: ~1e-11 on a 5-digit FX symbol, five orders of   |
//| magnitude below one tick and five above the representation noise   |
//| it is there to absorb. It cannot let a genuinely short stop        |
//| through; it only stops the boundary from flickering.               |
//+------------------------------------------------------------------+
#define SG_BOUNDARY_TOLERANCE 0.999999

//+------------------------------------------------------------------+
//| Smallest distance the server accepts between a level and the price |
//| it validates that level against.                                   |
//| STOPS_LEVEL and FREEZE_LEVEL are both honoured because either can  |
//| reject the request. The one-tick floor covers the very common      |
//| stops_level==0 broker, where a level sitting exactly ON the        |
//| validating price is still not placeable.                           |
//+------------------------------------------------------------------+
double SG_MinStopDistance(const double point,const long stops_level,
                          const long freeze_level,const double tick_size)
  {
   double tick=(tick_size>0.0) ? tick_size : point;
   long   lvl =(stops_level>freeze_level) ? stops_level : freeze_level;
   double need=(double)lvl*point;
   return((need>tick) ? need : tick);
  }
//+------------------------------------------------------------------+
//| Round a price onto the symbol's tick grid.                         |
//| Identity on a symbol whose tick size equals its point, which is    |
//| why applying it cannot disturb entries that were already valid.    |
//+------------------------------------------------------------------+
double SG_NormalizeToTick(const double price,const double tick_size,const int digits)
  {
   if(price==0.0)
      return(0.0);
   if(tick_size<=0.0)
      return(NormalizeDouble(price,digits));
   return(NormalizeDouble(MathRound(price/tick_size)*tick_size,digits));
  }
//+------------------------------------------------------------------+
//| A LONG position is closed at Bid, so the server measures BOTH of   |
//| its levels from Bid: stop below it, target above it.               |
//| A level of 0.0 means "not requested" and is never judged.          |
//| sl_bad / tp_bad report WHICH leg failed, so a refusal can never be |
//| attributed to the wrong half of the order.                         |
//+------------------------------------------------------------------+
bool SG_BuyStopsValid(const double sl,const double tp,const double bid,
                      const double need,bool &sl_bad,bool &tp_bad)
  {
   double gate=need*SG_BOUNDARY_TOLERANCE;
   sl_bad=(sl!=0.0 && (bid-sl)<gate);
   tp_bad=(tp!=0.0 && (tp-bid)<gate);
   return(!sl_bad && !tp_bad);
  }
//+------------------------------------------------------------------+
//| A SHORT position is closed at Ask, so the server measures BOTH of  |
//| its levels from Ask: stop above it, target below it.               |
//+------------------------------------------------------------------+
bool SG_SellStopsValid(const double sl,const double tp,const double ask,
                       const double need,bool &sl_bad,bool &tp_bad)
  {
   double gate=need*SG_BOUNDARY_TOLERANCE;
   sl_bad=(sl!=0.0 && (sl-ask)<gate);
   tp_bad=(tp!=0.0 && (ask-tp)<gate);
   return(!sl_bad && !tp_bad);
  }
//+------------------------------------------------------------------+
