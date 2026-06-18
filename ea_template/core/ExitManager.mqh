//+------------------------------------------------------------------+
//| ExitManager.mqh (V2) - TP/SL/trailing + basket exits.            |
//|  Exit 2x: 21 FixTP / 22 ATR_TP / 23 Trail / 24 RunTrend          |
//|  SL   3x: 30 None /31 Pip /32 Money /33 ATR(+adaptive) /34 Don   |
//|           /35 SR /36 SD. SL/TP use RISK-ATR (not signal ATR).    |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_EXITMANAGER_MQH
#define BOSS_LAB_EXITMANAGER_MQH
#include "Inputs.mqh"
#include "Indicators.mqh"
#include "Execution.mqh"

double Exit_Point() { return Indi_Point(); }

// effective Risk-ATR (price), with optional regime adaptive scaling (mode 33)
double Exit_RiskATR_Scaled()
{
   double atr = Indi_RiskATR(0);
   if(atr <= 0.0) return 0.0;
   if(_33_AdaptiveON)
   {
      double ma = Indi_RiskATR_MA(_33_AdaptiveN);
      if(ma > 0.0)
      {
         double scale = atr / ma;
         if(scale < 0.7) scale = 0.7;
         if(scale > 1.5) scale = 1.5;
         atr *= scale;
      }
   }
   return atr;
}

// SL distance in points for a fresh order (RISK sizing); 0 if not price-based
double Exit_SLDistancePoints()
{
   double pt = Exit_Point();
   switch(SLMode)
   {
      case SL_FIXED_POINTS: return _31_SL_Pip;
      case SL_ATR:          return (pt > 0.0 ? _33_SL_ATRmult * Exit_RiskATR_Scaled() / pt : 0.0);
      case SL_SD:           return (pt > 0.0 ? _36_SD_Mult * Indi_SD(1) / pt : 0.0);
      case SL_STRUCT_DONCHIAN:
      case SL_STRUCT_SR:
      {
         MqlTick t;
         if(!SymbolInfoTick(_Symbol, t)) return 0.0;
         int bars = (SLMode == SL_STRUCT_DONCHIAN ? _34_DonchianBars : _35_SRBars);
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
   switch(SLMode)
   {
      case SL_FIXED_POINTS:
         return (dir == 1 ? entryPrice - _31_SL_Pip * pt : entryPrice + _31_SL_Pip * pt);
      case SL_ATR:
      {
         double a = _33_SL_ATRmult * Exit_RiskATR_Scaled();
         return (dir == 1 ? entryPrice - a : entryPrice + a);
      }
      case SL_SD:
      {
         double a = _36_SD_Mult * Indi_SD(1);
         return (dir == 1 ? entryPrice - a : entryPrice + a);
      }
      case SL_STRUCT_DONCHIAN:
         return (dir == 1 ? Indi_LowestLow(_34_DonchianBars, 1) : Indi_HighestHigh(_34_DonchianBars, 1));
      case SL_STRUCT_SR:
         return (dir == 1 ? Indi_LowestLow(_35_SRBars, 1) : Indi_HighestHigh(_35_SRBars, 1));
      default:
         return 0.0;  // NONE, MONEY
   }
}

// initial TP price (0 = managed dynamically)
double Exit_InitialTP(const int dir, const double entryPrice)
{
   double pt = Exit_Point();
   switch(ExitMode)
   {
      case EXIT_FIXED_TP:
         return (dir == 1 ? entryPrice + _21_TP_Pip * pt : entryPrice - _21_TP_Pip * pt);
      case EXIT_ATR_TP:
      {
         double a = _22_TP_ATRmult * Exit_RiskATR_Scaled();
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
         if(gain >= _23_TrailStart)
         {
            double newSL = t.bid - _23_TrailStep * pt;
            if(newSL > curSL) Exec_ModifyPosition(tk, newSL, curTP);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double gain = (open - t.ask) / pt;
         if(gain >= _23_TrailStart)
         {
            double newSL = t.ask + _23_TrailStep * pt;
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
   if(_2_BasketTP_Money > 0.0 && profit >= _2_BasketTP_Money) { Exec_CloseAll(); return true; }
   if(_32_SL_Money > 0.0 && profit <= -_32_SL_Money)          { Exec_CloseAll(); return true; }

   if(ExitMode == EXIT_RUN_TREND)
   {
      double f = Indi_FastMA(0), s = Indi_SlowMA(0);
      if(f > 0.0 && s > 0.0)
      {
         if(Exec_CountDir(1) > 0 && f < s) { Exec_CloseAll(); return true; }
         if(Exec_CountDir(2) > 0 && f > s) { Exec_CloseAll(); return true; }
      }
   }

   if(ExitMode == EXIT_TRAIL) Exit_ApplyTrailing();

   return false;
}

#endif // BOSS_LAB_EXITMANAGER_MQH
