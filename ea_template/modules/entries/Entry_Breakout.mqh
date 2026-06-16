//+------------------------------------------------------------------+
//| Entry_Breakout.mqh - Donchian channel breakout signal.           |
//|                                                                  |
//| Channel anchor = bars BEFORE the confirmation window so that     |
//| confirmed closes are genuinely outside the prior channel         |
//| (avoids the look-ahead trap where bar[1] is both the confirmer  |
//| and part of the channel).                                        |
//|                                                                  |
//| InpBreakoutConfirmBars = 0 : tick-level (ask/bid vs channel)     |
//| InpBreakoutConfirmBars >= 1: require N closed bars beyond level  |
//|                                                                  |
//| Respects InpTradeDirection and InpTrendFilter (shared dropdowns).|
//+------------------------------------------------------------------+
#ifndef EA_LAB_ENTRY_BREAKOUT_MQH
#define EA_LAB_ENTRY_BREAKOUT_MQH
#include "IEntry.mqh"
#include "../Indicators.mqh"

EntrySignal Entry_Breakout_Evaluate(const string sym, const ENUM_TIMEFRAMES tf)
{
   int lookback = (InpBreakoutBars > 1 ? InpBreakoutBars : 2);
   int confirmN = (InpBreakoutConfirmBars >= 1 ? InpBreakoutConfirmBars : 0);

   // anchor channel BEFORE the confirmation window to avoid look-ahead
   // confirmN=0 → startShift=1 (exclude live bar only)
   // confirmN=1 → startShift=2 (exclude live bar + the 1 confirming bar)
   int channelStart = confirmN + 1;

   double ch_high = Indi_HighestHigh(lookback, channelStart);
   double ch_low  = Indi_LowestLow(lookback,  channelStart);
   if(ch_high <= 0.0 || ch_low <= 0.0)
      return Entry_MakeNone("Channel levels not ready");

   int    dir    = 0;
   string reason = "";

   if(confirmN == 0)
   {
      // tick-level: fire when current ask/bid pierces the channel
      MqlTick t;
      if(!SymbolInfoTick(_Symbol, t)) return Entry_MakeNone("No tick");
      if(t.ask > ch_high)
      {
         dir    = 1;
         reason = StringFormat("ASK %.5f > %d-bar high %.5f", t.ask, lookback, ch_high);
      }
      else if(t.bid < ch_low)
      {
         dir    = 2;
         reason = StringFormat("BID %.5f < %d-bar low %.5f", t.bid, lookback, ch_low);
      }
      else
         return Entry_MakeNone("Inside channel");
   }
   else
   {
      // close-confirmed: check last confirmN closed bars vs channel
      // determine candidate direction from the most recent close
      double c1 = iClose(_Symbol, _Period, 1);
      if(c1 <= 0.0) return Entry_MakeNone("No close data");

      if(c1 > ch_high)      dir = 1;
      else if(c1 < ch_low)  dir = 2;
      else return Entry_MakeNone("Close[1] inside channel");

      for(int i = 2; i <= confirmN; i++)
      {
         double c = iClose(_Symbol, _Period, i);
         if(c <= 0.0)               return Entry_MakeNone("No close data");
         if(dir == 1 && c <= ch_high) return Entry_MakeNone("Close confirm not met");
         if(dir == 2 && c >= ch_low)  return Entry_MakeNone("Close confirm not met");
      }
      reason = StringFormat("Close[1..%d] beyond %d-bar %s %.5f",
                            confirmN, lookback, (dir==1?"high":"low"), (dir==1?ch_high:ch_low));
   }

   // session filter (UTC hour gate)
   if(InpBreakoutHourFrom != InpBreakoutHourTo)
   {
      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      int h = dt.hour;
      bool inSession = (InpBreakoutHourFrom <= InpBreakoutHourTo)
                         ? (h >= InpBreakoutHourFrom && h < InpBreakoutHourTo)
                         : (h >= InpBreakoutHourFrom || h < InpBreakoutHourTo);
      if(!inSession) return Entry_MakeNone("Outside session");
   }

   // direction bias gate (shared)
   if(InpTradeDirection == TRADEDIR_LONG_ONLY  && dir == 2) return Entry_MakeNone("SHORT skipped (LONG_ONLY)");
   if(InpTradeDirection == TRADEDIR_SHORT_ONLY && dir == 1) return Entry_MakeNone("LONG skipped (SHORT_ONLY)");

   // trend filter gate (shared)
   if(InpTrendFilter == TFILTER_ATR_EXPAND)
   {
      if(!Indi_ATR_IsExpanding(InpFilterATRMA, InpFilterATRRatio))
         return Entry_MakeNone("ATR not expanding");
   }
   else if(InpTrendFilter == TFILTER_MA_SLOPE)
   {
      if(!Indi_MA_IsSloping(dir, InpFilterSlopeBar))
         return Entry_MakeNone("MA not sloping in direction");
   }

   EntrySignal sig;
   sig.direction  = dir;
   sig.strength   = (dir == 1 ? iClose(_Symbol,_Period,1) - ch_high
                               : ch_low - iClose(_Symbol,_Period,1));
   sig.confidence = 1.0;
   sig.valid      = true;
   sig.reason     = reason;
   return sig;
}

#endif // EA_LAB_ENTRY_BREAKOUT_MQH
