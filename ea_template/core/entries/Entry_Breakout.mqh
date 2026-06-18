//+------------------------------------------------------------------+
//| Entry_Breakout.mqh (V2) - Donchian channel breakout signal.      |
//| Channel anchored BEFORE the confirm window (no look-ahead).      |
//| _12_ConfirmBars=0 tick-level, >=1 N closed bars beyond level.    |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_BREAKOUT_MQH
#define BOSS_LAB_ENTRY_BREAKOUT_MQH
#include "IEntry.mqh"
#include "../Indicators.mqh"

EntrySignal Entry_Evaluate()
{
   int lookback = (_12_Bars > 1 ? _12_Bars : 2);
   int confirmN = (_12_ConfirmBars >= 1 ? _12_ConfirmBars : 0);
   int channelStart = confirmN + 1;

   double ch_high = Indi_HighestHigh(lookback, channelStart);
   double ch_low  = Indi_LowestLow(lookback,  channelStart);
   if(ch_high <= 0.0 || ch_low <= 0.0) return Entry_MakeNone("Channel not ready");

   int    dir    = 0;
   string reason = "";

   if(confirmN == 0)
   {
      MqlTick t;
      if(!SymbolInfoTick(_Symbol, t)) return Entry_MakeNone("No tick");
      if(t.ask > ch_high)      { dir = 1; reason = "ask>chHigh"; }
      else if(t.bid < ch_low)  { dir = 2; reason = "bid<chLow"; }
      else return Entry_MakeNone("Inside channel");
   }
   else
   {
      double c1 = iClose(_Symbol, _Period, 1);
      if(c1 <= 0.0) return Entry_MakeNone("No close");
      if(c1 > ch_high)      dir = 1;
      else if(c1 < ch_low)  dir = 2;
      else return Entry_MakeNone("Close[1] inside");

      for(int i = 2; i <= confirmN; i++)
      {
         double c = iClose(_Symbol, _Period, i);
         if(c <= 0.0)                 return Entry_MakeNone("No close");
         if(dir == 1 && c <= ch_high) return Entry_MakeNone("Confirm not met");
         if(dir == 2 && c >= ch_low)  return Entry_MakeNone("Confirm not met");
      }
      reason = "close-confirmed breakout";
   }

   // session filter (UTC hour)
   if(_12_HourFrom != _12_HourTo)
   {
      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      int h = dt.hour;
      bool inSession = (_12_HourFrom <= _12_HourTo)
                          ? (h >= _12_HourFrom && h < _12_HourTo)
                          : (h >= _12_HourFrom || h < _12_HourTo);
      if(!inSession) return Entry_MakeNone("Outside session");
   }

   if(TradeDir == TRADEDIR_LONG_ONLY  && dir == 2) return Entry_MakeNone("SHORT skipped");
   if(TradeDir == TRADEDIR_SHORT_ONLY && dir == 1) return Entry_MakeNone("LONG skipped");

   if(TrendFilter == TFILTER_ATR_EXPAND)
   {
      if(!Indi_ATR_IsExpanding(_71_ATRMA, _71_ATRRatio)) return Entry_MakeNone("ATR not expanding");
   }
   else if(TrendFilter == TFILTER_MA_SLOPE)
   {
      if(!Indi_MA_IsSloping(dir, _72_SlopeBar)) return Entry_MakeNone("MA not sloping");
   }

   EntrySignal sig;
   sig.direction  = dir;
   sig.strength   = (dir == 1 ? iClose(_Symbol,_Period,1) - ch_high : ch_low - iClose(_Symbol,_Period,1));
   sig.confidence = 1.0;
   sig.valid      = true;
   sig.reason     = reason;
   return sig;
}

#endif // BOSS_LAB_ENTRY_BREAKOUT_MQH
