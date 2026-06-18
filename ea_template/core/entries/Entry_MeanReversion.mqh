//+------------------------------------------------------------------+
//| Entry_MeanReversion.mqh (V2) - BB outer-band + RSI extreme.      |
//| LONG : close[1]<=BB_lower AND RSI[1]<=OS                          |
//| SHORT: close[1]>=BB_upper AND RSI[1]>=OB                          |
//| _13_RequireBB=false -> RSI-only.                                 |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_MEANREVERSION_MQH
#define BOSS_LAB_ENTRY_MEANREVERSION_MQH
#include "IEntry.mqh"
#include "../Indicators.mqh"

EntrySignal Entry_Evaluate()
{
   double rsi = Indi_RSI(1);
   if(rsi <= 0.0) return Entry_MakeNone("RSI not ready");

   double c1 = iClose(_Symbol, _Period, 1);
   if(c1 <= 0.0) return Entry_MakeNone("No close");

   double bb_upper = 0.0, bb_lower = 0.0;
   if(_13_RequireBB)
   {
      bb_upper = Indi_BB_Upper(1);
      bb_lower = Indi_BB_Lower(1);
      if(bb_upper <= 0.0 || bb_lower <= 0.0) return Entry_MakeNone("BB not ready");
   }

   int    dir    = 0;
   string reason = "";
   bool rsi_os = (rsi <= (double)_13_RSI_OS);
   bool rsi_ob = (rsi >= (double)_13_RSI_OB);
   bool at_lower = (!_13_RequireBB || c1 <= bb_lower);
   bool at_upper = (!_13_RequireBB || c1 >= bb_upper);

   if(rsi_os && at_lower)      { dir = 1; reason = "RSI<=OS & at BB lower"; }
   else if(rsi_ob && at_upper) { dir = 2; reason = "RSI>=OB & at BB upper"; }
   else return Entry_MakeNone("No MR extreme");

   if(TradeDir == TRADEDIR_LONG_ONLY  && dir == 2) return Entry_MakeNone("SHORT skipped");
   if(TradeDir == TRADEDIR_SHORT_ONLY && dir == 1) return Entry_MakeNone("LONG skipped");

   if(TrendFilter == TFILTER_ATR_EXPAND)
   {
      if(!Indi_ATR_IsExpanding(_71_ATRMA, _71_ATRRatio)) return Entry_MakeNone("ATR not expanding");
   }
   else if(TrendFilter == TFILTER_MA_SLOPE)
   {
      // for MR, slope should OPPOSE direction (counter-trend confirms reversal)
      if(!Indi_MA_IsSloping(3 - dir, _72_SlopeBar)) return Entry_MakeNone("slope not counter-trend");
   }

   double dist = (dir == 1) ? (bb_lower > 0 ? bb_lower - c1 : _13_RSI_OS - rsi)
                            : (bb_upper > 0 ? c1 - bb_upper : rsi - _13_RSI_OB);

   EntrySignal sig;
   sig.direction  = dir;
   sig.strength   = dist;
   sig.confidence = 1.0;
   sig.valid      = true;
   sig.reason     = reason;
   return sig;
}

#endif // BOSS_LAB_ENTRY_MEANREVERSION_MQH
