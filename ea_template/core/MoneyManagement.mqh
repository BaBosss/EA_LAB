//+------------------------------------------------------------------+
//| MoneyManagement.mqh (V2) - lot sizing.                           |
//|  first order : 41 Fixed / 42 Risk% (risk / SL distance)          |
//|  progression : 50 None / 51 Lin / 52 Mult / 53 Plus / 54 Log     |
//|  All clamped by RiskControl (RC_MaxLot) + Exec normalize.        |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_MM_MQH
#define BOSS_LAB_MM_MQH
#include "Inputs.mqh"
#include "RiskControl.mqh"

double MM_MoneyPerPointPerLot()
{
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tickSize <= 0.0) return 0.0;
   return tickVal * (point / tickSize);
}

// first-order lot. slDistancePoints required for RISK mode (else fixed).
double MM_FirstLot(const double slDistancePoints)
{
   double lot = _41_FixedLot;
   if(FirstLotMode == FIRSTLOT_RISK && slDistancePoints > 0.0)
   {
      double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * _42_RiskPct / 100.0;
      double perPoint  = MM_MoneyPerPointPerLot();
      if(perPoint > 0.0)
         lot = riskMoney / (slDistancePoints * perPoint);
   }
   return RiskControl_ClampLot(lot);
}

// lot for stacked order at given level (0 = first).
double MM_NextLot(const double firstLot, const int level)
{
   int lv    = level;
   int maxLv = RiskControl_MaxLevels();
   if(lv > maxLv) lv = maxLv;

   double lot = firstLot;
   switch(LotProg)
   {
      case PROG_LINEAR:
         lot = firstLot * (1.0 + _51_ProgFactor * lv);
         break;
      case PROG_MULTIPLIER:
      {
         double m = _52_ProgMult;
         if(RC_RecMultMax > 0.0 && m > RC_RecMultMax) m = RC_RecMultMax;
         lot = firstLot * MathPow(m, lv);
         break;
      }
      case PROG_PLUS:
         lot = firstLot + _53_PlusLot * lv;
         break;
      case PROG_LOG:
         lot = firstLot * (1.0 + _51_ProgFactor * MathLog((double)(lv + 1)));
         break;
      case PROG_NONE:
      default:
         lot = firstLot;
         break;
   }
   return RiskControl_ClampLot(lot);
}

#endif // BOSS_LAB_MM_MQH
