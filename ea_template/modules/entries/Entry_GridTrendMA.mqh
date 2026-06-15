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

EntrySignal Entry_GridTrendMA_Evaluate(const string sym, const ENUM_TIMEFRAMES tf)
{
   double f = Indi_FastMA(0);
   double s = Indi_SlowMA(0);
   if(f <= 0.0 || s <= 0.0) return Entry_MakeNone("MA not ready");

   int dir = 0;
   if(f > s) dir = 1;
   else if(f < s) dir = 2;
   else return Entry_MakeNone("MA flat");

   // direction bias gate
   if(InpTradeDirection == TRADEDIR_LONG_ONLY  && dir == 2) return Entry_MakeNone("SHORT skipped (LONG_ONLY)");
   if(InpTradeDirection == TRADEDIR_SHORT_ONLY && dir == 1) return Entry_MakeNone("LONG skipped (SHORT_ONLY)");

   // trend filter gate (optional)
   if(InpTrendFilter == TFILTER_ATR_EXPAND)
   {
      if(!Indi_ATR_IsExpanding(InpFilterATRMA, InpFilterATRRatio))
         return Entry_MakeNone("ATR not expanding (choppy market)");
   }
   else if(InpTrendFilter == TFILTER_MA_SLOPE)
   {
      if(!Indi_MA_IsSloping(dir, InpFilterSlopeBar))
         return Entry_MakeNone("MA not sloping in direction");
   }

   EntrySignal sig;
   sig.direction  = dir;
   sig.strength   = (dir == 1 ? f - s : s - f);
   sig.confidence = 1.0;
   sig.valid      = true;
   sig.reason     = (dir == 1 ? "fastMA>slowMA (uptrend)" : "fastMA<slowMA (downtrend)");
   return sig;
}

#endif // EA_LAB_ENTRY_GRIDTRENDMA_MQH
