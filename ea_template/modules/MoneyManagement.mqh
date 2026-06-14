//+------------------------------------------------------------------+
//| MoneyManagement.mqh - lot sizing in two axes:                    |
//|  first order : FIXED / RISK (risk% / SL distance)                |
//|  progression : NONE / LINEAR / MULTIPLIER / PLUS / LOG           |
//| All results clamped by RiskControl (MaxLot) + Exec normalize.    |
//+------------------------------------------------------------------+
#ifndef EA_LAB_MM_MQH
#define EA_LAB_MM_MQH
#include "Inputs.mqh"
#include "RiskControl.mqh"

// money per 1.0 point move per 1.0 lot (account currency)
double MM_MoneyPerPointPerLot()
{
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tickSize <= 0.0) return 0.0;
   return tickVal * (point / tickSize);
}

// first-order lot. slDistancePoints required for RISK mode (else falls back to fixed).
double MM_FirstLot(const double slDistancePoints)
{
   double lot = InpFixedLot;
   if(InpFirstLotMode == FIRSTLOT_RISK && slDistancePoints > 0.0)
   {
      double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0;
      double perPoint  = MM_MoneyPerPointPerLot();
      if(perPoint > 0.0)
         lot = riskMoney / (slDistancePoints * perPoint);
   }
   return RiskControl_ClampLot(lot);
}

// lot for grid/recovery order at given level (0 = first, 1.. = added)
double MM_NextLot(const double firstLot, const int level)
{
   int lv = level;
   int maxLv = RiskControl_MaxLevels();
   if(lv > maxLv) lv = maxLv;

   double lot = firstLot;
   switch(InpLotProgression)
   {
      case PROG_LINEAR:
         lot = firstLot * (1.0 + InpProgFactor * lv);
         break;
      case PROG_MULTIPLIER:
      {
         double m = InpProgMultiplier;
         if(InpRecoveryMultMax > 0.0 && m > InpRecoveryMultMax) m = InpRecoveryMultMax;
         lot = firstLot * MathPow(m, lv);
         break;
      }
      case PROG_PLUS:
         lot = firstLot + InpProgPlusLot * lv;
         break;
      case PROG_LOG:
         lot = firstLot * (1.0 + InpProgFactor * MathLog((double)(lv + 1)));
         break;
      case PROG_NONE:
      default:
         lot = firstLot;
         break;
   }
   return RiskControl_ClampLot(lot);
}

#endif // EA_LAB_MM_MQH
