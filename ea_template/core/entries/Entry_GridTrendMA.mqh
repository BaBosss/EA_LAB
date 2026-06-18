//+------------------------------------------------------------------+
//| Entry_GridTrendMA.mqh (V2) - trend direction via MA cross.       |
//| Pure signal. Stacking handled by Stack.mqh. Uses shared trend MA |
//| (_0_FastMA/_0_SlowMA) + shared filter (7x).                      |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_GRIDTRENDMA_MQH
#define BOSS_LAB_ENTRY_GRIDTRENDMA_MQH
#include "IEntry.mqh"
#include "../Indicators.mqh"

EntrySignal Entry_Evaluate()
{
   double f = Indi_FastMA(0);
   double s = Indi_SlowMA(0);
   if(f <= 0.0 || s <= 0.0) return Entry_MakeNone("MA not ready");

   int dir = 0;
   if(f > s) dir = 1;
   else if(f < s) dir = 2;
   else return Entry_MakeNone("MA flat");

   if(TradeDir == TRADEDIR_LONG_ONLY  && dir == 2) return Entry_MakeNone("SHORT skipped");
   if(TradeDir == TRADEDIR_SHORT_ONLY && dir == 1) return Entry_MakeNone("LONG skipped");

   if(TrendFilter == TFILTER_ATR_EXPAND)
   {
      if(!Indi_ATR_IsExpanding(_71_ATRMA, _71_ATRRatio))
         return Entry_MakeNone("ATR not expanding");
   }
   else if(TrendFilter == TFILTER_MA_SLOPE)
   {
      if(!Indi_MA_IsSloping(dir, _72_SlopeBar))
         return Entry_MakeNone("MA not sloping");
   }

   EntrySignal sig;
   sig.direction  = dir;
   sig.strength   = (dir == 1 ? f - s : s - f);
   sig.confidence = 1.0;
   sig.valid      = true;
   sig.reason     = (dir == 1 ? "fastMA>slowMA" : "fastMA<slowMA");
   return sig;
}

#endif // BOSS_LAB_ENTRY_GRIDTRENDMA_MQH
