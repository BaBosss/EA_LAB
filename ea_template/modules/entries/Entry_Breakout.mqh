//+------------------------------------------------------------------+
//| Entry_Breakout.mqh - Donchian channel breakout signal.           |
//| BUY  when ask breaks N-bar high; SELL when bid breaks N-bar low. |
//| InpBreakoutConfirmBars >= 1: require that many consecutive closed |
//| bars beyond the channel before firing (0 = tick-level breakout). |
//| Respects InpTradeDirection and InpTrendFilter (shared dropdowns). |
//+------------------------------------------------------------------+
#ifndef EA_LAB_ENTRY_BREAKOUT_MQH
#define EA_LAB_ENTRY_BREAKOUT_MQH
#include "IEntry.mqh"
#include "../Indicators.mqh"

// returns true if N consecutive closed bars all closed beyond level
bool Breakout_ClosesConfirm(const int dir, const double level, const int nBars)
{
   for(int i = 1; i <= nBars; i++)
   {
      double c = iClose(_Symbol, _Period, i);
      if(c <= 0.0)               return false;
      if(dir == 1 && c <= level) return false;
      if(dir == 2 && c >= level) return false;
   }
   return true;
}

EntrySignal Entry_Breakout_Evaluate(const string sym, const ENUM_TIMEFRAMES tf)
{
   int lookback = (InpBreakoutBars > 1 ? InpBreakoutBars : 2);

   // channel anchored 1 bar back (avoids look-ahead on current open bar)
   double channel_high = Indi_HighestHigh(lookback, 1);
   double channel_low  = Indi_LowestLow(lookback, 1);
   if(channel_high <= 0.0 || channel_low <= 0.0)
      return Entry_MakeNone("Channel levels not ready");

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return Entry_MakeNone("No tick");

   int    dir    = 0;
   string reason = "";

   if(t.ask > channel_high)
   {
      dir    = 1;
      reason = StringFormat("ASK %.5f > %d-bar high %.5f", t.ask, lookback, channel_high);
   }
   else if(t.bid < channel_low)
   {
      dir    = 2;
      reason = StringFormat("BID %.5f < %d-bar low %.5f", t.bid, lookback, channel_low);
   }
   else
      return Entry_MakeNone("Inside channel");

   // optional close-confirmation (InpBreakoutConfirmBars >= 1)
   if(InpBreakoutConfirmBars >= 1)
   {
      double confirm_level = (dir == 1 ? channel_high : channel_low);
      if(!Breakout_ClosesConfirm(dir, confirm_level, InpBreakoutConfirmBars))
         return Entry_MakeNone("Close confirm not met");
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
   sig.strength   = (dir == 1 ? t.ask - channel_high : channel_low - t.bid);
   sig.confidence = 1.0;
   sig.valid      = true;
   sig.reason     = reason;
   return sig;
}

#endif // EA_LAB_ENTRY_BREAKOUT_MQH
