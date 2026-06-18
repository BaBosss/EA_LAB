//+------------------------------------------------------------------+
//| Entry_MeanReversion.mqh - BB outer-band + RSI extreme bounce.    |
//|                                                                  |
//| LONG  signal: close[1] <= BB_lower AND RSI[1] <= OS level       |
//| SHORT signal: close[1] >= BB_upper AND RSI[1] >= OB level       |
//|                                                                  |
//| InpMR_RequireBB = false → RSI-only mode (BB check skipped)      |
//| Respects InpTradeDirection and InpTrendFilter (shared dropdowns).|
//+------------------------------------------------------------------+
#ifndef EA_LAB_ENTRY_MEANREVERSION_MQH
#define EA_LAB_ENTRY_MEANREVERSION_MQH
#include "IEntry.mqh"
#include "../Indicators.mqh"

EntrySignal Entry_MeanReversion_Evaluate(const string sym, const ENUM_TIMEFRAMES tf)
{
   double rsi = Indi_RSI(1);
   if(rsi <= 0.0) return Entry_MakeNone("RSI not ready");

   double c1 = iClose(sym, tf, 1);
   if(c1 <= 0.0) return Entry_MakeNone("No close data");

   double bb_upper = 0.0, bb_lower = 0.0;
   if(InpMR_RequireBB)
   {
      bb_upper = Indi_BB_Upper(1);
      bb_lower = Indi_BB_Lower(1);
      if(bb_upper <= 0.0 || bb_lower <= 0.0) return Entry_MakeNone("BB not ready");
   }

   int    dir    = 0;
   string reason = "";

   bool rsi_os = (rsi <= (double)InpMR_RSI_OS);
   bool rsi_ob = (rsi >= (double)InpMR_RSI_OB);
   bool at_lower = (!InpMR_RequireBB || c1 <= bb_lower);
   bool at_upper = (!InpMR_RequireBB || c1 >= bb_upper);

   if(rsi_os && at_lower)
   {
      dir    = 1;
      reason = StringFormat("RSI %.1f <= %d  close %.5f <= BB_lo %.5f", rsi, InpMR_RSI_OS, c1, bb_lower);
   }
   else if(rsi_ob && at_upper)
   {
      dir    = 2;
      reason = StringFormat("RSI %.1f >= %d  close %.5f >= BB_hi %.5f", rsi, InpMR_RSI_OB, c1, bb_upper);
   }
   else
      return Entry_MakeNone("No MR extreme");

   // direction bias gate (shared)
   if(InpTradeDirection == TRADEDIR_LONG_ONLY  && dir == 2) return Entry_MakeNone("SHORT skipped (LONG_ONLY)");
   if(InpTradeDirection == TRADEDIR_SHORT_ONLY && dir == 1) return Entry_MakeNone("LONG skipped (SHORT_ONLY)");

   // trend filter gate (shared — for MR, ATR_EXPAND is a useful volatility gate)
   if(InpTrendFilter == TFILTER_ATR_EXPAND)
   {
      if(!Indi_ATR_IsExpanding(InpFilterATRMA, InpFilterATRRatio))
         return Entry_MakeNone("ATR not expanding");
   }
   else if(InpTrendFilter == TFILTER_MA_SLOPE)
   {
      // for mean-reversion, MA slope should OPPOSE direction (counter-trend confirms reversal)
      if(!Indi_MA_IsSloping(3 - dir, InpFilterSlopeBar))
         return Entry_MakeNone("MA slope not counter-trend");
   }

   double dist = (dir == 1) ? (bb_lower > 0 ? bb_lower - c1 : InpMR_RSI_OS - rsi)
                             : (bb_upper > 0 ? c1 - bb_upper : rsi - InpMR_RSI_OB);

   EntrySignal sig;
   sig.direction  = dir;
   sig.strength   = dist;
   sig.confidence = 1.0;
   sig.valid      = true;
   sig.reason     = reason;
   return sig;
}

#endif // EA_LAB_ENTRY_MEANREVERSION_MQH
