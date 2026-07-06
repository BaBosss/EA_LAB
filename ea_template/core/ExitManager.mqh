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

// additive: _33_SL_MaxPips (0 = off) hard-caps the ATR SL distance (price units).
// pip = 10*point on 3/5-digit symbols. Zeus GridLog parity: SL = min(mult*ATR, 150 pips).
double Exit_CapATRDist(const double distPrice)
{
   if(_33_SL_MaxATRmult > 0.0)
   {
      double atrCap = Indi_RiskATR(0) * _33_SL_MaxATRmult;
      return (atrCap > 0.0 ? MathMin(distPrice, atrCap) : distPrice);
   }
   if(_33_SL_MaxPips <= 0.0) return distPrice;
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pipPrice = ((dg == 3 || dg == 5) ? 10.0 : 1.0) * Exit_Point();
   double cap = _33_SL_MaxPips * pipPrice;
   return (cap > 0.0 ? MathMin(distPrice, cap) : distPrice);
}

// SL distance in points for a fresh order (RISK sizing); 0 if not price-based
double Exit_SLDistancePoints()
{
   double pt = Exit_Point();
   switch(SLMode)
   {
      case SL_FIXED_POINTS: return _31_SL_Pip;
      case SL_ATR:          return (pt > 0.0 ? Exit_CapATRDist(_33_SL_ATRmult * Exit_RiskATR_Scaled()) / pt : 0.0);
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
         double a = Exit_CapATRDist(_33_SL_ATRmult * Exit_RiskATR_Scaled());
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
   // additive: _2_SuppressLegTP (default false = unchanged behavior) forces
   // every leg to have NO per-order broker TP, relying solely on the basket
   // money TP (_2_BasketTP_Money) to close the whole basket together. Needed
   // by GridLog(14) port: standalone Zeus opens every leg with TP=0.0 (real
   // per-order SL only) - without this, chassis EXIT_ATR_TP attaches a live
   // per-leg TP that lets individual legs close independently of the basket,
   // fragmenting one basket-cycle into several partial trades (breaks parity).
   if(_2_SuppressLegTP) return 0.0;
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

// additive: 2-stage partial close as basket floating profit approaches the
// _2_BasketTP_Money target (Zeus GridLog port (14)). OFF unless both pct
// thresholds are > 0. Mirrors standalone ManagePartialClose(): flags reset
// whenever floating profit dips back to/below zero (re-arms for the next
// approach to target within the same basket).
bool g_exit_partial1_done = false;
bool g_exit_partial2_done = false;

// Effective basket target in account currency. ATR mode scales the target by
// current Risk-ATR and aggregate open volume, so it remains portable across
// instruments whose price and tick-value scales differ. Default ATR mult=0
// preserves the legacy fixed-money target exactly.
double Exit_BasketTargetMoney()
{
   if(_2_BasketTP_ATRmult <= 0.0) return _2_BasketTP_Money;

   double atr       = Indi_RiskATR(0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lots      = Exec_TotalLots();
   if(atr <= 0.0 || tickValue <= 0.0 || tickSize <= 0.0 || lots <= 0.0) return 0.0;

   return atr * _2_BasketTP_ATRmult * (tickValue / tickSize) * lots;
}

void Exit_ManagePartialClose()
{
   // mode 93 (pending ladder): partial-close would fragment ladder legs while
   // resting siblings are still armed - basket TP is the single exit owner
   if(StackMode == STACK_PYRAMID) return;
   double targetMoney = Exit_BasketTargetMoney();
   if(targetMoney <= 0.0) return;                      // needs a target to measure % against
   if(_2_PartialPct1 <= 0.0 && _2_PartialPct2 <= 0.0) return;   // both off

   double profit = Exec_BasketProfit();
   if(profit <= 0.0) { g_exit_partial1_done = false; g_exit_partial2_done = false; return; }

   double pctOfTarget = profit / targetMoney * 100.0;

   if(!g_exit_partial1_done && _2_PartialPct1 > 0.0 && pctOfTarget >= _2_PartialPct1)
   {
      Exec_ClosePartialFraction(_2_PartialFrac1);
      g_exit_partial1_done = true;
   }
   if(!g_exit_partial2_done && _2_PartialPct2 > 0.0 && pctOfTarget >= _2_PartialPct2)
   {
      Exec_ClosePartialFraction(_2_PartialFrac2);
      g_exit_partial2_done = true;
   }
}

// per-tick basket management; returns true if it closed the whole basket
bool Exit_ManageBasket()
{
   if(Exec_CountAll() <= 0) return false;

   Exit_ManagePartialClose();   // no-op unless _2_PartialPct1/2 set

   double profit = Exec_BasketProfit();
   double targetMoney = Exit_BasketTargetMoney();
   if(targetMoney > 0.0 && profit >= targetMoney) { Exec_CloseAll(); return true; }
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
