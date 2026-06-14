//+------------------------------------------------------------------+
//| Entry_GridTrendMA.mqh - trend direction via fast/slow MA cross.  |
//| Pure signal only. The chassis (EA) does the grid stacking using  |
//| InpGridStep*/InpMaxGridLevels + position state - keeping this     |
//| module signal-only (matches core StrategySignal boundary).       |
//+------------------------------------------------------------------+
#ifndef EA_LAB_ENTRY_GRIDTRENDMA_MQH
#define EA_LAB_ENTRY_GRIDTRENDMA_MQH
#include "IEntry.mqh"
#include "../Indicators.mqh"

EntrySignal Entry_Evaluate(const string sym, const ENUM_TIMEFRAMES tf)
{
   double f = Indi_FastMA(0);
   double s = Indi_SlowMA(0);
   if(f <= 0.0 || s <= 0.0) return Entry_MakeNone("MA not ready");

   if(f > s)
   {
      EntrySignal sig;
      sig.direction  = 1;
      sig.strength   = (f - s);
      sig.confidence = 1.0;
      sig.valid      = true;
      sig.reason     = "fastMA>slowMA (uptrend)";
      return sig;
   }
   if(f < s)
   {
      EntrySignal sig;
      sig.direction  = 2;
      sig.strength   = (s - f);
      sig.confidence = 1.0;
      sig.valid      = true;
      sig.reason     = "fastMA<slowMA (downtrend)";
      return sig;
   }
   return Entry_MakeNone("MA flat");
}

#endif // EA_LAB_ENTRY_GRIDTRENDMA_MQH
