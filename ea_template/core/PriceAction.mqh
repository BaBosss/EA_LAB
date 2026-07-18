//+------------------------------------------------------------------+
//| PriceAction.mqh (V2) - candle-pattern confirm helpers.           |
//|  Phase-0 seed of the PriceAction module (KNOWLEDGE_SYNTHESIS      |
//|  dev plan). For now: engulfing (Bulkowski freq-A workhorse).      |
//|  Used as a CONFIRM filter on grid adds (Stack CONF_PA_ENGULF),    |
//|  never as a naked entry. Tier-tagging / lot-mult comes later.     |
//|  All detection on the last CLOSED bars (shift 1 = signal bar,     |
//|  shift 2 = prior bar) so it is repaint-safe on a bar-open gate.   |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_PRICEACTION_MQH
#define BOSS_LAB_PRICEACTION_MQH
#include "Inputs.mqh"

// Bullish engulfing: prior bar bearish, signal bar bullish, signal body
// engulfs the prior body, and the signal body is >= MinBodyRatio x prior body.
bool PA_BullEngulf()
{
   double o1 = iOpen(_Symbol, _Period, 1), c1 = iClose(_Symbol, _Period, 1);
   double o2 = iOpen(_Symbol, _Period, 2), c2 = iClose(_Symbol, _Period, 2);
   double b1 = MathAbs(c1 - o1), b2 = MathAbs(c2 - o2);
   bool priorBear = (c2 < o2);
   bool sigBull   = (c1 > o1);
   bool engulf    = (c1 >= o2 && o1 <= c2);
   bool bigEnough = (b2 <= 0.0) ? false : (b1 >= _9_PA_MinBodyRatio * b2);
   return (priorBear && sigBull && engulf && bigEnough);
}

// Bearish engulfing (mirror).
bool PA_BearEngulf()
{
   double o1 = iOpen(_Symbol, _Period, 1), c1 = iClose(_Symbol, _Period, 1);
   double o2 = iOpen(_Symbol, _Period, 2), c2 = iClose(_Symbol, _Period, 2);
   double b1 = MathAbs(c1 - o1), b2 = MathAbs(c2 - o2);
   bool priorBull = (c2 > o2);
   bool sigBear   = (c1 < o1);
   bool engulf    = (c1 <= o2 && o1 >= c2);
   bool bigEnough = (b2 <= 0.0) ? false : (b1 >= _9_PA_MinBodyRatio * b2);
   return (priorBull && sigBear && engulf && bigEnough);
}

#endif // BOSS_LAB_PRICEACTION_MQH
