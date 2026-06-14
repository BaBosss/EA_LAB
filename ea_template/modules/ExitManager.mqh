//+------------------------------------------------------------------+
//| ExitManager.mqh - TP / SL / trailing + basket exits.             |
//|  ExitMode: FIXED_TP / TRAIL / RUN_TREND / ATR_TP                 |
//|  SLMode  : NONE / FIXED_POINTS / MONEY / ATR / DONCHIAN / SR     |
//| Structural SL uses price (iHighest/iLowest) - no ext indicator.  |
//+------------------------------------------------------------------+
#ifndef EA_LAB_EXITMANAGER_MQH
#define EA_LAB_EXITMANAGER_MQH
#include "Inputs.mqh"
#include "Indicators.mqh"
#include "Execution.mqh"

double Exit_Point() { double p = SymbolInfoDouble(_Symbol, SYMBOL_POINT); return (p > 0.0 ? p : _Point); }

// SL distance in points for a fresh order (used by RISK sizing); 0 if not price-based
double Exit_SLDistancePoints()
{
   double pt = Exit_Point();
   switch(InpSLMode)
   {
      case SL_FIXED_POINTS: return InpSL_Points;
      case SL_ATR:          return InpSL_ATRmult * Indi_ATR_Points();
      case SL_STRUCT_DONCHIAN:
      case SL_STRUCT_SR:
      {
         MqlTick t;
         if(!SymbolInfoTick(_Symbol, t)) return 0.0;
         int bars = (InpSLMode == SL_STRUCT_DONCHIAN ? InpSL_DonchianBars : InpSL_SRBars);
         double lo = Indi_LowestLow(bars, 1);
         double hi = Indi_HighestHigh(bars, 1);
         double dLo = (lo > 0.0 ? (t.bid - lo) / pt : 0.0);
         double dHi = (hi > 0.0 ? (hi - t.ask) / pt : 0.0);
         double d = MathMax(dLo, dHi);
         return (d > 0.0 ? d : 0.0);
      }
      default: return 0.0;  // NONE, MONEY
   }
}

// initial SL price for a new order (0 = no per-order price SL)
double Exit_InitialSL(const int dir, const double entryPrice)
{
   double pt = Exit_Point();
   switch(InpSLMode)
   {
      case SL_FIXED_POINTS:
         return (dir == 1 ? entryPrice - InpSL_Points * pt : entryPrice + InpSL_Points * pt);
      case SL_ATR:
      {
         double a = InpSL_ATRmult * Indi_ATR();
         return (dir == 1 ? entryPrice - a : entryPrice + a);
      }
      case SL_STRUCT_DONCHIAN:
         return (dir == 1 ? Indi_LowestLow(InpSL_DonchianBars, 1) : Indi_HighestHigh(InpSL_DonchianBars, 1));
      case SL_STRUCT_SR:
         return (dir == 1 ? Indi_LowestLow(InpSL_SRBars, 1) : Indi_HighestHigh(InpSL_SRBars, 1));
      default:
         return 0.0;  // NONE, MONEY
   }
}

// initial TP price for a new order (0 = managed dynamically)
double Exit_InitialTP(const int dir, const double entryPrice)
{
   double pt = Exit_Point();
   switch(InpExitMode)
   {
      case EXIT_FIXED_TP:
         return (dir == 1 ? entryPrice + InpTP_Points * pt : entryPrice - InpTP_Points * pt);
      case EXIT_ATR_TP:
      {
         double a = InpTP_ATRmult * Indi_ATR();
         return (dir == 1 ? entryPrice + a : entryPrice - a);
      }
      default:
         return 0.0;  // TRAIL, RUN_TREND
   }
}

void Exit_ApplyTrailing()
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   double pt = Exit_Point();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      long   type  = PositionGetInteger(POSITION_TYPE);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      ulong  tk    = PositionGetInteger(POSITION_TICKET);
      if(type == POSITION_TYPE_BUY)
      {
         double gain = (t.bid - open) / pt;
         if(gain >= InpTrailStartPoints)
         {
            double newSL = t.bid - InpTrailStepPoints * pt;
            if(newSL > curSL) Exec_ModifyPosition(tk, newSL, curTP);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double gain = (open - t.ask) / pt;
         if(gain >= InpTrailStartPoints)
         {
            double newSL = t.ask + InpTrailStepPoints * pt;
            if(curSL == 0.0 || newSL < curSL) Exec_ModifyPosition(tk, newSL, curTP);
         }
      }
   }
}

// per-tick basket management; returns true if it closed the whole basket
bool Exit_ManageBasket()
{
   if(Exec_CountAll() <= 0) return false;

   double profit = Exec_BasketProfit();
   if(InpTP_BasketMoney > 0.0 && profit >= InpTP_BasketMoney) { Exec_CloseAll(); return true; }
   if(InpSL_BasketMoney > 0.0 && profit <= -InpSL_BasketMoney) { Exec_CloseAll(); return true; }

   if(InpExitMode == EXIT_RUN_TREND)
   {
      double f = Indi_FastMA(0), s = Indi_SlowMA(0);
      if(f > 0.0 && s > 0.0)
      {
         if(Exec_CountDir(1) > 0 && f < s) { Exec_CloseAll(); return true; }
         if(Exec_CountDir(2) > 0 && f > s) { Exec_CloseAll(); return true; }
      }
   }

   if(InpExitMode == EXIT_TRAIL) Exit_ApplyTrailing();

   return false;
}

#endif // EA_LAB_EXITMANAGER_MQH
